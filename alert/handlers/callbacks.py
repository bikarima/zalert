"""
CallbackRouter — routes all InlineKeyboard button presses.

Routing convention: callback_data = "domain:action[:param]"
  Domain   Action            Param
  -------  ----------------  -----------
  nav      main              —
  menu     new_alert         —
  menu     list              —
  menu     price             —
  menu     calendar          —
  menu     stats             —
  menu     profile           —
  menu     status            —
  alert    view              <alert_id>
  alert    del               <alert_id>
  alert    clear_confirm     —
  alert    clear_do          —
  newalert <SYMBOL>          —
  price    show / refresh    <SYMBOL>
  price    set               <SYMBOL>

Adding a new button? Add a new row here — no other file needs to change.
"""
import logging

from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.constants import ParseMode
from telegram.ext import ContextTypes

from .base    import BaseHandler
from .market  import MarketHandlers
from keyboards import KeyboardFactory
from utils     import fmt_price, direction_label, progress_bar

log = logging.getLogger("CallbackRouter")


class CallbackRouter(BaseHandler):
    """
    Single entry point for all callback queries.
    Inject MarketHandlers so we can reuse build_status_text / price_text.
    """

    def __init__(self, db, mt5, start_time, market: MarketHandlers) -> None:
        super().__init__(db, mt5, start_time)
        self._market = market

    # ── Entry point ────────────────────────────────────────────────────────────

    async def route(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        query = update.callback_query
        await query.answer()

        if not await self.can_use_callback(update):
            await query.answer("⛔️ دسترسی ندارید.", show_alert=True)
            return

        data    = query.data or ""
        user_id = update.effective_user.id
        parts   = data.split(":", 2)            # max 3 parts
        domain  = parts[0]
        action  = parts[1] if len(parts) > 1 else ""
        param   = parts[2] if len(parts) > 2 else ""

        log.debug("callback: user=%s data=%s", user_id, data)

        try:
            if domain == "nav":
                await self._nav(query, update, action, user_id)
            elif domain == "menu":
                await self._menu(query, update, action, user_id)
            elif domain == "alert":
                await self._alert(query, action, param, user_id)
            elif domain == "price":
                await self._price(query, action, param)
            elif domain == "newalert":
                await self._newalert_pick(query, action)   # action IS the symbol here
            else:
                log.warning("unknown callback domain=%s data=%s", domain, data)
        except Exception:
            log.exception("unhandled callback error: data=%s", data)
            await query.answer("❌ خطای داخلی.", show_alert=True)

    # ── nav ───────────────────────────────────────────────────────────────────

    async def _nav(self, query, update, action: str, user_id: int) -> None:
        if action == "main":
            name  = update.effective_user.first_name or "معامله‌گر"
            count = await self.db.count_user_alerts(user_id)
            await query.edit_message_text(
                f"🏠 <b>منوی اصلی</b>\n\nسلام <b>{name}</b>!\n"
                f"⚡️ آلرت‌های فعال: <b>{count}</b>",
                parse_mode=ParseMode.HTML,
                reply_markup=KeyboardFactory.main_menu(),
            )

    # ── menu ──────────────────────────────────────────────────────────────────

    async def _menu(self, query, update, action: str, user_id: int) -> None:
        if action == "new_alert":
            await query.edit_message_text(
                "🔔 <b>آلرت جدید</b>\n\nیه نماد انتخاب کن یا بنویس:\n"
                "<code>/set SYMBOL PRICE</code>",
                parse_mode=ParseMode.HTML,
                reply_markup=KeyboardFactory.symbol_picker("newalert"),
            )

        elif action == "list":
            await self._render_list(query, user_id)

        elif action == "price":
            await query.edit_message_text(
                "💰 <b>قیمت لحظه‌ای</b>\n\nنماد مورد نظرت رو انتخاب کن:",
                parse_mode=ParseMode.HTML,
                reply_markup=KeyboardFactory.symbol_picker("price:show"),
            )

        elif action == "calendar":
            await self._render_calendar(query)

        elif action == "stats":
            await self._render_stats(query)

        elif action == "profile":
            await self._render_profile(query, update, user_id)

        elif action == "status":
            await query.edit_message_text("⏳ در حال بررسی...", parse_mode=ParseMode.HTML)
            await query.edit_message_text(
                await self._market.build_status_text(),
                parse_mode=ParseMode.HTML,
                reply_markup=KeyboardFactory.status_actions(),
            )

    # ── alert ─────────────────────────────────────────────────────────────────

    async def _alert(self, query, action: str, param: str, user_id: int) -> None:
        if action == "view" and param:
            await self._render_detail(query, int(param), user_id)

        elif action == "del" and param:
            deleted = await self.db.delete_alert(int(param), user_id)
            if deleted:
                log.info("alert deleted via button: id=%s user=%s", param, user_id)
                await query.answer(f"✅ آلرت #{param} حذف شد.", show_alert=True)
                await self._render_list(query, user_id)
            else:
                await query.answer("❌ حذف ناموفق!", show_alert=True)

        elif action == "clear_confirm":
            count = await self.db.count_user_alerts(user_id)
            await query.edit_message_text(
                f"⚠️ <b>تأیید حذف همه</b>\n\nمیخوای <b>{count} آلرت</b> رو پاک کنی?\n"
                "این کار برگشت نداره! 🚨",
                parse_mode=ParseMode.HTML,
                reply_markup=KeyboardFactory.confirm_clear(),
            )

        elif action == "clear_do":
            count = await self.db.clear_user_alerts(user_id)
            log.info("alerts cleared: count=%s user=%s", count, user_id)
            await query.edit_message_text(
                f"🗑 <b>{count} آلرت حذف شد.</b>\n\nخیالت راحت! 😌",
                parse_mode=ParseMode.HTML,
                reply_markup=KeyboardFactory.back_main(),
            )

    # ── price ─────────────────────────────────────────────────────────────────

    async def _price(self, query, action: str, symbol: str) -> None:
        if action in ("show", "refresh") and symbol:
            price = self.mt5.get_price(symbol)
            if price is None:
                await query.answer(f"❌ قیمت {symbol} دریافت نشد.", show_alert=True)
                return
            await query.edit_message_text(
                MarketHandlers.price_text(symbol, price),
                parse_mode=ParseMode.HTML,
                reply_markup=KeyboardFactory.price_actions(symbol),
            )
            if action == "refresh":
                await query.answer("✅ بروز شد!")

        elif action == "set" and symbol:
            price = self.mt5.get_price(symbol)
            await query.edit_message_text(
                f"🔔 <b>آلرت برای {symbol}</b>\n\n"
                f"قیمت فعلی: <code>{'—' if price is None else fmt_price(price)}</code>\n\n"
                f"قیمت هدف رو بنویس:\n<code>/set {symbol} PRICE</code>",
                parse_mode=ParseMode.HTML,
                reply_markup=KeyboardFactory.back_main(),
            )

    # ── newalert symbol pick ──────────────────────────────────────────────────

    async def _newalert_pick(self, query, symbol: str) -> None:
        price = self.mt5.get_price(symbol)
        if price is None:
            await query.answer("❌ قیمت دریافت نشد.", show_alert=True)
            return
        real = self.mt5.get_resolved_symbol(symbol) or symbol
        await query.edit_message_text(
            f"💰 <b>{real}</b> = <code>{fmt_price(price)}</code>\n\n"
            f"قیمت هدفت رو بنویس:\n<code>/set {real} PRICE</code>",
            parse_mode=ParseMode.HTML,
            reply_markup=KeyboardFactory.price_actions(real),
        )

    # ── shared renderers ──────────────────────────────────────────────────────

    async def _render_list(self, query, user_id: int) -> None:
        alerts = await self.db.get_user_alerts(user_id)
        if not alerts:
            await query.edit_message_text(
                "📭 <b>آلرت فعالی نداری!</b>",
                parse_mode=ParseMode.HTML,
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("🔔 آلرت جدید", callback_data="menu:new_alert"),
                    InlineKeyboardButton("🏠 منوی اصلی", callback_data="nav:main"),
                ]]),
            )
            return

        lines = [f"📋 <b>آلرت‌های فعال ({len(alerts)} عدد)</b>\n"]
        for a in alerts:
            cur  = self.mt5.get_price(a["symbol"])
            diff = f"{abs(cur - a['target_price']) / cur * 100:.2f}%" if cur else "—"
            lines.append(
                f"<b>#{a['id']} {a['symbol']}</b>  "
                f"{direction_label(a['alert_type'])} → <code>{fmt_price(a['target_price'])}</code>  ({diff})"
            )
        await query.edit_message_text(
            "\n".join(lines),
            parse_mode=ParseMode.HTML,
            reply_markup=KeyboardFactory.alert_list(alerts),
        )

    async def _render_detail(self, query, alert_id: int, user_id: int) -> None:
        alert = await self.db.get_alert_by_id(alert_id)
        if not alert or alert.get("user_id") != user_id:
            await query.answer("❌ آلرت پیدا نشد.", show_alert=True)
            return

        cur  = self.mt5.get_price(alert["symbol"])
        bar  = progress_bar(cur, alert["target_price"], alert["alert_type"]) if cur else ""
        diff = f"{abs(cur - alert['target_price']) / cur * 100:.2f}%" if cur else "—"

        await query.edit_message_text(
            f"🔍 <b>جزئیات آلرت #{alert_id}</b>\n\n"
            f"📊 نماد: <b>{alert['symbol']}</b>\n"
            f"🎯 هدف: <code>{fmt_price(alert['target_price'])}</code>\n"
            f"💵 قیمت: <code>{fmt_price(cur) if cur else '—'}</code>\n"
            f"📈 جهت: {direction_label(alert['alert_type'])}\n"
            f"📏 فاصله: <b>{diff}</b>\n"
            f"{bar}\n"
            f"📅 ثبت: {alert.get('created_at', '—')}",
            parse_mode=ParseMode.HTML,
            reply_markup=KeyboardFactory.alert_detail(alert_id),
        )

    async def _render_calendar(self, query) -> None:
        from calendar_handler import get_today_events
        await query.edit_message_text("⏳ در حال دریافت تقویم...", parse_mode=ParseMode.HTML)
        IMPACT = {"high": "🔴", "medium": "🟡", "low": "🟢", "holiday": "🏖", "non_economic": "⚪️"}
        try:
            events = await get_today_events(user_tz="Asia/Tehran")
            if not events:
                text = "📅 <b>تقویم امروز</b>\n\nامروز رویداد اقتصادی نداریم. ✅"
            else:
                lines = [f"📅 <b>رویدادهای اقتصادی امروز ({len(events)} رویداد)</b>\n"]
                for e in events[:15]:
                    lines.append(
                        f"{IMPACT.get(e['impact'], '⚪️')} <b>{e['title']}</b>\n"
                        f"  🕐 {e['time']}  🌍 {e['currency']}"
                        + (f"\n  📊 قبلی: {e['previous']}  پیش‌بینی: {e['forecast']}"
                           if e["previous"] or e["forecast"] else "")
                    )
                text = "\n\n".join(lines)
        except Exception:
            log.exception("calendar render error")
            text = "❌ خطا در دریافت تقویم."
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=KeyboardFactory.back_main())

    async def _render_stats(self, query) -> None:
        data = await self.db.get_stats()
        if not data:
            text = "📊 <b>آمار</b>\n\nهیچ آلرت فعالی وجود ندارد."
        else:
            total = sum(data.values())
            lines = [f"📊 <b>آمار سیستم</b>\n\n🔢 مجموع: <b>{total}</b>\n"]
            for sym, cnt in data.items():
                bar = "█" * min(cnt, 10) + "░" * (10 - min(cnt, 10))
                lines.append(f"<code>{sym:<10}</code>  [{bar}]  {cnt}")
            text = "\n".join(lines)
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=KeyboardFactory.back_main())

    async def _render_profile(self, query, update, user_id: int) -> None:
        import config as cfg
        all_a  = await self.db.get_user_alerts(user_id, include_triggered=True)
        active = [a for a in all_a if not a.get("triggered")]
        trig   = [a for a in all_a if a.get("triggered")]
        name   = update.effective_user.first_name or update.effective_user.username or "—"
        syms   = list({a["symbol"] for a in all_a})[:5]

        await query.edit_message_text(
            f"👤 <b>پروفایل</b>\n\n"
            f"🙋 نام: <b>{name}</b>\n"
            f"🆔 شناسه: <code>{user_id}</code>\n\n"
            f"📊 <b>آمار آلرت‌ها:</b>\n"
            f"  ⚡️ فعال: <b>{len(active)}</b> / {cfg.MAX_ALERTS_PER_USER}\n"
            f"  ✅ تریگر شده: <b>{len(trig)}</b>\n"
            f"  📈 کل: <b>{len(all_a)}</b>\n\n"
            + (f"🎯 <b>نمادها:</b> {', '.join(syms)}\n" if syms else ""),
            parse_mode=ParseMode.HTML,
            reply_markup=KeyboardFactory.back_main(),
        )
