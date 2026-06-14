import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// ── Background handler — MUST be top-level, not inside any class ──────────────
// Runs in a separate Dart isolate. Cannot access any singleton instances.
// Creates its own local-notifications instance for display.

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final localNotif = FlutterLocalNotificationsPlugin();
  await localNotif.initialize(
    InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,   // already granted — don't re-prompt
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );

  final n = message.notification;
  if (n == null) return;

  final isTriggered = message.data['type'] == 'alert_triggered';
  final channelId   = isTriggered ? 'triggered' : 'alerts';
  final channelName = isTriggered ? 'Alert Triggered' : 'Price Alerts';

  await localNotif.show(
    message.hashCode,
    n.title ?? '🔔 ZAlert',
    n.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId, channelName,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(n.body ?? ''),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    // Store payload as proper JSON so _parsePayload can decode it reliably
    payload: jsonEncode(message.data),
  );
}

// ── Background local-notification tap handler ─────────────────────────────────
@pragma('vm:entry-point')
void _backgroundLocalNotifHandler(NotificationResponse response) {
  // Intentionally empty — app handles this when it resumes via getInitialMessage
}

// ── Service ───────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  FirebaseMessaging?                 _fcm;
  final _localNotif = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _ready = false;
  bool get ready => _ready;

  /// Called when a notification is tapped.
  /// Signature: `(Map<String, dynamic> data) → void`
  void Function(Map<String, dynamic> data)? onNotificationTap;

  /// Called when the FCM token is refreshed.
  /// Use to re-register the new token with your server.
  void Function(String newToken)? onTokenRefresh;

  // ── Notification channels ─────────────────────────────────────────────────

  static const _chAlerts = AndroidNotificationChannel(
    'alerts', 'Price Alerts',
    description: 'ZAlert price alert notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFF6C63FF),
  );

  static const _chTriggered = AndroidNotificationChannel(
    'triggered', 'Alert Triggered',
    description: 'Fires when your price target is hit',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFF00E676),
  );

  static const _chCalendar = AndroidNotificationChannel(
    'calendar', 'Economic Calendar',
    description: 'High-impact economic event reminders',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFFFF5252),
  );

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // Timezone
    tz_data.initializeTimeZones();
    try {
      final tzName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(tzName));
      debugPrint('[Push] Timezone: $tzName');
    } catch (e) {
      debugPrint('[Push] Timezone error: $e');
    }

    // Firebase
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[Push] Firebase init failed: $e');
      return;
    }

    // Android channels (must exist before any notification is shown)
    final androidPlugin = _localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_chAlerts);
    await androidPlugin?.createNotificationChannel(_chTriggered);
    await androidPlugin?.createNotificationChannel(_chCalendar);
    await androidPlugin?.requestNotificationsPermission();

    // Local notifications
    await _localNotif.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          notificationCategories: [
            DarwinNotificationCategory(
              'alert_triggered',
              actions: [
                DarwinNotificationAction.plain(
                  'view_alert', 'مشاهده آلرت',
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          onNotificationTap?.call(_parsePayload(details.payload!));
        }
      },
      onDidReceiveBackgroundNotificationResponse: _backgroundLocalNotifHandler,
    );

    // FCM
    try {
      _fcm = FirebaseMessaging.instance;

      // iOS permission — use provisional for quieter first-ask experience
      final settings = await _fcm!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: true,    // silent delivery on iOS until user decides
        sound: true,
      );
      debugPrint('[Push] Permission: ${settings.authorizationStatus}');

      // iOS foreground presentation
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get / refresh token
      _fcmToken = await _fcm!.getToken();
      debugPrint('[Push] Token: ${_fcmToken?.substring(0, 20)}…');

      // Token refresh — caller re-registers with server
      _fcm!.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('[Push] Token refreshed');
        onTokenRefresh?.call(newToken);
      });

      // Foreground: FCM doesn't auto-show → show via local notifications
      FirebaseMessaging.onMessage.listen((msg) {
        debugPrint('[Push] Foreground: ${msg.notification?.title}');
        _showLocalNotification(msg);
      });

      // Background tap: app already running but in background
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        debugPrint('[Push] Background tap: ${msg.data}');
        onNotificationTap?.call(msg.data);
      });

      // Terminated tap: app was closed, user tapped notification to open it
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        debugPrint('[Push] Terminated tap: ${initial.data}');
        // Delay slightly so the app is fully built before we navigate
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onNotificationTap?.call(initial.data);
        });
      }

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      _ready = true;
      debugPrint('[Push] ✅ Ready');
    } catch (e) {
      debugPrint('[Push] FCM setup error: $e');
    }
  }

  // ── Show local notification ───────────────────────────────────────────────

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;

    final isTriggered = message.data['type'] == 'alert_triggered';
    final channel     = isTriggered ? _chTriggered : _chAlerts;

    await _localNotif.show(
      message.hashCode,
      n.title ?? '🔔 ZAlert',
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id, channel.name,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          color: channel.ledColor,
          icon: '@mipmap/ic_launcher',
          actions: isTriggered
              ? const [
                  AndroidNotificationAction(
                    'view_alert', 'مشاهده آلرت',
                    showsUserInterface: true,
                    cancelNotification: true,
                  ),
                ]
              : null,
          styleInformation: BigTextStyleInformation(
            n.body ?? '',
            summaryText: message.data['symbol'] ?? '',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'alert_triggered',
        ),
      ),
      // Use JSON encode so payload is reliably parseable
      payload: jsonEncode(message.data),
    );
  }

  // ── Test notification ─────────────────────────────────────────────────────

  Future<void> showTestNotification(String lang) async {
    await _localNotif.show(
      999,
      lang == 'fa' ? '🔔 تست نوتیفیکیشن' : '🔔 Test Notification',
      lang == 'fa'
          ? 'اگه این رو میبینی، push notification کار میکنه ✅'
          : 'If you see this, push notifications are working ✅',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _chAlerts.id, _chAlerts.name,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          color: const Color(0xFF6C63FF),
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode({'type': 'test'}),
    );
  }

  // ── Scheduled calendar notifications ─────────────────────────────────────

  Future<void> scheduleCalendarNotification({
    required int      id,
    required String   title,
    required String   currency,
    required DateTime eventTime,    // UTC
    int minutesBefore = 10,
  }) async {
    final notifTime = eventTime.subtract(Duration(minutes: minutesBefore));
    if (notifTime.isBefore(DateTime.now().toUtc())) return;

    final tzTime = tz.TZDateTime.from(notifTime, tz.local);

    await _localNotif.zonedSchedule(
      id,
      '🔴 خبر مهم در $minutesBefore دقیقه دیگر',
      '$currency — $title',
      tzTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _chCalendar.id, _chCalendar.name,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          color: const Color(0xFFFF5252),
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            '$currency — $title',
            contentTitle: '🔴 خبر مهم در $minutesBefore دقیقه',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({'type': 'calendar', 'event_id': id}),
    );
    debugPrint('[CalNotif] Scheduled: $title @ $tzTime');
  }

  Future<void> cancelCalendarNotification(int id) =>
      _localNotif.cancel(id);

  Future<void> cancelAllCalendarNotifications() async {
    final pending = await _localNotif.pendingNotificationRequests();
    for (final n in pending) {
      try {
        final data = jsonDecode(n.payload ?? '{}') as Map<String, dynamic>;
        if (data['type'] == 'calendar') await _localNotif.cancel(n.id);
      } catch (_) {}
    }
  }

  // ── Utils ─────────────────────────────────────────────────────────────────

  /// Parse notification payload stored as JSON.
  Map<String, dynamic> _parsePayload(String payload) {
    try {
      return Map<String, dynamic>.from(jsonDecode(payload) as Map);
    } catch (_) {
      // Fallback for legacy payloads stored as Map.toString()
      final result = <String, dynamic>{};
      final cleaned = payload.replaceAll('{', '').replaceAll('}', '');
      for (final pair in cleaned.split(', ')) {
        final parts = pair.split(': ');
        if (parts.length == 2) result[parts[0].trim()] = parts[1].trim();
      }
      return result;
    }
  }
}
