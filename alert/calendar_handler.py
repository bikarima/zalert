"""
تقویم اقتصادی از Forex Factory
فرمت واقعی JSON:
{
  "title": "...",
  "country": "USD",
  "date": "2026-06-08T01:00:00-04:00",
  "impact": "High" | "Medium" | "Low" | "Holiday" | "Non-Economic",
  "forecast": "3.4%",
  "previous": "3.2%",
  "actual": ""
}
"""

import httpx
from datetime import datetime, timedelta
from typing import List, Dict, Optional
from dateutil import parser as dateutil_parser
import pytz

_cache: Dict[str, List[Dict]] = {}
_cache_time: Dict[str, datetime] = {}
_CACHE_TTL = timedelta(minutes=30)

FF_URLS = {
    'thisweek': 'https://nfs.faireconomy.media/ff_calendar_thisweek.json',
    'nextweek': 'https://nfs.faireconomy.media/ff_calendar_nextweek.json',
}

IMPACT_MAP = {
    'High':         'high',
    'Medium':       'medium',
    'Low':          'low',
    'Holiday':      'holiday',
    'Non-Economic': 'non_economic',
}


def _get_tz(user_tz: Optional[str]) -> pytz.BaseTzInfo:
    """دریافت timezone — اگه invalid بود Tehran"""
    if user_tz:
        try:
            return pytz.timezone(user_tz)
        except Exception:
            pass
    return pytz.timezone('Asia/Tehran')


async def fetch_calendar(week: str = 'thisweek',
                         user_tz: Optional[str] = None) -> List[Dict]:
    """دریافت تقویم اقتصادی با cache (cache بدون timezone، تبدیل موقع برگشت)"""
    now = datetime.utcnow()

    # cache raw data (timezone-agnostic)
    cache_key = week
    if (
        cache_key in _cache
        and cache_key in _cache_time
        and now - _cache_time[cache_key] < _CACHE_TTL
    ):
        raw_cached = _cache[cache_key]
    else:
        url = FF_URLS.get(week, FF_URLS['thisweek'])
        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.get(
                    url,
                    headers={'User-Agent': 'Mozilla/5.0'},
                    follow_redirects=True,
                )
                resp.raise_for_status()
                raw_cached = resp.json()
        except Exception as e:
            print(f"[Calendar] خطا: {e}")
            raw_cached = _cache.get(cache_key, [])

        _cache[cache_key]      = raw_cached
        _cache_time[cache_key] = now

    tz = _get_tz(user_tz)
    return _parse_events(raw_cached, tz)


def _parse_events(raw: List[Dict], tz: pytz.BaseTzInfo) -> List[Dict]:
    events = []
    for item in raw:
        try:
            date_iso = item.get('date', '')
            impact   = item.get('impact', '')

            # زمان UTC
            dt_utc       = None
            date_display = ''
            time_display = 'All Day'
            iso_utc      = ''

            if date_iso:
                dt_parsed   = dateutil_parser.parse(date_iso)
                dt_utc      = dt_parsed.astimezone(pytz.utc)
                dt_local    = dt_utc.astimezone(tz)
                date_display = dt_local.strftime('%Y-%m-%d')
                time_display = dt_local.strftime('%H:%M')
                iso_utc      = dt_utc.strftime('%Y-%m-%dT%H:%M:%SZ')  # برای scheduled notif

            events.append({
                'id':       item.get('id', date_iso + item.get('title', '')),
                'title':    item.get('title', ''),
                'currency': item.get('country', ''),
                'date':     date_display,
                'time':     time_display,
                'time_utc': iso_utc,          # زمان UTC برای flutter
                'impact':   IMPACT_MAP.get(impact, 'low'),
                'forecast': item.get('forecast', '') or '',
                'previous': item.get('previous', '') or '',
                'actual':   item.get('actual',   '') or '',
                'url':      item.get('url', ''),
            })
        except Exception as e:
            print(f"[Calendar] parse error: {e}")
            continue

    return events


async def get_today_events(user_tz: Optional[str] = None) -> List[Dict]:
    all_events = await fetch_calendar('thisweek', user_tz=user_tz)
    tz    = _get_tz(user_tz)
    today = datetime.now(tz).strftime('%Y-%m-%d')
    return [e for e in all_events if e['date'] == today]


async def get_high_impact_events(week: str = 'thisweek',
                                  user_tz: Optional[str] = None) -> List[Dict]:
    all_events = await fetch_calendar(week, user_tz=user_tz)
    return [e for e in all_events if e['impact'] == 'high']
