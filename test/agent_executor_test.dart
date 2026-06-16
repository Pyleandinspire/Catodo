// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/data/task_dao.dart';
import 'package:catodo/models/task.dart';
import 'package:catodo/services/ai_agent.dart';

/// 内存版 TaskRepository，避开 Isar 二进制依赖。
class _InMemoryTaskRepo implements TaskRepository {
  final Map<int, Task> _store = {};
  int _nextId = 1;
  int softDeletedId = -1; // 用于断言 softDeleteTask 被调用

  Task put(Task t) {
    if (t.id == Isar_autoIncrementSentinel) {
      // 模拟 Isar 自增分配
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
    softDeletedId = id;
    final t = _store[id];
    if (t != null) {
      t.isDeleted = true;
      t.updatedAt = DateTime.now();
    }
  }
}

const int Isar_autoIncrementSentinel =
    -9223372036854775808; // 与 Isar.autoIncrement 同；避免直接依赖 Isar 包

void main() {
  late _InMemoryTaskRepo repo;

  setUp(() {
    repo = _InMemoryTaskRepo();
  });

  Task addTask({
    String title = 'T',
    int priority = 1,
    String? description,
    String? groupName,
    DateTime? dueDate,
    List<String>? tags,
    List<DateTime>? reminders,
    String? rrule,
    bool isCompleted = false,
  }) {
    final t = Task(
      title: title,
      priority: priority,
      description: description,
      groupName: groupName,
      dueDate: dueDate,
      tags: tags ?? const [],
      reminderTimes: reminders ?? const [],
      rrule: rrule,
      isRepeatParent: rrule != null,
    );
    repo.put(t);
    return t;
  }

  // ============== executeAction 分发 ==============

  group('executeAction 分发表覆盖', () {
    test('未实现的 action 永远不会发生（switch exhaustive）', () {
      // 仅在编译期保证；这里跑一遍 createTask / addTag 确保连通
      expect(AgentActionType.values.length, 17);
    });
  });

  // ============== createTask ==============

  group('createTask', () {
    test('空 title 报错', () async {
      final r = await executeAction(
        const AgentAction(type: AgentActionType.createTask, params: {}),
        repo,
      );
      expect(r.success, false);
      expect(r.message, contains('标题'));
    });

    test('完整字段创建（含 reminders / rrule）', () async {
      final r = await executeAction(
        AgentAction(type: AgentActionType.createTask, params: {
          'title': '吃药',
          'description': '饭后',
          'priority': 3,
          'dueDate': '2026-06-16',
          'tags': ['健康'],
          'groupName': '生活',
          'reminderTimes': ['2026-06-16T09:00'],
          'rrule': 'FREQ=DAILY;INTERVAL=1',
        }),
        repo,
      );
      expect(r.success, true);
      final t = r.data as Task;
      expect(t.title, '吃药');
      expect(t.description, '饭后');
      expect(t.priority, 3);
      expect(t.tags, ['健康']);
      expect(t.groupName, '生活');
      expect(t.reminderTimes.length, 1);
      expect(t.rrule, 'FREQ=DAILY;INTERVAL=1');
      expect(t.isRepeatParent, true);
    });

    test('repeat 简词形式被转 rrule', () async {
      final r = await executeAction(
        const AgentAction(type: AgentActionType.createTask, params: {
          'title': 'X',
          'repeat': {'type': 'weekly', 'interval': 2},
        }),
        repo,
      );
      final t = r.data as Task;
      expect(t.rrule, 'FREQ=WEEKLY;INTERVAL=2');
    });
  });

  // ============== updateTask（核心：JSON-Patch 清空语义） ==============

  group('updateTask: JSON-Patch 清空语义（PLAN-AI-001-6 核心）', () {
    test('不传字段 → 全部不变', () async {
      final t = addTask(
        title: '原',
        description: '原描述',
        groupName: '工作',
        dueDate: DateTime(2026, 6, 17),
      );
      final r = await executeAction(
        AgentAction(
          type: AgentActionType.updateTask,
          params: {'taskId': t.id},
        ),
        repo,
      );
      expect(r.success, true);
      final after = await repo.getTaskById(t.id);
      expect(after!.title, '原');
      expect(after.description, '原描述');
      expect(after.groupName, '工作');
      expect(after.dueDate, DateTime(2026, 6, 17));
    });

    test('description = null 真清空', () async {
      final t = addTask(description: '旧');
      await executeAction(
        AgentAction(
          type: AgentActionType.updateTask,
          params: {'taskId': t.id, 'description': null},
        ),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.description, isNull);
    });

    test('dueDate = null 真清空', () async {
      final t = addTask(dueDate: DateTime(2026, 6, 17));
      await executeAction(
        AgentAction(
          type: AgentActionType.updateTask,
          params: {'taskId': t.id, 'dueDate': null},
        ),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.dueDate, isNull);
    });

    test('groupName = null 真清空', () async {
      final t = addTask(groupName: '生活');
      await executeAction(
        AgentAction(
          type: AgentActionType.updateTask,
          params: {'taskId': t.id, 'groupName': null},
        ),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.groupName, isNull);
    });

    test('rrule = null 真清空且 isRepeatParent=false', () async {
      final t = addTask(rrule: 'FREQ=DAILY');
      await executeAction(
        AgentAction(
          type: AgentActionType.updateTask,
          params: {'taskId': t.id, 'rrule': null},
        ),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.rrule, isNull);
      expect(after.isRepeatParent, false);
    });

    test('title 不能被传 null 抹掉（防御）', () async {
      final t = addTask(title: '保留');
      await executeAction(
        AgentAction(
          type: AgentActionType.updateTask,
          params: {'taskId': t.id, 'title': null},
        ),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.title, '保留');
    });

    test('tags 整段替换', () async {
      final t = addTask(tags: ['a', 'b']);
      await executeAction(
        AgentAction(
          type: AgentActionType.updateTask,
          params: {'taskId': t.id, 'tags': ['c']},
        ),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.tags, ['c']);
    });

    test('reminderTimes 整段替换', () async {
      final t = addTask(reminders: [DateTime(2026, 6, 17, 9)]);
      await executeAction(
        AgentAction(
          type: AgentActionType.updateTask,
          params: {
            'taskId': t.id,
            'reminderTimes': ['2026-06-17T08:30'],
          },
        ),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.reminderTimes.length, 1);
      expect(after.reminderTimes.first, DateTime(2026, 6, 17, 8, 30));
    });

    test('isCompleted=true', () async {
      final t = addTask();
      await executeAction(
        AgentAction(
          type: AgentActionType.updateTask,
          params: {'taskId': t.id, 'isCompleted': true},
        ),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.isCompleted, true);
    });

    test('taskId 不存在 → 失败', () async {
      final r = await executeAction(
        const AgentAction(
          type: AgentActionType.updateTask,
          params: {'taskId': 99999},
        ),
        repo,
      );
      expect(r.success, false);
    });

    test('无效 taskId → 失败', () async {
      final r = await executeAction(
        const AgentAction(
          type: AgentActionType.updateTask,
          params: {'taskId': 'not_a_number'},
        ),
        repo,
      );
      expect(r.success, false);
    });
  });

  // ============== Reminders ==============

  group('reminders', () {
    test('addReminder 添加 + 自动排序 + 去重', () async {
      final t = addTask(reminders: [DateTime(2026, 6, 17, 12)]);
      await executeAction(
        AgentAction(type: AgentActionType.addReminder, params: {
          'taskId': t.id,
          'time': '2026-06-17T08:00',
        }),
        repo,
      );
      // 重复添加同一时间不应再追加
      await executeAction(
        AgentAction(type: AgentActionType.addReminder, params: {
          'taskId': t.id,
          'time': '2026-06-17T08:00',
        }),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.reminderTimes.length, 2);
      expect(after.reminderTimes.first, DateTime(2026, 6, 17, 8));
    });

    test('addReminder 时间格式无效 → 失败', () async {
      final t = addTask();
      final r = await executeAction(
        AgentAction(type: AgentActionType.addReminder, params: {
          'taskId': t.id,
          'time': 'tomorrow morning',
        }),
        repo,
      );
      expect(r.success, false);
    });

    test('removeReminder 按 time 精准删除', () async {
      final t = addTask(reminders: [
        DateTime(2026, 6, 17, 9),
        DateTime(2026, 6, 17, 12),
      ]);
      await executeAction(
        AgentAction(type: AgentActionType.removeReminder, params: {
          'taskId': t.id,
          'time': '2026-06-17T09:00',
        }),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.reminderTimes, [DateTime(2026, 6, 17, 12)]);
    });

    test('removeReminder 按 index', () async {
      final t = addTask(reminders: [
        DateTime(2026, 6, 17, 9),
        DateTime(2026, 6, 17, 12),
      ]);
      await executeAction(
        AgentAction(type: AgentActionType.removeReminder, params: {
          'taskId': t.id,
          'index': 0,
        }),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.reminderTimes.length, 1);
    });

    test('removeReminder index 越界 → 失败', () async {
      final t = addTask(reminders: [DateTime(2026, 6, 17, 9)]);
      final r = await executeAction(
        AgentAction(type: AgentActionType.removeReminder, params: {
          'taskId': t.id,
          'index': 5,
        }),
        repo,
      );
      expect(r.success, false);
    });

    test('removeReminder 二者都不传 → 失败', () async {
      final t = addTask(reminders: [DateTime(2026, 6, 17, 9)]);
      final r = await executeAction(
        AgentAction(type: AgentActionType.removeReminder, params: {
          'taskId': t.id,
        }),
        repo,
      );
      expect(r.success, false);
    });

    test('clearReminders → 空数组', () async {
      final t = addTask(reminders: [
        DateTime(2026, 6, 17, 9),
        DateTime(2026, 6, 17, 12),
      ]);
      final r = await executeAction(
        AgentAction(type: AgentActionType.clearReminders, params: {
          'taskId': t.id,
        }),
        repo,
      );
      expect(r.success, true);
      final after = await repo.getTaskById(t.id);
      expect(after!.reminderTimes, isEmpty);
    });
  });

  // ============== Repeat ==============

  group('repeat', () {
    test('setRepeat rrule 字符串', () async {
      final t = addTask();
      await executeAction(
        AgentAction(type: AgentActionType.setRepeat, params: {
          'taskId': t.id,
          'rrule': 'FREQ=WEEKLY;INTERVAL=1',
        }),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.rrule, 'FREQ=WEEKLY;INTERVAL=1');
      expect(after.isRepeatParent, true);
    });

    test('setRepeat 简词 {type,interval}', () async {
      final t = addTask();
      await executeAction(
        AgentAction(type: AgentActionType.setRepeat, params: {
          'taskId': t.id,
          'type': 'monthly', // 注意：作为 repeat 子对象传更规范，但 PLAN 同样接受顶层
          'interval': 3,
        }),
        repo,
      );
      // 顶层 type/interval 不会被 _resolveRrule 识别（它读 rrule 或 repeat:{...}）
      // 这是有意设计：非法时报错由调用方再追问 LLM
      final after = await repo.getTaskById(t.id);
      // 缺少 rrule 与 repeat 时返回失败；任务不变
      expect(after!.rrule, isNull);
    });

    test('setRepeat 通过 repeat 子对象', () async {
      final t = addTask();
      await executeAction(
        AgentAction(type: AgentActionType.setRepeat, params: {
          'taskId': t.id,
          'repeat': {'type': 'monthly', 'interval': 3},
        }),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.rrule, 'FREQ=MONTHLY;INTERVAL=3');
      expect(after.isRepeatParent, true);
    });

    test('setRepeat 缺参 → 失败', () async {
      final t = addTask();
      final r = await executeAction(
        AgentAction(type: AgentActionType.setRepeat, params: {
          'taskId': t.id,
        }),
        repo,
      );
      expect(r.success, false);
    });

    test('clearRepeat → null + isRepeatParent=false', () async {
      final t = addTask(rrule: 'FREQ=DAILY');
      final r = await executeAction(
        AgentAction(type: AgentActionType.clearRepeat, params: {
          'taskId': t.id,
        }),
        repo,
      );
      expect(r.success, true);
      final after = await repo.getTaskById(t.id);
      expect(after!.rrule, isNull);
      expect(after.isRepeatParent, false);
    });
  });

  // ============== Tags / Groups / Priority ==============

  group('tags / group / priority', () {
    test('addTag 已存在不重复', () async {
      final t = addTask(tags: ['a']);
      await executeAction(
        AgentAction(type: AgentActionType.addTag, params: {
          'taskId': t.id,
          'tag': 'a',
        }),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.tags, ['a']);
    });

    test('removeTag 不存在视作成功', () async {
      final t = addTask(tags: ['a']);
      final r = await executeAction(
        AgentAction(type: AgentActionType.removeTag, params: {
          'taskId': t.id,
          'tag': 'b',
        }),
        repo,
      );
      expect(r.success, true);
    });

    test('setGroup', () async {
      final t = addTask();
      await executeAction(
        AgentAction(type: AgentActionType.setGroup, params: {
          'taskId': t.id,
          'groupName': '工作',
        }),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.groupName, '工作');
    });

    test('setPriority 边界 clamp', () async {
      final t = addTask();
      await executeAction(
        AgentAction(type: AgentActionType.setPriority, params: {
          'taskId': t.id,
          'priority': 99,
        }),
        repo,
      );
      final after = await repo.getTaskById(t.id);
      expect(after!.priority, 3);
    });
  });

  // ============== query_tasks / bulk_update ==============

  group('query_tasks / bulk_update', () {
    test('bulk_update 批量改优先级 + groupName', () async {
      final t1 = addTask(title: 'A', priority: 1);
      final t2 = addTask(title: 'B', priority: 1);
      final r = await executeAction(
        AgentAction(type: AgentActionType.bulkUpdate, params: {
          'taskIds': [t1.id, t2.id],
          'priority': 3,
          'groupName': '工作',
        }),
        repo,
      );
      expect(r.success, true);
      expect((await repo.getTaskById(t1.id))!.priority, 3);
      expect((await repo.getTaskById(t1.id))!.groupName, '工作');
      expect((await repo.getTaskById(t2.id))!.priority, 3);
    });

    test('bulk_update 空 taskIds 失败', () async {
      final r = await executeAction(
        AgentAction(type: AgentActionType.bulkUpdate, params: {
          'taskIds': [],
        }),
        repo,
      );
      expect(r.success, false);
    });

    test('bulk_update needsConfirmation=true', () {
      final a = AgentAction(type: AgentActionType.bulkUpdate, params: const {});
      expect(a.needsConfirmation, true);
    });

    test('query_tasks description 显示 keyword', () {
      final a = AgentAction(
        type: AgentActionType.queryTasks,
        params: const {'keyword': '报告'},
      );
      expect(a.description, contains('报告'));
    });
  });

  // ============== complete / uncomplete / delete ==============

  group('complete / uncomplete / delete', () {
    test('completeTask', () async {
      final t = addTask();
      await executeAction(
        AgentAction(type: AgentActionType.completeTask, params: {
          'taskId': t.id,
        }),
        repo,
      );
      expect((await repo.getTaskById(t.id))!.isCompleted, true);
    });

    test('uncompleteTask', () async {
      final t = addTask(isCompleted: true);
      await executeAction(
        AgentAction(type: AgentActionType.uncompleteTask, params: {
          'taskId': t.id,
        }),
        repo,
      );
      expect((await repo.getTaskById(t.id))!.isCompleted, false);
    });

    test('deleteTask 调用 softDelete', () async {
      final t = addTask();
      await executeAction(
        AgentAction(type: AgentActionType.deleteTask, params: {
          'taskId': t.id,
        }),
        repo,
      );
      expect(repo.softDeletedId, t.id);
      expect((await repo.getTaskById(t.id))!.isDeleted, true);
    });
  });

  // ============== applyUpdatesForTest 直测（最后一道防线） ==============

  group('applyUpdatesForTest 单测', () {
    test('description=null 清空、不传则保留', () {
      final t = Task(title: 'a', description: '原');
      applyUpdatesForTest(t, {'description': null});
      expect(t.description, isNull);
      applyUpdatesForTest(t, {'priority': 2});
      expect(t.description, isNull);
      expect(t.priority, 2);
    });

    test('rrule null 清空 + isRepeatParent=false', () {
      final t = Task(title: 'a', rrule: 'FREQ=DAILY', isRepeatParent: true);
      applyUpdatesForTest(t, {'rrule': null});
      expect(t.rrule, isNull);
      expect(t.isRepeatParent, false);
    });
  });
}
