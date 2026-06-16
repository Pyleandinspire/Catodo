import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/task_item.dart';
import '../../providers/task_providers.dart';
import '../../models/filter.dart';
import 'task_form_screen.dart';
import 'day_view_screen.dart';
import '../../services/webdav_service.dart';
import '../../providers/webdav_provider.dart';
import '../../data/task_dao.dart';
import '../../providers/isar_provider.dart';

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget? child;

  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: child ?? Icon(icon, size: 21, color: colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(filteredTasksProvider);
    final completedCount = tasks.where((t) => t.isCompleted).length;
    final pendingCount = tasks.length - completedCount;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 头部区域
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '喵待办',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '待办 $pendingCount 项 · 已完成 $completedCount 项',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeaderActionButton(
                          icon: Icons.calendar_today_rounded,
                          tooltip: '按天视图',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DayViewScreen(),
                            ),
                          ),
                        ),
                        _HeaderActionButton(
                          icon: Icons.add_rounded,
                          tooltip: '添加任务',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TaskFormScreen(),
                            ),
                          ),
                        ),
                        _HeaderActionButton(
                          icon: Icons.filter_list_rounded,
                          tooltip: '筛选',
                          onPressed: () => _showFilterDialog(context, ref),
                        ),
                        _buildSyncButton(context, ref),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: tasks.isNotEmpty ? completedCount / tasks.length : 0,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        color: colorScheme.primary,
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 任务列表
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.task_alt_rounded,
                            size: 70,
                            color: colorScheme.primary.withValues(alpha: 0.22),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '还没有任务',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '点击添加按钮，记录下一件想完成的事',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return TaskItem(
                          task: task,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TaskFormScreen(task: task),
                            ),
                          ),
                        );
                      },
                    ),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('筛选条件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String?>(
              value: filter.selectedGroup,
              items: [
                const DropdownMenuItem(value: null, child: Text('全部分组')),
                const DropdownMenuItem(value: '工作', child: Text('工作')),
                const DropdownMenuItem(value: '个人', child: Text('个人')),
                const DropdownMenuItem(value: '学习', child: Text('学习')),
                ...allGroups
                    .where((g) => !['工作', '个人', '学习'].contains(g))
                    .map((g) => DropdownMenuItem(value: g, child: Text(g))),
              ],
              onChanged: (value) =>
                  ref.read(filterConditionProvider.notifier).state = filter
                      .copyWith(selectedGroup: value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              value: filter.selectedPriority,
              items: const [
                DropdownMenuItem(value: null, child: Text('全部优先级')),
                DropdownMenuItem(value: 0, child: Text('无优先级')),
                DropdownMenuItem(value: 1, child: Text('低优先级')),
                DropdownMenuItem(value: 2, child: Text('中优先级')),
                DropdownMenuItem(value: 3, child: Text('高优先级')),
              ],
              onChanged: (value) =>
                  ref.read(filterConditionProvider.notifier).state = filter
                      .copyWith(selectedPriority: value),
            ),
            const SizedBox(height: 16),
            if (allTags.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('暂无标签', style: TextStyle(color: Colors.grey)),
              )
            else
              DropdownButtonFormField<String?>(
                value: allTags.contains(filter.selectedTag)
                    ? filter.selectedTag
                    : null,
                decoration: const InputDecoration(labelText: '标签'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部标签')),
                  ...allTags.map(
                    (t) => DropdownMenuItem(value: t, child: Text(t)),
                  ),
                ],
                onChanged: (value) =>
                    ref.read(filterConditionProvider.notifier).state = filter
                        .copyWith(selectedTag: value),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(filterConditionProvider.notifier).state = TaskFilter();
              Navigator.pop(context);
            },
            child: const Text('重置'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);

    return _HeaderActionButton(
      icon: Icons.sync_rounded,
      tooltip: syncStatus == SyncStatus.syncing ? '同步中...' : '同步',
      onPressed: syncStatus == SyncStatus.syncing
          ? null
          : () => _performSync(context, ref),
      child: syncStatus == SyncStatus.syncing
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : null,
    );
  }

  Future<void> _performSync(BuildContext context, WidgetRef ref) async {
    final config = ref.read(webdavConfigProvider);

    if (!config.isValid) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先配置 WebDAV')));
      }
      return;
    }

    ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;

    try {
      final isar = await ref.read(isarProvider.future);
      final dao = TaskDao(isar);
      final localTasks = await dao.getAllTasks();
      final syncMode = ref.read(syncModeProvider);

      final service = WebDAVService(config);
      final result = await service.sync(localTasks, mode: syncMode);

      if (result.status == SyncStatus.synced) {
        // 使用 sync 返回的合并结果更新本地数据库
        for (final task in result.mergedTasks) {
          if (task.isDeleted) {
            await dao.softDeleteTask(task.id);
          } else {
            await dao.updateTask(task);
          }
        }

        // 清理本地存在但合并结果中不存在的任务（双方都确认删除）
        final mergedSyncIds = result.mergedTasks
            .where((t) => t.syncId != null)
            .map((t) => t.syncId!)
            .toSet();
        for (final localTask in localTasks) {
          if (localTask.syncId != null &&
              !mergedSyncIds.contains(localTask.syncId)) {
            await dao.hardDeleteTask(localTask.id);
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '同步成功！上传 ${result.uploadedCount} 个，下载 ${result.downloadedCount} 个',
              ),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('同步失败: ${result.error ?? '未知错误'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步异常: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
    }
  }
}
