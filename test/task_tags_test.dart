import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/models/task.dart';
import 'package:catodo/models/filter.dart';

void main() {
  group('Task 标签测试', () {
    test('构造函数应创建独立的标签列表副本', () {
      final original = <String>['工作', '紧急'];
      final task = Task(title: '测试', tags: original);

      original.add('新增');

      expect(task.tags.length, 2);
      expect(task.tags.contains('新增'), false);
    });

    test('copyWith 应保留标签', () {
      final task = Task(title: '测试', tags: const ['标签A', '标签B']);
      final copied = task.copyWith(title: '测试2');

      expect(copied.tags, ['标签A', '标签B']);
    });

    test('copyWith 可替换标签', () {
      final task = Task(title: '测试', tags: const ['老标签']);
      final copied = task.copyWith(tags: ['新标签1', '新标签2']);

      expect(copied.tags, ['新标签1', '新标签2']);
    });

    test('空标签默认为空列表', () {
      final task = Task(title: '测试');
      expect(task.tags, isEmpty);
    });
  });

  group('TaskFilter 标签筛选测试', () {
    test('selectedTag 为 null 时未筛选', () {
      final filter = TaskFilter();
      expect(filter.selectedTag, isNull);
      expect(filter.isEmpty, true);
    });

    test('设置 selectedTag 后非空', () {
      final filter = TaskFilter(selectedTag: '工作');
      expect(filter.selectedTag, '工作');
      expect(filter.isEmpty, false);
    });

    test('copyWith 可更新标签筛选', () {
      final filter = TaskFilter(selectedTag: '旧标签');
      final updated = filter.copyWith(selectedTag: '新标签');
      expect(updated.selectedTag, '新标签');
    });

    test('标签筛选匹配逻辑', () {
      final task1 = Task(title: 'A', tags: const ['工作', '紧急']);
      final task2 = Task(title: 'B', tags: const ['个人']);
      final task3 = Task(title: 'C', tags: const []);

      // 模拟 filteredTasksProvider 中的筛选逻辑
      bool matchTag(Task t, String? selectedTag) =>
          selectedTag == null || t.tags.contains(selectedTag);

      expect(matchTag(task1, '工作'), true);
      expect(matchTag(task2, '工作'), false);
      expect(matchTag(task3, '工作'), false);
      expect(matchTag(task1, null), true);
    });
  });
}
