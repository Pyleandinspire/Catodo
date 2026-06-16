import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'webdav_settings_screen.dart';
import 'data_management_screen.dart';
import 'ai_settings_screen.dart';
import '../../providers/theme_provider.dart';
import '../icons/app_icons.dart';
import '../theme/app_tokens.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('设置', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: scheme.onSurface)),
                Text('管理你的应用配置', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // 外观
                  _buildCard(context, 
                    icon: themeMode == ThemeMode.dark ? AppIcons.moon : AppIcons.sun,
                    iconColor: themeMode == ThemeMode.dark ? Colors.indigo : Colors.orange,
                    iconBgColor: themeMode == ThemeMode.dark ? const Color(0xFFE3E0FF) : const Color(0xFFFFF3E0),
                    title: '外观',
                    subtitle: _themeLabel(themeMode),
                    onTap: () => _showThemeDialog(context, ref, themeMode),
                  ),
                  // AI
                  _buildCard(context, 
                    icon: AppIcons.bot,
                    iconColor: Colors.purple,
                    iconBgColor: const Color(0xFFF3E5F5),
                    title: 'AI 助手',
                    subtitle: '智能任务分解与建议',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AISettingsScreen())),
                  ),
                  // 数据管理
                  _buildCard(context, 
                    icon: AppIcons.download,
                    iconColor: Colors.blue,
                    iconBgColor: const Color(0xFFE3F2FD),
                    title: '数据管理',
                    subtitle: '导入导出与同步',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataManagementScreen())),
                  ),
                  // WebDAV
                  _buildCard(context, 
                    icon: AppIcons.cloud,
                    iconColor: Colors.green,
                    iconBgColor: const Color(0xFFE8F5E9),
                    title: 'WebDAV 同步',
                    subtitle: '跨设备数据同步',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WebDAVSettingsScreen())),
                  ),
                  // 关于
                  _buildCard(context, 
                    icon: AppIcons.info,
                    iconColor: scheme.onSurfaceVariant,
                    iconBgColor: scheme.surfaceContainerHighest,
                    title: '关于',
                    subtitle: '版本 1.0.0',
                    onTap: null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: iconBgColor, borderRadius: const BorderRadius.all(Radius.circular(12))), child: Icon(icon, color: iconColor)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(subtitle, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
            if (onTap != null) Icon(AppIcons.forward, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }

  String _themeLabel(ThemeMode m) {
    switch (m) { case ThemeMode.light: return '浅色'; case ThemeMode.dark: return '深色'; case ThemeMode.system: return '跟随系统'; }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode current) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('主题模式'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        RadioListTile<ThemeMode>(title: const Text('浅色'), value: ThemeMode.light, groupValue: current, onChanged: (v) { ref.read(themeModeProvider.notifier).setMode(v!); Navigator.pop(ctx); }),
        RadioListTile<ThemeMode>(title: const Text('深色'), value: ThemeMode.dark, groupValue: current, onChanged: (v) { ref.read(themeModeProvider.notifier).setMode(v!); Navigator.pop(ctx); }),
        RadioListTile<ThemeMode>(title: const Text('跟随系统'), value: ThemeMode.system, groupValue: current, onChanged: (v) { ref.read(themeModeProvider.notifier).setMode(v!); Navigator.pop(ctx); }),
      ]),
    ));
  }
}
