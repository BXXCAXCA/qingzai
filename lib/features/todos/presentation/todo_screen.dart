import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.check_circle_outline,
      title: '待办事项模块',
      description: '用于创建、编辑和管理待办事项，后续会接入 TodoItem、HiveStorageService 和 TodoProvider。',
      nextSteps: [
        '实现 TodoItem 数据模型和 Hive 适配器。',
        '实现创建、更新、完成状态切换、标签和优先级筛选。',
        '接入同步元数据：deviceId、逻辑时钟、tombstone。',
      ],
    );
  }
}
