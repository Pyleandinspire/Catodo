import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 系统级安全凭据存储（PLAN-AI-001-2）。
///
/// - iOS: Keychain（first_unlock）
/// - Android: EncryptedSharedPreferences
/// - macOS / Windows / Linux: 平台对应实现
///
/// 失败时返回 null，调用方应自行 fallback（例如视为未配置）。所有方法都自带
/// `try/catch` 与 `debugPrint`，避免单点崩溃影响整个应用。
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
  Future<void> writeAiApiKey(String value) => _safeWrite(_kAiApiKey, value);
  Future<void> deleteAiApiKey() => _safeDelete(_kAiApiKey);

  Future<String?> readWebDavPassword() => _safeRead(_kWebDavPassword);
  Future<void> writeWebDavPassword(String value) =>
      _safeWrite(_kWebDavPassword, value);
  Future<void> deleteWebDavPassword() => _safeDelete(_kWebDavPassword);

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('SecureStore.read($key) failed: $e');
      return null;
    }
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('SecureStore.write($key) failed: $e');
    }
  }

  Future<void> _safeDelete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('SecureStore.delete($key) failed: $e');
    }
  }
}
