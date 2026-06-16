import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task_dao.dart';
import '../../models/task.dart';
import '../../providers/chat_provider.dart';
import '../../providers/isar_provider.dart';
import '../../providers/task_providers.dart';
import '../../services/ai_agent.dart';
import '../../services/ai_service.dart';
import '../../services/notification_service.dart';

/// AI 时间安排优化助手屏（PLAN-AI-001-4）。
///
/// 流程：进屏 → 自动构造任务上下文 → 请求 LLM → 渲染建议卡片 → 用户逐项 / 全部应用。
class SchedulingOptimizerScreen extends ConsumerStatefulWidget {
  const SchedulingOptimizerScreen({super.key});

  @override
  ConsumerState<SchedulingOptimizerScreen> createState() =>
      _SchedulingOptimizerScreenState();
}

class _SchedulingOptimizerScreenState
    extends ConsumerState<SchedulingOptimizerScreen> {
  bool _loading = true;
  SchedulingPlan? _plan;
  AiCallError? _error;

  /// 已应用 / 已忽略的建议 id；UI 据此显示状态。
  final Set<String> _applied = {};
  final Set<String> _ignored = {};
  final Map<String, String> _failed = {}; // id → message

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAnalysis());
  }

  Future<void> _runAnalysis() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _plan = null;
    });

    final ai = ref.read(aiServiceProvider).valueOrNull;
    if (ai == null) {
      setState(() {
        _loading = false;
        _error = const AiCallError(
          type: AiErrorType.unauthorized,
          message: '未配置 AI',
          detail: '请先到设置中配置 API Key 与模型'
        );
      });
      return;
    }

    final tasks = ref.read(activeTasksProvider).valueOrNull ?? const <Task>[];
    final ctx = buildTaskContext(tasks);

    // 简单统计近 14 天的完成 / 逾期情况注入 extraNote
    final now = DateTime.now();
    final since = now.subtract(const Duration(days: 14));
    int completedRecently = 0;
    int overdueNow = 0;
    for (final t in tasks) {
      if (t.isCompleted && t.updatedAt.isAfter(since)) completedRecently++;
      if (!t.isCompleted &&
          t.dueDate != null &&
          t.dueDate!.isBefore(now)) {
        overdueNow++;
      }
    }
    final extra =
        '近 14 天完成 $completedRecently；当前逾期未处理 $overdueNow。';

    final r = await ai.requestSchedulingPlanDetailed(
      taskContext: ctx,
      extraNote: extra,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _plan = r.plan;
      _error = r.error;
    });
  }

  Future<void> _applySuggestion(SchedulingSuggestion s) async {
    final isar = ref.read(isarProvider).valueOrNull;
    if (isar == null) return;
    final dao = TaskDao(isar);

    // 高风险：completeOrDrop 必须二次确认
    if (s.type == SchedulingSuggestionType.completeOrDrop) {
      final ok = await _confirmCompleteOrDrop(s);
      if (ok == null) return;
      try {
        if (ok == 'complete') {
          final res = await executeAction(
            AgentAction(
              type: AgentActionType.completeTask,
              params: {'taskId': s.taskId},
            ),
            dao,
          );
          _markApplied(s, res);
        } else {
          final res = await executeAction(
            AgentAction(
              type: AgentActionType.deleteTask,
              params: {'taskId': s.taskId},
            ),
            dao,
          );
          _markApplied(s, res);
        }
      } catch (e) {
        if (mounted) setState(() => _failed[s.id] = '$e');
      }
      return;
    }

    final res = await applySchedulingSuggestion(s, dao);
    _markApplied(s, res);

    // 如果 reschedule / addReminder 改了通知触发条件，刷一次
    if (res.success && res.data is Task) {
      try {
        await NotificationService().rescheduleAllReminders([res.data as Task]);
      } catch (_) {}
    }
  }

  void _markApplied(SchedulingSuggestion s, ActionResult res) {
    if (!mounted) return;
    setState(() {
      if (res.success) {
        _applied.add(s.id);
        _failed.remove(s.id);
      } else {
        _failed[s.id] = res.message;
      }
    });
  }

  Future<String?> _confirmCompleteOrDrop(SchedulingSuggestion s) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('完成或关闭任务？'),
        content: Text('原因：${s.reason}\n\n你想：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'complete'),
            child: const Text('标记完成'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'drop'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除任务'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyAll() async {
    final plan = _plan;
    if (plan == null) return;
    for (final s in plan.suggestions) {
      if (_applied.contains(s.id) || _ignored.contains(s.id)) continue;
      // 全部应用时跳过高风险，让用户主动确认
      if (s.type == SchedulingSuggestionType.completeOrDrop) continue;
      await _applySuggestion(s);
    }
  }

  void _ignoreAll() {
    final plan = _plan;
    if (plan == null) return;
    setState(() {
      for (final s in plan.suggestions) {
        if (!_applied.contains(s.id)) _ignored.add(s.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('优化时间安排'),
        actions: [
          IconButton(
            tooltip: '重新分析',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _runAnalysis,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('正在分析你的任务安排…'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!.message, textAlign: TextAlign.center),
              if (_error!.detail != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!.detail!,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _runAnalysis,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    final plan = _plan;
    if (plan == null) {
      return const Center(child: Text('暂无建议'));
    }
    if (plan.suggestions.isEmpty && plan.issues.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.task_alt, size: 56, color: Colors.green),
              const SizedBox(height: 12),
              Text(plan.summary.isEmpty ? '安排看起来不错' : plan.summary,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (plan.summary.isNotEmpty) _buildSummaryCard(plan.summary),
        if (plan.issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('识别到的问题',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...plan.issues.map(_buildIssueCard),
        ],
        if (plan.suggestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('优化建议',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...plan.suggestions.map(_buildSuggestionCard),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: _ignoreAll,
                icon: const Icon(Icons.close),
                label: const Text('全部忽略'),
              ),
              FilledButton.icon(
                onPressed: _applyAll,
                icon: const Icon(Icons.done_all),
                label: const Text('全部应用'),
              ),
            ],
          ),
        ],
        if (plan.warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '（已忽略未知建议类型：${plan.warnings.join(", ")}）',
            style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryCard(String summary) {
    return Card(
      color: const Color(0xFFE3F2FD),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.insights, color: Color(0xFF1565C0)),
            const SizedBox(width: 12),
            Expanded(child: Text(summary)),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueCard(SchedulingIssue issue) {
    final ids = issue.taskIds.isEmpty
        ? ''
        : '（涉及 [${issue.taskIds.join(', ')}]）';
    final dateStr = issue.date != null ? '${issue.date} · ' : '';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.warning_amber, color: Colors.orange),
        title: Text('$dateStr${issue.note}'),
        subtitle: ids.isEmpty
            ? null
            : Text(ids, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  Widget _buildSuggestionCard(SchedulingSuggestion s) {
    final isApplied = _applied.contains(s.id);
    final isIgnored = _ignored.contains(s.id);
    final failedMsg = _failed[s.id];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(s.type), size: 18, color: _colorFor(s.type)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isApplied)
                  const Icon(Icons.check_circle, color: Colors.green),
                if (isIgnored)
                  const Icon(Icons.cancel, color: Colors.grey),
              ],
            ),
            if (s.reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(s.reason,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
            if (s.type == SchedulingSuggestionType.decompose &&
                s.subtasks != null) ...[
              const SizedBox(height: 8),
              ...s.subtasks!.map((st) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 2),
                    child: Text(
                      '• ${st['title'] ?? ''}'
                      '${st['priority'] != null ? '（优先级 ${st['priority']}）' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )),
            ],
            if (failedMsg != null) ...[
              const SizedBox(height: 6),
              Text('应用失败：$failedMsg',
                  style:
                      const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isApplied && !isIgnored)
                  TextButton(
                    onPressed: () => setState(() => _ignored.add(s.id)),
                    child: const Text('忽略'),
                  ),
                const SizedBox(width: 8),
                if (!isApplied)
                  FilledButton.icon(
                    onPressed: isIgnored ? null : () => _applySuggestion(s),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('应用'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(SchedulingSuggestionType t) {
    switch (t) {
      case SchedulingSuggestionType.reschedule:
        return Icons.update;
      case SchedulingSuggestionType.decompose:
        return Icons.call_split;
      case SchedulingSuggestionType.setPriority:
        return Icons.flag;
      case SchedulingSuggestionType.completeOrDrop:
        return Icons.delete_sweep;
      case SchedulingSuggestionType.addReminder:
        return Icons.alarm_add;
    }
  }

  Color _colorFor(SchedulingSuggestionType t) {
    switch (t) {
      case SchedulingSuggestionType.reschedule:
        return Colors.blue;
      case SchedulingSuggestionType.decompose:
        return Colors.purple;
      case SchedulingSuggestionType.setPriority:
        return Colors.red;
      case SchedulingSuggestionType.completeOrDrop:
        return Colors.brown;
      case SchedulingSuggestionType.addReminder:
        return Colors.teal;
    }
  }
}
