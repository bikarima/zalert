"""
ارسال Push Notification با Firebase Admin SDK (FCM v1)
پشتیبانی از چند دستگاه همزمان
"""

import asyncio
from typing import List
import firebase_admin
from firebase_admin import credentials, messaging

# ── راه‌اندازی Firebase Admin SDK ────────────────────────────────────

_initialized = False

def _ensure_initialized():
    global _initialized
    if not _initialized:
        cred = credentials.Certificate('firebase-adminsdk.json')
        firebase_admin.initialize_app(cred)
        _initialized = True


# ── ارسال به یک دستگاه ───────────────────────────────────────────────

def _send_one(token: str, title: str, body: str, data: dict) -> bool:
    """ارسال sync به یک دستگاه — در thread pool اجرا میشه"""
    try:
        _ensure_initialized()
        # data values باید string باشن
        str_data = {k: str(v) for k, v in data.items()}
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=str_data,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='alerts',
                    sound='default',
                ),
            ),
            token=token,
        )
        messaging.send(message)
        return True
    except messaging.UnregisteredError:
        print(f"[Push] توکن منقضی شده: {token[:20]}...")
        return False
    except Exception as e:
        print(f"[Push] خطا برای توکن {token[:20]}...: {e}")
        return False


# ── ارسال batch به چند دستگاه ────────────────────────────────────────

def _send_batch(tokens: List[str], title: str, body: str, data: dict) -> int:
    """ارسال batch تا 500 توکن — sync"""
    if not tokens:
        return 0
    try:
        _ensure_initialized()
        str_data = {k: str(v) for k, v in data.items()}
        messages = [
            messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                data=str_data,
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        channel_id='alerts',
                        sound='default',
                    ),
                ),
                token=token,
            )
            for token in tokens
        ]
        response = messaging.send_each(messages)
        success = sum(1 for r in response.responses if r.success)
        if response.failure_count > 0:
            for i, r in enumerate(response.responses):
                if not r.success:
                    print(f"[Push] شکست برای توکن {tokens[i][:20]}...: {r.exception}")
        return success
    except Exception as e:
        print(f"[Push] خطای batch: {e}")
        return 0


# ── توابع async عمومی ────────────────────────────────────────────────

async def send_push_multi(tokens: List[str], title: str, body: str, data: dict = None) -> int:
    """
    ارسال push به چند دستگاه همزمان (async wrapper).
    تعداد ارسال‌های موفق رو برمیگردونه.
    """
    if not tokens:
        return 0
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, _send_batch, tokens, title, body, data or {}
    )


async def send_push(token: str, title: str, body: str, data: dict = None) -> bool:
    """ارسال push به یک دستگاه (async wrapper)"""
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, _send_one, token, title, body, data or {}
    )


# ── توابع آلرت ───────────────────────────────────────────────────────

async def send_alert_triggered_push(tokens: List[str], symbol: str,
                                     target_price: float, current_price: float,
                                     alert_type: str, alert_id: int) -> int:
    """push وقتی آلرت فعال میشه — به همه دستگاه‌های کاربر"""
    direction = "پایین آمد" if alert_type == "below" else "بالا رفت"
    title = f"🔔 آلرت {symbol} فعال شد!"
    body  = f"{direction} | هدف: {target_price} | فعلی: {current_price}"
    data  = {
        "type":          "alert_triggered",
        "alert_id":      alert_id,
        "symbol":        symbol,
        "target_price":  target_price,
        "current_price": current_price,
        "alert_type":    alert_type,
    }
    return await send_push_multi(tokens, title, body, data)


async def send_alert_created_push(tokens: List[str], symbol: str,
                                   target_price: float, current_price: float,
                                   alert_type: str, alert_id: int) -> int:
    """push تأیید ثبت آلرت — به همه دستگاه‌های کاربر"""
    direction = "پایین بیاد" if alert_type == "below" else "بالا بره"
    title = f"✅ آلرت {symbol} ثبت شد"
    body  = f"هدف: {target_price} | فعلی: {current_price} | منتظرم {direction}"
    data  = {
        "type":          "alert_created",
        "alert_id":      alert_id,
        "symbol":        symbol,
        "target_price":  target_price,
        "current_price": current_price,
        "alert_type":    alert_type,
    }
    return await send_push_multi(tokens, title, body, data)
