import 'dart:convert';
import '../models/task.dart';

class CatodoExportData {
  final String version;
  final String exportedAt;
  final List<Task> tasks;
  final Map<String, dynamic> settings;

  CatodoExportData({
    required this.version,
    required this.exportedAt,
    required this.tasks,
    required this.settings,
  });
}

class CatodoIOService {
  CatodoIOService._();

  static const currentVersion = '1.0';

  /// 验证版本号是否兼容
  static bool validateVersion(String version) {
    try {
      final major = int.parse(version.split('.').first);
      final currentMajor = int.parse(currentVersion.split('.').first);
      return major == currentMajor;
    } catch (_) {
      return false;
    }
  }

  /// 导出为 .catodo JSON 格式
  static String exportCatodo({
    required List<Task> tasks,
    required Map<String, dynamic> settings,
    bool includeSensitive = false,
  }) {
    final safeSettings = <String, dynamic>{};

    // WebDAV 设置
    if (settings['webdav'] != null) {
      final wd = Map<String, dynamic>.from(settings['webdav'] as Map);
      if (!includeSensitive) {
        wd.remove('password');
      }
      safeSettings['webdav'] = wd;
    }

    // AI 设置
    if (settings['ai'] != null) {
      final ai = Map<String, dynamic>.from(settings['ai'] as Map);
      if (!includeSensitive) {
        ai.remove('apiKey');
      }
      safeSettings['ai'] = ai;
    }

    final data = {
      'version': currentVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': tasks.map((t) => _taskToJson(t)).toList(),
      'settings': safeSettings,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 导入 .catodo JSON 格式，返回解析后的数据
  static CatodoExportData importCatodo(String content) {
    final json = jsonDecode(content) as Map<String, dynamic>;

    final version = json['version'] as String? ?? '0.0';
    if (!validateVersion(version)) {
      throw FormatException(
        '不兼容的数据格式版本: $version，当前支持版本: $currentVersion.x',
      );
    }

    final taskList = json['tasks'] as List<dynamic>? ?? [];
    final tasks = taskList.map((t) {
      final task = _jsonToTask(t as Map<String, dynamic>);
      // 追加模式：重置 id，让数据库自动分配
      task.id = 0;
      return task;
    }).toList();

    final settings = json['settings'] as Map<String, dynamic>? ?? {};

    return CatodoExportData(
      version: version,
      exportedAt: json['exportedAt'] as String? ?? '',
      tasks: tasks,
      settings: settings,
    );
  }

  static Map<String, dynamic> _taskToJson(Task t) {
    return {
      'title': t.title,
      'description': t.description,
      'isCompleted': t.isCompleted,
      'priority': t.priority,
      'dueDate': t.dueDate?.toIso8601String(),
      'tags': t.tags,
      'groupName': t.groupName,
      'rrule': t.rrule,
      'isRepeatParent': t.isRepeatParent,
      'createdAt': t.createdAt.toIso8601String(),
      'updatedAt': t.updatedAt.toIso8601String(),
      'isDeleted': t.isDeleted,
      'reminderTimes':
          t.reminderTimes.map((dt) => dt.toIso8601String()).toList(),
    };
  }

  static Task _jsonToTask(Map<String, dynamic> t) {
    final task = Task(
      title: t['title'] ?? '',
      description: t['description'],
      isCompleted: t['isCompleted'] ?? false,
      priority: t['priority'] ?? 0,
      dueDate: t['dueDate'] != null ? DateTime.parse(t['dueDate']) : null,
      tags: List<String>.from(t['tags'] ?? []),
      groupName: t['groupName'],
      rrule: t['rrule'],
      isRepeatParent: t['isRepeatParent'] ?? false,
      reminderTimes: (t['reminderTimes'] as List<dynamic>?)
              ?.map((dt) => DateTime.parse(dt.toString()))
              .toList() ??
          [],
    )
      ..id = t['id'] ?? 0
      ..createdAt = t['createdAt'] != null
          ? DateTime.parse(t['createdAt'])
          : DateTime.now()
      ..updatedAt = t['updatedAt'] != null
          ? DateTime.parse(t['updatedAt'])
          : DateTime.now()
      ..isDeleted = t['isDeleted'] ?? false;
    return task;
  }
}