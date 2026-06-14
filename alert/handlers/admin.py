"""
AdminHandlers — Full admin control panel.

Commands (admin-only):
  /admin              Main admin panel (inline keyboard)
  /addgroup           Whitelist the current group
  /removegroup [ID]   Remove a group from whitelist
  /groups             List all whitelisted groups
  /users              List recent users
  /userinfo <ID>      Detailed user info + alerts
  /ban <ID> [reason]  Ban a user
  /unban <ID>         Unban a user
  /banned             List all banned users
  /alertsall          All active alerts system-wide
  /delany <ID>        Delete any alert (admin override)
  /clearall           Clear ALL active alerts
  /broadcast <text>   Send message to all groups
  /mt5reconnect       Reconnect MT5
  /setmax <N>         Set max alerts per user
  /adminhelp          Full admin command list

All commands silently ignore non-admin callers.
"""
import asyncio
import logging

from telegram import Chat, InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.constants import ParseMode
from telegram.ext import ContextTypes, ConversationHandler

import config
from .base     import BaseHandler
from keyboards import KeyboardFactory
from utils     import fmt_price, now_tehran_full

log = logging.getLogger("AdminHandlers")


class AdminHandlers(BaseHandler):
    """Complete admin control panel — all methods are admin-only."""

    # ── Guard ─────────────────────────────────────────────────────────────────

    def _check(self, update: Update) -> bool:
        """Return True and log if caller is admin, else silently drop."""
        if self._is_admin(update):
            return True
        log.warning(
            "non-admin tried admin command: user=%s cmd=%s",
            update.effective_user.id,
            update.message.text if update.message else "callback",
        )
        return False

    # ── /admin — Main Panel ───────────────────────────────────────────────────

    async def admin_panel(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        stats = await self.db.get_admin_stats()
        text = (
            f"🎛 <b>پنل مدیریت ZAlert</b>\n\n"
            f"{'─'*28}\n"
            f"👥 کاربران: <b>{stats['total_users']}</b>  "
            f"⛔️ بن‌شده: <b>{stats['banned_count']}</b>\n"
            f"🔔 آلرت فعال: <b>{stats['active_alerts']}</b>  "
            f"✅ تریگر شده: <b>{stats['triggered']}</b>\n"
            f"🏘 گروه‌ها: <b>{stats['total_groups']}</b>  "
            f"📱 دستگاه‌ها: <b>{stats['total_devices']}</b>\n"
            f"{'─'*28}\n"
            f"🕐 {now_tehran_full()}"
        )
        await update.message.reply_text(
            text, parse_mode=ParseMode.HTML,
            reply_markup=self._admin_menu_kb(),
        )

    @staticmethod
    def _admin_menu_kb() -> InlineKeyboardMarkup:
        return InlineKeyboardMarkup([
            [
                InlineKeyboardButton("👥 کاربران",       callback_data="admin:users"),
                InlineKeyboardButton("🏘 گروه‌ها",       callback_data="admin:groups"),
            ],
            [
                InlineKeyboardButton("🔔 آلرت‌های کل",  callback_data="admin:alerts_all"),
                InlineKeyboardButton("📊 آمار جامع",     callback_data="admin:stats"),
            ],
            [
                InlineKeyboardButton("⛔️ بن‌شده‌ها",    callback_data="admin:banned"),
                InlineKeyboardButton("📢 پیام همگانی",   callback_data="admin:broadcast_prompt"),
            ],
            [
                InlineKeyboardButton("🔌 اتصال MT5",     callback_data="admin:mt5_status"),
                InlineKeyboardButton("⚙️ تنظیمات",       callback_data="admin:settings"),
            ],
            [
                InlineKeyboardButton("🖥 وضعیت سرور",    callback_data="menu:status"),
            ],
        ])

    # ── /adminhelp ────────────────────────────────────────────────────────────

    async def admin_help(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        text = (
            "👑 <b>دستورات ادمین ZAlert</b>\n\n"
            "<b>پنل:</b>\n"
            "• /admin — پنل کامل ادمین\n\n"
            "<b>مدیریت گروه‌ها:</b>\n"
            "• /addgroup — مجاز کردن گروه فعلی\n"
            "• /removegroup [ID] — حذف گروه\n"
            "• /groups — لیست گروه‌های مجاز\n\n"
            "<b>مدیریت کاربران:</b>\n"
            "• /users — لیست کاربران اخیر\n"
            "• /userinfo ID — اطلاعات کاربر\n"
            "• /ban ID [reason] — بن کردن\n"
            "• /unban ID — آنبن کردن\n"
            "• /banned — لیست بن‌شده‌ها\n\n"
            "<b>مدیریت آلرت‌ها:</b>\n"
            "• /alertsall — همه آلرت‌های فعال\n"
            "• /delany ID — حذف هر آلرت\n"
            "• /clearall — پاک کردن همه آلرت‌ها\n\n"
            "<b>سیستم:</b>\n"
            "• /broadcast TEXT — پیام به همه گروه‌ها\n"
            "• /mt5reconnect — اتصال مجدد MT5\n"
            f"• /setmax N — سقف آلرت (الان: {config.MAX_ALERTS_PER_USER})\n"
        )
        await update.message.reply_text(
            text, parse_mode=ParseMode.HTML, reply_markup=KeyboardFactory.back_main()
        )

    # ── Group Management ──────────────────────────────────────────────────────

    async def add_group(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        chat = update.effective_chat
        if chat.type not in (Chat.GROUP, Chat.SUPERGROUP):
            await update.message.reply_text("❌ داخل گروه استفاده کن.")
            return
        title = chat.title or str(chat.id)
        await self.db.add_group(chat.id, title)
        log.info("group added: id=%s title=%s", chat.id, title)
        await update.message.reply_text(
            f"✅ گروه «<b>{title}</b>» مجاز شد.\n🆔 <code>{chat.id}</code>",
            parse_mode=ParseMode.HTML,
        )

    async def remove_group(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
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
            log.info("group removed: id=%s", group_id)
            await update.message.reply_text("✅ گروه حذف شد.")
        else:
            await update.message.reply_text("❌ گروه در لیست نبود.")

    async def list_groups(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        groups = await self.db.get_all_groups()
        if not groups:
            await update.message.reply_text("📭 هیچ گروه مجازی ثبت نشده.")
            return
        lines = [f"🏘 <b>گروه‌های مجاز ({len(groups)} عدد)</b>\n"]
        for g in groups:
            lines.append(
                f"• <b>{g['group_title']}</b>\n"
                f"  🆔 <code>{g['group_id']}</code>  📅 {g.get('added_at','—')}"
            )
        await update.message.reply_text("\n".join(lines), parse_mode=ParseMode.HTML)

    # ── User Management ───────────────────────────────────────────────────────

    async def list_users(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        users = await self.db.get_all_users(limit=20)
        total = await self.db.get_total_user_count()
        if not users:
            await update.message.reply_text("📭 هیچ کاربری ثبت نشده.")
            return
        lines = [f"👥 <b>کاربران اخیر</b> (نمایش {len(users)} از {total})\n"]
        for u in users:
            uid  = u["user_id"]
            name = u.get("username") or "—"
            cnt  = await self.db.count_user_alerts(uid)
            ban  = "⛔️" if await self.db.is_banned(uid) else ""
            lines.append(f"{ban}• @{name} | <code>{uid}</code> | 🔔{cnt} | {u.get('last_seen','—')[:10]}")
        rows = [[InlineKeyboardButton(f"🔍 جزئیات", callback_data="admin:users")]]
        await update.message.reply_text(
            "\n".join(lines), parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup(rows),
        )

    async def user_info(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        if not context.args:
            await update.message.reply_text("❌ /userinfo USER_ID")
            return
        try:
            uid = int(context.args[0])
        except ValueError:
            await update.message.reply_text("❌ آیدی باید عدد باشد!")
            return
        await update.message.reply_text(
            await self._build_user_detail(uid),
            parse_mode=ParseMode.HTML,
            reply_markup=self._user_action_kb(uid),
        )

    async def _build_user_detail(self, uid: int) -> str:
        user    = await self.db.get_user(uid)
        alerts  = await self.db.get_user_alerts(uid, include_triggered=True)
        active  = [a for a in alerts if not a.get("triggered")]
        trig    = [a for a in alerts if a.get("triggered")]
        devices = await self.db.get_user_devices(uid)
        is_ban  = await self.db.is_banned(uid)
        ban_inf = ""
        if is_ban:
            bans = await self.db.get_banned_users()
            b    = next((x for x in bans if x["user_id"] == uid), {})
            ban_inf = f"\n⛔️ بن‌شده: {b.get('reason','—')} ({b.get('banned_at','—')})"
        name = (user or {}).get("username", "—") if user else "—"
        return (
            f"👤 <b>اطلاعات کاربر</b>\n\n"
            f"🆔 آیدی: <code>{uid}</code>\n"
            f"👤 نام: @{name}\n"
            f"📅 ثبت‌نام: {(user or {}).get('registered_at','—')}\n"
            f"🕐 آخرین بازدید: {(user or {}).get('last_seen','—')}\n"
            f"{'─'*28}\n"
            f"🔔 آلرت فعال: <b>{len(active)}</b>\n"
            f"✅ تریگر شده: <b>{len(trig)}</b>\n"
            f"📱 دستگاه‌ها: <b>{len(devices)}</b>\n"
            f"{'─'*28}{ban_inf}"
        )

    @staticmethod
    def _user_action_kb(uid: int) -> InlineKeyboardMarkup:
        return InlineKeyboardMarkup([
            [
                InlineKeyboardButton("⛔️ بن کن",         callback_data=f"admin:ban_confirm:{uid}"),
                InlineKeyboardButton("✅ آنبن کن",        callback_data=f"admin:unban:{uid}"),
            ],
            [
                InlineKeyboardButton("🗑 پاک کردن آلرت‌ها", callback_data=f"admin:clear_user:{uid}"),
                InlineKeyboardButton("🔍 آلرت‌ها",           callback_data=f"admin:user_alerts:{uid}"),
            ],
            [InlineKeyboardButton("⬅️ بازگشت", callback_data="admin:users")],
        ])

    async def ban_user(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        if not context.args:
            await update.message.reply_text("❌ /ban USER_ID [reason]")
            return
        try:
            uid = int(context.args[0])
        except ValueError:
            await update.message.reply_text("❌ آیدی باید عدد باشد!")
            return
        reason = " ".join(context.args[1:]) if len(context.args) > 1 else ""
        await self.db.ban_user(uid, reason, banned_by=update.effective_user.id)
        log.warning("user banned: id=%s reason=%s by=%s", uid, reason, update.effective_user.id)
        await update.message.reply_text(
            f"⛔️ کاربر <code>{uid}</code> بن شد.\n📝 دلیل: {reason or '—'}",
            parse_mode=ParseMode.HTML,
        )

    async def unban_user(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        if not context.args:
            await update.message.reply_text("❌ /unban USER_ID")
            return
        try:
            uid = int(context.args[0])
        except ValueError:
            await update.message.reply_text("❌ آیدی باید عدد باشد!")
            return
        removed = await self.db.unban_user(uid)
        if removed:
            log.info("user unbanned: id=%s by=%s", uid, update.effective_user.id)
            await update.message.reply_text(f"✅ کاربر <code>{uid}</code> آنبن شد.", parse_mode=ParseMode.HTML)
        else:
            await update.message.reply_text(f"❌ کاربر <code>{uid}</code> در لیست بن نبود.", parse_mode=ParseMode.HTML)

    async def list_banned(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        bans = await self.db.get_banned_users()
        if not bans:
            await update.message.reply_text("✅ هیچ کاربری بن نشده.")
            return
        lines = [f"⛔️ <b>کاربران بن‌شده ({len(bans)} نفر)</b>\n"]
        for b in bans:
            lines.append(
                f"• <code>{b['user_id']}</code>  📝 {b.get('reason','—')}  📅 {b.get('banned_at','—')[:10]}"
            )
        await update.message.reply_text("\n".join(lines), parse_mode=ParseMode.HTML)

    # ── Alert Management ──────────────────────────────────────────────────────

    async def alerts_all(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        alerts = await self.db.get_all_active_alerts_admin(limit=30)
        if not alerts:
            await update.message.reply_text("📭 هیچ آلرت فعالی در سیستم نیست.")
            return
        lines = [f"🔔 <b>آلرت‌های فعال سیستم ({len(alerts)} عدد)</b>\n"]
        for a in alerts:
            cur  = self.mt5.get_price(a["symbol"])
            diff = f"{abs(cur - a['target_price'])/cur*100:.2f}%" if cur else "—"
            lines.append(
                f"<b>#{a['id']}</b> @{a.get('username','—')} | "
                f"<b>{a['symbol']}</b> → <code>{fmt_price(a['target_price'])}</code> ({diff})"
            )
        rows = [[
            InlineKeyboardButton("🗑 پاک کردن همه", callback_data="admin:clearall_confirm"),
            InlineKeyboardButton("⬅️ بازگشت",       callback_data="admin:menu"),
        ]]
        await update.message.reply_text(
            "\n".join(lines), parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup(rows),
        )

    async def delete_any_alert(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        if not context.args:
            await update.message.reply_text("❌ /delany ALERT_ID")
            return
        try:
            alert_id = int(context.args[0])
        except ValueError:
            await update.message.reply_text("❌ شناسه باید عدد باشد!")
            return
        deleted = await self.db.delete_alert_admin(alert_id)
        if deleted:
            log.info("alert deleted by admin: id=%s admin=%s", alert_id, update.effective_user.id)
            await update.message.reply_text(f"🗑 آلرت <b>#{alert_id}</b> حذف شد.", parse_mode=ParseMode.HTML)
        else:
            await update.message.reply_text(f"❌ آلرت #{alert_id} پیدا نشد.")

    async def clear_all(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        count = await self.db.get_admin_stats()
        active = count["active_alerts"]
        await update.message.reply_text(
            f"⚠️ <b>تأیید پاک کردن همه</b>\n\n"
            f"میخوای <b>{active} آلرت فعال</b> رو از کل سیستم پاک کنی?\n"
            f"این کار برگشت نداره! 🚨",
            parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("✅ بله، پاک کن",  callback_data="admin:clearall_do"),
                InlineKeyboardButton("❌ انصراف",       callback_data="admin:menu"),
            ]]),
        )

    # ── Broadcast ─────────────────────────────────────────────────────────────

    async def broadcast(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        if not context.args:
            await update.message.reply_text(
                "❌ استفاده: /broadcast متن پیامت اینجا\n\n"
                "پیام به همه گروه‌های مجاز ارسال میشه."
            )
            return
        text    = " ".join(context.args)
        groups  = await self.db.get_all_groups()
        if not groups:
            await update.message.reply_text("❌ هیچ گروه مجازی ثبت نشده.")
            return

        broadcast_text = f"📢 <b>پیام از ادمین:</b>\n\n{text}"

        async def _send(group_id: int) -> bool:
            try:
                await context.bot.send_message(
                    chat_id=group_id, text=broadcast_text, parse_mode=ParseMode.HTML
                )
                return True
            except Exception:
                log.exception("broadcast failed to group=%s", group_id)
                return False

        results = await asyncio.gather(*[_send(g["group_id"]) for g in groups])
        sent    = sum(results)
        log.info("broadcast: sent=%d/%d admin=%s", sent, len(groups), update.effective_user.id)
        await update.message.reply_text(
            f"📢 <b>پیام ارسال شد</b>\n\n"
            f"✅ موفق: <b>{sent}</b> گروه\n"
            f"❌ ناموفق: <b>{len(groups) - sent}</b> گروه",
            parse_mode=ParseMode.HTML,
        )

    # ── MT5 Management ────────────────────────────────────────────────────────

    async def mt5_reconnect(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        msg = await update.message.reply_text("🔄 در حال اتصال مجدد به MT5...")
        self.mt5.shutdown()
        success = self.mt5.initialize()
        if success:
            log.info("MT5 reconnected by admin=%s", update.effective_user.id)
            gold = self.mt5.get_price("XAUUSD")
            await msg.edit_text(
                f"✅ <b>MT5 مجدداً متصل شد!</b>\n\n"
                f"🥇 XAUUSD: <code>{fmt_price(gold) if gold else '—'}</code>",
                parse_mode=ParseMode.HTML,
            )
        else:
            log.error("MT5 reconnect failed admin=%s", update.effective_user.id)
            await msg.edit_text(
                "❌ <b>اتصال به MT5 ناموفق بود!</b>\n"
                "MT5 رو باز کن و دوباره امتحان کن.",
                parse_mode=ParseMode.HTML,
            )

    # ── Settings ──────────────────────────────────────────────────────────────

    async def set_max_alerts(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        if not context.args:
            await update.message.reply_text(
                f"⚙️ سقف فعلی آلرت: <b>{config.MAX_ALERTS_PER_USER}</b>\n\n"
                f"استفاده: /setmax عدد",
                parse_mode=ParseMode.HTML,
            )
            return
        try:
            n = int(context.args[0])
            if n < 1 or n > 1000:
                raise ValueError
        except ValueError:
            await update.message.reply_text("❌ عدد باید بین ۱ تا ۱۰۰۰ باشد!")
            return

        old = config.MAX_ALERTS_PER_USER
        config.MAX_ALERTS_PER_USER = n
        log.info("MAX_ALERTS_PER_USER changed: %d → %d by admin=%s", old, n, update.effective_user.id)
        await update.message.reply_text(
            f"⚙️ سقف آلرت تغییر کرد: <b>{old}</b> → <b>{n}</b>",
            parse_mode=ParseMode.HTML,
        )

    # ── Admin Stats ───────────────────────────────────────────────────────────

    async def admin_stats(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self._check(update):
            return
        s = await self.db.get_admin_stats()
        lines = [
            f"📊 <b>آمار جامع سیستم ZAlert</b>\n",
            f"{'─'*28}",
            f"👥 کل کاربران: <b>{s['total_users']}</b>",
            f"⛔️ بن‌شده: <b>{s['banned_count']}</b>",
            f"🏘 گروه‌های مجاز: <b>{s['total_groups']}</b>",
            f"📱 دستگاه‌های ثبت‌شده: <b>{s['total_devices']}</b>",
            f"{'─'*28}",
            f"🔔 آلرت فعال: <b>{s['active_alerts']}</b>",
            f"✅ تریگر شده: <b>{s['triggered']}</b>",
            f"📈 کل آلرت‌ها: <b>{s['total_alerts']}</b>",
        ]
        if s["top_symbols"]:
            lines.append(f"{'─'*28}")
            lines.append("🔝 <b>نمادهای محبوب:</b>")
            for sym, cnt in s["top_symbols"]:
                bar = "█" * min(cnt, 8) + "░" * (8 - min(cnt, 8))
                lines.append(f"  <code>{sym:<10}</code> [{bar}] {cnt}")
        if s["top_users"]:
            lines.append(f"{'─'*28}")
            lines.append("🏆 <b>فعال‌ترین کاربران:</b>")
            for uid, uname, cnt in s["top_users"]:
                lines.append(f"  @{uname} | <code>{uid}</code> | {cnt} آلرت")
        lines.append(f"{'─'*28}")
        lines.append(f"🕐 {now_tehran_full()}")
        await update.message.reply_text(
            "\n".join(lines), parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("🔄 بروزرسانی", callback_data="admin:stats"),
                InlineKeyboardButton("⬅️ پنل ادمین", callback_data="admin:menu"),
            ]]),
        )

    # ── Callback handler (admin domain) ───────────────────────────────────────

    async def handle_callback(self, query, update: Update, action: str, param: str) -> None:
        """
        Called by CallbackRouter for all callbacks with domain='admin'.
        action = parts[1], param = parts[2] (may be empty).
        """
        user_id = update.effective_user.id

        if action == "menu":
            stats = await self.db.get_admin_stats()
            text = (
                f"🎛 <b>پنل مدیریت ZAlert</b>\n\n"
                f"{'─'*28}\n"
                f"👥 کاربران: <b>{stats['total_users']}</b>  "
                f"⛔️ بن‌شده: <b>{stats['banned_count']}</b>\n"
                f"🔔 آلرت فعال: <b>{stats['active_alerts']}</b>  "
                f"✅ تریگر شده: <b>{stats['triggered']}</b>\n"
                f"🏘 گروه‌ها: <b>{stats['total_groups']}</b>  "
                f"📱 دستگاه‌ها: <b>{stats['total_devices']}</b>\n"
                f"{'─'*28}\n"
                f"🕐 {now_tehran_full()}"
            )
            await query.edit_message_text(
                text, parse_mode=ParseMode.HTML, reply_markup=self._admin_menu_kb()
            )

        elif action == "users":
            await self._cb_users(query)

        elif action == "user_detail" and param:
            uid = int(param)
            await query.edit_message_text(
                await self._build_user_detail(uid),
                parse_mode=ParseMode.HTML,
                reply_markup=self._user_action_kb(uid),
            )

        elif action == "user_alerts" and param:
            uid    = int(param)
            alerts = await self.db.get_user_alerts(uid, include_triggered=False)
            if not alerts:
                await query.answer(f"کاربر {uid} آلرت فعالی ندارد.", show_alert=True)
                return
            lines = [f"🔔 <b>آلرت‌های کاربر {uid}</b>\n"]
            for a in alerts:
                cur  = self.mt5.get_price(a["symbol"])
                diff = f"{abs(cur-a['target_price'])/cur*100:.2f}%" if cur else "—"
                lines.append(f"<b>#{a['id']}</b> {a['symbol']} → <code>{fmt_price(a['target_price'])}</code> ({diff})")
            await query.edit_message_text(
                "\n".join(lines), parse_mode=ParseMode.HTML,
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("⬅️ بازگشت", callback_data=f"admin:user_detail:{uid}")
                ]]),
            )

        elif action == "ban_confirm" and param:
            uid = int(param)
            await query.edit_message_text(
                f"⚠️ مطمئنی میخوای کاربر <code>{uid}</code> رو بن کنی?",
                parse_mode=ParseMode.HTML,
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("✅ بن کن",  callback_data=f"admin:ban_do:{uid}"),
                    InlineKeyboardButton("❌ انصراف", callback_data=f"admin:user_detail:{uid}"),
                ]]),
            )

        elif action == "ban_do" and param:
            uid = int(param)
            await self.db.ban_user(uid, banned_by=user_id)
            log.warning("user banned via btn: id=%s by=%s", uid, user_id)
            await query.answer(f"⛔️ کاربر {uid} بن شد.", show_alert=True)
            await query.edit_message_text(
                await self._build_user_detail(uid),
                parse_mode=ParseMode.HTML, reply_markup=self._user_action_kb(uid)
            )

        elif action == "unban" and param:
            uid = int(param)
            removed = await self.db.unban_user(uid)
            await query.answer(
                f"✅ کاربر {uid} آنبن شد." if removed else f"کاربر {uid} بن نبود.",
                show_alert=True,
            )
            await query.edit_message_text(
                await self._build_user_detail(uid),
                parse_mode=ParseMode.HTML, reply_markup=self._user_action_kb(uid)
            )

        elif action == "clear_user" and param:
            uid   = int(param)
            count = await self.db.clear_user_alerts(uid)
            log.info("admin cleared alerts: user=%s count=%d by=%s", uid, count, user_id)
            await query.answer(f"🗑 {count} آلرت کاربر {uid} پاک شد.", show_alert=True)
            await query.edit_message_text(
                await self._build_user_detail(uid),
                parse_mode=ParseMode.HTML, reply_markup=self._user_action_kb(uid)
            )

        elif action == "groups":
            await self._cb_groups(query)

        elif action == "alerts_all":
            await self._cb_alerts_all(query)

        elif action == "clearall_confirm":
            stats  = await self.db.get_admin_stats()
            active = stats["active_alerts"]
            await query.edit_message_text(
                f"⚠️ <b>تأیید پاک کردن کل سیستم</b>\n\n"
                f"میخوای <b>{active} آلرت</b> از همه کاربران پاک کنی?",
                parse_mode=ParseMode.HTML,
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("✅ بله پاک کن", callback_data="admin:clearall_do"),
                    InlineKeyboardButton("❌ انصراف",    callback_data="admin:menu"),
                ]]),
            )

        elif action == "clearall_do":
            count = await self.db.clear_all_alerts_admin()
            log.warning("ALL alerts cleared: count=%d by admin=%s", count, user_id)
            await query.edit_message_text(
                f"🗑 <b>{count} آلرت از کل سیستم پاک شد.</b>",
                parse_mode=ParseMode.HTML,
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("⬅️ پنل ادمین", callback_data="admin:menu")
                ]]),
            )

        elif action == "stats":
            s = await self.db.get_admin_stats()
            lines = [
                f"📊 <b>آمار جامع سیستم</b>\n",
                f"{'─'*28}",
                f"👥 کاربران: <b>{s['total_users']}</b>  ⛔️ بن: <b>{s['banned_count']}</b>",
                f"🏘 گروه‌ها: <b>{s['total_groups']}</b>  📱 دستگاه: <b>{s['total_devices']}</b>",
                f"🔔 آلرت فعال: <b>{s['active_alerts']}</b>  ✅ تریگر: <b>{s['triggered']}</b>",
            ]
            if s["top_symbols"]:
                lines.append(f"{'─'*28}\n🔝 <b>نمادهای محبوب:</b>")
                for sym, cnt in s["top_symbols"]:
                    lines.append(f"  <code>{sym:<10}</code> {cnt}")
            if s["top_users"]:
                lines.append(f"{'─'*28}\n🏆 <b>فعال‌ترین کاربران:</b>")
                for uid, uname, cnt in s["top_users"]:
                    lines.append(f"  @{uname} ({cnt})")
            lines.append(f"{'─'*28}\n🕐 {now_tehran_full()}")
            await query.edit_message_text(
                "\n".join(lines), parse_mode=ParseMode.HTML,
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("🔄 بروزرسانی", callback_data="admin:stats"),
                    InlineKeyboardButton("⬅️ پنل ادمین", callback_data="admin:menu"),
                ]]),
            )

        elif action == "banned":
            bans = await self.db.get_banned_users()
            if not bans:
                await query.edit_message_text(
                    "✅ هیچ کاربری بن نشده.",
                    reply_markup=InlineKeyboardMarkup([[
                        InlineKeyboardButton("⬅️ پنل ادمین", callback_data="admin:menu")
                    ]]),
                )
                return
            lines = [f"⛔️ <b>کاربران بن‌شده ({len(bans)} نفر)</b>\n"]
            for b in bans:
                lines.append(
                    f"• <code>{b['user_id']}</code>  {b.get('reason','—')}  {b.get('banned_at','—')[:10]}"
                )
            await query.edit_message_text(
                "\n".join(lines), parse_mode=ParseMode.HTML,
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("⬅️ پنل ادمین", callback_data="admin:menu")
                ]]),
            )

        elif action == "broadcast_prompt":
            await query.edit_message_text(
                "📢 <b>پیام همگانی</b>\n\n"
                "برای ارسال پیام به همه گروه‌ها از دستور زیر استفاده کن:\n"
                "<code>/broadcast متن پیامت اینجا</code>",
                parse_mode=ParseMode.HTML,
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("⬅️ پنل ادمین", callback_data="admin:menu")
                ]]),
            )

        elif action == "mt5_status":
            gold = self.mt5.get_price("XAUUSD")
            status = "🟢 متصل" if self.mt5.initialized else "🔴 قطع"
            await query.edit_message_text(
                f"🔌 <b>وضعیت MT5</b>\n\n"
                f"اتصال: {status}\n"
                f"🥇 XAUUSD: <code>{fmt_price(gold) if gold else '—'}</code>\n\n"
                f"برای اتصال مجدد: /mt5reconnect",
                parse_mode=ParseMode.HTML,
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("🔄 اتصال مجدد", callback_data="admin:mt5_reconnect"),
                    InlineKeyboardButton("⬅️ پنل ادمین",  callback_data="admin:menu"),
                ]]),
            )

        elif action == "mt5_reconnect":
            await query.edit_message_text("🔄 در حال اتصال مجدد به MT5...", parse_mode=ParseMode.HTML)
            self.mt5.shutdown()
            success = self.mt5.initialize()
            gold    = self.mt5.get_price("XAUUSD") if success else None
            if success:
                log.info("MT5 reconnected via btn by admin=%s", user_id)
                await query.edit_message_text(
                    f"✅ <b>MT5 متصل شد!</b>\n🥇 XAUUSD: <code>{fmt_price(gold) if gold else '—'}</code>",
                    parse_mode=ParseMode.HTML,
                    reply_markup=InlineKeyboardMarkup([[
                        InlineKeyboardButton("⬅️ پنل ادمین", callback_data="admin:menu")
                    ]]),
                )
            else:
                await query.edit_message_text(
                    "❌ <b>اتصال ناموفق بود!</b>\nMT5 رو باز کن.",
                    parse_mode=ParseMode.HTML,
                    reply_markup=InlineKeyboardMarkup([[
                        InlineKeyboardButton("🔄 تلاش مجدد", callback_data="admin:mt5_reconnect"),
                        InlineKeyboardButton("⬅️ پنل ادمین",  callback_data="admin:menu"),
                    ]]),
                )

        elif action == "settings":
            await query.edit_message_text(
                f"⚙️ <b>تنظیمات سیستم</b>\n\n"
                f"🔔 سقف آلرت هر کاربر: <b>{config.MAX_ALERTS_PER_USER}</b>\n"
                f"⏱ بازه چک آلرت: <b>{config.CHECK_INTERVAL}s</b>\n\n"
                f"برای تغییر سقف: <code>/setmax عدد</code>",
                parse_mode=ParseMode.HTML,
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("⬅️ پنل ادمین", callback_data="admin:menu")
                ]]),
            )

    # ── Shared sub-renderers ──────────────────────────────────────────────────

    async def _cb_users(self, query) -> None:
        users = await self.db.get_all_users(limit=15)
        total = await self.db.get_total_user_count()
        if not users:
            await query.edit_message_text("📭 هیچ کاربری ثبت نشده.")
            return
        lines = [f"👥 <b>کاربران اخیر</b> ({len(users)} از {total})\n"]
        rows  = []
        for u in users:
            uid  = u["user_id"]
            name = u.get("username") or str(uid)
            cnt  = await self.db.count_user_alerts(uid)
            ban  = "⛔️" if await self.db.is_banned(uid) else ""
            lines.append(f"{ban}• @{name} | <code>{uid}</code> | 🔔{cnt}")
            rows.append([InlineKeyboardButton(
                f"{ban}@{name} ({cnt}🔔)", callback_data=f"admin:user_detail:{uid}"
            )])
        rows.append([InlineKeyboardButton("⬅️ پنل ادمین", callback_data="admin:menu")])
        await query.edit_message_text(
            "\n".join(lines), parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup(rows),
        )

    async def _cb_groups(self, query) -> None:
        groups = await self.db.get_all_groups()
        if not groups:
            await query.edit_message_text(
                "📭 هیچ گروه مجازی ثبت نشده.\nاز /addgroup داخل گروه استفاده کن.",
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("⬅️ پنل ادمین", callback_data="admin:menu")
                ]]),
            )
            return
        lines = [f"🏘 <b>گروه‌های مجاز ({len(groups)} عدد)</b>\n"]
        rows  = []
        for g in groups:
            lines.append(f"• <b>{g['group_title']}</b>\n  🆔 <code>{g['group_id']}</code>")
            rows.append([InlineKeyboardButton(
                f"🗑 {g['group_title']}", callback_data=f"admin:rm_group:{g['group_id']}"
            )])
        rows.append([InlineKeyboardButton("⬅️ پنل ادمین", callback_data="admin:menu")])
        await query.edit_message_text(
            "\n".join(lines), parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup(rows),
        )

    async def _cb_alerts_all(self, query) -> None:
        alerts = await self.db.get_all_active_alerts_admin(limit=25)
        if not alerts:
            await query.edit_message_text(
                "📭 هیچ آلرت فعالی در سیستم نیست.",
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("⬅️ پنل ادمین", callback_data="admin:menu")
                ]]),
            )
            return
        lines = [f"🔔 <b>آلرت‌های فعال ({len(alerts)} عدد)</b>\n"]
        for a in alerts:
            cur  = self.mt5.get_price(a["symbol"])
            diff = f"{abs(cur-a['target_price'])/cur*100:.2f}%" if cur else "—"
            lines.append(
                f"<b>#{a['id']}</b> @{a.get('username','—')} | "
                f"<b>{a['symbol']}</b> → <code>{fmt_price(a['target_price'])}</code> ({diff})"
            )
        await query.edit_message_text(
            "\n".join(lines), parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([
                [
                    InlineKeyboardButton("🗑 پاک کردن همه", callback_data="admin:clearall_confirm"),
                    InlineKeyboardButton("⬅️ پنل ادمین",   callback_data="admin:menu"),
                ]
            ]),
        )
