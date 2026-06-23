import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note_item.dart';
import '../providers/notes_provider.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notesProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: '搜索标题、内容或标签',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _EmptyNotes(
                  icon: Icons.error_outline,
                  title: '笔记加载失败',
                  message: '$error',
                  action: OutlinedButton(
                    onPressed: () => ref.read(notesProvider.notifier).load(),
                    child: const Text('重试'),
                  ),
                ),
                data: (_) {
                  final notes = ref.read(notesProvider.notifier).search(_query);
                  if (notes.isEmpty) {
                    return _EmptyNotes(
                      icon: Icons.sticky_note_2_outlined,
                      title: _query.isEmpty ? '还没有笔记' : '没有匹配的笔记',
                      message: '创建一条 Markdown 笔记，支持标签、置顶和颜色标识。',
                      action: FilledButton.icon(
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('新建笔记'),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref.read(notesProvider.notifier).load(),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 420,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.35,
                      ),
                      itemCount: notes.length,
                      itemBuilder: (context, index) => _NoteCard(note: notes[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('新建笔记'),
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final tagsController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建笔记'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Markdown 内容',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: '标签，用逗号分隔',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty || content.isEmpty) return;
              await ref.read(notesProvider.notifier).createNote(
                    title: title,
                    content: content,
                    tags: tagsController.text
                        .split(',')
                        .map((tag) => tag.trim())
                        .where((tag) => tag.isNotEmpty)
                        .toList(),
                  );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    titleController.dispose();
    contentController.dispose();
    tagsController.dispose();
  }
}

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note});

  final NoteItem note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(note.title, style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: note.isPinned ? '取消置顶' : '置顶',
                  icon: Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                  onPressed: () => ref.read(notesProvider.notifier).togglePinned(note.id),
                ),
                IconButton(
                  tooltip: '删除',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref.read(notesProvider.notifier).deleteNote(note.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                note.content,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [for (final tag in note.tags) Chip(label: Text(tag))],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({
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
