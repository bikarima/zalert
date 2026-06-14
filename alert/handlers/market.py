"""
MarketHandlers — /price, /stats, /status.
"""
import config
from telegram import Update
from telegram.constants import ParseMode
from telegram.ext import ContextTypes

from .base     import BaseHandler
from keyboards import KeyboardFactory
from utils     import fmt_price, now_tehran, now_tehran_full


class MarketHandlers(BaseHandler):
    """Price queries, statistics, and server health."""

    # ── /price ────────────────────────────────────────────────────────────────

    async def get_price(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not await self.can_use(update):
            return

        if len(context.args) != 1:
            await update.message.reply_text(
                "❌ استفاده: <code>/price SYMBOL</code>\n"
                "مثال: <code>/price xauusd</code>",
                parse_mode=ParseMode.HTML,
                reply_markup=KeyboardFactory.symbol_picker("price:show"),
            )
            return

        symbol = context.args[0].upper()
        price  = self.mt5.get_price(symbol)
        if price is None:
            await update.message.reply_text(
                f"❌ قیمت <b>{symbol}</b> دریافت نشد.", parse_mode=ParseMode.HTML
            )
            return

        real = self.mt5.get_resolved_symbol(symbol) or symbol
        await update.message.reply_text(
            self.price_text(real, price),
            parse_mode=ParseMode.HTML,
            reply_markup=KeyboardFactory.price_actions(real),
        )

    # ── /stats ────────────────────────────────────────────────────────────────

    async def stats(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not await self.can_use(update):
            return

        data = await self.db.get_stats()
        if not data:
            await update.message.reply_text(
                "📊 هیچ آلرت فعالی وجود ندارد.", reply_markup=KeyboardFactory.back_main()
            )
            return

        total = sum(data.values())
        lines = [f"📊 <b>آمار ZAlert</b>\n\n🔢 مجموع آلرت‌های فعال: <b>{total}</b>\n"]
        for sym, cnt in data.items():
            bar = "█" * min(cnt, 10) + "░" * (10 - min(cnt, 10))
            lines.append(f"<code>{sym:<10}</code>  [{bar}]  {cnt}")

        await update.message.reply_text(
            "\n".join(lines), parse_mode=ParseMode.HTML, reply_markup=KeyboardFactory.back_main()
        )

    # ── /status ───────────────────────────────────────────────────────────────

    async def server_status(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not await self.can_use(update):
            return
        await update.message.reply_text(
            await self.build_status_text(),
            parse_mode=ParseMode.HTML,
            reply_markup=KeyboardFactory.status_actions(),
        )

    async def build_status_text(self) -> str:
        """Reusable — called by both the command handler and the callback router."""
        try:
            await self.db.get_stats()
            db_ok = True
        except Exception:
            db_ok = False

        data  = await self.db.get_stats()
        total = sum(data.values()) if data else 0
        gold  = self.mt5.get_price("XAUUSD")

        return (
            f"🖥 <b>وضعیت سرور ZAlert</b>\n\n"
            f"{'─'*28}\n"
            f"🔌 MT5: {'🟢 متصل' if self.mt5.initialized else '🔴 قطع'}\n"
            f"🗄 دیتابیس: {'🟢 آنلاین' if db_ok else '🔴 خطا'}\n"
            f"⏱ آپتایم: <b>{self.uptime()}</b>\n"
            f"{'─'*28}\n"
            f"📊 آلرت‌های فعال: <b>{total}</b>\n"
            f"⏰ بررسی هر: <b>{config.CHECK_INTERVAL}s</b>\n"
            f"🥇 XAUUSD: {'<code>' + fmt_price(gold) + '</code>' if gold else '—'}\n"
            f"{'─'*28}\n"
            f"🕐 سرور: {now_tehran_full()}"
        )

    @staticmethod
    def price_text(symbol: str, price: float) -> str:
        """Reusable price message — used by command handler and callback router."""
        return (
            f"💰 <b>قیمت لحظه‌ای</b>\n\n"
            f"📊 نماد: <b>{symbol}</b>\n"
            f"💵 قیمت: <code>{fmt_price(price)}</code>\n"
            f"🕐 ساعت: {now_tehran()} (تهران)"
        )
