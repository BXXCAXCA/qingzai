import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/service_providers.dart';
import '../../../core/services/lan_transfer_service.dart';
import '../../../core/services/socket_lan_transfer_service.dart';

class LANTransferScreen extends ConsumerStatefulWidget {
  const LANTransferScreen({super.key});

  @override
  ConsumerState<LANTransferScreen> createState() => _LANTransferScreenState();
}

class _LANTransferScreenState extends ConsumerState<LANTransferScreen> {
  final _deviceNameController = TextEditingController(text: 'Qing Zai Device');
  final _targetIpController = TextEditingController(text: '127.0.0.1');
  final _targetPortController = TextEditingController();
  final _filePathController = TextEditingController();

  StreamSubscription<ReceivedFile>? _receiveSubscription;
  String _status = '接收服务未启动';
  TransferProgress? _latestProgress;

  @override
  void dispose() {
    _receiveSubscription?.cancel();
    _deviceNameController.dispose();
    _targetIpController.dispose();
    _targetPortController.dispose();
    _filePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(lanTransferServiceProvider);
    final socketService = service is SocketLanTransferService ? service : null;
    final progress = _latestProgress;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('接收服务', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _deviceNameController,
                    decoration: const InputDecoration(
                      labelText: '设备名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_status),
                  if (socketService?.boundPort != null)
                    Text('本机接收端口：${socketService!.boundPort}'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _startReceiver(service),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('启动接收'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _stopReceiver(service),
                        icon: const Icon(Icons.stop),
                        label: const Text('停止'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('发送文件', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _targetIpController,
                          decoration: const InputDecoration(
                            labelText: '目标 IP',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _targetPortController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '端口',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _filePathController,
                    decoration: const InputDecoration(
                      labelText: '本地文件路径',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _sendFile(service),
                    icon: const Icon(Icons.send),
                    label: const Text('发送文件'),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: progress.progress),
                    const SizedBox(height: 8),
                    Text('状态：${progress.status.name} · ${(progress.progress * 100).toStringAsFixed(0)}%'),
                    if (progress.errorMessage != null) Text(progress.errorMessage!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('说明：当前 UI 接入 TCP 传输核心能力；mDNS 自动发现和 TLS 证书配置将在平台适配阶段继续完善。'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startReceiver(LanTransferService service) async {
    await _receiveSubscription?.cancel();
    await service.startDiscovery(deviceName: _deviceNameController.text.trim());
    _receiveSubscription = service.receiveFiles().listen(
      (file) {
        setState(() {
          _status = '收到文件：${file.fileName} (${file.fileSize} bytes)';
        });
      },
      onError: (Object error) {
        setState(() => _status = '接收失败：$error');
      },
    );
    setState(() => _status = '接收服务已启动');
  }

  Future<void> _stopReceiver(LanTransferService service) async {
    await _receiveSubscription?.cancel();
    _receiveSubscription = null;
    await service.stopDiscovery();
    setState(() => _status = '接收服务已停止');
  }

  Future<void> _sendFile(LanTransferService service) async {
    final port = int.tryParse(_targetPortController.text.trim());
    if (port == null) {
      setState(() => _status = '请输入有效端口');
      return;
    }

    final target = LanDevice(
      id: 'manual-target',
      name: '手动目标设备',
      ipAddress: _targetIpController.text.trim(),
      port: port,
      platform: 'manual',
    );

    await for (final progress in service.sendFile(
      targetDevice: target,
      filePath: _filePathController.text.trim(),
      secure: false,
    )) {
      if (!mounted) return;
      setState(() => _latestProgress = progress);
    }
  }
}
