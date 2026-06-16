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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('成功导入 ${data.tasks.length} 个任务')));
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _DataActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DataActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class DataManagementScreen extends ConsumerWidget {
  const DataManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_rounded, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '建议定期导出 .catodo 完整格式，换设备或重装应用时恢复更方便。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const _SectionTitle(title: '导入', icon: Icons.file_download_rounded),
          _DataActionCard(
            icon: Icons.event_note_rounded,
            iconColor: Colors.blue,
            iconBgColor: const Color(0xFFE3F2FD),
            title: '导入 .ics 文件',
            subtitle: '从日历文件导入任务',
            onTap: () => DataIoActions.importIcs(context, ref),
          ),
          _DataActionCard(
            icon: Icons.inventory_2_rounded,
            iconColor: Colors.indigo,
            iconBgColor: const Color(0xFFE8EAF6),
            title: '导入 .catodo 完整格式',
            subtitle: '从完整备份文件导入',
            onTap: () => DataIoActions.importCatodo(context, ref),
          ),
          const _SectionTitle(title: '导出', icon: Icons.file_upload_rounded),
          _DataActionCard(
            icon: Icons.calendar_month_rounded,
            iconColor: Colors.green,
            iconBgColor: const Color(0xFFE8F5E9),
            title: '导出 .ics 文件',
            subtitle: '保存所有任务到所选文件夹',
            onTap: () => DataIoActions.exportIcs(context, ref),
          ),
          _DataActionCard(
            icon: Icons.archive_rounded,
            iconColor: Colors.teal,
            iconBgColor: const Color(0xFFE0F2F1),
            title: '导出 .catodo 完整格式',
            subtitle: '导出所有任务和设置',
            onTap: () => _showExportCatodoDialog(context, ref),
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
