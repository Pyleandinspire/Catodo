import 'package:isar/isar.dart';

part 'chat_message_entity.g.dart';

/// 聊天消息持久化实体（Isar collection）
///
/// 设计说明（详见 PLAN-AI-001-5）：
/// - `sessionId`：MVP 阶段固定为 1（默认会话），保留字段为多会话切换铺路。
/// - `role`：取值 `'user' | 'assistant' | 'system_summary'`。
///   `system_summary` 用于"已执行操作摘要"等系统补述，与 user/assistant 同样进入 LLM 历史。
/// - `visibleToModel`：是否参与 LLM 多轮记忆派生。`false` 用于"取消提示" /
///   "数据库未就绪" 等仅 UI 层意义的提示，避免污染模型上下文。
///
/// 不持久化"待确认 actions"——它们是易朽的会话内 UI 状态，重启后即过期。
@collection
class ChatMessageEntity {
  Id id = Isar.autoIncrement;

  @Index()
  late int sessionId;

  late String role;

  late String content;

  @Index()
  late DateTime createdAt;

  bool visibleToModel = true;

  ChatMessageEntity({
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.visibleToModel = true,
  });

  /// 便捷工厂：用当前时间作为 createdAt。
  factory ChatMessageEntity.now({
    required int sessionId,
    required String role,
    required String content,
    bool visibleToModel = true,
  }) {
    return ChatMessageEntity(
      sessionId: sessionId,
      role: role,
      content: content,
      createdAt: DateTime.now(),
      visibleToModel: visibleToModel,
    );
  }
}
