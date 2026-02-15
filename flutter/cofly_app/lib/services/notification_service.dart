import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/platform_helper.dart';

/// 本地通知服务（单例）
class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Windows 通知设置
    const windowsSettings = WindowsInitializationSettings(
      appName: '沙河小狗',
      appUserModelId: 'org.shahe.cofly',
      guid: '5365dfdd-f287-4780-bbfa-8eb0e1c8c008',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      macOS: darwinSettings,
      iOS: darwinSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request permissions per platform
    if (Platform.isWindows) {
      // Windows 不需要额外请求权限
    } else if (PlatformHelper.isDesktop) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Show a message notification
  Future<void> showMessageNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'cofly_messages',
      'Messages',
      channelDescription: 'Cofly chat message notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Windows 通知详情 (使用默认构造)
    const windowsDetails = WindowsNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      macOS: darwinDetails,
      iOS: darwinDetails,
      windows: windowsDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// Notification tap callback — bring window to front
  void _onNotificationTap(NotificationResponse response) async {
    if (PlatformHelper.isDesktop) {
      await windowManager.show();
      await windowManager.focus();
    }
    // On mobile, tapping the notification automatically brings the app to front
  }
}
