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
  final String? initialMessage;
  const ChatScreen({super.key, this.initialMessage});

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

  /// 上次 query_tasks 的结果，下一轮注入上下文
  List<Task>? _lastQueryResults;

  /// 上一轮执行的操作摘要，下一轮追加到 user prompt（方案 B）
  String? _pendingContextNote;

  static const String _welcomeBase =
      '你好！我是 AI 助手，可以直接帮你管理任务：\n'
      '1. 创建任务 - "帮我创建一个高优先级任务：完成报告"\n'
      '2. 分解任务 - "分解任务「学习 Flutter」"\n'
      '3. 调整优先级 - "把任务「买牛奶」设为低优先级"\n'
      '4. 加标签/分组 - "给任务加标签「紧急」"\n'
      '5. 完成/删除 - "完成任务「买牛奶」"\n'
      '6. 自由对话 - 直接输入你的问题';

  String _buildWelcome() {
    final tasks = ref.read(activeTasksProvider).valueOrNull ?? const [];
    final active = tasks.where((t) => !t.isCompleted).length;
    final completed = tasks.length - active;
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final todayCount = tasks.where((t) => !t.isCompleted && t.dueDate != null && t.dueDate!.isBefore(todayEnd)).length;
    if (active == 0 && completed == 0) return _welcomeBase;
    final buf = StringBuffer('你好！');
    if (active > 0) buf.write(' 你今天有 $active 个任务');
    if (todayCount > 0) buf.write('，其中 $todayCount 个今天截止');
    if (completed > 0) buf.write('。已完成 $completed 个');
    buf.writeln('。\n\n我可以帮你创建、分解、调整优先级、加标签等，直接跟我说就好。');
    return buf.toString();
  }

  static const String _pendingHint = '未确认的操作仅在本次会话有效，关闭或切走即过期。';

  @override
  void initState() {
    super.initState();
    // 从外部带入的消息（如逾期 ❤️），等首帧渲染后自动发送
    // 监听外部传入的消息（逾期按钮等），切 Tab 过来也能触发
    ref.listenManual(chatInitialMessageProvider, (prev, next) {
      if (next != null && next.isNotEmpty) {
        ref.read(chatInitialMessageProvider.notifier).state = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _sendMessage(overrideText: next);
        });
      }
    });
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

    // 等待 AI Service 就绪：Provider 可能在启动后首次加载（读 SecureStore/SP）
    final ai = await ref.read(aiServiceProvider.future)
        .timeout(const Duration(seconds: 3), onTimeout: () => null);
    if (ai == null) {
      // 超时 3s 或真的未配置 → 提示用户
      await _appendDb(
        role: 'assistant',
        content: '请先在设置中配置 AI 助手的 API 参数。',
        visibleToModel: false,
      );
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
      return;
    }

    try {
      // 任务上下文
      final tasks = ref.read(activeTasksProvider).valueOrNull ?? const [];
      var context = buildTaskContext(tasks);

      // 追加上次 query_tasks 结果
      final lastQuery = _lastQueryResults;
      if (lastQuery != null && lastQuery.isNotEmpty) {
        context += '\n【上次查询结果（共 ${lastQuery.length} 条，可用 taskId 操作）】\n';
        for (final t in lastQuery.take(20)) {
          context += '- [id:${t.id}] ${t.title} | 优先级:${t.priority}${t.groupName != null ? ' | 分组:${t.groupName}' : ''}\n';
        }
        _lastQueryResults = null; // 只注入一次
      }

      // 多轮历史从持久化派生（不含本轮 user，因为 ChatTurn 由 latestUserMessage 单独传）
      final messagesNow = ref.read(chatMessagesProvider).valueOrNull ?? const [];
      final priorMessages = messagesNow.isNotEmpty
          ? messagesNow.sublist(0, messagesNow.length - 1)
          : const <ChatMessageEntity>[];
      final history = messagesToTurns(priorMessages);

      // 方案 E：加隐式指令防重复 + 方案 B：追加上轮执行摘要
      final note = _pendingContextNote;
      _pendingContextNote = null;
      final effectivePrompt = StringBuffer('（只处理本条消息，不要重复上下文中的操作。）');
      if (note != null && note!.isNotEmpty) effectivePrompt.write('\n$note');
      effectivePrompt.write('\n$text');

      final r = await ai.requestAgentActionDetailedWithHistory(
        history: history,
        latestUserMessage: effectivePrompt.toString(),
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

      // 拆分 query / 自动 / 待确认
      final queryActions = <AgentAction>[];
      final autoActions = <AgentAction>[];
      final confirmActions = <AgentAction>[];
      for (final a in response.actions) {
        if (a.type == AgentActionType.queryTasks) {
          queryActions.add(a);
        } else if (a.needsConfirmation) {
          confirmActions.add(a);
        } else {
          autoActions.add(a);
        }
      }

      // queryTasks：用完整 DAO 查询 → 存入 _lastQueryResults 给下一轮上下文
      if (queryActions.isNotEmpty) {
        final isar = ref.read(isarProvider).valueOrNull;
        if (isar != null) {
          final dao = TaskDao(isar);
          final allTasks = await dao.getAllActiveTasks();
          var results = allTasks;
          for (final q in queryActions) {
            results = _applyQueryFilter(results, q.params);
          }
          if (mounted) setState(() => _lastQueryResults = results);
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
      // 追加 query_tasks 结果到回复
      final qr = _lastQueryResults;
      if (qr != null && qr.isNotEmpty) {
        replyBuffer.write('\n\n找到 ${qr.length} 个匹配任务：');
        for (final t in qr.take(10)) {
          replyBuffer.write('\n- [id:${t.id}] ${t.title}');
        }
        if (qr.length > 10) replyBuffer.write('\n…还有 ${qr.length - 10} 个');
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

    // 执行摘要入历史（一行简短格式，避免 LLM 被长执行日志干扰后重复执行）
    final parts = <String>[];
    for (final r in results) {
      parts.add(r.message.replaceAll('\n', ' '));
    }
    final summary = parts.join('；');
    await _appendDb(
      role: 'system_summary',
      content: summary,
      visibleToModel: false, // 方案 G：执行摘要不让 LLM 看到，防止重复执行
    );

    // 方案 B：下一轮 user prompt 追加执行摘要
    _pendingContextNote = '（上轮已完成：$summary）';

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
            _buildQuickChips(),
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
              Text(
                'AI 助手',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                tooltip: '清空对话',
                onPressed: _isSending ? null : _confirmClearConversation,
                icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          Text(
            '智能任务管理 Agent',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            return _buildBubble(isUser: false, text: _buildWelcome());
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _messageController,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: _isSending
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(AppIcons.send, color: scheme.onSurfaceVariant, size: 24),
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

  Widget _buildQuickChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          ActionChip(
            avatar: const Icon(Icons.bolt, size: 16),
            label: const Text('优化'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SchedulingOptimizerScreen())),
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.add, size: 16),
            label: const Text('创建'),
            onPressed: () { _messageController.text = '帮我创建一个任务：'; _sendMessage(); },
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.call_split, size: 16),
            label: const Text('分解'),
            onPressed: () => _showTaskPicker('分解'),
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.flag, size: 16),
            label: const Text('优先级'),
            onPressed: () => _showTaskPicker('调整优先级'),
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.label, size: 16),
            label: const Text('标签'),
            onPressed: () => _showTaskPicker('加标签'),
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.check_circle, size: 16),
            label: const Text('完成'),
            onPressed: () => _showTaskPicker('完成'),
          ),
        ]),
      ),
    );
  }

  /// 在内存中用 query params 过滤任务列表
  List<Task> _applyQueryFilter(List<Task> tasks, Map<String, dynamic> params) {
    var results = tasks;
    if (params['keyword'] is String && (params['keyword'] as String).isNotEmpty) {
      final k = (params['keyword'] as String).toLowerCase();
      results = results.where((t) => t.title.toLowerCase().contains(k)).toList();
    }
    final tag = params['tag'];
    if (tag is String && tag.isNotEmpty) {
      results = results.where((t) => t.tags.any((x) => x == tag)).toList();
    }
    final group = params['groupName'];
    if (group is String && group.isNotEmpty && group != 'null') {
      results = results.where((t) => t.groupName == group).toList();
    }
    if (params['priority'] != null) {
      final p = params['priority'] is int ? params['priority'] as int : int.tryParse(params['priority'].toString());
      if (p != null) results = results.where((t) => t.priority == p).toList();
    }
    final completed = params['isCompleted'];
    if (completed is bool) {
      results = results.where((t) => t.isCompleted == completed).toList();
    }
    final limit = params['limit'];
    if (limit is int && limit > 0 && results.length > limit) {
      results = results.sublist(0, limit);
    } else if (results.length > 20) {
      results = results.sublist(0, 20); // 默认截断
    }
    return results;
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
