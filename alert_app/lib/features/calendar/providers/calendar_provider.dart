import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../../../core/models/calendar_event_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';

enum CalendarStatus { idle, loading, success, error }

class CalendarProvider extends ChangeNotifier {
  List<CalendarEventModel> _events = [];
  CalendarStatus _status  = CalendarStatus.idle;
  String? _error;
  String  _week           = 'thisweek';
  String? _filterImpact;
  String? _filterCurrency;
  String? _userTimezone;

  List<CalendarEventModel> get events         => _filtered();
  CalendarStatus           get status         => _status;
  String?                  get error          => _error;
  String                   get week           => _week;
  String?                  get filterImpact   => _filterImpact;
  String?                  get filterCurrency => _filterCurrency;

  // رویداد high impact بعدی که هنوز نگذشته
  CalendarEventModel? get nextHighImpact {
    final highs = _events
        .where((e) => e.isHighImpact && e.timeUntil != null)
        .toList()
      ..sort((a, b) => a.eventTimeUtc!.compareTo(b.eventTimeUtc!));
    return highs.isEmpty ? null : highs.first;
  }

  List<CalendarEventModel> _filtered() {
    var list = _events;
    if (_filterImpact != null) {
      list = list.where((e) => e.impact == _filterImpact).toList();
    }
    if (_filterCurrency != null) {
      list = list.where((e) =>
          e.currency.toUpperCase() == _filterCurrency!.toUpperCase()).toList();
    }
    return list;
  }

  Future<void> load({String week = 'thisweek', bool todayOnly = false}) async {
    _week   = week;
    _status = CalendarStatus.loading;
    _error  = null;
    notifyListeners();

    // دریافت timezone کاربر
    _userTimezone ??= await _getTimezone();

    try {
      final res = await ApiService.instance.getCalendar(
        week:     week,
        todayOnly: todayOnly,
        timezone: _userTimezone,
      );
      _events = res.map((j) => CalendarEventModel.fromJson(j)).toList();
      _status = CalendarStatus.success;

      // زمان‌بندی نوتیف برای اخبار مهم
      await _scheduleHighImpactNotifications();
    } catch (e) {
      _error  = e.toString();
      _status = CalendarStatus.error;
    }
    notifyListeners();
  }

  Future<void> _scheduleHighImpactNotifications() async {
    // اول همه نوتیف‌های قبلی تقویم رو لغو کن
    await NotificationService.instance.cancelAllCalendarNotifications();

    // بعد برای هر خبر مهم که هنوز نگذشته نوتیف بزار
    final highEvents = _events
        .where((e) => e.isHighImpact && e.eventTimeUtc != null)
        .toList();

    for (final event in highEvents) {
      final utcTime = event.eventTimeUtc!;
      final now     = DateTime.now().toUtc();

      // فقط اگه بیش از 10 دقیقه مونده
      if (utcTime.difference(now).inMinutes > 10) {
        // از hash id استفاده میکنیم
        final notifId = (event.id + event.title).hashCode.abs() % 100000;
        await NotificationService.instance.scheduleCalendarNotification(
          id:        notifId,
          title:     event.title,
          currency:  event.currency,
          eventTime: utcTime,
        );
      }
    }
  }

  Future<String?> _getTimezone() async {
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      return tzInfo.identifier;
    } catch (_) {
      return 'Asia/Tehran';
    }
  }

  void setImpactFilter(String? impact) {
    _filterImpact = impact;
    notifyListeners();
  }

  void setCurrencyFilter(String? currency) {
    _filterCurrency = currency;
    notifyListeners();
  }

  void clearFilters() {
    _filterImpact   = null;
    _filterCurrency = null;
    notifyListeners();
  }
}
