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
  static final Map<String, int> _weekdayMap = {
    '周一': 1,
    '周二': 2,
    '周三': 3,
    '周四': 4,
    '周五': 5,
    '周六': 6,
    '周日': 7,
    '星期一': 1,
    '星期二': 2,
    '星期三': 3,
    '星期四': 4,
    '星期五': 5,
    '星期六': 6,
    '星期日': 7,
  };

  // 仅匹配作为时间表达的"X 点 / X:Y"，不再无条件匹配纯数字
  static final RegExp _strongDateRe =
      RegExp(r'(今天|今日|明天|明日|后天|后日|周[一二三四五六日]|星期[一二三四五六日])');
  // 可选的"上午/下午/晚上/凌晨/中午"前缀；用于 12 小时制 → 24 小时制转换
  static final RegExp _hourPointRe =
      RegExp(r'(上午|下午|晚上|凌晨|中午)?(\d{1,2})点(?:(\d{1,2})分?)?');
  static final RegExp _hmColonRe = RegExp(r'(\d{1,2}):(\d{1,2})');

  /// 输入是否含任何时间相关强信号；UI 据此决定是否显示预览卡。
  static bool hasAnyTimeSignal(String input) {
    return _strongDateRe.hasMatch(input) ||
        _hourPointRe.hasMatch(input) ||
        _hmColonRe.hasMatch(input);
  }

  /// 把 12 小时制 hour（带"上午/下午/晚上"等修饰）转 24 小时制。
  static int _toHour24(String? meridiem, int hour) {
    if (meridiem == null) return hour;
    switch (meridiem) {
      case '凌晨':
        // 凌晨 1-5 点保持原值，凌晨 12 点 → 0
        return hour == 12 ? 0 : hour;
      case '上午':
        return hour == 12 ? 0 : hour;
      case '中午':
        return 12;
      case '下午':
      case '晚上':
        return hour < 12 ? hour + 12 : hour;
      default:
        return hour;
    }
  }

  /// 解析自然语言中的中文相对日期与时间点。
  ///
  /// 设计原则：
  /// - 必须存在"今天/明天/后天/周X/星期X"或"X 点/X:Y"这类强信号才尝试构造 dueDate；
  /// - 没有任何信号时 confidence=30，title 原样返回，dueDate=null；
  /// - 时间点未给出时默认 09:00。
  static ParsedTask parseNaturalLanguage(String input) {
    if (!hasAnyTimeSignal(input)) {
      return ParsedTask(title: input.trim(), confidence: 30);
    }

    String title = input;
    DateTime? baseDate;
    int confidence = 70;

    final todayMatch = RegExp(r'(今天|今日)').firstMatch(input);
    final tomorrowMatch = RegExp(r'(明天|明日)').firstMatch(input);
    final dayAfterMatch = RegExp(r'(后天|后日)').firstMatch(input);
    final weekdayMatch =
        RegExp(r'(周[一二三四五六日]|星期[一二三四五六日])').firstMatch(input);

    final now = DateTime.now();

    if (todayMatch != null) {
      baseDate = DateTime(now.year, now.month, now.day);
      title = title.replaceAll(todayMatch.group(0)!, '').trim();
      confidence += 10;
    } else if (tomorrowMatch != null) {
      final t = now.add(const Duration(days: 1));
      baseDate = DateTime(t.year, t.month, t.day);
      title = title.replaceAll(tomorrowMatch.group(0)!, '').trim();
      confidence += 10;
    } else if (dayAfterMatch != null) {
      final t = now.add(const Duration(days: 2));
      baseDate = DateTime(t.year, t.month, t.day);
      title = title.replaceAll(dayAfterMatch.group(0)!, '').trim();
      confidence += 10;
    } else if (weekdayMatch != null) {
      final wd = _weekdayMap[weekdayMatch.group(0)];
      if (wd != null) {
        var daysToAdd = (wd - now.weekday + 7) % 7;
        if (daysToAdd == 0) daysToAdd = 7;
        final t = now.add(Duration(days: daysToAdd));
        baseDate = DateTime(t.year, t.month, t.day);
        title = title.replaceAll(weekdayMatch.group(0)!, '').trim();
        confidence += 10;
      }
    }

    int hour = 9;
    int minute = 0;
    bool timeMatched = false;

    final hp = _hourPointRe.firstMatch(input);
    if (hp != null) {
      final meridiem = hp.group(1);
      final h = int.tryParse(hp.group(2)!) ?? 9;
      hour = _toHour24(meridiem, h);
      final mStr = hp.group(3);
      if (mStr != null && mStr.isNotEmpty) {
        minute = int.tryParse(mStr) ?? 0;
      }
      title = title.replaceAll(hp.group(0)!, '').trim();
      timeMatched = true;
    } else {
      final hm = _hmColonRe.firstMatch(input);
      if (hm != null) {
        hour = int.tryParse(hm.group(1)!) ?? 9;
        minute = int.tryParse(hm.group(2)!) ?? 0;
        title = title.replaceAll(hm.group(0)!, '').trim();
        timeMatched = true;
      }
    }
    if (timeMatched) confidence += 10;

    hour = hour.clamp(0, 23);
    minute = minute.clamp(0, 59);

    DateTime? dueDate;
    if (baseDate != null) {
      dueDate = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        hour,
        minute,
      );
    } else if (timeMatched) {
      // 只有时间没有日期 → 默认今天的该时间；若已过则推到明天
      final today = DateTime(now.year, now.month, now.day, hour, minute);
      dueDate = today.isBefore(now) ? today.add(const Duration(days: 1)) : today;
    }

    title = title.trim();
    if (title.isEmpty) title = input;

    return ParsedTask(
      title: title,
      dueDate: dueDate,
      confidence: confidence.clamp(0, 100),
    );
  }
}
