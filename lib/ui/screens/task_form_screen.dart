import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:photo_view/photo_view.dart';
import '../../models/task.dart';
import '../../data/task_dao.dart';
import '../../providers/isar_provider.dart';
import '../../providers/task_providers.dart';
import '../../providers/chat_provider.dart';
import '../../services/notification_service.dart';
import '../../services/nlp_service.dart';
import '../../services/nlp_ai_service.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  final Task? task;

  const TaskFormScreen({super.key, this.task});

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customGroupController = TextEditingController();
  final _repeatIntervalController = TextEditingController(text: '1');
  int _priority = 0;
  DateTime? _dueDate;
  String? _groupName;
  final _tagsController = TextEditingController();
  bool _isRepeat = false;
  String _repeatType = 'daily';
  int _repeatInterval = 1;
  bool _useCustomGroup = false;
  List<DateTime> _reminderTimes = [];

  // 标题 NLP 预览
  Timer? _nlpDebounce;
  ParsedTask? _nlpPreview;
  bool _nlpPreviewDismissed = false;
  bool _isAiParsing = false;
  AiParsedTask? _aiPreview;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description ?? '';
      _priority = widget.task!.priority;
      _dueDate = widget.task!.dueDate;
      _groupName = widget.task!.groupName;
      _tagsController.text = widget.task!.tags.join(', ');
      _isRepeat = widget.task!.rrule != null && widget.task!.rrule!.isNotEmpty;
      _reminderTimes = List.from(widget.task!.reminderTimes);
      if (_isRepeat && widget.task!.rrule!.contains('DAILY')) {
        _repeatType = 'daily';
      } else if (_isRepeat && widget.task!.rrule!.contains('WEEKLY')) {
        _repeatType = 'weekly';
      } else if (_isRepeat && widget.task!.rrule!.contains('MONTHLY')) {
        _repeatType = 'monthly';
      }
    }
    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    _nlpDebounce?.cancel();
    _nlpDebounce = Timer(const Duration(milliseconds: 300), _runNlpPreview);
  }

  void _runNlpPreview() {
    if (!mounted) return;
    final text = _titleController.text;
    if (text.trim().isEmpty || _nlpPreviewDismissed) {
      setState(() => _nlpPreview = null);
      return;
    }
    final parsed = NlpService.parseNaturalLanguage(text);
    setState(() {
      // 仅当解析出 dueDate 才显示预览（避免对纯标题打扰）
      _nlpPreview = parsed.dueDate != null ? parsed : null;
    });
  }

  void _dismissNlpPreview() {
    setState(() {
      _nlpPreview = null;
      _aiPreview = null;
      _nlpPreviewDismissed = true;
    });
  }

  void _applyNlpPreview() {
    final preview = _nlpPreview;
    if (preview == null || preview.dueDate == null) return;
    setState(() {
      _titleController.removeListener(_onTitleChanged);
      _titleController.text = preview.title;
      _titleController.addListener(_onTitleChanged);
      _dueDate = preview.dueDate;
      // 默认加一个截止前 30 分钟的提醒（如果还没有任何提醒）
      if (_reminderTimes.isEmpty) {
        _reminderTimes.add(
          preview.dueDate!.subtract(const Duration(minutes: 30)),
        );
        _reminderTimes.sort();
      }
      _nlpPreview = null;
    });
  }

  void _applyAiPreview() {
    final p = _aiPreview;
    if (p == null) return;
    setState(() {
      _titleController.removeListener(_onTitleChanged);
      _titleController.text = p.title;
      _titleController.addListener(_onTitleChanged);
      if (p.dueDate != null) _dueDate = p.dueDate;
      if (p.priority != null) _priority = p.priority!;
      if (p.rrule != null && p.rrule!.isNotEmpty) {
        _isRepeat = true;
        if (p.rrule!.contains('DAILY')) {
          _repeatType = 'daily';
        } else if (p.rrule!.contains('WEEKLY')) {
          _repeatType = 'weekly';
        } else if (p.rrule!.contains('MONTHLY')) {
          _repeatType = 'monthly';
        }
        final m = RegExp(r'INTERVAL=(\d+)').firstMatch(p.rrule!);
        if (m != null) {
          _repeatInterval = int.tryParse(m.group(1)!) ?? 1;
          _repeatIntervalController.text = '$_repeatInterval';
        }
      }
      if (p.dueDate != null && p.reminderOffsetsMin != null) {
        for (final off in p.reminderOffsetsMin!) {
          final t = p.dueDate!.subtract(Duration(minutes: off));
          if (!_reminderTimes.any((x) => x.isAtSameMomentAs(t))) {
            _reminderTimes.add(t);
          }
        }
        _reminderTimes.sort();
      }
      _aiPreview = null;
      _nlpPreview = null;
    });
  }

  Future<void> _runAiParse() async {
    if (_isAiParsing) return;
    final ai = ref.read(aiServiceProvider).valueOrNull;
    if (ai == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('AI 未配置；请到设置页配置后重试')));
      }
      return;
    }
    setState(() => _isAiParsing = true);
    try {
      final svc = NlpAiService(ai);
      final out = await svc.parse(_titleController.text);
      if (mounted) {
        setState(() => _aiPreview = out);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AI 解析失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _isAiParsing = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;
      final current = _descriptionController.text;
      final insert = current.isEmpty ? path : '$current\n$path';
      _descriptionController.text = insert;
      _descriptionController.selection = TextSelection.collapsed(
        offset: insert.length,
      );
    } catch (e) {
      debugPrint('_pickImage failed: $e');
    }
  }

  List<String> _extractImagePaths() {
    final text = _descriptionController.text;
    if (text.isEmpty) return const [];
    final regex = RegExp(
      r'(?:^|\n)(\/[^\n]+\.(?:png|jpg|jpeg|gif|webp|bmp))',
      multiLine: true,
    );
    return regex.allMatches(text).map((m) => m.group(1)!).toList();
  }

  Widget _buildImagePreviews() {
    final paths = _extractImagePaths();
    if (paths.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: paths
            .map(
              (p) => GestureDetector(
                onTap: () => _openImageFullscreen(p),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withAlpha(60)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.file(
                    File(p),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      size: 32,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _openImageFullscreen(String path) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          backgroundColor: Colors.black,
          body: PhotoView(
            imageProvider: FileImage(File(path)),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nlpDebounce?.cancel();
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _customGroupController.dispose();
    _repeatIntervalController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    List<String> tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    String? rrule;
    if (_isRepeat) {
      String freq;
      switch (_repeatType) {
        case 'daily':
          freq = 'FREQ=DAILY';
          break;
        case 'weekly':
          freq = 'FREQ=WEEKLY';
          break;
        case 'monthly':
          freq = 'FREQ=MONTHLY';
          break;
        default:
          freq = 'FREQ=DAILY';
      }
      if (_repeatInterval > 1) {
        rrule = '$freq;INTERVAL=$_repeatInterval';
      } else {
        rrule = freq;
      }
    }

    String? finalGroupName;
    if (_useCustomGroup) {
      finalGroupName = _customGroupController.text.isNotEmpty
          ? _customGroupController.text
          : null;
    } else {
      finalGroupName = _groupName?.isNotEmpty ?? false ? _groupName : null;
    }

    final newTask =
        widget.task?.copyWith(
          title: _titleController.text,
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : null,
          priority: _priority,
          dueDate: _dueDate,
          tags: tags,
          groupName: finalGroupName,
          rrule: rrule,
          isRepeatParent: _isRepeat,
          reminderTimes: _reminderTimes,
          updatedAt: DateTime.now(),
        ) ??
        Task(
          title: _titleController.text,
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : null,
          priority: _priority,
          dueDate: _dueDate,
          tags: tags,
          groupName: finalGroupName,
          rrule: rrule,
          isRepeatParent: _isRepeat,
          reminderTimes: _reminderTimes,
        );

    final isar = await ref.read(isarProvider.future);
    final dao = TaskDao(isar);

    if (widget.task != null) {
      await dao.updateTask(newTask);
    } else {
      await dao.insertTask(newTask);
    }

    if (newTask.dueDate != null) {
      await NotificationService().scheduleTaskReminder(newTask);
    }

    Navigator.pop(context);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _addReminderTime() async {
    // 默认日期：优先用截止日期（如果未过期），否则用今天
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final defaultDate = _dueDate != null && !_dueDate!.isBefore(today)
        ? _dueDate!
        : now;

    final date = await showDatePicker(
      context: context,
      initialDate: defaultDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _reminderTimes.add(
            DateTime(date.year, date.month, date.day, time.hour, time.minute),
          );
          _reminderTimes.sort();
        });
      }
    }
  }

  void _removeReminderTime(DateTime time) {
    setState(() {
      _reminderTimes.remove(time);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task != null ? '编辑任务' : '新建任务'),
        actions: [TextButton(onPressed: _submitForm, child: const Text('保存'))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 标题输入
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '任务标题',
                  hintText: '输入任务标题',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: _titleController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.lightbulb),
                          onPressed: _runAiParse,
                          tooltip: '用 AI 解析',
                        )
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入任务标题';
                  }
                  return null;
                },
                autofocus: true,
              ),
              if (_nlpPreview != null) _buildNlpPreviewCard(),
              if (_aiPreview != null) _buildAiPreviewCard(),

              const SizedBox(height: 16),

              // 描述输入
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: '任务描述',
                  hintText: '输入任务描述（可选）',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.image_outlined),
                    tooltip: '插入图片',
                    onPressed: _pickImage,
                  ),
                ),
                maxLines: 3,
              ),
              // 图片预览
              _buildImagePreviews(),

              const SizedBox(height: 16),

              // 截止日期
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: _selectDate,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _dueDate != null
                                ? '${_dueDate!.year}/${_dueDate!.month}/${_dueDate!.day}'
                                : '选择截止日期',
                            style: TextStyle(
                              fontSize: 16,
                              color: _dueDate != null
                                  ? Colors.black87
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFFBDBDBD),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 提醒时间设置
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '提醒时间',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _addReminderTime,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: const Text('添加提醒'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_reminderTimes.isEmpty)
                        const Text(
                          '暂无提醒时间',
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        Column(
                          children: _reminderTimes.map((time) {
                            return Row(
                              children: [
                                const Icon(Icons.alarm, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removeReminderTime(time),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 优先级选择
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '优先级',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _priorityButton(0, '无'),
                          _priorityButton(1, '低'),
                          _priorityButton(2, '中'),
                          _priorityButton(3, '高'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 分组选择
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '分组',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _groupButton('工作'),
                          _groupButton('个人'),
                          _groupButton('学习'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.add_circle_outline,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _customGroupController,
                              decoration: InputDecoration(
                                hintText: '自定义分组名称',
                                border: InputBorder.none,
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _useCustomGroup = value.isNotEmpty;
                                  if (value.isNotEmpty) {
                                    _groupName = null;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 标签输入
              TextFormField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: '标签',
                  hintText: '多个标签用逗号分隔',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, _) {
                  final allTags = ref.watch(allTagsProvider);
                  if (allTags.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final currentTags = _currentTagsFromController();
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '已有标签（点击添加）',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: allTags.map((tag) {
                            final selected = currentTags.contains(tag);
                            return FilterChip(
                              label: Text(tag),
                              selected: selected,
                              onSelected: (sel) {
                                setState(() {
                                  final tags = _currentTagsFromController();
                                  if (sel) {
                                    if (!tags.contains(tag)) tags.add(tag);
                                  } else {
                                    tags.remove(tag);
                                  }
                                  _tagsController.text = tags.join(', ');
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // 重复任务
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '重复任务',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Switch(
                            value: _isRepeat,
                            onChanged: (value) =>
                                setState(() => _isRepeat = value),
                          ),
                        ],
                      ),
                      if (_isRepeat) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _repeatButton('daily', '每天'),
                            _repeatButton('weekly', '每周'),
                            _repeatButton('monthly', '每月'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('间隔:', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _repeatIntervalController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '1',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                textAlign: TextAlign.center,
                                onChanged: (value) {
                                  setState(() {
                                    _repeatInterval = int.tryParse(value) ?? 1;
                                    if (_repeatInterval < 1)
                                      _repeatInterval = 1;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _repeatType == 'daily'
                                  ? '天'
                                  : _repeatType == 'weekly'
                                  ? '周'
                                  : '月',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 删除任务按钮（仅编辑模式显示）
              if (widget.task != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text(
                      '删除任务',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务"${widget.task!.title}"吗？\n\n删除后可通过同步从其他设备恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _deleteTask(context);
    }
  }

  Future<void> _deleteTask(BuildContext context) async {
    try {
      final isar = await ref.read(isarProvider.future);
      final dao = TaskDao(isar);

      // 取消该任务的所有提醒通知
      await NotificationService().cancelTaskReminder(widget.task!);

      // 软删除任务
      await dao.softDeleteTask(widget.task!.id);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('任务已删除')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _priorityButton(int priority, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: () => setState(() => _priority = priority),
          style: ElevatedButton.styleFrom(
            backgroundColor: _priority == priority
                ? _getPriorityColor(priority)
                : Colors.grey[100],
            foregroundColor: _priority == priority
                ? Colors.white
                : Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _groupButton(String group) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: () =>
            setState(() => _groupName = _groupName == group ? null : group),
        style: ElevatedButton.styleFrom(
          backgroundColor: _groupName == group ? Colors.blue : Colors.grey[100],
          foregroundColor: _groupName == group ? Colors.white : Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: Text(group),
      ),
    );
  }

  Widget _repeatButton(String type, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: () => setState(() => _repeatType = type),
        style: ElevatedButton.styleFrom(
          backgroundColor: _repeatType == type ? Colors.blue : Colors.grey[100],
          foregroundColor: _repeatType == type ? Colors.white : Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: Text(label),
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 3:
        return Colors.redAccent;
      case 2:
        return Colors.orangeAccent;
      case 1:
        return Colors.blueAccent;
      default:
        return Colors.grey[400]!;
    }
  }

  List<String> _currentTagsFromController() {
    return _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  String _fmtDateTimeShort(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final today = DateTime.now();
    final isSameDay =
        d.year == today.year && d.month == today.month && d.day == today.day;
    final tomorrow = today.add(const Duration(days: 1));
    final isTomorrow =
        d.year == tomorrow.year &&
        d.month == tomorrow.month &&
        d.day == tomorrow.day;
    final dateLabel = isSameDay
        ? '今天'
        : isTomorrow
        ? '明天'
        : '${d.month}/${d.day}';
    return '$dateLabel ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _buildNlpPreviewCard() {
    final preview = _nlpPreview!;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF90CAF9)),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Icon(Icons.event, size: 18, color: Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '识别到：${_fmtDateTimeShort(preview.dueDate!)} · 置信度 ${preview.confidence}%',
                style: const TextStyle(fontSize: 13, color: Color(0xFF0D47A1)),
              ),
            ),
            TextButton(onPressed: _applyNlpPreview, child: const Text('应用')),
            IconButton(
              tooltip: '用 AI 解析',
              onPressed: _isAiParsing ? null : _runAiParse,
              icon: _isAiParsing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
            ),
            IconButton(
              tooltip: '关闭',
              onPressed: _dismissNlpPreview,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiPreviewCard() {
    final p = _aiPreview!;
    final parts = <String>[];
    if (p.dueDate != null) parts.add('截止 ${_fmtDateTimeShort(p.dueDate!)}');
    if (p.priority != null) parts.add('优先级 ${p.priority}');
    if (p.rrule != null) parts.add('重复 ${p.rrule}');
    if (p.reminderOffsetsMin != null && p.reminderOffsetsMin!.isNotEmpty) {
      parts.add('提醒前 ${p.reminderOffsetsMin!.join('/')} 分钟');
    }
    final summary = parts.isEmpty ? '未识别到具体字段' : parts.join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3E5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCE93D8)),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: Color(0xFF6A1B9A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI 解析：${p.title}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4A148C),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => setState(() => _aiPreview = null),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              summary,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _applyAiPreview,
                child: const Text('应用'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
