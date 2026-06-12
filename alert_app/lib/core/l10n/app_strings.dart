/// تمام متن‌های اپ — فارسی و انگلیسی
class AppStrings {
  AppStrings._();

  // ── Language Screen ────────────────────────────────────────────
  static const Map<String, String> selectLanguage = {
    'fa': 'زبان خود را انتخاب کنید',
    'en': 'Select your language',
  };
  static const Map<String, String> continueBtn = {
    'fa': 'ادامه',
    'en': 'Continue',
  };

  // ── Onboarding ─────────────────────────────────────────────────
  static const List<Map<String, Map<String, String>>> onboarding = [
    {
      'title': {
        'fa': 'آلرت قیمت هوشمند',
        'en': 'Smart Price Alerts',
      },
      'desc': {
        'fa': 'قیمت دقیق هدف رو تنظیم کن و به محض رسیدن، فوری خبر بگیر',
        'en': 'Set your exact target price and get notified the moment it hits',
      },
    },
    {
      'title': {
        'fa': 'همه بازارها',
        'en': 'All Markets',
      },
      'desc': {
        'fa': 'طلا، فارکس، کریپتو و هر نمادی که در MT5 داری — همه اینجان',
        'en': 'Gold, Forex, Crypto and any symbol on MT5 — all covered here',
      },
    },
    {
      'title': {
        'fa': 'پوش نوتیفیکیشن فوری',
        'en': 'Instant Push Notifications',
      },
      'desc': {
        'fa': 'حتی وقتی اپ بسته‌ست، آلرت‌هات رو روی همه دستگاه‌هات دریافت کن',
        'en': 'Receive alerts on all your devices, even when the app is closed',
      },
    },
  ];

  static const Map<String, String> skip = {'fa': 'رد کردن', 'en': 'Skip'};
  static const Map<String, String> next = {'fa': 'بعدی', 'en': 'Next'};
  static const Map<String, String> getStarted = {
    'fa': 'شروع کن',
    'en': 'Get Started'
  };

  // ── Auth ────────────────────────────────────────────────────────
  static const Map<String, String> welcomeBack = {
    'fa': 'خوش برگشتی',
    'en': 'Welcome Back',
  };
  static const Map<String, String> loginSubtitle = {
    'fa': 'آیدی عددی تلگرامت رو وارد کن',
    'en': 'Enter your Telegram numeric ID',
  };
  static const Map<String, String> telegramId = {
    'fa': 'آیدی عددی تلگرام',
    'en': 'Telegram Numeric ID',
  };
  static const Map<String, String> telegramIdHint = {
    'fa': 'مثال: 123456789',
    'en': 'e.g. 123456789',
  };
  static const Map<String, String> username = {
    'fa': 'نام کاربری (اختیاری)',
    'en': 'Username (optional)',
  };
  static const Map<String, String> usernameHint = {
    'fa': 'مثال: Ali',
    'en': 'e.g. Ali',
  };
  static const Map<String, String> loginBtn = {
    'fa': 'ورود',
    'en': 'Login',
  };
  static const Map<String, String> idRequired = {
    'fa': 'آیدی را وارد کنید',
    'en': 'Please enter your ID',
  };
  static const Map<String, String> idMustBeNumber = {
    'fa': 'آیدی باید عدد باشد',
    'en': 'ID must be a number',
  };
  static const Map<String, String> getIdHint = {
    'fa': 'برای دریافت آیدی عددی به @userinfobot پیام بدید',
    'en': 'Message @userinfobot on Telegram to get your numeric ID',
  };
  static const Map<String, String> connectionError = {
    'fa': 'خطا در اتصال به سرور',
    'en': 'Failed to connect to server',
  };

  // ── Alerts Screen ───────────────────────────────────────────────
  static const Map<String, String> myAlerts = {
    'fa': 'آلرت‌های من',
    'en': 'My Alerts',
  };
  static const Map<String, String> active = {
    'fa': 'فعال',
    'en': 'Active',
  };
  static const Map<String, String> triggered = {
    'fa': 'فعال‌شده',
    'en': 'Triggered',
  };
  static const Map<String, String> noActiveAlerts = {
    'fa': 'هیچ آلرت فعالی ندارید',
    'en': 'No active alerts',
  };
  static const Map<String, String> noTriggeredAlerts = {
    'fa': 'هنوز هیچ آلرتی فعال نشده',
    'en': 'No triggered alerts yet',
  };
  static const Map<String, String> newAlert = {
    'fa': 'آلرت جدید',
    'en': 'New Alert',
  };
  static const Map<String, String> logout = {
    'fa': 'خروج',
    'en': 'Logout',
  };
  static const Map<String, String> target = {
    'fa': 'هدف',
    'en': 'Target',
  };

  // ── Add Alert Screen ────────────────────────────────────────────
  static const Map<String, String> addAlert = {
    'fa': 'آلرت جدید',
    'en': 'New Alert',
  };
  static const Map<String, String> symbol = {
    'fa': 'نماد',
    'en': 'Symbol',
  };
  static const Map<String, String> symbolHint = {
    'fa': 'مثال: XAUUSD',
    'en': 'e.g. XAUUSD',
  };
  static const Map<String, String> symbolRequired = {
    'fa': 'نماد را وارد کنید',
    'en': 'Enter symbol',
  };
  static const Map<String, String> getPrice = {
    'fa': 'قیمت',
    'en': 'Price',
  };
  static const Map<String, String> targetPrice = {
    'fa': 'قیمت هدف',
    'en': 'Target Price',
  };
  static const Map<String, String> priceHint = {
    'fa': 'مثال: 3300.50',
    'en': 'e.g. 3300.50',
  };
  static const Map<String, String> priceRequired = {
    'fa': 'قیمت را وارد کنید',
    'en': 'Enter price',
  };
  static const Map<String, String> priceMustBeNumber = {
    'fa': 'قیمت باید عدد باشد',
    'en': 'Price must be a number',
  };
  static const Map<String, String> autoDetect = {
    'fa': 'ربات خودکار جهت آلرت رو تشخیص میده',
    'en': 'Bot automatically detects alert direction',
  };
  static const Map<String, String> setAlert = {
    'fa': 'ثبت آلرت',
    'en': 'Set Alert',
  };
  static const Map<String, String> alertSetSuccess = {
    'fa': '✅ آلرت با موفقیت ثبت شد',
    'en': '✅ Alert set successfully',
  };

  // ── helper ──────────────────────────────────────────────────────
  static String t(Map<String, String> map, String lang) =>
      map[lang] ?? map['en'] ?? '';
}

// extension برای راحتی استفاده
extension AppStringsExt on String {
  String tr(String lang) => this;
}
