import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_store.dart';

/// 一次性把 SharedPreferences 中的明文敏感凭据迁移到 [SecureStore]。
///
/// 设计要点（PLAN-AI-001-2）：
/// - 读取 SharedPreferences 中的旧 key（`ai_api_key` / `webdav_password`），非空则写入 SecureStore，
///   随后从 SP 中删除。
/// - 用 SP 标志位 `secrets_migrated_v1` 防止重复迁移。
/// - 任意一步失败都不抛异常：仅 debugPrint 并跳过，不阻塞应用启动。
const String _kMigratedFlag = 'secrets_migrated_v1';
const String _kLegacyAiApiKey = 'ai_api_key';
const String _kLegacyWebDavPassword = 'webdav_password';

Future<void> migrateLegacySecretsIfNeeded({
  SharedPreferences? prefs,
  SecureStore? store,
}) async {
  try {
    final sp = prefs ?? await SharedPreferences.getInstance();
    if (sp.getBool(_kMigratedFlag) == true) return;

    final secureStore = store ?? SecureStore.instance;

    final legacyApiKey = sp.getString(_kLegacyAiApiKey);
    if (legacyApiKey != null && legacyApiKey.isNotEmpty) {
      await secureStore.writeAiApiKey(legacyApiKey);
      await sp.remove(_kLegacyAiApiKey);
    }

    final legacyPassword = sp.getString(_kLegacyWebDavPassword);
    if (legacyPassword != null && legacyPassword.isNotEmpty) {
      await secureStore.writeWebDavPassword(legacyPassword);
      await sp.remove(_kLegacyWebDavPassword);
    }

    await sp.setBool(_kMigratedFlag, true);
    debugPrint('secrets_migration: migrated legacy secrets to SecureStore');
  } catch (e) {
    debugPrint('secrets_migration failed (ignored): $e');
  }
}
