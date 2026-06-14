import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';

/// Auth flow:
///   1. requestOtp(userId)   — ارسال OTP به تلگرام
///   2. verifyOtp(userId, code) — تأیید کد
///   3. login() stores user in local storage
///
/// Device login (بدون تلگرام) مستقیم رجیستر میکنه.
class AuthProvider extends ChangeNotifier {
  int?    _userId;
  String? _username;
  bool    _loading  = false;
  String? _error;

  int?    get userId    => _userId;
  String? get username  => _username;
  bool    get loading   => _loading;
  String? get error     => _error;
  bool    get isLoggedIn => _userId != null;

  AuthProvider() {
    _loadFromStorage();
    // وقتی FCM token رفرش شد، سرور رو خبر کن
    NotificationService.instance.onTokenRefresh = _onTokenRefresh;
  }

  // ── Restore session ───────────────────────────────────────────────────────

  Future<void> _loadFromStorage() async {
    _userId   = await StorageService.instance.getUserId();
    _username = await StorageService.instance.getUsername();
    notifyListeners();
    if (_userId != null) await _syncPushToken();
  }

  Future<void> _syncPushToken() async {
    final token = NotificationService.instance.fcmToken;
    if (token == null || _userId == null) return;
    try {
      await ApiService.instance.updatePushToken(
        _userId!, token,
        platform:   await _platform(),
        deviceName: await _deviceName(),
      );
    } catch (_) {}
  }

  Future<void> _onTokenRefresh(String newToken) async {
    if (_userId == null) return;
    try {
      await ApiService.instance.updatePushToken(
        _userId!, newToken,
        platform:   await _platform(),
        deviceName: await _deviceName(),
      );
    } catch (_) {}
  }

  // ── OTP flow ──────────────────────────────────────────────────────────────

  /// مرحله ۱ — ارسال OTP به تلگرام کاربر.
  /// Returns true اگه کد با موفقیت ارسال شد.
  Future<bool> requestOtp(String userIdText, {String? username}) async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final userId = int.parse(userIdText.trim());
      await ApiService.instance.requestOtp(userId, username: username?.trim());
      _loading = false;
      notifyListeners();
      return true;
    } on FormatException {
      _error   = 'آیدی تلگرام باید عدد باشد';
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error   = _extractError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// مرحله ۲ — تأیید OTP و ورود.
  /// Returns true اگه کد صحیح بود و لاگین انجام شد.
  Future<bool> verifyOtp(String userIdText, String code, {String? username}) async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final userId     = int.parse(userIdText.trim());
      final deviceName = await _deviceName();
      final platform   = await _platform();
      String? pushToken = NotificationService.instance.fcmToken;
      if (pushToken == null) {
        await Future.delayed(const Duration(seconds: 2));
        pushToken = NotificationService.instance.fcmToken;
      }

      final result = await ApiService.instance.verifyOtp(
        userId:     userId,
        code:       code.trim(),
        deviceName: deviceName,
        platform:   platform,
        pushToken:  pushToken,
      );

      final finalUsername = result['username'] as String? ??
          (username?.trim().isNotEmpty == true ? username!.trim() : userId.toString());

      await StorageService.instance.saveUser(userId, finalUsername);
      _userId   = userId;
      _username = finalUsername;
      _loading  = false;
      notifyListeners();
      return true;
    } on FormatException {
      _error   = 'آیدی تلگرام باید عدد باشد';
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error   = _extractError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Device login (بدون تلگرام) ────────────────────────────────────────────

  Future<bool> loginWithDevice(String? username) async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final deviceId   = await StorageService.instance.getOrCreateDeviceIdAsInt();
      final deviceName = await _deviceName();
      final platform   = await _platform();
      String? pushToken = NotificationService.instance.fcmToken;
      if (pushToken == null) {
        await Future.delayed(const Duration(seconds: 2));
        pushToken = NotificationService.instance.fcmToken;
      }

      final displayName = (username?.trim().isNotEmpty == true)
          ? username!.trim()
          : 'device_$deviceId';

      await ApiService.instance.register(
        userId: deviceId, username: displayName,
        pushToken: pushToken, platform: platform, deviceName: deviceName,
      );
      await StorageService.instance.saveUser(deviceId, displayName);

      _userId   = deviceId;
      _username = displayName;
      _loading  = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error   = _extractError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    if (_userId != null) {
      try { await ApiService.instance.removeAllDevices(_userId!); } catch (_) {}
    }
    await StorageService.instance.clear();
    _userId   = null;
    _username = null;
    notifyListeners();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<String> _deviceName() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return '${info.brand} ${info.model}';
    } catch (_) {
      try {
        final info = await DeviceInfoPlugin().iosInfo;
        return info.name;
      } catch (_) {
        return 'Mobile Device';
      }
    }
  }

  Future<String> _platform() async {
    try {
      await DeviceInfoPlugin().androidInfo;
      return 'android';
    } catch (_) {
      return 'ios';
    }
  }

  static String _extractError(Object e) {
    final s = e.toString();
    // DioException — سعی کن detail رو از body بگیر
    if (s.contains('"detail"')) {
      final match = RegExp(r'"detail"\s*:\s*"([^"]+)"').firstMatch(s);
      if (match != null) return match.group(1)!;
    }
    if (s.contains('SocketException') || s.contains('Connection refused')) {
      return 'سرور در دسترس نیست — اینترنت را بررسی کنید';
    }
    return 'خطا: $s';
  }
}
