import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:flutter/foundation.dart';

import '../utils/app_navigator.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final fln.FlutterLocalNotificationsPlugin _notificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Create the channel FCM pushes target (functions payload references
    // 'cofiz_main_channel'). Without it Android 8+ falls back to a silent
    // "Miscellaneous" channel for background pushes.
    const channel = fln.AndroidNotificationChannel(
      'cofiz_main_channel',
      'Cofiz Notifications',
      description: 'Main channel for app notifications',
      importance: fln.Importance.max,
    );
    try {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              fln.AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (_) {
      // Non-Android platform or plugin unavailable - not fatal.
    }

    const fln.AndroidInitializationSettings initializationSettingsAndroid =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');

    const fln.DarwinInitializationSettings initializationSettingsDarwin =
        fln.DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const fln.InitializationSettings initializationSettings =
        fln.InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    try {
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          final payload = details.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final map = jsonDecode(payload) as Map<String, dynamic>;
            final type = map['type']?.toString() ?? 'info';
            final data = <String, String>{};
            final raw = map['data'];
            if (raw is Map) {
              raw.forEach((k, v) => data[k.toString()] = v.toString());
            }
            AppNavigator.openNotificationType(type, data);
          } catch (_) {
            AppNavigator.openNotificationType('info');
          }
        },
      )
          // A stuck platform channel must not block app startup (hot-restart
          // hang); a timeout leaves the app running without notifications.
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[Notifications] initialize failed/timed out: $e');
    }

    _isInitialized = true;
  }

  Future<bool?> requestPermissions() async {
    final android = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final ios = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            fln.IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    return android ?? ios;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const fln.AndroidNotificationDetails androidDetails =
        fln.AndroidNotificationDetails(
      'cofiz_main_channel',
      'Cofiz Notifications',
      channelDescription: 'Main channel for app notifications',
      importance: fln.Importance.max,
      priority: fln.Priority.high,
    );

    const fln.NotificationDetails details = fln.NotificationDetails(
      android: androidDetails,
      iOS: fln.DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(id, title, body, details, payload: payload);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
