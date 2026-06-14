"""
CalendarNotifier — fires 30 min before High Impact economic events.
Runs every 5 minutes via job_queue.run_repeating(interval=300).

Deduplication: an in-memory set (_sent) holds event IDs that have
already been notified. Keys are purged after the event is >2 hours old
so the set never grows unbounded between restarts.
"""
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

        now_utc = datetime.utcnow().replace(tzinfo=pytz.utc)

        for event in events:
            if not event.get("time_utc"):
                continue

            key = event["id"]

            try:
                event_utc = dp.parse(event["time_utc"])
                if not event_utc.tzinfo:
                    event_utc = event_utc.replace(tzinfo=pytz.utc)
            except Exception:
                log.warning("could not parse time_utc for event id=%s", key)
                continue

            diff_min = (event_utc - now_utc).total_seconds() / 60

            if NOTIFY_MIN_BEFORE <= diff_min <= NOTIFY_MAX_BEFORE:
                if key not in self._sent:
                    self._sent.add(key)
                    await self._notify(context, groups, event, event_utc)

            elif diff_min < CLEANUP_AFTER:
                self._sent.discard(key)   # keep set from growing

    async def _notify(
        self,
        context,
        groups: list,
        event: dict,
        event_utc: datetime,
    ) -> None:
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

        sent = 0
        for group in groups:
            try:
                await context.bot.send_message(
                    chat_id=group["group_id"], text=text, parse_mode=ParseMode.HTML
                )
                sent += 1
            except Exception:
                log.exception("failed to notify group=%s", group["group_id"])

        log.info(
            "calendar notif: event=%s groups=%d/%d",
            event["title"], sent, len(groups),
        )
