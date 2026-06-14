"""
ZAlert — Centralized logging configuration.
Call setup_logging() once at startup; use get_logger() everywhere else.
"""
import logging
import logging.handlers
import sys
from pathlib import Path


LOG_FORMAT  = "%(asctime)s | %(levelname)-8s | %(name)-24s | %(message)s"
DATE_FORMAT = "%Y-%m-%d %H:%M:%S"


def setup_logging(level: int = logging.INFO, log_file: str | None = None) -> None:
    """
    Configure root logger. Safe to call multiple times (force=True).

    Args:
        level:    Root log level (default INFO).
        log_file: Optional path for a rotating file handler (5 MB × 3 backups).
    """
    handlers: list[logging.Handler] = [logging.StreamHandler(sys.stdout)]

    if log_file:
        Path(log_file).parent.mkdir(parents=True, exist_ok=True)
        handlers.append(
            logging.handlers.RotatingFileHandler(
                log_file,
                maxBytes=5 * 1024 * 1024,
                backupCount=3,
                encoding="utf-8",
            )
        )

    logging.basicConfig(
        level=level,
        format=LOG_FORMAT,
        datefmt=DATE_FORMAT,
        handlers=handlers,
        force=True,
    )

    # Silence chatty third-party loggers
    for lib in ("httpx", "httpcore", "telegram", "uvicorn", "apscheduler", "motor"):
        logging.getLogger(lib).setLevel(logging.WARNING)


def get_logger(name: str) -> logging.Logger:
    """Return a named logger. Always call after setup_logging()."""
    return logging.getLogger(name)
