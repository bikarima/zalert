"""
BaseHandler — shared dependencies injected once, inherited everywhere.

Every concrete handler inherits from this class, which provides:
  - self.db         : Database  (async MongoDB)
  - self.mt5        : MT5Handler
  - self.start_time : datetime  (for uptime)
  - self.log        : Logger    (named after the subclass)
  - can_use()       : access control + ban check
  - can_use_callback()
"""
import logging
from datetime import datetime

from telegram import Chat, Update
from telegram.ext import ContextTypes
from telegram.constants import ParseMode

import config
from database    import Database
from mt5_handler import MT5Handler
from utils       import uptime_str


class BaseHandler:
    """
    Dependency container + access-control mixin.
    Concrete handlers must call super().__init__(db, mt5, start_time).
    """

    def __init__(self, db: Database, mt5: MT5Handler, start_time: datetime) -> None:
        self.db         = db
        self.mt5        = mt5
        self.start_time = start_time
        self.log        = logging.getLogger(self.__class__.__name__)

    # ── Access control ────────────────────────────────────────────────────────

    def _is_admin(self, update: Update) -> bool:
        return update.effective_user.id == config.ADMIN_USER_ID

    async def _is_allowed_group(self, update: Update) -> bool:
        chat = update.effective_chat
        if chat.type not in (Chat.GROUP, Chat.SUPERGROUP):
            return False
        return await self.db.is_allowed_group(chat.id)

    def _is_private_admin(self, update: Update) -> bool:
        return (
            update.effective_chat.type == Chat.PRIVATE
            and self._is_admin(update)
        )

    async def can_use(self, update: Update) -> bool:
        """
        Gate for all user-facing commands.
        Banned users are silently rejected (except admin).
        """
        user_id = update.effective_user.id

        # Admin always passes
        if self._is_admin(update):
            return self._is_private_admin(update) or await self._is_allowed_group(update)

        # Check ban
        if await self.db.is_banned(user_id):
            self.log.info("banned user attempted access: id=%s", user_id)
            if update.message:
                await update.message.reply_text("⛔️ دسترسی شما محدود شده است.")
            return False

        return await self._is_allowed_group(update)

    async def can_use_callback(self, update: Update) -> bool:
        """Gate for inline keyboard callbacks."""
        user_id = update.effective_user.id
        chat    = update.effective_chat

        if self._is_admin(update):
            return True

        if await self.db.is_banned(user_id):
            return False

        if chat.type == Chat.PRIVATE:
            return False

        return await self.db.is_allowed_group(chat.id)

    # ── Helpers ───────────────────────────────────────────────────────────────

    def uptime(self) -> str:
        return uptime_str(self.start_time)
