"""
AdminHandlers — /addgroup, /removegroup, /groups.
All methods are admin-only (checked via _is_admin).
"""
from telegram import Chat, Update
from telegram.constants import ParseMode
from telegram.ext import ContextTypes

from .base import BaseHandler


class AdminHandlers(BaseHandler):
    """Bot management — only the configured ADMIN_USER_ID may call these."""

    async def add_group(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._is_admin(update):
            return

        chat = update.effective_chat
        if chat.type not in (Chat.GROUP, Chat.SUPERGROUP):
            await update.message.reply_text("❌ داخل گروه استفاده کن.")
            return

        title = chat.title or str(chat.id)
        await self.db.add_group(chat.id, title)
        self.log.info("group added: id=%s title=%s", chat.id, title)
        await update.message.reply_text(
            f"✅ گروه «{title}» مجاز شد.\n🆔 <code>{chat.id}</code>",
            parse_mode=ParseMode.HTML,
        )

    async def remove_group(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._is_admin(update):
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

        removed = await self.db.remove_group(group_id)
        if removed:
            self.log.info("group removed: id=%s", group_id)
            await update.message.reply_text("✅ گروه حذف شد.")
        else:
            await update.message.reply_text("❌ گروه در لیست نبود.")

    async def list_groups(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._is_admin(update):
            return

        groups = await self.db.get_all_groups()
        if not groups:
            await update.message.reply_text("📭 هیچ گروه مجازی ثبت نشده.")
            return

        lines = ["📋 <b>گروه‌های مجاز:</b>\n"]
        for g in groups:
            lines.append(f"• <b>{g['group_title']}</b>\n  🆔 <code>{g['group_id']}</code>")
        await update.message.reply_text("\n".join(lines), parse_mode=ParseMode.HTML)
