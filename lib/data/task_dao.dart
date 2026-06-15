import 'package:isar/isar.dart';
import '../models/task.dart';

/// 任务仓储接口；TaskDao 是 Isar 实现，测试可注入内存版。
abstract class TaskRepository {
  Future<Task?> getTaskById(int id);
  Future<Task> insertTask(Task task);
  Future<Task> updateTask(Task task);
  Future<void> softDeleteTask(int id);
}

class TaskDao implements TaskRepository {
  final Isar isar;

  TaskDao(this.isar);

  @override
  Future<Task> insertTask(Task task) async {
    task.createdAt = DateTime.now();
    task.updatedAt = DateTime.now();
    task.isDeleted = false;
    await isar.writeTxn(() async {
      await isar.tasks.put(task);
    });
    return task;
  }

  @override
  Future<Task?> getTaskById(int id) async {
    return await isar.tasks.get(id);
  }

  Future<List<Task>> getAllTasks() async {
    return await isar.tasks.where().findAll();
  }

  Future<List<Task>> getAllActiveTasks() async {
    return await isar.tasks
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
  }

  Future<List<Task>> getActiveTasksByPriority(int priority) async {
    return await isar.tasks
        .filter()
        .isDeletedEqualTo(false)
        .priorityEqualTo(priority)
        .findAll();
  }

  Future<List<Task>> getActiveTasksByGroup(String groupName) async {
    return await isar.tasks
        .filter()
        .isDeletedEqualTo(false)
        .groupNameEqualTo(groupName)
        .findAll();
  }

  Future<List<Task>> getActiveTasksWithTag(String tag) async {
    final allTasks = await getAllActiveTasks();
    return allTasks.where((task) => task.tags.contains(tag)).toList();
  }

  @override
  Future<Task> updateTask(Task task) async {
    task.updatedAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.tasks.put(task);
    });
    return task;
  }

  @override
  Future<void> softDeleteTask(int id) async {
    final task = await isar.tasks.get(id);
    if (task != null) {
      task.isDeleted = true;
      task.updatedAt = DateTime.now();
      await isar.writeTxn(() async {
        await isar.tasks.put(task);
      });
    }
  }

  Future<void> hardDeleteTask(int id) async {
    await isar.writeTxn(() async {
      await isar.tasks.delete(id);
    });
  }

  Stream<List<Task>> watchAllActiveTasks() {
    return isar.tasks
        .filter()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true);
  }

  Stream<List<Task>> watchActiveTasksByPriority(int priority) {
    return isar.tasks
        .filter()
        .isDeletedEqualTo(false)
        .priorityEqualTo(priority)
        .watch(fireImmediately: true);
  }
}