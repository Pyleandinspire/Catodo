import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

/// 本地通知服务（io 平台实现）。
///
/// 设计要点（PLAN-AI-001-8）：
/// - **不再依赖 permission_handler**：通知权限改用 `flutter_local_notifications`
///   自带 API，按平台分流。Windows / Linux 不需要权限请求。
/// - 所有方法对 `_initialized=false` 友好：失败/未初始化时静默 no-op，不抛异常。
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    try {
      tz_data.initializeTimeZones();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();
      const DarwinInitializationSettings macosSettings =
          DarwinInitializationSettings();
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: macosSettings,
      );
      await _plugin.initialize(settings: settings);
      _initialized = true;

      // 按平台请求通知权限：Windows / Linux 不需要
      await _requestPlatformPermissions();
    } catch (e) {
      _initialized = false;
      debugPrint('NotificationService.initialize failed: $e');
    }
  }

  /// 按平台请求通知权限。失败不抛异常（仅 debugPrint）。
  Future<void> _requestPlatformPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        // Android 13+ 才会真正弹运行时对话框；老版本是 no-op
        await androidImpl?.requestNotificationsPermission();
        // Android 14+ 精确闹钟需要单独权限（zonedSchedule + exactAllowWhileIdle）
        await androidImpl?.requestExactAlarmsPermission();
      } else if (Platform.isIOS) {
        final iosImpl = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else if (Platform.isMacOS) {
        final macImpl = _plugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
        await macImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      // Windows / Linux：通知不需要运行时权限
    } catch (e) {
      debugPrint('NotificationService._requestPlatformPermissions failed: $e');
    }
  }

  Future<void> scheduleTaskReminder(Task task) async {
    if (!_initialized) return;
    if (task.dueDate == null || task.reminderTimes.isEmpty) return;

    for (var i = 0; i < task.reminderTimes.length; i++) {
      final reminderTime = task.reminderTimes[i];
      if (reminderTime.isBefore(DateTime.now())) continue;

      final notificationId = Object.hash(task.syncId, i);

      try {
        await _plugin.zonedSchedule(
          id: notificationId,
          title: task.title,
          body: task.description ?? '你有待办任务即将截止',
          scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'todo_reminders_channel',
              '任务提醒',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
            macOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('scheduleTaskReminder failed: $e');
      }
    }
  }

  Future<void> cancelTaskReminder(Task task) async {
    if (!_initialized) return;
    try {
      for (int i = 0; i < task.reminderTimes.length + 1; i++) {
        await _plugin.cancel(id: Object.hash(task.syncId, i));
      }
    } catch (e) {
      debugPrint('cancelTaskReminder failed: $e');
    }
  }

  Future<void> showNotification(int id, String title, String body) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'todo_reminders_channel',
            '任务提醒',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('showNotification failed: $e');
    }
  }

  Future<void> rescheduleAllReminders(List<Task> tasks) async {
    if (!_initialized) return;
    for (var task in tasks) {
      if (task.isCompleted) continue;
      if (task.reminderTimes.isEmpty) continue;
      await scheduleTaskReminder(task);
    }
  }
}
