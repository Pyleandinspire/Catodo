import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences + AES-GCM 应用级加密存储（PLAN-AI-001-7 兜底层）。
///
/// 数据序列化：`b64(nonce(12B)):b64(cipher+mac(16B))`。
/// 主密钥的获取由调用方注入（[masterKeyProvider]），让上层决定是 Keychain
/// 还是设备派生；本类只关注加解密。
///
/// 设计取舍：
/// - 解密失败一律视作"没存"（返回 null），不抛错；
/// - 写入失败仍通过 Future 抛出，调用方需要明确感知。
class EncryptedLocalStore {
  static const String _kPrefix = 'enc.';

  final Future<List<int>> Function() masterKeyProvider;
  final AesGcm _algo = AesGcm.with256bits();

  EncryptedLocalStore({required this.masterKeyProvider});

  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kPrefix$key');
    if (raw == null || raw.isEmpty) return null;
    try {
      final parts = raw.split(':');
      if (parts.length != 2) return null;
      final nonce = base64Decode(parts[0]);
      final cipherWithMac = base64Decode(parts[1]);
      if (cipherWithMac.length < 16) return null; // 至少要有 16B 的 MAC
      final cipherBytes = cipherWithMac.sublist(0, cipherWithMac.length - 16);
      final macBytes = cipherWithMac.sublist(cipherWithMac.length - 16);
      final keyBytes = await masterKeyProvider();
      final secretKey = SecretKey(keyBytes);
      final clear = await _algo.decrypt(
        SecretBox(cipherBytes, nonce: nonce, mac: Mac(macBytes)),
        secretKey: secretKey,
      );
      return utf8.decode(clear);
    } catch (e) {
      debugPrint('EncryptedLocalStore.read($key) failed: $e');
      return null;
    }
  }

  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final keyBytes = await masterKeyProvider();
    final secretKey = SecretKey(keyBytes);
    final nonce = _algo.newNonce();
    final box = await _algo.encrypt(
      utf8.encode(value),
      secretKey: secretKey,
      nonce: nonce,
    );
    // 拼接 ciphertext + mac
    final concat = Uint8List(box.cipherText.length + box.mac.bytes.length)
      ..setRange(0, box.cipherText.length, box.cipherText)
      ..setRange(box.cipherText.length, box.cipherText.length + box.mac.bytes.length,
          box.mac.bytes);
    final encoded = '${base64Encode(nonce)}:${base64Encode(concat)}';
    await prefs.setString('$_kPrefix$key', encoded);
  }

  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kPrefix$key');
  }

  /// 测试 helper：用一段 raw 32 字节作为主密钥的 provider。
  @visibleForTesting
  static Future<List<int>> Function() staticKeyProviderForTest(
    List<int> rawKey,
  ) {
    if (rawKey.length != 32) {
      throw ArgumentError('AES-256 key must be 32 bytes');
    }
    return () async => rawKey;
  }
}
