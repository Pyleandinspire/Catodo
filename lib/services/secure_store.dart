import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 系统级安全凭据存储（PLAN-AI-001-2 + PLAN-AI-001-6）。
///
/// - iOS: Keychain（first_unlock）
/// - Android: EncryptedSharedPreferences
/// - macOS / Windows / Linux: 平台对应实现
///
/// 设计：
/// - **读** 失败仍返回 null（"还没存"是正常情况，不打扰）；
/// - **写 / 删** 失败 **抛 [SecureStoreException]**，由调用方决定如何提示用户，
///   绝不静默写明文回退。
class SecureStore {
  static const _kAiApiKey = 'secure.ai_api_key';
  static const _kWebDavPassword = 'secure.webdav_password';

  static SecureStore? _instance;

  static SecureStore get instance => _instance ??= SecureStore._(
        const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        ),
      );

  /// 测试注入：替换底层 storage（FakeFlutterSecureStorage 之类）。
  @visibleForTesting
  static void overrideForTest(FlutterSecureStorage storage) {
    _instance = SecureStore._(storage);
  }

  /// 测试清理：恢复默认实现。
  @visibleForTesting
  static void resetForTest() {
    _instance = null;
  }

  final FlutterSecureStorage _storage;

  SecureStore._(this._storage);

  Future<String?> readAiApiKey() => _safeRead(_kAiApiKey);
  Future<void> writeAiApiKey(String value) => _writeOrThrow(_kAiApiKey, value);
  Future<void> deleteAiApiKey() => _deleteOrThrow(_kAiApiKey);

  Future<String?> readWebDavPassword() => _safeRead(_kWebDavPassword);
  Future<void> writeWebDavPassword(String value) =>
      _writeOrThrow(_kWebDavPassword, value);
  Future<void> deleteWebDavPassword() => _deleteOrThrow(_kWebDavPassword);

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('SecureStore.read($key) failed: $e');
      return null;
    }
  }

  Future<void> _writeOrThrow(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('SecureStore.write($key) failed: $e');
      throw SecureStoreException(operation: 'write', key: key, cause: e);
    }
  }

  Future<void> _deleteOrThrow(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('SecureStore.delete($key) failed: $e');
      throw SecureStoreException(operation: 'delete', key: key, cause: e);
    }
  }
}

/// SecureStore 写 / 删失败时抛出。携带原始异常便于 UI 展示具体原因。
class SecureStoreException implements Exception {
  /// 'write' 或 'delete'。
  final String operation;
  final String key;
  final Object cause;

  const SecureStoreException({
    required this.operation,
    required this.key,
    required this.cause,
  });

  /// 给 UI 展示的简短消息。
  String get displayMessage {
    return '安全存储 $operation 失败：$cause';
  }

  @override
  String toString() =>
      'SecureStoreException(operation=$operation, key=$key, cause=$cause)';
}
