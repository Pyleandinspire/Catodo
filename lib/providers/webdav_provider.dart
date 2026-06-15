import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/webdav_service.dart';
import '../services/secure_store.dart';

class WebDAVConfigNotifier extends StateNotifier<WebDAVConfig> {
  WebDAVConfigNotifier() : super(WebDAVConfig()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('webdav_url') ?? '';
    final username = prefs.getString('webdav_username') ?? '';
    final password = await SecureStore.instance.readWebDavPassword() ?? '';
    state = WebDAVConfig(url: url, username: username, password: password);
  }

  Future<void> saveConfig(WebDAVConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_url', config.url);
    await prefs.setString('webdav_username', config.username);
    await SecureStore.instance.writeWebDavPassword(config.password);
    // 旧明文 password 若仍残留，主动清掉一次
    await prefs.remove('webdav_password');
    state = config;
  }

  Future<bool> testConnection() async {
    final service = WebDAVService(state);
    return await service.testConnection();
  }
}

class SyncModeNotifier extends StateNotifier<SyncMode> {
  static const _key = 'sync_mode';

  SyncModeNotifier() : super(SyncMode.autoMerge) {
    _loadMode();
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;
    state = SyncMode.values[index.clamp(0, SyncMode.values.length - 1)];
  }

  Future<void> setMode(SyncMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }
}

final webdavConfigProvider =
    StateNotifierProvider<WebDAVConfigNotifier, WebDAVConfig>((ref) {
  return WebDAVConfigNotifier();
});

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

final syncModeProvider =
    StateNotifierProvider<SyncModeNotifier, SyncMode>((ref) {
  return SyncModeNotifier();
});