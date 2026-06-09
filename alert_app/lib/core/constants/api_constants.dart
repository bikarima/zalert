class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://83.228.225.124:8000';

  // اگه API_KEY تنظیم کردی اینجا بذار، وگرنه خالی بذار
  static const String apiKey = '';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
