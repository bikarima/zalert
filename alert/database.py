"""
Database layer — MongoDB (pymongo sync)
سازگار با محیط‌های async/sync مختلط (FastAPI + python-telegram-bot)
"""

from datetime import datetime
from typing import List, Optional, Dict
import pytz
import pymongo
import config

_client: Optional[pymongo.MongoClient] = None
_db     = None

def get_db():
    global _client, _db
    if _client is None:
        _client = pymongo.MongoClient(config.MONGO_URI)
        _db     = _client[config.MONGO_DB]
        _ensure_indexes(_db)
    return _db

def _ensure_indexes(db):
    try:
        db.alerts.create_index([('user_id', 1), ('triggered', 1)])
        db.alerts.create_index([('seq_id', 1)], unique=True, sparse=True)
        db.user_devices.create_index([('push_token', 1)], unique=True)
        db.user_devices.create_index([('user_id', 1)])
        db.users.create_index([('user_id', 1)], unique=True)
        db.allowed_groups.create_index([('group_id', 1)], unique=True)
    except Exception:
        pass

def _now() -> str:
    return datetime.now(pytz.timezone('Asia/Tehran')).strftime('%Y-%m-%d %H:%M:%S')


class Database:

    # ── Allowed Groups ─────────────────────────────────────────────────

    def add_group(self, group_id: int, group_title: str) -> bool:
        get_db().allowed_groups.update_one(
            {'group_id': group_id},
            {'$set': {'group_id': group_id, 'group_title': group_title, 'added_at': _now()}},
            upsert=True)
        return True

    def remove_group(self, group_id: int) -> bool:
        r = get_db().allowed_groups.delete_one({'group_id': group_id})
        return r.deleted_count > 0

    def is_allowed_group(self, group_id: int) -> bool:
        return get_db().allowed_groups.find_one({'group_id': group_id}) is not None

    def get_all_groups(self) -> List[Dict]:
        return list(get_db().allowed_groups.find({}, {'_id': 0}).sort('added_at', 1))

    # ── Users & Devices ────────────────────────────────────────────────

    def upsert_user(self, user_id: int, username: str = None,
                    push_token: str = None, platform: str = None,
                    device_name: str = None):
        db  = get_db()
        now = _now()
        db.users.update_one(
            {'user_id': user_id},
            {'$set': {'last_seen': now},
             '$setOnInsert': {'user_id': user_id, 'registered_at': now}},
            upsert=True)
        if username:
            db.users.update_one({'user_id': user_id}, {'$set': {'username': username}})
        if push_token:
            db.user_devices.update_one(
                {'push_token': push_token},
                {'$set': {'user_id': user_id, 'push_token': push_token,
                          'platform': platform, 'device_name': device_name,
                          'last_used': now},
                 '$setOnInsert': {'added_at': now}},
                upsert=True)

    def get_user(self, user_id: int) -> Optional[Dict]:
        return get_db().users.find_one({'user_id': user_id}, {'_id': 0})

    def get_user_devices(self, user_id: int) -> List[Dict]:
        return list(get_db().user_devices.find(
            {'user_id': user_id}, {'_id': 0}).sort('last_used', -1))

    def get_push_tokens(self, user_id: int) -> List[str]:
        return [d['push_token'] for d in self.get_user_devices(user_id)
                if d.get('push_token')]

    def get_push_token(self, user_id: int) -> Optional[str]:
        tokens = self.get_push_tokens(user_id)
        return tokens[0] if tokens else None

    def remove_device(self, user_id: int, push_token: str) -> bool:
        r = get_db().user_devices.delete_one(
            {'user_id': user_id, 'push_token': push_token})
        return r.deleted_count > 0

    def remove_all_devices(self, user_id: int) -> int:
        r = get_db().user_devices.delete_many({'user_id': user_id})
        return r.deleted_count

    # ── Alerts ─────────────────────────────────────────────────────────

    def add_alert(self, user_id: int, username: str, symbol: str,
                  target_price: float, alert_type: str,
                  group_id: int = 0) -> int:
        db  = get_db()
        counter = db.counters.find_one_and_update(
            {'_id': 'alert_id'}, {'$inc': {'seq': 1}},
            upsert=True, return_document=pymongo.ReturnDocument.AFTER)
        seq = counter['seq']
        db.alerts.insert_one({
            'seq_id': seq, 'user_id': user_id, 'username': username,
            'group_id': group_id, 'symbol': symbol.upper(),
            'target_price': target_price, 'alert_type': alert_type,
            'created_at': _now(), 'triggered': False, 'triggered_at': None,
        })
        return seq

    def get_user_alerts(self, user_id: int,
                        include_triggered: bool = False) -> List[Dict]:
        query = {'user_id': user_id}
        if not include_triggered:
            query['triggered'] = False
        docs = list(get_db().alerts.find(query, {'_id': 0}).sort('created_at', -1))
        for d in docs: d['id'] = d.get('seq_id', 0)
        return docs

    def get_alert_by_id(self, alert_id: int) -> Optional[Dict]:
        doc = get_db().alerts.find_one({'seq_id': alert_id}, {'_id': 0})
        if doc: doc['id'] = doc.get('seq_id', 0)
        return doc

    def get_all_active_alerts(self) -> List[Dict]:
        docs = list(get_db().alerts.find({'triggered': False}, {'_id': 0}))
        for d in docs: d['id'] = d.get('seq_id', 0)
        return docs

    def delete_alert(self, alert_id: int, user_id: int) -> bool:
        r = get_db().alerts.delete_one({'seq_id': alert_id, 'user_id': user_id})
        return r.deleted_count > 0

    def clear_user_alerts(self, user_id: int) -> int:
        r = get_db().alerts.delete_many({'user_id': user_id, 'triggered': False})
        return r.deleted_count

    def mark_triggered(self, alert_id: int):
        get_db().alerts.update_one(
            {'seq_id': alert_id},
            {'$set': {'triggered': True, 'triggered_at': _now()}})

    def get_stats(self) -> Dict[str, int]:
        pipeline = [
            {'$match': {'triggered': False}},
            {'$group': {'_id': '$symbol', 'count': {'$sum': 1}}},
            {'$sort': {'count': -1}}
        ]
        return {d['_id']: d['count'] for d in get_db().alerts.aggregate(pipeline)}

    def count_user_alerts(self, user_id: int) -> int:
        return get_db().alerts.count_documents(
            {'user_id': user_id, 'triggered': False})
