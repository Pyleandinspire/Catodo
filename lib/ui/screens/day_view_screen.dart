import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/task_item.dart';
import '../../providers/task_providers.dart';
import '../../providers/day_view_provider.dart';
import '../../models/task.dart';
import 'task_form_screen.dart';

class DayViewScreen extends ConsumerWidget {
  const DayViewScreen({super.key});

  String _formatDateHeader(DateTime date) {
    if (date.year == 9999) return '无截止日期';

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

  String _modeLabel(DayViewMode m) {
    switch (m) {
      case DayViewMode.all:
        return '全部';
      case DayViewMode.focusToday:
        return '专注今日';
      case DayViewMode.hideOverdue:
        return '隐藏过期';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(filteredTasksProvider);
    final mode = ref.watch(dayViewModeProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 按模式过滤
    List<Task> filteredTasks = allTasks.toList();
    switch (mode) {
      case DayViewMode.all:
        break;
      case DayViewMode.focusToday:
        filteredTasks = filteredTasks.where((t) {
          if (t.dueDate == null) return false;
          return DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day) == today;
        }).toList();
        break;
      case DayViewMode.hideOverdue:
        filteredTasks = filteredTasks.where((t) {
          if (t.dueDate == null) return true;
          final dueDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
          return !dueDay.isBefore(today);
        }).toList();
        break;
    }

    // 排序：未完成任务在前，已完成任务排到最底部
    filteredTasks.sort((a, b) {
      if (a.isCompleted && !b.isCompleted) return 1;
      if (!a.isCompleted && b.isCompleted) return -1;
      return 0;
    });

    // 按日期分组
    Map<DateTime, List<Task>> groupedTasks = {};
    for (final task in filteredTasks) {
      if (task.dueDate != null) {
        final dateKey = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
        groupedTasks.putIfAbsent(dateKey, () => []).add(task);
      } else {
        final noDateKey = DateTime(9999);
        groupedTasks.putIfAbsent(noDateKey, () => []).add(task);
      }
    }

    final sortedDates = groupedTasks.keys.toList()
      ..sort((a, b) {
        if (a.year == 9999) return 1;
        if (b.year == 9999) return -1;

        final aIsOverdue = a.isBefore(today);
        final bIsOverdue = b.isBefore(today);

        if (aIsOverdue && !bIsOverdue) return -1;
        if (!aIsOverdue && bIsOverdue) return 1;

        if (aIsOverdue && bIsOverdue) {
          return b.compareTo(a);
        }

        return a.compareTo(b);
      });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '按天视图 · ${filteredTasks.length}个任务',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          PopupMenuButton<DayViewMode>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _modeLabel(mode),
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.black87),
              ],
            ),
            onSelected: (selectedMode) {
              ref.read(dayViewModeProvider.notifier).setMode(selectedMode);
            },
            itemBuilder: (context) => DayViewMode.values.map((m) {
              return PopupMenuItem(
                value: m,
                child: Text(
                  _modeLabel(m),
                  style: TextStyle(
                    fontWeight: mode == m ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: filteredTasks.isEmpty
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
    );
  }
}