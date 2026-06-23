import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qingzai/core/services/storage_service.dart';
import 'package:qingzai/features/clipboard/models/clipboard_item.dart';
import 'package:qingzai/features/clipboard/providers/clipboard_provider.dart';
import 'package:qingzai/features/memos/providers/memo_provider.dart';
import 'package:qingzai/features/notes/providers/notes_provider.dart';
import 'package:qingzai/features/pomodoro/models/pomodoro_session.dart';
import 'package:qingzai/features/pomodoro/providers/pomodoro_provider.dart';
import 'package:qingzai/features/todos/providers/todo_provider.dart';

void main() {
  group('business providers', () {
    late _InMemoryStorageService storage;

    setUp(() {
      storage = _InMemoryStorageService();
    });

    test('TodoController creates, toggles, and tombstones todos', () async {
      final controller = TodoController(storage: storage, deviceId: 'device-1');

      final todo = await controller.createTodo(title: 'Ship task', priority: 2);
      expect(todo.deviceId, 'device-1');
      expect(todo.lamportClock, 1);
      expect(controller.state.value, hasLength(1));

      final toggled = await controller.toggleCompleted(todo.id);
      expect(toggled.isCompleted, isTrue);
      expect(toggled.lamportClock, 2);

      final deleted = await controller.deleteTodo(todo.id);
      expect(deleted.isDeleted, isTrue);
      expect(controller.state.value, isEmpty);
      expect(
        (await storage.getItemById(StorageBoxNames.todos, todo.id))!.isDeleted,
        isTrue,
      );
    });

    test('ClipboardController adds history and toggles favorites', () async {
      final controller = ClipboardController(storage: storage, deviceId: 'device-1');

      final item = await controller.addClipboardItem(
        type: ClipboardType.text,
        content: 'hello',
      );
      expect(controller.state.value!.single.content, 'hello');

      final favorite = await controller.toggleFavorite(item.id);
      expect(favorite.isFavorite, isTrue);
      expect(controller.favorites, hasLength(1));

      await controller.deleteClipboardItem(item.id);
      expect(controller.state.value, isEmpty);
    });

    test('NotesController creates notes, searches, pins, and tombstones', () async {
      final controller = NotesController(storage: storage, deviceId: 'device-1');

      final note = await controller.createNote(
        title: 'Design Notes',
        content: '# Markdown body',
        tags: const ['work'],
      );
      expect(controller.search('markdown'), hasLength(1));
      expect(controller.search('work'), hasLength(1));

      final pinned = await controller.togglePinned(note.id);
      expect(pinned.isPinned, isTrue);
      expect(controller.state.value!.first.id, note.id);

      await controller.deleteNote(note.id);
      expect(controller.state.value, isEmpty);
    });

    test('PomodoroController starts, completes, and tombstones sessions', () async {
      final controller = PomodoroController(storage: storage, deviceId: 'device-1');

      final session = await controller.startSession(
        duration: 25 * 60,
        type: PomodoroType.work,
        taskId: 'task-1',
      );
      expect(session.isCompleted, isFalse);
      expect(session.taskId, 'task-1');

      final completed = await controller.completeSession(session.id);
      expect(completed.isCompleted, isTrue);
      expect(completed.endTime, isNotNull);
      expect(controller.completedSessions, hasLength(1));

      await controller.deleteSession(session.id);
      expect(controller.state.value, isEmpty);
    });

    test('MemoController creates memos and appends attachments', () async {
      final controller = MemoController(storage: storage, deviceId: 'device-1');

      final memo = await controller.createMemo(content: 'Remember this');
      expect(controller.state.value!.single.content, 'Remember this');

      final withAttachment = await controller.addAttachment(memo.id, '/tmp/file.pdf');
      expect(withAttachment.attachments, contains('/tmp/file.pdf'));

      await controller.deleteMemo(memo.id);
      expect(controller.state.value, isEmpty);
    });
  });
}

class _InMemoryStorageService implements StorageService {
  final _boxes = <String, Map<String, Object>>{};

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> saveItem<T>(String boxName, T item) async {
    final id = (item as dynamic).id as String;
    _boxes.putIfAbsent(boxName, () => <String, Object>{})[id] = item as Object;
    return true;
  }

  @override
  Future<List<T>> getAllItems<T>(String boxName) async {
    return (_boxes[boxName]?.values ?? const <Object>[]).whereType<T>().toList();
  }

  @override
  Future<T?> getItemById<T>(String boxName, String id) async {
    return _boxes[boxName]?[id] as T?;
  }

  @override
  Future<bool> deleteItem(String boxName, String id) async {
    return _boxes[boxName]?.remove(id) != null;
  }

  @override
  Future<int> saveItemsBatch<T>(String boxName, List<T> items) async {
    for (final item in items) {
      await saveItem(boxName, item);
    }
    return items.length;
  }

  @override
  Future<void> clearBox(String boxName) async {
    _boxes[boxName]?.clear();
  }

  @override
  Future<int> getItemCount(String boxName) async {
    return _boxes[boxName]?.length ?? 0;
  }

  @override
  Stream<BoxEvent> watchBox(String boxName) {
    return const Stream<BoxEvent>.empty();
  }
}
