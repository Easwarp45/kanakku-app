import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// Centralized service to display immediate local OS notification banners.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Initialize notification settings for Android and iOS
  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification clicked with payload: ${response.payload}');
      },
    );
  }

  /// Request permissions dynamically for Android 13+ / iOS
  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.requestNotificationsPermission() ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosImplementation = _localNotifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ?? false;
    }
    return false;
  }

  /// Show a direct local notification banner immediately
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String type,
    bool sound = true,
    bool vibrate = true,
    bool dnd = false,
    String? payload,
  }) async {
    if (dnd) return; // Suppress notification if Do Not Disturb is enabled

    final androidDetails = AndroidNotificationDetails(
      'kanakku_smart_notifications',
      'Financial Updates',
      channelDescription: 'Ecosystem notifications for finance activity',
      importance: Importance.max,
      priority: Priority.high,
      playSound: sound,
      enableVibration: vibrate,
      styleInformation: const BigTextStyleInformation(''),
    );

    final iosDetails = DarwinNotificationDetails(
      presentSound: sound,
      presentAlert: true,
      presentBadge: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _localNotifications.show(id, title, body, details, payload: payload);
  }
}
