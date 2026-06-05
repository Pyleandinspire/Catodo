import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_service.dart';
import '../../providers/task_providers.dart';
import '../../providers/isar_provider.dart';
import '../../data/task_dao.dart';
import '../../models/task.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  AIService? _aiService;

  @override
  void initState() {
    super.initState();
    _initAIService();
    _messages.add(
      ChatMessage(
        isUser: false,
        text:
            '你好！我是 AI 助手，可以帮你：\n'
            '1. 分解任务 - 发送"分解：【任务名称】"\n'
            '2. 情绪支持 - 选择一个超时任务，我会帮你分析\n'
            '3. 自由对话 - 直接输入你的问题',
      ),
    );
  }

  Future<void> _initAIService() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('ai_api_key') ?? '';
    final baseUrl = prefs.getString('ai_base_url') ?? '';
    final model = prefs.getString('ai_model') ?? '';
    final providerId = prefs.getString('ai_provider_id') ?? 'custom';

    if (apiKey.isNotEmpty && baseUrl.isNotEmpty && model.isNotEmpty) {
      _aiService = AIService(
        AIConfig(
          providerId: providerId,
          apiKey: apiKey,
          baseUrl: baseUrl,
          modelName: model,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _messages.add(ChatMessage(isUser: true, text: text)));
    _scrollToBottom();

    if (_aiService == null) {
      setState(
        () => _messages.add(
          ChatMessage(isUser: false, text: '请先在设置中配置 AI 助手的 API 参数。'),
        ),
      );
      _scrollToBottom();
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (text.startsWith('分解：') || text.startsWith('分解:')) {
        final taskTitle = text.substring(3).trim();
        await _decomposeTask(taskTitle);
      } else if (text.startsWith('支持：') || text.startsWith('支持:')) {
        final taskTitle = text.substring(3).trim();
        await _emotionalSupport(taskTitle);
      } else {
        await _chatWithAI(text);
      }
    } catch (e) {
      setState(
        () => _messages.add(ChatMessage(isUser: false, text: '抱歉，发生错误：$e')),
      );
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _decomposeTask(String taskTitle) async {
    final subTasks = await _aiService!.decomposeTask(taskTitle);

    if (subTasks == null || subTasks.isEmpty) {
      setState(
        () => _messages.add(
          ChatMessage(isUser: false, text: '抱歉，无法分解该任务，请稍后再试。'),
        ),
      );
      return;
    }

    final buffer = StringBuffer('任务「$taskTitle」分解结果：\n\n');
    for (var i = 0; i < subTasks.length; i++) {
      final st = subTasks[i];
      final priorityText = _priorityLabel(st['priority'] ?? 1);
      final minutes = st['estimatedMinutes'] ?? 30;
      buffer.writeln('${i + 1}. ${st['title']} [$priorityText, 约${minutes}分钟]');
    }

    setState(
      () => {
        _messages.add(ChatMessage(isUser: false, text: buffer.toString())),
        _messages.add(
          ChatMessage(
            isUser: false,
            text: '是否需要将这些子任务添加到任务列表？',
            hasAddTaskAction: true,
            subTasks: subTasks,
          ),
        ),
      },
    );
  }

  Future<void> _emotionalSupport(String taskTitle) async {
    final result = await _aiService!.requestStructuredOutput(
      systemPrompt:
          '你是一位温暖的心理咨询师兼时间管理教练。用户任务超时了，请给予温柔鼓励和具体建议。返回JSON: {"response": "你的回复"}',
      userPrompt: '我的任务「$taskTitle」超时了，我感到很沮丧，请帮帮我。',
    );

    final response = result?['response'] ?? '没关系，超时是正常的。我们一起来看看怎么调整？';
    setState(
      () =>
          _messages.add(ChatMessage(isUser: false, text: response.toString())),
    );
  }

  Future<void> _chatWithAI(String text) async {
    final result = await _aiService!.requestStructuredOutput(
      systemPrompt:
          '你是一个个人任务管理助手，帮助用户管理任务、提高效率。回复简洁有温度。返回JSON: {"response": "你的回复"}',
      userPrompt: text,
    );

    final response = result?['response'] ?? '抱歉，我暂时无法回复。';
    setState(
      () =>
          _messages.add(ChatMessage(isUser: false, text: response.toString())),
    );
  }

  String _priorityLabel(int priority) {
    switch (priority) {
      case 3:
        return '高优先级';
      case 2:
        return '中优先级';
      case 1:
        return '低优先级';
      default:
        return '无优先级';
    }
  }

  Future<void> _addSubTasks(List<Map<String, dynamic>> subTasks) async {
    final isarAsync = ref.read(isarProvider);
    final isar = isarAsync.valueOrNull;
    if (isar == null) {
      setState(
        () => _messages.add(ChatMessage(isUser: false, text: '数据库未就绪，请稍后再试。')),
      );
      _scrollToBottom();
      return;
    }

    final dao = TaskDao(isar);
    int added = 0;
    for (final st in subTasks) {
      final task = Task(
        title: st['title'] ?? '未命名子任务',
        priority: st['priority'] ?? 1,
      );
      await dao.insertTask(task);
      added++;
    }

    setState(
      () => _messages.add(
        ChatMessage(isUser: false, text: '已成功添加 $added 个子任务到任务列表。'),
      ),
    );
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 头部
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'AI 助手',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showQuickActions,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('快捷操作'),
                      ),
                    ],
                  ),
                  const Text(
                    '智能任务分解与情绪支持',
                    style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
                  ),
                ],
              ),
            ),

            // 聊天区域
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading) {
                    return _buildLoadingBubble();
                  }
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),

            // 输入区域
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: '输入消息...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isLoading ? null : _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isLoading ? Colors.grey : Colors.black,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(24),
                        ),
                      ),
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Card(
          color: Color(0xFFF5F5F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 80,
              height: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '思考中...',
                    style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: message.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            decoration: BoxDecoration(
              color: message.isUser ? Colors.black : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(message.isUser ? 16 : 0),
                bottomRight: Radius.circular(message.isUser ? 0 : 16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (message.hasAddTaskAction && message.subTasks != null) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _addSubTasks(message.subTasks!),
              icon: const Icon(Icons.add_task, size: 18),
              label: const Text('添加到任务列表'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '快捷操作',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.call_split, color: Colors.purple),
              title: const Text('分解任务'),
              subtitle: const Text('选择一个任务，拆解为子任务'),
              onTap: () {
                Navigator.pop(context);
                _showTaskPicker(true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology, color: Colors.orange),
              title: const Text('超时情绪支持'),
              subtitle: const Text('选择超时任务，获取鼓励和建议'),
              onTap: () {
                Navigator.pop(context);
                _showTaskPicker(false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('手动输入'),
              subtitle: const Text('发送"分解：【任务名】"或"支持：【任务名】"'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskPicker(bool isDecompose) {
    final tasksAsync = ref.read(activeTasksProvider);
    final tasks = tasksAsync.valueOrNull ?? [];

    if (tasks.isEmpty) {
      setState(
        () =>
            _messages.add(ChatMessage(isUser: false, text: '当前没有可用任务，请先创建任务。')),
      );
      _scrollToBottom();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: 400,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isDecompose ? '选择要分解的任务' : '选择超时任务',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(tasks[i].title),
                  subtitle: Text(
                    tasks[i].dueDate != null
                        ? '截止: ${tasks[i].dueDate!.toLocal().toString().split('.')[0]}'
                        : '无截止日期',
                  ),
                  leading: Icon(
                    tasks[i].priority >= 2 ? Icons.flag : Icons.outlined_flag,
                    color: tasks[i].priority >= 2 ? Colors.red : Colors.grey,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (isDecompose) {
                      _messageController.text = '分解：${tasks[i].title}';
                      _sendMessage();
                    } else {
                      _messageController.text = '支持：${tasks[i].title}';
                      _sendMessage();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final bool isUser;
  final String text;
  final bool hasAddTaskAction;
  final List<Map<String, dynamic>>? subTasks;

  ChatMessage({
    required this.isUser,
    required this.text,
    this.hasAddTaskAction = false,
    this.subTasks,
  });
}
