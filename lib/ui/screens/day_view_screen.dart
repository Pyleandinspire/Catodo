import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/task_item.dart';
import '../../providers/task_providers.dart';
import '../../models/task.dart';
import 'task_form_screen.dart';

class DayViewScreen extends ConsumerWidget {
  const DayViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(filteredTasksProvider);

    Map<DateTime, List<Task>> groupedTasks = {};
    
    for (final task in tasks) {
      if (task.dueDate != null) {
        final dateKey = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
        groupedTasks.putIfAbsent(dateKey, () => []).add(task);
      } else {
        final noDateKey = DateTime(0);
        groupedTasks.putIfAbsent(noDateKey, () => []).add(task);
      }
    }

    final sortedDates = groupedTasks.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    String _formatDateHeader(DateTime date) {
      if (date.year == 0) return '无截止日期';
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final taskDate = DateTime(date.year, date.month, date.day);
      final diff = taskDate.difference(today).inDays;
      
      if (diff == 0) return '今天';
      if (diff == 1) return '明天';
      if (diff == -1) return '昨天';
      if (diff > 0 && diff < 7) {
        const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        return weekdays[date.weekday];
      }
      return '${date.month}月${date.day}日';
    }

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
                    '按天视图',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${tasks.length} 个任务',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // 任务列表按天分组
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.calendar_today,
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
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: sortedDates.length,
                      itemBuilder: (context, dateIndex) {
                        final date = sortedDates[dateIndex];
                        final dayTasks = groupedTasks[date]!;
                        final completedCount = dayTasks.where((t) => t.isCompleted).length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 日期头部
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Text(
                                    _formatDateHeader(date),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$completedCount/${dayTasks.length}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 任务列表
                            ...dayTasks.map((task) => TaskItem(
                              task: task,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TaskFormScreen(task: task),
                                ),
                              ),
                            )).toList(),
                          ],
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
}