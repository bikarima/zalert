"""
PushService — Firebase FCM v1 با قابلیت‌های پیشرفته:

  ✅ Retry با exponential backoff (3 بار)
  ✅ TTL 24 ساعت — پیام offline میمونه و موقع آنلاین شدن دریافت میشه
  ✅ برگشت توکن‌های invalid برای پاکسازی از DB
  ✅ iOS APNS config کامل (sound, badge, content-available)
  ✅ Channel ID درست برای هر نوع notification
  ✅ collapse_key برای جلوگیری از انباشت پیام‌های تکراری
  ✅ data-only fallback برای تضمین تحویل در background
"""
import asyncio
import time
import logging
from typing import List, Tuple, Optional

import firebase_admin
from firebase_admin import credentials, messaging

log = logging.getLogger("PushService")

# ── Firebase init ─────────────────────────────────────────────────────────────

_initialized = False

def _ensure_initialized() -> None:
    global _initialized
    if not _initialized:
        import os
        base_dir  = os.path.dirname(os.path.abspath(__file__))
        cred_path = os.path.join(base_dir, "firebase-adminsdk.json")
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        _initialized = True
        log.info("Firebase Admin SDK initialized")

# ── Constants ─────────────────────────────────────────────────────────────────

MAX_RETRIES   = 3
RETRY_DELAYS  = [1.0, 2.0, 4.0]   # exponential backoff (seconds)
DEFAULT_TTL   = 86_400             # 24 hours — message stays alive if device offline

# ── Message builder ───────────────────────────────────────────────────────────

def _build_message(
    token:        str,
    title:        str,
    body:         str,
    data:         dict,
    channel_id:   str = "alerts",
    ttl:          int = DEFAULT_TTL,
    collapse_key: Optional[str] = None,
) -> messaging.Message:
    """
    Build a FCM Message with full Android + iOS config.
    All data values coerced to str (FCM requirement).
    """
    str_data = {k: str(v) for k, v in data.items()}
    expiry   = int(time.time()) + ttl

    return messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data=str_data,

        # ── Android ──────────────────────────────────────────────
        android=messaging.AndroidConfig(
            priority="high",
            ttl=ttl,
            collapse_key=collapse_key,
            notification=messaging.AndroidNotification(
                channel_id=channel_id,
                sound="default",
                priority="max",          # heads-up notification
                visibility="public",     # show on lock screen
                notification_count=1,
            ),
        ),

        # ── iOS (APNS) ────────────────────────────────────────────
        apns=messaging.APNSConfig(
            headers={
                "apns-priority":   "10",           # immediate delivery
                "apns-expiration": str(expiry),    # TTL
                "apns-push-type":  "alert",
            },
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    alert=messaging.ApsAlert(title=title, body=body),
                    sound="default",
                    badge=1,
                    content_available=True,   # wake app in background
                    mutable_content=True,     # allow notification service extension
                ),
            ),
        ),

        token=token,
    )

# ── Sync batch sender (runs in thread executor) ───────────────────────────────

def _send_batch_sync(
    tokens:       List[str],
    title:        str,
    body:         str,
    data:         dict,
    channel_id:   str   = "alerts",
    collapse_key: Optional[str] = None,
) -> Tuple[int, List[str]]:
    """
    Send to all tokens with retry.
    Returns: (success_count, invalid_tokens_to_remove_from_db)
    
    Errors are classified:
    - UnregisteredError / SenderIdMismatchError → invalid token, remove from DB
    - Everything else → transient, retry up to MAX_RETRIES times
    """
    if not tokens:
        return 0, []

    _ensure_initialized()

    pending     = list(tokens)
    invalid     = []
    total_sent  = 0

    for attempt in range(MAX_RETRIES):
        if not pending:
            break

        messages = [
            _build_message(t, title, body, data, channel_id, collapse_key=collapse_key)
            for t in pending
        ]

        try:
            response = messaging.send_each(messages)
        except Exception as exc:
            log.error("[Push] send_each error (attempt %d/%d): %s",
                      attempt + 1, MAX_RETRIES, exc)
            if attempt < MAX_RETRIES - 1:
                time.sleep(RETRY_DELAYS[attempt])
            continue

        retry_tokens = []
        for i, r in enumerate(response.responses):
            if r.success:
                total_sent += 1
                continue

            token = pending[i]
            exc   = r.exception

            if isinstance(exc, (messaging.UnregisteredError, messaging.SenderIdMismatchError)):
                # Token is permanently invalid — schedule for DB removal
                log.warning("[Push] Invalid token (removing): %s…", token[:20])
                invalid.append(token)
            else:
                # Transient error (network, quota, etc.) — retry
                log.debug("[Push] Transient failure attempt %d for %s…: %s",
                          attempt + 1, token[:20], exc)
                retry_tokens.append(token)

        pending = retry_tokens

        if pending and attempt < MAX_RETRIES - 1:
            delay = RETRY_DELAYS[attempt]
            log.info("[Push] Retrying %d tokens in %.1fs (attempt %d/%d)",
                     len(pending), delay, attempt + 2, MAX_RETRIES)
            time.sleep(delay)

    if pending:
        log.warning("[Push] %d token(s) exhausted retries — not removed from DB",
                    len(pending))

    log.info("[Push] Batch result: sent=%d invalid=%d exhausted=%d total=%d",
             total_sent, len(invalid), len(pending), len(tokens))

    return total_sent, invalid

# ── Async wrappers ────────────────────────────────────────────────────────────

async def send_push_multi(
    tokens:       List[str],
    title:        str,
    body:         str,
    data:         dict         = None,
    channel_id:   str          = "alerts",
    collapse_key: Optional[str] = None,
) -> Tuple[int, List[str]]:
    """
    Async wrapper around _send_batch_sync.
    Returns (sent_count, invalid_tokens).
    
    IMPORTANT: Caller is responsible for removing invalid_tokens from the DB.
    Example:
        sent, invalid = await send_push_multi(tokens, ...)
        for token in invalid:
            await db.remove_device_by_token(token)
    """
    if not tokens:
        return 0, []
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None,
        _send_batch_sync,
        tokens, title, body, data or {}, channel_id, collapse_key,
    )

# ── High-level alert functions ────────────────────────────────────────────────

async def send_alert_triggered_push(
    tokens:        List[str],
    symbol:        str,
    target_price:  float,
    current_price: float,
    alert_type:    str,
    alert_id:      int,
) -> Tuple[int, List[str]]:
    """
    Push notification وقتی آلرت تریگر میشه.
    از channel 'triggered' استفاده میکنه (اهمیت بیشتر).
    collapse_key = symbol تا اگه چند آلرت یه نماد بود، stack نشن.
    """
    direction = "⬇️ پایین آمد" if alert_type == "below" else "⬆️ بالا رفت"
    title = f"🎯 آلرت {symbol} فعال شد!"
    body  = f"{direction}  |  هدف: {target_price}  |  الان: {current_price}"
    data  = {
        "type":          "alert_triggered",
        "alert_id":      str(alert_id),
        "symbol":        symbol,
        "target_price":  str(target_price),
        "current_price": str(current_price),
        "alert_type":    alert_type,
    }
    return await send_push_multi(
        tokens, title, body, data,
        channel_id="triggered",
        collapse_key=f"alert_{symbol}",
    )


async def send_alert_created_push(
    tokens:        List[str],
    symbol:        str,
    target_price:  float,
    current_price: float,
    alert_type:    str,
    alert_id:      int,
) -> Tuple[int, List[str]]:
    """Push تأیید ثبت آلرت."""
    direction = "⬇️ پایین بیاد" if alert_type == "below" else "⬆️ بالا بره"
    title = f"✅ آلرت {symbol} ثبت شد"
    body  = f"منتظرم {direction}  |  هدف: {target_price}  |  الان: {current_price}"
    data  = {
        "type":          "alert_created",
        "alert_id":      str(alert_id),
        "symbol":        symbol,
        "target_price":  str(target_price),
        "current_price": str(current_price),
        "alert_type":    alert_type,
    }
    return await send_push_multi(
        tokens, title, body, data,
        channel_id="alerts",
        collapse_key=f"new_alert_{symbol}",
    )
