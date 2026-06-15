import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/webdav_provider.dart';
import '../../services/webdav_service.dart';
import '../../services/secure_store.dart';
import '../../providers/isar_provider.dart';
import '../../data/task_dao.dart';

class WebDAVSettingsScreen extends ConsumerStatefulWidget {
  const WebDAVSettingsScreen({super.key});

  @override
  ConsumerState<WebDAVSettingsScreen> createState() =>
      _WebDAVSettingsScreenState();
}

class _WebDAVSettingsScreenState extends ConsumerState<WebDAVSettingsScreen> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isTesting = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(webdavConfigProvider);
    _urlController.text = config.url;
    _usernameController.text = config.username;
    _passwordController.text = config.password;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    final config = WebDAVConfig(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );
    final service = WebDAVService(config);
    final success = await service.testConnection();
    setState(() => _isTesting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '连接成功' : '连接失败，请检查配置'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _saveConfig() async {
    final config = WebDAVConfig(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!config.isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写完整的配置信息')));
      return;
    }

    try {
      await ref.read(webdavConfigProvider.notifier).saveConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('配置已保存')));
      }
    } on SecureStoreException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败：${e.cause}（密码未写入）'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sync() async {
    setState(() => _isSyncing = true);
    ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;

    try {
      final config = ref.read(webdavConfigProvider);
      final syncMode = ref.read(syncModeProvider);
      final service = WebDAVService(config);
      final isarAsync = ref.read(isarProvider);

      SyncResult result;
      final isar = isarAsync.valueOrNull;
      if (isar != null) {
        final dao = TaskDao(isar);
        final localTasks = await dao.getAllTasks();
        result = await service.sync(localTasks, mode: syncMode);
      } else {
        result = SyncResult(status: SyncStatus.failed, error: '数据库未就绪');
      }

      if (result.status == SyncStatus.synced) {
        // 将合并后的任务写回本地数据库
        if (isarAsync.valueOrNull != null) {
          final dao = TaskDao(isarAsync.valueOrNull!);
          for (final task in result.mergedTasks) {
            await dao.updateTask(task);
          }
        }
        ref.read(syncStatusProvider.notifier).state = SyncStatus.synced;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '同步完成：上传 ${result.uploadedCount} 个，下载 ${result.downloadedCount} 个',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ref.read(syncStatusProvider.notifier).state = SyncStatus.failed;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('同步失败: ${result.error ?? "未知错误"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ref.read(syncStatusProvider.notifier).state = SyncStatus.failed;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _showSyncModeInfo(SyncMode mode) {
    final descriptions = {
      SyncMode.autoMerge:
          '自动合并（默认）：基于更新时间戳的增量同步。冲突时更新时间较新的版本胜出，双方独有的任务都会保留。',
      SyncMode.localFirst:
          '本地优先：冲突时以本地版本为准，双方独有的任务都会保留。远程修改不会覆盖本地数据。',
      SyncMode.remoteFirst:
          '远程优先：冲突时以远程版本为准，双方独有的任务都会保留。适合从其他设备恢复数据。',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_modeLabel(mode)),
        content: Text(descriptions[mode] ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  String _modeLabel(SyncMode mode) {
    switch (mode) {
      case SyncMode.autoMerge:
        return '自动合并';
      case SyncMode.localFirst:
        return '本地优先';
      case SyncMode.remoteFirst:
        return '远程优先';
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);
    final syncMode = ref.watch(syncModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WebDAV 同步'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '服务器配置',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'WebDAV 地址',
                        hintText:
                            'https://example.com/remote.php/dav/files/username/',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '密码',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isTesting ? null : _testConnection,
                            icon: _isTesting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.wifi_tethering),
                            label: Text(_isTesting ? '测试中...' : '测试连接'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _saveConfig,
                          child: const Text('保存配置'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '同步模式',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: RadioGroup<SyncMode>(
                  groupValue: syncMode,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(syncModeProvider.notifier).setMode(value);
                    }
                  },
                  child: Column(
                    children: SyncMode.values.map((mode) {
                      return RadioListTile<SyncMode>(
                        value: mode,
                        title: Row(
                          children: [
                            Text(_modeLabel(mode)),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showSyncModeInfo(mode),
                              child: Icon(
                                Icons.help_outline,
                                size: 18,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          _modeShortDesc(mode),
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '同步操作',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _statusColor(syncStatus).withAlpha(30),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(12),
                            ),
                          ),
                          child: Icon(
                            _statusIcon(syncStatus),
                            color: _statusColor(syncStatus),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _statusText(syncStatus),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _statusSubText(syncStatus),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF757575),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSyncing ? null : _sync,
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.sync),
                        label: Text(_isSyncing ? '同步中...' : '开始同步'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '同步策略：基于更新时间戳的增量同步。\n双方独有的任务都会保留，已完成任务也会同步。',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _modeShortDesc(SyncMode mode) {
    switch (mode) {
      case SyncMode.autoMerge:
        return '冲突时取更新时间较新的版本';
      case SyncMode.localFirst:
        return '冲突时以本地版本为准';
      case SyncMode.remoteFirst:
        return '冲突时以远程版本为准';
    }
  }

  Color _statusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return Colors.orange;
      case SyncStatus.synced:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
      case SyncStatus.idle:
        return Colors.grey;
    }
  }

  IconData _statusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.synced:
        return Icons.check_circle;
      case SyncStatus.failed:
        return Icons.error;
      case SyncStatus.idle:
        return Icons.sync_disabled;
    }
  }

  String _statusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return '同步中...';
      case SyncStatus.synced:
        return '已同步';
      case SyncStatus.failed:
        return '同步失败';
      case SyncStatus.idle:
        return '未同步';
    }
  }

  String _statusSubText(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return '正在传输数据';
      case SyncStatus.synced:
        return '数据已是最新';
      case SyncStatus.failed:
        return '请检查配置';
      case SyncStatus.idle:
        return '点击下方按钮开始同步';
    }
  }
}