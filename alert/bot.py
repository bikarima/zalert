"""
ZAlert Bot — v3 (Professional Refactor)
========================================

Architecture overview:

    ZAlertBot
    ├── Database          (motor / MongoDB async)
    ├── MT5Handler        (MetaTrader 5 price feed)
    │
    ├── handlers/         (one class per concern, all share BaseHandler)
    │   ├── UserHandlers      /start, /help
    │   ├── AlertHandlers     /set, /list, /delete, /clear, /history
    │   ├── MarketHandlers    /price, /stats, /status
    │   ├── AdminHandlers     /addgroup, /removegroup, /groups
    │   └── CallbackRouter    all inline-keyboard callbacks
    │
    └── jobs/             (independent, schedulable background tasks)
        ├── AlertChecker      fires when price hits target
        ├── MorningReport     daily 08:00 Tehran briefing
        └── CalendarNotifier  30-min High Impact event warnings

Adding a new feature:
  - New command?  Add a method to the appropriate handler class and
    register it in _register_handlers().
  - New background job?  Create jobs/<name>.py, add it to jobs/__init__.py,
    instantiate in __init__, schedule in _register_jobs().
  - New button?  Add to keyboards.py and handle in callbacks.py.
"""
import datetime as dt
import logging
import threading

import pytz
import uvicorn
from telegram import Update
from telegram.ext import Application, CallbackQueryHandler, CommandHandler

import config
from logger   import setup_logging, get_logger
from database import Database
from mt5_handler import MT5Handler
from api import api, set_bot_app

from handlers import (
    UserHandlers,
    AlertHandlers,
    MarketHandlers,
    AdminHandlers,
    CallbackRouter,
)
from jobs import AlertChecker, MorningReport, CalendarNotifier


class ZAlertBot:
    """
    Central orchestrator — single entry point for the entire bot.
    Instantiate once, then call .run() to start polling.
    """

    def __init__(self) -> None:
        self.log        = get_logger("ZAlertBot")
        self.start_time = dt.datetime.now(pytz.timezone("Asia/Tehran"))

        # ── Core services ──────────────────────────────────────────────────
        self.db  = Database()
        self.mt5 = MT5Handler()

        # ── Handler objects ────────────────────────────────────────────────
        _deps = (self.db, self.mt5, self.start_time)

        self.user_h   = UserHandlers(*_deps)
        self.alert_h  = AlertHandlers(*_deps)
        self.market_h = MarketHandlers(*_deps)
        self.admin_h  = AdminHandlers(*_deps)
        self.cb_h     = CallbackRouter(*_deps, market=self.market_h)

        # ── Background jobs ────────────────────────────────────────────────
        self.checker   = AlertChecker(self.db, self.mt5)
        self.morning   = MorningReport(self.db, self.mt5)
        self.cal_notif = CalendarNotifier(self.db)

        self.log.info("ZAlertBot initialised")

    # ── Handler registration ───────────────────────────────────────────────

    def _register_handlers(self, app: Application) -> None:
        add = app.add_handler

        # User
        add(CommandHandler("start",   self.user_h.start))
        add(CommandHandler("help",    self.user_h.help_command))

        # Alerts
        add(CommandHandler("set",     self.alert_h.set_alert))
        add(CommandHandler("list",    self.alert_h.list_alerts))
        add(CommandHandler("delete",  self.alert_h.delete_alert))
        add(CommandHandler("clear",   self.alert_h.clear_alerts))
        add(CommandHandler("history", self.alert_h.history))

        # Market
        add(CommandHandler("price",   self.market_h.get_price))
        add(CommandHandler("stats",   self.market_h.stats))
        add(CommandHandler("status",  self.market_h.server_status))

        # Admin
        add(CommandHandler("addgroup",    self.admin_h.add_group))
        add(CommandHandler("removegroup", self.admin_h.remove_group))
        add(CommandHandler("groups",      self.admin_h.list_groups))

        # Inline keyboards
        add(CallbackQueryHandler(self.cb_h.route))

        self.log.info("handlers registered")

    # ── Job registration ───────────────────────────────────────────────────

    def _register_jobs(self, app: Application) -> None:
        jq = app.job_queue

        # Alert checker — every CHECK_INTERVAL seconds
        jq.run_repeating(
            self.checker.run,
            interval=config.CHECK_INTERVAL,
            first=10,
            name="alert_checker",
        )

        # Calendar notifier — every 5 minutes
        jq.run_repeating(
            self.cal_notif.run,
            interval=300,
            first=60,
            name="calendar_notifier",
        )

        # Morning report — 08:00 Tehran = 04:30 UTC
        jq.run_daily(
            self.morning.run,
            time=dt.time(4, 30, tzinfo=pytz.utc),
            name="morning_report",
        )

        self.log.info("background jobs scheduled")

    # ── REST API (side-car thread) ─────────────────────────────────────────

    def _start_api(self) -> None:
        def _run() -> None:
            uvicorn.run(
                api,
                host=config.API_HOST,
                port=config.API_PORT,
                log_level="error",
            )

        thread = threading.Thread(target=_run, daemon=True, name="api-thread")
        thread.start()
        self.log.info("REST API started on %s:%s", config.API_HOST, config.API_PORT)

    # ── Entry point ────────────────────────────────────────────────────────

    def run(self) -> None:
        self.log.info("initialising MT5…")
        if not self.mt5.initialize():
            self.log.critical("MT5 initialisation failed — aborting")
            return

        app = Application.builder().token(config.BOT_TOKEN).build()

        self._register_handlers(app)
        self._register_jobs(app)

        set_bot_app(app)
        self._start_api()

        self.log.info(
            "polling started — admin=%s interval=%ss",
            config.ADMIN_USER_ID,
            config.CHECK_INTERVAL,
        )
        app.run_polling(allowed_updates=Update.ALL_TYPES)

    def shutdown(self) -> None:
        self.log.info("shutdown requested")
        self.mt5.shutdown()


# ── Entry point ────────────────────────────────────────────────────────────────

def main() -> None:
    setup_logging(level=logging.INFO, log_file="logs/zalert.log")
    bot = ZAlertBot()
    try:
        bot.run()
    except KeyboardInterrupt:
        pass
    finally:
        bot.shutdown()


if __name__ == "__main__":
    main()
