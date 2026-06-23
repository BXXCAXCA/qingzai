import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/memo_item.dart';
import '../providers/memo_provider.dart';

class MemoScreen extends ConsumerStatefulWidget {
  const MemoScreen({super.key});

  @override
  ConsumerState<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends ConsumerState<MemoScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(memoProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoProvider);

    return Scaffold(
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _MemoMessage(
            icon: Icons.error_outline,
            title: '备忘录加载失败',
            message: '$error',
            action: OutlinedButton(
              onPressed: () => ref.read(memoProvider.notifier).load(),
              child: const Text('重试'),
            ),
          ),
          data: (memos) => memos.isEmpty
              ? _MemoMessage(
                  icon: Icons.edit_note_outlined,
                  title: '还没有备忘录',
                  message: '快速记录临时想法、链接或附件路径。',
                  action: FilledButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('新建备忘'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(memoProvider.notifier).load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: memos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _MemoTile(memo: memos[index]),
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('新建备忘'),
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final contentController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建备忘录'),
        content: TextField(
          controller: contentController,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: '内容',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final content = contentController.text.trim();
              if (content.isEmpty) return;
              await ref.read(memoProvider.notifier).createMemo(content: content);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    contentController.dispose();
  }
}

class _MemoTile extends ConsumerWidget {
  const _MemoTile({required this.memo});

  final MemoItem memo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.edit_note)),
        title: Text(memo.content, maxLines: 3, overflow: TextOverflow.ellipsis),
        subtitle: Text('附件 ${memo.attachments.length} 个 · ${memo.lastModified.toLocal()}'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: '添加附件路径',
              icon: const Icon(Icons.attach_file),
              onPressed: () => _showAddAttachment(context, ref),
            ),
            IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref.read(memoProvider.notifier).deleteMemo(memo.id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddAttachment(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加附件路径'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '本地路径或 URI',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              await ref.read(memoProvider.notifier).addAttachment(memo.id, value);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );

    controller.dispose();
  }
}

class _MemoMessage extends StatelessWidget {
  const _MemoMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
