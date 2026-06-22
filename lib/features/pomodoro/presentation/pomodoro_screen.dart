import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class PomodoroScreen extends StatelessWidget {
  const PomodoroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.timer_outlined,
      title: '番茄钟模块',
      description: '用于工作、短休息和长休息计时，后续会接入 PomodoroSession 与本地通知。',
      nextSteps: [
        '实现 PomodoroType 与 PomodoroSession 数据模型。',
        '实现倒计时状态机、会话完成记录和历史查询。',
        '支持将番茄钟会话关联到待办事项。',
      ],
    );
  }
}
