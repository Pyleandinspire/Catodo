import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/ui/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AppTheme', () {
    test('buildLight 返回 useMaterial3 的 light 主题', () { final t = AppTheme.buildLight(); expect(t.useMaterial3, true); expect(t.brightness, Brightness.light); });
    test('buildDark 返回 dark 主题', () { final t = AppTheme.buildDark(); expect(t.brightness, Brightness.dark); });
    test('seed 派生的 primary 不为默认蓝', () { final t = AppTheme.buildLight(); expect(t.colorScheme.primary, isNot(const Color(0xFF2196F3))); expect(t.colorScheme.primary.a, 1.0); });
    test('CardTheme 圆角 14、elevation 0', () { final t = AppTheme.buildLight(); final shape = t.cardTheme.shape as RoundedRectangleBorder; expect((shape.borderRadius as BorderRadius).topLeft.x, 14.0); expect(t.cardTheme.elevation, 0.0); });
    test('InputDecorationTheme.filled == true', () { final t = AppTheme.buildLight(); expect(t.inputDecorationTheme.filled, true); });
    test('textTheme 已应用 PlusJakartaSans', () { final t = AppTheme.buildLight(); expect(t.textTheme.bodyMedium?.fontFamily, 'PlusJakartaSans'); expect(t.textTheme.bodyMedium?.fontFamilyFallback, contains('PingFang SC')); });
    test('fontFamily 与 fallback 常量正确', () { expect(AppTheme.fontFamily, 'PlusJakartaSans'); expect(AppTheme.fontFamilyFallback, contains('Microsoft YaHei')); });
  });
}
