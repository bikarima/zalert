"""
Database layer — MongoDB (motor async) — fully async
"""

from datetime import datetime
from typing import List, Optional, Dict
import pytz
import motor.motor_asyncio
import config

_client = None
_db     = None

def get_db():
    global _client, _db
    if _client is None:
        _client = motor.motor_asyncio.AsyncIOMotorClient(config.MONGO_URI)
        _db     = _client[config.MONGO_DB]
    return _db

def _now() -> str:
    return datetime.now(pytz.timezone('Asia/Tehran')).strftime('%Y-%m-%d %H:%M:%S')


class Database:

    # ── Allowed Groups ─────────────────────────────────────────────────

    async def add_group(self, group_id: int, group_title: str) -> bool:
        await get_db().allowed_groups.update_one(
            {'group_id': group_id},
            {'$set': {'group_id': group_id, 'group_title': group_title, 'added_at': _now()}},
            upsert=True)
        return True

    async def remove_group(self, group_id: int) -> bool:
        r = await get_db().allowed_groups.delete_one({'group_id': group_id})
        return r.deleted_count > 0

    async def is_allowed_group(self, group_id: int) -> bool:
        doc = await get_db().allowed_groups.find_one({'group_id': group_id})
        return doc is not None

    async def get_all_groups(self) -> List[Dict]:
        return await get_db().allowed_groups.find({}, {'_id': 0}).sort('added_at', 1).to_list(None)

    # ── Users & Devices ────────────────────────────────────────────────

    async def upsert_user(self, user_id: int, username: str = None,
                          push_token: str = None, platform: str = None,
                          device_name: str = None):
        db  = get_db()
        now = _now()
        await db.users.update_one(
            {'user_id': user_id},
            {'$set': {'last_seen': now},
             '$setOnInsert': {'user_id': user_id, 'registered_at': now}},
            upsert=True)
        if username:
            await db.users.update_one({'user_id': user_id}, {'$set': {'username': username}})
        if push_token:
            await db.user_devices.update_one(
                {'push_token': push_token},
                {'$set': {'user_id': user_id, 'push_token': push_token,
                          'platform': platform, 'device_name': device_name,
                          'last_used': now},
                 '$setOnInsert': {'added_at': now}},
                upsert=True)

    async def get_user(self, user_id: int) -> Optional[Dict]:
        return await get_db().users.find_one({'user_id': user_id}, {'_id': 0})

    async def get_user_devices(self, user_id: int) -> List[Dict]:
        return await get_db().user_devices.find(
            {'user_id': user_id}, {'_id': 0}).sort('last_used', -1).to_list(None)

    async def get_push_tokens(self, user_id: int) -> List[str]:
        devices = await self.get_user_devices(user_id)
        return [d['push_token'] for d in devices if d.get('push_token')]

    async def get_push_token(self, user_id: int) -> Optional[str]:
        tokens = await self.get_push_tokens(user_id)
        return tokens[0] if tokens else None

    async def remove_device(self, user_id: int, push_token: str) -> bool:
        r = await get_db().user_devices.delete_one(
            {'user_id': user_id, 'push_token': push_token})
        return r.deleted_count > 0

    async def remove_all_devices(self, user_id: int) -> int:
        r = await get_db().user_devices.delete_many({'user_id': user_id})
        return r.deleted_count

    # ── Alerts ─────────────────────────────────────────────────────────

    async def add_alert(self, user_id: int, username: str, symbol: str,
                        target_price: float, alert_type: str,
                        group_id: int = 0) -> int:
        db  = get_db()
        doc = {
            'user_id': user_id, 'username': username, 'group_id': group_id,
            'symbol': symbol.upper(), 'target_price': target_price,
            'alert_type': alert_type, 'created_at': _now(),
            'triggered': False, 'triggered_at': None,
        }
        await db.alerts.insert_one(doc)
        counter = await db.counters.find_one_and_update(
            {'_id': 'alert_id'}, {'$inc': {'seq': 1}},
            upsert=True, return_document=True)
        seq = counter['seq']
        await db.alerts.update_one({'_id': doc['_id']}, {'$set': {'seq_id': seq}})
        return seq

    async def get_user_alerts(self, user_id: int,
                               include_triggered: bool = False) -> List[Dict]:
        query = {'user_id': user_id}
        if not include_triggered:
            query['triggered'] = False
        docs = await get_db().alerts.find(query, {'_id': 0}).sort('created_at', -1).to_list(None)
        for d in docs: d['id'] = d.get('seq_id', 0)
        return docs

    async def get_alert_by_id(self, alert_id: int) -> Optional[Dict]:
        doc = await get_db().alerts.find_one({'seq_id': alert_id}, {'_id': 0})
        if doc: doc['id'] = doc.get('seq_id', 0)
        return doc

    async def get_all_active_alerts(self) -> List[Dict]:
        docs = await get_db().alerts.find({'triggered': False}, {'_id': 0}).to_list(None)
        for d in docs: d['id'] = d.get('seq_id', 0)
        return docs

    async def delete_alert(self, alert_id: int, user_id: int) -> bool:
        r = await get_db().alerts.delete_one({'seq_id': alert_id, 'user_id': user_id})
        return r.deleted_count > 0

    async def clear_user_alerts(self, user_id: int) -> int:
        r = await get_db().alerts.delete_many({'user_id': user_id, 'triggered': False})
        return r.deleted_count

    async def mark_triggered(self, alert_id: int):
        await get_db().alerts.update_one(
            {'seq_id': alert_id},
            {'$set': {'triggered': True, 'triggered_at': _now()}})

    async def get_stats(self) -> Dict[str, int]:
        pipeline = [
            {'$match': {'triggered': False}},
            {'$group': {'_id': '$symbol', 'count': {'$sum': 1}}},
            {'$sort': {'count': -1}}
        ]
        docs = await get_db().alerts.aggregate(pipeline).to_list(None)
        return {d['_id']: d['count'] for d in docs}

    async def count_user_alerts(self, user_id: int) -> int:
        return await get_db().alerts.count_documents(
            {'user_id': user_id, 'triggered': False})

    async def ensure_indexes(self):
        db = get_db()
        await db.alerts.create_index([('user_id', 1), ('triggered', 1)])
        await db.alerts.create_index([('seq_id', 1)], unique=True, sparse=True)
        await db.user_devices.create_index([('push_token', 1)], unique=True)
        await db.user_devices.create_index([('user_id', 1)])
        await db.users.create_index([('user_id', 1)], unique=True)
        await db.allowed_groups.create_index([('group_id', 1)], unique=True)
