"""
Database layer — MongoDB (motor async)
Collections:
  alerts         — آلرت‌های قیمت
  users          — اطلاعات کاربران
  user_devices   — push token های هر کاربر
  allowed_groups — گروه‌های تلگرام مجاز
"""

import asyncio
from datetime import datetime
from typing import List, Optional, Dict, Any
import pytz
import motor.motor_asyncio
from bson import ObjectId
import config

# ── اتصال ────────────────────────────────────────────────────────────

_client: Optional[motor.motor_asyncio.AsyncIOMotorClient] = None
_db     = None

def get_db():
    global _client, _db
    if _client is None:
        _client = motor.motor_asyncio.AsyncIOMotorClient(config.MONGO_URI)
        _db     = _client[config.MONGO_DB]
    return _db

def _now_tehran() -> str:
    return datetime.now(pytz.timezone('Asia/Tehran')).strftime('%Y-%m-%d %H:%M:%S')


class Database:
    """Sync wrapper — همه متدها sync هستن، داخلشون asyncio.run میزنن"""

    # ── helper ────────────────────────────────────────────────────────

    def _run(self, coro):
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                import concurrent.futures
                with concurrent.futures.ThreadPoolExecutor() as pool:
                    future = pool.submit(asyncio.run, coro)
                    return future.result()
            else:
                return loop.run_until_complete(coro)
        except RuntimeError:
            return asyncio.run(coro)

    # ── Allowed Groups ─────────────────────────────────────────────────

    def add_group(self, group_id: int, group_title: str) -> bool:
        return self._run(self._add_group(group_id, group_title))

    async def _add_group(self, group_id: int, group_title: str) -> bool:
        db = get_db()
        await db.allowed_groups.update_one(
            {'group_id': group_id},
            {'$set': {'group_id': group_id, 'group_title': group_title,
                      'added_at': _now_tehran()}},
            upsert=True
        )
        return True

    def remove_group(self, group_id: int) -> bool:
        return self._run(self._remove_group(group_id))

    async def _remove_group(self, group_id: int) -> bool:
        db  = get_db()
        res = await db.allowed_groups.delete_one({'group_id': group_id})
        return res.deleted_count > 0

    def is_allowed_group(self, group_id: int) -> bool:
        return self._run(self._is_allowed_group(group_id))

    async def _is_allowed_group(self, group_id: int) -> bool:
        db  = get_db()
        doc = await db.allowed_groups.find_one({'group_id': group_id})
        return doc is not None

    def get_all_groups(self) -> List[Dict]:
        return self._run(self._get_all_groups())

    async def _get_all_groups(self) -> List[Dict]:
        db     = get_db()
        cursor = db.allowed_groups.find({}, {'_id': 0}).sort('added_at', 1)
        return await cursor.to_list(length=None)

    # ── Users & Devices ────────────────────────────────────────────────

    def upsert_user(self, user_id: int, username: str = None,
                    push_token: str = None, platform: str = None,
                    device_name: str = None):
        return self._run(self._upsert_user(user_id, username, push_token,
                                           platform, device_name))

    async def _upsert_user(self, user_id: int, username, push_token,
                            platform, device_name):
        db  = get_db()
        now = _now_tehran()

        # upsert user
        await db.users.update_one(
            {'user_id': user_id},
            {'$set': {'last_seen': now},
             '$setOnInsert': {'user_id': user_id, 'registered_at': now}},
            upsert=True
        )
        if username:
            await db.users.update_one(
                {'user_id': user_id}, {'$set': {'username': username}})

        # upsert device
        if push_token:
            await db.user_devices.update_one(
                {'push_token': push_token},
                {'$set': {'user_id': user_id, 'push_token': push_token,
                          'platform': platform, 'device_name': device_name,
                          'last_used': now},
                 '$setOnInsert': {'added_at': now}},
                upsert=True
            )

    def get_user(self, user_id: int) -> Optional[Dict]:
        return self._run(self._get_user(user_id))

    async def _get_user(self, user_id: int) -> Optional[Dict]:
        db  = get_db()
        doc = await db.users.find_one({'user_id': user_id}, {'_id': 0})
        return doc

    def get_user_devices(self, user_id: int) -> List[Dict]:
        return self._run(self._get_user_devices(user_id))

    async def _get_user_devices(self, user_id: int) -> List[Dict]:
        db     = get_db()
        cursor = db.user_devices.find(
            {'user_id': user_id}, {'_id': 0}).sort('last_used', -1)
        return await cursor.to_list(length=None)

    def get_push_tokens(self, user_id: int) -> List[str]:
        devices = self.get_user_devices(user_id)
        return [d['push_token'] for d in devices if d.get('push_token')]

    def get_push_token(self, user_id: int) -> Optional[str]:
        tokens = self.get_push_tokens(user_id)
        return tokens[0] if tokens else None

    def remove_device(self, user_id: int, push_token: str) -> bool:
        return self._run(self._remove_device(user_id, push_token))

    async def _remove_device(self, user_id, push_token) -> bool:
        db  = get_db()
        res = await db.user_devices.delete_one(
            {'user_id': user_id, 'push_token': push_token})
        return res.deleted_count > 0

    def remove_all_devices(self, user_id: int) -> int:
        return self._run(self._remove_all_devices(user_id))

    async def _remove_all_devices(self, user_id: int) -> int:
        db  = get_db()
        res = await db.user_devices.delete_many({'user_id': user_id})
        return res.deleted_count

    # ── Alerts ─────────────────────────────────────────────────────────

    def add_alert(self, user_id: int, username: str, symbol: str,
                  target_price: float, alert_type: str,
                  group_id: int = 0) -> int:
        return self._run(self._add_alert(
            user_id, username, symbol, target_price, alert_type, group_id))

    async def _add_alert(self, user_id, username, symbol,
                          target_price, alert_type, group_id) -> int:
        db  = get_db()
        doc = {
            'user_id':      user_id,
            'username':     username,
            'group_id':     group_id,
            'symbol':       symbol.upper(),
            'target_price': target_price,
            'alert_type':   alert_type,
            'created_at':   _now_tehran(),
            'triggered':    False,
            'triggered_at': None,
        }
        res = await db.alerts.insert_one(doc)
        # counter برای سازگاری با کد قدیمی
        counter = await db.counters.find_one_and_update(
            {'_id': 'alert_id'},
            {'$inc': {'seq': 1}},
            upsert=True,
            return_document=True
        )
        seq = counter['seq']
        await db.alerts.update_one({'_id': res.inserted_id},
                                    {'$set': {'seq_id': seq}})
        return seq

    def get_user_alerts(self, user_id: int,
                        include_triggered: bool = False) -> List[Dict]:
        return self._run(self._get_user_alerts(user_id, include_triggered))

    async def _get_user_alerts(self, user_id, include_triggered) -> List[Dict]:
        db     = get_db()
        query  = {'user_id': user_id}
        if not include_triggered:
            query['triggered'] = False
        cursor = db.alerts.find(query, {'_id': 0}).sort('created_at', -1)
        docs   = await cursor.to_list(length=None)
        for d in docs:
            d['id'] = d.get('seq_id', 0)
        return docs

    def get_alert_by_id(self, alert_id: int) -> Optional[Dict]:
        return self._run(self._get_alert_by_id(alert_id))

    async def _get_alert_by_id(self, alert_id: int) -> Optional[Dict]:
        db  = get_db()
        doc = await db.alerts.find_one({'seq_id': alert_id}, {'_id': 0})
        if doc:
            doc['id'] = doc.get('seq_id', 0)
        return doc

    def get_all_active_alerts(self) -> List[Dict]:
        return self._run(self._get_all_active_alerts())

    async def _get_all_active_alerts(self) -> List[Dict]:
        db     = get_db()
        cursor = db.alerts.find({'triggered': False}, {'_id': 0})
        docs   = await cursor.to_list(length=None)
        for d in docs:
            d['id'] = d.get('seq_id', 0)
        return docs

    def delete_alert(self, alert_id: int, user_id: int) -> bool:
        return self._run(self._delete_alert(alert_id, user_id))

    async def _delete_alert(self, alert_id, user_id) -> bool:
        db  = get_db()
        res = await db.alerts.delete_one(
            {'seq_id': alert_id, 'user_id': user_id})
        return res.deleted_count > 0

    def clear_user_alerts(self, user_id: int) -> int:
        return self._run(self._clear_user_alerts(user_id))

    async def _clear_user_alerts(self, user_id: int) -> int:
        db  = get_db()
        res = await db.alerts.delete_many(
            {'user_id': user_id, 'triggered': False})
        return res.deleted_count

    def mark_triggered(self, alert_id: int):
        return self._run(self._mark_triggered(alert_id))

    async def _mark_triggered(self, alert_id: int):
        db = get_db()
        await db.alerts.update_one(
            {'seq_id': alert_id},
            {'$set': {'triggered': True, 'triggered_at': _now_tehran()}}
        )

    def get_stats(self) -> Dict[str, int]:
        return self._run(self._get_stats())

    async def _get_stats(self) -> Dict[str, int]:
        db       = get_db()
        pipeline = [
            {'$match': {'triggered': False}},
            {'$group': {'_id': '$symbol', 'count': {'$sum': 1}}},
            {'$sort':  {'count': -1}}
        ]
        cursor = db.alerts.aggregate(pipeline)
        docs   = await cursor.to_list(length=None)
        return {d['_id']: d['count'] for d in docs}

    def count_user_alerts(self, user_id: int) -> int:
        return self._run(self._count_user_alerts(user_id))

    async def _count_user_alerts(self, user_id: int) -> int:
        db = get_db()
        return await db.alerts.count_documents(
            {'user_id': user_id, 'triggered': False})

    # ── Indexes (اجرا یه بار هنگام startup) ───────────────────────────

    def ensure_indexes(self):
        return self._run(self._ensure_indexes())

    async def _ensure_indexes(self):
        db = get_db()
        await db.alerts.create_index([('user_id', 1), ('triggered', 1)])
        await db.alerts.create_index([('seq_id', 1)], unique=True, sparse=True)
        await db.user_devices.create_index([('push_token', 1)], unique=True)
        await db.user_devices.create_index([('user_id', 1)])
        await db.users.create_index([('user_id', 1)], unique=True)
        await db.allowed_groups.create_index([('group_id', 1)], unique=True)
