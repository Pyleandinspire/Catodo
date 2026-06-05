import 'dart:convert';
import 'package:dio/dio.dart';
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

class SyncResult {
  final SyncStatus status;
  final int uploadedCount;
  final int downloadedCount;
  final String? error;

  SyncResult({
    required this.status,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.error,
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

  String get _tasksFileName => 'Catodo/catodo_tasks.json';

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
      print('WebDAV 连接测试失败: ${e.message}');
      print('  请求 URL: ${buildUrl('/')}');
      return false;
    } catch (e) {
      print('WebDAV 连接异常: $e');
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
      print('WebDAV 创建目录失败: 状态码 ${response.statusCode}');
      print('  请求 URL: $url');
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 405) {
        return true;
      }
      print('WebDAV 创建目录失败: ${e.message}');
      print('  请求 URL: $url');
      print('  状态码: ${e.response?.statusCode}');
      return false;
    } catch (e) {
      print('WebDAV 创建目录异常: $e');
      print('  请求 URL: $url');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _downloadTasks() async {
    final url = buildUrl('/$_tasksFileName');
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.data) as Map<String, dynamic>;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      print('WebDAV 下载失败: ${e.message}');
      print('  请求 URL: $url');
      print('  状态码: ${e.response?.statusCode}');
    } catch (e) {
      print('WebDAV 下载异常: $e');
      print('  请求 URL: $url');
    }
    return null;
  }

  Future<bool> _uploadTasks(Map<String, dynamic> data) async {
    final url = buildUrl('/$_tasksFileName');
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
      print('WebDAV 上传失败: 状态码 ${response.statusCode}');
      print('  请求 URL: $url');
      return false;
    } on DioException catch (e) {
      print('WebDAV 上传失败: ${e.message}');
      print('  请求 URL: $url');
      print('  状态码: ${e.response?.statusCode}');
      return false;
    } catch (e) {
      print('WebDAV 上传异常: $e');
      print('  请求 URL: $url');
      return false;
    }
  }

  Future<SyncResult> sync(List<Task> localTasks) async {
    try {
      final remoteData = await _downloadTasks();

      if (remoteData == null) {
        // 首次同步：上传所有本地任务
        final success = await _uploadTasks(_tasksToJson(localTasks));
        return SyncResult(
          status: success ? SyncStatus.synced : SyncStatus.failed,
          uploadedCount: success ? localTasks.length : 0,
          error: success ? null : '上传失败',
        );
      }

      // 增量同步
      final remoteTasks = _jsonToTasks(remoteData);
      int uploadedCount = 0;
      int downloadedCount = 0;

      final remoteMap = {for (var t in remoteTasks) t.id: t};
      final localMap = {for (var t in localTasks) t.id: t};

      final mergedTasks = <Task>[];

      // 处理本地任务
      for (final task in localTasks) {
        final remoteTask = remoteMap[task.id];
        if (remoteTask == null) {
          // 本地新增任务
          mergedTasks.add(task);
          uploadedCount++;
        } else {
          // 两边都有，用更新时间判断
          if (task.updatedAt.isAfter(remoteTask.updatedAt)) {
            mergedTasks.add(task);
            uploadedCount++;
          } else {
            mergedTasks.add(remoteTask);
            downloadedCount++;
          }
        }
      }

      // 处理远程新增任务
      for (final remoteTask in remoteTasks) {
        if (!localMap.containsKey(remoteTask.id)) {
          mergedTasks.add(remoteTask);
          downloadedCount++;
        }
      }

      // 上传合并后的数据
      final uploadSuccess = await _uploadTasks(_tasksToJson(mergedTasks));

      return SyncResult(
        status: uploadSuccess ? SyncStatus.synced : SyncStatus.failed,
        uploadedCount: uploadedCount,
        downloadedCount: downloadedCount,
        error: uploadSuccess ? null : '上传合并结果失败',
      );
    } catch (e) {
      return SyncResult(status: SyncStatus.failed, error: e.toString());
    }
  }

  Map<String, dynamic> _tasksToJson(List<Task> tasks) {
    return {
      'tasks': tasks
          .map(
            (t) => {
              'id': t.id,
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
