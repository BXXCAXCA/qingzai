import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clipboard_item.dart';
import '../providers/clipboard_provider.dart';

class ClipboardScreen extends ConsumerStatefulWidget {
  const ClipboardScreen({super.key});

  @override
  ConsumerState<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends ConsumerState<ClipboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(clipboardProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clipboardProvider);

    return Scaffold(
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _MessageState(
            icon: Icons.error_outline,
            title: '剪切板加载失败',
            message: '$error',
            action: OutlinedButton(
              onPressed: () => ref.read(clipboardProvider.notifier).load(),
              child: const Text('重试'),
            ),
          ),
          data: (items) => items.isEmpty
              ? _MessageState(
                  icon: Icons.content_paste_outlined,
                  title: '还没有剪切板历史',
                  message: '先手动添加一条文本记录，后续可接入系统剪切板监听。',
                  action: FilledButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('添加文本'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(clipboardProvider.notifier).load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _ClipboardTile(item: items[index]),
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('添加'),
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final contentController = TextEditingController();
    var type = ClipboardType.text;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('添加剪切板项'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<ClipboardType>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: '类型',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: ClipboardType.text, child: Text('文本')),
                      DropdownMenuItem(value: ClipboardType.image, child: Text('图片路径')),
                      DropdownMenuItem(value: ClipboardType.file, child: Text('文件路径')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '内容或路径',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    final content = contentController.text.trim();
                    if (content.isEmpty) return;
                    await ref.read(clipboardProvider.notifier).addClipboardItem(
                          type: type,
                          content: content,
                        );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    contentController.dispose();
  }
}

class _ClipboardTile extends ConsumerWidget {
  const _ClipboardTile({required this.item});

  final ClipboardItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = switch (item.type) {
      ClipboardType.text => Icons.text_fields,
      ClipboardType.image => Icons.image_outlined,
      ClipboardType.file => Icons.insert_drive_file_outlined,
    };

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(
          item.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('来自 ${item.deviceId} · ${item.timestamp.toLocal()}'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: item.isFavorite ? '取消收藏' : '收藏',
              icon: Icon(item.isFavorite ? Icons.star : Icons.star_border),
              onPressed: () => ref.read(clipboardProvider.notifier).toggleFavorite(item.id),
            ),
            IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref.read(clipboardProvider.notifier).deleteClipboardItem(item.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
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
