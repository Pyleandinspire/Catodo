import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/data/chat_message_dao.dart';
import 'package:catodo/models/chat_message_entity.dart';

void main() {
  ChatMessageEntity make({
    int sessionId = 1,
    required String role,
    required String content,
    required DateTime at,
    bool visibleToModel = true,
  }) {
    return ChatMessageEntity(
      sessionId: sessionId,
      role: role,
      content: content,
      createdAt: at,
      visibleToModel: visibleToModel,
    );
  }

  group('applyRecentWindow', () {
    test('过滤指定 sessionId，其它 session 不可见', () {
      final all = <ChatMessageEntity>[
        make(role: 'user', content: 'a', at: DateTime(2026, 6, 15, 10)),
        make(
          sessionId: 2,
          role: 'user',
          content: 'other',
          at: DateTime(2026, 6, 15, 10, 5),
        ),
        make(role: 'assistant', content: 'b', at: DateTime(2026, 6, 15, 10, 10)),
      ];
      final out = applyRecentWindow(all, sessionId: 1);
      expect(out.map((m) => m.content).toList(), ['a', 'b']);
    });

    test('按 createdAt 升序输出（最旧在前）', () {
      final all = <ChatMessageEntity>[
        make(role: 'user', content: 'late', at: DateTime(2026, 6, 15, 12)),
        make(role: 'user', content: 'early', at: DateTime(2026, 6, 15, 9)),
        make(role: 'user', content: 'mid', at: DateTime(2026, 6, 15, 11)),
      ];
      final out = applyRecentWindow(all, sessionId: 1);
      expect(out.map((m) => m.content).toList(), ['early', 'mid', 'late']);
    });

    test('limit 截断为最近 N 条', () {
      final all = List.generate(
        10,
        (i) => make(
          role: 'user',
          content: 'm$i',
          at: DateTime(2026, 6, 15, 9, i),
        ),
      );
      final out = applyRecentWindow(all, sessionId: 1, limit: 3);
      // m7 / m8 / m9 是最近的三条
      expect(out.map((m) => m.content).toList(), ['m7', 'm8', 'm9']);
    });

    test('空集合返回空列表', () {
      final out = applyRecentWindow(const <ChatMessageEntity>[], sessionId: 1);
      expect(out, isEmpty);
    });

    test('clear 模拟：仅清掉指定 session 后，剩余其它 session 不变', () {
      final all = <ChatMessageEntity>[
        make(role: 'user', content: 's1-a', at: DateTime(2026, 6, 15, 10)),
        make(
          sessionId: 2,
          role: 'user',
          content: 's2-a',
          at: DateTime(2026, 6, 15, 10, 5),
        ),
      ];
      final remain = all.where((m) => m.sessionId != 1).toList();
      final s1 = applyRecentWindow(remain, sessionId: 1);
      final s2 = applyRecentWindow(remain, sessionId: 2);
      expect(s1, isEmpty);
      expect(s2.map((m) => m.content).toList(), ['s2-a']);
    });
  });

  group('ChatMessageEntity.now 工厂', () {
    test('默认 visibleToModel=true，createdAt 不为空', () {
      final m = ChatMessageEntity.now(
        sessionId: 1,
        role: 'assistant',
        content: 'hi',
      );
      expect(m.visibleToModel, true);
      expect(m.createdAt, isNotNull);
    });

    test('visibleToModel=false 透传', () {
      final m = ChatMessageEntity.now(
        sessionId: 1,
        role: 'assistant',
        content: 'hidden',
        visibleToModel: false,
      );
      expect(m.visibleToModel, false);
    });
  });
}
