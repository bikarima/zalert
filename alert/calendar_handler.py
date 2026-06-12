"""
تقویم اقتصادی از Forex Factory
فرمت JSON:
{
  "title": "...",
  "country": "USD",
  "date": "2026-06-08T01:00:00-04:00",
  "impact": "High" | "Medium" | "Low" | "Holiday" | "Non-Economic",
  "forecast": "3.4%",
  "previous": "3.2%",
  "actual": ""
}
نکته: FF فقط thisweek JSON داره. برای today_only داده همین هفته فیلتر میشه.
"""

import httpx
from datetime import datetime, timedelta
from typing import List, Dict, Optional
from dateutil import parser as dateutil_parser
import pytz

_cache: Dict[str, List[Dict]] = {}
_cache_time: Dict[str, datetime] = {}
_CACHE_TTL = timedelta(minutes=30)

FF_URL = 'https://nfs.faireconomy.media/ff_calendar_thisweek.json'

IMPACT_MAP = {
    'High':         'high',
    'Medium':       'medium',
    'Low':          'low',
    'Holiday':      'holiday',
    'Non-Economic': 'non_economic',
}


def _get_tz(user_tz: Optional[str]) -> pytz.BaseTzInfo:
    if user_tz:
        try:
            return pytz.timezone(user_tz)
        except Exception:
            pass
    return pytz.timezone('Asia/Tehran')


async def fetch_calendar(week: str = 'thisweek',
                         user_tz: Optional[str] = None) -> List[Dict]:
    """دریافت تقویم هفته جاری با cache"""
    now       = datetime.utcnow()
    cache_key = 'thisweek'  # FF فقط thisweek داره

    if (
        cache_key in _cache
        and cache_key in _cache_time
        and now - _cache_time[cache_key] < _CACHE_TTL
    ):
        raw_cached = _cache[cache_key]
    else:
        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.get(
                    FF_URL,
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

    tz     = _get_tz(user_tz)
    events = _parse_events(raw_cached, tz)

    # فقط امروز و روزهای بعد
    today  = datetime.now(tz).date()
    events = [e for e in events if e['date'] >= today.strftime('%Y-%m-%d')]

    return events


def _parse_events(raw: List[Dict], tz: pytz.BaseTzInfo) -> List[Dict]:
    events = []
    for item in raw:
        try:
            date_iso     = item.get('date', '')
            impact       = item.get('impact', '')
            date_display = ''
            time_display = 'All Day'
            iso_utc      = ''

            if date_iso:
                dt_parsed    = dateutil_parser.parse(date_iso)
                dt_utc       = dt_parsed.astimezone(pytz.utc)
                dt_local     = dt_utc.astimezone(tz)
                date_display = dt_local.strftime('%Y-%m-%d')
                time_display = dt_local.strftime('%H:%M')
                iso_utc      = dt_utc.strftime('%Y-%m-%dT%H:%M:%SZ')

            events.append({
                'id':       item.get('id', date_iso + item.get('title', '')),
                'title':    item.get('title', ''),
                'currency': item.get('country', ''),
                'date':     date_display,
                'time':     time_display,
                'time_utc': iso_utc,
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
