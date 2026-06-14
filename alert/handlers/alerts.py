"""
AlertHandlers — /set, /list, /delete, /clear, /history.
"""
from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.constants import ParseMode
from telegram.ext import ContextTypes

import config
from .base     import BaseHandler
from keyboards import KeyboardFactory
from utils     import fmt_price, direction_label, progress_bar


class AlertHandlers(BaseHandler):
    """Full CRUD for price alerts, with inline keyboard responses."""

    # ── /set ─────────────────────────────────────────────────────────────────

    async def set_alert(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not await self.can_use(update):
            return

        user_id  = update.effective_user.id
        username = update.effective_user.username or update.effective_user.first_name

        if len(context.args) != 2:
            await update.message.reply_text(
                "❌ <b>فرمت نادرست!</b>\n\n"
                "استفاده: <code>/set SYMBOL PRICE</code>\n"
                "مثال: <code>/set xauusd 3400</code>",
                parse_mode=ParseMode.HTML,
            )
            return

        symbol = context.args[0].upper()
        try:
            target_price = float(context.args[1])
        except ValueError:
            await update.message.reply_text("❌ قیمت باید عدد باشد!", parse_mode=ParseMode.HTML)
            return

        if await self.db.count_user_alerts(user_id) >= config.MAX_ALERTS_PER_USER:
            await update.message.reply_text(
                f"⚠️ به سقف {config.MAX_ALERTS_PER_USER} آلرت رسیدی!\nابتدا یه آلرت حذف کن.",
                parse_mode=ParseMode.HTML,
            )
            return

        current_price = self.mt5.get_price(symbol)
        if current_price is None:
            await update.message.reply_text(
                f"❌ نماد <b>{symbol}</b> یافت نشد.", parse_mode=ParseMode.HTML
            )
            return

        real_symbol = self.mt5.get_resolved_symbol(symbol) or symbol
        alert_type  = "below" if current_price > target_price else "above"
        alert_id    = await self.db.add_alert(
            user_id, username, real_symbol, target_price, alert_type,
            group_id=update.effective_chat.id,
        )

        diff_pct = abs(current_price - target_price) / current_price * 100
        bar      = progress_bar(current_price, target_price, alert_type)
        sym_disp = real_symbol if real_symbol == symbol else f"{real_symbol} <i>(از {symbol})</i>"

        self.log.info(
            "alert created: id=%s user=%s symbol=%s target=%.5f type=%s",
            alert_id, user_id, real_symbol, target_price, alert_type,
        )
        await update.message.reply_text(
            f"✅ <b>آلرت #{alert_id} ثبت شد!</b>\n\n"
            f"📊 نماد: <b>{sym_disp}</b>\n"
            f"💵 قیمت فعلی: <code>{fmt_price(current_price)}</code>\n"
            f"🎯 هدف: <code>{fmt_price(target_price)}</code>\n"
            f"📈 جهت: {direction_label(alert_type)}\n"
            f"📏 فاصله: <b>{diff_pct:.2f}%</b>\n"
            f"{bar}\n\n"
            f"⏱ هر {config.CHECK_INTERVAL}ثانیه چک میشه 👀",
            parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("📋 لیست آلرت‌ها", callback_data="menu:list"),
                InlineKeyboardButton("🏠 منوی اصلی",    callback_data="nav:main"),
            ]]),
        )

    # ── /list ─────────────────────────────────────────────────────────────────

    async def list_alerts(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not await self.can_use(update):
            return

        alerts = await self.db.get_user_alerts(update.effective_user.id)

        if not alerts:
            await update.message.reply_text(
                "📭 <b>هیچ آلرت فعالی نداری!</b>\nبا دکمه زیر یه آلرت بذار 👇",
                parse_mode=ParseMode.HTML,
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("🔔 آلرت جدید", callback_data="menu:new_alert"),
                ]]),
            )
            return

        lines = [f"📋 <b>آلرت‌های فعال ({len(alerts)} عدد)</b>\n"]
        for a in alerts:
            cur  = self.mt5.get_price(a["symbol"])
            diff = f"{abs(cur - a['target_price']) / cur * 100:.2f}%" if cur else "—"
            bar  = progress_bar(cur, a["target_price"], a["alert_type"]) if cur else ""
            lines.append(
                f"{'─'*28}\n"
                f"<b>#{a['id']} {a['symbol']}</b>  {direction_label(a['alert_type'])}\n"
                f"🎯 <code>{fmt_price(a['target_price'])}</code>  "
                f"💵 <code>{fmt_price(cur) if cur else '—'}</code>  📏 {diff}\n"
                f"{bar}"
            )

        await update.message.reply_text(
            "\n".join(lines),
            parse_mode=ParseMode.HTML,
            reply_markup=KeyboardFactory.alert_list(alerts),
        )

    # ── /delete ───────────────────────────────────────────────────────────────

    async def delete_alert(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not await self.can_use(update):
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

        deleted = await self.db.delete_alert(alert_id, user_id)
        if deleted:
            self.log.info("alert deleted: id=%s user=%s", alert_id, user_id)
            await update.message.reply_text(
                f"🗑 <b>آلرت #{alert_id} حذف شد.</b>",
                parse_mode=ParseMode.HTML,
                reply_markup=KeyboardFactory.back_main(),
            )
        else:
            await update.message.reply_text(
                f"❌ آلرت #{alert_id} پیدا نشد یا مال تو نیست.", parse_mode=ParseMode.HTML
            )

    # ── /clear ────────────────────────────────────────────────────────────────

    async def clear_alerts(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not await self.can_use(update):
            return

        count = await self.db.count_user_alerts(update.effective_user.id)
        if count == 0:
            await update.message.reply_text("📭 آلرت فعالی نداری!")
            return

        await update.message.reply_text(
            f"⚠️ <b>مطمئنی؟</b>\n\n"
            f"میخوای <b>{count} آلرت</b> فعالت رو حذف کنی?\nاین کار برگشت نداره! 🚨",
            parse_mode=ParseMode.HTML,
            reply_markup=KeyboardFactory.confirm_clear(),
        )

    # ── /history ──────────────────────────────────────────────────────────────

    async def history(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not await self.can_use(update):
            return

        all_a    = await self.db.get_user_alerts(update.effective_user.id, include_triggered=True)
        triggered = [a for a in all_a if a.get("triggered")]

        if not triggered:
            await update.message.reply_text(
                "📭 هنوز هیچ آلرتی تریگر نشده.", reply_markup=KeyboardFactory.back_main()
            )
            return

        lines = [f"🏆 <b>آلرت‌های فعال شده ({len(triggered)} عدد)</b>\n"]
        for a in triggered[-10:]:
            lines.append(
                f"{'─'*28}\n"
                f"✅ <b>{a['symbol']}</b>  {direction_label(a['alert_type'])}\n"
                f"🎯 هدف: <code>{fmt_price(a['target_price'])}</code>\n"
                f"📅 {a.get('triggered_at', '—')}"
            )

        await update.message.reply_text(
            "\n".join(lines), parse_mode=ParseMode.HTML, reply_markup=KeyboardFactory.back_main()
        )
