import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'webdav_settings_screen.dart';
import 'data_management_screen.dart';
import 'ai_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '设置',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '管理同步、AI 和数据备份',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildCard(
              context: context,
              icon: Icons.smart_toy_rounded,
              iconColor: Colors.purple,
              iconBgColor: const Color(0xFFF3E5F5),
              title: 'AI 助手',
              subtitle: '配置模型、API Key 与智能任务能力',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AISettingsScreen()),
              ),
            ),
            _buildCard(
              context: context,
              icon: Icons.inventory_2_rounded,
              iconColor: Colors.blue,
              iconBgColor: const Color(0xFFE3F2FD),
              title: '数据管理',
              subtitle: '导入导出任务，备份完整配置',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DataManagementScreen()),
              ),
            ),
            _buildCard(
              context: context,
              icon: Icons.sync_rounded,
              iconColor: Colors.green,
              iconBgColor: const Color(0xFFE8F5E9),
              title: 'WebDAV 同步',
              subtitle: '跨设备同步任务数据',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WebDAVSettingsScreen()),
              ),
            ),
            _buildCard(
              context: context,
              icon: Icons.info_outline_rounded,
              iconColor: colorScheme.onSurfaceVariant,
              iconBgColor: colorScheme.surfaceContainerHighest,
              title: '关于',
              subtitle: '版本 1.0.0',
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
