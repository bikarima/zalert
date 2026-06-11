import MetaTrader5 as mt5
from typing import Optional
import config

class MT5Handler:
    def __init__(self):
        self.initialized = False

    def initialize(self) -> bool:
        """اتصال به MT5"""
        if not mt5.initialize(timeout=config.MT5_TIMEOUT, portable=config.MT5_PORTABLE):
            print(f"خطا در اتصال به MT5: {mt5.last_error()}")
            return False
        self.initialized = True
        print("✅ اتصال به MT5 برقرار شد")
        return True

    def resolve_symbol(self, symbol: str) -> Optional[str]:
        """
        نماد واقعی در MT5 رو پیدا میکنه.
        اگه کاربر XAUUSD بنویسه و بروکر XAUUSD.c داشته باشه، همون رو برمیگردونه.
        اولویت: تطابق دقیق > شروع با نماد > حاوی نماد
        """
        if not self.initialized:
            if not self.initialize():
                return None

        symbol = symbol.upper()

        # اول تطابق دقیق رو چک کن
        info = mt5.symbol_info(symbol)
        if info is not None:
            return symbol

        # بگرد توی همه نمادهای بروکر
        all_symbols = mt5.symbols_get()
        if all_symbols is None:
            return None

        # اول نمادهایی که دقیقاً با ورودی شروع میشن
        starts_with = [s.name for s in all_symbols if s.name.upper().startswith(symbol)]
        if starts_with:
            return starts_with[0]

        # بعد نمادهایی که ورودی رو در خودشون دارن (مثل پیشوند: mXAUUSD)
        contains = [s.name for s in all_symbols if symbol in s.name.upper()]
        if contains:
            return contains[0]

        return None

    def get_price(self, symbol: str) -> Optional[float]:
        """دریافت قیمت فعلی نماد — نماد رو خودکار resolve و select میکنه"""
        if not self.initialized:
            if not self.initialize():
                return None

        real_symbol = self.resolve_symbol(symbol)
        if real_symbol is None:
            print(f"نماد {symbol} در MT5 پیدا نشد")
            return None

        if real_symbol.upper() != symbol.upper():
            print(f"نماد {symbol} → {real_symbol} (resolve شد)")

        # اگه نماد select نشده، اضافه‌اش کن
        info = mt5.symbol_info(real_symbol)
        if info is not None and not info.select:
            mt5.symbol_select(real_symbol, True)

        tick = mt5.symbol_info_tick(real_symbol)
        if tick is None:
            print(f"خطا در دریافت قیمت {real_symbol}: {mt5.last_error()}")
            return None

        return tick.bid

    def get_resolved_symbol(self, symbol: str) -> Optional[str]:
        """فقط نام واقعی نماد رو برمیگردونه بدون قیمت"""
        return self.resolve_symbol(symbol)

    def shutdown(self):
        """قطع اتصال از MT5"""
        if self.initialized:
            mt5.shutdown()
            self.initialized = False
            print("🔌 اتصال MT5 قطع شد")
