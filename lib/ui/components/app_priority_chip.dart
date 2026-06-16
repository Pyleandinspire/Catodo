import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppPriorityChip extends StatelessWidget {
  final int priority; final bool compact;
  const AppPriorityChip({super.key, required this.priority, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final color = AppSemanticColors.forPriority(priority);
    final label = AppSemanticColors.labelForPriority(priority);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? AppTokens.sp8 : AppTokens.sp12, vertical: compact ? 2 : AppTokens.sp4),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(AppTokens.rPill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: AppTokens.sp4), Text(label, style: TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
