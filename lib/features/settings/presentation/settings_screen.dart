import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _sections = [
    _SettingsSection(
      icon: Icons.cloud_sync_outlined,
      title: 'WebDAV 同步',
      description: '配置服务器 URL、用户名、密码和同步目录。',
    ),
    _SettingsSection(
      icon: Icons.lock_outline,
      title: '端到端加密',
      description: '设置主密码，派生 AES-256-GCM 加密密钥。',
    ),
    _SettingsSection(
      icon: Icons.system_update_alt_outlined,
      title: '应用更新',
      description: '按平台策略检查商店更新或自托管补丁更新。',
    ),
    _SettingsSection(
      icon: Icons.devices_outlined,
      title: '平台能力',
      description: '显示当前设备、平台、权限和功能支持情况。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: _sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final section = _sections[index];
          return Card(
            child: ListTile(
              leading: Icon(section.icon, color: theme.colorScheme.primary),
              title: Text(section.title),
              subtitle: Text(section.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          );
        },
      ),
    );
  }
}

class _SettingsSection {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
