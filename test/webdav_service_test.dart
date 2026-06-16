import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/services/webdav_service.dart';
import 'package:catodo/models/task.dart';

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

  group('resolveConflictTest 软删除优先', () {
    test('本地已删远程未删 → 返回已删版本', () {
      final service = WebDAVService(WebDAVConfig());
      final local = Task(title: 'A', isCompleted: false)..id = 1..isDeleted = true;
      final remote = Task(title: 'A', isCompleted: false)..id = 1..isDeleted = false;
      final winner = service.resolveConflictTest(local, remote, SyncMode.autoMerge);
      expect(winner.isDeleted, true);
    });
    test('远程已删本地未删 → 返回已删版本', () {
      final service = WebDAVService(WebDAVConfig());
      final local = Task(title: 'A')..id = 1..isDeleted = false;
      final remote = Task(title: 'A')..id = 1..isDeleted = true;
      final winner = service.resolveConflictTest(local, remote, SyncMode.autoMerge);
      expect(winner.isDeleted, true);
    });
    test('双方未删 autoMerge → updatedAt 新者胜', () {
      final service = WebDAVService(WebDAVConfig());
      final local = Task(title: 'Local')..id = 1..updatedAt = DateTime(2026, 6, 16);
      final remote = Task(title: 'Remote')..id = 1..updatedAt = DateTime(2026, 6, 15);
      final winner = service.resolveConflictTest(local, remote, SyncMode.autoMerge);
      expect(winner.title, 'Local');
    });
  });
}
