import 'package:isar/isar.dart';
import '../models/task.dart';

class TaskDao {
  final Isar isar;

  TaskDao(this.isar);

  Future<Task> insertTask(Task task) async {
    task.createdAt = DateTime.now();
    task.updatedAt = DateTime.now();
    task.isDeleted = false;
    await isar.writeTxn(() async {
      await isar.tasks.put(task);
    });
    return task;
  }

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

  Future<Task> updateTask(Task task) async {
    task.updatedAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.tasks.put(task);
    });
    return task;
  }

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