"""
UserHandlers — /start, /help.
"""
from telegram import Update
from telegram.constants import ParseMode
from telegram.ext import ContextTypes

import config
from .base   import BaseHandler
from keyboards import KeyboardFactory


class UserHandlers(BaseHandler):
    """Informational commands available to all allowed users."""

    async def start(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not await self.can_use(update):
            return

        user  = update.effective_user
        name  = user.first_name or user.username or "معامله‌گر"
        count = await self.db.count_user_alerts(user.id)
        adm   = "\n👑 <b>ادمین سیستم</b>" if self._is_admin(update) else ""

        self.log.info("start: user=%s id=%s", name, user.id)
        await update.message.reply_text(
            f"سلام <b>{name}</b>! 👋{adm}\n\n"
            f"به <b>ZAlert</b> خوش اومدی — ربات آلرت قیمت MT5 🚀\n\n"
            f"⚡️ آلرت‌های فعالت: <b>{count}</b>\n"
            f"📡 وضعیت سرور: <b>آنلاین</b>\n\n"
            "از منوی پایین شروع کن 👇",
            parse_mode=ParseMode.HTML,
            reply_markup=KeyboardFactory.main_menu(),
        )

    async def help_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not await self.can_use(update):
            return

        await update.message.reply_text(
            "📖 <b>راهنمای ZAlert</b>\n\n"
            "<b>دستورات:</b>\n"
            "• /set SYMBOL PRICE — آلرت جدید\n"
            "  مثال: <code>/set xauusd 3400</code>\n\n"
            "• /price SYMBOL — قیمت لحظه‌ای\n"
            "• /list — آلرت‌های فعال\n"
            "• /delete ID — حذف یک آلرت\n"
            "• /clear — حذف همه آلرت‌ها\n"
            "• /stats — آمار کل سیستم\n"
            "• /history — آلرت‌های تریگر شده\n"
            "• /status — وضعیت سرور\n\n"
            f"⚙️ حداکثر {config.MAX_ALERTS_PER_USER} آلرت فعال\n"
            f"⏱ بررسی هر {config.CHECK_INTERVAL} ثانیه",
            parse_mode=ParseMode.HTML,
            reply_markup=KeyboardFactory.main_menu(),
        )
