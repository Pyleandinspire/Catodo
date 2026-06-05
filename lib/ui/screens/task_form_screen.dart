import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task.dart';
import '../../data/task_dao.dart';
import '../../providers/isar_provider.dart';
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
  int _priority = 0;
  DateTime? _dueDate;
  String? _groupName;
  final _tagsController = TextEditingController();
  bool _isRepeat = false;
  String _repeatType = 'daily';
  bool _useCustomGroup = false;

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
      switch (_repeatType) {
        case 'daily':
          rrule = 'FREQ=DAILY';
          break;
        case 'weekly':
          rrule = 'FREQ=WEEKLY';
          break;
        case 'monthly':
          rrule = 'FREQ=MONTHLY';
          break;
      }
    }

    String? finalGroupName;
    if (_useCustomGroup) {
      finalGroupName = _customGroupController.text.isNotEmpty ? _customGroupController.text : null;
    } else {
      finalGroupName = _groupName?.isNotEmpty ?? false ? _groupName : null;
    }

    final newTask = widget.task?.copyWith(
      title: _titleController.text,
      description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      priority: _priority,
      dueDate: _dueDate,
      tags: tags,
      groupName: finalGroupName,
      rrule: rrule,
      isRepeatParent: _isRepeat,
      updatedAt: DateTime.now(),
    ) ?? Task(
      title: _titleController.text,
      description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      priority: _priority,
      dueDate: _dueDate,
      tags: tags,
      groupName: finalGroupName,
      rrule: rrule,
      isRepeatParent: _isRepeat,
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

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task != null ? '编辑任务' : '新建任务'),
        actions: [
          TextButton(
            onPressed: _submitForm,
            child: const Text('保存'),
          ),
        ],
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              // 截止日期
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                              color: _dueDate != null ? Colors.black87 : Colors.grey[500],
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Color(0xFFBDBDBD)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 优先级选择
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          const Icon(Icons.add_circle_outline, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _customGroupController,
                              decoration: InputDecoration(
                                hintText: '自定义分组名称',
                                border: InputBorder.none,
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey[300]!),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 16),

              // 重复任务
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            onChanged: (value) => setState(() => _isRepeat = value),
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
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            foregroundColor: _priority == priority ? Colors.white : Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        onPressed: () => setState(() => _groupName = _groupName == group ? null : group),
        style: ElevatedButton.styleFrom(
          backgroundColor: _groupName == group ? Colors.blue : Colors.grey[100],
          foregroundColor: _groupName == group ? Colors.white : Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
}