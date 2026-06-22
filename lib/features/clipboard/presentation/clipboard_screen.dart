import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class ClipboardScreen extends StatelessWidget {
  const ClipboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.content_paste_outlined,
      title: '剪切板同步模块',
      description: '用于管理文本、图片和文件剪切板历史，后续会接入 ClipboardItem、系统剪切板监听和同步服务。',
      nextSteps: [
        '定义 ClipboardType 与 ClipboardItem 数据模型。',
        '实现剪切板历史、收藏和缩略图显示。',
        '处理不同平台的剪切板权限和能力差异。',
      ],
    );
  }
}
