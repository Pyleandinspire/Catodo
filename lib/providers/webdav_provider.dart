import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/webdav_service.dart';

class WebDAVConfigNotifier extends StateNotifier<WebDAVConfig> {
  WebDAVConfigNotifier() : super(WebDAVConfig()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('webdav_url') ?? '';
    final username = prefs.getString('webdav_username') ?? '';
    final password = prefs.getString('webdav_password') ?? '';
    state = WebDAVConfig(url: url, username: username, password: password);
  }

  Future<void> saveConfig(WebDAVConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_url', config.url);
    await prefs.setString('webdav_username', config.username);
    await prefs.setString('webdav_password', config.password);
    state = config;
  }

  Future<bool> testConnection() async {
    final service = WebDAVService(state);
    return await service.testConnection();
  }
}

final webdavConfigProvider =
    StateNotifierProvider<WebDAVConfigNotifier, WebDAVConfig>((ref) {
  return WebDAVConfigNotifier();
});

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);