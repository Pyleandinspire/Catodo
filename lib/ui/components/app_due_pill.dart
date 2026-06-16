import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppDuePill extends StatelessWidget {
  final DateTime? dueDate; final DateTime? now;
  const AppDuePill({super.key, this.dueDate, this.now});
  @override
  Widget build(BuildContext context) {
    final due = dueDate; if (due == null) return const SizedBox.shrink();
    final anchor = now ?? DateTime.now();
    final tone = _classify(due, anchor);
    final color = _colorFor(tone); final label = _labelFor(due, anchor, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp8, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(AppTokens.rSm)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
  _DueTone _classify(DateTime due, DateTime anchor) {
    final d = due.difference(DateTime(anchor.year, anchor.month, anchor.day)).inDays;
    if (d < 0) return _DueTone.overdue; if (d == 0) return _DueTone.today; if (d == 1) return _DueTone.tomorrow; if (d <= 7) return _DueTone.thisWeek; return _DueTone.later;
  }
  Color _colorFor(_DueTone t) { switch (t) { case _DueTone.overdue: return AppSemanticColors.overdue; case _DueTone.today: return AppSemanticColors.priorityMid; case _DueTone.tomorrow: case _DueTone.thisWeek: return AppSemanticColors.priorityLow; case _DueTone.later: return AppSemanticColors.priorityNone; } }
  String _labelFor(DateTime due, DateTime anchor, _DueTone tone) {
    final d = due.difference(DateTime(anchor.year, anchor.month, anchor.day)).inDays;
    String two(int v) => v.toString().padLeft(2, '0'); final hm = due.hour != 0 || due.minute != 0 ? ' ${two(due.hour)}:${two(due.minute)}' : '';
    switch (tone) { case _DueTone.overdue: return d == 0 ? '今天逾期' : '逾期 ${-d} 天'; case _DueTone.today: return '今天$hm'; case _DueTone.tomorrow: return '明天$hm'; case _DueTone.thisWeek: return '$d 天后'; case _DueTone.later: return '${due.month}/${due.day}'; }
  }
}
enum _DueTone { overdue, today, tomorrow, thisWeek, later }
