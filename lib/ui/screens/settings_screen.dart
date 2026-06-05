import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'webdav_settings_screen.dart';
import 'data_management_screen.dart';
import 'ai_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 头部区域
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '设置',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '管理你的应用配置',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // 设置选项列表
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // AI 设置
                  _buildCard(
                    icon: Icons.smart_toy,
                    iconColor: Colors.purple,
                    iconBgColor: const Color(0xFFF3E5F5),
                    title: 'AI 助手',
                    subtitle: '智能任务分解与建议',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AISettingsScreen(),
                      ),
                    ),
                  ),

                  // 数据管理
                  _buildCard(
                    icon: Icons.data_saver_on,
                    iconColor: Colors.blue,
                    iconBgColor: const Color(0xFFE3F2FD),
                    title: '数据管理',
                    subtitle: '导入导出与同步',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DataManagementScreen(),
                      ),
                    ),
                  ),

                  // WebDAV 同步
                  _buildCard(
                    icon: Icons.sync,
                    iconColor: Colors.green,
                    iconBgColor: const Color(0xFFE8F5E9),
                    title: 'WebDAV 同步',
                    subtitle: '跨设备数据同步',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WebDAVSettingsScreen(),
                      ),
                    ),
                  ),

                  // 关于
                  _buildCard(
                    icon: Icons.info,
                    iconColor: const Color(0xFF757575),
                    iconBgColor: const Color(0xFFF5F5F5),
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

  Widget _buildCard({
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
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.arrow_forward_ios, color: Color(0xFFBDBDBD)),
            ],
          ),
        ),
      ),
    );
  }
}
