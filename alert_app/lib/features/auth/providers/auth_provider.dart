import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  int?    _userId;
  String? _username;
  bool    _loading = false;
  String? _error;

  int?    get userId   => _userId;
  String? get username => _username;
  bool    get loading  => _loading;
  String? get error    => _error;
  bool    get isLoggedIn => _userId != null;

  AuthProvider() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    _userId   = await StorageService.instance.getUserId();
    _username = await StorageService.instance.getUsername();
    notifyListeners();
    // بعد از لود، push token رو آپدیت کن
    await _refreshPushToken();
  }

  Future<void> _refreshPushToken() async {
    if (_userId == null) return;
    final token = NotificationService.instance.fcmToken;
    if (token != null) {
      try {
        await ApiService.instance.updatePushToken(
          _userId!,
          token,
          platform: 'android',
        );
      } catch (_) {}
    }
  }

  Future<bool> login(String userIdText, String username) async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final userId = int.parse(userIdText.trim());
      final deviceName = await _getDeviceName();

      // اول یه بار token رو بگیر
      String? pushToken = NotificationService.instance.fcmToken;

      // اگه null بود، کمی صبر کن و دوباره امتحان کن (retry)
      if (pushToken == null) {
        await Future.delayed(const Duration(seconds: 2));
        pushToken = NotificationService.instance.fcmToken;
      }

      await ApiService.instance.register(
        userId: userId,
        username: username.trim().isEmpty ? null : username.trim(),
        pushToken: pushToken,
        platform: 'android',
        deviceName: deviceName,
      );

      await StorageService.instance.saveUser(
        userId,
        username.trim().isEmpty ? userId.toString() : username.trim(),
      );

      _userId   = userId;
      _username = username.trim().isEmpty ? userId.toString() : username.trim();
      _loading  = false;
      notifyListeners();
      return true;
    } on FormatException {
      _error   = 'آیدی تلگرام باید عدد باشد';
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error   = 'خطا در اتصال به سرور: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// ورود با Device ID (بدون تلگرام)
  Future<bool> loginWithDevice(String? username) async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final deviceIdInt = await StorageService.instance.getOrCreateDeviceIdAsInt();
      final deviceName  = await _getDeviceName();

      String? pushToken = NotificationService.instance.fcmToken;
      if (pushToken == null) {
        await Future.delayed(const Duration(seconds: 2));
        pushToken = NotificationService.instance.fcmToken;
      }

      final displayName = (username != null && username.trim().isNotEmpty)
          ? username.trim()
          : 'device_$deviceIdInt';

      await ApiService.instance.register(
        userId: deviceIdInt,
        username: displayName,
        pushToken: pushToken,
        platform: 'android',
        deviceName: deviceName,
      );

      await StorageService.instance.saveUser(deviceIdInt, displayName);

      _userId   = deviceIdInt;
      _username = displayName;
      _loading  = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error   = 'خطا در اتصال به سرور: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// لینک کردن حساب device به تلگرام
  Future<bool> linkToTelegram(int telegramId) async {
    if (_userId == null) return false;
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final pushToken  = NotificationService.instance.fcmToken;
      final deviceName = await _getDeviceName();

      await ApiService.instance.register(
        userId: telegramId,
        username: _username,
        pushToken: pushToken,
        platform: 'android',
        deviceName: deviceName,
      );

      // آپدیت local با تلگرام ID
      await StorageService.instance.saveUser(
        telegramId,
        _username ?? telegramId.toString(),
      );
      _userId  = telegramId;
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error   = 'خطا در لینک کردن: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    if (_userId != null) {
      try {
        await ApiService.instance.removeAllDevices(_userId!);
      } catch (_) {}
    }
    await StorageService.instance.clear();
    _userId   = null;
    _username = null;
    notifyListeners();
  }

  Future<String> _getDeviceName() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return '${info.brand} ${info.model}';
    } catch (_) {
      return 'Android Device';
    }
  }
}
