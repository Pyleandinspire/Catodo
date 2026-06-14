import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../models/chat_message_entity.dart';

/// 聊天消息数据访问层。
///
/// 单会话 MVP：所有方法默认 `sessionId = 1`，保留参数为多会话铺路。
class ChatMessageDao {
  static const int defaultSessionId = 1;

  final Isar isar;

  ChatMessageDao(this.isar);

  /// 拉取最近 [limit] 条该会话的消息，按 `createdAt` 升序返回（最旧在前）。
  Future<List<ChatMessageEntity>> getRecent({
    int sessionId = defaultSessionId,
    int limit = 200,
  }) async {
    final desc = await isar.chatMessageEntitys
        .filter()
        .sessionIdEqualTo(sessionId)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
    return desc.reversed.toList();
  }

  /// 监听该会话的最近 [limit] 条消息。
  ///
  /// 用 `watchLazy()` 监听任意写入再重新拉取一次窗口数据，
  /// 避免对所有变更下游全量发射；首次立即吐出当前快照。
  Stream<List<ChatMessageEntity>> watchRecent({
    int sessionId = defaultSessionId,
    int limit = 200,
  }) async* {
    yield await getRecent(sessionId: sessionId, limit: limit);
    final lazyStream = isar.chatMessageEntitys.watchLazy();
    await for (final _ in lazyStream) {
      yield await getRecent(sessionId: sessionId, limit: limit);
    }
  }

  /// 追加一条消息并返回写入后的实体（含分配的 id）。
  Future<ChatMessageEntity> append(ChatMessageEntity msg) async {
    await isar.writeTxn(() async {
      await isar.chatMessageEntitys.put(msg);
    });
    return msg;
  }

  /// 物理删除该会话的全部消息。
  Future<void> clearSession({int sessionId = defaultSessionId}) async {
    await isar.writeTxn(() async {
      await isar.chatMessageEntitys
          .filter()
          .sessionIdEqualTo(sessionId)
          .deleteAll();
    });
  }

  /// 该会话的消息总数。
  Future<int> count({int sessionId = defaultSessionId}) async {
    return isar.chatMessageEntitys
        .filter()
        .sessionIdEqualTo(sessionId)
        .count();
  }
}

/// 纯 Dart 实现的"窗口排序与截断"逻辑，与 [ChatMessageDao.getRecent] 等价。
///
/// 抽出来便于在不引入 Isar 原生二进制的情况下，对核心规则做单元测试：
/// - 仅保留指定 sessionId；
/// - 按 createdAt 降序取最近 [limit] 条；
/// - 然后反转为升序输出，便于 UI 直接渲染。
@visibleForTesting
List<ChatMessageEntity> applyRecentWindow(
  List<ChatMessageEntity> all, {
  required int sessionId,
  int limit = 200,
}) {
  final filtered = all.where((m) => m.sessionId == sessionId).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final desc = filtered.take(limit).toList();
  return desc.reversed.toList();
}

