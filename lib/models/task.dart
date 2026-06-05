import 'package:isar/isar.dart';

part 'task.g.dart';

@collection
class Task {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String title;

  String? description;

  @Index()
  late bool isCompleted;

  @Index()
  late int priority;

  @Index()
  DateTime? dueDate;

  List<String> tags = [];

  String? groupName;

  String? rrule;
  bool isRepeatParent = false;

  @Index()
  late DateTime createdAt;
  late DateTime updatedAt;
  late bool isDeleted;

  List<DateTime> reminderTimes = [];

  Task({
    required this.title,
    this.description,
    this.isCompleted = false,
    this.priority = 0,
    this.dueDate,
    List<String> tags = const [],
    this.groupName,
    this.rrule,
    this.isRepeatParent = false,
    List<DateTime> reminderTimes = const [],
  })  : reminderTimes = List.from(reminderTimes) {
    this.createdAt = DateTime.now();
    this.updatedAt = DateTime.now();
    this.isDeleted = false;
  }

  Task copyWith({
    String? title,
    String? description,
    bool? isCompleted,
    int? priority,
    DateTime? dueDate,
    List<String>? tags,
    String? groupName,
    String? rrule,
    bool? isRepeatParent,
    List<DateTime>? reminderTimes,
    DateTime? updatedAt,
  }) {
    return Task(
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      tags: tags ?? this.tags,
      groupName: groupName ?? this.groupName,
      rrule: rrule ?? this.rrule,
      isRepeatParent: isRepeatParent ?? this.isRepeatParent,
      reminderTimes: reminderTimes ?? this.reminderTimes,
    )
      ..id = id
      ..createdAt = createdAt
      ..updatedAt = updatedAt ?? DateTime.now()
      ..isDeleted = isDeleted;
  }
}