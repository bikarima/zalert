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
  // ── private constructor — هیچ کاری توش انجام نمیشه ─────────────
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // Firebase objects فقط بعد از initialize ساخته میشن
  FirebaseMessaging? _fcm;
  final _localNotif = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _ready = false;
  bool get ready => _ready;

  void Function(Map<String, dynamic> data)? onNotificationTap;

  Future<void> initialize() async {
    // ── 1. Firebase init ─────────────────────────────────────────
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[Push] Firebase.initializeApp failed: $e');
      return; // بدون push کار میکنیم
    }

    // ── 2. Local notifications channel ──────────────────────────
    try {
      const androidChannel = AndroidNotificationChannel(
        'alerts', 'Price Alerts',
        description: 'MT5 price alert notifications',
        importance: Importance.max,
        playSound: true,
      );
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      await _localNotif.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null) {
            try {
              onNotificationTap?.call(_parsePayload(details.payload!));
            } catch (_) {}
          }
        },
      );
    } catch (e) {
      debugPrint('[Push] Local notifications init failed: $e');
    }

    // ── 3. FCM — اینجا ساخته میشه، نه توی constructor ──────────
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
    await _localNotif.show(
      n.hashCode, n.title, n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alerts', 'Price Alerts',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
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
