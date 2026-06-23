import '../services/storage_service.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_result.dart';
import 'connectivity_monitor.dart';
import 'offline_sync_queue.dart';

class OfflineSyncCoordinator {
  OfflineSyncCoordinator({
    required ConnectivityMonitor connectivity,
    required OfflineSyncQueue queue,
    required SyncManager syncManager,
  })  : _connectivity = connectivity,
        _queue = queue,
        _syncManager = syncManager;

  final ConnectivityMonitor _connectivity;
  final OfflineSyncQueue _queue;
  final SyncManager _syncManager;

  Future<SyncResult> syncOrQueue({
    List<String> boxNames = StorageBoxNames.syncableBoxes,
    String reason = 'manual sync request',
  }) async {
    final online = await _connectivity.isOnline;
    if (!online) {
      for (final boxName in boxNames) {
        await _queue.enqueue(boxName: boxName, reason: reason);
      }

      return SyncResult(
        uploaded: 0,
        downloaded: 0,
        errors: const ['Device is offline. Sync request has been queued.'],
        completedAt: DateTime.now(),
      );
    }

    final result = await _syncManager.performSync(boxNames: boxNames);
    if (result.hasErrors) {
      for (final boxName in boxNames) {
        await _queue.enqueue(boxName: boxName, reason: result.errors.join('\n'));
      }
    }

    return result;
  }

  Future<SyncResult> flushQueue() async {
    final online = await _connectivity.isOnline;
    if (!online) {
      return SyncResult(
        uploaded: 0,
        downloaded: 0,
        errors: const ['Device is offline. Pending sync queue was not flushed.'],
        completedAt: DateTime.now(),
      );
    }

    final operations = await _queue.pending();
    if (operations.isEmpty) {
      return SyncResult(
        uploaded: 0,
        downloaded: 0,
        errors: const [],
        completedAt: DateTime.now(),
      );
    }

    var uploaded = 0;
    var downloaded = 0;
    final errors = <String>[];

    for (final operation in operations) {
      try {
        final result = await _syncManager.performSync(
          boxNames: [operation.boxName],
        );
        uploaded += result.uploaded;
        downloaded += result.downloaded;

        if (result.hasErrors) {
          final error = result.errors.join('\n');
          errors.add(error);
          await _queue.markAttemptFailed(operation: operation, error: error);
        } else {
          await _queue.remove(operation.id);
        }
      } catch (error) {
        errors.add(error.toString());
        await _queue.markAttemptFailed(operation: operation, error: error);
      }
    }

    return SyncResult(
      uploaded: uploaded,
      downloaded: downloaded,
      errors: List.unmodifiable(errors),
      completedAt: DateTime.now(),
    );
  }

  Stream<SyncResult> flushWhenOnline() async* {
    await for (final online in _connectivity.onOnlineChanged) {
      if (online) {
        yield await flushQueue();
      }
    }
  }
}
