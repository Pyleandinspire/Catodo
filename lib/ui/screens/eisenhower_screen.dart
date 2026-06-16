import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/task_providers.dart';
import '../../models/task.dart';
import 'task_form_screen.dart';

class EisenhowerScreen extends ConsumerWidget {
  const EisenhowerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(filteredTasksProvider);

    List<Task> urgentImportant = [];
    List<Task> notUrgentImportant = [];
    List<Task> urgentNotImportant = [];
    List<Task> notUrgentNotImportant = [];

    for (final task in tasks) {
      if (task.isCompleted) continue;
      bool isUrgent = task.dueDate != null && task.dueDate!.isBefore(DateTime.now().add(const Duration(days: 2)));
      bool isImportant = task.priority >= 2;
      if (isUrgent && isImportant) { urgentImportant.add(task); }
      else if (!isUrgent && isImportant) { notUrgentImportant.add(task); }
      else if (isUrgent && !isImportant) { urgentNotImportant.add(task); }
      else { notUrgentNotImportant.add(task); }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('艾森豪威尔矩阵', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(children: [
                Expanded(child: Row(children: [
                  Expanded(child: _quadrant(context, '重要·紧急', '重要·紧急', urgentImportant, const Color(0xFFFFE0DB))),
                  Expanded(child: _quadrant(context, '重要·不紧急', '重要·不紧急', notUrgentImportant, const Color(0xFFEDE7FE))),
                ])),
                const Divider(height: 1),
                Expanded(child: Row(children: [
                  Expanded(child: _quadrant(context, '紧急·不重要', '紧急·不重要', urgentNotImportant, const Color(0xFFFFF2CC))),
                  Expanded(child: _quadrant(context, '不重要·不紧急', '不重要·不紧急', notUrgentNotImportant, const Color(0xFFF5F5F5))),
                ])),
              ]),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _quadrant(BuildContext context, String title, String subtitle, List<Task> tasks, Color bg) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (tasks.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Colors.black.withAlpha(15), borderRadius: BorderRadius.circular(8)),
                child: Text('${tasks.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        Expanded(
          child: tasks.isEmpty
              ? Center(child: Text('暂无', style: TextStyle(fontSize: 12, color: Colors.grey.withAlpha(100))))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: tasks.length,
                  itemBuilder: (_, i) {
                    final t = tasks[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskFormScreen(task: t))),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withAlpha(179), borderRadius: BorderRadius.circular(10)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (t.dueDate != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text('${t.dueDate!.month}/${t.dueDate!.day}', style: const TextStyle(fontSize: 11, color: Color(0xFF757575)))),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
