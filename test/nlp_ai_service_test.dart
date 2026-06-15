import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/services/nlp_ai_service.dart';

void main() {
  group('NlpAiService.fromJsonForTest', () {
    test('基本字段解析', () {
      final p = NlpAiService.fromJsonForTest(
        {
          'title': '吃药',
          'dueDate': '2026-06-16T09:00',
          'priority': 2,
          'rrule': 'FREQ=DAILY;INTERVAL=1',
          'reminderOffsetsMin': [30, 0],
        },
        fallbackTitle: '原始',
      );
      expect(p, isNotNull);
      expect(p!.title, '吃药');
      expect(p.dueDate, DateTime(2026, 6, 16, 9));
      expect(p.priority, 2);
      expect(p.rrule, 'FREQ=DAILY;INTERVAL=1');
      expect(p.reminderOffsetsMin, [0, 30]);
    });

    test('null 字段被忽略，title 缺失回落到 fallbackTitle', () {
      final p = NlpAiService.fromJsonForTest(
        {'title': null, 'dueDate': null},
        fallbackTitle: '默认标题',
      );
      expect(p!.title, '默认标题');
      expect(p.dueDate, isNull);
      expect(p.priority, isNull);
      expect(p.rrule, isNull);
      expect(p.reminderOffsetsMin, isNull);
    });

    test('priority 字符串与越界被 clamp', () {
      final p = NlpAiService.fromJsonForTest(
        {'priority': '5'},
        fallbackTitle: '原文',
      );
      expect(p!.priority, 3);
    });

    test('reminderOffsetsMin 非数组返回 null', () {
      final p = NlpAiService.fromJsonForTest(
        {'reminderOffsetsMin': 30},
        fallbackTitle: '原文',
      );
      expect(p!.reminderOffsetsMin, isNull);
    });

    test('rrule 非空字符串保留，空串视作 null', () {
      final a = NlpAiService.fromJsonForTest(
        {'rrule': ''},
        fallbackTitle: 't',
      );
      expect(a!.rrule, isNull);
      final b = NlpAiService.fromJsonForTest(
        {'rrule': 'FREQ=WEEKLY'},
        fallbackTitle: 't',
      );
      expect(b!.rrule, 'FREQ=WEEKLY');
    });
  });
}
