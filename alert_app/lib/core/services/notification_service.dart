import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

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

  // callback وقتی روی نوتیف کلیک شد
  void Function(Map<String, dynamic> data)? onNotificationTap;

  // کانال‌های نوتیفیکیشن
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

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[Push] Firebase.initializeApp failed: $e');
      return;
    }

    // ساخت کانال‌های اندروید
    final androidPlugin = _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channelAlerts);
    await androidPlugin?.createNotificationChannel(_channelTriggered);

    // درخواست نمایش badge
    await androidPlugin?.requestNotificationsPermission();

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

    try {
      _fcm = FirebaseMessaging.instance;
      await _fcm!.requestPermission(alert: true, sound: true, badge: true);
      _fcmToken = await _fcm!.getToken();
      debugPrint('[Push] FCM token: $_fcmToken');

      _fcm!.onTokenRefresh.listen((t) => _fcmToken = t);
      FirebaseMessaging.onMessage.listen(_showLocalNotification);
      FirebaseMessaging.onMessageOpenedApp
          .listen((m) => onNotificationTap?.call(m.data));
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      _ready = true;
    } catch (e) {
      debugPrint('[Push] FCM setup failed: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;

    final isTriggered =
        message.data['type'] == 'alert_triggered';
    final symbol = message.data['symbol'] ?? '';

    await _localNotif.show(
      message.hashCode,
      n.title ?? '🔔 Alert',
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isTriggered ? _channelTriggered.id : _channelAlerts.id,
          isTriggered ? _channelTriggered.name : _channelAlerts.name,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          // رنگ متفاوت برای triggered
          color: isTriggered
              ? const Color(0xFF00E676)
              : const Color(0xFF6C63FF),
          icon: '@mipmap/ic_launcher',
          // action button
          actions: isTriggered
              ? [
                  const AndroidNotificationAction(
                    'view_alert',
                    'مشاهده',
                    showsUserInterface: true,
                    cancelNotification: true,
                  ),
                ]
              : null,
          styleInformation: BigTextStyleInformation(
            n.body ?? '',
            summaryText: symbol,
          ),
        ),
      ),
      payload: message.data.toString(),
    );
  }

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
void _backgroundNotifHandler(NotificationResponse response) {
  // handle background notification tap
}
