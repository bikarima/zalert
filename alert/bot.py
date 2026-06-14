"""
ZAlert Bot — v3.1 (Admin Panel)
=================================

Architecture:
    ZAlertBot
    ├── handlers/
    │   ├── UserHandlers      /start, /help
    │   ├── AlertHandlers     /set, /list, /delete, /clear, /history
    │   ├── MarketHandlers    /price, /stats, /status
    │   ├── AdminHandlers     full admin panel (see below)
    │   └── CallbackRouter    all inline-keyboard callbacks
    └── jobs/
        ├── AlertChecker      price watcher
        ├── MorningReport     daily 08:00 Tehran briefing
        └── CalendarNotifier  30-min High Impact warnings

Admin commands (/admin for the full inline panel):
  /admin            Main admin control panel
  /adminhelp        Full admin command list
  /addgroup         Whitelist current group
  /removegroup [ID] Remove group from whitelist
  /groups           List whitelisted groups
  /users            List recent users
  /userinfo ID      User detail + actions
  /ban ID [reason]  Ban a user
  /unban ID         Unban a user
  /banned           List all banned users
  /alertsall        All active alerts system-wide
  /delany ID        Delete any alert (admin override)
  /clearall         Clear ALL active alerts
  /broadcast TEXT   Send message to all groups
  /mt5reconnect     Reconnect MT5
  /setmax N         Set max alerts per user
"""
import datetime as dt
import logging
import threading

import pytz
import uvicorn
from telegram import Update
from telegram.ext import Application, CallbackQueryHandler, CommandHandler

import config
from logger      import setup_logging, get_logger
from database    import Database
from mt5_handler import MT5Handler
from api         import api, set_bot_app

from handlers import (
    UserHandlers,
    AlertHandlers,
    MarketHandlers,
    AdminHandlers,
    CallbackRouter,
)
from jobs import AlertChecker, MorningReport, CalendarNotifier


class ZAlertBot:
    """Central orchestrator — instantiate once, call .run()."""

    def __init__(self) -> None:
        self.log        = get_logger("ZAlertBot")
        self.start_time = dt.datetime.now(pytz.timezone("Asia/Tehran"))

        self.db  = Database()
        self.mt5 = MT5Handler()

        _deps = (self.db, self.mt5, self.start_time)

        self.user_h   = UserHandlers(*_deps)
        self.alert_h  = AlertHandlers(*_deps)
        self.market_h = MarketHandlers(*_deps)
        self.admin_h  = AdminHandlers(*_deps)
        self.cb_h     = CallbackRouter(*_deps, market=self.market_h, admin=self.admin_h)

        self.checker   = AlertChecker(self.db, self.mt5)
        self.morning   = MorningReport(self.db, self.mt5)
        self.cal_notif = CalendarNotifier(self.db)

        self.log.info("ZAlertBot v3.1 initialised")

    def _register_handlers(self, app: Application) -> None:
        add = app.add_handler

        # ── User ──────────────────────────────────────────────────────────
        add(CommandHandler("start",   self.user_h.start))
        add(CommandHandler("help",    self.user_h.help_command))

        # ── Alerts ────────────────────────────────────────────────────────
        add(CommandHandler("set",     self.alert_h.set_alert))
        add(CommandHandler("list",    self.alert_h.list_alerts))
        add(CommandHandler("delete",  self.alert_h.delete_alert))
        add(CommandHandler("clear",   self.alert_h.clear_alerts))
        add(CommandHandler("history", self.alert_h.history))

        # ── Market ────────────────────────────────────────────────────────
        add(CommandHandler("price",   self.market_h.get_price))
        add(CommandHandler("stats",   self.market_h.stats))
        add(CommandHandler("status",  self.market_h.server_status))

        # ── Admin — panel & help ──────────────────────────────────────────
        add(CommandHandler("admin",        self.admin_h.admin_panel))
        add(CommandHandler("adminhelp",    self.admin_h.admin_help))

        # ── Admin — group management ──────────────────────────────────────
        add(CommandHandler("addgroup",     self.admin_h.add_group))
        add(CommandHandler("removegroup",  self.admin_h.remove_group))
        add(CommandHandler("groups",       self.admin_h.list_groups))

        # ── Admin — user management ───────────────────────────────────────
        add(CommandHandler("users",        self.admin_h.list_users))
        add(CommandHandler("userinfo",     self.admin_h.user_info))
        add(CommandHandler("ban",          self.admin_h.ban_user))
        add(CommandHandler("unban",        self.admin_h.unban_user))
        add(CommandHandler("banned",       self.admin_h.list_banned))

        # ── Admin — alert management ──────────────────────────────────────
        add(CommandHandler("alertsall",    self.admin_h.alerts_all))
        add(CommandHandler("delany",       self.admin_h.delete_any_alert))
        add(CommandHandler("clearall",     self.admin_h.clear_all))

        # ── Admin — system ────────────────────────────────────────────────
        add(CommandHandler("broadcast",    self.admin_h.broadcast))
        add(CommandHandler("mt5reconnect", self.admin_h.mt5_reconnect))
        add(CommandHandler("setmax",       self.admin_h.set_max_alerts))
        add(CommandHandler("adminstats",   self.admin_h.admin_stats))

        # ── Inline keyboards ──────────────────────────────────────────────
        add(CallbackQueryHandler(self.cb_h.route))

        self.log.info("handlers registered")

    def _register_jobs(self, app: Application) -> None:
        jq = app.job_queue
        jq.run_repeating(self.checker.run,   interval=config.CHECK_INTERVAL, first=10,  name="alert_checker")
        jq.run_repeating(self.cal_notif.run, interval=300, first=60,                    name="calendar_notifier")
        jq.run_daily(self.morning.run,       time=dt.time(4, 30, tzinfo=pytz.utc),      name="morning_report")
        self.log.info("background jobs scheduled")

    def _start_api(self) -> None:
        def _run() -> None:
            uvicorn.run(api, host=config.API_HOST, port=config.API_PORT, log_level="error")
        threading.Thread(target=_run, daemon=True, name="api-thread").start()
        self.log.info("REST API on %s:%s", config.API_HOST, config.API_PORT)

    def run(self) -> None:
        self.log.info("initialising MT5…")
        if not self.mt5.initialize():
            self.log.critical("MT5 init failed — aborting")
            return

        app = Application.builder().token(config.BOT_TOKEN).build()
        self._register_handlers(app)
        self._register_jobs(app)
        set_bot_app(app)
        self._start_api()

        self.log.info("polling — admin=%s interval=%ss", config.ADMIN_USER_ID, config.CHECK_INTERVAL)
        app.run_polling(allowed_updates=Update.ALL_TYPES)

    def shutdown(self) -> None:
        self.log.info("shutdown")
        self.mt5.shutdown()


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
