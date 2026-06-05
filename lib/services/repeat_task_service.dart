import '../models/task.dart';

class RepeatTaskService {
  static DateTime? calculateNextDate(Task task) {
    if (task.rrule == null || task.rrule!.isEmpty) return null;
    if (task.dueDate == null) return null;

    try {
      final rruleStr = task.rrule!;
      
      if (rruleStr.contains('FREQ=DAILY')) {
        int interval = 1;
        final intervalMatch = RegExp(r'INTERVAL=(\d+)').firstMatch(rruleStr);
        if (intervalMatch != null) {
          interval = int.parse(intervalMatch.group(1)!);
        }
        return task.dueDate!.add(Duration(days: interval));
      }
      
      if (rruleStr.contains('FREQ=WEEKLY')) {
        int interval = 1;
        final intervalMatch = RegExp(r'INTERVAL=(\d+)').firstMatch(rruleStr);
        if (intervalMatch != null) {
          interval = int.parse(intervalMatch.group(1)!);
        }
        return task.dueDate!.add(Duration(days: interval * 7));
      }
      
      if (rruleStr.contains('FREQ=MONTHLY')) {
        int interval = 1;
        final intervalMatch = RegExp(r'INTERVAL=(\d+)').firstMatch(rruleStr);
        if (intervalMatch != null) {
          interval = int.parse(intervalMatch.group(1)!);
        }
        return DateTime(
          task.dueDate!.year,
          task.dueDate!.month + interval,
          task.dueDate!.day,
        );
      }
      
      return task.dueDate!.add(const Duration(days: 1));
    } catch (e) {
      return null;
    }
  }

  static Task createNextTask(Task parentTask) {
    final nextDate = calculateNextDate(parentTask);
    if (nextDate == null) {
      throw Exception('无法计算下一个循环日期');
    }

    return Task(
      title: parentTask.title,
      description: parentTask.description,
      priority: parentTask.priority,
      dueDate: nextDate,
      tags: List.from(parentTask.tags),
      groupName: parentTask.groupName,
      rrule: parentTask.rrule,
      isRepeatParent: true,
    );
  }

  static bool isRepeatTask(Task task) {
    return task.rrule != null && task.rrule!.isNotEmpty;
  }
}