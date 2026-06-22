import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.sticky_note_2_outlined,
      title: '笔记与备忘模块',
      description: '用于 Markdown 笔记、桌面便签和快速备忘录，后续会拆分 NoteItem 与 MemoItem 的业务逻辑。',
      nextSteps: [
        '实现 NoteItem 与 MemoItem 数据模型。',
        '实现 Markdown 编辑、置顶、颜色标识和附件管理。',
        '统一接入本地存储、加密同步和冲突解决。',
      ],
    );
  }
}
