import 'package:flutter_test/flutter_test.dart';
import '../lib/services/repeat_task_service.dart';
import '../lib/models/task.dart';

void main() {
  group('RepeatTaskService', () {
    late RepeatTaskService service;

    setUp(() {
      service = RepeatTaskService();
    });

    group('extractFreq', () {
      test('should extract DAILY freq', () {
        expect(service.extractFreq('FREQ=DAILY'), equals('DAILY'));
      });

      test('should extract WEEKLY freq', () {
        expect(service.extractFreq('FREQ=WEEKLY'), equals('WEEKLY'));
      });

      test('should extract MONTHLY freq', () {
        expect(service.extractFreq('FREQ=MONTHLY'), equals('MONTHLY'));
      });

      test('should handle case insensitivity', () {
        expect(service.extractFreq('freq=daily'), equals('DAILY'));
      });

      test('should return empty string for invalid rrule', () {
        expect(service.extractFreq('INVALID'), equals(''));
      });
    });

    group('extractInterval', () {
      test('should extract interval from rrule', () {
        expect(service.extractInterval('FREQ=DAILY;INTERVAL=2'), equals(2));
      });

      test('should return null when no interval', () {
        expect(service.extractInterval('FREQ=DAILY'), isNull);
      });

      test('should return null for invalid interval', () {
        expect(service.extractInterval('FREQ=DAILY;INTERVAL=abc'), isNull);
      });

      test('should extract interval 3', () {
        expect(service.extractInterval('FREQ=WEEKLY;INTERVAL=3'), equals(3));
      });
    });

    group('calculateNextDueDate', () {
      test('should return null when rrule is null', () {
        final task = Task(title: 'Test', rrule: null, dueDate: DateTime(2024, 1, 1));
        expect(service.calculateNextDueDate(task), isNull);
      });

      test('should return null when dueDate is null', () {
        final task = Task(title: 'Test', rrule: 'FREQ=DAILY', dueDate: null);
        expect(service.calculateNextDueDate(task), isNull);
      });

      test('should return null when freq is invalid', () {
        final task = Task(title: 'Test', rrule: 'INVALID', dueDate: DateTime(2024, 1, 1));
        expect(service.calculateNextDueDate(task), isNull);
      });

      test('should calculate next daily date with default interval', () {
        final task = Task(title: 'Test', rrule: 'FREQ=DAILY', dueDate: DateTime(2024, 1, 1));
        final nextDate = service.calculateNextDueDate(task);
        
        expect(nextDate, isNotNull);
        expect(nextDate!.year, equals(2024));
        expect(nextDate.month, equals(1));
        expect(nextDate.day, equals(2));
      });

      test('should calculate next daily date with interval 2', () {
        final task = Task(title: 'Test', rrule: 'FREQ=DAILY;INTERVAL=2', dueDate: DateTime(2024, 1, 1));
        final nextDate = service.calculateNextDueDate(task);
        
        expect(nextDate, isNotNull);
        expect(nextDate!.day, equals(3));
      });

      test('should calculate next daily date with interval 5', () {
        final task = Task(title: 'Test', rrule: 'FREQ=DAILY;INTERVAL=5', dueDate: DateTime(2024, 1, 1));
        final nextDate = service.calculateNextDueDate(task);
        
        expect(nextDate, isNotNull);
        expect(nextDate!.day, equals(6));
      });

      test('should calculate next weekly date', () {
        final task = Task(title: 'Test', rrule: 'FREQ=WEEKLY', dueDate: DateTime(2024, 1, 1));
        final nextDate = service.calculateNextDueDate(task);
        
        expect(nextDate, isNotNull);
        expect(nextDate!.day, equals(8));
      });

      test('should calculate next weekly date with interval 2', () {
        final task = Task(title: 'Test', rrule: 'FREQ=WEEKLY;INTERVAL=2', dueDate: DateTime(2024, 1, 1));
        final nextDate = service.calculateNextDueDate(task);
        
        expect(nextDate, isNotNull);
        expect(nextDate!.day, equals(15));
      });

      test('should calculate next monthly date', () {
        final task = Task(title: 'Test', rrule: 'FREQ=MONTHLY', dueDate: DateTime(2024, 1, 15));
        final nextDate = service.calculateNextDueDate(task);
        
        expect(nextDate, isNotNull);
        expect(nextDate!.month, equals(2));
        expect(nextDate!.day, equals(15));
      });

      test('should calculate next monthly date with interval 3', () {
        final task = Task(title: 'Test', rrule: 'FREQ=MONTHLY;INTERVAL=3', dueDate: DateTime(2024, 1, 15));
        final nextDate = service.calculateNextDueDate(task);
        
        expect(nextDate, isNotNull);
        expect(nextDate!.month, equals(4));
      });

      test('should handle month end correctly (January 31)', () {
        final task = Task(title: 'Test', rrule: 'FREQ=MONTHLY', dueDate: DateTime(2024, 1, 31));
        final nextDate = service.calculateNextDueDate(task);
        
        expect(nextDate, isNotNull);
        expect(nextDate!.month, equals(2));
        expect(nextDate!.day, equals(29));
      });

      test('should handle year boundary', () {
        final task = Task(title: 'Test', rrule: 'FREQ=MONTHLY', dueDate: DateTime(2024, 12, 15));
        final nextDate = service.calculateNextDueDate(task);
        
        expect(nextDate, isNotNull);
        expect(nextDate!.year, equals(2025));
        expect(nextDate!.month, equals(1));
      });
    });
  });
}