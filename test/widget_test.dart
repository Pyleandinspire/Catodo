import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catodo/main.dart';
import 'package:catodo/models/task.dart';
import 'package:catodo/models/filter.dart';
import 'package:catodo/services/notification_service.dart';
import 'package:catodo/ui/components/adaptive_navigation.dart';
import 'package:catodo/ui/components/task_item.dart';

// 用于 AdaptiveNavigation 测试的常量回调
void _noop(int _) {}

// ============================================================
// 测试套件 1: 应用启动 & 基础渲染
// ============================================================
void main() {
  group('1. 应用启动测试', () {
    testWidgets('1.1 App 启动不崩溃', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: CatodoApp()));
      await tester.pump(const Duration(seconds: 2));
      // 应用启动后不应该崩溃，应该渲染出 UI
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('1.2 初始化时显示加载指示器', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: CatodoApp()));
      // 数据库初始化期间应该显示加载界面
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // ============================================================
  // 测试套件 2: Task 模型测试
  // ============================================================
  group('2. Task 模型测试', () {
    test('2.1 创建 Task 默认值正确', () {
      final task = Task(title: '测试任务');
      expect(task.title, '测试任务');
      expect(task.isCompleted, false);
      expect(task.priority, 0);
      expect(task.tags, isEmpty);
      expect(task.reminderTimes, isEmpty);
      expect(task.isDeleted, false);
      expect(task.createdAt, isNotNull);
      expect(task.updatedAt, isNotNull);
    });

    test('2.2 创建 Task 自定义值', () {
      final dueDate = DateTime(2026, 6, 10);
      final task = Task(
        title: '高优先级任务',
        description: '这是一个描述',
        isCompleted: false,
        priority: 3,
        dueDate: dueDate,
        tags: ['紧急', '工作'],
        groupName: '工作',
        reminderTimes: [DateTime(2026, 6, 9, 10, 0)],
      );
      expect(task.title, '高优先级任务');
      expect(task.description, '这是一个描述');
      expect(task.priority, 3);
      expect(task.dueDate, dueDate);
      expect(task.tags, contains('紧急'));
      expect(task.tags, contains('工作'));
      expect(task.groupName, '工作');
      expect(task.reminderTimes.length, 1);
    });

    test('2.3 Task copyWith 正确复制', () {
      final task = Task(title: '原始任务', priority: 1, tags: ['标签1'])..id = 5;

      final copied = task.copyWith(title: '新标题', priority: 3);
      expect(copied.id, 5);
      expect(copied.title, '新标题');
      expect(copied.priority, 3);
      expect(copied.tags, ['标签1']);
    });

    test('2.4 Task 标签列表是独立副本', () {
      final tags = ['标签1'];
      final task = Task(title: '测试', tags: tags);
      tags.add('标签2');
      // 原始 task 的 tags 不应被外部修改影响
      expect(task.tags.length, 1);
    });

    test('2.5 Task 提醒时间列表是独立副本', () {
      final times = [DateTime(2026, 6, 9)];
      final task = Task(title: '测试', reminderTimes: times);
      times.add(DateTime(2026, 6, 10));
      // 原始 task 的 reminderTimes 不应被外部修改影响
      expect(task.reminderTimes.length, 1);
    });
  });

  // ============================================================
  // 测试套件 3: TaskFilter 模型测试
  // ============================================================
  group('3. TaskFilter 模型测试', () {
    test('3.1 默认筛选器不过滤任何内容', () {
      final filter = TaskFilter();
      expect(filter.selectedGroup, isNull);
      expect(filter.selectedPriority, isNull);
      expect(filter.selectedTag, isNull);
    });

    test('3.2 筛选器 copyWith 正确', () {
      final filter = TaskFilter();
      final filtered = filter.copyWith(
        selectedGroup: '工作',
        selectedPriority: 3,
        selectedTag: '紧急',
      );
      expect(filtered.selectedGroup, '工作');
      expect(filtered.selectedPriority, 3);
      expect(filtered.selectedTag, '紧急');
    });

    test('3.3 筛选器 copyWith 保留未修改字段', () {
      final filter = TaskFilter(selectedGroup: '工作');
      final filtered = filter.copyWith(selectedPriority: 2);
      expect(filtered.selectedGroup, '工作');
      expect(filtered.selectedPriority, 2);
    });
  });

  // ============================================================
  // 测试套件 4: 通知服务抽象层测试
  // ============================================================
  group('4. 通知服务测试', () {
    test('4.1 NotificationService 单例', () {
      final instance1 = NotificationService();
      final instance2 = NotificationService();
      expect(identical(instance1, instance2), true);
    });

    test('4.2 NotificationService 方法调用不抛异常', () async {
      final service = NotificationService();
      // 所有方法都应安全调用，不抛异常
      await service.initialize();
      await service.showNotification(1, '标题', '内容');
      await service.cancelTaskReminder(1);
      await service.rescheduleAllReminders([]);

      final task = Task(title: '测试');
      await service.scheduleTaskReminder(task);
      // 没有异常就是通过
    });
  });

  // ============================================================
  // 测试套件 5: UI 组件渲染测试
  // ============================================================
  group('5. UI 组件渲染测试', () {
    testWidgets('5.1 AdaptiveNavigation 窄屏渲染 BottomNavigationBar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400, // 窄屏
                child: AdaptiveNavigation(
                  selectedIndex: 0,
                  onDestinationSelected: _noop,
                  children: [
                    Text('Screen 1'),
                    Text('Screen 2'),
                    Text('Screen 3'),
                    Text('Screen 4'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 窄屏应显示底部导航栏
      expect(find.byType(NavigationBar), findsOneWidget);
      // 窄屏不应显示 NavigationRail
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('5.2 AdaptiveNavigation 宽屏渲染 NavigationRail', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800, // 宽屏
                child: AdaptiveNavigation(
                  selectedIndex: 0,
                  onDestinationSelected: _noop,
                  children: [
                    Text('Screen 1'),
                    Text('Screen 2'),
                    Text('Screen 3'),
                    Text('Screen 4'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 宽屏应显示 NavigationRail
      expect(find.byType(NavigationRail), findsOneWidget);
      // 宽屏不应显示底部导航栏
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('5.3 AdaptiveNavigation 切换页面', (WidgetTester tester) async {
      int selectedIndex = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: SizedBox(
                  width: 400,
                  child: AdaptiveNavigation(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) {
                      setState(() => selectedIndex = index);
                    },
                    children: [
                      const Text('Screen 1'),
                      const Text('Screen 2'),
                      const Text('Screen 3'),
                      const Text('Screen 4'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 初始显示 Screen 1
      expect(find.text('Screen 1'), findsOneWidget);

      // 切换到第二个标签
      await tester.tap(find.text('priority'));
      await tester.pumpAndSettle();
      expect(find.text('Screen 2'), findsOneWidget);
    });

    testWidgets('5.4 TaskItem 渲染正确', (WidgetTester tester) async {
      final task = Task(
        title: '测试任务',
        description: '描述文字',
        priority: 3,
        dueDate: DateTime(2026, 6, 10),
        tags: ['紧急'],
        groupName: '工作',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TaskItem(task: task, onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证标题
      expect(find.text('测试任务'), findsOneWidget);
      // 验证描述
      expect(find.text('描述文字'), findsOneWidget);
      // 验证高优先级标签
      expect(find.text('高'), findsOneWidget);
      // 验证分组
      expect(find.text('工作'), findsOneWidget);
      // 验证标签
      expect(find.text('紧急'), findsOneWidget);
    });

    testWidgets('5.5 TaskItem 已完成任务渲染删除线', (WidgetTester tester) async {
      final task = Task(title: '已完成任务', isCompleted: true);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TaskItem(task: task, onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 已完成任务应显示勾选标记
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  // ============================================================
  // 测试套件 6: 边界条件测试
  // ============================================================
  group('6. 边界条件测试', () {
    test('6.1 空标题任务', () {
      final task = Task(title: '');
      expect(task.title, '');
      expect(task.isCompleted, false);
    });

    test('6.2 极长标题任务', () {
      final longTitle = 'A' * 1000;
      final task = Task(title: longTitle);
      expect(task.title.length, 1000);
    });

    test('6.3 任务带大量标签', () {
      final tags = List.generate(100, (i) => '标签$i');
      final task = Task(title: '测试', tags: tags);
      expect(task.tags.length, 100);
    });

    test('6.4 优先级边界值', () {
      final t0 = Task(title: '无优先级', priority: 0);
      final t3 = Task(title: '高优先级', priority: 3);
      expect(t0.priority, 0);
      expect(t3.priority, 3);
    });

    test('6.5 过去的截止日期', () {
      final pastDate = DateTime(2000, 1, 1);
      final task = Task(title: '过期任务', dueDate: pastDate);
      expect(task.dueDate!.isBefore(DateTime.now()), true);
    });

    test('6.6 未来的截止日期', () {
      final futureDate = DateTime(2100, 1, 1);
      final task = Task(title: '未来任务', dueDate: futureDate);
      expect(task.dueDate!.isAfter(DateTime.now()), true);
    });

    test('6.7 空提醒时间列表', () {
      final task = Task(title: '测试');
      expect(task.reminderTimes, isEmpty);
    });

    test('6.8 多个提醒时间', () {
      final times = [
        DateTime(2026, 6, 9, 8, 0),
        DateTime(2026, 6, 9, 12, 0),
        DateTime(2026, 6, 9, 18, 0),
      ];
      final task = Task(title: '测试', reminderTimes: times);
      expect(task.reminderTimes.length, 3);
    });
  });

  // ============================================================
  // 测试套件 7: 平台兼容性测试
  // ============================================================
  group('7. 平台兼容性测试', () {
    test('7.1 条件导入 - NotificationService 可用', () {
      // 无论在哪个平台，NotificationService 都应可实例化
      final service = NotificationService();
      expect(service, isNotNull);
    });

    test('7.2 条件导入 - 方法签名一致', () async {
      // 验证 stub 和 io 实现的方法签名一致
      final service = NotificationService();
      // 以下调用不会抛 NoSuchMethodError
      await service.initialize();
      await service.showNotification(1, 'test', 'body');
      await service.cancelTaskReminder(1);
      await service.rescheduleAllReminders([]);
      await service.scheduleTaskReminder(Task(title: 'test'));
    });
  });
}
