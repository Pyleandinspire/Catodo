import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon; final String title; final String? subtitle; final String? actionLabel; final VoidCallback? onAction;
  const AppEmptyState({super.key, required this.icon, required this.title, this.subtitle, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(child: Padding(padding: const EdgeInsets.all(AppTokens.sp32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(AppTokens.sp24), decoration: BoxDecoration(color: scheme.primary.withAlpha(20), shape: BoxShape.circle), child: Icon(icon, size: 48, color: scheme.primary)),
      const SizedBox(height: AppTokens.sp24), Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      if (subtitle != null) ...[const SizedBox(height: AppTokens.sp8), Text(subtitle!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))],
      if (actionLabel != null && onAction != null) ...[const SizedBox(height: AppTokens.sp24), FilledButton(onPressed: onAction, child: Text(actionLabel!))],
    ])));
  }
}
