import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../models/filter.dart';
import '../data/task_dao.dart';
import 'isar_provider.dart';

final activeTasksProvider = StreamProvider<List<Task>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.when(
    data: (isarInstance) {
      final dao = TaskDao(isarInstance);
      return dao.watchAllActiveTasks();
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

final filterConditionProvider = StateProvider<TaskFilter>((ref) {
  return TaskFilter();
});

final filteredTasksProvider = Provider<List<Task>>((ref) {
  final asyncTasks = ref.watch(activeTasksProvider);
  final filter = ref.watch(filterConditionProvider);

  return asyncTasks.when(
    data: (tasks) {
      return tasks.where((task) {
        final matchGroup = filter.selectedGroup == null || task.groupName == filter.selectedGroup;
        final matchPriority = filter.selectedPriority == null || task.priority == filter.selectedPriority;
        final matchTag = filter.selectedTag == null || task.tags.contains(filter.selectedTag);
        return matchGroup && matchPriority && matchTag;
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

final urgentImportantTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(filteredTasksProvider);
  return tasks.where((task) => task.priority == 3 && !task.isCompleted).toList();
});

final importantNotUrgentTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(filteredTasksProvider);
  return tasks.where((task) => task.priority == 2 && !task.isCompleted).toList();
});

final urgentNotImportantTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(filteredTasksProvider);
  return tasks.where((task) => task.priority == 1 && !task.isCompleted).toList();
});

final notUrgentNotImportantTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(filteredTasksProvider);
  return tasks.where((task) => task.priority == 0 && !task.isCompleted).toList();
});

final tasksByDayProvider = Provider<Map<String, List<Task>>>((ref) {
  final tasks = ref.watch(filteredTasksProvider);
  final activeTasks = tasks.where((t) => !t.isCompleted && t.dueDate != null).toList();
  
  Map<String, List<Task>> groupedTasks = {};
  
  for (var task in activeTasks) {
    final dateKey = task.dueDate!.toIso8601String().split('T')[0];
    if (!groupedTasks.containsKey(dateKey)) {
      groupedTasks[dateKey] = [];
    }
    groupedTasks[dateKey]!.add(task);
  }
  
  return Map.fromEntries(
    groupedTasks.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
  );
});

final allGroupsProvider = Provider<List<String>>((ref) {
  final asyncTasks = ref.watch(activeTasksProvider);
  
  return asyncTasks.when(
    data: (tasks) {
      final groups = <String>{};
      for (final task in tasks) {
        if (task.groupName != null) {
          groups.add(task.groupName!);
        }
      }
      return groups.toList()..sort();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

final allTagsProvider = Provider<List<String>>((ref) {
  final asyncTasks = ref.watch(activeTasksProvider);

  return asyncTasks.when(
    data: (tasks) {
      final tags = <String>{};
      for (final task in tasks) {
        for (final tag in task.tags) {
          if (tag.isNotEmpty) tags.add(tag);
        }
      }
      return tags.toList()..sort();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});