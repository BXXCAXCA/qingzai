import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const _features = [
    _FeatureCardData(
      icon: Icons.check_circle_outline,
      title: '待办事项',
      description: '创建、编辑、标记完成，支持优先级、截止日期和标签。',
    ),
    _FeatureCardData(
      icon: Icons.content_paste_outlined,
      title: '剪切板同步',
      description: '同步文本、图片和文件剪切板历史，支持收藏。',
    ),
    _FeatureCardData(
      icon: Icons.sticky_note_2_outlined,
      title: '笔记与备忘',
      description: 'Markdown 笔记、快速备忘、标签、置顶和颜色标识。',
    ),
    _FeatureCardData(
      icon: Icons.timer_outlined,
      title: '番茄钟',
      description: '工作、短休息、长休息会话，可关联待办事项。',
    ),
    _FeatureCardData(
      icon: Icons.sync_outlined,
      title: 'WebDAV 同步',
      description: '离线优先，本地变更加密后同步到用户自己的 WebDAV。',
    ),
    _FeatureCardData(
      icon: Icons.lan_outlined,
      title: '局域网传输',
      description: 'mDNS 设备发现与点对点文件传输。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('欢迎使用轻载', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    '一个无服务器、端到端加密、离线优先的跨平台生产力应用。',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.45,
              ),
              itemCount: _features.length,
              itemBuilder: (context, index) {
                final feature = _features[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          feature.icon,
                          color: theme.colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(feature.title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            feature.description,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCardData {
  const _FeatureCardData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
