import 'package:flutter_test/flutter_test.dart';
import 'package:qingzai/features/clipboard/models/clipboard_item.dart';
import 'package:qingzai/features/memos/models/memo_item.dart';
import 'package:qingzai/features/notes/models/note_item.dart';
import 'package:qingzai/features/pomodoro/models/pomodoro_session.dart';
import 'package:qingzai/features/todos/models/todo_item.dart';

void main() {
  final now = DateTime.utc(2026, 6, 22, 10, 30);
  const id = '550e8400-e29b-41d4-a716-446655440000';
  const deviceId = 'device-alpha';

  group('TodoItem', () {
    test('serializes and deserializes without data loss', () {
      final item = TodoItem(
        id: id,
        title: '完成工程化骨架',
        description: '实现模型层',
        isCompleted: false,
        createdAt: now,
        dueDate: now.add(const Duration(days: 1)),
        priority: 2,
        tags: const <String>['qingzai', 'mvp'],
        lastModified: now,
        deviceId: deviceId,
        lamportClock: 7,
      );

      final restored = TodoItem.fromJson(item.toJson());

      expect(restored.toJson(), equals(item.toJson()));
    });

    test('validates title and priority', () {
      expect(
        () => TodoItem(
          id: id,
          title: '',
          createdAt: now,
          lastModified: now,
          deviceId: deviceId,
        ),
        throwsArgumentError,
      );

      expect(
        () => TodoItem(
          id: id,
          title: 'Invalid priority',
          createdAt: now,
          lastModified: now,
          deviceId: deviceId,
          priority: 3,
        ),
        throwsArgumentError,
      );
    });

    test('copyWith advances lamport clock by default', () {
      final item = TodoItem(
        id: id,
        title: '初始任务',
        createdAt: now,
        lastModified: now,
        deviceId: deviceId,
        lamportClock: 1,
      );

      final updated = item.copyWith(title: '更新任务');

      expect(updated.title, '更新任务');
      expect(updated.lamportClock, 2);
    });
  });

  group('ClipboardItem', () {
    test('serializes enum and thumbnail fields', () {
      final item = ClipboardItem(
        id: id,
        type: ClipboardType.image,
        content: '/tmp/image.png',
        timestamp: now,
        deviceId: deviceId,
        isFavorite: true,
        thumbnail: 'base64-thumbnail',
        lamportClock: 2,
      );

      final restored = ClipboardItem.fromJson(item.toJson());

      expect(restored.toJson(), equals(item.toJson()));
    });
  });

  group('NoteItem', () {
    test('serializes markdown notes', () {
      final item = NoteItem(
        id: id,
        title: '设计记录',
        content: '# Markdown',
        createdAt: now,
        lastModified: now,
        tags: const <String>['note'],
        isPinned: true,
        deviceId: deviceId,
        color: 'yellow',
        lamportClock: 3,
      );

      final restored = NoteItem.fromJson(item.toJson());

      expect(restored.toJson(), equals(item.toJson()));
    });
  });

  group('PomodoroSession', () {
    test('serializes pomodoro sessions', () {
      final item = PomodoroSession(
        id: id,
        startTime: now,
        endTime: now.add(const Duration(minutes: 25)),
        duration: 1500,
        type: PomodoroType.work,
        isCompleted: true,
        taskId: id,
        deviceId: deviceId,
        lamportClock: 4,
      );

      final restored = PomodoroSession.fromJson(item.toJson());

      expect(restored.toJson(), equals(item.toJson()));
    });

    test('validates positive duration', () {
      expect(
        () => PomodoroSession(
          id: id,
          startTime: now,
          duration: 0,
          type: PomodoroType.work,
          deviceId: deviceId,
        ),
        throwsArgumentError,
      );
    });
  });

  group('MemoItem', () {
    test('serializes attachments', () {
      final item = MemoItem(
        id: id,
        content: '临时备忘',
        createdAt: now,
        lastModified: now,
        deviceId: deviceId,
        attachments: const <String>['/tmp/a.txt'],
        lamportClock: 5,
      );

      final restored = MemoItem.fromJson(item.toJson());

      expect(restored.toJson(), equals(item.toJson()));
    });
  });

  group('shared sync validation', () {
    test('rejects invalid UUIDs', () {
      expect(
        () => TodoItem(
          id: 'not-a-uuid',
          title: 'Invalid id',
          createdAt: now,
          lastModified: now,
          deviceId: deviceId,
        ),
        throwsArgumentError,
      );
    });

    test('preserves tombstone flag in JSON', () {
      final item = MemoItem(
        id: id,
        content: '删除同步项',
        createdAt: now,
        lastModified: now,
        deviceId: deviceId,
        isDeleted: true,
        lamportClock: 8,
      );

      final restored = MemoItem.fromJson(item.toJson());

      expect(restored.isDeleted, isTrue);
      expect(restored.lamportClock, 8);
    });
  });
}
