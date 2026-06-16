import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/task_item.dart';
import '../../providers/task_providers.dart';
import '../../models/filter.dart';
import '../../models/task.dart';
import 'task_form_screen.dart';
import 'day_view_screen.dart';
import '../../services/webdav_service.dart';
import '../../providers/webdav_provider.dart';
import '../../data/task_dao.dart';
import '../../providers/isar_provider.dart';
import '../../providers/chat_provider.dart';

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(filteredTasksProvider);
    final completedCount = tasks.where((t) => t.isCompleted).length;
    final pendingCount = tasks.length - completedCount;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 头部
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Catodo', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text('$pendingCount/$completedCount', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  ]),
                  Row(children: [
                    IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DayViewScreen())), icon: const Icon(Icons.calendar_today, color: Colors.black), tooltip: '按天视图'),
                    IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskFormScreen())), icon: const Icon(Icons.add, color: Colors.black), tooltip: '添加任务'),
                    IconButton(onPressed: () => _showFilterDialog(context, ref), icon: const Icon(Icons.filter_list, color: Colors.black), tooltip: '筛选'),
                    _buildSyncButton(context, ref),
                  ]),
                ],
              ),
            ),
            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: tasks.isNotEmpty
                  ? LinearProgressIndicator(value: tasks.length > 0 ? completedCount / tasks.length : 0, backgroundColor: Colors.grey[200], color: Colors.green, borderRadius: BorderRadius.circular(8), minHeight: 4)
                  : const SizedBox(height: 4),
            ),
            const SizedBox(height: 8),
            // 任务列表
            Expanded(
              child: tasks.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.check_circle_outline, size: 64, color: Color(0xFFE0E0E0)),
                      SizedBox(height: 16),
                      Text('暂无任务', style: TextStyle(fontSize: 16, color: Color(0xFF9E9E9E))),
                      SizedBox(height: 8),
                      Text('点击下方按钮添加新任务', style: TextStyle(fontSize: 14, color: Color(0xFFBDBDBD))),
                    ]))
                  : _buildTaskList(ref, context, tasks),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterConditionProvider);
    final allGroups = ref.watch(allGroupsProvider);
    final allTags = ref.watch(allTagsProvider);
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('筛选条件'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String?>(value: filter.selectedGroup, items: [
          const DropdownMenuItem(value: null, child: Text('全部分组')),
          const DropdownMenuItem(value: '工作', child: Text('工作')),
          const DropdownMenuItem(value: '个人', child: Text('个人')),
          const DropdownMenuItem(value: '学习', child: Text('学习')),
          ...allGroups.where((g) => !['工作', '个人', '学习'].contains(g)).map((g) => DropdownMenuItem(value: g, child: Text(g))),
        ], onChanged: (v) => ref.read(filterConditionProvider.notifier).state = filter.copyWith(selectedGroup: v)),
        const SizedBox(height: 16),
        DropdownButtonFormField<int?>(value: filter.selectedPriority, items: const [
          DropdownMenuItem(value: null, child: Text('全部优先级')),
          DropdownMenuItem(value: 0, child: Text('无优先级')),
          DropdownMenuItem(value: 1, child: Text('低优先级')),
          DropdownMenuItem(value: 2, child: Text('中优先级')),
          DropdownMenuItem(value: 3, child: Text('高优先级')),
        ], onChanged: (v) => ref.read(filterConditionProvider.notifier).state = filter.copyWith(selectedPriority: v)),
        const SizedBox(height: 16),
        if (allTags.isEmpty) const Align(alignment: Alignment.centerLeft, child: Text('暂无标签', style: TextStyle(color: Colors.grey)))
        else DropdownButtonFormField<String?>(value: allTags.contains(filter.selectedTag) ? filter.selectedTag : null, decoration: const InputDecoration(labelText: '标签'), items: [
          const DropdownMenuItem(value: null, child: Text('全部标签')),
          ...allTags.map((t) => DropdownMenuItem(value: t, child: Text(t))),
        ], onChanged: (v) => ref.read(filterConditionProvider.notifier).state = filter.copyWith(selectedTag: v)),
      ]),
      actions: [
        TextButton(onPressed: () { ref.read(filterConditionProvider.notifier).state = TaskFilter(); Navigator.pop(context); }, child: const Text('清除筛选')),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
      ],
    ));
  }

  Widget _buildTaskList(WidgetRef ref, BuildContext context, List tasks) {
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    final weekEnd = today0.add(const Duration(days: 7));

    final urgent = <Task>[];
    final thisWeek = <Task>[];
    final later = <Task>[];
    final completed = <Task>[];

    for (final t in tasks) {
      if (t.isCompleted) { completed.add(t); continue; }
      if (t.dueDate == null) { later.add(t); continue; }
      if (t.dueDate!.isBefore(today0.add(const Duration(days: 1)))) { urgent.add(t); continue; }
      if (t.dueDate!.isBefore(weekEnd)) { thisWeek.add(t); continue; }
      later.add(t);
    }

    int count = 0;
    if (urgent.isNotEmpty) count += 1 + urgent.length;
    if (thisWeek.isNotEmpty) count += 1 + thisWeek.length;
    if (later.isNotEmpty) count += 1 + later.length;
    if (completed.isNotEmpty) count += 1 + completed.length;
    if (count == 0) {
      return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 8), itemCount: tasks.length, itemBuilder: (ctx, i) {
        final task = tasks[i];
        return TaskItem(task: task,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TaskFormScreen(task: task))),
                    onHeartTap: (t) {
                    ref.read(chatInitialMessageProvider.notifier).state = '我有个任务「${t.title}」已经逾期了，给我一点支持和建议';
                    ref.read(selectedTabProvider.notifier).state = 2;
                  });
      });
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: count,
      itemBuilder: (ctx, index) {
        int cursor = 0;
        for (final s in [
          if (urgent.isNotEmpty) ['今天 / 逾期 (${urgent.length})', urgent],
          if (thisWeek.isNotEmpty) ['本周 (${thisWeek.length})', thisWeek],
          if (later.isNotEmpty) ['以后 (${later.length})', later],
          if (completed.isNotEmpty) ['已完成 (${completed.length})', completed],
        ]) {
          final title = s[0] as String;
          final list = s[1] as List<Task>;
          if (index == cursor) return Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 8), child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF757575))));
          cursor += 1;
          final ti = index - cursor;
          if (ti < list.length) {
            final task = list[ti];
            return TaskItem(task: task,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskFormScreen(task: task))),
                    onHeartTap: (t) {
                    ref.read(chatInitialMessageProvider.notifier).state = '我有个任务「${t.title}」已经逾期了，给我一点支持和建议';
                    ref.read(selectedTabProvider.notifier).state = 2;
                  });
          }
          cursor += list.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSyncButton(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    return IconButton(
      onPressed: syncStatus == SyncStatus.syncing ? null : () async {
        ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
        final config = ref.read(webdavConfigProvider);
        if (!config.isValid) { ref.read(syncStatusProvider.notifier).state = SyncStatus.idle; return; }
        final isar = ref.read(isarProvider).valueOrNull;
        if (isar == null) { ref.read(syncStatusProvider.notifier).state = SyncStatus.idle; return; }
        final dao = TaskDao(isar);
        final service = WebDAVService(config);
        final mode = ref.read(syncModeProvider);
        try {
          final result = await service.sync(await dao.getAllTasks(), mode: mode);
          if (result.mergedTasks != null) {
            for (final t in result.mergedTasks!) {
              if (t.isDeleted) { await dao.softDeleteTask(t.id); } else { await dao.updateTask(t); }
            }
          }
          ref.read(syncStatusProvider.notifier).state = SyncStatus.synced;
        } catch (_) { ref.read(syncStatusProvider.notifier).state = SyncStatus.failed; }
      },
      icon: syncStatus == SyncStatus.syncing ? const Icon(Icons.sync, color: Colors.orange) : const Icon(Icons.cloud, color: Colors.grey),
      tooltip: syncStatus == SyncStatus.syncing ? '同步中...' : '同步',
    );
  }
}
