import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../data/task_dao.dart';
import 'notification_service.dart';

// ==================== Action 定义 ====================

/// Agent 操作类型
enum AgentActionType {
  createTask('create_task'),
  updateTask('update_task'),
  completeTask('complete_task'),
  uncompleteTask('uncomplete_task'),
  deleteTask('delete_task'),
  decomposeTask('decompose_task'),
  addTag('add_tag'),
  removeTag('remove_tag'),
  setGroup('set_group'),
  setPriority('set_priority'),
  addReminder('add_reminder'),
  removeReminder('remove_reminder'),
  clearReminders('clear_reminders'),
  setRepeat('set_repeat'),
  clearRepeat('clear_repeat');

  final String value;
  const AgentActionType(this.value);

  /// 解析字符串到枚举；未知值返回 null（由调用方决定如何降级，避免误回退到 createTask）。
  static AgentActionType? fromString(String value) {
    for (final t in AgentActionType.values) {
      if (t.value == value) return t;
    }
    return null;
  }
}

/// 单个 Agent 操作
class AgentAction {
  final AgentActionType type;
  final Map<String, dynamic> params;

  const AgentAction({required this.type, required this.params});

  /// 从 JSON 解析 AgentAction；类型未知时返回 null，由 [AgentResponse.fromJson] 收集到 warnings 中。
  static AgentAction? tryFromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? '';
    final t = AgentActionType.fromString(typeStr);
    if (t == null) return null;
    final params = json['params'] as Map<String, dynamic>? ?? {};
    return AgentAction(
      type: t,
      params: Map<String, dynamic>.from(params),
    );
  }

  /// 兼容历史调用：未知 type 退化为 [AgentActionType.createTask]，仅供测试/旧代码使用。
  ///
  /// 推荐使用 [tryFromJson]，会把未知动作过滤到 [AgentResponse.warnings]。
  factory AgentAction.fromJson(Map<String, dynamic> json) {
    final maybe = tryFromJson(json);
    if (maybe != null) return maybe;
    final params = json['params'] as Map<String, dynamic>? ?? {};
    return AgentAction(
      type: AgentActionType.createTask,
      params: Map<String, dynamic>.from(params),
    );
  }

  /// 是否需要用户确认后才执行
  bool get needsConfirmation {
    switch (type) {
      case AgentActionType.deleteTask:
      case AgentActionType.completeTask:
      case AgentActionType.uncompleteTask:
      case AgentActionType.updateTask:
      case AgentActionType.addReminder:
      case AgentActionType.removeReminder:
      case AgentActionType.clearReminders:
      case AgentActionType.setRepeat:
      case AgentActionType.clearRepeat:
        return true;
      default:
        return false;
    }
  }

  /// 操作的简短描述（用于确认 UI）
  String get description {
    switch (type) {
      case AgentActionType.createTask:
        return '创建任务「${params['title'] ?? ''}」';
      case AgentActionType.updateTask:
        return '更新任务 [${params['taskId']}]';
      case AgentActionType.completeTask:
        return '完成任务 [${params['taskId']}]';
      case AgentActionType.uncompleteTask:
        return '撤销完成任务 [${params['taskId']}]';
      case AgentActionType.deleteTask:
        return '删除任务 [${params['taskId']}]';
      case AgentActionType.decomposeTask:
        return '分解任务 [${params['taskId']}]';
      case AgentActionType.addTag:
        return '给任务 [${params['taskId']}] 添加标签「${params['tag']}」';
      case AgentActionType.removeTag:
        return '移除任务 [${params['taskId']}] 的标签「${params['tag']}」';
      case AgentActionType.setGroup:
        return '设置任务 [${params['taskId']}] 的分组为「${params['groupName']}」';
      case AgentActionType.setPriority:
        final p = params['priority'];
        final label = p == 3
            ? '高'
            : p == 2
            ? '中'
            : '低';
        return '设置任务 [${params['taskId']}] 优先级为$label';
      case AgentActionType.addReminder:
        return '给任务 [${params['taskId']}] 添加提醒：${params['time'] ?? ''}';
      case AgentActionType.removeReminder:
        final t = params['time'];
        if (t != null) return '移除任务 [${params['taskId']}] 的提醒：$t';
        return '移除任务 [${params['taskId']}] 的第 ${params['index']} 个提醒';
      case AgentActionType.clearReminders:
        return '清空任务 [${params['taskId']}] 的所有提醒';
      case AgentActionType.setRepeat:
        if (params['rrule'] is String) {
          return '设置任务 [${params['taskId']}] 重复规则：${params['rrule']}';
        }
        final ty = params['type'];
        final iv = params['interval'] ?? 1;
        return '设置任务 [${params['taskId']}] 为每 $iv $ty 重复';
      case AgentActionType.clearRepeat:
        return '取消任务 [${params['taskId']}] 的重复';
    }
  }
}

/// Agent 响应
class AgentResponse {
  final String reply;
  final List<AgentAction> actions;

  /// 解析时跳过的未知 action 类型字符串（用于 UI 提示用户哪些动作被忽略）。
  final List<String> warnings;

  const AgentResponse({
    required this.reply,
    this.actions = const [],
    this.warnings = const [],
  });

  factory AgentResponse.fromJson(Map<String, dynamic> json) {
    final reply = json['reply']?.toString() ?? '';
    final actionsList = json['actions'] as List<dynamic>? ?? [];
    final actions = <AgentAction>[];
    final warnings = <String>[];
    for (final a in actionsList) {
      if (a is! Map<String, dynamic>) continue;
      final parsed = AgentAction.tryFromJson(a);
      if (parsed != null) {
        actions.add(parsed);
      } else {
        final t = a['type'];
        if (t is String && t.isNotEmpty) warnings.add(t);
      }
    }
    return AgentResponse(reply: reply, actions: actions, warnings: warnings);
  }
}

/// Action 执行结果
class ActionResult {
  final bool success;
  final String message;
  final dynamic data;

  const ActionResult({required this.success, required this.message, this.data});
}

// ==================== 上下文构建器 ====================

/// 每段上限。设置为顶层常量便于测试与未来调参。
const int _kCtxLimitTodayOverdue = 20;
const int _kCtxLimitThisWeek = 15;
const int _kCtxLimitHighPriority = 10;
const int _kCtxLimitOthers = 15;
const int _kCtxTitleMaxLen = 50;

/// 构建任务上下文，注入到 LLM 请求中。
///
/// 输出按相关性分段（任务概览 / 今日逾期 / 本周内截止 / 高优先级 / 其他活跃），
/// 每段独立上限，避免任务多于 50 时后段任务被全部丢弃。
///
/// [now] 用于划分"今天"和"本周"的时间锚点；未传时取 [DateTime.now]。
/// 测试时可注入固定值以避免日期依赖。
String buildTaskContext(List<Task> tasks, {DateTime? now}) {
  if (tasks.isEmpty) {
    return '【当前任务上下文】\n当前没有活跃任务。';
  }

  final anchor = now ?? DateTime.now();
  final todayStart = DateTime(anchor.year, anchor.month, anchor.day);
  final todayEnd = todayStart.add(const Duration(days: 1));
  final weekEnd = todayStart.add(const Duration(days: 7));

  final todayOrOverdue = <Task>[];
  final thisWeek = <Task>[];
  final highPriRest = <Task>[];
  final others = <Task>[];

  for (final t in tasks) {
    if (t.dueDate != null) {
      if (t.dueDate!.isBefore(todayEnd)) {
        todayOrOverdue.add(t);
        continue;
      }
      if (t.dueDate!.isBefore(weekEnd)) {
        thisWeek.add(t);
        continue;
      }
    }
    if (t.priority >= 2) {
      highPriRest.add(t);
    } else {
      others.add(t);
    }
  }

  todayOrOverdue.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  thisWeek.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  highPriRest.sort((a, b) {
    final p = b.priority.compareTo(a.priority);
    if (p != 0) return p;
    return b.updatedAt.compareTo(a.updatedAt);
  });
  others.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  // 收集所有分组和标签
  final groups = <String>{};
  final tagSet = <String>{};
  for (final task in tasks) {
    if (task.groupName != null && task.groupName!.isNotEmpty) {
      groups.add(task.groupName!);
    }
    for (final tag in task.tags) {
      if (tag.isNotEmpty) tagSet.add(tag);
    }
  }

  final highPriorityTotal = tasks.where((t) => t.priority >= 2).length;

  final buffer = StringBuffer('【任务概览】\n');
  buffer.writeln(
    '活跃任务共 ${tasks.length} 个；今日/逾期 ${todayOrOverdue.length}，'
    '本周内截止 ${thisWeek.length}，高优先级(≥2) $highPriorityTotal。',
  );
  if (groups.isNotEmpty) {
    final sortedGroups = groups.toList()..sort();
    buffer.writeln('可用分组: [${sortedGroups.join(', ')}]');
  }
  if (tagSet.isNotEmpty) {
    final sortedTags = tagSet.toList()..sort();
    buffer.writeln('可用标签: [${sortedTags.join(', ')}]');
  }

  void writeSection(
    String title,
    List<Task> all,
    int limit, {
    required bool short,
  }) {
    if (all.isEmpty) return;
    final shown = all.take(limit).toList();
    final headerCount = shown.length < all.length
        ? '前 ${shown.length}/${all.length}'
        : '共 ${all.length}';
    buffer.writeln();
    buffer.writeln('【$title】($headerCount)');
    for (final t in shown) {
      buffer.writeln(short ? _formatTaskShort(t) : _formatTaskFull(t));
    }
  }

  writeSection('今日 / 逾期', todayOrOverdue, _kCtxLimitTodayOverdue, short: false);
  writeSection('本周内截止', thisWeek, _kCtxLimitThisWeek, short: false);
  writeSection('高优先级 (≥2)', highPriRest, _kCtxLimitHighPriority, short: false);
  writeSection('其他活跃任务', others, _kCtxLimitOthers, short: true);

  return buffer.toString().trimRight();
}

String _formatTaskFull(Task task) {
  final priorityLabel = _priorityLabel(task.priority);
  final title = _truncateTitle(task.title);
  final groupStr = (task.groupName != null && task.groupName!.isNotEmpty)
      ? ' | 分组:${task.groupName}'
      : '';
  final tagsStr = task.tags.isNotEmpty
      ? ' | 标签:${task.tags.map((t) => '「$t」').join(',')}'
      : '';
  final dueStr = task.dueDate != null
      ? ' | 截止:${_fmtDate(task.dueDate!)}'
      : '';
  return '- [id:${task.id}] $title | 优先级:$priorityLabel$groupStr$tagsStr$dueStr';
}

String _formatTaskShort(Task task) {
  final priorityLabel = _priorityLabel(task.priority);
  final title = _truncateTitle(task.title);
  return '- [id:${task.id}] $title | 优先级:$priorityLabel';
}

String _priorityLabel(int p) {
  switch (p) {
    case 3:
      return '高';
    case 2:
      return '中';
    case 1:
      return '低';
    default:
      return '无';
  }
}

String _truncateTitle(String title) {
  if (title.length <= _kCtxTitleMaxLen) return title;
  return '${title.substring(0, _kCtxTitleMaxLen - 1)}…';
}

String _fmtDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}

// ==================== Action 执行器 ====================

/// 执行单个 Agent Action
Future<ActionResult> executeAction(AgentAction action, TaskRepository dao) async {
  try {
    switch (action.type) {
      case AgentActionType.createTask:
        return await _executeCreateTask(action, dao);

      case AgentActionType.updateTask:
        return await _executeUpdateTask(action, dao);

      case AgentActionType.completeTask:
        return await _executeCompleteTask(action, dao);

      case AgentActionType.uncompleteTask:
        return await _executeUncompleteTask(action, dao);

      case AgentActionType.deleteTask:
        return await _executeDeleteTask(action, dao);

      case AgentActionType.decomposeTask:
        return await _executeDecomposeTask(action, dao);

      case AgentActionType.addTag:
        return await _executeAddTag(action, dao);

      case AgentActionType.removeTag:
        return await _executeRemoveTag(action, dao);

      case AgentActionType.setGroup:
        return await _executeSetGroup(action, dao);

      case AgentActionType.setPriority:
        return await _executeSetPriority(action, dao);

      case AgentActionType.addReminder:
        return await _executeAddReminder(action, dao);

      case AgentActionType.removeReminder:
        return await _executeRemoveReminder(action, dao);

      case AgentActionType.clearReminders:
        return await _executeClearReminders(action, dao);

      case AgentActionType.setRepeat:
        return await _executeSetRepeat(action, dao);

      case AgentActionType.clearRepeat:
        return await _executeClearRepeat(action, dao);
    }
  } catch (e) {
    return ActionResult(success: false, message: '执行失败: $e');
  }
}

Future<ActionResult> _executeCreateTask(AgentAction action, TaskRepository dao) async {
  final title = action.params['title'] as String? ?? '';
  if (title.isEmpty) {
    return const ActionResult(success: false, message: '任务标题不能为空');
  }

  final reminderTimes = _parseDateList(action.params['reminderTimes']);
  final rrule = _resolveRrule(action.params);

  final task = Task(
    title: title,
    description: action.params['description'] as String?,
    priority: _parsePriority(action.params['priority']),
    dueDate: _parseDate(action.params['dueDate']),
    tags: _parseStringList(action.params['tags']),
    groupName: action.params['groupName'] as String?,
    reminderTimes: reminderTimes,
    rrule: rrule,
    isRepeatParent: rrule != null,
  );

  final created = await dao.insertTask(task);
  return ActionResult(
    success: true,
    message: '已创建任务「${created.title}」',
    data: created,
  );
}

Future<ActionResult> _executeUpdateTask(AgentAction action, TaskRepository dao) async {
  final taskId = _parseTaskId(action.params['taskId']);
  if (taskId == null) {
    return const ActionResult(success: false, message: '无效的任务 ID');
  }

  final existing = await dao.getTaskById(taskId);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 $taskId 不存在');
  }

  // JSON-Patch 风格：未传字段 → 不变；传 null → 显式清空（仅可空字段生效）。
  // 直接对实体改字段，避开 copyWith 的 `?? this.x` 语义。
  applyUpdatesForTest(existing, action.params);

  await dao.updateTask(existing);
  return ActionResult(
    success: true,
    message: '已更新任务「${existing.title}」',
    data: existing,
  );
}

/// 把 LLM 给的 params 应用到 [task] 上。
///
/// 可见字段语义：
/// - **未传字段** → 不变；
/// - **传字段** → 改为对应值；
/// - **传 null** → `description / dueDate / groupName` 清空；
///   `rrule` 设为 null + `isRepeatParent=false`；
///   其它必填字段忽略 null（防止 LLM 误传 null 把 title 抹空）。
///
/// `tags` / `reminderTimes` 整段替换；空数组等同清空。
@visibleForTesting
void applyUpdatesForTest(Task task, Map<String, dynamic> p) {
  if (p.containsKey('title')) {
    final v = p['title'];
    if (v is String && v.isNotEmpty) task.title = v;
  }
  if (p.containsKey('description')) {
    final v = p['description'];
    task.description = v is String ? v : null;
  }
  if (p.containsKey('priority')) {
    task.priority = _parsePriority(p['priority']);
  }
  if (p.containsKey('dueDate')) {
    task.dueDate = _parseDate(p['dueDate']);
  }
  if (p.containsKey('tags')) {
    task.tags = _parseStringList(p['tags']);
  }
  if (p.containsKey('groupName')) {
    final v = p['groupName'];
    task.groupName = v is String ? v : null;
  }
  if (p.containsKey('reminderTimes')) {
    task.reminderTimes = _parseDateList(p['reminderTimes']);
  }
  if (p.containsKey('rrule') || p.containsKey('repeat')) {
    final r = _resolveRrule(p);
    task.rrule = r;
    task.isRepeatParent = r != null;
  }
  if (p.containsKey('isCompleted')) {
    final v = p['isCompleted'];
    if (v is bool) task.isCompleted = v;
  }
  task.updatedAt = DateTime.now();
}

Future<ActionResult> _executeCompleteTask(
  AgentAction action,
  TaskRepository dao,
) async {
  final taskId = _parseTaskId(action.params['taskId']);
  if (taskId == null) {
    return const ActionResult(success: false, message: '无效的任务 ID');
  }

  final existing = await dao.getTaskById(taskId);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 $taskId 不存在');
  }

  final updated = existing.copyWith(isCompleted: true);
  await dao.updateTask(updated);
  return ActionResult(success: true, message: '已完成任务「${existing.title}」');
}

Future<ActionResult> _executeDeleteTask(AgentAction action, TaskRepository dao) async {
  final taskId = _parseTaskId(action.params['taskId']);
  if (taskId == null) {
    return const ActionResult(success: false, message: '无效的任务 ID');
  }

  final existing = await dao.getTaskById(taskId);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 $taskId 不存在');
  }

  // 删任务前先取消所有挂着的通知，避免删后通知残留
  try {
    await NotificationService().cancelTaskReminder(existing);
  } catch (e) {
    debugPrint('cancelTaskReminder before delete failed (ignored): $e');
  }

  await dao.softDeleteTask(taskId);
  return ActionResult(success: true, message: '已删除任务「${existing.title}」');
}

Future<ActionResult> _executeDecomposeTask(
  AgentAction action,
  TaskRepository dao,
) async {
  final taskId = _parseTaskId(action.params['taskId']);
  if (taskId == null) {
    return const ActionResult(success: false, message: '无效的任务 ID');
  }

  final existing = await dao.getTaskById(taskId);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 $taskId 不存在');
  }

  final subtasksRaw = action.params['subtasks'] as List<dynamic>? ?? [];
  if (subtasksRaw.isEmpty) {
    return const ActionResult(success: false, message: '子任务列表不能为空');
  }

  final createdTitles = <String>[];
  for (final st in subtasksRaw) {
    if (st is! Map<String, dynamic>) continue;
    final title = st['title'] as String? ?? '';
    if (title.isEmpty) continue;

    final task = Task(
      title: title,
      priority: _parsePriority(st['priority']),
      groupName: existing.groupName,
      tags: List<String>.from(existing.tags),
    );
    await dao.insertTask(task);
    createdTitles.add(title);
  }

  return ActionResult(
    success: true,
    message: '已将「${existing.title}」分解为 ${createdTitles.length} 个子任务',
    data: createdTitles,
  );
}

Future<ActionResult> _executeAddTag(AgentAction action, TaskRepository dao) async {
  final taskId = _parseTaskId(action.params['taskId']);
  final tag = action.params['tag'] as String? ?? '';
  if (taskId == null) {
    return const ActionResult(success: false, message: '无效的任务 ID');
  }
  if (tag.isEmpty) {
    return const ActionResult(success: false, message: '标签不能为空');
  }

  final existing = await dao.getTaskById(taskId);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 $taskId 不存在');
  }

  if (existing.tags.contains(tag)) {
    return ActionResult(
      success: true,
      message: '任务「${existing.title}」已有标签「$tag」',
    );
  }

  final updated = existing.copyWith(tags: [...existing.tags, tag]);
  await dao.updateTask(updated);
  return ActionResult(
    success: true,
    message: '已给任务「${existing.title}」添加标签「$tag」',
  );
}

Future<ActionResult> _executeRemoveTag(AgentAction action, TaskRepository dao) async {
  final taskId = _parseTaskId(action.params['taskId']);
  final tag = action.params['tag'] as String? ?? '';
  if (taskId == null) {
    return const ActionResult(success: false, message: '无效的任务 ID');
  }
  if (tag.isEmpty) {
    return const ActionResult(success: false, message: '标签不能为空');
  }

  final existing = await dao.getTaskById(taskId);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 $taskId 不存在');
  }

  final updated = existing.copyWith(
    tags: existing.tags.where((t) => t != tag).toList(),
  );
  await dao.updateTask(updated);
  return ActionResult(
    success: true,
    message: '已移除任务「${existing.title}」的标签「$tag」',
  );
}

Future<ActionResult> _executeSetGroup(AgentAction action, TaskRepository dao) async {
  final taskId = _parseTaskId(action.params['taskId']);
  final groupName = action.params['groupName'] as String?;
  if (taskId == null) {
    return const ActionResult(success: false, message: '无效的任务 ID');
  }

  final existing = await dao.getTaskById(taskId);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 $taskId 不存在');
  }

  final updated = existing.copyWith(groupName: groupName);
  await dao.updateTask(updated);
  return ActionResult(
    success: true,
    message: '已设置任务「${existing.title}」的分组为「${groupName ?? '无'}」',
  );
}

Future<ActionResult> _executeSetPriority(
  AgentAction action,
  TaskRepository dao,
) async {
  final taskId = _parseTaskId(action.params['taskId']);
  if (taskId == null) {
    return const ActionResult(success: false, message: '无效的任务 ID');
  }

  final existing = await dao.getTaskById(taskId);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 $taskId 不存在');
  }

  final priority = _parsePriority(action.params['priority']);
  final updated = existing.copyWith(priority: priority);
  await dao.updateTask(updated);

  final label = priority == 3
      ? '高'
      : priority == 2
      ? '中'
      : priority == 1
      ? '低'
      : '无';
  return ActionResult(
    success: true,
    message: '已设置任务「${existing.title}」优先级为$label',
  );
}

Future<ActionResult> _executeUncompleteTask(
  AgentAction action,
  TaskRepository dao,
) async {
  final taskId = _parseTaskId(action.params['taskId']);
  if (taskId == null) {
    return const ActionResult(success: false, message: '无效的任务 ID');
  }
  final existing = await dao.getTaskById(taskId);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 $taskId 不存在');
  }
  final updated = existing.copyWith(isCompleted: false);
  await dao.updateTask(updated);
  return ActionResult(success: true, message: '已撤销完成「${existing.title}」');
}

Future<ActionResult> _executeAddReminder(
  AgentAction action,
  TaskRepository dao,
) async {
  final taskId = _parseTaskId(action.params['taskId']);
  if (taskId == null) {
    return const ActionResult(success: false, message: '无效的任务 ID');
  }
  final time = _parseDate(action.params['time']);
  if (time == null) {
    return const ActionResult(success: false, message: '提醒时间格式无效（应为 YYYY-MM-DDTHH:mm）');
  }
  final existing = await dao.getTaskById(taskId);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 $taskId 不存在');
  }
  // 去重：同一时间点不重复添加
  final newTimes = List<DateTime>.from(existing.reminderTimes);
  if (!newTimes.any((t) => t.isAtSameMomentAs(time))) {
    newTimes.add(time);
    newTimes.sort((a, b) => a.compareTo(b));
  }
  final updated = existing.copyWith(reminderTimes: newTimes);
  await dao.updateTask(updated);
  return ActionResult(
    success: true,
    message: '已给「${existing.title}」添加提醒：${_fmtDateTime(time)}',
    data: updated,
  );
}

Future<ActionResult> _executeRemoveReminder(
  AgentAction action,
  TaskRepository dao,
) async {
  final taskId = _parseTaskId(action.params['taskId']);
  if (taskId == null) {
    return const ActionResult(success: false, message: '无效的任务 ID');
  }
  final existing = await dao.getTaskById(taskId);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 $taskId 不存在');
  }
  final List<DateTime> newTimes = List<DateTime>.from(existing.reminderTimes);

  final timeStr = action.params['time'];
  final indexParam = action.params['index'];
  if (timeStr != null) {
    final time = _parseDate(timeStr);
    if (time == null) {
      return const ActionResult(success: false, message: '提醒时间格式无效');
    }
    newTimes.removeWhere((t) => t.isAtSameMomentAs(time));
  } else if (indexParam is int) {
    if (indexParam < 0 || indexParam >= newTimes.length) {
      return const ActionResult(success: false, message: '提醒索引越界');
    }
    newTimes.removeAt(indexParam);
  } else {
    return const ActionResult(
      success: false,
      message: '需要提供 time 或 index 之一',
    );
  }
  final updated = existing.copyWith(reminderTimes: newTimes);
  await dao.updateTask(updated);
  return ActionResult(
    success: true,
    message: '已移除「${existing.title}」的一个提醒',
    data: updated,
  );
}

Future<ActionResult> _executeClearReminders(
  AgentAction action,
  TaskRepository dao,
) async {
  final taskId = _parseTaskId(action.params['taskId']);
  if (taskId == null) {
    return const ActionResult(success: false, message: '无效的任务 ID');
  }
  final existing = await dao.getTaskById(taskId);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 $taskId 不存在');
  }
  // 直接赋值：copyWith 用 ?? 语义无法把 List 替换为空（非 null）以外的清空。
  existing.reminderTimes = <DateTime>[];
  existing.updatedAt = DateTime.now();
  await dao.updateTask(existing);
  return ActionResult(
    success: true,
    message: '已清空「${existing.title}」的所有提醒',
    data: existing,
  );
}

Future<ActionResult> _executeSetRepeat(
  AgentAction action,
  TaskRepository dao,
) async {
  final taskId = _parseTaskId(action.params['taskId']);
  if (taskId == null) {
    return const ActionResult(success: false, message: '无效的任务 ID');
  }
  final existing = await dao.getTaskById(taskId);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 $taskId 不存在');
  }
  final rrule = _resolveRrule(action.params);
  if (rrule == null) {
    return const ActionResult(
      success: false,
      message: '需要提供 rrule 字符串或 {type, interval}',
    );
  }
  final updated = existing.copyWith(rrule: rrule, isRepeatParent: true);
  await dao.updateTask(updated);
  return ActionResult(
    success: true,
    message: '已设置「${existing.title}」重复规则：$rrule',
    data: updated,
  );
}

Future<ActionResult> _executeClearRepeat(
  AgentAction action,
  TaskRepository dao,
) async {
  final taskId = _parseTaskId(action.params['taskId']);
  if (taskId == null) {
    return const ActionResult(success: false, message: '无效的任务 ID');
  }
  final existing = await dao.getTaskById(taskId);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 $taskId 不存在');
  }
  // copyWith 用 ?? 语义无法把可空字段写回 null；直接赋值。
  existing.rrule = null;
  existing.isRepeatParent = false;
  existing.updatedAt = DateTime.now();
  await dao.updateTask(existing);
  return ActionResult(
    success: true,
    message: '已取消「${existing.title}」的重复规则',
    data: existing,
  );
}

// ==================== 辅助方法 ====================

int _parsePriority(dynamic value) {
  if (value is int) return value.clamp(0, 3);
  if (value is String) return int.tryParse(value)?.clamp(0, 3) ?? 0;
  return 0;
}

int? _parseTaskId(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<String> _parseStringList(dynamic value) {
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return [];
}

List<DateTime> _parseDateList(dynamic value) {
  if (value is! List) return <DateTime>[];
  final out = <DateTime>[];
  for (final v in value) {
    final dt = _parseDate(v);
    if (dt != null) out.add(dt);
  }
  out.sort((a, b) => a.compareTo(b));
  return out;
}

/// 把简词重复规则映射为 RFC 5545 RRULE 字符串。
///
/// type ∈ {daily, weekly, monthly}，interval ≥ 1。
/// 输入非法时返回 null。
@visibleForTesting
String? repeatToRrule(String? type, int? interval) {
  if (type == null) return null;
  final iv = (interval == null || interval < 1) ? 1 : interval;
  switch (type.toLowerCase()) {
    case 'daily':
      return 'FREQ=DAILY;INTERVAL=$iv';
    case 'weekly':
      return 'FREQ=WEEKLY;INTERVAL=$iv';
    case 'monthly':
      return 'FREQ=MONTHLY;INTERVAL=$iv';
    default:
      return null;
  }
}

/// 同时兼容 `rrule` 字符串与 `repeat: {type, interval}` 简词形式。
/// rrule 优先；二者都缺失返回 null。
String? _resolveRrule(Map<String, dynamic> params) {
  final rrule = params['rrule'];
  if (rrule is String && rrule.isNotEmpty) return rrule;
  final repeat = params['repeat'];
  if (repeat is Map) {
    final type = repeat['type'] as String?;
    final iv = repeat['interval'];
    final intervalInt = iv is int
        ? iv
        : (iv is String ? int.tryParse(iv) : null);
    return repeatToRrule(type, intervalInt);
  }
  return null;
}

String _fmtDateTime(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

// ==================== Agent System Prompt ====================

const String kAgentSystemPrompt = '''
你是一个任务管理 AI Agent，可以直接帮用户管理任务。

【动作目录】
你可以在 actions 数组里放任意条以下指令：

1) create_task — 创建新任务
   params: title(必填), priority?(1-3), description?, tags?(string[]),
           groupName?, dueDate?(YYYY-MM-DD 或 YYYY-MM-DDTHH:mm),
           reminderTimes?(YYYY-MM-DDTHH:mm 字符串数组),
           rrule?(如 "FREQ=DAILY;INTERVAL=1") 或 repeat?({type, interval})

2) update_task — 修改已有任务（任意字段都可）
   params: taskId(必填) + 任意以下：
           title?, description?, priority?, dueDate?, tags?, groupName?,
           reminderTimes?(整段替换), rrule?(传 null 表示取消重复) 或 repeat?({type, interval}),
           isCompleted?(true 表示完成，false 表示撤销完成)

3) complete_task — 完成任务  params: taskId
4) uncomplete_task — 撤销完成 params: taskId
5) delete_task — 删除任务   params: taskId
6) decompose_task — 拆解任务 params: taskId, subtasks[{title, priority?}]

7) add_tag / remove_tag    params: taskId, tag
8) set_group               params: taskId, groupName
9) set_priority            params: taskId, priority(1-3)

10) add_reminder           params: taskId, time("YYYY-MM-DDTHH:mm")
11) remove_reminder        params: taskId, 二选一: time(同上) 或 index(从 0 起)
12) clear_reminders        params: taskId

13) set_repeat             params: taskId,
                                   rrule?("FREQ=DAILY;INTERVAL=2")
                                   或 repeat?({type:"daily|weekly|monthly", interval:>=1})
14) clear_repeat           params: taskId

【重复规则】
- 优先使用 rrule 字符串（RFC 5545）；
- 也可使用简词 {type, interval} 由代码转 rrule；
- 客户端会自动维护 isRepeatParent 字段，不必手动设置。

【确认机制（仅给你做参考；客户端自动判断）】
- create_task / add_tag / remove_tag / set_group / set_priority / decompose_task → 自动执行
- 其它涉及"修改/删除已有任务"的（含 reminders / repeat / 完成态切换）→ 用户会被弹卡确认

【规则】
1. 操作已有任务时必须用 taskId（来自上下文里的 [id:N]）。
2. 优先复用上下文给出的分组/标签，除非用户明确要求新建。
3. priority: 1=低 2=中 3=高。
4. 不确定意图时，只返回 reply，不放 action。
5. 回复要简短有温度。
6. 你必须只返回纯 JSON：{"reply": "...", "actions": [...]}；actions 为空表示纯聊天。
7. **字段语义**：在 update_task 里
   - 不传字段 → 不变；
   - 传具体值 → 改为该值；
   - 传 null → 显式清空（仅 description / dueDate / groupName / rrule 支持 null 清空）。
   不要为了"保持不变"而把字段重复传一遍，会浪费 tokens。

【示例】
用户："明天上午 9 点提醒我吃药"
你：
{
  "reply": "好，明早 9 点提醒你吃药。",
  "actions": [
    {"type": "create_task",
     "params": {"title": "吃药",
                "dueDate": "2026-06-16",
                "reminderTimes": ["2026-06-16T09:00"]}}
  ]
}

用户："把'写报告'的描述清掉，截止改到下周三晚 8 点"
你：
{
  "reply": "好的。",
  "actions": [
    {"type": "update_task",
     "params": {"taskId": 12, "description": null,
                "dueDate": "2026-06-17T20:00"}}
  ]
}

用户："把'晨会'设为每周一三五"
你（先建议简词或直接 rrule，二选一即可）：
{
  "reply": "好的，已经把晨会改成每周重复（间隔 1 周），需要更精细到周一三五吗？我可以用 rrule 写。",
  "actions": [
    {"type": "set_repeat",
     "params": {"taskId": 12, "rrule": "FREQ=WEEKLY;BYDAY=MO,WE,FR"}}
  ]
}

用户："取消'写周报'的重复"
你：
{
  "reply": "好的，已取消重复。",
  "actions": [
    {"type": "clear_repeat", "params": {"taskId": 7}}
  ]
}
''';

// ==================== 时间安排优化助手（PLAN-AI-001-4） ====================

/// 优化建议类型。
enum SchedulingSuggestionType {
  reschedule('reschedule'),
  decompose('decompose'),
  setPriority('set_priority'),
  completeOrDrop('complete_or_drop'),
  addReminder('add_reminder');

  final String value;
  const SchedulingSuggestionType(this.value);

  static SchedulingSuggestionType? fromString(String? v) {
    if (v == null) return null;
    for (final s in SchedulingSuggestionType.values) {
      if (s.value == v) return s;
    }
    return null;
  }
}

/// 一个识别到的"问题"：堆叠 / 大任务 / 长期不动 等。
class SchedulingIssue {
  final String type;
  final String? date;
  final List<int> taskIds;
  final String note;

  const SchedulingIssue({
    required this.type,
    this.date,
    this.taskIds = const [],
    required this.note,
  });

  factory SchedulingIssue.fromJson(Map<String, dynamic> json) {
    final ids = <int>[];
    final raw = json['taskIds'];
    if (raw is List) {
      for (final v in raw) {
        if (v is int) {
          ids.add(v);
        } else if (v is String) {
          final p = int.tryParse(v);
          if (p != null) ids.add(p);
        }
      }
    } else if (raw is int) {
      ids.add(raw);
    }
    return SchedulingIssue(
      type: (json['type'] as String?) ?? 'unknown',
      date: json['date'] as String?,
      taskIds: ids,
      note: (json['note'] as String?) ?? '',
    );
  }
}

/// 一条具体建议。
class SchedulingSuggestion {
  final String id;
  final SchedulingSuggestionType type;
  final int? taskId;
  final DateTime? newDueDate;
  final int? priority;
  final List<Map<String, dynamic>>? subtasks;
  final List<DateTime>? reminderTimes;
  final String reason;

  const SchedulingSuggestion({
    required this.id,
    required this.type,
    this.taskId,
    this.newDueDate,
    this.priority,
    this.subtasks,
    this.reminderTimes,
    required this.reason,
  });

  /// LLM 给的描述，UI 卡片标题用。
  String get title {
    switch (type) {
      case SchedulingSuggestionType.reschedule:
        final d = newDueDate;
        return '把任务 [$taskId] 改到 ${d != null ? _fmtDate(d) : '?'}';
      case SchedulingSuggestionType.decompose:
        final n = subtasks?.length ?? 0;
        return '拆解任务 [$taskId]（$n 个子任务）';
      case SchedulingSuggestionType.setPriority:
        final p = priority;
        final label = p == 3 ? '高' : p == 2 ? '中' : p == 1 ? '低' : '?';
        return '设置任务 [$taskId] 优先级为 $label';
      case SchedulingSuggestionType.completeOrDrop:
        return '考虑完成或关闭任务 [$taskId]';
      case SchedulingSuggestionType.addReminder:
        final times = reminderTimes;
        if (times != null && times.isNotEmpty) {
          return '给任务 [$taskId] 加 ${times.length} 个提醒';
        }
        return '给任务 [$taskId] 加提醒';
    }
  }

  static SchedulingSuggestion? tryFromJson(Map<String, dynamic> json) {
    final t = SchedulingSuggestionType.fromString(json['type'] as String?);
    if (t == null) return null;
    final id = json['id'] as String? ?? '';
    int? parseInt(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

    DateTime? parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    List<DateTime>? parseDates(dynamic v) {
      if (v is! List) return null;
      final out = <DateTime>[];
      for (final x in v) {
        final d = parseDate(x);
        if (d != null) out.add(d);
      }
      out.sort((a, b) => a.compareTo(b));
      return out.isEmpty ? null : out;
    }

    final priorityRaw = parseInt(json['priority']);
    final priority = priorityRaw?.clamp(0, 3);

    final subtasksRaw = json['subtasks'];
    List<Map<String, dynamic>>? subtasks;
    if (subtasksRaw is List) {
      subtasks = subtasksRaw
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false);
    }

    return SchedulingSuggestion(
      id: id,
      type: t,
      taskId: parseInt(json['taskId']),
      newDueDate: parseDate(json['newDueDate']),
      priority: priority,
      subtasks: subtasks,
      reminderTimes: parseDates(json['reminderTimes']),
      reason: (json['reason'] as String?) ?? '',
    );
  }
}

/// 一份完整的时间安排分析结果。
class SchedulingPlan {
  final String summary;
  final List<SchedulingIssue> issues;
  final List<SchedulingSuggestion> suggestions;

  /// 解析时被忽略的未知建议类型，UI 可在底部弱提示。
  final List<String> warnings;

  const SchedulingPlan({
    required this.summary,
    this.issues = const [],
    this.suggestions = const [],
    this.warnings = const [],
  });

  factory SchedulingPlan.fromJson(Map<String, dynamic> json) {
    final issuesRaw = json['issues'];
    final issues = <SchedulingIssue>[];
    if (issuesRaw is List) {
      for (final x in issuesRaw) {
        if (x is Map<String, dynamic>) issues.add(SchedulingIssue.fromJson(x));
      }
    }
    final suggestionsRaw = json['suggestions'];
    final suggestions = <SchedulingSuggestion>[];
    final warnings = <String>[];
    if (suggestionsRaw is List) {
      for (final x in suggestionsRaw) {
        if (x is! Map<String, dynamic>) continue;
        final s = SchedulingSuggestion.tryFromJson(x);
        if (s != null) {
          suggestions.add(s);
        } else {
          final t = x['type'];
          if (t is String && t.isNotEmpty) warnings.add(t);
        }
      }
    }
    return SchedulingPlan(
      summary: (json['summary'] as String?) ?? '',
      issues: issues,
      suggestions: suggestions,
      warnings: warnings,
    );
  }
}

/// 应用一条建议；返回 [ActionResult]。
///
/// `completeOrDrop` **不在此处自动执行**：UI 必须二次确认后调
/// [executeAction]([completeTask]) 或 [deleteTask]，避免误关闭。
Future<ActionResult> applySchedulingSuggestion(
  SchedulingSuggestion s,
  TaskRepository dao,
) async {
  try {
    switch (s.type) {
      case SchedulingSuggestionType.reschedule:
        return await _applyReschedule(s, dao);
      case SchedulingSuggestionType.setPriority:
        return await _applySetPriority(s, dao);
      case SchedulingSuggestionType.decompose:
        return await _applyDecompose(s, dao);
      case SchedulingSuggestionType.addReminder:
        return await _applyAddReminders(s, dao);
      case SchedulingSuggestionType.completeOrDrop:
        return const ActionResult(
          success: false,
          message: 'complete_or_drop 需要 UI 二次确认后再执行',
        );
    }
  } catch (e) {
    return ActionResult(success: false, message: '应用建议失败: $e');
  }
}

Future<ActionResult> _applyReschedule(
  SchedulingSuggestion s,
  TaskRepository dao,
) async {
  if (s.taskId == null || s.newDueDate == null) {
    return const ActionResult(success: false, message: 'reschedule 缺少 taskId 或 newDueDate');
  }
  final existing = await dao.getTaskById(s.taskId!);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 ${s.taskId} 不存在');
  }
  // 边界保护：若 LLM 给出过去时间，仍允许（用户可能就要回填），但加个温和提示
  existing.dueDate = s.newDueDate;
  existing.updatedAt = DateTime.now();
  await dao.updateTask(existing);
  return ActionResult(
    success: true,
    message: '已把「${existing.title}」改到 ${_fmtDate(s.newDueDate!)}',
    data: existing,
  );
}

Future<ActionResult> _applySetPriority(
  SchedulingSuggestion s,
  TaskRepository dao,
) async {
  if (s.taskId == null || s.priority == null) {
    return const ActionResult(success: false, message: 'set_priority 缺参');
  }
  final existing = await dao.getTaskById(s.taskId!);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 ${s.taskId} 不存在');
  }
  final updated = existing.copyWith(priority: s.priority!.clamp(0, 3));
  await dao.updateTask(updated);
  final label = s.priority == 3 ? '高' : s.priority == 2 ? '中' : s.priority == 1 ? '低' : '无';
  return ActionResult(
    success: true,
    message: '已把「${existing.title}」优先级设为$label',
    data: updated,
  );
}

Future<ActionResult> _applyDecompose(
  SchedulingSuggestion s,
  TaskRepository dao,
) async {
  if (s.taskId == null || s.subtasks == null || s.subtasks!.isEmpty) {
    return const ActionResult(success: false, message: 'decompose 缺少子任务');
  }
  final existing = await dao.getTaskById(s.taskId!);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 ${s.taskId} 不存在');
  }
  final created = <String>[];
  for (final st in s.subtasks!) {
    final title = st['title'] as String? ?? '';
    if (title.isEmpty) continue;
    final task = Task(
      title: title,
      priority: _parsePriority(st['priority']),
      groupName: existing.groupName,
      tags: List<String>.from(existing.tags),
    );
    await dao.insertTask(task);
    created.add(title);
  }
  return ActionResult(
    success: true,
    message: '已把「${existing.title}」拆为 ${created.length} 个子任务',
    data: created,
  );
}

Future<ActionResult> _applyAddReminders(
  SchedulingSuggestion s,
  TaskRepository dao,
) async {
  if (s.taskId == null || s.reminderTimes == null || s.reminderTimes!.isEmpty) {
    return const ActionResult(success: false, message: 'add_reminder 缺少时间');
  }
  final existing = await dao.getTaskById(s.taskId!);
  if (existing == null) {
    return ActionResult(success: false, message: '任务 ${s.taskId} 不存在');
  }
  final newTimes = List<DateTime>.from(existing.reminderTimes);
  for (final t in s.reminderTimes!) {
    if (!newTimes.any((x) => x.isAtSameMomentAs(t))) newTimes.add(t);
  }
  newTimes.sort((a, b) => a.compareTo(b));
  final updated = existing.copyWith(reminderTimes: newTimes);
  await dao.updateTask(updated);
  return ActionResult(
    success: true,
    message: '已给「${existing.title}」加 ${s.reminderTimes!.length} 个提醒',
    data: updated,
  );
}

/// 时间安排优化的 system prompt。
///
/// 与 [kAgentSystemPrompt] 不同：本提示只生成"分析报告 + 建议清单"，
/// 不直接执行 action。客户端把每条建议渲染成卡片，逐条/批量应用。
const String kSchedulingSystemPrompt = '''
你是一位时间管理顾问。基于"任务上下文"分析用户当前的安排，输出**纯 JSON**：
{
  "summary": "一句话总览（30 字以内）",
  "issues": [
    {"type": "overload|too_big|stale|conflict|other",
     "date": "YYYY-MM-DD" 或 null,
     "taskIds": [int, ...],
     "note": "简短说明"}
  ],
  "suggestions": [
    {"id": "s1",
     "type": "reschedule",
     "taskId": <int>,
     "newDueDate": "YYYY-MM-DDTHH:mm",
     "reason": "..."},
    {"id": "s2",
     "type": "decompose",
     "taskId": <int>,
     "subtasks": [
        {"title": "...", "priority": 1|2|3, "estimatedDays": <int?>}
     ],
     "reason": "..."},
    {"id": "s3",
     "type": "set_priority",
     "taskId": <int>,
     "priority": 1|2|3,
     "reason": "..."},
    {"id": "s4",
     "type": "complete_or_drop",
     "taskId": <int>,
     "reason": "..."},
    {"id": "s5",
     "type": "add_reminder",
     "taskId": <int>,
     "reminderTimes": ["YYYY-MM-DDTHH:mm", ...],
     "reason": "..."}
  ]
}

规则：
1. 只能引用上下文里出现过的 taskId（[id:N]）。
2. 建议总数 3–8 条，避免泛滥。
3. 工作日参考：周一至周五 9:00–18:00；除非用户上下文给了不同信号。
4. 不要返回 markdown 代码块，只返回纯 JSON。
5. 没什么好建议时，suggestions 留空数组，summary 简单描述。
''';
