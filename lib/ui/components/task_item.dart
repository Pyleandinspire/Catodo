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

  Color _getPriorityBackground(int priority) {
    switch (priority) {
      case 3:
        return const Color(0xFFFFE4E6);
      case 2:
        return const Color(0xFFFFF1D6);
      case 1:
        return const Color(0xFFE1ECFF);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  Color _getPriorityForeground(int priority) {
    switch (priority) {
      case 3:
        return const Color(0xFFE11D48);
      case 2:
        return const Color(0xFFD97706);
      case 1:
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF6B7280);
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

  bool _isOverdue(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    return taskDate.isBefore(today) && !task.isCompleted;
  }

  Future<void> _toggleComplete(WidgetRef ref, Task task) async {
    final isar = await ref.read(isarProvider.future);
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
        debugPrint('Failed to create next task: $e');
      }
    } else {
      await dao.updateTask(task.copyWith(isCompleted: !task.isCompleted));
    }

    await NotificationService().cancelTaskReminder(task);
  }

  Widget _buildMetaChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = color ?? colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: foreground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final overdue = _isOverdue(task.dueDate);

    return Opacity(
      opacity: task.isCompleted ? 0.72 : 1,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.65)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: GestureDetector(
                    onTap: () => _toggleComplete(ref, task),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: task.isCompleted
                              ? colorScheme.primary
                              : colorScheme.outline,
                          width: 2,
                        ),
                        color: task.isCompleted
                            ? colorScheme.primary
                            : colorScheme.surface,
                      ),
                      child: task.isCompleted
                          ? Icon(Icons.check_rounded,
                              size: 17, color: colorScheme.onPrimary)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: task.isCompleted
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.onSurface,
                                  ),
                            ),
                          ),
                          if (task.priority > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getPriorityBackground(task.priority),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _getPriorityLabel(task.priority),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getPriorityForeground(task.priority),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (task.description != null && task.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            task.description!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (task.dueDate != null)
                              _buildMetaChip(
                                context: context,
                                icon: Icons.calendar_today_rounded,
                                label: _formatDate(task.dueDate),
                                color: overdue ? colorScheme.error : null,
                              ),
                            if (task.groupName != null)
                              _buildMetaChip(
                                context: context,
                                icon: Icons.folder_rounded,
                                label: task.groupName!,
                              ),
                            if (task.rrule != null)
                              _buildMetaChip(
                                context: context,
                                icon: Icons.repeat_rounded,
                                label: '重复',
                                color: colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                      if (task.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ...task.tags.take(3).map(
                                    (tag) => Chip(
                                      label: Text(
                                        tag,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      backgroundColor: colorScheme.primaryContainer
                                          .withValues(alpha: 0.4),
                                      side: BorderSide.none,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                              if (task.tags.length > 3)
                                Chip(
                                  label: Text(
                                    '+${task.tags.length - 3}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                  side: BorderSide.none,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
