import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DayViewMode { all, focusToday, hideOverdue }

class DayViewStateNotifier extends StateNotifier<DayViewMode> {
  static const _key = 'day_view_mode';

  DayViewStateNotifier() : super(DayViewMode.all) {
    _loadMode();
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;
    state = DayViewMode.values[index.clamp(0, DayViewMode.values.length - 1)];
  }

  Future<void> setMode(DayViewMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }
}

final dayViewModeProvider =
    StateNotifierProvider<DayViewStateNotifier, DayViewMode>((ref) {
  return DayViewStateNotifier();
});