import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class LANTransferScreen extends StatelessWidget {
  const LANTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.lan_outlined,
      title: '局域网传输模块',
      description: '用于 mDNS 设备发现、点对点文件发送和接收，后续会接入 LANTransferService。',
      nextSteps: [
        '定义 LANDevice、TransferProgress、ReceivedFile 等数据类。',
        '实现 mDNS 发现和 TLS 文件传输。',
        '实现传输进度、取消、失败恢复和校验和验证。',
      ],
    );
  }
}
