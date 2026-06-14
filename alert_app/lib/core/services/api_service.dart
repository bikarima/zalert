import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/alert_model.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl:        ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {
        if (ApiConstants.apiKey.isNotEmpty) 'X-Api-Key': ApiConstants.apiKey,
        'Content-Type': 'application/json',
      },
    ),
  );

  // ── OTP Auth ──────────────────────────────────────────────────────────────

  /// ارسال کد ۶ رقمی به تلگرام کاربر.
  /// [userId] — آیدی عددی تلگرام.
  /// Throws DioException on server errors (detail in response body).
  Future<void> requestOtp(int userId, {String? username}) async {
    await _dio.post('/auth/request-otp', data: {
      'user_id':  userId,
      if (username != null && username.isNotEmpty) 'username': username,
    });
  }

  /// تأیید کد OTP.
  /// Returns `{success, user_id, username}` on success.
  /// Throws DioException with error detail on failure.
  Future<Map<String, dynamic>> verifyOtp({
    required int    userId,
    required String code,
    String?         deviceName,
    String?         platform,
    String?         pushToken,
  }) async {
    final res = await _dio.post('/auth/verify-otp', data: {
      'user_id':     userId,
      'code':        code,
      if (deviceName != null) 'device_name': deviceName,
      if (platform   != null) 'platform':    platform,
      if (pushToken  != null) 'push_token':  pushToken,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── Register / Update ─────────────────────────────────────────────────────

  Future<void> register({
    required int    userId,
    String?         username,
    String?         pushToken,
    String?         platform,
    String?         deviceName,
  }) async {
    await _dio.post('/register', data: {
      'user_id': userId,
      if (username   != null) 'username':    username,
      if (pushToken  != null) 'push_token':  pushToken,
      if (platform   != null) 'platform':    platform,
      if (deviceName != null) 'device_name': deviceName,
    });
  }

  Future<void> updatePushToken(
    int    userId,
    String pushToken, {
    String? platform,
    String? deviceName,
  }) async {
    await _dio.put(
      '/user/$userId/push-token',
      queryParameters: {
        'push_token': pushToken,
        if (platform   != null) 'platform':    platform,
        if (deviceName != null) 'device_name': deviceName,
      },
    );
  }

  // ── Alerts ────────────────────────────────────────────────────────────────

  Future<List<AlertModel>> getAlerts(int userId,
      {bool includeTriggered = false}) async {
    final res = await _dio.get(
      '/alerts/$userId',
      queryParameters: {'include_triggered': includeTriggered},
    );
    return (res.data as List)
        .map((j) => AlertModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> createAlert({
    required int    userId,
    required String symbol,
    required double targetPrice,
    String? username,
    String? pushToken,
    String? platform,
    String? deviceName,
  }) async {
    final res = await _dio.post('/alert', data: {
      'user_id':      userId,
      'symbol':       symbol,
      'target_price': targetPrice,
      if (username   != null) 'username':    username,
      if (pushToken  != null) 'push_token':  pushToken,
      if (platform   != null) 'platform':    platform,
      if (deviceName != null) 'device_name': deviceName,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteAlert(int alertId, int userId) async {
    await _dio.delete('/alert/$alertId', queryParameters: {'user_id': userId});
  }

  Future<void> clearAlerts(int userId) async {
    await _dio.delete('/alerts/$userId/clear');
  }

  // ── Price ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPrice(String symbol) async {
    final res = await _dio.get('/price/$symbol');
    return res.data as Map<String, dynamic>;
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() async {
    final res = await _dio.get('/stats');
    return res.data as Map<String, dynamic>;
  }

  // ── Calendar ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCalendar({
    String  week      = 'thisweek',
    String? impact,
    String? currency,
    bool    todayOnly = false,
    String? timezone,
  }) async {
    final res = await _dio.get('/calendar', queryParameters: {
      'week': week,
      if (impact   != null) 'impact':     impact,
      if (currency != null) 'currency':   currency,
      if (todayOnly)        'today_only': true,
      if (timezone != null) 'timezone':   timezone,
    });
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  // ── Devices ───────────────────────────────────────────────────────────────

  Future<List<dynamic>> getDevices(int userId) async {
    final res = await _dio.get('/user/$userId/devices');
    return res.data as List;
  }

  Future<void> removeAllDevices(int userId) async {
    await _dio.delete('/user/$userId/devices');
  }

  // ── Announcements ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final res = await _dio.get('/announcements');
    return (res.data as List).cast<Map<String, dynamic>>();
  }
}
