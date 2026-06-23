import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingzai/core/errors/app_exception.dart';
import 'package:qingzai/core/services/hive_storage_service.dart';
import 'package:qingzai/core/services/storage_service.dart';
import 'package:qingzai/features/todos/models/todo_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late HiveStorageService storage;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'qingzai_hive_storage_test_',
    );
    storage = HiveStorageService(storageDirectory: tempDirectory.path);
    await storage.initialize();
  });

  tearDown(() async {
    await storage.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  group('HiveStorageService', () {
    test('lazily opens configured boxes on first access', () async {
      for (final boxName in StorageBoxNames.allBoxes) {
        expect(await storage.getItemCount(boxName), 0);
      }
    });

    test('saves and reads a single syncable item by id', () async {
      final todo = _todo(id: '11111111-1111-4111-8111-111111111111');

      final saved = await storage.saveItem(StorageBoxNames.todos, todo);
      final loaded = await storage.getItemById<TodoItem>(
        StorageBoxNames.todos,
        todo.id,
      );

      expect(saved, isTrue);
      expect(loaded, isNotNull);
      expect(loaded!.id, todo.id);
      expect(loaded.title, todo.title);
    });

    test('returns null when item id is not found', () async {
      final loaded = await storage.getItemById<TodoItem>(
        StorageBoxNames.todos,
        '22222222-2222-4222-8222-222222222222',
      );

      expect(loaded, isNull);
    });

    test('saves a batch and returns saved item count', () async {
      final todos = [
        _todo(id: '33333333-3333-4333-8333-333333333333', title: 'First'),
        _todo(id: '44444444-4444-4444-8444-444444444444', title: 'Second'),
      ];

      final count = await storage.saveItemsBatch(StorageBoxNames.todos, todos);
      final loaded = await storage.getAllItems<TodoItem>(StorageBoxNames.todos);

      expect(count, 2);
      expect(
        loaded.map((todo) => todo.title),
        containsAll(['First', 'Second']),
      );
    });

    test('returns paged items without materializing callers into a larger list', () async {
      await storage.saveItemsBatch(StorageBoxNames.todos, [
        _todo(id: '10111111-1111-4111-8111-111111111111', title: 'First'),
        _todo(id: '10222222-2222-4222-8222-222222222222', title: 'Second'),
        _todo(id: '10333333-3333-4333-8333-333333333333', title: 'Third'),
      ]);

      final page = await storage.getItemsPage<TodoItem>(
        StorageBoxNames.todos,
        offset: 1,
        limit: 1,
      );

      expect(page, hasLength(1));
      expect(page.single.title, 'Second');
    });

    test('returns syncable changes sorted by Lamport clock and id', () async {
      final older = _todo(
        id: '21111111-1111-4111-8111-111111111111',
        title: 'Older',
        lamportClock: 1,
      );
      final changed = _todo(
        id: '22222222-2222-4222-8222-222222222222',
        title: 'Changed',
        lamportClock: 3,
      );
      final changedTie = _todo(
        id: '23333333-3333-4333-8333-333333333333',
        title: 'Changed tie',
        lamportClock: 3,
      );

      await storage.saveItemsBatch(StorageBoxNames.todos, [changedTie, older, changed]);

      final changes = await storage.getSyncableChangesAfter<TodoItem>(
        StorageBoxNames.todos,
        lamportClock: 1,
      );

      expect(changes.map((todo) => todo.title), ['Changed', 'Changed tie']);
    });

    test('reads a subset by id', () async {
      final first = _todo(id: '31111111-1111-4111-8111-111111111111', title: 'First');
      final second = _todo(id: '32222222-2222-4222-8222-222222222222', title: 'Second');
      await storage.saveItemsBatch(StorageBoxNames.todos, [first, second]);

      final loaded = await storage.getItemsByIds<TodoItem>(
        StorageBoxNames.todos,
        [second.id],
      );

      expect(loaded.keys, [second.id]);
      expect(loaded[second.id]!.title, 'Second');
    });

    test('deleteItem removes an existing item and reports whether it existed', () async {
      final todo = _todo(id: '55555555-5555-4555-8555-555555555555');
      await storage.saveItem(StorageBoxNames.todos, todo);

      final deleted = await storage.deleteItem(StorageBoxNames.todos, todo.id);
      final deletedAgain = await storage.deleteItem(StorageBoxNames.todos, todo.id);

      expect(deleted, isTrue);
      expect(deletedAgain, isFalse);
      expect(
        await storage.getItemById<TodoItem>(StorageBoxNames.todos, todo.id),
        isNull,
      );
    });

    test('clearBox removes all items from a box', () async {
      await storage.saveItemsBatch(StorageBoxNames.todos, [
        _todo(id: '66666666-6666-4666-8666-666666666666'),
        _todo(id: '77777777-7777-4777-8777-777777777777'),
      ]);

      await storage.clearBox(StorageBoxNames.todos);

      expect(await storage.getItemCount(StorageBoxNames.todos), 0);
    });

    test('watchBox emits when a box changes', () async {
      final expectation = expectLater(
        storage.watchBox(StorageBoxNames.todos),
        emits(anything),
      );

      await storage.saveItem(
        StorageBoxNames.todos,
        _todo(id: '88888888-8888-4888-8888-888888888888'),
      );

      await expectation;
    });

    test('rejects items without a valid UUID id', () async {
      expect(
        () => storage.saveItem(StorageBoxNames.todos, {'id': 'not-a-uuid'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects unknown boxes', () async {
      expect(
        () => storage.getItemCount('unknown_box'),
        throwsA(isA<StorageException>()),
      );
    });
  });
}

TodoItem _todo({
  required String id,
  String title = 'Write storage service',
  int lamportClock = 0,
}) {
  final now = DateTime.utc(2026, 1, 1, 12);
  return TodoItem(
    id: id,
    title: title,
    createdAt: now,
    lastModified: now,
    deviceId: 'device-a',
    lamportClock: lamportClock,
  );
}
