import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:catodo/services/secrets_migration.dart';
import 'package:catodo/services/secure_store.dart';

/// 简易内存版 FlutterSecureStorage：通过覆盖底层 MethodChannel 实现，
/// 让 unit test 不依赖 iOS Keychain / Android Keystore。
class _InMemorySecureStorage {
  static const _channel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  final Map<String, String> _store = {};

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'read':
          final key = (call.arguments as Map)['key'] as String;
          return _store[key];
        case 'write':
          final args = (call.arguments as Map);
          final key = args['key'] as String;
          final value = args['value'] as String?;
          if (value == null) {
            _store.remove(key);
          } else {
            _store[key] = value;
          }
          return null;
        case 'delete':
          final key = (call.arguments as Map)['key'] as String;
          _store.remove(key);
          return null;
        case 'readAll':
          return Map<String, String>.from(_store);
        case 'deleteAll':
          _store.clear();
          return null;
        case 'containsKey':
          final key = (call.arguments as Map)['key'] as String;
          return _store.containsKey(key);
        default:
          return null;
      }
    });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    _store.clear();
  }

  String? operator [](String key) => _store[key];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _InMemorySecureStorage storage;

  setUp(() {
    storage = _InMemorySecureStorage()..install();
    SecureStore.overrideForTest(const FlutterSecureStorage());
  });

  tearDown(() {
    storage.uninstall();
    SecureStore.resetForTest();
  });

  test('首次启动：迁移旧 ai_api_key 与 webdav_password 到 SecureStore，并清空 SP', () async {
    SharedPreferences.setMockInitialValues({
      'ai_api_key': 'sk-legacy',
      'webdav_password': 'pw-legacy',
      'ai_api_url': 'https://x.example.com/v1/chat/completions', // 非敏感保留
    });
    await migrateLegacySecretsIfNeeded();

    final sp = await SharedPreferences.getInstance();
    expect(sp.getString('ai_api_key'), isNull);
    expect(sp.getString('webdav_password'), isNull);
    expect(sp.getString('ai_api_url'), 'https://x.example.com/v1/chat/completions');
    expect(sp.getBool('secrets_migrated_v1'), true);

    // SecureStore 中应能读到
    expect(await SecureStore.instance.readAiApiKey(), 'sk-legacy');
    expect(await SecureStore.instance.readWebDavPassword(), 'pw-legacy');
  });

  test('已迁移过：再次调用应早返回，不动 SecureStore 也不动 SP', () async {
    SharedPreferences.setMockInitialValues({
      'secrets_migrated_v1': true,
      'ai_api_key': 'should-not-touch',
    });
    await migrateLegacySecretsIfNeeded();
    final sp = await SharedPreferences.getInstance();
    // 已标记迁移完成 → SP 中遗留的旧 key 不动（说明 migration 短路）
    expect(sp.getString('ai_api_key'), 'should-not-touch');
    expect(await SecureStore.instance.readAiApiKey(), isNull);
  });

  test('无旧 key：仍然标记 migrated=true，避免下次再跑', () async {
    SharedPreferences.setMockInitialValues({});
    await migrateLegacySecretsIfNeeded();
    final sp = await SharedPreferences.getInstance();
    expect(sp.getBool('secrets_migrated_v1'), true);
    expect(await SecureStore.instance.readAiApiKey(), isNull);
    expect(await SecureStore.instance.readWebDavPassword(), isNull);
  });

  test('空字符串视作无值，不写入 SecureStore', () async {
    SharedPreferences.setMockInitialValues({
      'ai_api_key': '',
      'webdav_password': '',
    });
    await migrateLegacySecretsIfNeeded();
    expect(await SecureStore.instance.readAiApiKey(), isNull);
    expect(await SecureStore.instance.readWebDavPassword(), isNull);
  });

  test('SecureStore 读写：覆盖与删除', () async {
    await SecureStore.instance.writeAiApiKey('k1');
    expect(await SecureStore.instance.readAiApiKey(), 'k1');
    await SecureStore.instance.writeAiApiKey('k2');
    expect(await SecureStore.instance.readAiApiKey(), 'k2');
    await SecureStore.instance.deleteAiApiKey();
    expect(await SecureStore.instance.readAiApiKey(), isNull);
  });
}
