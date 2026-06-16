import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/ui/components/app_card.dart';
import 'package:catodo/ui/components/app_due_pill.dart';
import 'package:catodo/ui/components/app_empty_state.dart';
import 'package:catodo/ui/components/app_priority_chip.dart';
import 'package:catodo/ui/icons/app_icons.dart';
import 'package:catodo/ui/theme/app_theme.dart';
import 'package:catodo/ui/theme/app_tokens.dart';

Widget _wrap(Widget c) => MaterialApp(theme: AppTheme.buildLight(), home: Scaffold(body: c));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppCard', () {
    testWidgets('渲染 child', (t) async { await t.pumpWidget(_wrap(const AppCard(child: Text('h')))); expect(find.text('h'), findsOneWidget); });
    testWidgets('onTap', (t) async { var i=0; await t.pumpWidget(_wrap(AppCard(onTap:()=>i++, child:const Text('x')))); await t.tap(find.text('x')); await t.pumpAndSettle(); expect(i,1); });
  });

  group('AppPriorityChip', () {
    testWidgets('3→高', (t) async { await t.pumpWidget(_wrap(const AppPriorityChip(priority:3))); expect(find.text('高'), findsOneWidget); });
    testWidgets('2→中', (t) async { await t.pumpWidget(_wrap(const AppPriorityChip(priority:2))); expect(find.text('中'), findsOneWidget); });
    testWidgets('1→低', (t) async { await t.pumpWidget(_wrap(const AppPriorityChip(priority:1))); expect(find.text('低'), findsOneWidget); });
    testWidgets('0→无', (t) async { await t.pumpWidget(_wrap(const AppPriorityChip(priority:0))); expect(find.text('无'), findsOneWidget); });
    test('forPriority/label 一致', () { expect(AppSemanticColors.forPriority(3), AppSemanticColors.priorityHigh); expect(AppSemanticColors.labelForPriority(3),'高'); });
  });

  group('AppDuePill', () {
    final n = DateTime(2026,6,16,10);
    testWidgets('null 不渲染', (t) async { await t.pumpWidget(_wrap(AppDuePill(now: n))); expect(find.byType(Container), findsNothing); });
    testWidgets('今天', (t) async { await t.pumpWidget(_wrap(AppDuePill(dueDate:DateTime(2026,6,16,14,30), now:n))); expect(find.text('今天 14:30'), findsOneWidget); });
    testWidgets('明天', (t) async { await t.pumpWidget(_wrap(AppDuePill(dueDate:DateTime(2026,6,17), now:n))); expect(find.text('明天'), findsOneWidget); });
    testWidgets('3天后', (t) async { await t.pumpWidget(_wrap(AppDuePill(dueDate:DateTime(2026,6,19), now:n))); expect(find.text('3 天后'), findsOneWidget); });
    testWidgets('逾期2天', (t) async { await t.pumpWidget(_wrap(AppDuePill(dueDate:DateTime(2026,6,14), now:n))); expect(find.text('逾期 2 天'), findsOneWidget); });
    testWidgets('远日期', (t) async { await t.pumpWidget(_wrap(AppDuePill(dueDate:DateTime(2026,7,15), now:n))); expect(find.text('7/15'), findsOneWidget); });
  });

  group('AppEmptyState', () {
    testWidgets('渲染', (t) async { var p=0; await t.pumpWidget(_wrap(AppEmptyState(icon:AppIcons.list, title:'空', subtitle:'s', actionLabel:'新建', onAction:()=>p++)));
      expect(find.text('空'), findsOneWidget); expect(find.text('新建'), findsOneWidget);
      await t.tap(find.text('新建')); expect(p,1); });
    testWidgets('无按钮', (t) async { await t.pumpWidget(_wrap(AppEmptyState(icon:AppIcons.list, title:'t'))); expect(find.byType(FilledButton), findsNothing); });
  });

  group('AppTokens', () { test('间距递增', () { const xs=[AppTokens.sp4,AppTokens.sp8,AppTokens.sp12,AppTokens.sp16,AppTokens.sp20,AppTokens.sp24,AppTokens.sp32,AppTokens.sp40,AppTokens.sp48]; for(var i=0;i<xs.length-1;i++) expect(xs[i] < xs[i+1], true); }); });
}
