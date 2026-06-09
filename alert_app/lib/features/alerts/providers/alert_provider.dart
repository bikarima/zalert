import 'package:flutter/material.dart';
import '../../../core/models/alert_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';

enum AlertStatus { idle, loading, success, error }

class AlertProvider extends ChangeNotifier {
  List<AlertModel> _alerts = [];
  AlertStatus _status = AlertStatus.idle;
  String? _error;
  Map<String, dynamic>? _stats;

  List<AlertModel> get alerts  => _alerts;
  AlertStatus      get status  => _status;
  String?          get error   => _error;
  Map<String, dynamic>? get stats => _stats;

  List<AlertModel> get activeAlerts    => _alerts.where((a) => !a.triggered).toList();
  List<AlertModel> get triggeredAlerts => _alerts.where((a) =>  a.triggered).toList();

  Future<void> loadAlerts(int userId, {bool includeTriggered = false}) async {
    _status = AlertStatus.loading;
    _error  = null;
    notifyListeners();

    try {
      _alerts = await ApiService.instance.getAlerts(
        userId,
        includeTriggered: includeTriggered,
      );
      _status = AlertStatus.success;
    } catch (e) {
      _error  = e.toString();
      _status = AlertStatus.error;
    }
    notifyListeners();
  }

  Future<bool> createAlert({
    required int userId,
    required String symbol,
    required double targetPrice,
    String? username,
  }) async {
    _status = AlertStatus.loading;
    _error  = null;
    notifyListeners();

    try {
      final pushToken = NotificationService.instance.fcmToken;
      await ApiService.instance.createAlert(
        userId: userId,
        symbol: symbol,
        targetPrice: targetPrice,
        username: username,
        pushToken: pushToken,
        platform: 'android',
      );
      await loadAlerts(userId);
      return true;
    } catch (e) {
      _error  = _friendlyError(e.toString());
      _status = AlertStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAlert(int alertId, int userId) async {
    try {
      await ApiService.instance.deleteAlert(alertId, userId);
      _alerts.removeWhere((a) => a.id == alertId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadStats() async {
    try {
      _stats = await ApiService.instance.getStats();
      notifyListeners();
    } catch (_) {}
  }

  // قیمت فعلی یه نماد
  Future<Map<String, dynamic>?> getPrice(String symbol) async {
    try {
      return await ApiService.instance.getPrice(symbol);
    } catch (e) {
      _error = _friendlyError(e.toString());
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _friendlyError(String raw) {
    if (raw.contains('SocketException') || raw.contains('ConnectionRefused')) {
      return 'اتصال به سرور برقرار نشد';
    }
    if (raw.contains('404')) return 'آیتم یافت نشد';
    if (raw.contains('401')) return 'دسترسی غیرمجاز';
    if (raw.contains('400')) {
      // سعی کن پیام سرور رو نشون بده
      final match = RegExp(r'"detail":"([^"]+)"').firstMatch(raw);
      if (match != null) return match.group(1)!;
    }
    return 'خطا: $raw';
  }
}
