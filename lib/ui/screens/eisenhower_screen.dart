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

    // 按艾森豪威尔矩阵分组
    List<Task> urgentImportant = [];
    List<Task> notUrgentImportant = [];
    List<Task> urgentNotImportant = [];
    List<Task> notUrgentNotImportant = [];

    for (final task in tasks) {
      if (task.isCompleted) continue;
      
      bool isUrgent = task.dueDate != null && task.dueDate!.isBefore(DateTime.now().add(const Duration(days: 2)));
      bool isImportant = task.priority >= 2;

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

    Widget _buildQuadrant({
      required String title,
      required String subtitle,
      required List<Task> tasks,
      required Color color,
      required Color bgColor,
    }) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          '暂无任务',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TaskFormScreen(task: task),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (task.dueDate != null)
                                      Text(
                                        '截止: ${task.dueDate!.month}/${task.dueDate!.day}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (tasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${tasks.length} 个任务',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
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
                    '艾森豪威尔矩阵',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '按紧急和重要性分类',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // 矩阵网格
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.grid_3x3,
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
                  : Column(
                      children: [
                        // 第一行：重要
                        Expanded(
                          child: Row(
                            children: [
                              _buildQuadrant(
                                title: '紧急且重要',
                                subtitle: '立即处理',
                                tasks: urgentImportant,
                                color: Colors.red,
                                bgColor: Colors.red[50]!,
                              ),
                              _buildQuadrant(
                                title: '不紧急但重要',
                                subtitle: '规划时间',
                                tasks: notUrgentImportant,
                                color: Colors.orange,
                                bgColor: Colors.orange[50]!,
                              ),
                            ],
                          ),
                        ),
                        // 第二行：不重要
                        Expanded(
                          child: Row(
                            children: [
                              _buildQuadrant(
                                title: '紧急但不重要',
                                subtitle: '授权他人',
                                tasks: urgentNotImportant,
                                color: Colors.blue,
                                bgColor: Colors.blue[50]!,
                              ),
                              _buildQuadrant(
                                title: '不紧急不重要',
                                subtitle: '尽量避免',
                                tasks: notUrgentNotImportant,
                                color: Colors.grey,
                                bgColor: Colors.grey[100]!,
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