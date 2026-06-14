"""
CalendarNotifier — fires 30 min before High Impact economic events.
Runs every 5 minutes via job_queue.run_repeating(interval=300).

Async correctness notes:
  - Group sends run in parallel via asyncio.gather (not sequential).
  - A key is added to _sent ONLY after ≥1 group was successfully notified.
    If all sends fail the event is retried on the next tick.
  - datetime.now(pytz.utc) replaces the deprecated datetime.utcnow().
  - dateutil dp.parse() is CPU-bound; runs in the default thread executor
    so it never blocks the event loop.
"""
import asyncio
import logging
from datetime import datetime
from typing import Set

import pytz
from dateutil import parser as dp
from telegram.constants import ParseMode
from telegram.ext import ContextTypes

from database         import Database
from calendar_handler import get_high_impact_events
from utils            import TEHRAN

log = logging.getLogger("CalendarNotifier")

# Notification window (minutes before event)
NOTIFY_MIN_BEFORE = 25.0
NOTIFY_MAX_BEFORE = 35.0
CLEANUP_AFTER     = -120.0  # remove key when event is >2h in the past


class CalendarNotifier:
    """
    Checks for upcoming High Impact events every 5 minutes.
    Sends one warning per event, ~30 minutes in advance.
    """

    def __init__(self, db: Database) -> None:
        self.db    = db
        self._sent: Set[str] = set()

    async def run(self, context: ContextTypes.DEFAULT_TYPE) -> None:
        groups = await self.db.get_all_groups()
        if not groups:
            return

        try:
            events = await get_high_impact_events(user_tz="Asia/Tehran")
        except Exception:
            log.exception("failed to fetch high-impact events")
            return

        # FIX: datetime.now(pytz.utc) — replaces deprecated datetime.utcnow()
        now_utc = datetime.now(pytz.utc)

        for event in events:
            if not event.get("time_utc"):
                continue

            key = event["id"]

            # FIX: dp.parse is CPU-bound — run in thread executor, never block event loop
            try:
                loop      = asyncio.get_event_loop()
                event_utc = await loop.run_in_executor(None, dp.parse, event["time_utc"])
                if not event_utc.tzinfo:
                    event_utc = event_utc.replace(tzinfo=pytz.utc)
            except Exception:
                log.warning("could not parse time_utc for event id=%s", key)
                continue

            diff_min = (event_utc - now_utc).total_seconds() / 60

            if NOTIFY_MIN_BEFORE <= diff_min <= NOTIFY_MAX_BEFORE:
                if key not in self._sent:
                    # FIX: add to _sent ONLY after ≥1 successful send.
                    # If all sends fail we leave key out of _sent so the next
                    # tick retries — as long as it’s still in the 25–35 min window.
                    sent_count = await self._notify(context, groups, event, event_utc)
                    if sent_count > 0:
                        self._sent.add(key)
                    else:
                        log.warning(
                            "all sends failed for event=%s — will retry next tick",
                            event["title"],
                        )

            elif diff_min < CLEANUP_AFTER:
                self._sent.discard(key)   # keep set from growing

    async def _notify(
        self,
        context,
        groups: list,
        event: dict,
        event_utc: datetime,
    ) -> int:
        """
        Send notification to all groups in parallel.
        Returns the number of successful sends.
        """
        et = event_utc.astimezone(TEHRAN).strftime("%H:%M")

        text = (
            f"📅 <b>هشدار تقویم اقتصادی!</b>\n\n"
            f"🔴 <b>{event['title']}</b>\n"
            f"🌍 کشور: <b>{event['currency']}</b>\n"
            f"🕐 ساعت: <b>{et}</b> (تهران)\n"
            f"⏰ تا شروع: <b>~۳۰ دقیقه</b>"
        )
        if event.get("forecast") or event.get("previous"):
            text += (
                f"\n\n📊 پیش‌بینی: <b>{event.get('forecast', '—')}</b>"
                f"  |  قبلی: <b>{event.get('previous', '—')}</b>"
            )
        text += "\n\n⚠️ مراقب نوسانات باشید!"

        # FIX: send to all groups in parallel, not sequentially
        async def _send(group_id: int) -> bool:
            try:
                await context.bot.send_message(
                    chat_id=group_id, text=text, parse_mode=ParseMode.HTML
                )
                return True
            except Exception:
                log.exception("failed to notify group=%s", group_id)
                return False

        results   = await asyncio.gather(*[_send(g["group_id"]) for g in groups])
        sent      = sum(results)
        log.info(
            "calendar notif: event=%s groups=%d/%d",
            event["title"], sent, len(groups),
        )
        return sent
