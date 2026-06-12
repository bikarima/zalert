import 'package:flutter/material.dart';
import '../../../core/models/calendar_event_model.dart';
import '../../../core/services/api_service.dart';

enum CalendarStatus { idle, loading, success, error }

class CalendarProvider extends ChangeNotifier {
  List<CalendarEventModel> _events = [];
  CalendarStatus _status = CalendarStatus.idle;
  String? _error;
  String _week = 'thisweek';
  String? _filterImpact;   // null = همه
  String? _filterCurrency; // null = همه

  List<CalendarEventModel> get events      => _filtered();
  CalendarStatus           get status      => _status;
  String?                  get error       => _error;
  String                   get week        => _week;
  String?                  get filterImpact   => _filterImpact;
  String?                  get filterCurrency => _filterCurrency;

  List<CalendarEventModel> _filtered() {
    var list = _events;
    if (_filterImpact != null) {
      list = list.where((e) => e.impact == _filterImpact).toList();
    }
    if (_filterCurrency != null) {
      list = list
          .where((e) =>
              e.currency.toUpperCase() == _filterCurrency!.toUpperCase())
          .toList();
    }
    return list;
  }

  Future<void> load({String week = 'thisweek', bool todayOnly = false}) async {
    _week   = week;
    _status = CalendarStatus.loading;
    _error  = null;
    notifyListeners();

    try {
      final res = await ApiService.instance.getCalendar(
        week: week,
        todayOnly: todayOnly,
      );
      _events = res.map((j) => CalendarEventModel.fromJson(j)).toList();
      _status = CalendarStatus.success;
    } catch (e) {
      _error  = e.toString();
      _status = CalendarStatus.error;
    }
    notifyListeners();
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
