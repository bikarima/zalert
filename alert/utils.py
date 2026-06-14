"""
ZAlert — Shared utility functions.
Pure helpers with no side effects — safe to import anywhere.
"""
from datetime import datetime
import pytz

TEHRAN = pytz.timezone("Asia/Tehran")

WEEKDAY_FA: dict[int, str] = {
    0: "دوشنبه", 1: "سه‌شنبه", 2: "چهارشنبه",
    3: "پنج‌شنبه", 4: "جمعه", 5: "شنبه", 6: "یکشنبه",
}


# ── Time ──────────────────────────────────────────────────────────────────────

def now_tehran() -> str:
    """Current Tehran time as HH:MM:SS."""
    return datetime.now(TEHRAN).strftime("%H:%M:%S")


def now_tehran_full() -> str:
    """Current Tehran time as YYYY-MM-DD HH:MM:SS."""
    return datetime.now(TEHRAN).strftime("%Y-%m-%d %H:%M:%S")


# ── Formatting ────────────────────────────────────────────────────────────────

def fmt_price(price: float) -> str:
    """
    Human-readable price.
    ≥1000  → 2 decimals with comma  (e.g. 3,412.50)
    ≥1     → up to 5 sig. decimals  (e.g. 1.23456)
    <1     → up to 6 sig. decimals  (e.g. 0.000123)
    """
    if price >= 1_000:
        return f"{price:,.2f}"
    if price >= 1:
        return f"{price:.5f}".rstrip("0").rstrip(".")
    return f"{price:.6f}".rstrip("0").rstrip(".")


def direction_label(alert_type: str) -> str:
    """Human-readable alert direction label with emoji."""
    return "⬇️ کاهش" if alert_type == "below" else "⬆️ افزایش"


def progress_bar(current: float, target: float, alert_type: str, width: int = 10) -> str:
    """
    ASCII bar showing how close the current price is to the target.
    Returns an empty string on any error (never raises).
    """
    try:
        if alert_type == "above":
            ratio = min(current / target, 1.0) if target else 0.0
        else:
            ratio = min(target / current, 1.0) if current else 0.0
        filled = int(ratio * width)
        return f"[{'█' * filled}{'░' * (width - filled)}] {int(ratio * 100)}%"
    except Exception:
        return ""


def uptime_str(start_time: datetime) -> str:
    """Elapsed time since start_time as 'Xh Ym Zs'."""
    elapsed = datetime.now(TEHRAN) - start_time
    h, rem  = divmod(int(elapsed.total_seconds()), 3600)
    m, s    = divmod(rem, 60)
    return f"{h}h {m}m {s}s"
