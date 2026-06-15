import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catodo/services/secure_store.dart';

/// 在 MethodChannel 层面注入：write/delete 永远抛异常；read 永远返回 null。
class _AlwaysFailStorage {
  static const _channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  void install({required Set<String> failOps}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (failOps.contains(call.method)) {
        throw PlatformException(code: 'BOOM', message: '模拟失败');
      }
      // 默认无值
      switch (call.method) {
        case 'read':
          return null;
        case 'write':
        case 'delete':
        case 'deleteAll':
        case 'containsKey':
        case 'readAll':
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

  late _AlwaysFailStorage mock;

  setUp(() {
    mock = _AlwaysFailStorage();
    SecureStore.overrideForTest(const FlutterSecureStorage());
  });

  tearDown(() {
    mock.uninstall();
    SecureStore.resetForTest();
  });

  test('write 失败 → 抛 SecureStoreException', () async {
    mock.install(failOps: {'write'});
    expect(
      () => SecureStore.instance.writeAiApiKey('sk-x'),
      throwsA(isA<SecureStoreException>()),
    );
  });

  test('webdav write 失败 → 抛 SecureStoreException', () async {
    mock.install(failOps: {'write'});
    expect(
      () => SecureStore.instance.writeWebDavPassword('pw'),
      throwsA(isA<SecureStoreException>()),
    );
  });

  test('delete 失败 → 抛 SecureStoreException', () async {
    mock.install(failOps: {'delete'});
    expect(
      () => SecureStore.instance.deleteAiApiKey(),
      throwsA(isA<SecureStoreException>()),
    );
  });

  test('read 失败仍返回 null（不抛）', () async {
    mock.install(failOps: {'read'});
    final v = await SecureStore.instance.readAiApiKey();
    expect(v, isNull);
  });

  test('正常路径不抛错', () async {
    mock.install(failOps: const <String>{});
    // write 不抛
    await SecureStore.instance.writeAiApiKey('k');
    // delete 不抛
    await SecureStore.instance.deleteAiApiKey();
  });

  test('SecureStoreException 携带原始异常 / 操作 / key', () async {
    mock.install(failOps: {'write'});
    try {
      await SecureStore.instance.writeAiApiKey('k');
      fail('expected throw');
    } on SecureStoreException catch (e) {
      expect(e.operation, 'write');
      expect(e.key, contains('ai_api_key'));
      expect(e.cause, isA<PlatformException>());
      expect(e.toString(), contains('write'));
    }
  });
}
