import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task.dart';
import '../../services/notification_service.dart';
import '../../services/repeat_task_service.dart';
import '../../data/task_dao.dart';
import '../../providers/isar_provider.dart';
import '../icons/app_icons.dart';
import 'app_due_pill.dart';

class TaskItem extends ConsumerWidget {
  final Task task;
  final VoidCallback onTap;
  final void Function(Task)? onHeartTap;
  const TaskItem({super.key, required this.task, required this.onTap, this.onHeartTap});

  static const _comfortPhrases = ['需要安慰', '聊聊吧', '有点焦虑', '求助 AI', '帮帮我'];
  String get _comfortText => _comfortPhrases[DateTime.now().millisecondsSinceEpoch % _comfortPhrases.length];

  bool _isOverdue(Task t) {
    if (t.isCompleted || t.dueDate == null) return false;
    final now = DateTime.now();
    return t.dueDate!.isBefore(DateTime(now.year, now.month, now.day));
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
      } catch (e) { debugPrint('Failed to create next task: $e'); }
    } else {
      await dao.updateTask(task.copyWith(isCompleted: !task.isCompleted));
    }
    await NotificationService().cancelTaskReminder(task);
  }

  Color _getPriorityColor(int priority) {
    switch (priority) { case 3: return Colors.redAccent; case 2: return Colors.orangeAccent; case 1: return Colors.blueAccent; default: return Colors.grey; }
  }

  String _getPriorityLabel(int priority) {
    switch (priority) { case 3: return '高'; case 2: return '中'; case 1: return '低'; default: return ''; }
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
    if (diff > 0 && diff < 7) { const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日']; return weekdays[taskDate.weekday]; }
    return '${date.month}/${date.day}';
  }

  Widget _priorityChip(Color c, String l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withAlpha(30), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        Text(l, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = task;
    final isCompleted = t.isCompleted;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左侧优先级色条
              if (task.priority >= 1)
                Container(width: 4, color: _getPriorityColor(task.priority).withAlpha(180)),
              // 内容区
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 圆形勾选框
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: GestureDetector(
                          onTap: () => _toggleComplete(ref, t),
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: isCompleted ? Colors.green : onSurfaceVariant, width: 2),
                              color: isCompleted ? Colors.green : Colors.transparent,
                            ),
                            child: isCompleted ? const Icon(AppIcons.check, size: 16, color: Colors.white) : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(t.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, decoration: isCompleted ? TextDecoration.lineThrough : null, color: isCompleted ? onSurfaceVariant : onSurface))),
                            if (task.priority > 0) Padding(padding: const EdgeInsets.only(left: 6), child: _priorityChip(_getPriorityColor(task.priority), _getPriorityLabel(task.priority))),
                          ]),
                          if (t.description != null && t.description!.isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 4), child: Text(t.description!, style: TextStyle(fontSize: 14, color: onSurfaceVariant, decoration: isCompleted ? TextDecoration.lineThrough : null), maxLines: 2, overflow: TextOverflow.ellipsis)),
                          Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
                            if (t.dueDate != null) AppDuePill(dueDate: t.dueDate),
                            // 逾期任务情绪支持按钮
                            if (_isOverdue(t) && onHeartTap != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Material(
                                  elevation: 3,
                                  borderRadius: BorderRadius.circular(14),
                                  color: const Color(0xFFFFE0DB),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => onHeartTap!(t),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFFCDD2).withAlpha(100),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _comfortText,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE53935)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (t.dueDate != null && t.groupName != null) const SizedBox(width: 12),
                            if (t.groupName != null) ...[Icon(AppIcons.folder, size: 14, color: onSurfaceVariant), const SizedBox(width: 4), Text(t.groupName!, style: TextStyle(fontSize: 13, color: onSurfaceVariant))],
                            if (t.rrule != null) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(AppIcons.repeat, size: 14, color: Colors.blue)),
                          ])),
                          if (t.tags.isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, runSpacing: 4, children: [
                              ...t.tags.take(3).map((tag) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey.withAlpha(25), borderRadius: BorderRadius.circular(999)), child: Text(tag, style: const TextStyle(fontSize: 11)))),
                              if (t.tags.length > 3) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey.withAlpha(50), borderRadius: BorderRadius.circular(999)), child: Text('+${t.tags.length - 3}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                            ])),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
