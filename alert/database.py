"""
Database layer — MongoDB (motor async) — fully async.

Collections:
  alerts          price alert documents
  users           registered users
  user_devices    FCM push tokens per device
  allowed_groups  white-listed Telegram groups
  banned_users    users banned by admin
  counters        auto-increment sequences
"""
from datetime import datetime
from typing import List, Optional, Dict, Tuple
import pytz
import motor.motor_asyncio
import config

# هر event loop کلاینت motor جداگانه خودشو داره
# دلیل: uvicorn در thread جدا اجرا میشه و loop متفاوتی داره — اگه کلاینت رو بین‌شون شیر میکنه
_loop_clients: dict = {}


def get_db():
    """
    ارتباط motor برای event loop جاری — loop-aware singleton.
    بات کلاینت همیشه به loop همان تردی که درش ساخته شده — خطای
    'Future attached to a different loop' دیگه نمییاد.
    """
    import asyncio
    try:
        loop    = asyncio.get_running_loop()
        loop_id = id(loop)
    except RuntimeError:
        loop_id = 0   # not inside an async context

    if loop_id not in _loop_clients:
        client = motor.motor_asyncio.AsyncIOMotorClient(config.MONGO_URI)
        _loop_clients[loop_id] = (client, client[config.MONGO_DB])

    return _loop_clients[loop_id][1]



def _now() -> str:
    return datetime.now(pytz.timezone("Asia/Tehran")).strftime("%Y-%m-%d %H:%M:%S")


class Database:

    # ── Allowed Groups ────────────────────────────────────────────────────────

    async def add_group(self, group_id: int, group_title: str) -> bool:
        await get_db().allowed_groups.update_one(
            {"group_id": group_id},
            {"$set": {"group_id": group_id, "group_title": group_title, "added_at": _now()}},
            upsert=True,
        )
        return True

    async def remove_group(self, group_id: int) -> bool:
        r = await get_db().allowed_groups.delete_one({"group_id": group_id})
        return r.deleted_count > 0

    async def is_allowed_group(self, group_id: int) -> bool:
        doc = await get_db().allowed_groups.find_one({"group_id": group_id})
        return doc is not None

    async def get_all_groups(self) -> List[Dict]:
        return await get_db().allowed_groups.find({}, {"_id": 0}).sort("added_at", 1).to_list(None)

    # ── Users & Devices ───────────────────────────────────────────────────────

    async def upsert_user(
        self,
        user_id: int,
        username: str = None,
        push_token: str = None,
        platform: str = None,
        device_name: str = None,
    ) -> None:
        db  = get_db()
        now = _now()
        await db.users.update_one(
            {"user_id": user_id},
            {
                "$set": {"last_seen": now},
                "$setOnInsert": {"user_id": user_id, "registered_at": now},
            },
            upsert=True,
        )
        if username:
            await db.users.update_one({"user_id": user_id}, {"$set": {"username": username}})
        if push_token:
            await db.user_devices.update_one(
                {"push_token": push_token},
                {
                    "$set": {
                        "user_id": user_id,
                        "push_token": push_token,
                        "platform": platform,
                        "device_name": device_name,
                        "last_used": now,
                    },
                    "$setOnInsert": {"added_at": now},
                },
                upsert=True,
            )

    async def get_user(self, user_id: int) -> Optional[Dict]:
        return await get_db().users.find_one({"user_id": user_id}, {"_id": 0})

    async def get_user_devices(self, user_id: int) -> List[Dict]:
        return (
            await get_db()
            .user_devices.find({"user_id": user_id}, {"_id": 0})
            .sort("last_used", -1)
            .to_list(None)
        )

    async def get_push_tokens(self, user_id: int) -> List[str]:
        devices = await self.get_user_devices(user_id)
        return [d["push_token"] for d in devices if d.get("push_token")]

    async def get_push_token(self, user_id: int) -> Optional[str]:
        tokens = await self.get_push_tokens(user_id)
        return tokens[0] if tokens else None

    async def remove_device(self, user_id: int, push_token: str) -> bool:
        r = await get_db().user_devices.delete_one(
            {"user_id": user_id, "push_token": push_token}
        )
        return r.deleted_count > 0

    async def remove_device_by_token(self, push_token: str) -> bool:
        """حذف دستگاه فقط با push token — بدون نیاز به user_id.
        برای cleanup خودکار توکن‌های expired/invalid که FCM برمیگردونه."""
        r = await get_db().user_devices.delete_one({"push_token": push_token})
        return r.deleted_count > 0


    async def remove_all_devices(self, user_id: int) -> int:
        r = await get_db().user_devices.delete_many({"user_id": user_id})
        return r.deleted_count

    # ── Alerts ────────────────────────────────────────────────────────────────

    async def add_alert(
        self,
        user_id: int,
        username: str,
        symbol: str,
        target_price: float,
        alert_type: str,
        group_id: int = 0,
    ) -> int:
        db  = get_db()
        doc = {
            "user_id": user_id,
            "username": username,
            "group_id": group_id,
            "symbol": symbol.upper(),
            "target_price": target_price,
            "alert_type": alert_type,
            "created_at": _now(),
            "triggered": False,
            "triggered_at": None,
        }
        await db.alerts.insert_one(doc)
        counter = await db.counters.find_one_and_update(
            {"_id": "alert_id"},
            {"$inc": {"seq": 1}},
            upsert=True,
            return_document=True,
        )
        seq = counter["seq"]
        await db.alerts.update_one({"_id": doc["_id"]}, {"$set": {"seq_id": seq}})
        return seq

    async def get_user_alerts(
        self, user_id: int, include_triggered: bool = False
    ) -> List[Dict]:
        query = {"user_id": user_id}
        if not include_triggered:
            query["triggered"] = False
        docs = (
            await get_db()
            .alerts.find(query, {"_id": 0})
            .sort("created_at", -1)
            .to_list(None)
        )
        for d in docs:
            d["id"] = d.get("seq_id", 0)
        return docs

    async def get_alert_by_id(self, alert_id: int) -> Optional[Dict]:
        doc = await get_db().alerts.find_one({"seq_id": alert_id}, {"_id": 0})
        if doc:
            doc["id"] = doc.get("seq_id", 0)
        return doc

    async def get_all_active_alerts(self) -> List[Dict]:
        docs = await get_db().alerts.find({"triggered": False}, {"_id": 0}).to_list(None)
        for d in docs:
            d["id"] = d.get("seq_id", 0)
        return docs

    async def delete_alert(self, alert_id: int, user_id: int) -> bool:
        r = await get_db().alerts.delete_one({"seq_id": alert_id, "user_id": user_id})
        return r.deleted_count > 0

    async def clear_user_alerts(self, user_id: int) -> int:
        r = await get_db().alerts.delete_many({"user_id": user_id, "triggered": False})
        return r.deleted_count

    async def mark_triggered(self, alert_id: int) -> None:
        await get_db().alerts.update_one(
            {"seq_id": alert_id},
            {"$set": {"triggered": True, "triggered_at": _now()}},
        )

    async def get_stats(self) -> Dict[str, int]:
        pipeline = [
            {"$match": {"triggered": False}},
            {"$group": {"_id": "$symbol", "count": {"$sum": 1}}},
            {"$sort": {"count": -1}},
        ]
        docs = await get_db().alerts.aggregate(pipeline).to_list(None)
        return {d["_id"]: d["count"] for d in docs}

    async def count_user_alerts(self, user_id: int) -> int:
        return await get_db().alerts.count_documents(
            {"user_id": user_id, "triggered": False}
        )

    # ── Ban Management ────────────────────────────────────────────────────────

    async def ban_user(
        self, user_id: int, reason: str = "", banned_by: int = 0
    ) -> bool:
        await get_db().banned_users.update_one(
            {"user_id": user_id},
            {
                "$set": {
                    "user_id": user_id,
                    "reason": reason,
                    "banned_by": banned_by,
                    "banned_at": _now(),
                }
            },
            upsert=True,
        )
        return True

    async def unban_user(self, user_id: int) -> bool:
        r = await get_db().banned_users.delete_one({"user_id": user_id})
        return r.deleted_count > 0

    async def is_banned(self, user_id: int) -> bool:
        doc = await get_db().banned_users.find_one({"user_id": user_id})
        return doc is not None

    async def get_banned_users(self) -> List[Dict]:
        return (
            await get_db()
            .banned_users.find({}, {"_id": 0})
            .sort("banned_at", -1)
            .to_list(None)
        )

    # ── Admin Queries ─────────────────────────────────────────────────────────

    async def get_all_users(self, limit: int = 20) -> List[Dict]:
        return (
            await get_db()
            .users.find({}, {"_id": 0})
            .sort("registered_at", -1)
            .to_list(limit)
        )

    async def get_total_user_count(self) -> int:
        return await get_db().users.count_documents({})

    async def get_admin_stats(self) -> Dict:
        """Comprehensive system statistics for the admin dashboard."""
        db = get_db()
        total_users   = await db.users.count_documents({})
        active_alerts = await db.alerts.count_documents({"triggered": False})
        total_alerts  = await db.alerts.count_documents({})
        triggered     = await db.alerts.count_documents({"triggered": True})
        total_groups  = await db.allowed_groups.count_documents({})
        total_devices = await db.user_devices.count_documents({})
        banned_count  = await db.banned_users.count_documents({})

        # Top 5 symbols by active alert count
        sym_pipeline = [
            {"$match": {"triggered": False}},
            {"$group": {"_id": "$symbol", "count": {"$sum": 1}}},
            {"$sort": {"count": -1}},
            {"$limit": 5},
        ]
        top_symbols: List[Tuple[str, int]] = [
            (d["_id"], d["count"])
            for d in await db.alerts.aggregate(sym_pipeline).to_list(None)
        ]

        # Top 5 users by active alert count
        usr_pipeline = [
            {"$match": {"triggered": False}},
            {
                "$group": {
                    "_id": "$user_id",
                    "username": {"$first": "$username"},
                    "count": {"$sum": 1},
                }
            },
            {"$sort": {"count": -1}},
            {"$limit": 5},
        ]
        top_users: List[Tuple[int, str, int]] = [
            (d["_id"], d.get("username") or "—", d["count"])
            for d in await db.alerts.aggregate(usr_pipeline).to_list(None)
        ]

        return {
            "total_users": total_users,
            "active_alerts": active_alerts,
            "total_alerts": total_alerts,
            "triggered": triggered,
            "total_groups": total_groups,
            "total_devices": total_devices,
            "banned_count": banned_count,
            "top_symbols": top_symbols,
            "top_users": top_users,
        }

    async def delete_alert_admin(self, alert_id: int) -> bool:
        """Admin override — delete any alert regardless of owner."""
        r = await get_db().alerts.delete_one({"seq_id": alert_id})
        return r.deleted_count > 0

    async def clear_all_alerts_admin(self) -> int:
        """Admin override — wipe ALL active alerts system-wide."""
        r = await get_db().alerts.delete_many({"triggered": False})
        return r.deleted_count

    async def get_all_active_alerts_admin(self, limit: int = 30) -> List[Dict]:
        """All active alerts (newest first) for admin view."""
        docs = (
            await get_db()
            .alerts.find({"triggered": False}, {"_id": 0})
            .sort("created_at", -1)
            .to_list(limit)
        )
        for d in docs:
            d["id"] = d.get("seq_id", 0)
        return docs

    # ── Auth OTP ────────────────────────────────────────────────────────────────────

    async def create_otp(self, user_id: int, code_hash: str) -> None:
        """ذخیره OTP جدید (۵ دقیقه اعتبار) — OTP قبلی جایگزین میشه."""
        from datetime import timezone, timedelta
        now        = datetime.now(timezone.utc)
        expires_at = now + timedelta(minutes=5)
        await get_db().auth_otps.update_one(
            {"user_id": user_id},
            {"$set": {
                "user_id":    user_id,
                "code_hash":  code_hash,
                "expires_at": expires_at,
                "attempts":   0,
                "created_at": now,
            }},
            upsert=True,
        )
        # لاگ برای rate limiting (خودکار بعد از ۱ ساعت پاک میشه)
        await get_db().otp_log.insert_one({"user_id": user_id, "created_at": now})

    async def verify_otp(self, user_id: int, code_hash: str) -> tuple[bool, str]:
        """
        تأیید OTP. Returns (success, error_message).
        بعد از موفقیت با delete_otp پاک کن.
        """
        from datetime import timezone
        doc = await get_db().auth_otps.find_one({"user_id": user_id}, {"_id": 0})
        if not doc:
            return False, "کد تأیید یافت نشد — دوباره درخواست کنید"

        expires_at = doc["expires_at"]
        if not expires_at.tzinfo:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) > expires_at:
            await self.delete_otp(user_id)
            return False, "کد منقضی شده — دوباره درخواست کنید"

        attempts = doc.get("attempts", 0)
        if attempts >= 5:
            await self.delete_otp(user_id)
            return False, "تعداد تلاش‌های مجاز تمام شد — دوباره درخواست کنید"

        await get_db().auth_otps.update_one({"user_id": user_id}, {"$inc": {"attempts": 1}})

        if doc["code_hash"] != code_hash:
            remaining = 4 - attempts
            if remaining <= 0:
                await self.delete_otp(user_id)
                return False, "کد نادرست — تمام تلاش‌ها استفاده شد"
            return False, f"کد نادرست — {remaining} تلاش باقیمانده"

        return True, ""

    async def delete_otp(self, user_id: int) -> None:
        """OTP رو بعد استفاده یا انقضا پاک کن."""
        await get_db().auth_otps.delete_one({"user_id": user_id})

    async def count_recent_otp_requests(self, user_id: int, since) -> int:
        """تعداد درخواست‌های اخیر OTP — برای rate limiting."""
        return await get_db().otp_log.count_documents({
            "user_id":    user_id,
            "created_at": {"$gte": since},
        })

    # ── Indexes ────────────────────────────────────────────────────────────────────

    async def ensure_indexes(self) -> None:
        db = get_db()
        await db.alerts.create_index([("user_id", 1), ("triggered", 1)])
        await db.alerts.create_index([("seq_id", 1)], unique=True, sparse=True)
        await db.user_devices.create_index([("push_token", 1)], unique=True)
        await db.user_devices.create_index([("user_id", 1)])
        await db.users.create_index([("user_id", 1)], unique=True)
        await db.allowed_groups.create_index([("group_id", 1)], unique=True)
        await db.banned_users.create_index([("user_id", 1)], unique=True)
        # OTP indexes
        await db.auth_otps.create_index([("user_id", 1)], unique=True)
        await db.auth_otps.create_index("expires_at", expireAfterSeconds=600)   # انقضای خودکار
        await db.otp_log.create_index("created_at", expireAfterSeconds=3600)    # لاگ بعد ۱ساعت پاک

