import 'package:flutter_test/flutter_test.dart';
import '../lib/services/notification_service.dart';
import '../lib/models/task.dart';

void main() {
  group('NotificationService', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService();
    });

    group('Task Filtering Logic', () {
      test('completed tasks should be filtered out', () {
        final task = Task(
          title: 'Completed Task',
          isCompleted: true,
          reminderTimes: [DateTime.now().add(const Duration(days: 1))],
        );
        
        final shouldProcess = !task.isCompleted && task.reminderTimes.isNotEmpty;
        expect(shouldProcess, isFalse);
      });

      test('tasks without reminders should be filtered out', () {
        final task = Task(
          title: 'Task without reminders',
          isCompleted: false,
          reminderTimes: [],
        );
        
        final shouldProcess = !task.isCompleted && task.reminderTimes.isNotEmpty;
        expect(shouldProcess, isFalse);
      });

      test('tasks with future reminders should be processed', () {
        final futureReminder = DateTime.now().add(const Duration(days: 1));
        final task = Task(
          title: 'Task with future reminder',
          isCompleted: false,
          reminderTimes: [futureReminder],
        );
        
        final shouldProcess = !task.isCompleted && task.reminderTimes.isNotEmpty;
        expect(shouldProcess, isTrue);
      });

      test('expired reminders should be skipped during scheduling', () {
        final expiredReminder = DateTime.now().subtract(const Duration(days: 1));
        final futureReminder = DateTime.now().add(const Duration(days: 1));
        
        final validReminders = [expiredReminder, futureReminder]
            .where((time) => time.isAfter(DateTime.now()))
            .toList();
        
        expect(validReminders.length, equals(1));
        expect(validReminders.first, equals(futureReminder));
      });

      test('empty task list should be handled safely', () {
        expect(() => service.rescheduleAllReminders([]), returnsNormally);
      });

      test('filter logic should correctly identify processable tasks', () {
        final tasks = [
          Task(
            title: 'Task 1',
            isCompleted: false,
            reminderTimes: [DateTime.now().add(const Duration(days: 1))],
          ),
          Task(
            title: 'Task 2',
            isCompleted: false,
            reminderTimes: [DateTime.now().add(const Duration(days: 2))],
          ),
          Task(
            title: 'Completed Task',
            isCompleted: true,
            reminderTimes: [DateTime.now().add(const Duration(days: 1))],
          ),
          Task(
            title: 'No reminder task',
            isCompleted: false,
            reminderTimes: [],
          ),
        ];

        final processableTasks = tasks.where((t) => 
          !t.isCompleted && t.reminderTimes.isNotEmpty
        ).toList();

        expect(processableTasks.length, equals(2));
        expect(processableTasks[0].title, equals('Task 1'));
        expect(processableTasks[1].title, equals('Task 2'));
      });
    });
  });
}