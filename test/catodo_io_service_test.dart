import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/services/catodo_io_service.dart';
import 'package:catodo/models/task.dart';

void main() {
  group('version validation', () {
    test('same major ok', () {
      expect(CatodoIOService.validateVersion('1.0'), true);
      expect(CatodoIOService.validateVersion('1.5'), true);
    });
    test('different major rejects', () {
      expect(CatodoIOService.validateVersion('2.0'), false);
      expect(CatodoIOService.validateVersion('0.9'), false);
    });
    test('invalid format returns false', () {
      expect(CatodoIOService.validateVersion('abc'), false);
      expect(CatodoIOService.validateVersion(''), false);
    });
  });

  group('exportCatodo', () {
    test('不含敏感字段', () {
      final tasks = <Task>[];
      final json = CatodoIOService.exportCatodo(
        tasks: tasks,
        settings: {'webdav': {'url': 'x'}, 'ai': {'apiKey': 'secret'}},
        includeSensitive: false,
      );
      expect(json, isNot(contains('secret')));
      expect(json, isNot(contains('password')));
    });
    test('含敏感字段', () {
      final tasks = <Task>[];
      final json = CatodoIOService.exportCatodo(
        tasks: tasks,
        settings: {'webdav': {'url': 'x', 'password': 'p'}, 'ai': {'apiKey': 'k'}},
        includeSensitive: true,
      );
      expect(json, contains('password'));
      expect(json, contains('apiKey'));
    });
    test('包含 version 字段', () {
      final json = CatodoIOService.exportCatodo(tasks: [], settings: {});
      expect(json, contains('"version"'));
    });
  });

  group('importCatodo', () {
    test('有效版本 1.x 可导入', () {
      final json = '{"version":"1.0","tasks":[],"settings":{}}';
      final data = CatodoIOService.importCatodo(json);
      expect(data.tasks, isEmpty);
    });
    test('无效版本抛 FormatException', () {
      final json = '{"version":"2.0","tasks":[],"settings":{}}';
      expect(() => CatodoIOService.importCatodo(json), throwsA(isA<FormatException>()));
    });
  });
}
