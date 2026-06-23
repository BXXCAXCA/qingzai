import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pomodoro_session.dart';
import '../providers/pomodoro_provider.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(pomodoroProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pomodoroProvider);

    return SafeArea(
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text('番茄钟加载失败：$error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.read(pomodoroProvider.notifier).load(),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
        data: (sessions) {
          final active = sessions.where((session) => !session.isCompleted).firstOrNull;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TimerCard(active: active),
              const SizedBox(height: 16),
              Text('会话历史', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (sessions.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('还没有番茄钟会话。先启动一个 25 分钟专注。'),
                  ),
                )
              else
                for (final session in sessions) _SessionTile(session: session),
            ],
          );
        },
      ),
    );
  }
}

class _TimerCard extends ConsumerWidget {
  const _TimerCard({required this.active});

  final PomodoroSession? active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeSession = active;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('番茄钟', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              activeSession == null
                  ? '选择一个模式开始记录专注时间。'
                  : '当前会话：${_typeLabel(activeSession.type)} · ${activeSession.duration ~/ 60} 分钟',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => ref.read(pomodoroProvider.notifier).startSession(
                        duration: 25 * 60,
                        type: PomodoroType.work,
                      ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始专注 25 分钟'),
                ),
                OutlinedButton(
                  onPressed: () => ref.read(pomodoroProvider.notifier).startSession(
                        duration: 5 * 60,
                        type: PomodoroType.shortBreak,
                      ),
                  child: const Text('短休息 5 分钟'),
                ),
                OutlinedButton(
                  onPressed: () => ref.read(pomodoroProvider.notifier).startSession(
                        duration: 15 * 60,
                        type: PomodoroType.longBreak,
                      ),
                  child: const Text('长休息 15 分钟'),
                ),
                if (activeSession != null)
                  FilledButton.tonalIcon(
                    onPressed: () => ref.read(pomodoroProvider.notifier).completeSession(activeSession.id),
                    icon: const Icon(Icons.done),
                    label: const Text('标记完成'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final PomodoroSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: Icon(session.isCompleted ? Icons.task_alt : Icons.hourglass_top),
        title: Text('${_typeLabel(session.type)} · ${session.duration ~/ 60} 分钟'),
        subtitle: Text('开始：${session.startTime.toLocal()}'),
        trailing: IconButton(
          tooltip: '删除',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => ref.read(pomodoroProvider.notifier).deleteSession(session.id),
        ),
      ),
    );
  }
}

String _typeLabel(PomodoroType type) {
  return switch (type) {
    PomodoroType.work => '工作',
    PomodoroType.shortBreak => '短休息',
    PomodoroType.longBreak => '长休息',
  };
}
