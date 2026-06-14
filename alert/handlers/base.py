"""
BaseHandler — shared dependencies injected once, inherited everywhere.

Every concrete handler inherits from this class, which gives it:
  - self.db         : Database  (async MongoDB)
  - self.mt5        : MT5Handler
  - self.start_time : datetime  (for uptime calculation)
  - self.log        : Logger    (named after the subclass)
  - Access-control helpers: can_use(), can_use_callback(), _is_admin()
"""
import logging
from datetime import datetime

from telegram import Chat, Update
from telegram.ext import ContextTypes

import config
from database    import Database
from mt5_handler import MT5Handler
from utils       import uptime_str


class BaseHandler:
    """
    Dependency container + access-control mixin.

    Concrete handlers MUST call super().__init__(*args) and should
    not add positional arguments beyond (db, mt5, start_time).
    """

    def __init__(self, db: Database, mt5: MT5Handler, start_time: datetime) -> None:
        self.db         = db
        self.mt5        = mt5
        self.start_time = start_time
        self.log        = logging.getLogger(self.__class__.__name__)

    # ── Access control ────────────────────────────────────────────────────────

    def _is_admin(self, update: Update) -> bool:
        """True if the sender is the configured bot admin."""
        return update.effective_user.id == config.ADMIN_USER_ID

    async def _is_allowed_group(self, update: Update) -> bool:
        """True if the message comes from a white-listed group."""
        chat = update.effective_chat
        if chat.type not in (Chat.GROUP, Chat.SUPERGROUP):
            return False
        return await self.db.is_allowed_group(chat.id)

    def _is_private_admin(self, update: Update) -> bool:
        """True if the admin sent a DM to the bot."""
        return (
            update.effective_chat.type == Chat.PRIVATE
            and self._is_admin(update)
        )

    async def can_use(self, update: Update) -> bool:
        """
        A user may send commands if:
          a) they are in an allowed group, OR
          b) they are the admin messaging in a private chat.
        """
        return await self._is_allowed_group(update) or self._is_private_admin(update)

    async def can_use_callback(self, update: Update) -> bool:
        """Same gate but for CallbackQuery updates."""
        chat = update.effective_chat
        if chat.type == Chat.PRIVATE and self._is_admin(update):
            return True
        return await self.db.is_allowed_group(chat.id)

    # ── Utilities ─────────────────────────────────────────────────────────────

    def uptime(self) -> str:
        """Human-readable uptime since bot start."""
        return uptime_str(self.start_time)
