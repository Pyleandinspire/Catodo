import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/chat_message_dao.dart';
import '../models/chat_message_entity.dart';
import '../services/ai_service.dart';
import '../services/secure_store.dart';
import 'isar_provider.dart';

/// ChatMessageDao 依赖 isarProvider 就绪后的 Isar 实例。
final chatMessageDaoProvider = Provider<ChatMessageDao>((ref) {
  final isar = ref.watch(isarProvider).requireValue;
  return ChatMessageDao(isar);
});

/// 监听最近若干条聊天消息（升序）。UI 层直接消费此 stream。
final chatMessagesProvider =
    StreamProvider<List<ChatMessageEntity>>((ref) async* {
  final dao = ref.watch(chatMessageDaoProvider);
  yield* dao.watchRecent();
});

/// 从 SecureStore + SharedPreferences 加载 AIService。
///
/// 配置不完整时返回 null，UI 层需引导用户进入设置。
final aiServiceProvider = FutureProvider<AIService?>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = await SecureStore.instance.readAiApiKey() ?? '';
    final apiUrl = prefs.getString('ai_api_url') ?? '';
    final model = prefs.getString('ai_model') ?? '';
    final providerId = prefs.getString('ai_provider_id') ?? 'custom';

    if (apiKey.isEmpty || apiUrl.isEmpty || model.isEmpty) {
      return null;
    }

    return AIService(
      AIConfig(
        providerId: providerId,
        apiKey: apiKey,
        apiUrl: apiUrl,
        modelName: model,
      ),
    );
  } catch (e) {
    debugPrint('aiServiceProvider 初始化失败: $e');
    return null;
  }
});

/// 从外部（如 task_list_screen 的逾期按钮）传来的初始消息。
/// ChatScreen 在首帧渲染后读取并自动发送，发送后清空。
final chatInitialMessageProvider = StateProvider<String?>((ref) => null);

/// 全局 Tab 切换：task_list_screen 等可通过此 Provider 切到聊天 Tab（index=2）。
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// 把持久化消息映射为可发给 LLM 的 [ChatTurn] 列表。
///
/// **方案 F**：仅保留 user 角色消息。assistant / system_summary 等不进 LLM 上下文。
/// 防止 LLM 看到历史执行记录后重复之前的操作。
/// LLM 每轮都通过注入的 `buildTaskContext` 获取最新任务状态，不依赖历史。
@visibleForTesting
List<ChatTurn> messagesToTurns(Iterable<ChatMessageEntity> messages) {
  final out = <ChatTurn>[];
  for (final m in messages) {
    if (!m.visibleToModel) continue;
    if (m.role == 'user') {
      out.add(ChatTurn.user(m.content));
    }
    // 所有非 user 消息不进 LLM
  }
  return out;
}
