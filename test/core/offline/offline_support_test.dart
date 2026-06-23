import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qingzai/core/errors/app_exception.dart';
import 'package:qingzai/core/errors/error_messages.dart';
import 'package:qingzai/core/offline/offline.dart';
import 'package:qingzai/core/services/storage_service.dart';
import 'package:qingzai/core/sync/sync_manager.dart';
import 'package:qingzai/core/sync/sync_result.dart';
import 'package:qingzai/core/models/syncable_model.dart';

void main() {
  group('RetryPolicy', () {
    test('uses bounded exponential backoff', () {
      const policy = RetryPolicy(
        initialDelay: Duration(seconds: 2),
        maxDelay: Duration(seconds: 10),
        multiplier: 2,
      );

      expect(policy.delayForAttempt(0), Duration.zero);
      expect(policy.delayForAttempt(1), const Duration(seconds: 2));
      expect(policy.delayForAttempt(2), const Duration(seconds: 4));
      expect(policy.delayForAttempt(3), const Duration(seconds: 8));
      expect(policy.delayForAttempt(4), const Duration(seconds: 10));
    });
  });

  group('HiveOfflineSyncQueue', () {
    late _InMemoryStorage storage;
    late HiveOfflineSyncQueue queue;

    setUp(() {
      storage = _InMemoryStorage();
      queue = HiveOfflineSyncQueue(
        storage: storage,
        retryPolicy: const RetryPolicy(
          initialDelay: Duration(seconds: 1),
          maxDelay: Duration(seconds: 8),
        ),
      );
    });

    test('enqueues one pending operation per syncable box', () async {
      final first = await queue.enqueue(
        boxName: StorageBoxNames.todos,
        reason: 'offline',
      );
      final second = await queue.enqueue(
        boxName: StorageBoxNames.todos,
        reason: 'still offline',
      );

      final pending = await queue.pending();

      expect(first.id, second.id);
      expect(pending, hasLength(1));
      expect(pending.single.reason, 'still offline');
    });

    test('rejects non-syncable boxes', () async {
      await expectLater(
        queue.enqueue(boxName: StorageBoxNames.syncMeta, reason: 'invalid'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('failed attempts are delayed until next retry time', () async {
      final operation = await queue.enqueue(
        boxName: StorageBoxNames.todos,
        reason: 'network error',
      );
      await queue.markAttemptFailed(operation: operation, error: 'boom');

      expect(await queue.pending(), isEmpty);
      expect(
        await queue.pending(now: DateTime.now().add(const Duration(seconds: 2))),
        hasLength(1),
      );
    });
  });

  group('OfflineSyncCoordinator', () {
    late _FakeConnectivityMonitor connectivity;
    late _InMemoryStorage storage;
    late HiveOfflineSyncQueue queue;
    late _FakeSyncManager syncManager;
    late OfflineSyncCoordinator coordinator;

    setUp(() {
      connectivity = _FakeConnectivityMonitor(isOnline: false);
      storage = _InMemoryStorage();
      queue = HiveOfflineSyncQueue(storage: storage);
      syncManager = _FakeSyncManager();
      coordinator = OfflineSyncCoordinator(
        connectivity: connectivity,
        queue: queue,
        syncManager: syncManager,
      );
    });

    test('syncOrQueue stores requests while offline', () async {
      final result = await coordinator.syncOrQueue(
        boxNames: const [StorageBoxNames.todos],
        reason: 'offline edit',
      );

      expect(result.hasErrors, isTrue);
      expect(syncManager.calls, isEmpty);
      expect(await queue.pending(), hasLength(1));
    });

    test('flushQueue replays pending operations when online', () async {
      await coordinator.syncOrQueue(
        boxNames: const [StorageBoxNames.todos],
      );
      connectivity.setOnline(true);

      final result = await coordinator.flushQueue();

      expect(result.hasErrors, isFalse);
      expect(syncManager.calls, [StorageBoxNames.todos]);
      expect(await queue.pending(), isEmpty);
    });

    test('flushQueue keeps failed operations for retry', () async {
      await queue.enqueue(boxName: StorageBoxNames.notes, reason: 'retry me');
      connectivity.setOnline(true);
      syncManager.nextResult = SyncResult(
        uploaded: 0,
        downloaded: 0,
        errors: const ['remote failure'],
        completedAt: DateTime.now(),
      );

      final result = await coordinator.flushQueue();

      expect(result.hasErrors, isTrue);
      expect(syncManager.calls, [StorageBoxNames.notes]);
      expect(await queue.pending(), isEmpty);
      expect(
        await queue.pending(now: DateTime.now().add(const Duration(minutes: 10))),
        hasLength(1),
      );
    });
  });

  group('ErrorMessageFormatter', () {
    test('maps known exceptions to friendly messages', () {
      const formatter = ErrorMessageFormatter();

      expect(
        formatter.format(const WebDavException('cannot connect')),
        contains('WebDAV'),
      );
      expect(
        formatter.format(const AuthenticationException('bad password')),
        contains('主密码'),
      );
      expect(
        formatter.format(Object()),
        contains('未知错误'),
      );
    });
  });

  group('AppStorageSpaceService', () {
    test('calculates recursive directory size', () async {
      final tempDir = await Directory.systemTemp.createTemp('qingzai_storage_test_');
      try {
        await File('${tempDir.path}/a.txt').writeAsString('12345');
        final nested = Directory('${tempDir.path}/nested');
        await nested.create();
        await File('${nested.path}/b.txt').writeAsString('123');

        const service = AppStorageSpaceService();
        final size = await service.calculateDirectorySize(tempDir);

        expect(size, 8);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}

class _FakeConnectivityMonitor implements ConnectivityMonitor {
  _FakeConnectivityMonitor({required bool isOnline}) : _online = isOnline;

  final _controller = StreamController<bool>.broadcast();
  bool _online;

  void setOnline(bool value) {
    _online = value;
    _controller.add(value);
  }

  @override
  Future<bool> get isOnline async => _online;

  @override
  Stream<bool> get onOnlineChanged => _controller.stream;
}

class _FakeSyncManager implements SyncManager {
  final calls = <String>[];
  SyncResult? nextResult;

  @override
  Future<SyncResult> performSync({
    List<String> boxNames = StorageBoxNames.syncableBoxes,
  }) async {
    calls.addAll(boxNames);
    return nextResult ??
        SyncResult(
          uploaded: 1,
          downloaded: 0,
          errors: const [],
          completedAt: DateTime.now(),
        );
  }

  @override
  SyncableModel resolveConflict(SyncableModel local, SyncableModel remote) {
    return local;
  }
}

class _InMemoryStorage implements StorageService {
  final _boxes = <String, Map<String, Object?>>{
    for (final boxName in StorageBoxNames.allBoxes) boxName: <String, Object?>{},
  };

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> saveItem<T>(String boxName, T item) async {
    final id = (item as Map<String, Object?>)['id']! as String;
    _boxes[boxName]![id] = item;
    return true;
  }

  @override
  Future<List<T>> getAllItems<T>(String boxName) async {
    return _boxes[boxName]!.values.cast<T>().toList(growable: false);
  }

  @override
  Future<T?> getItemById<T>(String boxName, String id) async {
    return _boxes[boxName]![id] as T?;
  }

  @override
  Future<bool> deleteItem(String boxName, String id) async {
    return _boxes[boxName]!.remove(id) != null;
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
    _boxes[boxName]!.clear();
  }

  @override
  Future<int> getItemCount(String boxName) async {
    return _boxes[boxName]!.length;
  }

  @override
  Stream<BoxEvent> watchBox(String boxName) {
    return const Stream<BoxEvent>.empty();
  }
}
