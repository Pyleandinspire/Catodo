import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/task_providers.dart';
import '../../models/task.dart';
import 'task_form_screen.dart';

class _QuadrantData {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Task> tasks;
  final Color color;
  final Color bgColor;

  const _QuadrantData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tasks,
    required this.color,
    required this.bgColor,
  });
}

class EisenhowerScreen extends ConsumerWidget {
  const EisenhowerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(filteredTasksProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final urgentImportant = <Task>[];
    final notUrgentImportant = <Task>[];
    final urgentNotImportant = <Task>[];
    final notUrgentNotImportant = <Task>[];

    for (final task in tasks) {
      if (task.isCompleted) continue;

      final isUrgent = task.dueDate != null &&
          task.dueDate!.isBefore(DateTime.now().add(const Duration(days: 2)));
      final isImportant = task.priority >= 2;

      if (isUrgent && isImportant) {
        urgentImportant.add(task);
      } else if (!isUrgent && isImportant) {
        notUrgentImportant.add(task);
      } else if (isUrgent && !isImportant) {
        urgentNotImportant.add(task);
      } else {
        notUrgentNotImportant.add(task);
      }
    }

    final quadrants = [
      _QuadrantData(
        title: '紧急且重要',
        subtitle: '立即处理',
        icon: Icons.priority_high_rounded,
        tasks: urgentImportant,
        color: const Color(0xFFE11D48),
        bgColor: const Color(0xFFFFF1F2),
      ),
      _QuadrantData(
        title: '不紧急但重要',
        subtitle: '规划时间',
        icon: Icons.event_available_rounded,
        tasks: notUrgentImportant,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFF7ED),
      ),
      _QuadrantData(
        title: '紧急但不重要',
        subtitle: '授权或快速处理',
        icon: Icons.flash_on_rounded,
        tasks: urgentNotImportant,
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
      ),
      _QuadrantData(
        title: '不紧急不重要',
        subtitle: '尽量避免',
        icon: Icons.spa_rounded,
        tasks: notUrgentNotImportant,
        color: const Color(0xFF64748B),
        bgColor: const Color(0xFFF8FAFC),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '四象限',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '按紧急和重要性安排任务',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.dashboard_customize_rounded,
                            size: 70,
                            color: colorScheme.primary.withValues(alpha: 0.22),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '暂无任务',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '添加任务后会自动出现在对应象限',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final useGrid = constraints.maxWidth >= 700;
                        if (useGrid) {
                          return GridView.count(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                            crossAxisCount: 2,
                            childAspectRatio: 1.35,
                            children: quadrants
                                .map((q) => _buildQuadrant(context, q))
                                .toList(),
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                          children: quadrants
                              .map(
                                (q) => SizedBox(
                                  height: 320,
                                  child: _buildQuadrant(context, q),
                                ),
                              )
                              .toList(),
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
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildQuadrant(BuildContext context, _QuadrantData quadrant) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: quadrant.bgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: quadrant.color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: quadrant.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(quadrant.icon, color: quadrant.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quadrant.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: quadrant.color,
                            ),
                      ),
                      Text(
                        quadrant.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: quadrant.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${quadrant.tasks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: quadrant.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: quadrant.tasks.isEmpty
                ? Center(
                    child: Text(
                      '暂无任务',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    itemCount: quadrant.tasks.length,
                    itemBuilder: (context, index) {
                      final task = quadrant.tasks[index];
                      return Card(
                        elevation: 0,
                        color: colorScheme.surface,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                          ),
                        ),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TaskFormScreen(task: task),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onSurface,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (task.dueDate != null) ...[
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 13,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '截止 ${task.dueDate!.month}/${task.dueDate!.day}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
