import asyncio
import threading
import uvicorn
from telegram import Update, Chat
from telegram.ext import Application, CommandHandler, ContextTypes, MessageHandler, filters
from datetime import datetime
import pytz
import config
from database import Database
from mt5_handler import MT5Handler
from api import api, set_bot_app
from push import send_alert_triggered_push

# ایجاد نمونه‌ها
db = Database()
mt5 = MT5Handler()

# ── بررسی دسترسی ─────────────────────────────────────────────────────

def is_admin(update: Update) -> bool:
    """بررسی ادمین بودن فرستنده"""
    return update.effective_user.id == config.ADMIN_USER_ID

def is_allowed_group(update: Update) -> bool:
    """بررسی اینکه پیام از یک گروه مجاز آمده"""
    chat = update.effective_chat
    if chat.type not in (Chat.GROUP, Chat.SUPERGROUP):
        return False
    return db.is_allowed_group(chat.id)

def is_private_admin(update: Update) -> bool:
    """ادمین در DM ربات"""
    return (update.effective_chat.type == Chat.PRIVATE and is_admin(update))

def can_use_bot(update: Update) -> bool:
    """کاربر میتواند از ربات استفاده کند (گروه مجاز یا ادمین در DM)"""
    return is_allowed_group(update) or is_private_admin(update)

# ── دستورات ادمین ────────────────────────────────────────────────────

async def add_group(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    ادمین این دستور را داخل گروه میزند تا آن گروه مجاز شود.
    /addgroup
    """
    if not is_admin(update):
        return

    chat = update.effective_chat
    if chat.type not in (Chat.GROUP, Chat.SUPERGROUP):
        await update.message.reply_text("❌ این دستور باید داخل یک گروه استفاده شود.")
        return

    group_title = chat.title or str(chat.id)
    db.add_group(chat.id, group_title)
    await update.message.reply_text(
        f"✅ گروه «{group_title}» به لیست مجاز اضافه شد.\n"
        f"🆔 آیدی گروه: <code>{chat.id}</code>",
        parse_mode="HTML"
    )

async def remove_group(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    حذف گروه از لیست مجاز.
    میتوان داخل گروه زد یا ادمین در DM بنویسد: /removegroup GROUP_ID
    """
    if not is_admin(update):
        return

    chat = update.effective_chat

    # اگر داخل گروه زده شده
    if chat.type in (Chat.GROUP, Chat.SUPERGROUP):
        group_id = chat.id
        group_title = chat.title or str(chat.id)
    else:
        # در DM باید آیدی گروه بدهد
        if not context.args:
            await update.message.reply_text(
                "❌ در DM باید آیدی گروه را بدهید:\n/removegroup GROUP_ID"
            )
            return
        try:
            group_id = int(context.args[0])
            group_title = str(group_id)
        except ValueError:
            await update.message.reply_text("❌ آیدی گروه باید عدد باشد!")
            return

    removed = db.remove_group(group_id)
    if removed:
        await update.message.reply_text(f"✅ گروه «{group_title}» از لیست مجاز حذف شد.")
    else:
        await update.message.reply_text("❌ این گروه در لیست مجاز نبود.")

async def list_groups(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    لیست گروه‌های مجاز — فقط ادمین در DM
    /groups
    """
    if not is_admin(update):
        return

    groups = db.get_all_groups()
    if not groups:
        await update.message.reply_text("📭 هیچ گروه مجازی ثبت نشده.")
        return

    lines = ["📋 گروه‌های مجاز:\n"]
    for g in groups:
        lines.append(f"• {g['group_title']}\n  🆔 <code>{g['group_id']}</code>\n  📅 {g['added_at']}\n")
    await update.message.reply_text("\n".join(lines), parse_mode="HTML")

# ── دستورات عمومی ────────────────────────────────────────────────────

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /start"""
    if not can_use_bot(update):
        return

    is_adm = is_admin(update)
    admin_section = """
👑 دستورات ادمین:
/addgroup - مجاز کردن این گروه
/removegroup [ID] - حذف گروه از لیست مجاز
/groups - لیست گروه‌های مجاز
""" if is_adm else ""

    message = f"""
🤖 ربات آلرت قیمت MT5

📋 دستورات:
/set SYMBOL PRICE - تنظیم آلرت
/price SYMBOL - دریافت قیمت فعلی
/list - لیست آلرت‌های شما
/delete ID - حذف یک آلرت
/clear - حذف تمام آلرت‌ها
/stats - آمار کل آلرت‌ها
/help - راهنما
{admin_section}
مثال:
/set xauusd 5100
/price eurusd
"""
    await update.message.reply_text(message)

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /help"""
    if not can_use_bot(update):
        return

    message = """
📖 راهنمای کامل ربات

🔔 تنظیم آلرت:
/set SYMBOL PRICE
مثال: /set xauusd 5100

ربات خودکار تشخیص می‌دهد:
• اگر قیمت فعلی بالاتر از هدف باشد → آلرت برای پایین آمدن
• اگر قیمت فعلی پایین‌تر از هدف باشد → آلرت برای بالا رفتن

💰 دریافت قیمت:
/price SYMBOL
مثال: /price eurusd

📋 مدیریت آلرت‌ها:
/list - مشاهده آلرت‌های فعال شما
/delete ID - حذف آلرت با شناسه مشخص
/clear - حذف تمام آلرت‌های شما

📊 آمار:
/stats - مشاهده آمار کل آلرت‌ها

⚠️ نکات:
• نماد را می‌توانید با حروف کوچک یا بزرگ بنویسید
• حداکثر {MAX_ALERTS_PER_USER} آلرت فعال برای هر کاربر
• آلرت‌ها هر {CHECK_INTERVAL} ثانیه چک می‌شوند
""".format(MAX_ALERTS_PER_USER=config.MAX_ALERTS_PER_USER, CHECK_INTERVAL=config.CHECK_INTERVAL)

    await update.message.reply_text(message)

async def set_alert(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /set"""
    if not can_use_bot(update):
        return

    user_id = update.effective_user.id
    username = update.effective_user.username or update.effective_user.first_name

    if len(context.args) != 2:
        await update.message.reply_text("❌ فرمت نادرست!\n\nاستفاده: /set SYMBOL PRICE\nمثال: /set xauusd 5100")
        return

    symbol = context.args[0].upper()

    try:
        target_price = float(context.args[1])
    except ValueError:
        await update.message.reply_text("❌ قیمت باید عدد باشد!")
        return

    user_alert_count = db.count_user_alerts(user_id)
    if user_alert_count >= config.MAX_ALERTS_PER_USER:
        await update.message.reply_text(f"❌ شما حداکثر {config.MAX_ALERTS_PER_USER} آلرت فعال می‌توانید داشته باشید!")
        return

    current_price = mt5.get_price(symbol)
    if current_price is None:
        await update.message.reply_text(f"❌ خطا در دریافت قیمت {symbol}\n\nلطفاً نماد را بررسی کنید.")
        return

    # نماد واقعی که MT5 استفاده کرد
    real_symbol = mt5.get_resolved_symbol(symbol) or symbol

    if current_price > target_price:
        alert_type = "below"
        type_text = "⬇️ پایین آمدن"
    else:
        alert_type = "above"
        type_text = "⬆️ بالا رفتن"

    alert_id = db.add_alert(user_id, username, real_symbol, target_price, alert_type,
                            group_id=update.effective_chat.id)

    # نمایش نماد resolve شده اگه با ورودی فرق داشت
    symbol_display = f"{real_symbol}" if real_symbol == symbol else f"{real_symbol} (از {symbol})"

    message = f"""
✅ آلرت با موفقیت ثبت شد!

🆔 شناسه: {alert_id}
📊 نماد: {symbol_display}
🎯 قیمت هدف: {target_price}
💵 قیمت فعلی: {current_price}
📈 نوع: {type_text}
👤 کاربر: @{username}
"""
    await update.message.reply_text(message)

async def get_price(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /price"""
    if not can_use_bot(update):
        return

    if len(context.args) != 1:
        await update.message.reply_text("❌ فرمت نادرست!\n\nاستفاده: /price SYMBOL\nمثال: /price xauusd")
        return

    symbol = context.args[0].upper()
    price = mt5.get_price(symbol)

    if price is None:
        await update.message.reply_text(f"❌ خطا در دریافت قیمت {symbol}")
        return

    real_symbol = mt5.get_resolved_symbol(symbol) or symbol
    tehran_tz = pytz.timezone('Asia/Tehran')
    current_time = datetime.now(tehran_tz).strftime('%H:%M:%S')

    symbol_display = real_symbol if real_symbol == symbol else f"{real_symbol} (از {symbol})"

    await update.message.reply_text(f"""
💰 قیمت فعلی

📊 نماد: {symbol_display}
💵 قیمت: {price}
🕐 ساعت: {current_time} (تهران)
""")

async def list_alerts(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /list"""
    if not can_use_bot(update):
        return

    user_id = update.effective_user.id
    alerts = db.get_user_alerts(user_id)

    if not alerts:
        await update.message.reply_text("📭 شما هیچ آلرت فعالی ندارید.")
        return

    message = "📋 آلرت‌های فعال شما:\n\n"
    for alert in alerts:
        type_emoji = "⬇️" if alert['alert_type'] == "below" else "⬆️"
        message += f"🆔 {alert['id']} | {alert['symbol']} | {type_emoji} {alert['target_price']}\n"
        message += f"   📅 {alert['created_at']}\n\n"
    message += f"📊 مجموع: {len(alerts)} آلرت"

    await update.message.reply_text(message)

async def delete_alert(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /delete"""
    if not can_use_bot(update):
        return

    user_id = update.effective_user.id

    if len(context.args) != 1:
        await update.message.reply_text("❌ فرمت نادرست!\n\nاستفاده: /delete ID\nمثال: /delete 5")
        return

    try:
        alert_id = int(context.args[0])
    except ValueError:
        await update.message.reply_text("❌ شناسه آلرت باید عدد باشد!")
        return

    deleted = db.delete_alert(alert_id, user_id)
    if deleted:
        await update.message.reply_text(f"✅ آلرت {alert_id} حذف شد.")
    else:
        await update.message.reply_text(f"❌ آلرت {alert_id} یافت نشد یا متعلق به شما نیست!")

async def clear_alerts(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /clear"""
    if not can_use_bot(update):
        return

    user_id = update.effective_user.id
    count = db.clear_user_alerts(user_id)

    if count > 0:
        await update.message.reply_text(f"✅ {count} آلرت حذف شد.")
    else:
        await update.message.reply_text("📭 شما هیچ آلرت فعالی ندارید.")

async def stats(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /stats"""
    if not can_use_bot(update):
        return

    stats_data = db.get_stats()
    if not stats_data:
        await update.message.reply_text("📊 هیچ آلرت فعالی وجود ندارد.")
        return

    message = "📊 آمار آلرت‌های فعال:\n\n"
    total = 0
    for symbol, count in stats_data.items():
        message += f"📈 {symbol}: {count} آلرت\n"
        total += count
    message += f"\n🔢 مجموع کل: {total} آلرت"

    await update.message.reply_text(message)

# ── چک کردن آلرت‌ها (پس‌زمینه) ──────────────────────────────────────

async def check_alerts(context: ContextTypes.DEFAULT_TYPE):
    """چک کردن آلرت‌ها هر CHECK_INTERVAL ثانیه"""
    alerts = db.get_all_active_alerts()

    for alert in alerts:
        symbol = alert['symbol']
        target_price = alert['target_price']
        alert_type = alert['alert_type']
        group_id = alert['group_id']

        current_price = mt5.get_price(symbol)
        if current_price is None:
            continue

        triggered = False
        if alert_type == "below" and current_price <= target_price:
            triggered = True
        elif alert_type == "above" and current_price >= target_price:
            triggered = True

        if triggered:
            tehran_tz = pytz.timezone('Asia/Tehran')
            current_time = datetime.now(tehran_tz).strftime('%Y-%m-%d %H:%M:%S')

            username = alert['username']
            user_mention = f"@{username}" if username else f"کاربر {alert['user_id']}"
            type_text = "⬇️ پایین آمد" if alert_type == "below" else "⬆️ بالا رفت"

            message = f"""
🔔 آلرت فعال شد!

{user_mention}

📊 نماد: {symbol}
🎯 قیمت هدف: {target_price}
💵 قیمت فعلی: {current_price}
📈 {type_text} به هدف رسید!
🕐 زمان: {current_time}
"""
            try:
                await context.bot.send_message(chat_id=group_id, text=message)
                db.mark_triggered(alert['id'])

                # ارسال push notification به همه دستگاه‌های کاربر
                push_tokens = db.get_push_tokens(alert['user_id'])
                if push_tokens:
                    await send_alert_triggered_push(
                        tokens=push_tokens,
                        symbol=symbol,
                        target_price=target_price,
                        current_price=current_price,
                        alert_type=alert_type,
                        alert_id=alert['id']
                    )
            except Exception as e:
                print(f"خطا در ارسال پیام آلرت: {e}")

# ── اجرا ─────────────────────────────────────────────────────────────

def main():
    if not mt5.initialize():
        print("❌ خطا در اتصال به MT5. لطفاً MT5 را باز کنید.")
        return

    application = Application.builder().token(config.BOT_TOKEN).build()

    # دستورات عمومی
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("help", help_command))
    application.add_handler(CommandHandler("set", set_alert))
    application.add_handler(CommandHandler("price", get_price))
    application.add_handler(CommandHandler("list", list_alerts))
    application.add_handler(CommandHandler("delete", delete_alert))
    application.add_handler(CommandHandler("clear", clear_alerts))
    application.add_handler(CommandHandler("stats", stats))

    # دستورات ادمین
    application.add_handler(CommandHandler("addgroup", add_group))
    application.add_handler(CommandHandler("removegroup", remove_group))
    application.add_handler(CommandHandler("groups", list_groups))

    # تسک پس‌زمینه
    job_queue = application.job_queue
    job_queue.run_repeating(check_alerts, interval=config.CHECK_INTERVAL, first=10)

    # معرفی ربات به API
    set_bot_app(application)

    # اجرای API در یه thread جداگانه
    def run_api():
        uvicorn.run(
            api,
            host=config.API_HOST,
            port=config.API_PORT,
            log_level="warning"
        )

    api_thread = threading.Thread(target=run_api, daemon=True)
    api_thread.start()

    print("✅ ربات شروع به کار کرد...")
    print(f"📊 چک کردن آلرت‌ها هر {config.CHECK_INTERVAL} ثانیه")
    print(f"👑 ادمین: {config.ADMIN_USER_ID}")
    print(f"🌐 API در حال اجرا: http://{config.API_HOST}:{config.API_PORT}")
    print(f"📖 مستندات API: http://127.0.0.1:{config.API_PORT}/docs")

    application.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n🛑 ربات متوقف شد")
    finally:
        mt5.shutdown()
