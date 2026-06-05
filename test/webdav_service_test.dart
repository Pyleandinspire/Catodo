import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/services/webdav_service.dart';

void main() {
  group('WebDAVService URL 构建测试', () {
    test('基础 URL 拼接', () {
      final config = WebDAVConfig(
        url: 'https://example.com/webdav',
        username: 'user',
        password: 'pass',
      );
      final service = WebDAVService(config);
      expect(
        service.buildUrl('/test.txt'),
        'https://example.com/webdav/test.txt',
      );
    });

    test('URL 末尾带斜杠', () {
      final config = WebDAVConfig(
        url: 'https://example.com/webdav/',
        username: 'user',
        password: 'pass',
      );
      final service = WebDAVService(config);
      expect(
        service.buildUrl('/test.txt'),
        'https://example.com/webdav/test.txt',
      );
    });

    test('path 不带前导斜杠', () {
      final config = WebDAVConfig(
        url: 'https://example.com/webdav',
        username: 'user',
        password: 'pass',
      );
      final service = WebDAVService(config);
      expect(
        service.buildUrl('test.txt'),
        'https://example.com/webdav/test.txt',
      );
    });

    test('根路径请求', () {
      final config = WebDAVConfig(
        url: 'https://example.com/webdav',
        username: 'user',
        password: 'pass',
      );
      final service = WebDAVService(config);
      expect(service.buildUrl('/'), 'https://example.com/webdav/');
    });

    test('任务文件路径', () {
      final config = WebDAVConfig(
        url: 'https://example.com/remote.php/dav/files/user',
        username: 'user',
        password: 'pass',
      );
      final service = WebDAVService(config);
      expect(
        service.buildUrl('/Catodo/catodo_tasks.json'),
        'https://example.com/remote.php/dav/files/user/Catodo/catodo_tasks.json',
      );
    });

    test('URL 末尾带斜杠 + path 不带斜杠', () {
      final config = WebDAVConfig(
        url: 'https://example.com/webdav/',
        username: 'user',
        password: 'pass',
      );
      final service = WebDAVService(config);
      expect(
        service.buildUrl('Catodo/catodo_tasks.json'),
        'https://example.com/webdav/Catodo/catodo_tasks.json',
      );
    });
  });

  group('WebDAVConfig 测试', () {
    test('完整配置有效', () {
      final config = WebDAVConfig(
        url: 'https://example.com',
        username: 'user',
        password: 'pass',
      );
      expect(config.isValid, true);
    });

    test('缺少 url 无效', () {
      final config = WebDAVConfig(url: '', username: 'user', password: 'pass');
      expect(config.isValid, false);
    });

    test('缺少 username 无效', () {
      final config = WebDAVConfig(
        url: 'https://example.com',
        username: '',
        password: 'pass',
      );
      expect(config.isValid, false);
    });
  });

  group('SyncResult 测试', () {
    test('同步成功结果', () {
      final result = SyncResult(
        status: SyncStatus.synced,
        uploadedCount: 5,
        downloadedCount: 3,
      );
      expect(result.status, SyncStatus.synced);
      expect(result.uploadedCount, 5);
      expect(result.downloadedCount, 3);
      expect(result.error, isNull);
    });

    test('同步失败结果', () {
      final result = SyncResult(status: SyncStatus.failed, error: '网络错误');
      expect(result.status, SyncStatus.failed);
      expect(result.error, '网络错误');
      expect(result.uploadedCount, 0);
    });
  });
}
