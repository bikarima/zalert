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
  }

  Future<bool> login(String userIdText, String username) async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final userId = int.parse(userIdText.trim());
      final deviceName = await _getDeviceName();
      final pushToken  = NotificationService.instance.fcmToken;

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

  Future<void> logout() async {
    final pushToken = NotificationService.instance.fcmToken;
    if (_userId != null && pushToken != null) {
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
