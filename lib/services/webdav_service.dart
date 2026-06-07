import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';

class WebDAVConfig {
  String url;
  String username;
  String password;

  WebDAVConfig({this.url = '', this.username = '', this.password = ''});

  bool get isValid =>
      url.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'url': url,
    'username': username,
    'password': password,
  };

  factory WebDAVConfig.fromJson(Map<String, dynamic> json) => WebDAVConfig(
    url: json['url'] ?? '',
    username: json['username'] ?? '',
    password: json['password'] ?? '',
  );
}

enum SyncStatus { idle, syncing, synced, failed }

enum SyncMode { autoMerge, localFirst, remoteFirst }

class SyncResult {
  final SyncStatus status;
  final int uploadedCount;
  final int downloadedCount;
  final String? error;
  final List<Task> mergedTasks;

  SyncResult({
    required this.status,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.error,
    this.mergedTasks = const [],
  });
}

class WebDAVService {
  final WebDAVConfig config;
  final Dio _dio;

  WebDAVService(this.config)
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            if (config.username.isNotEmpty && config.password.isNotEmpty)
              'Authorization':
                  'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}',
          },
        ),
      );

  /// 旧格式文件名（保留兼容）
  String get _oldTasksFileName => 'Catodo/catodo_tasks.json';

  /// 新格式文件名（catodo 完整格式）
  String get _newTasksFileName => 'Catodo/catodo_full.catodo';

  String buildUrl(String path) {
    final baseUrl = config.url.endsWith('/')
        ? config.url.substring(0, config.url.length - 1)
        : config.url;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$cleanPath';
  }

  Future<bool> testConnection() async {
    try {
      final response = await _dio.request(
        buildUrl('/'),
        options: Options(method: 'PROPFIND', headers: {'Depth': '0'}),
      );
      return response.statusCode == 207 || response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('WebDAV 连接测试失败: ${e.message}');
      debugPrint('  请求 URL: ${buildUrl('/')}');
      return false;
    } catch (e) {
      debugPrint('WebDAV 连接异常: $e');
      return false;
    }
  }

  Future<bool> _createDirectory(String path) async {
    final url = buildUrl(path);
    try {
      final response = await _dio.request(
        url,
        options: Options(
          method: 'MKCOL',
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode == 201 ||
          response.statusCode == 204 ||
          response.statusCode == 405) {
        return true;
      }
      debugPrint('WebDAV 创建目录失败: 状态码 ${response.statusCode}');
      debugPrint('  请求 URL: $url');
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 405) {
        return true;
      }
      debugPrint('WebDAV 创建目录失败: ${e.message}');
      debugPrint('  请求 URL: $url');
      debugPrint('  状态码: ${e.response?.statusCode}');
      return false;
    } catch (e) {
      debugPrint('WebDAV 创建目录异常: $e');
      debugPrint('  请求 URL: $url');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _downloadFile(String fileName) async {
    final url = buildUrl('/$fileName');
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.data) as Map<String, dynamic>;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      debugPrint('WebDAV 下载失败: ${e.message}');
      debugPrint('  请求 URL: $url');
      debugPrint('  状态码: ${e.response?.statusCode}');
    } catch (e) {
      debugPrint('WebDAV 下载异常: $e');
      debugPrint('  请求 URL: $url');
    }
    return null;
  }

  Future<bool> _uploadFile(String fileName, Map<String, dynamic> data) async {
    final url = buildUrl('/$fileName');
    try {
      await _createDirectory('/Catodo');

      final response = await _dio.put(
        url,
        data: jsonEncode(data),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return true;
      }
      debugPrint('WebDAV 上传失败: 状态码 ${response.statusCode}');
      debugPrint('  请求 URL: $url');
      return false;
    } on DioException catch (e) {
      debugPrint('WebDAV 上传失败: ${e.message}');
      debugPrint('  请求 URL: $url');
      debugPrint('  状态码: ${e.response?.statusCode}');
      return false;
    } catch (e) {
      debugPrint('WebDAV 上传异常: $e');
      debugPrint('  请求 URL: $url');
      return false;
    }
  }

  /// 下载远程任务数据：优先读新格式，不存在则回退读旧格式
  Future<Map<String, dynamic>?> _downloadTasks() async {
    final newData = await _downloadFile(_newTasksFileName);
    if (newData != null) return newData;
    // 回退读旧格式
    return await _downloadFile(_oldTasksFileName);
  }

  /// 上传任务数据：新旧格式都写，保证兼容
  Future<bool> _uploadTasksBoth(Map<String, dynamic> data) async {
    final newResult = await _uploadFile(_newTasksFileName, data);
    // 旧格式也写一份（仅 tasks 部分）
    final oldData = {'tasks': data['tasks']};
    await _uploadFile(_oldTasksFileName, oldData);
    return newResult;
  }

  Future<SyncResult> sync(
    List<Task> localTasks, {
    SyncMode mode = SyncMode.autoMerge,
  }) async {
    try {
      // 为没有 syncId 的任务生成 syncId（数据迁移）
      for (final task in localTasks) {
        task.syncId ??= const Uuid().v4();
      }

      final remoteData = await _downloadTasks();

      if (remoteData == null) {
        // 首次同步：上传所有本地任务
        final data = _tasksToJson(localTasks);
        final success = await _uploadTasksBoth(data);
        return SyncResult(
          status: success ? SyncStatus.synced : SyncStatus.failed,
          uploadedCount: success ? localTasks.length : 0,
          error: success ? null : '上传失败',
          mergedTasks: localTasks,
        );
      }

      // 增量同步
      final remoteTasks = _jsonToTasks(remoteData);
      int uploadedCount = 0;
      int downloadedCount = 0;

      final remoteMap = <String, Task>{};
      for (final t in remoteTasks) {
        if (t.syncId != null) {
          remoteMap[t.syncId!] = t;
        }
      }
      final localMap = <String, Task>{};
      for (final t in localTasks) {
        if (t.syncId != null) {
          localMap[t.syncId!] = t;
        }
      }

      final mergedTasks = <Task>[];

      for (final task in localTasks) {
        final remoteTask = task.syncId != null ? remoteMap[task.syncId] : null;
        if (remoteTask == null) {
          mergedTasks.add(task);
          uploadedCount++;
        } else {
          final winner = _resolveConflict(task, remoteTask, mode);
          mergedTasks.add(winner);
          if (identical(winner, task)) {
            uploadedCount++;
          } else {
            downloadedCount++;
          }
        }
      }

      for (final remoteTask in remoteTasks) {
        final exists =
            remoteTask.syncId != null &&
            localMap.containsKey(remoteTask.syncId);
        if (!exists) {
          mergedTasks.add(remoteTask);
          downloadedCount++;
        }
      }

      // 过滤双方都删除的任务（不再上传到云端）
      mergedTasks.removeWhere((t) {
        if (t.syncId == null) return false;
        final local = localMap[t.syncId];
        final remote = remoteMap[t.syncId];
        return local != null &&
            remote != null &&
            local.isDeleted &&
            remote.isDeleted;
      });

      final data = _tasksToJson(mergedTasks);
      final uploadSuccess = await _uploadTasksBoth(data);

      return SyncResult(
        status: uploadSuccess ? SyncStatus.synced : SyncStatus.failed,
        uploadedCount: uploadedCount,
        downloadedCount: downloadedCount,
        error: uploadSuccess ? null : '上传合并结果失败',
        mergedTasks: mergedTasks,
      );
    } catch (e) {
      return SyncResult(status: SyncStatus.failed, error: e.toString());
    }
  }

  /// 根据同步模式解决冲突（含软删除处理）
  Task _resolveConflict(Task local, Task remote, SyncMode mode) {
    // 软删除优先处理：任一方删除即传播删除
    if (local.isDeleted || remote.isDeleted) {
      final deleted = local.isDeleted ? local : remote;
      deleted.isDeleted = true;
      return deleted;
    }

    // 双方都未删除 → 按原有模式处理
    switch (mode) {
      case SyncMode.autoMerge:
        return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
      case SyncMode.localFirst:
        return local;
      case SyncMode.remoteFirst:
        return remote;
    }
  }

  /// 测试辅助：公开 _tasksToJson
  @visibleForTesting
  Map<String, dynamic> tasksToJsonTest(List<Task> tasks) => _tasksToJson(tasks);

  /// 测试辅助：公开 _jsonToTasks
  @visibleForTesting
  List<Task> jsonToTasksTest(Map<String, dynamic> json) => _jsonToTasks(json);

  /// 测试辅助：公开 _resolveConflict
  @visibleForTesting
  Task resolveConflictTest(Task local, Task remote, SyncMode mode) =>
      _resolveConflict(local, remote, mode);

  Future<List<Task>> downloadTasks() async {
    final data = await _downloadTasks();
    if (data == null) return [];
    return _jsonToTasks(data);
  }

  Map<String, dynamic> _tasksToJson(List<Task> tasks) {
    return {
      'tasks': tasks
          .map(
            (t) => {
              'id': t.id,
              'syncId': t.syncId,
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
              'reminderTimes': t.reminderTimes
                  .map((dt) => dt.toIso8601String())
                  .toList(),
            },
          )
          .toList(),
    };
  }

  List<Task> _jsonToTasks(Map<String, dynamic> json) {
    final taskList = json['tasks'] as List<dynamic>? ?? [];
    return taskList.map((t) {
      final task =
          Task(
              title: t['title'] ?? '',
              description: t['description'],
              isCompleted: t['isCompleted'] ?? false,
              priority: t['priority'] ?? 0,
              dueDate: t['dueDate'] != null
                  ? DateTime.parse(t['dueDate'])
                  : null,
              tags: List<String>.from(t['tags'] ?? []),
              groupName: t['groupName'],
              syncId: t['syncId'] as String?,
              rrule: t['rrule'],
              isRepeatParent: t['isRepeatParent'] ?? false,
              reminderTimes:
                  (t['reminderTimes'] as List<dynamic>?)
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
    }).toList();
  }
}
