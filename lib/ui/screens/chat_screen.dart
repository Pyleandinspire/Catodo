import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ai_agent.dart';
import '../../services/ai_service.dart';
import '../../services/notification_service.dart';
import '../../providers/task_providers.dart';
import '../../providers/isar_provider.dart';
import '../../providers/chat_provider.dart';
import '../../data/task_dao.dart';
import '../../data/chat_message_dao.dart';
import '../../models/chat_message_entity.dart';
import '../../models/task.dart';
import 'ai_settings_screen.dart';
import 'scheduling_optimizer_screen.dart';
import '../icons/app_icons.dart';

/// 聊天页 — 已迁到 Isar 持久化（PLAN-AI-001-5）。
///
/// - 历史 / 多轮记忆来自 [chatMessagesProvider]，跨切页与重启都保留；
/// - AIService 来自 [aiServiceProvider]，避免旧的 fire-and-forget 加载竞态；
/// - 待确认 actions 仍在内存（[_pending]），重启即过期，避免 taskId 失效误执行。
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const int _sessionId = ChatMessageDao.defaultSessionId;
  static const int _historyMaxFromDb = 200;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  /// 待确认 actions 队列（仅内存，不入库）。每组对应一次模型回复带出的待确认操作。
  final List<List<AgentAction>> _pending = [];

  /// 最近一次失败信息（仅 UI 提示，不入库）。点击重试 / 修复后清空。
  AiCallError? _lastError;
  String? _lastUserMessage; // 用于"重试"

  bool _isSending = false;

  static const String _welcomeText =
      '你好！我是 AI 助手，可以直接帮你管理任务：\n'
      '1. 创建任务 - "帮我创建一个高优先级任务：完成报告"\n'
      '2. 分解任务 - "分解任务「学习 Flutter」"\n'
      '3. 调整优先级 - "把任务「买牛奶」设为低优先级"\n'
      '4. 加标签/分组 - "给任务加标签「紧急」"\n'
      '5. 完成/删除 - "完成任务「买牛奶」"\n'
      '6. 自由对话 - 直接输入你的问题';

  static const String _pendingHint = '未确认的操作仅在本次会话有效，关闭或切走即过期。';

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

  Future<void> _appendDb({
    required String role,
    required String content,
    bool visibleToModel = true,
  }) async {
    final dao = ref.read(chatMessageDaoProvider);
    await dao.append(ChatMessageEntity.now(
      sessionId: _sessionId,
      role: role,
      content: content,
      visibleToModel: visibleToModel,
    ));
  }

  Future<void> _sendMessage({String? overrideText}) async {
    final text = (overrideText ?? _messageController.text).trim();
    if (text.isEmpty) return;
    if (_isSending) {
      // 上一条仍在发送：给一条提示，不清输入框
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上一条还在发送中…')),
        );
      }
      return;
    }

    // 立刻置 sending=true 让按钮变灰；避免点击与异步写库间的视觉延迟
    setState(() {
      _isSending = true;
      _lastError = null;
    });
    if (overrideText == null) {
      _messageController.clear();
    }
    _lastUserMessage = text;

    // 立刻把 user 消息入库；UI 由 streamProvider 自动刷新
    await _appendDb(role: 'user', content: text);
    _scrollToBottom();

    // 取 AIService（FutureProvider，已配置时会立刻同步取到值）
    final aiAsync = ref.read(aiServiceProvider);
    final ai = aiAsync.valueOrNull;
    if (ai == null) {
      // 加载中或未配置：以 UI 提示告知，不入模型上下文
      await _appendDb(
        role: 'assistant',
        content: aiAsync.isLoading
            ? '正在加载 AI 配置，请稍候再发送…'
            : '请先在设置中配置 AI 助手的 API 参数。',
        visibleToModel: false,
      );
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
      return;
    }

    try {
      // 任务上下文
      final tasks = ref.read(activeTasksProvider).valueOrNull ?? const [];
      final context = buildTaskContext(tasks);

      // 多轮历史从持久化派生（不含本轮 user，因为 ChatTurn 由 latestUserMessage 单独传）
      final messagesNow = ref.read(chatMessagesProvider).valueOrNull ?? const [];
      final priorMessages = messagesNow.isNotEmpty
          ? messagesNow.sublist(0, messagesNow.length - 1)
          : const <ChatMessageEntity>[];
      final history = messagesToTurns(priorMessages);

      final r = await ai.requestAgentActionDetailedWithHistory(
        history: history,
        latestUserMessage: text,
        context: context,
      );

      // 错误优先：UI 在底部展示分级提示卡，并把简短摘要写入历史以便复盘
      if (r.error != null) {
        await _appendDb(
          role: 'assistant',
          content: '⚠️ ${r.error!.message}',
          visibleToModel: false,
        );
        if (mounted) setState(() => _lastError = r.error);
        return;
      }

      final response = r.response;

      // 拆分自动 / 待确认
      final autoActions = <AgentAction>[];
      final confirmActions = <AgentAction>[];
      for (final a in response.actions) {
        if (a.needsConfirmation) {
          confirmActions.add(a);
        } else {
          autoActions.add(a);
        }
      }

      // 自动执行
      final autoResults = <ActionResult>[];
      final autoTouched = <Task>[];
      if (autoActions.isNotEmpty) {
        final isar = ref.read(isarProvider).valueOrNull;
        if (isar != null) {
          final dao = TaskDao(isar);
          for (final action in autoActions) {
            final res = await executeAction(action, dao);
            autoResults.add(res);
            if (res.success && res.data is Task) {
              autoTouched.add(res.data as Task);
            }
          }
        }
      }
      // reminders / rrule 类自动操作（理论上当前都是 needsConfirmation=true，
      // 但保留这一步以防今后规则变化）
      if (autoTouched.isNotEmpty) {
        await NotificationService().rescheduleAllReminders(autoTouched);
      }

      // 拼接回复 + 自动结果 + 未知动作 warnings
      final replyBuffer = StringBuffer(response.reply);
      for (final ar in autoResults) {
        replyBuffer.write(ar.success ? '\n\n✓ ${ar.message}' : '\n\n✗ ${ar.message}');
      }
      if (response.warnings.isNotEmpty) {
        replyBuffer.write(
          '\n\n（已忽略未知动作：${response.warnings.join(', ')}）',
        );
      }
      final assistantText = replyBuffer.toString();
      await _appendDb(
        role: 'assistant',
        content: assistantText.isEmpty ? '(无内容)' : assistantText,
      );

      // 待确认 actions 进内存队列
      if (confirmActions.isNotEmpty) {
        setState(() => _pending.add(confirmActions));
      }
      _scrollToBottom();
    } catch (e) {
      await _appendDb(
        role: 'assistant',
        content: '抱歉，发生错误：$e',
        visibleToModel: false,
      );
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  Future<void> _confirmActions(List<AgentAction> actions) async {
    final isar = ref.read(isarProvider).valueOrNull;
    if (isar == null) {
      await _appendDb(
        role: 'assistant',
        content: '数据库未就绪，请稍后再试。',
        visibleToModel: false,
      );
      _scrollToBottom();
      return;
    }

    final dao = TaskDao(isar);
    final results = <ActionResult>[];
    final touched = <Task>[];
    for (final a in actions) {
      final res = await executeAction(a, dao);
      results.add(res);
      if (res.success && res.data is Task) {
        touched.add(res.data as Task);
      }
    }

    // 提醒/重复规则会改变通知；统一刷新一次
    if (touched.isNotEmpty) {
      await NotificationService().rescheduleAllReminders(touched);
    }

    final buf = StringBuffer('已执行操作：\n');
    for (final r in results) {
      buf.writeln(r.success ? '✓ ${r.message}' : '✗ ${r.message}');
    }
    await _appendDb(role: 'system_summary', content: buf.toString());

    setState(() => _pending.remove(actions));
    _scrollToBottom();
  }

  Future<void> _cancelActions(List<AgentAction> actions) async {
    await _appendDb(
      role: 'assistant',
      content: '已取消操作。',
      visibleToModel: false,
    );
    setState(() => _pending.remove(actions));
    _scrollToBottom();
  }

  Future<void> _confirmClearConversation() async {
    final dao = ref.read(chatMessageDaoProvider);
    final hasAny = (await dao.count(sessionId: _sessionId)) > 0;
    final hasPending = _pending.isNotEmpty;
    if (!hasAny && !hasPending) {
      return; // 本来就空
    }

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空对话'),
        content: const Text('清空当前对话历史与多轮记忆，欢迎语保留。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await dao.clearSession(sessionId: _sessionId);
      if (mounted) {
        setState(() {
          _pending.clear();
          _lastError = null;
        });
      }
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(messagesAsync.valueOrNull ?? const []),
            Expanded(
              child: messagesAsync.when(
                data: (msgs) => _buildList(msgs),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载消息失败: $e')),
              ),
            ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(List<ChatMessageEntity> msgs) {
    return Padding(
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
              Row(
                children: [
                  IconButton(
                    tooltip: '清空对话',
                    onPressed: _isSending ? null : _confirmClearConversation,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                    color: Colors.black54,
                  ),
                  TextButton.icon(
                    onPressed: _showQuickActions,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('快捷操作'),
                  ),
                ],
              ),
            ],
          ),
          const Text(
            '智能任务管理 Agent',
            style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<ChatMessageEntity> msgs) {
    final isEmpty = msgs.isEmpty;
    // 截断到最近 N 条参与渲染（与 DAO 上限保持一致，作为防御）
    final shown = msgs.length > _historyMaxFromDb
        ? msgs.sublist(msgs.length - _historyMaxFromDb)
        : msgs;

    final itemCount = (isEmpty ? 1 : shown.length) +
        _pending.length +
        (_pending.isNotEmpty ? 1 : 0) + // pending 提示行
        (_lastError != null ? 1 : 0) +   // 错误卡
        (_isSending ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: itemCount,
      itemBuilder: (ctx, index) {
        // 1) 历史区
        final histLen = isEmpty ? 1 : shown.length;
        if (index < histLen) {
          if (isEmpty) {
            return _buildBubble(isUser: false, text: _welcomeText);
          }
          final m = shown[index];
          return _buildBubble(
            isUser: m.role == 'user',
            text: m.content,
            isSystem: m.role == 'system_summary',
          );
        }

        var cursor = histLen;

        // 2) 待确认提示行 + 卡片们
        if (_pending.isNotEmpty) {
          if (index == cursor) {
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                _pendingHint,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
              ),
            );
          }
          cursor += 1;
          final pendingIdx = index - cursor;
          if (pendingIdx >= 0 && pendingIdx < _pending.length) {
            return _buildConfirmationCard(_pending[pendingIdx]);
          }
          cursor += _pending.length;
        }

        // 3) 错误卡（最近一次）
        if (_lastError != null && index == cursor) {
          return _buildErrorCard(_lastError!);
        }
        if (_lastError != null) cursor += 1;

        // 4) 加载气泡
        if (_isSending && index == cursor) {
          return _buildLoadingBubble();
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildComposer() {
    return Padding(
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
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isSending ? Colors.grey : Colors.black,
                borderRadius: const BorderRadius.all(Radius.circular(24)),
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(AppIcons.send, color: Colors.white),
            ),
          ),
        ],
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
                  const Text(
                    '猫猫在想...',
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

  Widget _buildBubble({
    required bool isUser,
    required String text,
    bool isSystem = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    Color aiBg;
    try { aiBg = scheme.surfaceContainerHigh; } catch (_) { aiBg = const Color(0xFFF5F5F5); }
    final bg = isUser
        ? scheme.primary
        : isSystem
            ? const Color(0xFFE8F5E9)
            : aiBg;
    final fg = isUser ? scheme.onPrimary : (isSystem ? const Color(0xFF2E7D32) : scheme.onSurface);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 0),
              bottomRight: Radius.circular(isUser ? 0 : 16),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              text,
              style: TextStyle(color: fg, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(AiCallError err) {
    final color = _errorColor(err.type);
    final action = _errorAction(err);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        color: color.withAlpha(30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_errorIcon(err.type), color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      err.message,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭提示',
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _lastError = null),
                    icon: const Icon(Icons.close, color: Colors.black54),
                  ),
                ],
              ),
              if (err.detail != null && err.detail!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  err.detail!,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: action == null
                    ? [const SizedBox.shrink()]
                    : [
                        TextButton.icon(
                          onPressed: action.onTap,
                          icon: Icon(action.icon, size: 16),
                          label: Text(action.label),
                          style: TextButton.styleFrom(foregroundColor: color),
                        ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _errorColor(AiErrorType t) {
    switch (t) {
      case AiErrorType.unauthorized:
      case AiErrorType.forbidden:
        return Colors.red.shade700;
      case AiErrorType.notFound:
      case AiErrorType.badRequest:
      case AiErrorType.parseFailed:
        return Colors.orange.shade700;
      case AiErrorType.rateLimited:
      case AiErrorType.timeout:
      case AiErrorType.network:
        return Colors.blueGrey.shade700;
      case AiErrorType.serverError:
      case AiErrorType.unknown:
        return Colors.deepPurple.shade400;
    }
  }

  IconData _errorIcon(AiErrorType t) {
    switch (t) {
      case AiErrorType.unauthorized:
      case AiErrorType.forbidden:
        return Icons.lock_outline;
      case AiErrorType.notFound:
      case AiErrorType.badRequest:
        return Icons.link_off;
      case AiErrorType.parseFailed:
        return Icons.code_off;
      case AiErrorType.rateLimited:
        return Icons.hourglass_top;
      case AiErrorType.timeout:
      case AiErrorType.network:
        return Icons.wifi_off;
      case AiErrorType.serverError:
        return Icons.cloud_off;
      case AiErrorType.unknown:
        return Icons.error_outline;
    }
  }

  _ErrorAction? _errorAction(AiCallError err) {
    switch (err.type) {
      case AiErrorType.unauthorized:
      case AiErrorType.forbidden:
      case AiErrorType.notFound:
      case AiErrorType.badRequest:
        return _ErrorAction(
          label: '前往设置',
          icon: Icons.settings,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AISettingsScreen()),
            );
            // 设置回来后让 aiServiceProvider 重新读
            ref.invalidate(aiServiceProvider);
            if (mounted) setState(() => _lastError = null);
          },
        );
      case AiErrorType.network:
      case AiErrorType.timeout:
      case AiErrorType.rateLimited:
      case AiErrorType.serverError:
        return _ErrorAction(
          label: '重试',
          icon: Icons.refresh,
          onTap: () {
            final last = _lastUserMessage;
            if (last == null || last.isEmpty) return;
            setState(() => _lastError = null);
            _sendMessage(overrideText: last);
          },
        );
      case AiErrorType.parseFailed:
        return _ErrorAction(
          label: '换个模型',
          icon: Icons.swap_horiz,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AISettingsScreen()),
            );
            ref.invalidate(aiServiceProvider);
            if (mounted) setState(() => _lastError = null);
          },
        );
      case AiErrorType.unknown:
        return null;
    }
  }

  Widget _buildConfirmationCard(List<AgentAction> actions) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        color: const Color(0xFFFFF8E1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFFD54F)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '需要确认',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...actions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_right,
                        size: 16,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          action.description,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _cancelActions(actions),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _confirmActions(actions),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('确认执行'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
              leading: const Icon(Icons.bolt, color: Colors.amber),
              title: const Text('优化时间安排'),
              subtitle: const Text('AI 分析当前任务并给出建议'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SchedulingOptimizerScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_task, color: Colors.green),
              title: const Text('创建任务'),
              subtitle: const Text('让 AI 帮你创建新任务'),
              onTap: () {
                Navigator.pop(context);
                _messageController.text = '帮我创建一个任务：';
                _sendMessage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.call_split, color: Colors.purple),
              title: const Text('分解任务'),
              subtitle: const Text('选择一个任务，让 AI 拆解为子任务'),
              onTap: () {
                Navigator.pop(context);
                _showTaskPicker('分解');
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.red),
              title: const Text('调整优先级'),
              subtitle: const Text('选择任务并设置优先级'),
              onTap: () {
                Navigator.pop(context);
                _showTaskPicker('调整优先级');
              },
            ),
            ListTile(
              leading: const Icon(Icons.label, color: Colors.blue),
              title: const Text('加标签/分组'),
              subtitle: const Text('给任务添加标签或设置分组'),
              onTap: () {
                Navigator.pop(context);
                _showTaskPicker('加标签');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.teal),
              title: const Text('完成任务'),
              subtitle: const Text('选择要完成的任务'),
              onTap: () {
                Navigator.pop(context);
                _showTaskPicker('完成');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskPicker(String actionType) {
    final tasks = ref.read(activeTasksProvider).valueOrNull ?? const [];
    if (tasks.isEmpty) {
      _appendDb(
        role: 'assistant',
        content: '当前没有可用任务，请先创建任务。',
        visibleToModel: false,
      );
      _scrollToBottom();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: constraints.maxHeight * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '选择要$actionType的任务',
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
                      String message;
                      switch (actionType) {
                        case '分解':
                          message = '分解任务「${tasks[i].title}」';
                          break;
                        case '调整优先级':
                          message = '调整任务「${tasks[i].title}」的优先级';
                          break;
                        case '加标签':
                          message = '给任务「${tasks[i].title}」加标签和分组';
                          break;
                        case '完成':
                          message = '完成任务「${tasks[i].title}」';
                          break;
                        default:
                          message = '帮我管理任务「${tasks[i].title}」';
                      }
                      _messageController.text = message;
                      _sendMessage();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 错误卡片可执行的单个动作（"前往设置" / "重试" / "换模型"）。
class _ErrorAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ErrorAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}
