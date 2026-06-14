import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/chat_message_dao.dart';
import '../models/chat_message_entity.dart';
import '../services/ai_service.dart';
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

/// 从 SharedPreferences 加载 AIService。
///
/// 配置不完整时返回 null，UI 层需引导用户进入设置。
/// PLAN-AI-001-2 落地后 apiKey 读取将切到 SecureStore。
final aiServiceProvider = FutureProvider<AIService?>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('ai_api_key') ?? '';
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

/// 把持久化消息映射为可发给 LLM 的 [ChatTurn] 列表。
///
/// 规则：
/// - 过滤 `visibleToModel == false`；
/// - role 映射：'user' → ChatTurn.user；
///   'assistant' / 'system_summary' → ChatTurn.assistant；
///   其他角色（保险起见）按 assistant 处理；
/// - 输入应已按 `createdAt` 升序，输出原序保留。
@visibleForTesting
List<ChatTurn> messagesToTurns(Iterable<ChatMessageEntity> messages) {
  final out = <ChatTurn>[];
  for (final m in messages) {
    if (!m.visibleToModel) continue;
    if (m.role == 'user') {
      out.add(ChatTurn.user(m.content));
    } else {
      out.add(ChatTurn.assistant(m.content));
    }
  }
  return out;
}
