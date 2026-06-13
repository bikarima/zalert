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
    _check_bot()
    db, _ = _get_db_mt5()

    print(f"[Register] ← user_id={body.user_id} platform={body.platform} device={body.device_name}")
    print(f"[Register] ← push_token={'YES: '+body.push_token[:40]+'...' if body.push_token else 'NONE ⚠️'}")

    is_new_user = db.get_user(body.user_id) is None

    db.upsert_user(
        user_id=body.user_id,
        username=body.username,
        push_token=body.push_token,
        platform=body.platform,
        device_name=body.device_name
    )
    devices = db.get_user_devices(body.user_id)
    print(f"[Register] → devices in DB: {len(devices)}")

    # ارسال پیام تلگرام به کاربر
    from datetime import datetime
    import pytz
    tehran = pytz.timezone('Asia/Tehran')
    now = datetime.now(tehran).strftime('%Y-%m-%d %H:%M:%S')

    display_name = body.username or str(body.user_id)
    platform_text = body.platform or 'نامشخص'
    device_text = body.device_name or 'نامشخص'

    if is_new_user:
        msg = (
            f"👋 خوش اومدی به Alert!\n\n"
            f"👤 نام: {display_name}\n"
            f"📱 دستگاه: {device_text}\n"
            f"🖥 پلتفرم: {platform_text}\n"
            f"🕐 زمان: {now}\n\n"
            f"آلرت‌های قیمتت رو تنظیم کن و فوری خبر بگیر 🔔"
        )
    else:
        msg = (
            f"✅ ورود موفق\n\n"
            f"👤 نام: {display_name}\n"
            f"📱 دستگاه: {device_text}\n"
            f"🖥 پلتفرم: {platform_text}\n"
            f"🕐 زمان: {now}\n"
            f"📲 تعداد دستگاه‌های فعال: {len(devices)}"
        )

    try:
        await _bot_app.bot.send_message(chat_id=body.user_id, text=msg)
    except Exception as e:
        print(f"[Register] پیام تلگرام ارسال نشد: {e}")

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


@api.get("/symbols/search", summary="جستجوی نماد در MT5")
async def search_symbols(
    q: str = Query(..., description="عبارت جستجو مثل XAU یا BTC"),
    x_api_key: Optional[str] = Header(default=None)
):
    """جستجوی نمادهای موجود در MT5 — برای autocomplete"""
    _check_api_key(x_api_key)
    from mt5_handler import MT5Handler
    mt5_h = MT5Handler()
    results = mt5_h.search_symbols(q)
    return {"symbols": results}


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


# ── تقویم اقتصادی ─────────────────────────────────────────────────────────────

from calendar_handler import fetch_calendar, get_today_events, get_high_impact_events

class CalendarEvent(BaseModel):
    id:       str
    title:    str
    currency: str
    date:     str
    time:     str
    time_utc: str   # زمان UTC برای scheduled notification در Flutter
    impact:   str
    forecast: str
    previous: str
    actual:   str
    url:      str


@api.get("/calendar", response_model=List[CalendarEvent],
         summary="تقویم اقتصادی هفته جاری")
async def get_calendar(
    week:        str  = Query('thisweek', description="thisweek یا nextweek"),
    impact:      Optional[str] = Query(None, description="فیلتر: high, medium, low"),
    currency:    Optional[str] = Query(None, description="فیلتر ارز مثل USD, EUR"),
    today_only:  bool = Query(False, description="فقط رویدادهای امروز"),
    timezone:    Optional[str] = Query(None, description="timezone کاربر مثل Asia/Tehran"),
    x_api_key:   Optional[str] = Header(default=None),
):
    """
    تقویم اقتصادی از Forex Factory.
    زمان‌ها بر اساس timezone کاربر نمایش داده میشن.
    داده هر 30 دقیقه cache میشه.
    """
    _check_api_key(x_api_key)

    if today_only:
        events = await get_today_events(user_tz=timezone)
    elif impact == 'high':
        events = await get_high_impact_events(week, user_tz=timezone)
    else:
        events = await fetch_calendar(week, user_tz=timezone)

    # فیلتر ارز
    if currency:
        cur = currency.upper()
        events = [e for e in events if e['currency'].upper() == cur]

    # فیلتر impact
    if impact and impact != 'high':
        events = [e for e in events if e['impact'] == impact.lower()]

    return [CalendarEvent(**e) for e in events]


# ── Announcements ─────────────────────────────────────────────────────────────

class AnnouncementOut(BaseModel):
    id:         str
    title:      str
    body:       str
    type:       str   # info / warning / update
    created_at: str


# لیست اطلاعیه‌ها — میتونی بعداً به دیتابیس وصل کنی
_ANNOUNCEMENTS = [
    {
        "id": "1",
        "title": "خوش آمدید!",
        "body": "به اپلیکیشن Alert خوش آمدید. از قسمت آلرت‌ها شروع کنید.",
        "type": "info",
        "created_at": "2026-06-01 10:00:00",
    },
]


@api.get("/announcements", response_model=List[AnnouncementOut],
         summary="لیست اطلاعیه‌های سیستم")
async def get_announcements(x_api_key: Optional[str] = Header(default=None)):
    _check_api_key(x_api_key)
    return [AnnouncementOut(**a) for a in _ANNOUNCEMENTS]


@api.post("/announcements", summary="ارسال اطلاعیه جدید (فقط ادمین)")
async def add_announcement(
    title:    str = Query(...),
    body:     str = Query(...),
    ann_type: str = Query('info', alias='type'),
    admin_key: str = Query(..., description="کلید ادمین"),
    x_api_key: Optional[str] = Header(default=None),
):
    """ادمین میتونه اطلاعیه جدید اضافه کنه"""
    _check_api_key(x_api_key)
    if admin_key != config.API_KEY and admin_key != 'admin':
        raise HTTPException(status_code=403, detail="دسترسی ادمین لازمه")

    import pytz
    from datetime import datetime
    tehran = pytz.timezone('Asia/Tehran')
    now    = datetime.now(tehran).strftime('%Y-%m-%d %H:%M:%S')

    ann = {
        "id":         str(len(_ANNOUNCEMENTS) + 1),
        "title":      title,
        "body":       body,
        "type":       ann_type,
        "created_at": now,
    }
    _ANNOUNCEMENTS.insert(0, ann)
    return {"success": True, "id": ann["id"]}


# ── Debug Push ────────────────────────────────────────────────────────────────

@api.get("/debug/push/{user_id}", summary="بررسی push token کاربر (debug)")
async def debug_push(
    user_id: int,
    x_api_key: Optional[str] = Header(default=None),
):
    """بررسی توکن‌های push یک کاربر"""
    _check_api_key(x_api_key)
    db, _ = _get_db_mt5()
    devices = db.get_user_devices(user_id)
    user    = db.get_user(user_id)
    return {
        "user":        user,
        "devices":     devices,
        "token_count": len(devices),
    }


@api.post("/debug/test-push/{user_id}", summary="ارسال push تست به کاربر")
async def test_push(
    user_id: int,
    x_api_key: Optional[str] = Header(default=None),
):
    """ارسال یه push تست به همه دستگاه‌های کاربر"""
    _check_api_key(x_api_key)
    _check_bot()
    db, _ = _get_db_mt5()
    tokens = db.get_push_tokens(user_id)

    if not tokens:
        raise HTTPException(status_code=404,
            detail=f"هیچ push token برای user {user_id} ثبت نشده")

    from push import send_push_multi
    count = await send_push_multi(
        tokens,
        title="🔔 تست Push",
        body=f"این یه پیام تست برای user {user_id} هست",
        data={"type": "test"},
    )

    return {
        "success":     count > 0,
        "tokens_used": len(tokens),
        "sent":        count,
        "tokens":      [t[:20] + "..." for t in tokens],
    }
