import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/task_item.dart';
import '../../providers/task_providers.dart';
import '../../models/task.dart';
import '../../models/filter.dart';
import 'task_form_screen.dart';

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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Catodo',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '今日待办',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$pendingCount',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '/ $completedCount 已完成',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: tasks.isNotEmpty
                  ? LinearProgressIndicator(
                      value: tasks.length > 0 ? completedCount / tasks.length : 0,
                      backgroundColor: Colors.grey[200],
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                      minHeight: 6,
                    )
                  : const SizedBox(height: 6),
            ),

            const SizedBox(height: 16),

            // 筛选按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showFilterDialog(context, ref),
                      icon: const Icon(Icons.filter_list, size: 18),
                      label: const Text('筛选'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TaskFormScreen()),
        ),
        backgroundColor: Colors.blue,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterConditionProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('筛选条件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String?>(
              value: filter.selectedGroup,
              items: const [
                DropdownMenuItem(value: null, child: Text('全部分组')),
                DropdownMenuItem(value: '工作', child: Text('工作')),
                DropdownMenuItem(value: '个人', child: Text('个人')),
                DropdownMenuItem(value: '学习', child: Text('学习')),
              ],
              onChanged: (value) => ref.read(filterConditionProvider.notifier).state =
                  filter.copyWith(selectedGroup: value),
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
              onChanged: (value) => ref.read(filterConditionProvider.notifier).state =
                  filter.copyWith(selectedPriority: value),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: '标签'),
              onChanged: (value) => ref.read(filterConditionProvider.notifier).state =
                  filter.copyWith(selectedTag: value.isEmpty ? null : value),
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
}