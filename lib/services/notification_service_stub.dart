import '../models/task.dart';

/// 平台不支持本地通知时的空实现，所有方法均为 no-op。
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {}

  Future<void> scheduleTaskReminder(Task task) async {}

  Future<void> cancelTaskReminder(int taskId) async {}

  Future<void> showNotification(int id, String title, String body) async {}

  Future<void> rescheduleAllReminders(List<Task> tasks) async {}
}