import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/models/chat_message_entity.dart';
import 'package:catodo/providers/chat_provider.dart';
import 'package:catodo/services/ai_service.dart';

void main() {
  ChatMessageEntity make({
    required String role,
    required String content,
    required DateTime at,
    bool visibleToModel = true,
  }) {
    return ChatMessageEntity(
      sessionId: 1,
      role: role,
      content: content,
      createdAt: at,
      visibleToModel: visibleToModel,
    );
  }

  group('messagesToTurns', () {
    test('方案 F：仅保留 user 消息，assistant/system_summary 不进 LLM', () {
      final msgs = [
        make(role: 'user', content: 'u1', at: DateTime(2026, 6, 15, 9)),
        make(role: 'assistant', content: 'a1', at: DateTime(2026, 6, 15, 10)),
        make(
          role: 'system_summary',
          content: '已执行: 完成任务 X',
          at: DateTime(2026, 6, 15, 11),
        ),
      ];
      final turns = messagesToTurns(msgs);
      expect(turns.length, 1);
      expect(turns[0].role, 'user');
      expect(turns[0].content, 'u1');
    });

    test('过滤 visibleToModel=false', () {
      final msgs = [
        make(role: 'user', content: 'u1', at: DateTime(2026, 6, 15, 9)),
        make(
          role: 'user',
          content: 'hidden question',
          at: DateTime(2026, 6, 15, 9, 1),
          visibleToModel: false,
        ),
        make(role: 'user', content: 'u2', at: DateTime(2026, 6, 15, 9, 2)),
      ];
      final turns = messagesToTurns(msgs);
      expect(turns.map((t) => t.content).toList(), ['u1', 'u2']);
    });

    test('保留输入顺序（仅 user）', () {
      final msgs = [
        make(role: 'user', content: '1', at: DateTime(2026, 6, 15, 9)),
        make(role: 'assistant', content: 'ignored', at: DateTime(2026, 6, 15, 10)),
        make(role: 'user', content: '3', at: DateTime(2026, 6, 15, 11)),
        make(role: 'assistant', content: 'ignored', at: DateTime(2026, 6, 15, 12)),
      ];
      final turns = messagesToTurns(msgs);
      expect(turns.map((t) => t.content).toList(), ['1', '3']);
    });

    test('与 truncateChatHistory 配合：user-only 后截断', () {
      // 3 条 user → 3 个 ChatTurn；maxTurns=1 → 保留最近 2 条
      final msgs = <ChatMessageEntity>[];
      for (var i = 0; i < 3; i++) {
        msgs.add(make(role: 'user', content: 'u$i', at: DateTime(2026, 6, 15, 9, i * 2)));
        msgs.add(make(role: 'assistant', content: 'a$i', at: DateTime(2026, 6, 15, 9, i * 2 + 1)));
      }
      final turns = messagesToTurns(msgs);
      expect(turns.length, 3);
      expect(turns.map((t) => t.content).toList(), ['u0', 'u1', 'u2']);
      final clipped = truncateChatHistory(turns, maxTurns: 1);
      expect(clipped.length, 2);
      expect(clipped.first.content, 'u1');
      expect(clipped.last.content, 'u2');
    });

    test('未知角色不进入', () {
      final msgs = [
        make(role: 'tool_call', content: 'whatever', at: DateTime(2026, 6, 15)),
      ];
      final turns = messagesToTurns(msgs);
      expect(turns, isEmpty);
    });

    test('空集合返回空列表', () {
      expect(messagesToTurns(const <ChatMessageEntity>[]), isEmpty);
    });
  });
}
