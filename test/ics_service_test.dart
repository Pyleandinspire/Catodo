import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/models/task.dart';
import 'package:catodo/services/ics_service.dart';

void main() {
  group('IcsService.generateIcs', () {
    test('生成包含 VCALENDAR 头尾', () {
      final ics = IcsService.generateIcs([]);
      expect(ics.contains('BEGIN:VCALENDAR'), true);
      expect(ics.contains('END:VCALENDAR'), true);
      expect(ics.contains('VERSION:2.0'), true);
    });

    test('每个任务生成一个 VEVENT', () {
      final tasks = [
        Task(title: '任务A'),
        Task(title: '任务B'),
      ];
      final ics = IcsService.generateIcs(tasks);
      final beginCount = 'BEGIN:VEVENT'.allMatches(ics).length;
      final endCount = 'END:VEVENT'.allMatches(ics).length;
      expect(beginCount, 2);
      expect(endCount, 2);
    });

    test('标签写入 CATEGORIES', () {
      final task = Task(title: '带标签', tags: const ['工作', '紧急']);
      final ics = IcsService.generateIcs([task]);
      expect(ics.contains('CATEGORIES:工作,紧急'), true);
    });

    test('转义特殊字符', () {
      final task = Task(
        title: 'A,B',
        description: '行1\n行2',
      );
      final ics = IcsService.generateIcs([task]);
      expect(ics.contains('SUMMARY:A\\,B'), true);
      expect(ics.contains('DESCRIPTION:行1\\n行2'), true);
    });
  });

  group('IcsService.parseIcs', () {
    test('解析单个 VEVENT', () {
      const content = '''BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:测试任务
DESCRIPTION:测试描述
END:VEVENT
END:VCALENDAR''';
      final tasks = IcsService.parseIcs(content);
      expect(tasks.length, 1);
      expect(tasks[0].title, '测试任务');
      expect(tasks[0].description, '测试描述');
    });

    test('解析多个 VEVENT', () {
      const content = '''BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:A
END:VEVENT
BEGIN:VEVENT
SUMMARY:B
END:VEVENT
END:VCALENDAR''';
      final tasks = IcsService.parseIcs(content);
      expect(tasks.length, 2);
      expect(tasks[0].title, 'A');
      expect(tasks[1].title, 'B');
    });

    test('解析 DTSTART 日期', () {
      const content = '''BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:带日期
DTSTART:20240115T120000Z
END:VEVENT
END:VCALENDAR''';
      final tasks = IcsService.parseIcs(content);
      expect(tasks.length, 1);
      expect(tasks[0].dueDate, isNotNull);
      expect(tasks[0].dueDate!.year, 2024);
      expect(tasks[0].dueDate!.month, 1);
      expect(tasks[0].dueDate!.day, 15);
    });

    test('反转义特殊字符', () {
      const content = '''BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:A\\,B
DESCRIPTION:行1\\n行2
END:VEVENT
END:VCALENDAR''';
      final tasks = IcsService.parseIcs(content);
      expect(tasks.length, 1);
      expect(tasks[0].title, 'A,B');
      expect(tasks[0].description, '行1\n行2');
    });

    test('忽略空 SUMMARY', () {
      const content = '''BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:
END:VEVENT
END:VCALENDAR''';
      final tasks = IcsService.parseIcs(content);
      expect(tasks, isEmpty);
    });
  });

  group('IcsService 双向往返', () {
    test('生成后解析应保留主要字段', () {
      final original = Task(
        title: '完整任务',
        description: '描述内容',
        dueDate: DateTime.utc(2024, 6, 5, 10, 30, 0),
        tags: const ['标签1', '标签2'],
      );
      final ics = IcsService.generateIcs([original]);
      final parsed = IcsService.parseIcs(ics);

      expect(parsed.length, 1);
      expect(parsed[0].title, original.title);
      expect(parsed[0].description, original.description);
      expect(parsed[0].dueDate, original.dueDate);
    });
  });
}
