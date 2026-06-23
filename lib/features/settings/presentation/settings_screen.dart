import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/service_providers.dart';
import '../../../core/services/version_service.dart';
import '../../../core/services/webdav_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _webDavUrlController = TextEditingController(text: 'https://example.com/dav');
  final _webDavUserController = TextEditingController();
  final _webDavSecretController = TextEditingController();
  final _masterPasswordController = TextEditingController();
  String _message = '设置项保存在后续安全存储任务中接入。';

  @override
  void dispose() {
    _webDavUrlController.dispose();
    _webDavUserController.dispose();
    _webDavSecretController.dispose();
    _masterPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            icon: Icons.cloud_sync_outlined,
            title: 'WebDAV 同步',
            child: Column(
              children: [
                TextField(
                  controller: _webDavUrlController,
                  decoration: const InputDecoration(
                    labelText: '服务器 URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _webDavUserController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _webDavSecretController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码或 Token',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _testWebDavConnection,
                    icon: const Icon(Icons.cloud_done_outlined),
                    label: const Text('测试连接'),
                  ),
                ),
              ],
            ),
          ),
          _SectionCard(
            icon: Icons.lock_outline,
            title: '端到端加密',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _masterPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '主密码',
                    helperText: '至少 12 位，并包含多种字符类型。',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _initializeEncryption,
                    icon: const Icon(Icons.key_outlined),
                    label: const Text('初始化加密服务'),
                  ),
                ),
              ],
            ),
          ),
          _SectionCard(
            icon: Icons.system_update_alt_outlined,
            title: '应用更新',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('当前版本：0.1.0；默认更新服务需要在构造时配置 manifest 地址。'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _checkUpdateSkeleton,
                  icon: const Icon(Icons.refresh),
                  label: const Text('检查更新能力'),
                ),
              ],
            ),
          ),
          const _SectionCard(
            icon: Icons.devices_outlined,
            title: '平台能力',
            child: Text('Android / iOS / Windows / 鸿蒙平台适配将在后续平台任务中补齐权限、设备 ID 和能力检测。'),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_message),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testWebDavConnection() async {
    try {
      final connected = await ref.read(webDavServiceProvider).connect(
            WebDavConfig(
              serverUrl: _webDavUrlController.text.trim(),
              username: _webDavUserController.text.trim(),
              secret: _webDavSecretController.text,
            ),
          );
      setState(() => _message = connected ? 'WebDAV 连接成功。' : 'WebDAV 连接失败。');
    } catch (error) {
      setState(() => _message = 'WebDAV 连接失败：${_redact(error)}');
    }
  }

  Future<void> _initializeEncryption() async {
    try {
      await ref.read(encryptionServiceProvider).initialize(_masterPasswordController.text);
      _masterPasswordController.clear();
      setState(() => _message = '加密服务已初始化。');
    } catch (error) {
      setState(() => _message = '加密服务初始化失败：${_redact(error)}');
    }
  }

  Future<void> _checkUpdateSkeleton() async {
    try {
      final info = await ref.read(versionServiceProvider).check(
            const VersionContext(
              currentVersion: '0.1.0',
              platform: 'windows',
              channel: 'self-hosted',
            ),
          );
      setState(() => _message = info == null ? '当前无可用更新。' : '发现版本 ${info.version}。');
    } catch (error) {
      setState(() => _message = '更新服务尚未配置 manifest：${_redact(error)}');
    }
  }

  String _redact(Object error) {
    return ref.read(sensitiveValueRedactorProvider).redactError(error).toString();
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
