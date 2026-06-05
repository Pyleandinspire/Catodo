import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/task.dart';

class DatabaseService {
  static Isar? _instance;

  static Future<Isar> getInstance() async {
    if (_instance != null) {
      try {
        await _instance!.tasks.where().count();
        return _instance!;
      } catch (_) {
        // Instance is closed or invalid, recreate it
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    _instance = await Isar.open(
      [TaskSchema],
      directory: dir.path,
      inspector: true,
    );
    return _instance!;
  }

  static Future<void> close() async {
    if (_instance != null) {
      await _instance!.close();
      _instance = null;
    }
  }
}