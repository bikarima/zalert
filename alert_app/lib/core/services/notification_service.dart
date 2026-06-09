import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// هندلر پیام‌های background — باید top-level باشه
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  NotificationService.instance._showLocalNotification(message);
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // callback — وقتی روی نوتیف کلیک شد
  void Function(Map<String, dynamic> data)? onNotificationTap;

  Future<void> initialize() async {
    await Firebase.initializeApp();

    // کانال اندروید
    const androidChannel = AndroidNotificationChannel(
      'alerts',
      'Price Alerts',
      description: 'MT5 price alert notifications',
      importance: Importance.max,
      playSound: true,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // تنظیمات local notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          // payload رو parse کن و callback رو صدا بزن
          try {
            final data = _parsePayload(details.payload!);
            onNotificationTap?.call(data);
          } catch (_) {}
        }
      },
    );

    // درخواست permission
    await _fcm.requestPermission(alert: true, sound: true, badge: true);

    // دریافت token
    _fcmToken = await _fcm.getToken();

    // آپدیت token وقتی عوض شد
    _fcm.onTokenRefresh.listen((token) {
      _fcmToken = token;
    });

    // پیام‌های foreground
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // وقتی اپ از background باز میشه
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onNotificationTap?.call(message.data);
    });

    // handler برای background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification == null) return;

    _localNotif.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'alerts',
          'Price Alerts',
          channelDescription: 'MT5 price alert notifications',
          importance: Importance.max,
          priority: Priority.high,
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          playSound: true,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  Map<String, dynamic> _parsePayload(String payload) {
    // payload به شکل {key: value, ...} ذخیره شده
    final result = <String, dynamic>{};
    final cleaned = payload.replaceAll('{', '').replaceAll('}', '');
    for (final pair in cleaned.split(', ')) {
      final parts = pair.split(': ');
      if (parts.length == 2) result[parts[0].trim()] = parts[1].trim();
    }
    return result;
  }
}
