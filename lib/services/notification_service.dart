import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const DarwinInitializationSettings macosSettings = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macosSettings,
    );
    await _plugin.initialize(settings);
  }

  Future<void> scheduleTaskReminder(Task task) async {
    if (task.dueDate == null || task.reminderTimes.isEmpty) return;

    for (var i = 0; i < task.reminderTimes.length; i++) {
      final reminderTime = task.reminderTimes[i];
      if (reminderTime.isBefore(DateTime.now())) continue;

      final notificationId = task.id * 10 + i;

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
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelTaskReminder(int taskId) async {
    for (int i = 0; i < 10; i++) {
      await _plugin.cancel(taskId * 10 + i);
    }
  }

  Future<void> showNotification(int id, String title, String body) async {
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
  }
}