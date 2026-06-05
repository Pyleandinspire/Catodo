import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task.dart';
import '../../providers/task_providers.dart';
import '../../services/notification_service.dart';
import '../../services/repeat_task_service.dart';
import '../../data/task_dao.dart';
import '../../providers/isar_provider.dart';

class TaskItem extends ConsumerWidget {
  final Task task;
  final VoidCallback onTap;

  const TaskItem({
    super.key,
    required this.task,
    required this.onTap,
  });

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 3:
        return Colors.redAccent;
      case 2:
        return Colors.orangeAccent;
      case 1:
        return Colors.blueAccent;
      default:
        return Colors.grey[300]!;
    }
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 3:
        return '高';
      case 2:
        return '中';
      case 1:
        return '低';
      default:
        return '';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    final diff = taskDate.difference(today).inDays;
    
    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    if (diff == -1) return '昨天';
    if (diff > 0 && diff < 7) {
      const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[taskDate.weekday];
    }
    return '${date.month}/${date.day}';
  }

  Future<void> _toggleComplete(WidgetRef ref, Task task) async {
    final isar = await ref.watch(isarProvider.future);
    final dao = TaskDao(isar);

    if (task.isRepeatParent && !task.isCompleted) {
      await dao.updateTask(task.copyWith(isCompleted: true));

      try {
        final nextTask = RepeatTaskService().generateNextRepeatTask(task);
        if (nextTask != null) {
          await dao.insertTask(nextTask);
          await NotificationService().scheduleTaskReminder(nextTask);
        }
      } catch (e) {
        print('Failed to create next task: $e');
      }
    } else {
      await dao.updateTask(task.copyWith(isCompleted: !task.isCompleted));
    }

    await NotificationService().cancelTaskReminder(task.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 圆形勾选框
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: GestureDetector(
                  onTap: () => _toggleComplete(ref, task),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: task.isCompleted ? Colors.green : Colors.grey[400]!,
                        width: 2,
                      ),
                      color: task.isCompleted ? Colors.green : Colors.transparent,
                    ),
                    child: task.isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // 任务内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题和优先级
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                              color: task.isCompleted ? Colors.grey : Colors.black87,
                            ),
                          ),
                        ),
                        if (task.priority > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(task.priority),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getPriorityLabel(task.priority),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    // 描述
                    if (task.description != null && task.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          task.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    
                    // 标签、日期、分组
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          if (task.dueDate != null)
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(task.dueDate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: task.dueDate!.isBefore(DateTime.now()) && !task.isCompleted
                                        ? Colors.red
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          if (task.dueDate != null && task.groupName != null)
                            const SizedBox(width: 12),
                          if (task.groupName != null)
                            Row(
                              children: [
                                const Icon(Icons.folder, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  task.groupName!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          if (task.rrule != null)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.repeat, size: 14, color: Colors.blue),
                            ),
                        ],
                      ),
                    ),
                    
                    // 标签
                    if (task.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          children: task.tags.take(3).map((tag) => Chip(
                            label: Text(
                              tag,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.grey[100],
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          )).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}