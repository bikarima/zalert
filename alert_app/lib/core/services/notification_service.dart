import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    await NotificationService.instance._showLocalNotification(message);
  } catch (e) {
    debugPrint('[Push Background] error: $e');
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  FirebaseMessaging? _fcm;
  final _localNotif = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  bool _ready = false;
  bool get ready => _ready;

  void Function(Map<String, dynamic> data)? onNotificationTap;

  // کانال‌ها
  static const _channelAlerts = AndroidNotificationChannel(
    'alerts', 'Price Alerts',
    description: 'MT5 price alert notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFF6C63FF),
  );

  static const _channelTriggered = AndroidNotificationChannel(
    'triggered', 'Alert Triggered',
    description: 'When your price target is hit',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFF00E676),
  );

  static const _channelCalendar = AndroidNotificationChannel(
    'calendar', 'Economic Calendar',
    description: 'High impact news reminders',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFFFF5252),
  );

  Future<void> initialize() async {
    // راه‌اندازی timezone
    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final tzName = tzInfo.identifier;
      tz.setLocalLocation(tz.getLocation(tzName));
      debugPrint('[TZ] Timezone: $tzName');
    } catch (e) {
      debugPrint('[TZ] Could not get timezone: $e');
    }

    // Firebase
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[Push] Firebase.initializeApp failed: $e');
      return;
    }

    // کانال‌های اندروید
    final androidPlugin = _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channelAlerts);
    await androidPlugin?.createNotificationChannel(_channelTriggered);
    await androidPlugin?.createNotificationChannel(_channelCalendar);
    await androidPlugin?.requestNotificationsPermission();

    // راه‌اندازی local notifications
    await _localNotif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (details) {
        try {
          if (details.payload != null) {
            onNotificationTap?.call(_parsePayload(details.payload!));
          }
        } catch (_) {}
      },
      onDidReceiveBackgroundNotificationResponse: _backgroundNotifHandler,
    );

    // FCM
    try {
      _fcm = FirebaseMessaging.instance;
      await _fcm!.requestPermission(alert: true, sound: true, badge: true);
      _fcmToken = await _fcm!.getToken();
      debugPrint('[Push] FCM token: $_fcmToken');
      _fcm!.onTokenRefresh.listen((t) => _fcmToken = t);
      FirebaseMessaging.onMessage.listen(_showLocalNotification);
      FirebaseMessaging.onMessageOpenedApp
          .listen((m) => onNotificationTap?.call(m.data));
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      _ready = true;
    } catch (e) {
      debugPrint('[Push] FCM setup failed: $e');
    }
  }

  // ── Push notifications ────────────────────────────────────────────

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    final isTriggered = message.data['type'] == 'alert_triggered';
    final symbol = message.data['symbol'] ?? '';
    final channelId   = isTriggered ? _channelTriggered.id : _channelAlerts.id;
    final channelName = isTriggered ? _channelTriggered.name : _channelAlerts.name;
    final ledColor    = isTriggered ? const Color(0xFF00E676) : const Color(0xFF6C63FF);

    await _localNotif.show(
      message.hashCode,
      n.title ?? '🔔 Alert',
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId, channelName,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          color: ledColor,
          icon: '@mipmap/ic_launcher',
          actions: isTriggered
              ? const [AndroidNotificationAction(
                  'view_alert', 'مشاهده',
                  showsUserInterface: true,
                  cancelNotification: true,
                )]
              : null,
          styleInformation: BigTextStyleInformation(
            n.body ?? '', summaryText: symbol),
        ),
      ),
      payload: message.data.toString(),
    );
  }

  // ── Scheduled calendar notifications ─────────────────────────────

  /// زمان‌بندی نوتیف 10 دقیقه قبل از خبر مهم
  Future<void> scheduleCalendarNotification({
    required int id,
    required String title,
    required String currency,
    required DateTime eventTime,     // زمان دقیق رویداد (UTC)
  }) async {
    final notifTime = eventTime.subtract(const Duration(minutes: 10));
    final now       = DateTime.now().toUtc();

    if (notifTime.isBefore(now)) return; // گذشته

    final tzNotifTime = tz.TZDateTime.from(notifTime, tz.local);

    await _localNotif.zonedSchedule(
      id,
      '🔴 خبر مهم در ۱۰ دقیقه دیگر',
      '$currency — $title',
      tzNotifTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelCalendar.id,
          _channelCalendar.name,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          color: const Color(0xFFFF5252),
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            '$currency — $title',
            contentTitle: '🔴 خبر مهم در ۱۰ دقیقه',
          ),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'calendar:$id',
    );
    debugPrint('[Calendar Notif] Scheduled: $title @ $tzNotifTime');
  }

  /// لغو یه نوتیف تقویم
  Future<void> cancelCalendarNotification(int id) async {
    await _localNotif.cancel(id);
  }

  /// لغو همه نوتیف‌های تقویم
  Future<void> cancelAllCalendarNotifications() async {
    final pending = await _localNotif.pendingNotificationRequests();
    for (final n in pending) {
      if (n.payload?.startsWith('calendar:') == true) {
        await _localNotif.cancel(n.id);
      }
    }
  }

  // ── Utils ─────────────────────────────────────────────────────────

  Map<String, dynamic> _parsePayload(String payload) {
    final result = <String, dynamic>{};
    final cleaned = payload.replaceAll('{', '').replaceAll('}', '');
    for (final pair in cleaned.split(', ')) {
      final parts = pair.split(': ');
      if (parts.length == 2) result[parts[0].trim()] = parts[1].trim();
    }
    return result;
  }
}

@pragma('vm:entry-point')
void _backgroundNotifHandler(NotificationResponse response) {}
