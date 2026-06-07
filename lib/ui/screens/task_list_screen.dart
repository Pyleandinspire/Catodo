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
            // 头部区域
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 标题
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catodo',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '$pendingCount/$completedCount',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // 右上角按钮组
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DayViewScreen(),
                          ),
                        ),
                        icon: const Icon(
                          Icons.calendar_today,
                          color: Colors.black,
                        ),
                        tooltip: '按天视图',
                      ),
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TaskFormScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.add, color: Colors.black),
                        tooltip: '添加任务',
                      ),
                      IconButton(
                        onPressed: () => _showFilterDialog(context, ref),
                        icon: const Icon(
                          Icons.filter_list,
                          color: Colors.black,
                        ),
                        tooltip: '筛选',
                      ),
                      _buildSyncButton(context, ref),
                    ],
                  ),
                ],
              ),
            ),

            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: tasks.isNotEmpty
                  ? LinearProgressIndicator(
                      value: tasks.length > 0
                          ? completedCount / tasks.length
                          : 0,
                      backgroundColor: Colors.grey[200],
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                      minHeight: 4,
                    )
                  : const SizedBox(height: 4),
            ),

            const SizedBox(height: 8),

            // 任务列表
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: Color(0xFFE0E0E0),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '暂无任务',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '点击下方按钮添加新任务',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFBDBDBD),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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

    return IconButton(
      onPressed: syncStatus == SyncStatus.syncing
          ? null
          : () => _performSync(context, ref),
      icon: syncStatus == SyncStatus.syncing
          ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
          : const Icon(Icons.sync, color: Colors.black),
      tooltip: syncStatus == SyncStatus.syncing ? '同步中...' : '同步',
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
