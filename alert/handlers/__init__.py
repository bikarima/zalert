"""
handlers package — all Telegram command and callback handlers.

Import everything from here; bot.py only needs this package.
"""
from .user      import UserHandlers
from .alerts    import AlertHandlers
from .market    import MarketHandlers
from .admin     import AdminHandlers
from .callbacks import CallbackRouter

__all__ = [
    "UserHandlers",
    "AlertHandlers",
    "MarketHandlers",
    "AdminHandlers",
    "CallbackRouter",
]
