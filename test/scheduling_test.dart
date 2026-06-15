import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/data/task_dao.dart';
import 'package:catodo/models/task.dart';
import 'package:catodo/services/ai_agent.dart';

/// 内存版 TaskRepository，避开 Isar 二进制依赖。
/// 与 agent_executor_test 保持同样接口，避免重复依赖。
class _InMemoryTaskRepo implements TaskRepository {
  final Map<int, Task> _store = {};
  int _nextId = 1;

  Task put(Task t) {
    if (t.id <= 0 || t.id == _autoIncSentinel) {
      t.id = _nextId++;
    }
    _store[t.id] = t;
    return t;
  }

  @override
  Future<Task?> getTaskById(int id) async => _store[id];

  @override
  Future<Task> insertTask(Task task) async {
    task.createdAt = DateTime.now();
    task.updatedAt = DateTime.now();
    task.isDeleted = false;
    task.id = _nextId++;
    _store[task.id] = task;
    return task;
  }

  @override
  Future<Task> updateTask(Task task) async {
    task.updatedAt = DateTime.now();
    _store[task.id] = task;
    return task;
  }

  @override
  Future<void> softDeleteTask(int id) async {
    final t = _store[id];
    if (t != null) {
      t.isDeleted = true;
      t.updatedAt = DateTime.now();
    }
  }

  static const int _autoIncSentinel = -9223372036854775808;
}

void main() {
  // ============== SchedulingPlan.fromJson ==============

  group('SchedulingPlan.fromJson', () {
    test('完整 JSON 解析', () {
      final plan = SchedulingPlan.fromJson({
        'summary': '本周紧张',
        'issues': [
          {
            'type': 'overload',
            'date': '2026-06-17',
            'taskIds': [12, 14, 23],
            'note': '同一天 3 个高优先级',
          }
        ],
        'suggestions': [
          {
            'id': 's1',
            'type': 'reschedule',
            'taskId': 14,
            'newDueDate': '2026-06-19T09:00',
            'reason': '分散负载',
          },
          {
            'id': 's2',
            'type': 'decompose',
            'taskId': 41,
            'subtasks': [
              {'title': '收集数据', 'priority': 2},
              {'title': '撰写初稿', 'priority': 3},
            ],
            'reason': '拆成 2 步',
          },
          {
            'id': 's3',
            'type': 'set_priority',
            'taskId': 7,
            'priority': 1,
            'reason': '降优先级',
          },
          {
            'id': 's4',
            'type': 'add_reminder',
            'taskId': 5,
            'reminderTimes': ['2026-06-15T08:30'],
            'reason': '会前 30 分钟',
          },
          {
            'id': 's5',
            'type': 'complete_or_drop',
            'taskId': 9,
            'reason': '已逾期 5 天',
          },
        ],
      });
      expect(plan.summary, '本周紧张');
      expect(plan.issues.length, 1);
      expect(plan.issues.first.taskIds, [12, 14, 23]);
      expect(plan.suggestions.length, 5);

      final s1 = plan.suggestions[0];
      expect(s1.type, SchedulingSuggestionType.reschedule);
      expect(s1.taskId, 14);
      expect(s1.newDueDate, DateTime(2026, 6, 19, 9));

      final s2 = plan.suggestions[1];
      expect(s2.type, SchedulingSuggestionType.decompose);
      expect(s2.subtasks!.length, 2);

      final s3 = plan.suggestions[2];
      expect(s3.type, SchedulingSuggestionType.setPriority);
      expect(s3.priority, 1);

      final s4 = plan.suggestions[3];
      expect(s4.type, SchedulingSuggestionType.addReminder);
      expect(s4.reminderTimes!.first, DateTime(2026, 6, 15, 8, 30));

      expect(plan.warnings, isEmpty);
    });

    test('未知 suggestion 类型进 warnings', () {
      final plan = SchedulingPlan.fromJson({
        'summary': '',
        'suggestions': [
          {'id': 'x', 'type': 'fancy_unknown', 'reason': 'r'},
          {
            'id': 's1',
            'type': 'reschedule',
            'taskId': 1,
            'newDueDate': '2026-06-15',
            'reason': 'r',
          },
        ],
      });
      expect(plan.suggestions.length, 1);
      expect(plan.warnings, ['fancy_unknown']);
    });

    test('空对象返回空 plan', () {
      final plan = SchedulingPlan.fromJson({});
      expect(plan.summary, '');
      expect(plan.issues, isEmpty);
      expect(plan.suggestions, isEmpty);
    });

    test('SchedulingSuggestion.title 文本合理', () {
      final s = SchedulingSuggestion.tryFromJson({
        'id': 's1',
        'type': 'reschedule',
        'taskId': 14,
        'newDueDate': '2026-06-19',
        'reason': 'r',
      })!;
      expect(s.title, contains('[14]'));
      expect(s.title, contains('2026-06-19'));
    });
  });

  // ============== applySchedulingSuggestion ==============

  group('applySchedulingSuggestion', () {
    late _InMemoryTaskRepo repo;
    late Task base;

    setUp(() {
      repo = _InMemoryTaskRepo();
      base = repo.put(Task(
        title: '原任务',
        priority: 1,
        groupName: '工作',
        tags: const ['项目A'],
      ));
    });

    test('reschedule 改 dueDate', () async {
      final s = SchedulingSuggestion(
        id: 's1',
        type: SchedulingSuggestionType.reschedule,
        taskId: base.id,
        newDueDate: DateTime(2026, 6, 19, 9),
        reason: 'r',
      );
      final r = await applySchedulingSuggestion(s, repo);
      expect(r.success, true);
      final after = await repo.getTaskById(base.id);
      expect(after!.dueDate, DateTime(2026, 6, 19, 9));
    });

    test('reschedule 缺 newDueDate → 失败', () async {
      final s = SchedulingSuggestion(
        id: 's1',
        type: SchedulingSuggestionType.reschedule,
        taskId: base.id,
        reason: 'r',
      );
      final r = await applySchedulingSuggestion(s, repo);
      expect(r.success, false);
    });

    test('setPriority clamp 边界', () async {
      final s = SchedulingSuggestion(
        id: 's2',
        type: SchedulingSuggestionType.setPriority,
        taskId: base.id,
        priority: 5,
        reason: 'r',
      );
      final r = await applySchedulingSuggestion(s, repo);
      expect(r.success, true);
      final after = await repo.getTaskById(base.id);
      expect(after!.priority, 3);
    });

    test('decompose 创建子任务并继承 group/tags', () async {
      final s = SchedulingSuggestion(
        id: 's3',
        type: SchedulingSuggestionType.decompose,
        taskId: base.id,
        subtasks: const [
          {'title': 'A', 'priority': 2},
          {'title': 'B'},
        ],
        reason: 'r',
      );
      final r = await applySchedulingSuggestion(s, repo);
      expect(r.success, true);
      // 母任务保留；新增 2 个子任务
      expect(repo._store.length, 3);
      final children = repo._store.values.where((t) => t.id != base.id).toList();
      for (final c in children) {
        expect(c.groupName, '工作');
        expect(c.tags, ['项目A']);
      }
    });

    test('decompose 子任务为空 → 失败', () async {
      final s = SchedulingSuggestion(
        id: 's3',
        type: SchedulingSuggestionType.decompose,
        taskId: base.id,
        subtasks: const [],
        reason: 'r',
      );
      final r = await applySchedulingSuggestion(s, repo);
      expect(r.success, false);
    });

    test('addReminder 合并去重 + 排序', () async {
      // 已有一个 12:00 的提醒
      base.reminderTimes = [DateTime(2026, 6, 17, 12)];
      final s = SchedulingSuggestion(
        id: 's4',
        type: SchedulingSuggestionType.addReminder,
        taskId: base.id,
        reminderTimes: [
          DateTime(2026, 6, 17, 9),
          DateTime(2026, 6, 17, 12), // 重复，应去重
        ],
        reason: 'r',
      );
      final r = await applySchedulingSuggestion(s, repo);
      expect(r.success, true);
      final after = await repo.getTaskById(base.id);
      expect(after!.reminderTimes.length, 2);
      expect(after.reminderTimes.first, DateTime(2026, 6, 17, 9));
    });

    test('addReminder 缺 reminderTimes → 失败', () async {
      final s = SchedulingSuggestion(
        id: 's4',
        type: SchedulingSuggestionType.addReminder,
        taskId: base.id,
        reason: 'r',
      );
      final r = await applySchedulingSuggestion(s, repo);
      expect(r.success, false);
    });

    test('completeOrDrop → 显式不在此处自动执行', () async {
      final s = SchedulingSuggestion(
        id: 's5',
        type: SchedulingSuggestionType.completeOrDrop,
        taskId: base.id,
        reason: 'r',
      );
      final r = await applySchedulingSuggestion(s, repo);
      expect(r.success, false);
      expect(r.message, contains('UI 二次确认'));
    });

    test('taskId 不存在 → 失败', () async {
      final s = SchedulingSuggestion(
        id: 's6',
        type: SchedulingSuggestionType.setPriority,
        taskId: 99999,
        priority: 2,
        reason: 'r',
      );
      final r = await applySchedulingSuggestion(s, repo);
      expect(r.success, false);
    });
  });

  // ============== kSchedulingSystemPrompt ==============

  group('kSchedulingSystemPrompt', () {
    test('包含必备字段名', () {
      expect(kSchedulingSystemPrompt, contains('summary'));
      expect(kSchedulingSystemPrompt, contains('issues'));
      expect(kSchedulingSystemPrompt, contains('suggestions'));
      expect(kSchedulingSystemPrompt, contains('reschedule'));
      expect(kSchedulingSystemPrompt, contains('decompose'));
      expect(kSchedulingSystemPrompt, contains('set_priority'));
      expect(kSchedulingSystemPrompt, contains('complete_or_drop'));
      expect(kSchedulingSystemPrompt, contains('add_reminder'));
    });
  });
}
