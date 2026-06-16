import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child; final EdgeInsetsGeometry padding; final VoidCallback? onTap; final Color? color; final Color? borderColor; final BorderRadiusGeometry? borderRadius;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppTokens.sp16), this.onTap, this.color, this.borderColor, this.borderRadius});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color resolvedColor() { if (color != null) return color!; try { return scheme.surfaceContainerLow; } catch (_) { return scheme.surface; } }
    final radius = borderRadius ?? BorderRadius.circular(AppTokens.rLg);
    return Material(
      color: resolvedColor(), shape: RoundedRectangleBorder(borderRadius: radius, side: borderColor != null ? BorderSide(color: borderColor!) : BorderSide.none),
      clipBehavior: Clip.antiAlias, child: InkWell(onTap: onTap, borderRadius: radius is BorderRadius ? radius : null, child: Padding(padding: padding, child: child)),
    );
  }
}
