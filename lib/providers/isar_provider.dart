import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../services/database_service.dart';

final isarProvider = FutureProvider<Isar>((ref) async {
  final isar = await DatabaseService.getInstance();
  ref.onDispose(() {
    DatabaseService.close();
  });
  return isar;
});