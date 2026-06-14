"""
REST API — ZAlert MT5
برای اتصال اپلیکیشن موبایل

Auth flow:
  POST /auth/request-otp  — ارسال کد ۶ رقمی به تلگرام کاربر
  POST /auth/verify-otp   — تأیید کد و ورود
  POST /register          — ثبت/آپدیت دستگاه (بعد از verify-otp صدا زده میشه)
"""
import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional, List

import pytz
from fastapi import FastAPI, HTTPException, Header, Path, Query
from pydantic import BaseModel, Field

import config
from push import send_alert_created_push

# ربات تلگرام — از bot.py inject میشه
_bot_app = None

def set_bot_app(app):
    global _bot_app
    _bot_app = app

# ── OTP helpers ───────────────────────────────────────────────────────────────

OTP_EXPIRE_MINUTES    = 5
OTP_MAX_ATTEMPTS      = 5
OTP_RATE_LIMIT_HOUR   = 5     # حداکثر درخواست در ساعت

def _gen_otp() -> str:
    """کد ۶ رقمی کریپتوگرافیک."""
    return str(secrets.randbelow(900_000) + 100_000)

def _hash_otp(code: str) -> str:
    return hashlib.sha256(code.strip().encode()).hexdigest()

# ── Pydantic models ───────────────────────────────────────────────────────────

class OtpRequestBody(BaseModel):
    user_id:  int            = Field(..., description="آیدی عددی تلگرام کاربر")
    username: Optional[str]  = Field(None, description="نام کاربری (اختیاری)")

class OtpVerifyBody(BaseModel):
    user_id:     int           = Field(..., description="آیدی عددی تلگرام کاربر")
    code:        str           = Field(..., description="کد ۶ رقمی دریافتی از تلگرام")
    device_name: Optional[str] = Field(None)
    platform:    Optional[str] = Field(None, description="android / ios")
    push_token:  Optional[str] = Field(None)

class RegisterRequest(BaseModel):
    user_id:     int            = Field(..., description="آیدی عددی تلگرام کاربر")
    username:    Optional[str]  = Field(None, description="نام کاربری تلگرام")
    push_token:  Optional[str]  = Field(None, description="توکن push (FCM)")
    platform:    Optional[str]  = Field(None, description="ios / android")
    device_name: Optional[str]  = Field(None, description="نام دستگاه")

class DeviceOut(BaseModel):
    id:          int
    push_token:  str
    platform:    Optional[str]
    device_name: Optional[str]
    added_at:    str
    last_used:   Optional[str]

class AlertCreateRequest(BaseModel):
    user_id:      int           = Field(..., description="آیدی عددی تلگرام کاربر")
    symbol:       str           = Field(..., description="نماد مثل XAUUSD")
    target_price: float         = Field(..., description="قیمت هدف")
    username:     Optional[str] = Field(None)
    push_token:   Optional[str] = Field(None, description="توکن push دستگاه جاری")
    platform:     Optional[str] = Field(None)
    device_name:  Optional[str] = Field(None)

class AlertOut(BaseModel):
    id:           int
    symbol:       str
    target_price: float
    alert_type:   str
    direction:    str
    created_at:   str
    triggered:    bool
    triggered_at: Optional[str]

class AlertCreateResponse(BaseModel):
    success:       bool
    alert_id:      int
    symbol:        str
    current_price: float
    alert_type:    str
    message:       str

class DeleteResponse(BaseModel):
    success: bool
    message: str

class PriceResponse(BaseModel):
    symbol:          str
    resolved_symbol: str
    price:           float
    time:            str

class StatsResponse(BaseModel):
    total_active: int
    by_symbol:    dict

# ── App ───────────────────────────────────────────────────────────────────────

api = FastAPI(
    title="ZAlert API",
    version="3.0.0",
    description="API ربات آلرت قیمت — اتصال اپلیکیشن موبایل"
)

# ── Helpers ───────────────────────────────────────────────────────────────────

def _check_api_key(x_api_key: Optional[str]):
    if config.API_KEY and x_api_key != config.API_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized")

def _check_bot():
    if _bot_app is None:
        raise HTTPException(status_code=503, detail="Bot not ready")

def _get_db_mt5():
    from database    import Database
    from mt5_handler import MT5Handler
    return Database(), MT5Handler()

def _direction(alert_type: str) -> str:
    return "⬇️ پایین آمدن" if alert_type == "below" else "⬆️ بالا رفتن"

def _to_alert_out(a: dict) -> AlertOut:
    return AlertOut(
        id=a["id"], symbol=a["symbol"],
        target_price=a["target_price"], alert_type=a["alert_type"],
        direction=_direction(a["alert_type"]),
        created_at=a["created_at"], triggered=a["triggered"],
        triggered_at=a.get("triggered_at"),
    )

def _now_tehran() -> str:
    return datetime.now(pytz.timezone("Asia/Tehran")).strftime("%Y-%m-%d %H:%M:%S")

# ══════════════════════════════════════════════════════════════════════════════
# Auth — OTP
# ══════════════════════════════════════════════════════════════════════════════

@api.post("/auth/request-otp", summary="درخواست کد تأیید تلگرام")
async def request_otp(
    body:      OtpRequestBody,
    x_api_key: Optional[str] = Header(default=None),
):
    """
    یه کد ۶ رقمی تولید میکنه و از طریق ربات تلگرام به کاربر میفرسته.
    کاربر باید ابتدا /start به ربات زده باشه تا بتونه پیام دریافت کنه.
    """
    _check_api_key(x_api_key)
    _check_bot()
    db, _ = _get_db_mt5()

    # Rate limiting
    one_hour_ago = datetime.now(timezone.utc) - timedelta(hours=1)
    recent = await db.count_recent_otp_requests(body.user_id, one_hour_ago)
    if recent >= OTP_RATE_LIMIT_HOUR:
        raise HTTPException(429, "درخواست زیاد — یک ساعت دیگر تلاش کنید")

    code      = _gen_otp()
    code_hash = _hash_otp(code)
    await db.create_otp(body.user_id, code_hash)

    msg = (
        f"🔐 <b>کد تأیید ZAlert</b>\n\n"
        f"<b>  {code}  </b>\n\n"
        f"⏱ این کد <b>{OTP_EXPIRE_MINUTES} دقیقه</b> معتبر است.\n"
        f"⚠️ این کد را با کسی به اشتراک نگذارید.\n\n"
        f"اگر شما درخواست نداده‌اید، این پیام را نادیده بگیرید."
    )
    try:
        await _bot_app.bot.send_message(
            chat_id=body.user_id, text=msg, parse_mode="HTML"
        )
    except Exception as e:
        print(f"[OTP] send failed for user_id={body.user_id}: {e}")
        raise HTTPException(
            400,
            "ارسال کد ممکن نشد — ابتدا ربات @YourBotUsername را در تلگرام استارت کنید"
        )

    print(f"[OTP] Code sent → user_id={body.user_id}")
    return {
        "success":    True,
        "expires_in": OTP_EXPIRE_MINUTES * 60,
        "message":    f"کد {OTP_EXPIRE_MINUTES} دقیقه‌ای به تلگرامت ارسال شد",
    }


@api.post("/auth/verify-otp", summary="تأیید کد و ورود")
async def verify_otp(
    body:      OtpVerifyBody,
    x_api_key: Optional[str] = Header(default=None),
):
    """
    کد وارد شده رو تأیید میکنه.
    در صورت موفقیت: کاربر رجیستر میشه و پیام تأیید به تلگرام میفرسته.
    """
    _check_api_key(x_api_key)
    _check_bot()
    db, _ = _get_db_mt5()

    ok, err = await db.verify_otp(body.user_id, _hash_otp(body.code))
    if not ok:
        raise HTTPException(400, err)

    # OTP تأیید شد — کاربر رو ثبت کن
    device_name = body.device_name or "Unknown Device"
    await db.upsert_user(
        user_id=body.user_id,
        push_token=body.push_token,
        platform=body.platform,
        device_name=device_name,
    )
    await db.delete_otp(body.user_id)

    # پیام تأیید تلگرام
    try:
        await _bot_app.bot.send_message(
            chat_id=body.user_id,
            text=(
                f"✅ <b>ورود موفق!</b>\n\n"
                f"📱 دستگاه: {device_name}\n"
                f"🖥 پلتفرم: {body.platform or '—'}\n"
                f"🕐 زمان: {_now_tehran()}"
            ),
            parse_mode="HTML",
        )
    except Exception:
        pass

    user = await db.get_user(body.user_id)
    print(f"[OTP] Verified → user_id={body.user_id} device={device_name}")
    return {
        "success":  True,
        "user_id":  body.user_id,
        "username": (user or {}).get("username"),
    }

# ══════════════════════════════════════════════════════════════════════════════
# Register / User
# ══════════════════════════════════════════════════════════════════════════════

@api.post("/register", summary="ثبت یا آپدیت دستگاه + push token")
async def register(
    body:      RegisterRequest,
    x_api_key: Optional[str] = Header(default=None),
):
    """
    بعد از verify-otp این endpoint فراخوانی میشه.
    همچنین هنگام FCM token refresh.
    """
    _check_api_key(x_api_key)
    _check_bot()
    db, _ = _get_db_mt5()

    print(f"[Register] user_id={body.user_id} platform={body.platform} "
          f"push={'YES' if body.push_token else 'NONE'}")

    await db.upsert_user(
        user_id=body.user_id,
        username=body.username,
        push_token=body.push_token,
        platform=body.platform,
        device_name=body.device_name,
    )
    devices = await db.get_user_devices(body.user_id)
    return {"success": True, "message": "کاربر ثبت شد", "device_count": len(devices)}

# ══════════════════════════════════════════════════════════════════════════════
# Alerts
# ══════════════════════════════════════════════════════════════════════════════

@api.post("/alert", response_model=AlertCreateResponse, summary="ثبت آلرت جدید")
async def create_alert(
    body:      AlertCreateRequest,
    x_api_key: Optional[str] = Header(default=None),
):
    _check_api_key(x_api_key)
    _check_bot()
    db, mt5 = _get_db_mt5()

    symbol   = body.symbol.upper()
    username = body.username or str(body.user_id)

    if body.push_token:
        await db.upsert_user(body.user_id, username, body.push_token,
                             body.platform, body.device_name)

    if await db.count_user_alerts(body.user_id) >= config.MAX_ALERTS_PER_USER:
        raise HTTPException(400, f"حداکثر {config.MAX_ALERTS_PER_USER} آلرت مجاز است")

    current_price = mt5.get_price(symbol)
    if current_price is None:
        raise HTTPException(400, f"نماد {symbol} یافت نشد")

    real_symbol = mt5.get_resolved_symbol(symbol) or symbol
    alert_type  = "below" if current_price > body.target_price else "above"
    alert_id    = await db.add_alert(
        body.user_id, username, real_symbol, body.target_price,
        alert_type, group_id=body.user_id,
    )

    try:
        await _bot_app.bot.send_message(
            chat_id=body.user_id,
            text=(
                f"🔔 آلرت جدید ثبت شد!\n\n"
                f"🆔 #{alert_id}\n"
                f"📊 {real_symbol}\n"
                f"🎯 هدف: {body.target_price}\n"
                f"💵 فعلی: {current_price}\n"
                f"📈 {_direction(alert_type)}"
            ),
        )
    except Exception:
        pass

    push_tokens = await db.get_push_tokens(body.user_id)
    if body.push_token and body.push_token not in push_tokens:
        push_tokens.append(body.push_token)
    if push_tokens:
        try:
            await send_alert_created_push(
                tokens=push_tokens, symbol=real_symbol,
                target_price=body.target_price, current_price=current_price,
                alert_type=alert_type, alert_id=alert_id,
            )
        except Exception:
            pass

    return AlertCreateResponse(
        success=True, alert_id=alert_id, symbol=real_symbol,
        current_price=current_price, alert_type=alert_type,
        message="آلرت با موفقیت ثبت شد",
    )


@api.get("/alerts/{user_id}", response_model=List[AlertOut])
async def get_alerts(
    user_id:           int  = Path(...),
    include_triggered: bool = Query(False),
    x_api_key:         Optional[str] = Header(default=None),
):
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    return [_to_alert_out(a) for a in
            await db.get_user_alerts(user_id, include_triggered=include_triggered)]


@api.delete("/alert/{alert_id}", response_model=DeleteResponse)
async def delete_alert(
    alert_id:  int = Path(...),
    user_id:   int = Query(...),
    x_api_key: Optional[str] = Header(default=None),
):
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    if not await db.delete_alert(alert_id, user_id):
        raise HTTPException(404, "آلرت یافت نشد یا متعلق به این کاربر نیست")
    return DeleteResponse(success=True, message=f"آلرت {alert_id} حذف شد")


@api.delete("/alerts/{user_id}/clear", response_model=DeleteResponse)
async def clear_alerts(
    user_id:   int = Path(...),
    x_api_key: Optional[str] = Header(default=None),
):
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    count = await db.clear_user_alerts(user_id)
    return DeleteResponse(success=True, message=f"{count} آلرت حذف شد")

# ══════════════════════════════════════════════════════════════════════════════
# Price / Stats
# ══════════════════════════════════════════════════════════════════════════════

@api.get("/price/{symbol}", response_model=PriceResponse)
async def get_price(
    symbol:    str = Path(...),
    x_api_key: Optional[str] = Header(default=None),
):
    _check_api_key(x_api_key)
    from mt5_handler import MT5Handler
    mt5 = MT5Handler()
    sym   = symbol.upper()
    price = mt5.get_price(sym)
    if price is None:
        raise HTTPException(400, f"نماد {sym} یافت نشد")
    return PriceResponse(
        symbol=sym, resolved_symbol=mt5.get_resolved_symbol(sym) or sym,
        price=price, time=_now_tehran(),
    )


@api.get("/symbols/search")
async def search_symbols(
    q:         str = Query(...),
    x_api_key: Optional[str] = Header(default=None),
):
    _check_api_key(x_api_key)
    from mt5_handler import MT5Handler
    return {"symbols": MT5Handler().search_symbols(q)}


@api.get("/stats", response_model=StatsResponse)
async def get_stats(x_api_key: Optional[str] = Header(default=None)):
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    by_symbol = await db.get_stats()
    return StatsResponse(total_active=sum(by_symbol.values()), by_symbol=by_symbol)

# ══════════════════════════════════════════════════════════════════════════════
# Devices / Push token
# ══════════════════════════════════════════════════════════════════════════════

@api.put("/user/{user_id}/push-token")
async def update_push_token(
    user_id:     int             = Path(...),
    push_token:  str             = Query(...),
    platform:    Optional[str]   = Query(None),
    device_name: Optional[str]   = Query(None),
    x_api_key:   Optional[str]   = Header(default=None),
):
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    await db.upsert_user(user_id, push_token=push_token,
                         platform=platform, device_name=device_name)
    devices = await db.get_user_devices(user_id)
    return {"success": True, "message": "توکن push ثبت شد", "device_count": len(devices)}


@api.get("/user/{user_id}/devices", response_model=List[DeviceOut])
async def get_devices(
    user_id:   int = Path(...),
    x_api_key: Optional[str] = Header(default=None),
):
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    return await db.get_user_devices(user_id)


@api.delete("/user/{user_id}/devices", response_model=DeleteResponse)
async def remove_all_devices(
    user_id:   int = Path(...),
    x_api_key: Optional[str] = Header(default=None),
):
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    count = await db.remove_all_devices(user_id)
    return DeleteResponse(success=True, message=f"{count} دستگاه حذف شد")

# ══════════════════════════════════════════════════════════════════════════════
# Calendar
# ══════════════════════════════════════════════════════════════════════════════

from calendar_handler import fetch_calendar, get_today_events, get_high_impact_events

class CalendarEvent(BaseModel):
    id: str; title: str; currency: str; date: str; time: str
    time_utc: str; impact: str; forecast: str; previous: str
    actual: str; url: str

@api.get("/calendar", response_model=List[CalendarEvent])
async def get_calendar(
    week:       str           = Query("thisweek"),
    impact:     Optional[str] = Query(None),
    currency:   Optional[str] = Query(None),
    today_only: bool          = Query(False),
    timezone:   Optional[str] = Query(None),
    x_api_key:  Optional[str] = Header(default=None),
):
    _check_api_key(x_api_key)
    if today_only:
        events = await get_today_events(user_tz=timezone)
    elif impact == "high":
        events = await get_high_impact_events(week, user_tz=timezone)
    else:
        events = await fetch_calendar(week, user_tz=timezone)
    if currency:
        events = [e for e in events if e["currency"].upper() == currency.upper()]
    if impact and impact != "high":
        events = [e for e in events if e["impact"] == impact.lower()]
    return [CalendarEvent(**e) for e in events]

# ══════════════════════════════════════════════════════════════════════════════
# Announcements
# ══════════════════════════════════════════════════════════════════════════════

class AnnouncementOut(BaseModel):
    id: str; title: str; body: str; type: str; created_at: str

_ANNOUNCEMENTS = [{
    "id": "1", "title": "خوش آمدید!",
    "body": "به ZAlert خوش آمدید. از قسمت آلرت‌ها شروع کنید.",
    "type": "info", "created_at": "2026-06-01 10:00:00",
}]

@api.get("/announcements", response_model=List[AnnouncementOut])
async def get_announcements(x_api_key: Optional[str] = Header(default=None)):
    _check_api_key(x_api_key)
    return [AnnouncementOut(**a) for a in _ANNOUNCEMENTS]

# ══════════════════════════════════════════════════════════════════════════════
# Health
# ══════════════════════════════════════════════════════════════════════════════

@api.get("/health")
async def health():
    return {"status": "ok", "bot_ready": _bot_app is not None, "version": "3.0.0"}
