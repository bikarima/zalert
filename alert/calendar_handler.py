"""
تقویم اقتصادی از Forex Factory
داده رو از JSON عمومی آنها میگیره و cache میکنه
"""

import httpx
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Optional
import pytz

# cache برای جلوگیری از ریکوئست‌های زیاد
_cache: Optional[List[Dict]] = None
_cache_time: Optional[datetime] = None
_CACHE_TTL = timedelta(minutes=30)  # هر 30 دقیقه آپدیت

FF_URLS = {
    'thisweek': 'https://nfs.faireconomy.media/ff_calendar_thisweek.json',
    'nextweek': 'https://nfs.faireconomy.media/ff_calendar_nextweek.json',
}

IMPACT_MAP = {
    'High':    'high',
    'Medium':  'medium',
    'Low':     'low',
    'Holiday': 'holiday',
    'Non-Economic': 'non_economic',
}


async def fetch_calendar(week: str = 'thisweek') -> List[Dict]:
    """دریافت تقویم اقتصادی با cache"""
    global _cache, _cache_time

    now = datetime.utcnow()

    # اگه cache معتبره برگردون
    if (
        _cache is not None
        and _cache_time is not None
        and now - _cache_time < _CACHE_TTL
        and week == 'thisweek'
    ):
        return _cache

    url = FF_URLS.get(week, FF_URLS['thisweek'])

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.get(
                url,
                headers={'User-Agent': 'Mozilla/5.0 (compatible; AlertBot/1.0)'},
                follow_redirects=True,
            )
            resp.raise_for_status()
            raw: List[Dict] = resp.json()
    except Exception as e:
        print(f"[Calendar] خطا در دریافت تقویم: {e}")
        return _cache or []

    events = _parse_events(raw)

    if week == 'thisweek':
        _cache = events
        _cache_time = now

    return events


def _parse_events(raw: List[Dict]) -> List[Dict]:
    """تبدیل داده خام به فرمت تمیز"""
    events = []
    for item in raw:
        try:
            # تبدیل زمان
            date_str = item.get('date', '')
            time_str = item.get('time', '')

            # فرمت FF: "Jun 12, 2026" + "12:30am"
            dt_str = f"{date_str} {time_str}".strip()
            try:
                # تلاش برای parse کردن
                if time_str and time_str.lower() not in ('all day', 'tentative'):
                    dt = datetime.strptime(dt_str, '%b %d, %Y %I:%M%p')
                    dt = pytz.utc.localize(dt)
                    tehran = pytz.timezone('Asia/Tehran')
                    dt_tehran = dt.astimezone(tehran)
                    time_display = dt_tehran.strftime('%H:%M')
                    date_display = dt_tehran.strftime('%Y-%m-%d')
                else:
                    time_display = time_str or 'All Day'
                    date_display = date_str
            except Exception:
                time_display = time_str or ''
                date_display = date_str

            impact = item.get('impact', '')
            impact_key = IMPACT_MAP.get(impact, 'low')

            events.append({
                'id':         item.get('id', ''),
                'title':      item.get('name', ''),
                'currency':   item.get('currency', ''),
                'date':       date_display,
                'time':       time_display,
                'impact':     impact_key,       # high / medium / low / holiday
                'forecast':   item.get('forecast', ''),
                'previous':   item.get('previous', ''),
                'actual':     item.get('actual', ''),
                'url':        item.get('url', ''),
            })
        except Exception as e:
            print(f"[Calendar] خطا در parse رویداد: {e}")
            continue

    return events


async def get_today_events() -> List[Dict]:
    """فقط رویدادهای امروز"""
    all_events = await fetch_calendar('thisweek')
    tehran = pytz.timezone('Asia/Tehran')
    today = datetime.now(tehran).strftime('%Y-%m-%d')
    return [e for e in all_events if e['date'] == today]


async def get_high_impact_events(week: str = 'thisweek') -> List[Dict]:
    """فقط رویدادهای high impact"""
    all_events = await fetch_calendar(week)
    return [e for e in all_events if e['impact'] == 'high']
