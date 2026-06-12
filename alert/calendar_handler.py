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
_CACHE_TTL = timedelta(minutes=60)  # افزایش از 30 به 60 دقیقه
_last_429: Optional[datetime] = None  # آخرین بار که 429 گرفتیم

FF_URL = 'https://nfs.faireconomy.media/ff_calendar_thisweek.json'

_RETRY_AFTER_429 = timedelta(minutes=15)  # بعد از 429، تا 15 دقیقه request نزن

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
    global _last_429
    now       = datetime.utcnow()
    cache_key = 'thisweek'

    # اگه cache معتبره برگردون
    if (
        cache_key in _cache
        and cache_key in _cache_time
        and now - _cache_time[cache_key] < _CACHE_TTL
    ):
        tz     = _get_tz(user_tz)
        return _post_process(_cache[cache_key], tz, now)

    # اگه 429 گرفتیم و هنوز 15 دقیقه نگذشته، cache قدیمی رو برگردون
    if _last_429 and now - _last_429 < _RETRY_AFTER_429:
        print(f"[Calendar] Rate limited — از cache استفاده میشه")
        tz = _get_tz(user_tz)
        return _post_process(_cache.get(cache_key, []), tz, now)

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.get(
                FF_URL,
                headers={'User-Agent': 'Mozilla/5.0'},
                follow_redirects=True,
            )

            if resp.status_code == 429:
                _last_429 = now
                print(f"[Calendar] 429 Rate Limit — از cache استفاده میشه")
                tz = _get_tz(user_tz)
                return _post_process(_cache.get(cache_key, []), tz, now)

            resp.raise_for_status()
            raw_cached = resp.json()
            _last_429  = None  # reset

    except Exception as e:
        if '429' not in str(e):
            print(f"[Calendar] خطا: {e}")
        tz = _get_tz(user_tz)
        return _post_process(_cache.get(cache_key, []), tz, now)

    _cache[cache_key]      = raw_cached
    _cache_time[cache_key] = now

    tz = _get_tz(user_tz)
    return _post_process(raw_cached, tz, now)


def _post_process(raw: List[Dict], tz: pytz.BaseTzInfo,
                   now: datetime) -> List[Dict]:
    """parse + فیلتر رویدادهای گذشته"""
    events    = _parse_events(raw, tz)
    now_local = datetime.now(tz)
    today_str = now_local.strftime('%Y-%m-%d')
    filtered  = []
    for e in events:
        if e['date'] < today_str:
            continue
        if e['date'] == today_str and e['time_utc']:
            try:
                from dateutil import parser as dp
                event_utc = dp.parse(e['time_utc']).replace(tzinfo=pytz.utc)
                if event_utc < now_local.astimezone(pytz.utc) - timedelta(minutes=30):
                    continue
            except Exception:
                pass
        filtered.append(e)
    return filtered


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