"""
AlertChecker — background job: fires when price reaches target.
Runs every CHECK_INTERVAL seconds via job_queue.run_repeating().
"""
import logging

from telegram.constants import ParseMode
from telegram.ext import ContextTypes

import config
from database    import Database
from mt5_handler import MT5Handler
from push        import send_alert_triggered_push
from utils       import fmt_price, direction_label, now_tehran_full

log = logging.getLogger("AlertChecker")


class AlertChecker:
    """
    Polls MT5 on every tick, compares against all active alerts,
    and fires notifications + push when a target is hit.
    """

    def __init__(self, db: Database, mt5: MT5Handler) -> None:
        self.db  = db
        self.mt5 = mt5

    async def run(self, context: ContextTypes.DEFAULT_TYPE) -> None:
        alerts = await self.db.get_all_active_alerts()
        if not alerts:
            return

        log.debug("tick: checking %d active alerts", len(alerts))

        for alert in alerts:
            symbol       = alert["symbol"]
            target_price = alert["target_price"]
            alert_type   = alert["alert_type"]
            group_id     = alert["group_id"]

            current_price = self.mt5.get_price(symbol)
            if current_price is None:
                log.warning("price unavailable for symbol=%s — skipping", symbol)
                continue

            triggered = (
                (alert_type == "below" and current_price <= target_price) or
                (alert_type == "above" and current_price >= target_price)
            )
            if not triggered:
                continue

            await self._fire(context, alert, current_price, group_id)

    async def _fire(self, context, alert: dict, current_price: float, group_id: int) -> None:
        """Send Telegram message + push notification for a triggered alert."""
        alert_id     = alert["id"]
        symbol       = alert["symbol"]
        target_price = alert["target_price"]
        alert_type   = alert["alert_type"]
        username     = alert["username"]

        user_mention = f"@{username}" if username else f"کاربر {alert['user_id']}"
        diff_pct     = abs(current_price - target_price) / target_price * 100

        text = (
            f"🔔 <b>آلرت #{alert_id} فعال شد!</b>\n\n"
            f"👤 {user_mention}\n\n"
            f"📊 نماد: <b>{symbol}</b>\n"
            f"🎯 هدف: <code>{fmt_price(target_price)}</code>\n"
            f"💵 قیمت فعلی: <code>{fmt_price(current_price)}</code>\n"
            f"📈 {direction_label(alert_type)} — <b>{diff_pct:.2f}%</b> تغییر\n"
            f"🕐 {now_tehran_full()}\n\n"
            f"✅ هدف گرفته شد! 🎯"
        )

        try:
            await context.bot.send_message(
                chat_id=group_id, text=text, parse_mode=ParseMode.HTML
            )
            await self.db.mark_triggered(alert_id)
            log.info(
                "alert triggered: id=%s symbol=%s user=%s price=%.5f",
                alert_id, symbol, alert["user_id"], current_price,
            )
        except Exception:
            log.exception("failed to send telegram alert id=%s", alert_id)
            return   # don't attempt push if telegram message failed

        # Push notification
        tokens = await self.db.get_push_tokens(alert["user_id"])
        if tokens:
            try:
                sent = await send_alert_triggered_push(
                    tokens=tokens,
                    symbol=symbol,
                    target_price=target_price,
                    current_price=current_price,
                    alert_type=alert_type,
                    alert_id=alert_id,
                )
                log.info("push sent: %d/%d tokens for alert id=%s", sent, len(tokens), alert_id)
            except Exception:
                log.exception("push failed for alert id=%s", alert_id)
        else:
            log.debug("no push tokens for user %s (alert id=%s)", alert["user_id"], alert_id)
