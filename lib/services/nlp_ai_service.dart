import 'package:flutter/foundation.dart';

import 'ai_service.dart';

/// AI 高准确度任务解析结果。
///
/// 与 NlpService.ParsedTask 平行，但携带更多字段（rrule / reminderOffsetsMin / priority）。
class AiParsedTask {
  /// 抽取得到的任务标题；解析失败时回落到原文。
  final String title;

  /// 截止日期；null 表示模型也无法确定。
  final DateTime? dueDate;

  /// 优先级 1/2/3，null 表示未指定。
  final int? priority;

  /// 重复规则 RRULE 字符串（RFC 5545），null 表示一次性任务。
  final String? rrule;

  /// 提醒偏移列表（截止前 N 分钟）；null/空表示不自动加提醒。
  final List<int>? reminderOffsetsMin;

  const AiParsedTask({
    required this.title,
    this.dueDate,
    this.priority,
    this.rrule,
    this.reminderOffsetsMin,
  });
}

/// 用 AI 高准确度解析自然语言任务输入。
///
/// 包装 [AIService.requestStructuredOutput]，注入"当下时间"作为 system 锚点，
/// 输出严格 JSON：{title, dueDate, priority, rrule, reminderOffsetsMin}。
class NlpAiService {
  final AIService aiService;

  NlpAiService(this.aiService);

  /// 解析单段输入；任何失败返回 null，由 UI 决定是否回落到本地正则。
  Future<AiParsedTask?> parse(String input, {DateTime? now}) async {
    final n = now ?? DateTime.now();
    final isoNow = n.toIso8601String();
    final systemPrompt =
        '''
你是一个任务时间抽取器。从用户输入中抽出任务信息，仅返回 JSON：
{
  "title": "任务标题（不含日期/时间词）",
  "dueDate": "YYYY-MM-DDTHH:mm" 或 null,
  "priority": 1|2|3 或 null,
  "rrule": "FREQ=DAILY;INTERVAL=1" 或 null,
  "reminderOffsetsMin": [30, 0] 或 null
}
当下时间：$isoNow（请据此解析"今天/明天/下周X"等相对表达）。
- dueDate 必须包含时间，没有具体时间时默认 09:00。
- 一次性任务 rrule=null；周/月级重复请用 RFC 5545 RRULE。
- reminderOffsetsMin 是"截止前 N 分钟"的整数数组（升序，可为空）。
- 完全无法确定的字段填 null，不要编造。
''';

    final result = await aiService.requestStructuredOutput(
      systemPrompt: systemPrompt,
      userPrompt: input,
    );
    if (result == null) return null;

    return _fromJson(result, fallbackTitle: input.trim());
  }

  @visibleForTesting
  static AiParsedTask? fromJsonForTest(
    Map<String, dynamic> json, {
    required String fallbackTitle,
  }) =>
      _fromJson(json, fallbackTitle: fallbackTitle);

  static AiParsedTask? _fromJson(
    Map<String, dynamic> json, {
    required String fallbackTitle,
  }) {
    final title = (json['title'] as String?)?.trim();
    final dueRaw = json['dueDate'];
    DateTime? due;
    if (dueRaw is String && dueRaw.isNotEmpty) {
      due = DateTime.tryParse(dueRaw);
    }
    final pr = json['priority'];
    int? priority;
    if (pr is int) {
      priority = pr.clamp(1, 3);
    } else if (pr is String) {
      priority = int.tryParse(pr)?.clamp(1, 3);
    }
    final rruleRaw = json['rrule'];
    final rrule = (rruleRaw is String && rruleRaw.isNotEmpty) ? rruleRaw : null;

    final offRaw = json['reminderOffsetsMin'];
    List<int>? offsets;
    if (offRaw is List) {
      offsets = <int>[];
      for (final v in offRaw) {
        if (v is int) {
          offsets.add(v);
        } else if (v is String) {
          final n = int.tryParse(v);
          if (n != null) offsets.add(n);
        }
      }
      offsets.sort();
      if (offsets.isEmpty) offsets = null;
    }

    return AiParsedTask(
      title: (title == null || title.isEmpty) ? fallbackTitle : title,
      dueDate: due,
      priority: priority,
      rrule: rrule,
      reminderOffsetsMin: offsets,
    );
  }
}
