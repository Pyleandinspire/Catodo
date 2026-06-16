import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/services/ai_service.dart';

/// 从 task_form_screen._extractImagePaths 复制的纯函数版本供测试。
List<String> extractImagePathsForTest(String text) {
  if (text.isEmpty) return const [];
  final regex = RegExp(
    r'(?:^|\n)(\/[^\n]+\.(?:png|jpg|jpeg|gif|webp|bmp))',
    multiLine: true,
  );
  return regex.allMatches(text).map((m) => m.group(1)!).toList();
}

void main() {
  group('_extractImagePaths', () {
    test('空字符串返回空', () {
      expect(extractImagePathsForTest(''), isEmpty);
    });

    test('单个图片路径被提取', () {
      final paths = extractImagePathsForTest('/Users/me/photo.png');
      expect(paths, ['/Users/me/photo.png']);
    });

    test('多个图片路径被提取', () {
      final paths = extractImagePathsForTest(
        '/Users/me/a.jpg\n一些描述文字\n/home/b.png',
      );
      expect(paths, ['/Users/me/a.jpg', '/home/b.png']);
    });

    test('非图片路径不匹配', () {
      final paths = extractImagePathsForTest('/home/doc.pdf\n/var/log.txt');
      expect(paths, isEmpty);
    });

    test('描述文字中的内联路径不被截取', () {
      // 路径必须独占一行（行首）
      final paths = extractImagePathsForTest('请看附件 /path/to/img.png 谢谢');
      expect(paths, isEmpty);
    });

    test('混合文本只提取图片行', () {
      final paths = extractImagePathsForTest(
        '任务说明\n/Users/me/screenshot.png\n联系张三\n/tmp/photo.jpg',
      );
      expect(paths, ['/Users/me/screenshot.png', '/tmp/photo.jpg']);
    });

    test('webp/gif/bmp 扩展名也被支持', () {
      final paths = extractImagePathsForTest('/a/img.webp\n/b/img.gif\n/c/img.bmp');
      expect(paths.length, 3);
    });
  });

  group('AiCallError 属性', () {
    test('detail 可存储长字符串', () {
      final long = 'x' * 500;
      final err = AiCallError(
        type: AiErrorType.unknown,
        message: 'test',
        detail: long,
      );
      expect(err.detail!.length, 500);
    });
  });
}
