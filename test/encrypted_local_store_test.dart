import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/services/encrypted_local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 32 字节固定 key 用于测试
  final rawKey = List<int>.generate(32, (i) => i + 1);
  late EncryptedLocalStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = EncryptedLocalStore(
      masterKeyProvider: EncryptedLocalStore.staticKeyProviderForTest(rawKey),
    );
  });

  test('round-trip：写后能读出', () async {
    await store.write('ai_api_key', 'sk-secret');
    final v = await store.read('ai_api_key');
    expect(v, 'sk-secret');
  });

  test('未写入时返回 null', () async {
    final v = await store.read('missing');
    expect(v, isNull);
  });

  test('delete 后读回 null', () async {
    await store.write('k', 'v');
    await store.delete('k');
    expect(await store.read('k'), isNull);
  });

  test('损坏的 base64 视作没存', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('enc.broken', 'not-base64:also-not');
    final v = await store.read('broken');
    expect(v, isNull);
  });

  test('用错误 key 解密 → null', () async {
    await store.write('k', 'v');
    final wrongKey = List<int>.generate(32, (i) => i + 100);
    final wrong = EncryptedLocalStore(
      masterKeyProvider:
          EncryptedLocalStore.staticKeyProviderForTest(wrongKey),
    );
    expect(await wrong.read('k'), isNull);
  });

  test('staticKeyProviderForTest: key 长度必须是 32', () {
    expect(
      () => EncryptedLocalStore.staticKeyProviderForTest([1, 2, 3]),
      throwsArgumentError,
    );
  });

  test('两次写同一 key 互不干扰（最新值生效）', () async {
    await store.write('k', 'v1');
    await store.write('k', 'v2');
    expect(await store.read('k'), 'v2');
  });

  test('密文格式：nonce:cipher 两段 base64', () async {
    await store.write('k', 'hi');
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('enc.k')!;
    final parts = raw.split(':');
    expect(parts.length, 2);
    expect(() => base64Decode(parts[0]), returnsNormally);
    expect(() => base64Decode(parts[1]), returnsNormally);
  });
}
