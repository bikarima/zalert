import MetaTrader5 as mt5
from typing import Optional, List
import config

# نگاشت نمادهای رایج به نمادهای جایگزین
# اگه نماد اصلی پیدا نشد، از این لیست جستجو میکنیم
SYMBOL_ALIASES = {
    'BTCUSD': ['BTC', 'BTCUSD.', 'XBTUSD', 'BTC/USD'],
    'ETHUSD': ['ETH', 'ETHUSD.', 'ETH/USD'],
    'LTCUSD': ['LTC', 'LTCUSD.'],
    'XRPUSD': ['XRP', 'XRPUSD.'],
    'US500':  ['US500', 'SPX500', 'SP500', 'USIDX', 'US500M', 'SPXC'],
    'US30':   ['US30', 'DOW', 'US30M', 'DJIA'],
    'NAS100': ['NAS100', 'NASDAQ', 'US100', 'NDX', 'SNDX'],
    'DAX40':  ['DAX40', 'DAX', 'GER40', 'GDAXIm'],
    'USOIL':  ['WTI', 'USOIL', 'OIL', 'WTID', 'OILU'],
    'UKOIL':  ['UKOIL', 'BRENT', 'UKOUSD'],
    'XAUUSD': ['XAUUSD', 'GOLD', 'GOLDUSD', 'XAUUSD.'],
    'XAGUSD': ['XAGUSD', 'SILVER', 'SILVERUSD'],
}


class MT5Handler:
    def __init__(self):
        self.initialized = False
        self._symbol_cache = {}  # cache resolved symbols

    def initialize(self) -> bool:
        if not mt5.initialize(timeout=config.MT5_TIMEOUT, portable=config.MT5_PORTABLE):
            print(f"خطا در اتصال به MT5: {mt5.last_error()}")
            return False
        self.initialized    = True
        self._symbols_cache = []  # reset cache
        print("✅ اتصال به MT5 برقرار شد")
        return True

    def _get_all_symbol_names(self) -> List[str]:
        """لیست همه نمادها — با cache"""
        if not hasattr(self, '_symbols_cache') or not self._symbols_cache:
            syms = mt5.symbols_get()
            self._symbols_cache = [s.name for s in syms] if syms else []
        return self._symbols_cache

    def resolve_symbol(self, symbol: str) -> Optional[str]:
        """
        نماد واقعی رو در MT5 پیدا میکنه.
        اولویت:
        1. cache
        2. تطابق دقیق
        3. alias map
        4. شروع با نماد
        5. حاوی نماد
        """
        if not self.initialized:
            if not self.initialize():
                return None

        symbol_up = symbol.upper()

        # 1. cache
        if symbol_up in self._symbol_cache:
            return self._symbol_cache[symbol_up]

        # 2. تطابق دقیق
        info = mt5.symbol_info(symbol_up)
        if info is not None:
            self._symbol_cache[symbol_up] = symbol_up
            return symbol_up

        all_symbols = self._get_all_symbol_names()
        all_upper   = [s.upper() for s in all_symbols]

        # 3. alias map
        if symbol_up in SYMBOL_ALIASES:
            for alias in SYMBOL_ALIASES[symbol_up]:
                alias_up = alias.upper()
                for i, s_up in enumerate(all_upper):
                    if s_up == alias_up or s_up.startswith(alias_up):
                        result = all_symbols[i]
                        self._symbol_cache[symbol_up] = result
                        print(f"نماد {symbol} → {result} (alias)")
                        return result

        # 4. شروع با نماد
        starts = [all_symbols[i] for i, s in enumerate(all_upper) if s.startswith(symbol_up)]
        if starts:
            result = starts[0]
            self._symbol_cache[symbol_up] = result
            if result.upper() != symbol_up:
                print(f"نماد {symbol} → {result} (prefix)")
            return result

        # 5. حاوی نماد (بیس کارنسی)
        base = symbol_up.replace('USD', '').replace('EUR', '').replace('GBP', '')
        if len(base) >= 3:
            contains = [all_symbols[i] for i, s in enumerate(all_upper)
                       if base in s and 'USD' in s]
            if contains:
                result = contains[0]
                self._symbol_cache[symbol_up] = result
                print(f"نماد {symbol} → {result} (contains)")
                return result

        print(f"نماد {symbol} در MT5 پیدا نشد")
        return None

    def get_price(self, symbol: str) -> Optional[float]:
        if not self.initialized:
            if not self.initialize():
                return None

        real_symbol = self.resolve_symbol(symbol)
        if real_symbol is None:
            return None

        # select کردن نماد اگه لازم باشه
        info = mt5.symbol_info(real_symbol)
        if info is not None and not info.select:
            mt5.symbol_select(real_symbol, True)

        tick = mt5.symbol_info_tick(real_symbol)
        if tick is None:
            print(f"خطا در دریافت قیمت {real_symbol}: {mt5.last_error()}")
            return None

        return tick.bid

    def get_resolved_symbol(self, symbol: str) -> Optional[str]:
        return self.resolve_symbol(symbol)

    def search_symbols(self, query: str) -> List[str]:
        """جستجوی نمادها برای autocomplete"""
        if not self.initialized:
            if not self.initialize():
                return []
        query_up = query.upper()
        all_syms = self._get_all_symbol_names()
        # اول exact starts_with، بعد contains
        starts   = [s for s in all_syms if s.upper().startswith(query_up)]
        contains = [s for s in all_syms if query_up in s.upper() and s not in starts]
        return (starts + contains)[:20]

    def shutdown(self):
        if self.initialized:
            mt5.shutdown()
            self.initialized = False
            print("🔌 اتصال MT5 قطع شد")
