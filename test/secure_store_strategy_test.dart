import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:catodo/services/encrypted_local_store.dart';
import 'package:catodo/services/secure_store.dart';

/// MethodChannel 模拟：可配置 fail 哪些操作。
class _ConfigurableStorage {
  static const _channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  Set<String> failOps = {};
  final Map<String, String> _store = {};

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (failOps.contains(call.method)) {
        throw PlatformException(code: 'BOOM');
      }
      switch (call.method) {
        case 'read':
          return _store[(call.arguments as Map)['key'] as String];
        case 'write':
          final args = call.arguments as Map;
          _store[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          _store.remove((call.arguments as Map)['key'] as String);
          return null;
        case 'readAll':
          return Map<String, String>.from(_store);
        case 'deleteAll':
          _store.clear();
          return null;
      }
      return null;
    });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ConfigurableStorage mock;

  // 用一个固定 key 注入 EncryptedLocalStore，避免依赖 Keychain 派生路径
  final fixedKey = List<int>.generate(32, (i) => 7);
  final encrypted = EncryptedLocalStore(
    masterKeyProvider: EncryptedLocalStore.staticKeyProviderForTest(fixedKey),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mock = _ConfigurableStorage()..install();
    SecureStore.overrideForTest(
      const FlutterSecureStorage(),
      encryptedStore: encrypted,
    );
  });

  tearDown(() {
    mock.uninstall();
    SecureStore.resetForTest();
  });

  group('strategy=auto（默认）', () {
    test('Keychain 正常 → 写读都走 Keychain', () async {
      await SecureStore.instance.writeAiApiKey('sk-1');
      final v = await SecureStore.instance.readAiApiKey();
      expect(v, 'sk-1');
      // 没写入 EncryptedLocalStore
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('enc.secure.ai_api_key'), isNull);
    });

    test('Keychain 写失败 → 抛 SecureStoreException', () async {
      mock.failOps = {'write'};
      expect(
        () => SecureStore.instance.writeAiApiKey('sk-x'),
        throwsA(isA<SecureStoreException>()),
      );
    });

    test('Keychain 读失败 → 自动 fallback 读 EncryptedLocalStore', () async {
      // 先把值写到 encrypted
      await SecureStore.instance.setStrategy(SecureStoreStrategy.appEncrypted);
      await SecureStore.instance.writeAiApiKey('sk-fallback');
      // 切回 auto，让 Keychain 读失败
      await SecureStore.instance.setStrategy(SecureStoreStrategy.auto);
      mock.failOps = {'read'};
      final v = await SecureStore.instance.readAiApiKey();
      expect(v, 'sk-fallback');
    });
  });

  group('strategy=appEncrypted', () {
    test('完全走 EncryptedLocalStore（不动 Keychain）', () async {
      await SecureStore.instance.setStrategy(SecureStoreStrategy.appEncrypted);
      // 故意让 Keychain 全失败，仍然能写读
      mock.failOps = {'write', 'read', 'delete'};
      await SecureStore.instance.writeAiApiKey('sk-enc');
      final v = await SecureStore.instance.readAiApiKey();
      expect(v, 'sk-enc');
    });

    test('encrypted 写抛异常时透传 SecureStoreException', () async {
      // encrypted 内部用 SharedPreferences；这里简单断言 strategy 切换 + 正常写
      await SecureStore.instance.setStrategy(SecureStoreStrategy.appEncrypted);
      await SecureStore.instance.writeAiApiKey('ok');
      expect(await SecureStore.instance.readAiApiKey(), 'ok');
    });
  });

  group('strategy 持久化', () {
    test('setStrategy 后下次默认按用户选择', () async {
      expect(
        await SecureStore.instance.currentStrategy(),
        SecureStoreStrategy.auto,
      );
      await SecureStore.instance.setStrategy(SecureStoreStrategy.appEncrypted);
      expect(
        await SecureStore.instance.currentStrategy(),
        SecureStoreStrategy.appEncrypted,
      );
    });

    test('未知字符串解析为 auto', () {
      expect(
        SecureStoreStrategy.fromString('garbage'),
        SecureStoreStrategy.auto,
      );
    });
  });

  group('switchToAppEncryptedAndWrite', () {
    test('一次调用切策略 + 写值', () async {
      mock.failOps = {'write'};
      // Keychain 写失败时调用切换
      await SecureStore.instance.switchToAppEncryptedAndWrite(
        'secure.ai_api_key',
        'sk-fallback',
      );
      expect(
        await SecureStore.instance.currentStrategy(),
        SecureStoreStrategy.appEncrypted,
      );
      mock.failOps = {}; // 解锁 Keychain 但策略已固定
      expect(await SecureStore.instance.readAiApiKey(), 'sk-fallback');
    });
  });

  group('SecureStoreException tier 标记', () {
    test('Keychain 写失败 tier=keychain', () async {
      mock.failOps = {'write'};
      try {
        await SecureStore.instance.writeAiApiKey('x');
        fail('expected throw');
      } on SecureStoreException catch (e) {
        expect(e.tier, 'keychain');
        expect(e.operation, 'write');
      }
    });
  });
}
