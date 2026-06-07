import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task.dart';
import '../../data/task_dao.dart';
import '../../providers/isar_provider.dart';
import '../../providers/task_providers.dart';
import '../../services/notification_service.dart';

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
  }

  @override
  void dispose() {
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
                          onPressed: () {},
                          tooltip: '智能解析',
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
                ),
                maxLines: 3,
              ),

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
}
