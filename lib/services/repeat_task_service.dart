import '../models/task.dart';

class RepeatTaskService {
  static final RepeatTaskService _instance = RepeatTaskService._internal();
  factory RepeatTaskService() => _instance;
  RepeatTaskService._internal();

  String extractFreq(String rrule) {
    final match = RegExp(r'FREQ=(\w+)', caseSensitive: false).firstMatch(rrule);
    return match?.group(1)?.toUpperCase() ?? '';
  }

  int? extractInterval(String rrule) {
    final match = RegExp(r'INTERVAL=(\d+)').firstMatch(rrule);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  DateTime? calculateNextDueDate(Task task) {
    if (task.rrule == null || task.rrule!.isEmpty) return null;
    if (task.dueDate == null) return null;

    final freq = extractFreq(task.rrule!);
    final interval = extractInterval(task.rrule!) ?? 1;

    switch (freq) {
      case 'DAILY':
        return task.dueDate!.add(Duration(days: interval));
      case 'WEEKLY':
        return task.dueDate!.add(Duration(days: interval * 7));
      case 'MONTHLY':
        return _addMonths(task.dueDate!, interval);
      default:
        return null;
    }
  }

  DateTime _addMonths(DateTime date, int months) {
    int year = date.year;
    int month = date.month + months;

    while (month > 12) {
      month -= 12;
      year++;
    }

    int day = date.day;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    if (day > lastDayOfMonth) {
      day = lastDayOfMonth;
    }

    return DateTime(year, month, day, date.hour, date.minute);
  }

  Task? generateNextRepeatTask(Task parentTask) {
    if (!parentTask.isRepeatParent || parentTask.rrule == null) return null;

    final nextDueDate = calculateNextDueDate(parentTask);
    if (nextDueDate == null) return null;

    return Task(
      title: parentTask.title,
      description: parentTask.description,
      priority: parentTask.priority,
      dueDate: nextDueDate,
      tags: List.from(parentTask.tags),
      groupName: parentTask.groupName,
      rrule: parentTask.rrule,
      isRepeatParent: false,
      reminderTimes: parentTask.reminderTimes
          .map((rt) => DateTime(
                nextDueDate.year,
                nextDueDate.month,
                nextDueDate.day,
                rt.hour,
                rt.minute,
              ))
          .toList(),
    );
  }
}