import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    try {
      // 初始化时区数据库
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
      await _plugin.initialize(settings);
      _initialized = true;
    } catch (_) {
      _initialized = false;
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
          notificationId,
          task.title,
          task.description ?? '你有待办任务即将截止',
          tz.TZDateTime.from(reminderTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'todo_reminders_channel',
              '任务提醒',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        // Platform doesn't support notifications
      }
    }
  }

  Future<void> cancelTaskReminder(Task task) async {
    if (!_initialized) return;
    try {
      for (int i = 0; i < task.reminderTimes.length + 1; i++) {
        await _plugin.cancel(Object.hash(task.syncId, i));
      }
    } catch (_) {
      // Platform doesn't support notifications
    }
  }

  Future<void> showNotification(int id, String title, String body) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'todo_reminders_channel',
            '任务提醒',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // Platform doesn't support notifications
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
