import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/isar_provider.dart';
import '../../data/task_dao.dart';
import '../../models/task.dart';

class DataManagementScreen extends ConsumerWidget {
  const DataManagementScreen({super.key});

  Future<void> _importIcs(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ics'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final tasks = _parseIcs(content);

      final isarAsync = ref.read(isarProvider);
      isarAsync.whenData((isar) async {
        final dao = TaskDao(isar);
        for (final task in tasks) {
          await dao.insertTask(task);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('成功导入 ${tasks.length} 个任务')));
        }
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  List<Task> _parseIcs(String content) {
    final tasks = <Task>[];
    final lines = content.split('\n');
    String? title;
    DateTime? dueDate;
    String? description;
    bool inVevent = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == 'BEGIN:VEVENT') {
        inVevent = true;
        title = null;
        dueDate = null;
        description = null;
      } else if (trimmed == 'END:VEVENT') {
        if (inVevent && title != null && title.isNotEmpty) {
          tasks.add(
            Task(title: title, dueDate: dueDate, description: description),
          );
        }
        inVevent = false;
      } else if (inVevent) {
        if (trimmed.startsWith('SUMMARY:')) {
          title = _unescapeIcs(trimmed.substring(8));
        } else if (trimmed.startsWith('DTSTART')) {
          dueDate = _parseIcsDate(trimmed);
        } else if (trimmed.startsWith('DTEND')) {
          dueDate ??= _parseIcsDate(trimmed);
        } else if (trimmed.startsWith('DESCRIPTION:')) {
          description = _unescapeIcs(trimmed.substring(12));
        }
      }
    }
    return tasks;
  }

  String _unescapeIcs(String s) {
    return s
        .replaceAll('\\n', '\n')
        .replaceAll('\\,', ',')
        .replaceAll('\\\\', '\\');
  }

  DateTime? _parseIcsDate(String line) {
    try {
      final parts = line.split(':');
      if (parts.length < 2) return null;
      final dateStr = parts[1].trim();
      // 格式: 20240101T120000Z
      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));
      if (dateStr.length >= 15) {
        final hour = int.parse(dateStr.substring(9, 11));
        final minute = int.parse(dateStr.substring(11, 13));
        final second = int.parse(dateStr.substring(13, 15));
        return DateTime.utc(year, month, day, hour, minute, second);
      }
      return DateTime.utc(year, month, day);
    } catch (_) {
      return null;
    }
  }

  Future<void> _exportIcs(BuildContext context, WidgetRef ref) async {
    try {
      final isarAsync = ref.read(isarProvider);
      final isar = isarAsync.valueOrNull;
      final tasks = isar != null
          ? await TaskDao(isar).getAllActiveTasks()
          : <Task>[];

      if (tasks.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('没有可导出的任务')));
        }
        return;
      }

      final icsContent = _generateIcs(tasks);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/catodo_export.ics');
      await file.writeAsString(icsContent);

      await Share.shareXFiles([XFile(file.path)], subject: 'Catodo 任务导出');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  String _generateIcs(List<Task> tasks) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Catodo//Catodo App//EN');

    for (final task in tasks) {
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:catodo-${task.id}');
      buffer.writeln('SUMMARY:${_escapeIcs(task.title)}');
      if (task.description != null && task.description!.isNotEmpty) {
        buffer.writeln('DESCRIPTION:${_escapeIcs(task.description!)}');
      }
      if (task.dueDate != null) {
        final dateStr = _formatIcsDate(task.dueDate!);
        buffer.writeln('DTSTART:$dateStr');
        buffer.writeln('DTEND:$dateStr');
      }
      buffer.writeln('PRIORITY:${task.priority + 1}');
      buffer.writeln(
        'STATUS:${task.isCompleted ? 'COMPLETED' : 'NEEDS-ACTION'}',
      );
      if (task.tags.isNotEmpty) {
        buffer.writeln('CATEGORIES:${task.tags.join(',')}');
      }
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  String _escapeIcs(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n');
  }

  String _formatIcsDate(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}'
        'T${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}';
  }

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
              onTap: () => _importIcs(context, ref),
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
              subtitle: const Text('将所有任务导出为日历格式'),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFFBDBDBD),
              ),
              onTap: () => _exportIcs(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}
