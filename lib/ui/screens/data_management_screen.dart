import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/isar_provider.dart';
import '../../data/task_dao.dart';
import '../../services/ics_service.dart';
import '../../services/catodo_io_service.dart';
import '../../services/secure_store.dart';

/// 数据导入/导出公共逻辑（提供给页面与按钮共用）。
class DataIoActions {
  DataIoActions._();

  /// 通过系统对话框选择 .ics 文件并导入。
  static Future<void> importIcs(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ics'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.single.bytes;
      if (bytes == null) return;

      final content = utf8.decode(bytes);
      final tasks = IcsService.parseIcs(content);

      final isar = await ref.read(isarProvider.future);
      final dao = TaskDao(isar);
      for (final task in tasks) {
        await dao.insertTask(task);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('成功导入 ${tasks.length} 个任务')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  /// 让用户选择保存位置，将所有活动任务导出为 .ics 文件。
  static Future<void> exportIcs(BuildContext context, WidgetRef ref) async {
    try {
      final isar = await ref.read(isarProvider.future);
      final tasks = await TaskDao(isar).getAllActiveTasks();

      if (tasks.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('没有可导出的任务')));
        }
        return;
      }

      final icsContent = IcsService.generateIcs(tasks);
      final fileName =
          'catodo_export_${DateTime.now().millisecondsSinceEpoch}.ics';
      final bytes = Uint8List.fromList(icsContent.codeUnits);

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '选择导出位置',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['ics'],
        bytes: bytes,
      );

      if (context.mounted) {
        if (savedPath != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('导出成功: $savedPath')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  /// 导入 .catodo 完整格式文件
  static Future<void> importCatodo(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['catodo'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.single.bytes;
      if (bytes == null) return;

      final content = utf8.decode(bytes);
      final data = CatodoIOService.importCatodo(content);

      final isar = await ref.read(isarProvider.future);
      final dao = TaskDao(isar);
      for (final task in data.tasks) {
        await dao.insertTask(task);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 ${data.tasks.length} 个任务')),
        );
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败: ${e.message}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  /// 导出 .catodo 完整格式文件
  static Future<void> exportCatodo(
    BuildContext context,
    WidgetRef ref, {
    bool includeSensitive = false,
  }) async {
    try {
      final isar = await ref.read(isarProvider.future);
      final tasks = await TaskDao(isar).getAllActiveTasks();

      if (tasks.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('没有可导出的任务')));
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      // 敏感字段从 SecureStore 读取
      final webdavPassword = includeSensitive
          ? (await SecureStore.instance.readWebDavPassword() ?? '')
          : '';
      final aiApiKey = includeSensitive
          ? (await SecureStore.instance.readAiApiKey() ?? '')
          : '';
      final settings = {
        'webdav': {
          'url': prefs.getString('webdav_url') ?? '',
          'username': prefs.getString('webdav_username') ?? '',
          if (includeSensitive) 'password': webdavPassword,
        },
        'ai': {
          'provider': prefs.getString('ai_provider_id') ?? 'custom',
          'apiUrl': prefs.getString('ai_api_url') ?? '',
          'model': prefs.getString('ai_model') ?? '',
          if (includeSensitive) 'apiKey': aiApiKey,
        },
      };

      final jsonContent = CatodoIOService.exportCatodo(
        tasks: tasks,
        settings: settings,
        includeSensitive: includeSensitive,
      );

      final fileName =
          'catodo_export_${DateTime.now().millisecondsSinceEpoch}.catodo';
      final bytes = Uint8List.fromList(jsonContent.codeUnits);

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '选择导出位置',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['catodo'],
        bytes: bytes,
      );

      if (context.mounted) {
        if (savedPath != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('导出成功: $savedPath')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }
}

class DataManagementScreen extends ConsumerWidget {
  const DataManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据管理'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '导入',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: const Icon(Icons.file_download, color: Colors.blue),
              ),
              title: const Text('导入 .ics 文件'),
              subtitle: const Text('从日历文件导入任务'),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFFBDBDBD),
              ),
              onTap: () => DataIoActions.importIcs(context, ref),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: const Icon(Icons.file_download, color: Colors.blue),
              ),
              title: const Text('导入 .catodo 完整格式'),
              subtitle: const Text('从 Catodo 完整备份文件导入'),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFFBDBDBD),
              ),
              onTap: () => DataIoActions.importCatodo(context, ref),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '导出',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: const Icon(Icons.file_upload, color: Colors.green),
              ),
              title: const Text('导出 .ics 文件'),
              subtitle: const Text('保存所有任务到所选文件夹'),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFFBDBDBD),
              ),
              onTap: () => DataIoActions.exportIcs(context, ref),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: const Icon(Icons.file_upload, color: Colors.green),
              ),
              title: const Text('导出 .catodo 完整格式'),
              subtitle: const Text('导出所有任务和设置'),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFFBDBDBD),
              ),
              onTap: () => _showExportCatodoDialog(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportCatodoDialog(BuildContext context, WidgetRef ref) {
    bool includeSensitive = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('导出完整格式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('导出所有任务和设置到 .catodo 文件。'),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: includeSensitive,
                onChanged: (value) {
                  setState(() => includeSensitive = value ?? false);
                },
                title: const Text('包含敏感设置'),
                subtitle: const Text(
                  '包括 WebDAV 密码、AI API Key 等敏感信息',
                  style: TextStyle(fontSize: 12),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                DataIoActions.exportCatodo(
                  context,
                  ref,
                  includeSensitive: includeSensitive,
                );
              },
              child: const Text('导出'),
            ),
          ],
        ),
      ),
    );
  }
}
