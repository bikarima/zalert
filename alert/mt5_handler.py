import logging
import MetaTrader5 as mt5
from typing import Optional, List
import config

log = logging.getLogger("MT5Handler")

# نگاشت نمادهای رایج به نمادهای جایگزین
# اگه نماد اصلی پیدا نشد، از این لیست جستجو میکنیم
# نکته: الیاسها با توجه به بروکر متفاوت دارن — اگه قیمت اشتباهه نماد واقعی بروکرت رو بهش اضافه کن
# SYMBOL_ALIASES دیکشنری SYMBOL_OVERRIDES برای اینکه مستقیماً بگی نماد واقعی رو مپن
# مثل: SYMBOL_OVERRIDES = {'BTCUSD': 'BTCUSD#', 'USOIL': 'XTIUSD'}
SYMBOL_OVERRIDES: dict[str, str] = {
    # نماد رو به شکل واقعیش در بروکر بنویس
    # مثال: 'BTCUSD': 'BTCUSD#'
}

SYMBOL_ALIASES = {
    'BTCUSD': ['BTCUSD.', 'XBTUSD', 'BTCUSD#', 'BTC/USD', 'BTC'],
    'ETHUSD': ['ETHUSD.', 'ETHUSD#', 'ETH/USD', 'ETH'],
    'LTCUSD': ['LTCUSD.', 'LTC'],
    'XRPUSD': ['XRPUSD.', 'XRP'],
    'US500':  ['SPX500', 'SP500', 'US500.', 'US500M', 'SPXUSD', 'SPXC', 'USIDX'],
    'US30':   ['DOW', 'US30.', 'US30M', 'DJIA'],
    'NAS100': ['US100', 'NASDAQ', 'NDX', 'NAS100.', 'SNDX'],
    'DAX40':  ['DAX', 'GER40', 'GDAXIm'],
    'USOIL':  ['WTI', 'XTIUSD', 'USOIL.', 'OILUSD', 'OIL', 'WTID', 'OILU'],
    'UKOIL':  ['BRENT', 'UKOUSD', 'UKOIL.'],
    'XAUUSD': ['XAUUSD.', 'GOLD', 'GOLDUSD', 'XAUUSD#'],
    'XAGUSD': ['XAGUSD.', 'SILVER', 'SILVERUSD'],
}


class MT5Handler:
    def __init__(self):
        self.initialized   = False
        self._symbol_cache: dict[str, str] = {}
        self._symbols_cache: list[str]     = []
        self._init_count   = 0   # تعداد دفعات اتصال

    def initialize(self) -> bool:
        if not mt5.initialize(timeout=config.MT5_TIMEOUT, portable=config.MT5_PORTABLE):
            log.error("MT5 init failed: %s", mt5.last_error())
            return False
        self.initialized     = True
        self._symbols_cache  = []   # reset symbol list cache on reconnect
        self._init_count    += 1
        if self._init_count == 1:
            log.info("✅ MT5 متصل شد")
        else:
            log.debug("اتصال مجدد به MT5 (#%d)", self._init_count)
        return True

    def _get_all_symbol_names(self) -> List[str]:
        """لیست همه نمادها — با cache"""
        if not self._symbols_cache:
            syms = mt5.symbols_get()
            self._symbols_cache = [s.name for s in syms] if syms else []
        return self._symbols_cache

    def resolve_symbol(self, symbol: str) -> Optional[str]:
        """
        نماد واقعی رو در MT5 پیدا میکنه.
        اولویت:
          0. SYMBOL_OVERRIDES (مستقیم مپنی)
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

        # 0. override مستقیم
        if symbol_up in SYMBOL_OVERRIDES:
            return SYMBOL_OVERRIDES[symbol_up]

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
                        # فقط یکبار لاگ میکنیم (DEBUG نه INFO)
                        log.debug("نماد %s → %s (alias)", symbol, result)
                        return result

        # 4. شروع با نماد
        starts = [all_symbols[i] for i, s in enumerate(all_upper) if s.startswith(symbol_up)]
        if starts:
            result = starts[0]
            self._symbol_cache[symbol_up] = result
            if result.upper() != symbol_up:
                log.debug("نماد %s → %s (prefix)", symbol, result)
            return result

        # 5. حاوی نماد (بیس کارنسی)
        base = symbol_up.replace('USD', '').replace('EUR', '').replace('GBP', '')
        if len(base) >= 3:
            contains = [all_symbols[i] for i, s in enumerate(all_upper)
                       if base in s and 'USD' in s]
            if contains:
                result = contains[0]
                self._symbol_cache[symbol_up] = result
                log.debug("نماد %s → %s (contains)", symbol, result)
                return result

        log.warning("نماد %s در MT5 پیدا نشد", symbol)
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
            log.warning("خطا در دریافت قیمت %s: %s", real_symbol, mt5.last_error())
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
        starts   = [s for s in all_syms if s.upper().startswith(query_up)]
        contains = [s for s in all_syms if query_up in s.upper() and s not in starts]
        return (starts + contains)[:20]

    def shutdown(self):
        if self.initialized:
            mt5.shutdown()
            self.initialized = False
            log.info("🔌 MT5 قطع شد")
