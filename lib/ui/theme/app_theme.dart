import 'package:flutter/material.dart';

/// Catodo 全局主题（PLAN-UI-001-1 + PLAN-UI-001-1b）。
///
/// - 颜色：以 `#5145FF`（图标紫蓝）为 seed，自动生成 light / dark Material 3 ColorScheme。
/// - 字体：英文 Plus Jakarta Sans（本地打包）；中文回退到平台系统字体。
/// - 样式：圆角 14 卡片 / 圆角 12 按钮+输入框、轻阴影。
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF5145FF);
  static const String fontFamily = 'PlusJakartaSans';
  static const List<String> fontFamilyFallback = <String>[
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'sans-serif',
  ];

  static ThemeData buildLight() {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    return _build(scheme, Brightness.light);
  }

  static ThemeData buildDark() {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
    return _build(scheme, Brightness.dark);
  }

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
    final textTheme = base.textTheme.apply(fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback);

    Color cardColor() {
      try { return scheme.surfaceContainerLow; } catch (_) { return scheme.surface; }
    }
    Color inputFill() {
      try { return scheme.surfaceContainerHigh; } catch (_) { return scheme.surfaceContainerHighest; }
    }

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: 0, color: cardColor(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.primary, width: 2)),
        filled: true, fillColor: inputFill(),
      ),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      snackBarTheme: SnackBarThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), behavior: SnackBarBehavior.floating),
    );
  }
}
