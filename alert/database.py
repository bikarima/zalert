import sqlite3
from datetime import datetime
import pytz
from typing import List, Optional, Dict


class Database:
    def __init__(self, db_file='alerts.db'):
        self.db_file = db_file
        self.init_db()

    def init_db(self):
        """ایجاد جداول دیتابیس"""
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()

        cursor.execute('''
            CREATE TABLE IF NOT EXISTS alerts (
                id           INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id      INTEGER NOT NULL,
                username     TEXT,
                group_id     INTEGER NOT NULL DEFAULT 0,
                symbol       TEXT NOT NULL,
                target_price REAL NOT NULL,
                alert_type   TEXT NOT NULL,
                created_at   TEXT NOT NULL,
                triggered    INTEGER DEFAULT 0,
                triggered_at TEXT
            )
        ''')

        cursor.execute('''
            CREATE TABLE IF NOT EXISTS allowed_groups (
                group_id    INTEGER PRIMARY KEY,
                group_title TEXT,
                added_at    TEXT NOT NULL
            )
        ''')

        # جدول کاربران — اطلاعات پایه
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                user_id       INTEGER PRIMARY KEY,
                username      TEXT,
                registered_at TEXT NOT NULL,
                last_seen     TEXT
            )
        ''')

        # جدول دستگاه‌های کاربر — هر کاربر چند دستگاه میتونه داشته باشه
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS user_devices (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id    INTEGER NOT NULL,
                push_token TEXT NOT NULL UNIQUE,
                platform   TEXT,              -- ios / android / expo
                device_name TEXT,             -- اختیاری: "iPhone Ali" و ...
                added_at   TEXT NOT NULL,
                last_used  TEXT,
                FOREIGN KEY (user_id) REFERENCES users(user_id)
            )
        ''')

        # ایندکس برای جستجوی سریع
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_devices_user_id ON user_devices(user_id)
        ''')

        conn.commit()
        conn.close()

        # migration برای دیتابیس‌های قدیمی
        self._migrate()

    def _migrate(self):
        """اضافه کردن ستون‌های جدید به دیتابیس‌های قدیمی"""
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()

        migrations = [
            "ALTER TABLE alerts ADD COLUMN triggered_at TEXT",
            "ALTER TABLE alerts ADD COLUMN group_id INTEGER NOT NULL DEFAULT 0",
        ]

        for sql in migrations:
            try:
                cursor.execute(sql)
            except sqlite3.OperationalError:
                pass  # ستون قبلاً وجود داره

        conn.commit()
        conn.close()

    # ── مدیریت کاربران ────────────────────────────────────────────────

    def upsert_user(self, user_id: int, username: str = None,
                    push_token: str = None, platform: str = None,
                    device_name: str = None):
        """ثبت یا آپدیت کاربر + اضافه کردن دستگاه جدید در صورت نیاز"""
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        tehran_tz = pytz.timezone('Asia/Tehran')
        now = datetime.now(tehran_tz).strftime('%Y-%m-%d %H:%M:%S')

        # upsert کاربر
        cursor.execute('''
            INSERT INTO users (user_id, username, registered_at, last_seen)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET
                username  = COALESCE(excluded.username, username),
                last_seen = excluded.last_seen
        ''', (user_id, username, now, now))

        # اضافه کردن دستگاه اگه push_token داده شده
        if push_token:
            cursor.execute('''
                INSERT INTO user_devices (user_id, push_token, platform, device_name, added_at, last_used)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(push_token) DO UPDATE SET
                    user_id     = excluded.user_id,
                    platform    = COALESCE(excluded.platform,    platform),
                    device_name = COALESCE(excluded.device_name, device_name),
                    last_used   = excluded.last_used
            ''', (user_id, push_token, platform, device_name, now, now))

        conn.commit()
        conn.close()

    def get_user(self, user_id: int) -> Optional[Dict]:
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        cursor.execute(
            'SELECT user_id, username, registered_at, last_seen FROM users WHERE user_id = ?',
            (user_id,)
        )
        row = cursor.fetchone()
        conn.close()
        if row is None:
            return None
        return {'user_id': row[0], 'username': row[1],
                'registered_at': row[2], 'last_seen': row[3]}

    def get_user_devices(self, user_id: int) -> List[Dict]:
        """همه دستگاه‌های یک کاربر"""
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT id, push_token, platform, device_name, added_at, last_used
            FROM user_devices WHERE user_id = ?
            ORDER BY last_used DESC
        ''', (user_id,))
        devices = []
        for row in cursor.fetchall():
            devices.append({
                'id': row[0], 'push_token': row[1], 'platform': row[2],
                'device_name': row[3], 'added_at': row[4], 'last_used': row[5]
            })
        conn.close()
        return devices

    def get_push_tokens(self, user_id: int) -> List[str]:
        """لیست همه push tokenهای یک کاربر (برای همه دستگاه‌ها)"""
        devices = self.get_user_devices(user_id)
        return [d['push_token'] for d in devices if d['push_token']]

    def get_push_token(self, user_id: int) -> Optional[str]:
        """سازگاری با کد قدیمی — اولین توکن رو برمیگردونه"""
        tokens = self.get_push_tokens(user_id)
        return tokens[0] if tokens else None

    def remove_device(self, user_id: int, push_token: str) -> bool:
        """حذف یک دستگاه خاص"""
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        cursor.execute(
            'DELETE FROM user_devices WHERE user_id = ? AND push_token = ?',
            (user_id, push_token)
        )
        deleted = cursor.rowcount > 0
        conn.commit()
        conn.close()
        return deleted

    def remove_all_devices(self, user_id: int) -> int:
        """حذف همه دستگاه‌های یک کاربر"""
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        cursor.execute('DELETE FROM user_devices WHERE user_id = ?', (user_id,))
        count = cursor.rowcount
        conn.commit()
        conn.close()
        return count

    # ── مدیریت گروه‌های مجاز ──────────────────────────────────────────

    def add_group(self, group_id: int, group_title: str) -> bool:
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        tehran_tz = pytz.timezone('Asia/Tehran')
        added_at = datetime.now(tehran_tz).strftime('%Y-%m-%d %H:%M:%S')
        cursor.execute('''
            INSERT OR REPLACE INTO allowed_groups (group_id, group_title, added_at)
            VALUES (?, ?, ?)
        ''', (group_id, group_title, added_at))
        conn.commit()
        conn.close()
        return True

    def remove_group(self, group_id: int) -> bool:
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        cursor.execute('DELETE FROM allowed_groups WHERE group_id = ?', (group_id,))
        deleted = cursor.rowcount > 0
        conn.commit()
        conn.close()
        return deleted

    def is_allowed_group(self, group_id: int) -> bool:
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        cursor.execute('SELECT 1 FROM allowed_groups WHERE group_id = ?', (group_id,))
        result = cursor.fetchone()
        conn.close()
        return result is not None

    def get_all_groups(self) -> List[Dict]:
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        cursor.execute('SELECT group_id, group_title, added_at FROM allowed_groups ORDER BY added_at')
        groups = [{'group_id': r[0], 'group_title': r[1], 'added_at': r[2]} for r in cursor.fetchall()]
        conn.close()
        return groups

    # ── مدیریت آلرت‌ها ────────────────────────────────────────────────

    def add_alert(self, user_id: int, username: str, symbol: str,
                  target_price: float, alert_type: str, group_id: int = 0) -> int:
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        tehran_tz = pytz.timezone('Asia/Tehran')
        created_at = datetime.now(tehran_tz).strftime('%Y-%m-%d %H:%M:%S')
        cursor.execute('''
            INSERT INTO alerts (user_id, username, group_id, symbol, target_price, alert_type, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (user_id, username, group_id, symbol.upper(), target_price, alert_type, created_at))
        alert_id = cursor.lastrowid
        conn.commit()
        conn.close()
        return alert_id

    def get_user_alerts(self, user_id: int, include_triggered: bool = False) -> List[Dict]:
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        query = '''
            SELECT id, symbol, target_price, alert_type, created_at, triggered, triggered_at
            FROM alerts
            WHERE user_id = ?
        '''
        if not include_triggered:
            query += ' AND triggered = 0'
        query += ' ORDER BY created_at DESC'
        cursor.execute(query, (user_id,))
        alerts = []
        for row in cursor.fetchall():
            alerts.append({
                'id': row[0], 'symbol': row[1],
                'target_price': row[2], 'alert_type': row[3],
                'created_at': row[4], 'triggered': bool(row[5]),
                'triggered_at': row[6]
            })
        conn.close()
        return alerts

    def get_alert_by_id(self, alert_id: int) -> Optional[Dict]:
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT id, user_id, username, group_id, symbol, target_price, alert_type,
                   created_at, triggered, triggered_at
            FROM alerts WHERE id = ?
        ''', (alert_id,))
        row = cursor.fetchone()
        conn.close()
        if row is None:
            return None
        return {
            'id': row[0], 'user_id': row[1], 'username': row[2],
            'group_id': row[3], 'symbol': row[4], 'target_price': row[5],
            'alert_type': row[6], 'created_at': row[7],
            'triggered': bool(row[8]), 'triggered_at': row[9]
        }

    def get_all_active_alerts(self) -> List[Dict]:
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT id, user_id, username, group_id, symbol, target_price, alert_type
            FROM alerts WHERE triggered = 0
        ''')
        alerts = []
        for row in cursor.fetchall():
            alerts.append({
                'id': row[0], 'user_id': row[1], 'username': row[2],
                'group_id': row[3], 'symbol': row[4],
                'target_price': row[5], 'alert_type': row[6]
            })
        conn.close()
        return alerts

    def delete_alert(self, alert_id: int, user_id: int) -> bool:
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        cursor.execute('DELETE FROM alerts WHERE id = ? AND user_id = ?', (alert_id, user_id))
        deleted = cursor.rowcount > 0
        conn.commit()
        conn.close()
        return deleted

    def clear_user_alerts(self, user_id: int) -> int:
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        cursor.execute('DELETE FROM alerts WHERE user_id = ? AND triggered = 0', (user_id,))
        count = cursor.rowcount
        conn.commit()
        conn.close()
        return count

    def mark_triggered(self, alert_id: int):
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        tehran_tz = pytz.timezone('Asia/Tehran')
        triggered_at = datetime.now(tehran_tz).strftime('%Y-%m-%d %H:%M:%S')
        cursor.execute(
            'UPDATE alerts SET triggered = 1, triggered_at = ? WHERE id = ?',
            (triggered_at, alert_id)
        )
        conn.commit()
        conn.close()

    def get_stats(self) -> Dict[str, int]:
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT symbol, COUNT(*) as count FROM alerts
            WHERE triggered = 0 GROUP BY symbol ORDER BY count DESC
        ''')
        stats = {row[0]: row[1] for row in cursor.fetchall()}
        conn.close()
        return stats

    def count_user_alerts(self, user_id: int) -> int:
        conn = sqlite3.connect(self.db_file)
        cursor = conn.cursor()
        cursor.execute('SELECT COUNT(*) FROM alerts WHERE user_id = ? AND triggered = 0', (user_id,))
        count = cursor.fetchone()[0]
        conn.close()
        return count
