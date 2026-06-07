import '../models/task.dart';

/// ICS 文件解析与生成服务（纯函数，无 UI 依赖）。
class IcsService {
  IcsService._();

  static List<Task> parseIcs(String content) {
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

  static String generateIcs(List<Task> tasks) {
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

  static String _escapeIcs(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n');
  }

  static String _unescapeIcs(String s) {
    return s
        .replaceAll('\\\\', '\\')
        .replaceAll('\\,', ',')
        .replaceAll('\\n', '\n');
  }

  static String _formatIcsDate(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}'
        'T${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseIcsDate(String line) {
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
}
