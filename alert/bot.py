"""
ZAlert Bot — نسخه ۲.۰
ربات آلرت قیمت MT5 با رابط کاربری شیشه‌ای و فیچرهای پیشرفته
"""

import asyncio
import threading
import uvicorn
from telegram import (
    Update, Chat,
    InlineKeyboardButton, InlineKeyboardMarkup,
)
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    ContextTypes, MessageHandler, filters,
)
from telegram.constants import ParseMode
from datetime import datetime
import pytz
import config
from database import Database
from mt5_handler import MT5Handler
from api import api, set_bot_app
from push import send_alert_triggered_push
from calendar_handler import get_today_events, get_high_impact_events

# ─── نمونه‌ها ───────────────────────────────────────────────────────────────
db  = Database()
mt5 = MT5Handler()

TEHRAN = pytz.timezone('Asia/Tehran')

# ردیابی زمان شروع برای uptime
_start_time = datetime.now(TEHRAN)

# جلوگیری از ارسال تکراری نوتیف تقویم
_sent_calendar_notifs: set = set()

# نمادهای محبوب
POPULAR_SYMBOLS = [
    ("🥇 طلا",    "XAUUSD"),
    ("🥈 نقره",   "XAGUSD"),
    ("💶 EUR/USD", "EURUSD"),
    ("🫙 نفت",    "USOIL"),
    ("📈 S&P500",  "US500"),
    ("🔷 BTC",    "BTCUSD"),
    ("💵 GBP/USD", "GBPUSD"),
    ("📊 NAS100",  "NAS100"),
]

# ─── کمکی ───────────────────────────────────────────────────────────────────

def now_tehran() -> str:
    return datetime.now(TEHRAN).strftime('%H:%M:%S')

def now_tehran_full() -> str:
    return datetime.now(TEHRAN).strftime('%Y-%m-%d %H:%M:%S')

def fmt_price(price: float) -> str:
    """نمایش قیمت با فرمت مناسب"""
    if price >= 1000:
        return f"{price:,.2f}"
    elif price >= 1:
        return f"{price:.5f}".rstrip('0').rstrip('.')
    else:
        return f"{price:.6f}".rstrip('0').rstrip('.')

def type_text(alert_type: str) -> str:
    return "⬇️ کاهش" if alert_type == "below" else "⬆️ افزایش"

def progress_bar(current: float, target: float, alert_type: str, width: int = 10) -> str:
    """نوار پیشرفت قیمت به سمت هدف"""
    try:
        if alert_type == "above":
            ratio = min(current / target, 1.0) if target else 0
        else:
            ratio = min(target / current, 1.0) if current else 0
        filled = int(ratio * width)
        bar = "█" * filled + "░" * (width - filled)
        pct = int(ratio * 100)
        return f"[{bar}] {pct}%"
    except Exception:
        return ""

# ─── کیبوردها ───────────────────────────────────────────────────────────────

def main_menu_keyboard() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([
        [
            InlineKeyboardButton("🔔 آلرت جدید",    callback_data="menu_new_alert"),
            InlineKeyboardButton("📋 آلرت‌های من",  callback_data="menu_list"),
        ],
        [
            InlineKeyboardButton("💰 قیمت لحظه‌ای", callback_data="menu_price"),
            InlineKeyboardButton("📅 تقویم امروز",  callback_data="menu_calendar"),
        ],
        [
            InlineKeyboardButton("📊 آمار کل",      callback_data="menu_stats"),
            InlineKeyboardButton("👤 پروفایل من",    callback_data="menu_profile"),
        ],
        [
            InlineKeyboardButton("🖥 وضعیت سرور", callback_data="menu_status"),
        ],
            InlineKeyboardButton("📊 آمار کل",      callback_data="menu_stats"),
            InlineKeyboardButton("👤 پروفایل من",    callback_data="menu_profile"),
        ],
    ])

def symbol_keyboard(action: str) -> InlineKeyboardMarkup:
    """کیبورد انتخاب سریع نماد"""
    rows = []
    row = []
    for label, sym in POPULAR_SYMBOLS:
        row.append(InlineKeyboardButton(label, callback_data=f"{action}:{sym}"))
        if len(row) == 2:
            rows.append(row)
            row = []
    if row:
        rows.append(row)
    rows.append([InlineKeyboardButton("⬅️ بازگشت", callback_data="back_main")])
    return InlineKeyboardMarkup(rows)

def alert_list_keyboard(alerts: list) -> InlineKeyboardMarkup:
    """کیبورد لیست آلرت‌ها با دکمه حذف"""
    rows = []
    for a in alerts:
        sym  = a['symbol']
        tid  = a['id']
        tp   = fmt_price(a['target_price'])
        emoji = "⬇️" if a['alert_type'] == "below" else "⬆️"
        rows.append([
            InlineKeyboardButton(f"{emoji} {sym} @ {tp}", callback_data=f"view_alert:{tid}"),
            InlineKeyboardButton("🗑",                      callback_data=f"del_alert:{tid}"),
        ])
    rows.append([
        InlineKeyboardButton("🗑 حذف همه",    callback_data="clear_confirm"),
        InlineKeyboardButton("🏠 منوی اصلی", callback_data="back_main"),
    ])
    return InlineKeyboardMarkup(rows)

def price_keyboard(symbol: str) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([
        [
            InlineKeyboardButton("🔄 بروزرسانی", callback_data=f"refresh_price:{symbol}"),
            InlineKeyboardButton("🔔 آلرت بذار",  callback_data=f"set_for:{symbol}"),
        ],
        [InlineKeyboardButton("⬅️ بازگشت", callback_data="menu_price")],
    ])

def confirm_clear_keyboard() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([
        [
            InlineKeyboardButton("✅ بله، حذف کن",   callback_data="clear_do"),
            InlineKeyboardButton("❌ نه، برگرد",     callback_data="menu_list"),
        ],
    ])

def back_main_keyboard() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("🏠 منوی اصلی", callback_data="back_main")],
    ])

def alert_detail_keyboard(alert_id: int) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([
        [
            InlineKeyboardButton("🗑 حذف آلرت",   callback_data=f"del_alert:{alert_id}"),
            InlineKeyboardButton("⬅️ بازگشت",    callback_data="menu_list"),
        ],
    ])

# ─── بررسی دسترسی ────────────────────────────────────────────────────────────

def is_admin(update: Update) -> bool:
    return update.effective_user.id == config.ADMIN_USER_ID

async def is_allowed_group(update: Update) -> bool:
    chat = update.effective_chat
    if chat.type not in (Chat.GROUP, Chat.SUPERGROUP):
        return False
    return await db.is_allowed_group(chat.id)

def is_private_admin(update: Update) -> bool:
    return update.effective_chat.type == Chat.PRIVATE and is_admin(update)

async def can_use_bot(update: Update) -> bool:
    return await is_allowed_group(update) or is_private_admin(update)

async def can_use_callback(update: Update) -> bool:
    query = update.callback_query
    chat  = update.effective_chat
    if chat.type == Chat.PRIVATE and update.effective_user.id == config.ADMIN_USER_ID:
        return True
    return await db.is_allowed_group(chat.id)

# ─── /start ─────────────────────────────────────────────────────────────────

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await can_use_bot(update):
        return

    user  = update.effective_user
    name  = user.first_name or user.username or "معامله‌گر"
    count = await db.count_user_alerts(user.id)
    admin_note = "\n👑 <b>ادمین سیستم</b>" if is_admin(update) else ""

    text = (
        f"سلام <b>{name}</b>! 👋{admin_note}\n\n"
        f"به <b>ZAlert</b> خوش اومدی — ربات آلرت قیمت MT5 🚀\n\n"
        f"⚡️ آلرت‌های فعالت: <b>{count}</b>\n"
        f"📡 وضعیت سرور: <b>آنلاین</b>\n\n"
        f"از منوی پایین شروع کن 👇"
    )
    await update.message.reply_text(text, parse_mode=ParseMode.HTML, reply_markup=main_menu_keyboard())

# ─── /help ──────────────────────────────────────────────────────────────────

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await can_use_bot(update):
        return

    text = (
        "📖 <b>راهنمای ZAlert</b>\n\n"
        "<b>دستورات متنی:</b>\n"
        "• /set SYMBOL PRICE — آلرت جدید\n"
        "  مثال: <code>/set xauusd 3400</code>\n\n"
        "• /price SYMBOL — قیمت لحظه‌ای\n"
        "  مثال: <code>/price eurusd</code>\n\n"
        "• /list — آلرت‌های فعال شما\n"
        "• /delete ID — حذف یک آلرت\n"
        "• /clear — حذف همه آلرت‌ها\n"
        "• /stats — آمار کل سیستم\n"
        "• /history — آلرت‌های تریگر شده\n\n"
        f"⚙️ حداکثر {config.MAX_ALERTS_PER_USER} آلرت فعال\n"
        f"⏱ بررسی هر {config.CHECK_INTERVAL} ثانیه"
    )
    await update.message.reply_text(text, parse_mode=ParseMode.HTML, reply_markup=main_menu_keyboard())

# ─── /set ────────────────────────────────────────────────────────────────────

async def set_alert(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await can_use_bot(update):
        return

    user_id  = update.effective_user.id
    username = update.effective_user.username or update.effective_user.first_name

    if len(context.args) != 2:
        await update.message.reply_text(
            "❌ <b>فرمت نادرست!</b>\n\nاستفاده: <code>/set SYMBOL PRICE</code>\nمثال: <code>/set xauusd 3400</code>",
            parse_mode=ParseMode.HTML
        )
        return

    symbol = context.args[0].upper()
    try:
        target_price = float(context.args[1])
    except ValueError:
        await update.message.reply_text("❌ قیمت باید عدد باشد!", parse_mode=ParseMode.HTML)
        return

    count = await db.count_user_alerts(user_id)
    if count >= config.MAX_ALERTS_PER_USER:
        await update.message.reply_text(
            f"⚠️ به سقف {config.MAX_ALERTS_PER_USER} آلرت رسیدی!\nابتدا یه آلرت حذف کن.",
            parse_mode=ParseMode.HTML
        )
        return

    current_price = mt5.get_price(symbol)
    if current_price is None:
        await update.message.reply_text(
            f"❌ نماد <b>{symbol}</b> یافت نشد.\nنمادها رو چک کن.",
            parse_mode=ParseMode.HTML
        )
        return

    real_symbol = mt5.get_resolved_symbol(symbol) or symbol
    alert_type  = "below" if current_price > target_price else "above"
    alert_id    = await db.add_alert(
        user_id, username, real_symbol, target_price, alert_type,
        group_id=update.effective_chat.id
    )

    diff_pct = abs(current_price - target_price) / current_price * 100
    bar = progress_bar(current_price, target_price, alert_type)

    sym_line = real_symbol if real_symbol == symbol else f"{real_symbol} <i>(از {symbol})</i>"
    text = (
        f"✅ <b>آلرت #{alert_id} ثبت شد!</b>\n\n"
        f"📊 نماد: <b>{sym_line}</b>\n"
        f"💵 قیمت فعلی: <code>{fmt_price(current_price)}</code>\n"
        f"🎯 هدف: <code>{fmt_price(target_price)}</code>\n"
        f"📈 جهت: {type_text(alert_type)}\n"
        f"📏 فاصله: <b>{diff_pct:.2f}%</b>\n"
        f"{bar}\n\n"
        f"⏱ هر {config.CHECK_INTERVAL}ثانیه چک میشه 👀"
    )
    kb = InlineKeyboardMarkup([
        [
            InlineKeyboardButton("📋 لیست آلرت‌ها", callback_data="menu_list"),
            InlineKeyboardButton("🏠 منوی اصلی",    callback_data="back_main"),
        ]
    ])
    await update.message.reply_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)

# ─── /price ──────────────────────────────────────────────────────────────────

async def get_price(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await can_use_bot(update):
        return

    if len(context.args) != 1:
        await update.message.reply_text(
            "❌ استفاده: <code>/price SYMBOL</code>\nمثال: <code>/price xauusd</code>",
            parse_mode=ParseMode.HTML, reply_markup=symbol_keyboard("qprice")
        )
        return

    symbol = context.args[0].upper()
    price  = mt5.get_price(symbol)
    if price is None:
        await update.message.reply_text(f"❌ قیمت <b>{symbol}</b> دریافت نشد.", parse_mode=ParseMode.HTML)
        return

    real_symbol = mt5.get_resolved_symbol(symbol) or symbol
    text = _price_message(real_symbol, price)
    await update.message.reply_text(text, parse_mode=ParseMode.HTML, reply_markup=price_keyboard(real_symbol))

def _price_message(symbol: str, price: float) -> str:
    return (
        f"💰 <b>قیمت لحظه‌ای</b>\n\n"
        f"📊 نماد: <b>{symbol}</b>\n"
        f"💵 قیمت: <code>{fmt_price(price)}</code>\n"
        f"🕐 ساعت: {now_tehran()} (تهران)"
    )

# ─── /list ───────────────────────────────────────────────────────────────────

async def list_alerts(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await can_use_bot(update):
        return

    user_id = update.effective_user.id
    alerts  = await db.get_user_alerts(user_id)

    if not alerts:
        text = "📭 <b>هیچ آلرت فعالی نداری!</b>\nبا دکمه زیر یه آلرت جدید بذار 👇"
        kb   = InlineKeyboardMarkup([[InlineKeyboardButton("🔔 آلرت جدید", callback_data="menu_new_alert")]])
        await update.message.reply_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)
        return

    lines = [f"📋 <b>آلرت‌های فعال تو ({len(alerts)} عدد)</b>\n"]
    for a in alerts:
        cur  = mt5.get_price(a['symbol'])
        bar  = progress_bar(cur, a['target_price'], a['alert_type']) if cur else ""
        diff = f"{abs(cur - a['target_price']) / cur * 100:.2f}%" if cur else "—"
        lines.append(
            f"{'─'*28}\n"
            f"<b>#{a['id']} {a['symbol']}</b>  {type_text(a['alert_type'])}\n"
            f"🎯 هدف: <code>{fmt_price(a['target_price'])}</code>  "
            f"💵 الان: <code>{fmt_price(cur) if cur else '—'}</code>\n"
            f"📏 فاصله: <b>{diff}</b>  {bar}"
        )

    await update.message.reply_text(
        "\n".join(lines),
        parse_mode=ParseMode.HTML,
        reply_markup=alert_list_keyboard(alerts)
    )

# ─── /delete ─────────────────────────────────────────────────────────────────

async def delete_alert(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await can_use_bot(update):
        return

    user_id = update.effective_user.id
    if not context.args:
        await update.message.reply_text("❌ استفاده: <code>/delete ID</code>", parse_mode=ParseMode.HTML)
        return

    try:
        alert_id = int(context.args[0])
    except ValueError:
        await update.message.reply_text("❌ شناسه باید عدد باشد!", parse_mode=ParseMode.HTML)
        return

    deleted = await db.delete_alert(alert_id, user_id)
    if deleted:
        await update.message.reply_text(
            f"🗑 <b>آلرت #{alert_id} حذف شد.</b>",
            parse_mode=ParseMode.HTML, reply_markup=back_main_keyboard()
        )
    else:
        await update.message.reply_text(
            f"❌ آلرت #{alert_id} پیدا نشد یا مال تو نیست.",
            parse_mode=ParseMode.HTML
        )

# ─── /clear ──────────────────────────────────────────────────────────────────

async def clear_alerts(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await can_use_bot(update):
        return

    count = await db.count_user_alerts(update.effective_user.id)
    if count == 0:
        await update.message.reply_text("📭 آلرت فعالی نداری!", parse_mode=ParseMode.HTML)
        return

    text = (
        f"⚠️ <b>مطمئنی؟</b>\n\n"
        f"میخوای <b>{count} آلرت</b> فعالت رو حذف کنی؟\n"
        f"این کار برگشت نداره! 🚨"
    )
    await update.message.reply_text(text, parse_mode=ParseMode.HTML, reply_markup=confirm_clear_keyboard())

# ─── /stats ──────────────────────────────────────────────────────────────────

async def stats(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await can_use_bot(update):
        return

    stats_data = await db.get_stats()
    if not stats_data:
        await update.message.reply_text("📊 هیچ آلرت فعالی وجود ندارد.", reply_markup=back_main_keyboard())
        return

    total = sum(stats_data.values())
    lines = [f"📊 <b>آمار ZAlert</b>\n\n🔢 مجموع آلرت‌های فعال: <b>{total}</b>\n"]
    for sym, cnt in stats_data.items():
        bar = "█" * min(cnt, 10) + "░" * (10 - min(cnt, 10))
        lines.append(f"<code>{sym:<10}</code>  [{bar}]  {cnt}")

    await update.message.reply_text("\n".join(lines), parse_mode=ParseMode.HTML, reply_markup=back_main_keyboard())

# ─── /history ────────────────────────────────────────────────────────────────

async def history(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await can_use_bot(update):
        return

    user_id = update.effective_user.id
    alerts  = await db.get_user_alerts(user_id, include_triggered=True)
    triggered = [a for a in alerts if a.get('triggered')]

    if not triggered:
        await update.message.reply_text(
            "📭 هنوز هیچ آلرتی تریگر نشده.",
            reply_markup=back_main_keyboard()
        )
        return

    lines = [f"🏆 <b>آلرت‌های فعال شده ({len(triggered)} عدد)</b>\n"]
    for a in triggered[-10:]:  # آخرین ۱۰ تا
        lines.append(
            f"{'─'*28}\n"
            f"✅ <b>{a['symbol']}</b>  {type_text(a['alert_type'])}\n"
            f"🎯 هدف: <code>{fmt_price(a['target_price'])}</code>\n"
            f"📅 {a.get('triggered_at', '—')}"
        )

    await update.message.reply_text("\n".join(lines), parse_mode=ParseMode.HTML, reply_markup=back_main_keyboard())

# ─── /status ─────────────────────────────────────────────────────────────────────────

async def server_status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await can_use_bot(update):
        return
    await _send_status(update.message.reply_text)

async def _send_status(reply_fn):
    mt5_ok    = mt5.initialized
    mt5_str   = "🟢 متصل" if mt5_ok else "🔴 قطع"
    try:
        await db.get_stats()
        db_str = "🟢 آنلاین"
    except Exception:
        db_str = "🔴 خطا"
    elapsed    = datetime.now(TEHRAN) - _start_time
    total_s    = int(elapsed.total_seconds())
    h, r       = divmod(total_s, 3600)
    m, s       = divmod(r, 60)
    uptime_str = f"{h}h {m}m {s}s"
    stats_data   = await db.get_stats()
    total_alerts = sum(stats_data.values()) if stats_data else 0
    gold     = mt5.get_price("XAUUSD")
    gold_str = f"<code>{fmt_price(gold)}</code>" if gold else "—"
    text = (
        f"🖥 <b>وضعیت سرور ZAlert</b>\n\n"
        f"{'─'*28}\n"
        f"🔌 MT5: {mt5_str}\n"
        f"🗄 دیتابیس: {db_str}\n"
        f"⏱ آپتایم: <b>{uptime_str}</b>\n"
        f"{'─'*28}\n"
        f"📊 آلرت‌های فعال: <b>{total_alerts}</b>\n"
        f"⏰ بررسی هر: <b>{config.CHECK_INTERVAL}s</b>\n"
        f"🥇 XAUUSD: {gold_str}\n"
        f"{'─'*28}\n"
        f"🕐 سرور: {now_tehran_full()}"
    )
    kb = InlineKeyboardMarkup([[
        InlineKeyboardButton("🔄 بروزرسانی", callback_data="menu_status"),
        InlineKeyboardButton("🏠 منوی اصلی", callback_data="back_main"),
    ]])
    await reply_fn(text, parse_mode=ParseMode.HTML, reply_markup=kb)


# ─── گزارش صبحگاهی ───────────────────────────────────────────────────────

async def morning_report(context: ContextTypes.DEFAULT_TYPE):
    """گزارش صبحگاهی — هر روز ساعت ۸ صبح تهران (04:30 UTC)"""
    groups = await db.get_all_groups()
    if not groups:
        return
    stats_data   = await db.get_stats()
    total_alerts = sum(stats_data.values()) if stats_data else 0
    try:
        events      = await get_today_events(user_tz='Asia/Tehran')
        high_events = [e for e in events if e['impact'] == 'high']
    except Exception:
        events = high_events = []
    day_names = {0: 'دوشنبه', 1: 'سه‌شنبه', 2: 'چهارشنبه',
                 3: 'پنج‌شنبه', 4: 'جمعه', 5: 'شنبه', 6: 'یکشنبه'}
    now_th  = datetime.now(TEHRAN)
    weekday = day_names.get(now_th.weekday(), '')
    today   = now_th.strftime('%Y-%m-%d')
    lines = [
        f"🌅 <b>گزارش صبحگاهی ZAlert</b>\n",
        f"📅 {weekday} — {today}\n",
        f"{'─'*28}",
        f"📊 آلرت‌های فعال سیستم: <b>{total_alerts}</b>",
    ]
    if stats_data:
        lines.append("🔝 پرطرفدارترین نمادها:")
        for sym, cnt in list(stats_data.items())[:3]:
            lines.append(f"  • {sym}: {cnt} آلرت")
    lines.append(f"{'─'*28}")
    if high_events:
        lines.append(f"\n🔴 <b>رویدادهای مهم امروز ({len(high_events)} رویداد):</b>")
        for e in high_events[:6]:
            lines.append(f"  🔴 {e['time']} — <b>{e['title']}</b> ({e['currency']})")
    else:
        lines.append("\n✅ امروز رویداد High Impact نداریم — بازار آرومه!")
    prices = []
    for _, sym in POPULAR_SYMBOLS[:4]:
        p = mt5.get_price(sym)
        if p:
            prices.append(f"  <code>{sym:<10}</code> {fmt_price(p)}")
    if prices:
        lines += [f"\n{'─'*28}", "💹 قیمت لحظه‌ای:"] + prices
    lines += [f"\n{'─'*28}", "💡 معامله خوب! 🚀"]
    text = "\n".join(lines)
    for group in groups:
        try:
            await context.bot.send_message(
                chat_id=group['group_id'], text=text, parse_mode=ParseMode.HTML
            )
        except Exception as e:
            print(f"[Morning] خطا در ارسال به {group['group_id']}: {e}")


# ─── نوتیف تقویم ──────────────────────────────────────────────────────────────────

async def calendar_notifier(context: ContextTypes.DEFAULT_TYPE):
    """هر ۵ دقیقه — ۳۰ دقیقه قبل از High Impact هشدار میده"""
    global _sent_calendar_notifs
    groups = await db.get_all_groups()
    if not groups:
        return
    try:
        events = await get_high_impact_events(user_tz='Asia/Tehran')
    except Exception as e:
        print(f"[CalNotif] خطا: {e}")
        return
    from dateutil import parser as dp
    now_utc = datetime.utcnow().replace(tzinfo=pytz.utc)
    for e in events:
        if not e.get('time_utc'):
            continue
        key = e['id']
        if key in _sent_calendar_notifs:
            continue
        try:
            event_utc = dp.parse(e['time_utc'])
            if not event_utc.tzinfo:
                event_utc = event_utc.replace(tzinfo=pytz.utc)
        except Exception:
            continue
        diff_min = (event_utc - now_utc).total_seconds() / 60
        if 25 <= diff_min <= 35:
            _sent_calendar_notifs.add(key)
            et = event_utc.astimezone(TEHRAN).strftime('%H:%M')
            text = (
                f"📅 <b>هشدار تقویم اقتصادی!</b>\n\n"
                f"🔴 <b>{e['title']}</b>\n"
                f"🌍 کشور: <b>{e['currency']}</b>\n"
                f"🕐 ساعت: <b>{et}</b> (تهران)\n"
                f"⏰ تا شروع: <b>~۳۰ دقیقه</b>"
            )
            if e.get('forecast') or e.get('previous'):
                text += f"\n📊 پیش‌بینی: <b>{e.get('forecast','—')}</b>  |قبلی: <b>{e.get('previous','—')}</b>"
            text += "\n\n⚠️ مراقب نوسانات باشید!"
            for group in groups:
                try:
                    await context.bot.send_message(
                        chat_id=group['group_id'], text=text, parse_mode=ParseMode.HTML
                    )
                except Exception as ex:
                    print(f"[CalNotif] خطا {group['group_id']}: {ex}")
        elif diff_min < -120:
            _sent_calendar_notifs.discard(key)



# ─── دستورات ادمین ───────────────────────────────────────────────────────────

async def add_group(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        return
    chat = update.effective_chat
    if chat.type not in (Chat.GROUP, Chat.SUPERGROUP):
        await update.message.reply_text("❌ داخل گروه استفاده کن.")
        return
    title = chat.title or str(chat.id)
    await db.add_group(chat.id, title)
    await update.message.reply_text(
        f"✅ گروه «{title}» مجاز شد.\n🆔 <code>{chat.id}</code>",
        parse_mode=ParseMode.HTML
    )

async def remove_group(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        return
    chat = update.effective_chat
    if chat.type in (Chat.GROUP, Chat.SUPERGROUP):
        group_id = chat.id
    else:
        if not context.args:
            await update.message.reply_text("❌ /removegroup GROUP_ID")
            return
        try:
            group_id = int(context.args[0])
        except ValueError:
            await update.message.reply_text("❌ آیدی باید عدد باشد!")
            return
    removed = await db.remove_group(group_id)
    if removed:
        await update.message.reply_text("✅ گروه حذف شد.")
    else:
        await update.message.reply_text("❌ گروه در لیست نبود.")

async def list_groups(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        return
    groups = await db.get_all_groups()
    if not groups:
        await update.message.reply_text("📭 هیچ گروه مجازی ثبت نشده.")
        return
    lines = ["📋 <b>گروه‌های مجاز:</b>\n"]
    for g in groups:
        lines.append(f"• <b>{g['group_title']}</b>\n  🆔 <code>{g['group_id']}</code>")
    await update.message.reply_text("\n".join(lines), parse_mode=ParseMode.HTML)

# ─── Callback Handlers ───────────────────────────────────────────────────────

async def callback_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    if not await can_use_callback(update):
        await query.answer("⛔️ دسترسی ندارید.", show_alert=True)
        return

    data    = query.data
    user_id = update.effective_user.id

    # ── منوی اصلی ────────────────────────────────────────────────────────
    if data == "back_main":
        name  = update.effective_user.first_name or "معامله‌گر"
        count = await db.count_user_alerts(user_id)
        text  = (
            f"🏠 <b>منوی اصلی</b>\n\n"
            f"سلام <b>{name}</b>!\n"
            f"⚡️ آلرت‌های فعال: <b>{count}</b>"
        )
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=main_menu_keyboard())

    # ── آلرت جدید — انتخاب نماد ──────────────────────────────────────────
    elif data == "menu_new_alert":
        text = (
            "🔔 <b>آلرت جدید</b>\n\n"
            "یه نماد انتخاب کن یا مستقیم بنویس:\n"
            "<code>/set SYMBOL PRICE</code>"
        )
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=symbol_keyboard("newalert"))

    # ── انتخاب نماد برای آلرت ────────────────────────────────────────────
    elif data.startswith("newalert:"):
        symbol = data.split(":", 1)[1]
        price  = mt5.get_price(symbol)
        if price is None:
            await query.answer("❌ قیمت دریافت نشد.", show_alert=True)
            return
        real_symbol = mt5.get_resolved_symbol(symbol) or symbol
        text = (
            f"💰 <b>{real_symbol}</b> = <code>{fmt_price(price)}</code>\n\n"
            f"برای ثبت آلرت، قیمت هدفت رو بنویس:\n"
            f"<code>/set {real_symbol} PRICE</code>"
        )
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=price_keyboard(real_symbol))

    # ── لیست آلرت‌ها ─────────────────────────────────────────────────────
    elif data == "menu_list":
        alerts = await db.get_user_alerts(user_id)
        if not alerts:
            text = "📭 <b>آلرت فعالی نداری!</b>\nبا دکمه زیر یه آلرت بذار 👇"
            kb   = InlineKeyboardMarkup([
                [InlineKeyboardButton("🔔 آلرت جدید", callback_data="menu_new_alert")],
                [InlineKeyboardButton("🏠 منوی اصلی", callback_data="back_main")],
            ])
            await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)
            return

        lines = [f"📋 <b>آلرت‌های فعال ({len(alerts)} عدد)</b>\n"]
        for a in alerts:
            cur  = mt5.get_price(a['symbol'])
            diff = f"{abs(cur - a['target_price']) / cur * 100:.2f}%" if cur else "—"
            lines.append(
                f"<b>#{a['id']} {a['symbol']}</b>  "
                f"{type_text(a['alert_type'])} → <code>{fmt_price(a['target_price'])}</code>  "
                f"({diff})"
            )

        await query.edit_message_text(
            "\n".join(lines),
            parse_mode=ParseMode.HTML,
            reply_markup=alert_list_keyboard(alerts)
        )

    # ── جزئیات یه آلرت ───────────────────────────────────────────────────
    elif data.startswith("view_alert:"):
        alert_id = int(data.split(":", 1)[1])
        alert    = await db.get_alert_by_id(alert_id)
        if not alert or alert.get('user_id') != user_id:
            await query.answer("❌ آلرت پیدا نشد.", show_alert=True)
            return
        cur  = mt5.get_price(alert['symbol'])
        bar  = progress_bar(cur, alert['target_price'], alert['alert_type']) if cur else ""
        diff = f"{abs(cur - alert['target_price']) / cur * 100:.2f}%" if cur else "—"
        text = (
            f"🔍 <b>جزئیات آلرت #{alert_id}</b>\n\n"
            f"📊 نماد: <b>{alert['symbol']}</b>\n"
            f"🎯 هدف: <code>{fmt_price(alert['target_price'])}</code>\n"
            f"💵 قیمت فعلی: <code>{fmt_price(cur) if cur else '—'}</code>\n"
            f"📈 جهت: {type_text(alert['alert_type'])}\n"
            f"📏 فاصله: <b>{diff}</b>\n"
            f"{bar}\n"
            f"📅 ثبت: {alert.get('created_at', '—')}"
        )
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=alert_detail_keyboard(alert_id))

    # ── حذف یه آلرت ──────────────────────────────────────────────────────
    elif data.startswith("del_alert:"):
        alert_id = int(data.split(":", 1)[1])
        deleted  = await db.delete_alert(alert_id, user_id)
        if deleted:
            await query.answer(f"✅ آلرت #{alert_id} حذف شد.", show_alert=True)
            # بروز کردن لیست
            alerts = await db.get_user_alerts(user_id)
            if not alerts:
                await query.edit_message_text(
                    "📭 <b>همه آلرت‌ها حذف شدن!</b>",
                    parse_mode=ParseMode.HTML,
                    reply_markup=InlineKeyboardMarkup([
                        [InlineKeyboardButton("🔔 آلرت جدید", callback_data="menu_new_alert")],
                        [InlineKeyboardButton("🏠 منوی اصلی", callback_data="back_main")],
                    ])
                )
            else:
                lines = [f"📋 <b>آلرت‌های فعال ({len(alerts)} عدد)</b>\n"]
                for a in alerts:
                    cur  = mt5.get_price(a['symbol'])
                    diff = f"{abs(cur - a['target_price']) / cur * 100:.2f}%" if cur else "—"
                    lines.append(
                        f"<b>#{a['id']} {a['symbol']}</b>  "
                        f"{type_text(a['alert_type'])} → <code>{fmt_price(a['target_price'])}</code>  "
                        f"({diff})"
                    )
                await query.edit_message_text(
                    "\n".join(lines),
                    parse_mode=ParseMode.HTML,
                    reply_markup=alert_list_keyboard(alerts)
                )
        else:
            await query.answer("❌ حذف ناموفق!", show_alert=True)

    # ── تأیید حذف همه ────────────────────────────────────────────────────
    elif data == "clear_confirm":
        count = await db.count_user_alerts(user_id)
        text  = (
            f"⚠️ <b>تأیید حذف همه</b>\n\n"
            f"میخوای <b>{count} آلرت</b> فعالت رو پاک کنی؟\n"
            f"این کار برگشت نداره! 🚨"
        )
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=confirm_clear_keyboard())

    elif data == "clear_do":
        count = await db.clear_user_alerts(user_id)
        text  = f"🗑 <b>{count} آلرت حذف شد.</b>\n\nخیالت راحت! 😌"
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=back_main_keyboard())

    # ── قیمت لحظه‌ای — انتخاب نماد ──────────────────────────────────────
    elif data == "menu_price":
        text = "💰 <b>قیمت لحظه‌ای</b>\n\nنماد مورد نظرت رو انتخاب کن:"
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=symbol_keyboard("qprice"))

    elif data.startswith("qprice:"):
        symbol = data.split(":", 1)[1]
        price  = mt5.get_price(symbol)
        if price is None:
            await query.answer(f"❌ قیمت {symbol} دریافت نشد.", show_alert=True)
            return
        real_symbol = mt5.get_resolved_symbol(symbol) or symbol
        await query.edit_message_text(
            _price_message(real_symbol, price),
            parse_mode=ParseMode.HTML,
            reply_markup=price_keyboard(real_symbol)
        )

    elif data.startswith("refresh_price:"):
        symbol = data.split(":", 1)[1]
        price  = mt5.get_price(symbol)
        if price is None:
            await query.answer("❌ قیمت دریافت نشد.", show_alert=True)
            return
        await query.edit_message_text(
            _price_message(symbol, price),
            parse_mode=ParseMode.HTML,
            reply_markup=price_keyboard(symbol)
        )
        await query.answer("✅ بروز شد!")

    elif data.startswith("set_for:"):
        symbol = data.split(":", 1)[1]
        price  = mt5.get_price(symbol)
        text   = (
            f"🔔 <b>آلرت برای {symbol}</b>\n\n"
            f"قیمت فعلی: <code>{fmt_price(price) if price else '—'}</code>\n\n"
            f"قیمت هدف رو بنویس:\n"
            f"<code>/set {symbol} PRICE</code>"
        )
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=back_main_keyboard())

    # ── تقویم امروز ───────────────────────────────────────────────────────
    elif data == "menu_calendar":
        await query.edit_message_text(
            "⏳ در حال دریافت تقویم...",
            parse_mode=ParseMode.HTML
        )
        try:
            events = await get_today_events()
            if not events:
                text = "📅 <b>تقویم امروز</b>\n\nامروز رویداد اقتصادی نداریم. ✅"
            else:
                impact_emoji = {"high": "🔴", "medium": "🟡", "low": "🟢", "holiday": "🏖", "non_economic": "⚪️"}
                lines = [f"📅 <b>رویدادهای اقتصادی امروز ({len(events)} رویداد)</b>\n"]
                for e in events[:15]:
                    emoji = impact_emoji.get(e['impact'], "⚪️")
                    lines.append(
                        f"{emoji} <b>{e['title']}</b>\n"
                        f"  🕐 {e['time']}  🌍 {e['currency']}"
                        + (f"\n  📊 قبلی: {e['previous']}  پیش‌بینی: {e['forecast']}" if e['previous'] or e['forecast'] else "")
                    )
                text = "\n\n".join(lines)
        except Exception as ex:
            text = f"❌ خطا در دریافت تقویم:\n{ex}"

        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=back_main_keyboard())

    # ── آمار کل ───────────────────────────────────────────────────────────
    elif data == "menu_stats":
        stats_data = await db.get_stats()
        if not stats_data:
            text = "📊 <b>آمار</b>\n\nهیچ آلرت فعالی وجود ندارد."
        else:
            total = sum(stats_data.values())
            lines = [f"📊 <b>آمار سیستم</b>\n\n🔢 مجموع آلرت فعال: <b>{total}</b>\n"]
            for sym, cnt in stats_data.items():
                bar = "█" * min(cnt, 10) + "░" * (10 - min(cnt, 10))
                lines.append(f"<code>{sym:<10}</code>  [{bar}]  {cnt}")
            text = "\n".join(lines)
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=back_main_keyboard())

    # ── پروفایل کاربر ────────────────────────────────────────────────────
    elif data == "menu_profile":
        all_alerts = await db.get_user_alerts(user_id, include_triggered=True)
        active     = [a for a in all_alerts if not a.get('triggered')]
        triggered  = [a for a in all_alerts if a.get('triggered')]
        user       = update.effective_user
        name       = user.first_name or user.username or "—"

        symbols_used = list({a['symbol'] for a in all_alerts})[:5]

        text = (
            f"👤 <b>پروفایل تو</b>\n\n"
            f"🙋 نام: <b>{name}</b>\n"
            f"🆔 شناسه: <code>{user_id}</code>\n\n"
            f"📊 <b>آمار آلرت‌ها:</b>\n"
            f"  ⚡️ فعال: <b>{len(active)}</b> / {config.MAX_ALERTS_PER_USER}\n"
            f"  ✅ تریگر شده: <b>{len(triggered)}</b>\n"
            f"  📈 کل آلرت‌ها: <b>{len(all_alerts)}</b>\n\n"
            + (f"🎯 <b>نمادهای اخیر:</b> {', '.join(symbols_used)}\n" if symbols_used else "")
        )
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=back_main_keyboard())

    # ── وضعیت سرور ────────────────────────────────────────────────
    elif data == "menu_status":
        await query.edit_message_text("⏳ در حال بررسی...", parse_mode=ParseMode.HTML)
        await _send_status(query.edit_message_text)

# ─── چک کردن آلرت‌ها (پس‌زمینه) ─────────────────────────────────────────────

async def check_alerts(context: ContextTypes.DEFAULT_TYPE):
    alerts = await db.get_all_active_alerts()

    for alert in alerts:
        symbol       = alert['symbol']
        target_price = alert['target_price']
        alert_type   = alert['alert_type']
        group_id     = alert['group_id']

        current_price = mt5.get_price(symbol)
        if current_price is None:
            continue

        triggered = (
            (alert_type == "below" and current_price <= target_price) or
            (alert_type == "above" and current_price >= target_price)
        )

        if not triggered:
            continue

        username     = alert['username']
        user_mention = f"@{username}" if username else f"کاربر {alert['user_id']}"
        diff_pct     = abs(current_price - target_price) / target_price * 100
        direction    = "⬇️ کاهش" if alert_type == "below" else "⬆️ افزایش"

        text = (
            f"🔔 <b>آلرت #{alert['id']} فعال شد!</b>\n\n"
            f"👤 {user_mention}\n\n"
            f"📊 نماد: <b>{symbol}</b>\n"
            f"🎯 هدف: <code>{fmt_price(target_price)}</code>\n"
            f"💵 قیمت فعلی: <code>{fmt_price(current_price)}</code>\n"
            f"📈 {direction} — <b>{diff_pct:.2f}%</b> تغییر\n"
            f"🕐 {now_tehran_full()}\n\n"
            f"✅ هدف گرفته شد! 🎯"
        )
        try:
            await context.bot.send_message(
                chat_id=group_id, text=text, parse_mode=ParseMode.HTML
            )
            await db.mark_triggered(alert['id'])

            push_tokens = await db.get_push_tokens(alert['user_id'])
            if push_tokens:
                sent = await send_alert_triggered_push(
                    tokens=push_tokens,
                    symbol=symbol,
                    target_price=target_price,
                    current_price=current_price,
                    alert_type=alert_type,
                    alert_id=alert['id']
                )
                print(f"[Alert] push sent={sent}/{len(push_tokens)}")
        except Exception as e:
            print(f"[Alert] خطا در ارسال: {e}")

# ─── main ─────────────────────────────────────────────────────────────────────

def main():
    if not mt5.initialize():
        print("❌ خطا در اتصال به MT5. لطفاً MT5 را باز کنید.")
        return

    app = Application.builder().token(config.BOT_TOKEN).build()

    # دستورات عمومی
    app.add_handler(CommandHandler("start",   start))
    app.add_handler(CommandHandler("help",    help_command))
    app.add_handler(CommandHandler("set",     set_alert))
    app.add_handler(CommandHandler("price",   get_price))
    app.add_handler(CommandHandler("list",    list_alerts))
    app.add_handler(CommandHandler("delete",  delete_alert))
    app.add_handler(CommandHandler("clear",   clear_alerts))
    app.add_handler(CommandHandler("stats",   stats))
    app.add_handler(CommandHandler("history", history))
    app.add_handler(CommandHandler("status",  server_status))

    # دستورات ادمین
    app.add_handler(CommandHandler("addgroup",    add_group))
    app.add_handler(CommandHandler("removegroup", remove_group))
    app.add_handler(CommandHandler("groups",      list_groups))

    # callback buttons
    app.add_handler(CallbackQueryHandler(callback_handler))

    # تسک پس‌زمینه
    import datetime as dt
    app.job_queue.run_repeating(check_alerts,      interval=config.CHECK_INTERVAL, first=10)
    app.job_queue.run_repeating(calendar_notifier, interval=300, first=60)          # هر ۵ دقیقه
    app.job_queue.run_daily(morning_report,        time=dt.time(4, 30, tzinfo=pytz.utc))  # ۸ صبح تهران
    app.job_queue.run_repeating(check_alerts, interval=config.CHECK_INTERVAL, first=10)

    # API
    set_bot_app(app)

    def run_api():
        uvicorn.run(api, host=config.API_HOST, port=config.API_PORT, log_level="error")

    threading.Thread(target=run_api, daemon=True).start()

    print("✅ ZAlert v2 شروع به کار کرد...")
    print(f"⏱ چک آلرت هر {config.CHECK_INTERVAL}ثانیه")
    print(f"🌐 API: http://{config.API_HOST}:{config.API_PORT}")

    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n🛑 ربات متوقف شد")
    finally:
        mt5.shutdown()
