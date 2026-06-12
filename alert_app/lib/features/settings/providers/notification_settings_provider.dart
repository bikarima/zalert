import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsProvider extends ChangeNotifier {
  // ── Alert Notifications ───────────────────────────────────────────
  bool _alertTriggered   = true;   // وقتی آلرت فعال میشه
  bool _alertCreated     = true;   // وقتی آلرت ثبت میشه
  bool _alertSound       = true;   // صدا
  bool _alertVibration   = true;   // لرزش

  // ── Calendar Notifications ────────────────────────────────────────
  bool _calendarHighOnly = true;   // فقط high impact
  bool _calendarReminder = true;   // ۱۰ دقیقه قبل از خبر
  int  _calendarMinutes  = 10;     // چند دقیقه قبل

  // ── General ───────────────────────────────────────────────────────
  bool _quietHoursEnabled = false;
  int  _quietStart        = 23;   // ساعت شروع quiet hours
  int  _quietEnd          = 7;    // ساعت پایان quiet hours
  bool _showBadge         = true;

  bool get alertTriggered    => _alertTriggered;
  bool get alertCreated      => _alertCreated;
  bool get alertSound        => _alertSound;
  bool get alertVibration    => _alertVibration;
  bool get calendarHighOnly  => _calendarHighOnly;
  bool get calendarReminder  => _calendarReminder;
  int  get calendarMinutes   => _calendarMinutes;
  bool get quietHoursEnabled => _quietHoursEnabled;
  int  get quietStart        => _quietStart;
  int  get quietEnd          => _quietEnd;
  bool get showBadge         => _showBadge;

  NotificationSettingsProvider() { _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _alertTriggered    = p.getBool('notif_alert_triggered')   ?? true;
    _alertCreated      = p.getBool('notif_alert_created')     ?? true;
    _alertSound        = p.getBool('notif_alert_sound')       ?? true;
    _alertVibration    = p.getBool('notif_alert_vibration')   ?? true;
    _calendarHighOnly  = p.getBool('notif_cal_high_only')     ?? true;
    _calendarReminder  = p.getBool('notif_cal_reminder')      ?? true;
    _calendarMinutes   = p.getInt ('notif_cal_minutes')       ?? 10;
    _quietHoursEnabled = p.getBool('notif_quiet_enabled')     ?? false;
    _quietStart        = p.getInt ('notif_quiet_start')       ?? 23;
    _quietEnd          = p.getInt ('notif_quiet_end')         ?? 7;
    _showBadge         = p.getBool('notif_show_badge')        ?? true;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('notif_alert_triggered',  _alertTriggered);
    await p.setBool('notif_alert_created',    _alertCreated);
    await p.setBool('notif_alert_sound',      _alertSound);
    await p.setBool('notif_alert_vibration',  _alertVibration);
    await p.setBool('notif_cal_high_only',    _calendarHighOnly);
    await p.setBool('notif_cal_reminder',     _calendarReminder);
    await p.setInt ('notif_cal_minutes',      _calendarMinutes);
    await p.setBool('notif_quiet_enabled',    _quietHoursEnabled);
    await p.setInt ('notif_quiet_start',      _quietStart);
    await p.setInt ('notif_quiet_end',        _quietEnd);
    await p.setBool('notif_show_badge',       _showBadge);
  }

  void setAlertTriggered(bool v)   { _alertTriggered    = v; _notify(); }
  void setAlertCreated(bool v)     { _alertCreated      = v; _notify(); }
  void setAlertSound(bool v)       { _alertSound        = v; _notify(); }
  void setAlertVibration(bool v)   { _alertVibration    = v; _notify(); }
  void setCalendarHighOnly(bool v) { _calendarHighOnly  = v; _notify(); }
  void setCalendarReminder(bool v) { _calendarReminder  = v; _notify(); }
  void setCalendarMinutes(int v)   { _calendarMinutes   = v; _notify(); }
  void setQuietEnabled(bool v)     { _quietHoursEnabled = v; _notify(); }
  void setQuietStart(int v)        { _quietStart        = v; _notify(); }
  void setQuietEnd(int v)          { _quietEnd          = v; _notify(); }
  void setShowBadge(bool v)        { _showBadge         = v; _notify(); }

  void _notify() {
    notifyListeners();
    _save();
  }

  /// آیا الان quiet hours هست؟
  bool get isQuietHour {
    if (!_quietHoursEnabled) return false;
    final hour = DateTime.now().hour;
    if (_quietStart > _quietEnd) {
      return hour >= _quietStart || hour < _quietEnd;
    }
    return hour >= _quietStart && hour < _quietEnd;
  }
}
