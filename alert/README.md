# ربات آلرت قیمت MT5 تلگرام

ربات تلگرامی برای تنظیم آلرت قیمت با استفاده از MetaTrader 5

## نصب

```bash
pip install -r requirements.txt
```

## تنظیمات

فایل `.env` را ویرایش کنید:
- `BOT_TOKEN`: توکن ربات تلگرام
- `ALLOWED_GROUP_ID`: آیدی گروه مجاز

## اجرا

```bash
python bot.py
```

⚠️ توجه: قبل از اجرا، MetaTrader 5 باید باز باشد.

## دستورات

- `/set SYMBOL PRICE` - تنظیم آلرت
- `/price SYMBOL` - دریافت قیمت فعلی
- `/list` - لیست آلرت‌های شما
- `/delete ID` - حذف یک آلرت
- `/clear` - حذف تمام آلرت‌ها
- `/stats` - آمار کل آلرت‌ها
- `/help` - راهنما

## مثال‌ها

```
/set xauusd 5100
/price eurusd
/delete 5
```
