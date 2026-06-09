import os
from dotenv import load_dotenv

load_dotenv()

BOT_TOKEN     = os.getenv('BOT_TOKEN')
ADMIN_USER_ID = int(os.getenv('ADMIN_USER_ID'))

# تنظیمات MT5
MT5_TIMEOUT  = 60000
MT5_PORTABLE = False

# تنظیمات چک کردن قیمت
CHECK_INTERVAL = 15  # هر 15 ثانیه یکبار

# محدودیت‌ها
MAX_ALERTS_PER_USER = 20

# تنظیمات API
API_HOST = os.getenv('API_HOST', '0.0.0.0')
API_PORT = int(os.getenv('API_PORT', '8000'))
API_KEY  = os.getenv('API_KEY', '')

# Firebase Admin SDK — فایل json کنار bot.py باشه
FIREBASE_CREDENTIALS = os.getenv('FIREBASE_CREDENTIALS', 'firebase-adminsdk.json')
