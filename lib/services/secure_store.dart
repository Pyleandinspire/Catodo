import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'encrypted_local_store.dart';

/// 凭据存储策略。
///
/// - [auto]：首选 Keychain；写失败时由 UI 引导用户选择 [appEncrypted]。
/// - [keychainOnly]：只用 Keychain，写失败抛错（合规优先）。
/// - [appEncrypted]：完全走应用级 AES-GCM（即使 Keychain 可用）。
enum SecureStoreStrategy {
  auto('auto'),
  keychainOnly('keychain_only'),
  appEncrypted('app_encrypted');

  final String value;
  const SecureStoreStrategy(this.value);

  static SecureStoreStrategy fromString(String? v) {
    for (final s in SecureStoreStrategy.values) {
      if (s.value == v) return s;
    }
    return SecureStoreStrategy.auto;
  }
}

/// 系统级安全凭据存储（PLAN-AI-001-2 + PLAN-AI-001-6 + PLAN-AI-001-7）。
///
/// 三档：
/// 1. **Keychain**（FlutterSecureStorage）；
/// 2. **应用级 AES-GCM**（[EncryptedLocalStore]）— Keychain 不可用时的回退；
/// 3. 异常透传，**绝不静默写明文**。
///
/// 当前 strategy 决定优先顺序；可通过 [setStrategy] 持久化用户选择。
class SecureStore {
  static const _kAiApiKey = 'secure.ai_api_key';
  static const _kWebDavPassword = 'secure.webdav_password';
  static const _kStrategyPref = 'secure.store_strategy_v1';
  // 用作"app-encrypted 模式"下 EncryptedLocalStore 的主密钥的 Keychain key
  static const _kMasterKey = 'secure.master_key';

  static SecureStore? _instance;

  static SecureStore get instance => _instance ??= SecureStore._(
        const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        ),
      );

  /// 测试注入。
  @visibleForTesting
  static void overrideForTest(
    FlutterSecureStorage storage, {
    EncryptedLocalStore? encryptedStore,
  }) {
    _instance = SecureStore._(storage, encryptedStore: encryptedStore);
  }

  /// 测试清理。
  @visibleForTesting
  static void resetForTest() {
    _instance = null;
  }

  final FlutterSecureStorage _storage;
  final EncryptedLocalStore _encrypted;

  SecureStore._(
    this._storage, {
    EncryptedLocalStore? encryptedStore,
  }) : _encrypted = encryptedStore ??
            EncryptedLocalStore(
              masterKeyProvider: () => _resolveMasterKey(_storage),
            );

  // ============== 公共 API（按数据 key 分） ==============

  Future<String?> readAiApiKey() => _read(_kAiApiKey);
  Future<void> writeAiApiKey(String value) => _write(_kAiApiKey, value);
  Future<void> deleteAiApiKey() => _delete(_kAiApiKey);

  Future<String?> readWebDavPassword() => _read(_kWebDavPassword);
  Future<void> writeWebDavPassword(String value) =>
      _write(_kWebDavPassword, value);
  Future<void> deleteWebDavPassword() => _delete(_kWebDavPassword);

  // ============== 策略 ==============

  Future<SecureStoreStrategy> currentStrategy() async {
    final prefs = await SharedPreferences.getInstance();
    return SecureStoreStrategy.fromString(prefs.getString(_kStrategyPref));
  }

  Future<void> setStrategy(SecureStoreStrategy s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStrategyPref, s.value);
  }

  // ============== 内部路由 ==============

  Future<String?> _read(String key) async {
    final strategy = await currentStrategy();
    if (strategy == SecureStoreStrategy.appEncrypted) {
      return _encrypted.read(key);
    }
    // auto / keychainOnly：先看 Keychain；读失败/无值再看 EncryptedLocalStore（auto 兜底）
    try {
      final v = await _storage.read(key: key);
      if (v != null && v.isNotEmpty) return v;
    } catch (e) {
      debugPrint('SecureStore.read($key) Keychain failed: $e');
    }
    if (strategy == SecureStoreStrategy.auto) {
      return _encrypted.read(key);
    }
    return null;
  }

  Future<void> _write(String key, String value) async {
    final strategy = await currentStrategy();
    if (strategy == SecureStoreStrategy.appEncrypted) {
      try {
        await _encrypted.write(key, value);
        return;
      } catch (e) {
        debugPrint('SecureStore.write($key) encrypted failed: $e');
        throw SecureStoreException(
          operation: 'write',
          key: key,
          cause: e,
          tier: 'encrypted',
        );
      }
    }
    // Keychain 优先
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('SecureStore.write($key) Keychain failed: $e');
      throw SecureStoreException(
        operation: 'write',
        key: key,
        cause: e,
        tier: 'keychain',
      );
    }
  }

  Future<void> _delete(String key) async {
    final strategy = await currentStrategy();
    if (strategy == SecureStoreStrategy.appEncrypted) {
      await _encrypted.delete(key);
      return;
    }
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('SecureStore.delete($key) Keychain failed: $e');
      throw SecureStoreException(
        operation: 'delete',
        key: key,
        cause: e,
        tier: 'keychain',
      );
    }
  }

  /// "auto + Keychain 失败" 时迁移到 app-encrypted 的便捷工具。
  ///
  /// UI 在用户确认后调一次：
  /// - 设置 strategy=appEncrypted；
  /// - 用 [pendingValue] 重新写一次到 EncryptedLocalStore；
  /// - 调用方可继续写其它字段。
  Future<void> switchToAppEncryptedAndWrite(
    String key,
    String pendingValue,
  ) async {
    await setStrategy(SecureStoreStrategy.appEncrypted);
    await _encrypted.write(key, pendingValue);
  }
}

/// 解析主密钥：先尝试从 Keychain 读 / 写一个 256-bit key；失败时退化为
/// 从 packageName + bundleId 派生（HKDF over a fixed app-secret）。
///
/// 派生不依赖 package_info_plus（避免新依赖），用一段编译期常量 + key 名做派生。
/// 这一档安全等价 obfuscated 明文，但比裸明文好。
Future<List<int>> _resolveMasterKey(FlutterSecureStorage storage) async {
  // 1) 尝试 Keychain
  try {
    final existing = await storage.read(key: SecureStore._kMasterKey);
    if (existing != null && existing.isNotEmpty) {
      final bytes = base64Decode(existing);
      if (bytes.length == 32) return bytes;
    }
    final algo = AesGcm.with256bits();
    final newKey = await algo.newSecretKey();
    final raw = await newKey.extractBytes();
    await storage.write(
      key: SecureStore._kMasterKey,
      value: base64Encode(raw),
    );
    return raw;
  } catch (_) {
    // 2) Keychain 不可用 → 派生
    final salt = utf8.encode('catodo.secure_store.v1');
    final base = utf8.encode('catodo.app_encrypted_fallback_secret.v1');
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final out = await hkdf.deriveKey(
      secretKey: SecretKey(base),
      nonce: salt,
    );
    return out.extractBytes();
  }
}

/// SecureStore 写 / 删失败时抛出。携带原始异常便于 UI 展示具体原因。
class SecureStoreException implements Exception {
  /// 'write' 或 'delete'。
  final String operation;
  final String key;
  final Object cause;

  /// 哪一档失败：'keychain' | 'encrypted'。
  final String tier;

  const SecureStoreException({
    required this.operation,
    required this.key,
    required this.cause,
    this.tier = 'keychain',
  });

  /// 给 UI 展示的简短消息。
  String get displayMessage {
    return '安全存储 $operation 失败（$tier）：$cause';
  }

  @override
  String toString() =>
      'SecureStoreException(operation=$operation, key=$key, tier=$tier, cause=$cause)';
}
