"""
MorningReport — daily 08:00 Tehran briefing for all allowed groups.
Scheduled via job_queue.run_daily(time=04:30 UTC).
"""
import asyncio
import logging
from datetime import datetime
from datetime import datetime

from telegram.constants import ParseMode
from telegram.ext import ContextTypes

from database        import Database
from mt5_handler     import MT5Handler
from calendar_handler import get_today_events
from keyboards       import POPULAR_SYMBOLS
from utils           import fmt_price, WEEKDAY_FA, TEHRAN

log = logging.getLogger("MorningReport")


class MorningReport:
    """Broadcasts a morning market briefing to every allowed group."""

    def __init__(self, db: Database, mt5: MT5Handler) -> None:
        self.db  = db
        self.mt5 = mt5

    async def run(self, context: ContextTypes.DEFAULT_TYPE) -> None:
        groups = await self.db.get_all_groups()
        if not groups:
            log.debug("no allowed groups — skipping morning report")
            return

        text = await self._build()

        # FIX: send to all groups in parallel, not sequentially
        async def _send(group_id: int) -> bool:
            try:
                await context.bot.send_message(
                    chat_id=group_id, text=text, parse_mode=ParseMode.HTML
                )
                return True
            except Exception:
                log.exception("failed to send morning report to group=%s", group_id)
                return False

        results = await asyncio.gather(*[_send(g["group_id"]) for g in groups])
        sent    = sum(results)
        log.info("morning report: sent=%d/%d", sent, len(groups))

    async def _build(self) -> str:
        import config

        stats   = await self.db.get_stats()
        total   = sum(stats.values()) if stats else 0

        try:
            events      = await get_today_events(user_tz="Asia/Tehran")
            high_events = [e for e in events if e["impact"] == "high"]
        except Exception:
            log.exception("failed to fetch calendar for morning report")
            events = high_events = []

        now_th  = datetime.now(TEHRAN)
        weekday = WEEKDAY_FA.get(now_th.weekday(), "")
        today   = now_th.strftime("%Y-%m-%d")

        lines = [
            f"🌅 <b>گزارش صبحگاهی ZAlert</b>\n",
            f"📅 {weekday} — {today}\n",
            "─" * 28,
            f"📊 آلرت‌های فعال سیستم: <b>{total}</b>",
        ]

        if stats:
            lines.append("🔝 پرطرفدارترین نمادها:")
            for sym, cnt in list(stats.items())[:3]:
                lines.append(f"  • {sym}: {cnt} آلرت")

        lines.append("─" * 28)

        if high_events:
            lines.append(f"\n🔴 <b>رویدادهای مهم امروز ({len(high_events)} رویداد):</b>")
            for e in high_events[:6]:
                lines.append(f"  🔴 {e['time']} — <b>{e['title']}</b> ({e['currency']})")
        else:
            lines.append("\n✅ امروز رویداد High Impact نداریم — بازار آروم!")

        # Live prices for top 4 symbols
        price_lines = []
        for _, sym in POPULAR_SYMBOLS[:4]:
            p = self.mt5.get_price(sym)
            if p:
                price_lines.append(f"  <code>{sym:<10}</code> {fmt_price(p)}")
        if price_lines:
            lines += ["─" * 28, "📉 قیمت لحظه‌ای:"] + price_lines

        lines += ["─" * 28, "💡 معامله خوب! 🚀"]
        return "\n".join(lines)
