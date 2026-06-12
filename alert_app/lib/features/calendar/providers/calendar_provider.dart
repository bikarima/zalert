import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/calendar_filter.dart';
import '../../../core/models/calendar_event_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';

enum CalendarStatus { idle, loading, success, error }

class CalendarProvider extends ChangeNotifier {
  List<CalendarEventModel> _events = [];
  CalendarStatus _status  = CalendarStatus.idle;
  String? _error;
  String  _week           = 'thisweek';
  String? _userTimezone;
  CalendarFilter _filter  = CalendarFilter.defaultFilter;

  List<CalendarEventModel> get events  => _filtered();
  CalendarStatus           get status  => _status;
  String?                  get error   => _error;
  String                   get week    => _week;
  CalendarFilter           get filter  => _filter;

  CalendarEventModel? get nextHighImpact {
    final highs = _events
        .where((e) => e.isHighImpact && e.timeUntil != null)
        .toList()
      ..sort((a, b) => a.eventTimeUtc!.compareTo(b.eventTimeUtc!));
    return highs.isEmpty ? null : highs.first;
  }

  List<CalendarEventModel> _filtered() =>
      _events.where((e) => _filter.matches(e.impact, e.currency)).toList();

  Future<void> load({String week = 'thisweek', bool todayOnly = false}) async {
    _week   = week;
    _status = CalendarStatus.loading;
    _error  = null;
    notifyListeners();

    _userTimezone ??= await _getTimezone();

    try {
      final res = await ApiService.instance.getCalendar(
        week:      week,
        todayOnly: todayOnly,
        timezone:  _userTimezone,
      );
      _events = res.map((j) => CalendarEventModel.fromJson(j)).toList();
      _status = CalendarStatus.success;
      await _scheduleHighImpactNotifications();
    } catch (e) {
      _error  = e.toString();
      _status = CalendarStatus.error;
    }
    notifyListeners();
  }

  void applyFilter(CalendarFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void resetFilter() {
    _filter = CalendarFilter.defaultFilter;
    notifyListeners();
  }

  Future<void> _scheduleHighImpactNotifications() async {
    await NotificationService.instance.cancelAllCalendarNotifications();
    final highEvents = _events
        .where((e) => e.isHighImpact && e.eventTimeUtc != null)
        .toList();
    for (final event in highEvents) {
      final utcTime = event.eventTimeUtc!;
      final now     = DateTime.now().toUtc();
      if (utcTime.difference(now).inMinutes > 10) {
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
}
