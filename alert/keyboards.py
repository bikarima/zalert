"""
ZAlert — KeyboardFactory.

All InlineKeyboardMarkup builders live here.
Centralising keyboards means UI changes never touch handler logic —
just edit this file and every screen updates automatically.

Callback data follows the convention:  "domain:action[:param]"
  nav:main               → go back to main menu
  menu:new_alert         → open new alert flow
  menu:list              → show alert list
  menu:price             → open price picker
  menu:calendar          → show today's calendar
  menu:stats             → show system stats
  menu:profile           → show user profile
  menu:status            → show server status
  alert:view:<id>        → show alert detail
  alert:del:<id>         → delete alert
  alert:clear_confirm    → ask to confirm clear-all
  alert:clear_do         → execute clear-all
  newalert:<SYMBOL>      → symbol picked for new alert
  price:show:<SYMBOL>    → show price for symbol
  price:refresh:<SYMBOL> → refresh price (inline edit)
  price:set:<SYMBOL>     → prompt user to set an alert
"""
from telegram import InlineKeyboardButton, InlineKeyboardMarkup

from utils import fmt_price

# Popular symbols shown in quick-pick menus — order matters (most common first)
POPULAR_SYMBOLS: list[tuple[str, str]] = [
    ("🥇 طلا",    "XAUUSD"),
    ("🥈 نقره",   "XAGUSD"),
    ("💶 EUR/USD", "EURUSD"),
    ("🫙 نفت",    "USOIL"),
    ("📈 S&P500",  "US500"),
    ("🔷 BTC",    "BTCUSD"),
    ("💵 GBP/USD", "GBPUSD"),
    ("📊 NAS100",  "NAS100"),
]


class KeyboardFactory:
    """
    Static factory — every method returns an InlineKeyboardMarkup.
    No instance state; import the class and call its static methods directly.
    """

    # ── Main menu ─────────────────────────────────────────────────────────────

    @staticmethod
    def main_menu() -> InlineKeyboardMarkup:
        return InlineKeyboardMarkup([
            [
                InlineKeyboardButton("🔔 آلرت جدید",    callback_data="menu:new_alert"),
                InlineKeyboardButton("📋 آلرت‌های من",  callback_data="menu:list"),
            ],
            [
                InlineKeyboardButton("💰 قیمت لحظه‌ای", callback_data="menu:price"),
                InlineKeyboardButton("📅 تقویم امروز",  callback_data="menu:calendar"),
            ],
            [
                InlineKeyboardButton("📊 آمار کل",      callback_data="menu:stats"),
                InlineKeyboardButton("👤 پروفایل من",    callback_data="menu:profile"),
            ],
            [
                InlineKeyboardButton("🖥 وضعیت سرور",   callback_data="menu:status"),
            ],
        ])

    # ── Symbol picker ─────────────────────────────────────────────────────────

    @staticmethod
    def symbol_picker(action_prefix: str) -> InlineKeyboardMarkup:
        """
        2-column grid of POPULAR_SYMBOLS.
        Each button callback = f"{action_prefix}:{SYMBOL}"
        """
        rows: list[list[InlineKeyboardButton]] = []
        row:  list[InlineKeyboardButton]       = []
        for label, sym in POPULAR_SYMBOLS:
            row.append(InlineKeyboardButton(label, callback_data=f"{action_prefix}:{sym}"))
            if len(row) == 2:
                rows.append(row)
                row = []
        if row:
            rows.append(row)
        rows.append([InlineKeyboardButton("⬅️ بازگشت", callback_data="nav:main")])
        return InlineKeyboardMarkup(rows)

    # ── Alert list ────────────────────────────────────────────────────────────

    @staticmethod
    def alert_list(alerts: list[dict]) -> InlineKeyboardMarkup:
        """One row per alert: label button + 🗑 delete button, then footer."""
        rows: list[list[InlineKeyboardButton]] = []
        for a in alerts:
            emoji = "⬇️" if a["alert_type"] == "below" else "⬆️"
            rows.append([
                InlineKeyboardButton(
                    f"{emoji} {a['symbol']} @ {fmt_price(a['target_price'])}",
                    callback_data=f"alert:view:{a['id']}",
                ),
                InlineKeyboardButton("🗑", callback_data=f"alert:del:{a['id']}"),
            ])
        rows.append([
            InlineKeyboardButton("🗑 حذف همه",    callback_data="alert:clear_confirm"),
            InlineKeyboardButton("🏠 منوی اصلی", callback_data="nav:main"),
        ])
        return InlineKeyboardMarkup(rows)

    # ── Price actions ─────────────────────────────────────────────────────────

    @staticmethod
    def price_actions(symbol: str) -> InlineKeyboardMarkup:
        return InlineKeyboardMarkup([
            [
                InlineKeyboardButton("🔄 بروزرسانی", callback_data=f"price:refresh:{symbol}"),
                InlineKeyboardButton("🔔 آلرت بذار",  callback_data=f"price:set:{symbol}"),
            ],
            [InlineKeyboardButton("⬅️ بازگشت", callback_data="menu:price")],
        ])

    # ── Alert detail ──────────────────────────────────────────────────────────

    @staticmethod
    def alert_detail(alert_id: int) -> InlineKeyboardMarkup:
        return InlineKeyboardMarkup([[
            InlineKeyboardButton("🗑 حذف",      callback_data=f"alert:del:{alert_id}"),
            InlineKeyboardButton("⬅️ بازگشت", callback_data="menu:list"),
        ]])

    # ── Confirm clear ─────────────────────────────────────────────────────────

    @staticmethod
    def confirm_clear() -> InlineKeyboardMarkup:
        return InlineKeyboardMarkup([[
            InlineKeyboardButton("✅ بله، حذف کن", callback_data="alert:clear_do"),
            InlineKeyboardButton("❌ نه، برگرد",   callback_data="menu:list"),
        ]])

    # ── Server status ─────────────────────────────────────────────────────────

    @staticmethod
    def status_actions() -> InlineKeyboardMarkup:
        return InlineKeyboardMarkup([[
            InlineKeyboardButton("🔄 بروزرسانی", callback_data="menu:status"),
            InlineKeyboardButton("🏠 منوی اصلی", callback_data="nav:main"),
        ]])

    # ── Generic back ─────────────────────────────────────────────────────────

    @staticmethod
    def back_main() -> InlineKeyboardMarkup:
        return InlineKeyboardMarkup([[
            InlineKeyboardButton("🏠 منوی اصلی", callback_data="nav:main"),
        ]])
