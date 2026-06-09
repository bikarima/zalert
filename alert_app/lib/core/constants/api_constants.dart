class ApiConstants {
  ApiConstants._();

  // آدرس سرور رو اینجا تنظیم کن
  static const String baseUrl = 'http://YOUR_SERVER_IP:8000';

  // اگه API_KEY تنظیم کردی اینجا بذار، وگرنه خالی بذار
  static const String apiKey = '';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
