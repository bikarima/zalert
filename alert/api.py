"""
REST API — ربات آلرت MT5
برای اتصال اپلیکیشن موبایل
"""

from fastapi import FastAPI, HTTPException, Header, Path, Query
from pydantic import BaseModel, Field
from typing import Optional, List
import config
from push import send_alert_created_push

# ربات تلگرام — از bot.py inject میشه
_bot_app = None


def set_bot_app(app):
    global _bot_app
    _bot_app = app


# ══════════════════════════════════════════════════════════════════════
# مدل‌های ورودی / خروجی
# ══════════════════════════════════════════════════════════════════════

class RegisterRequest(BaseModel):
    user_id:     int            = Field(..., description="آیدی عددی تلگرام کاربر")
    username:    Optional[str]  = Field(None, description="نام کاربری تلگرام")
    push_token:  Optional[str]  = Field(None, description="توکن push (Expo یا FCM)")
    platform:    Optional[str]  = Field(None, description="ios / android / expo")
    device_name: Optional[str]  = Field(None, description="نام دستگاه مثل iPhone Ali")


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
    alert_type:   str           # above / below
    direction:    str           # ⬆️ بالا رفتن / ⬇️ پایین آمدن
    created_at:   str
    triggered:    bool
    triggered_at: Optional[str]


class AlertCreateResponse(BaseModel):
    success:       bool
    alert_id:      int
    symbol:        str           # نماد واقعی که MT5 استفاده کرد
    current_price: float
    alert_type:    str
    message:       str


class DeleteResponse(BaseModel):
    success: bool
    message: str


class PriceResponse(BaseModel):
    symbol:        str
    resolved_symbol: str
    price:         float
    time:          str


class StatsResponse(BaseModel):
    total_active: int
    by_symbol:    dict


# ══════════════════════════════════════════════════════════════════════
# ساخت API
# ══════════════════════════════════════════════════════════════════════

api = FastAPI(
    title="MT5 Alert API",
    version="2.0.0",
    description="API ربات آلرت قیمت — برای اتصال اپلیکیشن موبایل"
)


# ── helper ────────────────────────────────────────────────────────────

def _check_api_key(x_api_key: Optional[str]):
    if config.API_KEY and x_api_key != config.API_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized")

def _check_bot():
    if _bot_app is None:
        raise HTTPException(status_code=503, detail="Bot not ready")

def _get_db_mt5():
    from database import Database
    from mt5_handler import MT5Handler
    return Database(), MT5Handler()

def _direction(alert_type: str) -> str:
    return "⬇️ پایین آمدن" if alert_type == "below" else "⬆️ بالا رفتن"

def _to_alert_out(a: dict) -> AlertOut:
    return AlertOut(
        id=a['id'],
        symbol=a['symbol'],
        target_price=a['target_price'],
        alert_type=a['alert_type'],
        direction=_direction(a['alert_type']),
        created_at=a['created_at'],
        triggered=a['triggered'],
        triggered_at=a.get('triggered_at')
    )


# ══════════════════════════════════════════════════════════════════════
# Endpoints
# ══════════════════════════════════════════════════════════════════════

# ── ثبت / آپدیت کاربر ────────────────────────────────────────────────

@api.post("/register", summary="ثبت یا آپدیت کاربر + ذخیره push token")
async def register(body: RegisterRequest, x_api_key: Optional[str] = Header(default=None)):
    """
    اپ موبایل هنگام لاگین یا هر بار که توکن push عوض شد این رو صدا میزنه.
    هر بار با یه push_token جدید صدا زده بشه، دستگاه جدید اضافه میشه.
    """
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    db.upsert_user(
        user_id=body.user_id,
        username=body.username,
        push_token=body.push_token,
        platform=body.platform,
        device_name=body.device_name
    )
    devices = db.get_user_devices(body.user_id)
    return {
        "success": True,
        "message": "کاربر ثبت شد",
        "device_count": len(devices)
    }


# ── آلرت‌ها ───────────────────────────────────────────────────────────

@api.post("/alert", response_model=AlertCreateResponse, summary="ثبت آلرت جدید")
async def create_alert(
    body: AlertCreateRequest,
    x_api_key: Optional[str] = Header(default=None)
):
    """
    ثبت آلرت جدید برای کاربر.
    بعد از ثبت:
    - پیام تأیید به DM تلگرام کاربر میفرسته
    - push notification به اپ موبایل میفرسته (اگه push_token داشته باشه)
    """
    _check_api_key(x_api_key)
    _check_bot()

    db, mt5 = _get_db_mt5()
    symbol = body.symbol.upper()
    username = body.username or str(body.user_id)

    # اگه push_token فرستاده، دستگاه رو ثبت/آپدیت کن
    if body.push_token:
        db.upsert_user(body.user_id, username, body.push_token,
                       body.platform, body.device_name)

    # بررسی محدودیت
    if db.count_user_alerts(body.user_id) >= config.MAX_ALERTS_PER_USER:
        raise HTTPException(status_code=400,
            detail=f"حداکثر {config.MAX_ALERTS_PER_USER} آلرت فعال مجاز است")

    # دریافت قیمت + resolve نماد
    current_price = mt5.get_price(symbol)
    if current_price is None:
        raise HTTPException(status_code=400,
            detail=f"نماد {symbol} یافت نشد یا MT5 در دسترس نیست")

    real_symbol = mt5.get_resolved_symbol(symbol) or symbol

    alert_type = "below" if current_price > body.target_price else "above"

    alert_id = db.add_alert(
        user_id=body.user_id,
        username=username,
        symbol=real_symbol,
        target_price=body.target_price,
        alert_type=alert_type,
        group_id=body.user_id      # آلرت API همیشه به DM میره
    )

    # ارسال پیام تلگرام
    tg_text = (
        f"🔔 آلرت جدید ثبت شد!\n\n"
        f"🆔 شناسه: {alert_id}\n"
        f"📊 نماد: {real_symbol}\n"
        f"🎯 قیمت هدف: {body.target_price}\n"
        f"💵 قیمت فعلی: {current_price}\n"
        f"📈 نوع: {_direction(alert_type)}\n\n"
        f"وقتی قیمت به هدف برسه بهت خبر میدم ✅"
    )
    try:
        await _bot_app.bot.send_message(chat_id=body.user_id, text=tg_text)
    except Exception as e:
        print(f"[API] پیام تلگرام ارسال نشد: {e}")

    # ارسال push notification به همه دستگاه‌های کاربر
    push_tokens = db.get_push_tokens(body.user_id)
    # اگه توکن جاری هم داده شده و هنوز در لیست نیست اضافه‌اش کن
    if body.push_token and body.push_token not in push_tokens:
        push_tokens.append(body.push_token)
    if push_tokens:
        try:
            await send_alert_created_push(
                tokens=push_tokens,
                symbol=real_symbol,
                target_price=body.target_price,
                current_price=current_price,
                alert_type=alert_type,
                alert_id=alert_id
            )
        except Exception as e:
            print(f"[API] push ارسال نشد: {e}")

    return AlertCreateResponse(
        success=True,
        alert_id=alert_id,
        symbol=real_symbol,
        current_price=current_price,
        alert_type=alert_type,
        message="آلرت با موفقیت ثبت شد"
    )


@api.get("/alerts/{user_id}", response_model=List[AlertOut], summary="آلرت‌های یک کاربر")
async def get_alerts(
    user_id: int = Path(..., description="آیدی عددی تلگرام کاربر"),
    include_triggered: bool = Query(False, description="شامل آلرت‌های فعال شده هم بشه"),
    x_api_key: Optional[str] = Header(default=None)
):
    """لیست آلرت‌های فعال (و در صورت درخواست، triggered شده) یک کاربر"""
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    alerts = db.get_user_alerts(user_id, include_triggered=include_triggered)
    return [_to_alert_out(a) for a in alerts]


@api.get("/alert/{alert_id}", response_model=AlertOut, summary="جزئیات یک آلرت")
async def get_alert(
    alert_id: int = Path(...),
    x_api_key: Optional[str] = Header(default=None)
):
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    alert = db.get_alert_by_id(alert_id)
    if alert is None:
        raise HTTPException(status_code=404, detail="آلرت یافت نشد")
    return _to_alert_out(alert)


@api.delete("/alert/{alert_id}", response_model=DeleteResponse, summary="حذف یک آلرت")
async def delete_alert(
    alert_id: int = Path(...),
    user_id: int = Query(..., description="آیدی کاربر برای تأیید مالکیت"),
    x_api_key: Optional[str] = Header(default=None)
):
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    deleted = db.delete_alert(alert_id, user_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="آلرت یافت نشد یا متعلق به این کاربر نیست")
    return DeleteResponse(success=True, message=f"آلرت {alert_id} حذف شد")


@api.delete("/alerts/{user_id}/clear", response_model=DeleteResponse, summary="حذف همه آلرت‌های یک کاربر")
async def clear_alerts(
    user_id: int = Path(...),
    x_api_key: Optional[str] = Header(default=None)
):
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    count = db.clear_user_alerts(user_id)
    return DeleteResponse(success=True, message=f"{count} آلرت حذف شد")


# ── قیمت ─────────────────────────────────────────────────────────────

@api.get("/price/{symbol}", response_model=PriceResponse, summary="قیمت فعلی یک نماد")
async def get_price(
    symbol: str = Path(..., description="نماد مثل XAUUSD"),
    x_api_key: Optional[str] = Header(default=None)
):
    _check_api_key(x_api_key)
    from mt5_handler import MT5Handler
    import pytz
    from datetime import datetime
    mt5 = MT5Handler()
    sym = symbol.upper()
    price = mt5.get_price(sym)
    if price is None:
        raise HTTPException(status_code=400, detail=f"نماد {sym} یافت نشد")
    real = mt5.get_resolved_symbol(sym) or sym
    tehran = pytz.timezone('Asia/Tehran')
    now = datetime.now(tehran).strftime('%Y-%m-%d %H:%M:%S')
    return PriceResponse(symbol=sym, resolved_symbol=real, price=price, time=now)


# ── آمار ─────────────────────────────────────────────────────────────

@api.get("/stats", response_model=StatsResponse, summary="آمار کل آلرت‌های فعال")
async def get_stats(x_api_key: Optional[str] = Header(default=None)):
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    by_symbol = db.get_stats()
    total = sum(by_symbol.values())
    return StatsResponse(total_active=total, by_symbol=by_symbol)


# ── push token ────────────────────────────────────────────────────────

@api.put("/user/{user_id}/push-token", summary="آپدیت push token کاربر")
async def update_push_token(
    user_id: int = Path(...),
    push_token: str = Query(..., description="توکن جدید"),
    platform: Optional[str] = Query(None, description="ios / android / expo"),
    x_api_key: Optional[str] = Header(default=None)
):
    """
    وقتی توکن push در اپ عوض میشه (مثلاً بعد از نصب مجدد) این رو صدا بزن.
    """
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    db.upsert_user(user_id, push_token=push_token, platform=platform)
    return {"success": True, "message": "توکن push آپدیت شد"}


# ── مدیریت دستگاه‌ها ─────────────────────────────────────────────────

@api.get("/user/{user_id}/devices", response_model=List[DeviceOut],
         summary="لیست دستگاه‌های یک کاربر")
async def get_devices(
    user_id: int = Path(...),
    x_api_key: Optional[str] = Header(default=None)
):
    """همه دستگاه‌هایی که این کاربر push token ثبت کرده"""
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    return db.get_user_devices(user_id)


@api.delete("/user/{user_id}/devices/{device_id}",
            response_model=DeleteResponse, summary="حذف یک دستگاه")
async def remove_device(
    user_id: int = Path(...),
    device_id: int = Path(..., description="آیدی دستگاه از لیست /devices"),
    x_api_key: Optional[str] = Header(default=None)
):
    """حذف یک دستگاه خاص — مثلاً وقتی کاربر از اپ logout میکنه"""
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    # پیدا کردن توکن با device_id
    devices = db.get_user_devices(user_id)
    device = next((d for d in devices if d['id'] == device_id), None)
    if device is None:
        raise HTTPException(status_code=404, detail="دستگاه یافت نشد")
    db.remove_device(user_id, device['push_token'])
    return DeleteResponse(success=True, message="دستگاه حذف شد")


@api.delete("/user/{user_id}/devices", response_model=DeleteResponse,
            summary="حذف همه دستگاه‌های یک کاربر")
async def remove_all_devices(
    user_id: int = Path(...),
    x_api_key: Optional[str] = Header(default=None)
):
    """حذف همه دستگاه‌ها — مثلاً وقتی کاربر از همه جا logout میکنه"""
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    count = db.remove_all_devices(user_id)
    return DeleteResponse(success=True, message=f"{count} دستگاه حذف شد")


# ── push token ────────────────────────────────────────────────────────

@api.put("/user/{user_id}/push-token", summary="اضافه کردن یا آپدیت push token")
async def update_push_token(
    user_id: int = Path(...),
    push_token: str = Query(..., description="توکن جدید"),
    platform: Optional[str] = Query(None, description="ios / android / expo"),
    device_name: Optional[str] = Query(None, description="نام دستگاه"),
    x_api_key: Optional[str] = Header(default=None)
):
    """
    وقتی توکن push در اپ عوض میشه (مثلاً بعد از نصب مجدد) این رو صدا بزن.
    اگه توکن جدید باشه دستگاه جدید اضافه میشه، اگه قبلاً بوده آپدیت میشه.
    """
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    db.upsert_user(user_id, push_token=push_token,
                   platform=platform, device_name=device_name)
    devices = db.get_user_devices(user_id)
    return {
        "success": True,
        "message": "توکن push ثبت شد",
        "device_count": len(devices)
    }


# ── health ────────────────────────────────────────────────────────────

@api.get("/health", summary="بررسی وضعیت سرویس")
async def health():
    return {
        "status": "ok",
        "bot_ready": _bot_app is not None,
        "version": "2.0.0"
    }
