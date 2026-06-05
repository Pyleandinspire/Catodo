import 'dart:convert';

class ParsedTask {
  final String title;
  final DateTime? dueDate;
  final int confidence;

  ParsedTask({
    required this.title,
    this.dueDate,
    required this.confidence,
  });
}

class NlpService {
  static final Map<String, String> _weekdayMap = {
    '周一': '1',
    '周二': '2',
    '周三': '3',
    '周四': '4',
    '周五': '5',
    '周六': '6',
    '周日': '7',
    '星期日': '7',
    '星期一': '1',
    '星期二': '2',
    '星期三': '3',
    '星期四': '4',
    '星期五': '5',
    '星期六': '6',
  };

  static ParsedTask parseNaturalLanguage(String input) {
    String title = input;
    DateTime? dueDate;
    int confidence = 70;

    final todayMatch = RegExp(r'(今天|今日)').firstMatch(input);
    final tomorrowMatch = RegExp(r'(明天|明日)').firstMatch(input);
    final dayAfterMatch = RegExp(r'(后天|后日)').firstMatch(input);
    final weekdayMatch = RegExp(r'(周[一二三四五六日]|星期[一二三四五六日])').firstMatch(input);

    DateTime baseDate = DateTime.now();

    if (todayMatch != null) {
      baseDate = DateTime.now();
      title = input.replaceAll(todayMatch.group(0)!, '').trim();
      confidence += 10;
    } else if (tomorrowMatch != null) {
      baseDate = DateTime.now().add(const Duration(days: 1));
      title = input.replaceAll(tomorrowMatch.group(0)!, '').trim();
      confidence += 10;
    } else if (dayAfterMatch != null) {
      baseDate = DateTime.now().add(const Duration(days: 2));
      title = input.replaceAll(dayAfterMatch.group(0)!, '').trim();
      confidence += 10;
    } else if (weekdayMatch != null) {
      final weekday = _weekdayMap[weekdayMatch.group(0)];
      if (weekday != null) {
        final targetWeekday = int.parse(weekday);
        int daysToAdd = (targetWeekday - baseDate.weekday + 7) % 7;
        if (daysToAdd == 0) daysToAdd = 7;
        baseDate = DateTime.now().add(Duration(days: daysToAdd));
        title = input.replaceAll(weekdayMatch.group(0)!, '').trim();
        confidence += 10;
      }
    }

    final timeMatch = RegExp(r'(\d{1,2})[:：]?(\d{1,2})?\s*(点|分|时)?').firstMatch(input);
    final hourMinuteMatch = RegExp(r'(\d{1,2})点(\d{1,2})?分?').firstMatch(input);

    int hour = 9;
    int minute = 0;

    if (hourMinuteMatch != null) {
      hour = int.tryParse(hourMinuteMatch.group(1)!) ?? 9;
      minute = int.tryParse(hourMinuteMatch.group(2)!) ?? 0;
      title = input.replaceAll(hourMinuteMatch.group(0)!, '').trim();
      confidence += 10;
    } else if (timeMatch != null) {
      hour = int.tryParse(timeMatch.group(1)!) ?? 9;
      minute = int.tryParse(timeMatch.group(2)!) ?? 0;
      title = input.replaceAll(timeMatch.group(0)!, '').trim();
      confidence += 10;
    }

    hour = hour.clamp(0, 23);
    minute = minute.clamp(0, 59);

    if (todayMatch != null || tomorrowMatch != null || dayAfterMatch != null || weekdayMatch != null) {
      dueDate = DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    }

    title = title.trim();
    if (title.isEmpty) {
      title = input;
    }

    return ParsedTask(
      title: title,
      dueDate: dueDate,
      confidence: confidence.clamp(0, 100),
    );
  }
}