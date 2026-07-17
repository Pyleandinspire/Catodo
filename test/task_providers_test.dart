import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/models/filter.dart';

void main() {
  group('TaskFilter', () {
    test('copyWith 单独改 selectedGroup', () {
      final f = TaskFilter().copyWith(selectedGroup: '工作');
      expect(f.selectedGroup, '工作');
      expect(f.selectedPriority, isNull);
      expect(f.selectedTag, isNull);
    });
    test('copyWith 单独改 selectedPriority', () {
      final f = TaskFilter().copyWith(selectedPriority: 3);
      expect(f.selectedPriority, 3);
      expect(f.selectedGroup, isNull);
    });
    test('copyWith 单独改 selectedTag', () {
      final f = TaskFilter().copyWith(selectedTag: '紧急');
      expect(f.selectedTag, '紧急');
      expect(f.selectedGroup, isNull);
    });
    test('copyWith 组合', () {
      final f = TaskFilter().copyWith(selectedGroup: '工作', selectedPriority: 2, selectedTag: '报告');
      expect(f.selectedGroup, '工作');
      expect(f.selectedPriority, 2);
      expect(f.selectedTag, '报告');
    });
    test('默认全部 null', () {
      final f = TaskFilter();
      expect(f.selectedGroup, isNull);
      expect(f.selectedPriority, isNull);
      expect(f.selectedTag, isNull);
    });
  });
}
