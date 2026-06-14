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
    test('user / assistant / system_summary 角色映射正确', () {
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
      expect(turns.length, 3);
      expect(turns[0].role, 'user');
      expect(turns[0].content, 'u1');
      expect(turns[1].role, 'assistant');
      expect(turns[2].role, 'assistant');
      expect(turns[2].content, '已执行: 完成任务 X');
    });

    test('过滤 visibleToModel=false', () {
      final msgs = [
        make(role: 'user', content: 'u1', at: DateTime(2026, 6, 15, 9)),
        make(
          role: 'assistant',
          content: '请先在设置中配置 AI 助手的 API 参数。',
          at: DateTime(2026, 6, 15, 9, 1),
          visibleToModel: false,
        ),
        make(role: 'assistant', content: 'a1', at: DateTime(2026, 6, 15, 9, 2)),
      ];
      final turns = messagesToTurns(msgs);
      expect(turns.map((t) => t.content).toList(), ['u1', 'a1']);
    });

    test('保留输入顺序', () {
      final msgs = [
        make(role: 'user', content: '1', at: DateTime(2026, 6, 15, 9)),
        make(role: 'assistant', content: '2', at: DateTime(2026, 6, 15, 10)),
        make(role: 'user', content: '3', at: DateTime(2026, 6, 15, 11)),
        make(role: 'assistant', content: '4', at: DateTime(2026, 6, 15, 12)),
      ];
      final turns = messagesToTurns(msgs);
      expect(turns.map((t) => t.content).toList(), ['1', '2', '3', '4']);
    });

    test('与 truncateChatHistory 配合：保留最近 maxTurns*2', () {
      // 6 轮（12 条） + maxTurns=4 → 期望保留最近 8 条
      final msgs = <ChatMessageEntity>[];
      for (var i = 0; i < 6; i++) {
        msgs.add(make(
          role: 'user',
          content: 'u$i',
          at: DateTime(2026, 6, 15, 9, i * 2),
        ));
        msgs.add(make(
          role: 'assistant',
          content: 'a$i',
          at: DateTime(2026, 6, 15, 9, i * 2 + 1),
        ));
      }
      final turns = messagesToTurns(msgs);
      expect(turns.length, 12);
      final clipped = truncateChatHistory(turns, maxTurns: 4);
      expect(clipped.length, 8);
      expect(clipped.first.content, 'u2');
      expect(clipped.last.content, 'a5');
    });

    test('未知角色按 assistant 处理（保险分支）', () {
      final msgs = [
        make(role: 'tool_call', content: 'whatever', at: DateTime(2026, 6, 15)),
      ];
      final turns = messagesToTurns(msgs);
      expect(turns.length, 1);
      expect(turns.first.role, 'assistant');
    });

    test('空集合返回空列表', () {
      expect(messagesToTurns(const <ChatMessageEntity>[]), isEmpty);
    });
  });
}
