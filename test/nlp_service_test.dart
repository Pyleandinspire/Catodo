import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/services/nlp_service.dart';

void main() {
  group('hasAnyTimeSignal', () {
    test('强信号：今天/明天/后天/周X/星期X', () {
      expect(NlpService.hasAnyTimeSignal('今天买菜'), isTrue);
      expect(NlpService.hasAnyTimeSignal('明天上午开会'), isTrue);
      expect(NlpService.hasAnyTimeSignal('后天交报告'), isTrue);
      expect(NlpService.hasAnyTimeSignal('周五跟客户'), isTrue);
      expect(NlpService.hasAnyTimeSignal('星期日体检'), isTrue);
    });

    test('强信号：X 点 / X:Y', () {
      expect(NlpService.hasAnyTimeSignal('15点开会'), isTrue);
      expect(NlpService.hasAnyTimeSignal('15:30 同步'), isTrue);
    });

    test('纯标题不触发（如"完成 3 月报告"）', () {
      expect(NlpService.hasAnyTimeSignal('完成 3 月报告'), isFalse);
      expect(NlpService.hasAnyTimeSignal('做项目 2 的 PPT'), isFalse);
    });
  });

  group('parseNaturalLanguage', () {
    test('明天下午 3 点开会 → date=明天 15:00, title="开会", confidence ≥ 80', () {
      final r = NlpService.parseNaturalLanguage('明天下午3点开会');
      expect(r.dueDate, isNotNull);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(r.dueDate!.year, tomorrow.year);
      expect(r.dueDate!.month, tomorrow.month);
      expect(r.dueDate!.day, tomorrow.day);
      expect(r.dueDate!.hour, 15);
      expect(r.dueDate!.minute, 0);
      expect(r.title.contains('开会'), isTrue);
      expect(r.confidence, greaterThanOrEqualTo(80));
    });

    test('"明天" 默认 09:00 ，confidence ≥ 80', () {
      final r = NlpService.parseNaturalLanguage('明天');
      expect(r.dueDate, isNotNull);
      expect(r.dueDate!.hour, 9);
      expect(r.dueDate!.minute, 0);
      expect(r.confidence, greaterThanOrEqualTo(80));
    });

    test('"完成 3 月报告" 不识别为今天 3 点', () {
      final r = NlpService.parseNaturalLanguage('完成 3 月报告');
      expect(r.dueDate, isNull);
      expect(r.confidence, lessThan(50));
    });

    test('周五 10 点 → 命中下一个周五 10:00', () {
      final r = NlpService.parseNaturalLanguage('周五10点拜访客户');
      expect(r.dueDate, isNotNull);
      expect(r.dueDate!.weekday, 5);
      expect(r.dueDate!.hour, 10);
      expect(r.title.contains('拜访客户'), isTrue);
    });

    test('15:30 同步 → date 在今天或明天，时间 15:30', () {
      final r = NlpService.parseNaturalLanguage('15:30 同步');
      expect(r.dueDate, isNotNull);
      expect(r.dueDate!.hour, 15);
      expect(r.dueDate!.minute, 30);
    });
  });
}
