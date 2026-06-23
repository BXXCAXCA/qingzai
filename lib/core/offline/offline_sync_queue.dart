import 'package:uuid/uuid.dart';

import '../errors/app_exception.dart';
import '../services/storage_service.dart';
import 'retry_policy.dart';

class PendingSyncOperation {
  const PendingSyncOperation({
    required this.id,
    required this.boxName,
    required this.reason,
    required this.queuedAt,
    this.attemptCount = 0,
    this.lastError,
    this.nextRetryAt,
  });

  final String id;
  final String boxName;
  final String reason;
  final DateTime queuedAt;
  final int attemptCount;
  final String? lastError;
  final DateTime? nextRetryAt;

  PendingSyncOperation copyWith({
    String? reason,
    int? attemptCount,
    String? lastError,
    DateTime? nextRetryAt,
    bool resetNextRetryAt = false,
  }) {
    return PendingSyncOperation(
      id: id,
      boxName: boxName,
      reason: reason ?? this.reason,
      queuedAt: queuedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      nextRetryAt: resetNextRetryAt ? null : nextRetryAt ?? this.nextRetryAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'boxName': boxName,
      'reason': reason,
      'queuedAt': queuedAt.toIso8601String(),
      'attemptCount': attemptCount,
      'lastError': lastError,
      'nextRetryAt': nextRetryAt?.toIso8601String(),
    };
  }

  factory PendingSyncOperation.fromJson(Map<String, Object?> json) {
    return PendingSyncOperation(
      id: json['id']! as String,
      boxName: json['boxName']! as String,
      reason: json['reason']! as String,
      queuedAt: DateTime.parse(json['queuedAt']! as String),
      attemptCount: json['attemptCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      nextRetryAt: json['nextRetryAt'] == null
          ? null
          : DateTime.parse(json['nextRetryAt']! as String),
    );
  }
}

abstract interface class OfflineSyncQueue {
  Future<PendingSyncOperation> enqueue({
    required String boxName,
    required String reason,
  });

  Future<List<PendingSyncOperation>> pending({DateTime? now});

  Future<void> markAttemptFailed({
    required PendingSyncOperation operation,
    required Object error,
  });

  Future<void> remove(String operationId);

  Future<void> clear();
}

class HiveOfflineSyncQueue implements OfflineSyncQueue {
  HiveOfflineSyncQueue({
    required StorageService storage,
    RetryPolicy retryPolicy = const RetryPolicy(),
    Uuid? uuid,
  })  : _storage = storage,
        _retryPolicy = retryPolicy,
        _uuid = uuid ?? const Uuid();

  static const _reasonManual = 'manual sync request';

  final StorageService _storage;
  final RetryPolicy _retryPolicy;
  final Uuid _uuid;

  @override
  Future<PendingSyncOperation> enqueue({
    required String boxName,
    required String reason,
  }) async {
    _validateBoxName(boxName);
    final normalizedReason = reason.trim().isEmpty ? _reasonManual : reason.trim();

    final existing = await _operationForBox(boxName);
    final operation = existing == null
        ? PendingSyncOperation(
            id: _uuid.v4(),
            boxName: boxName,
            reason: normalizedReason,
            queuedAt: DateTime.now(),
          )
        : existing.copyWith(
            reason: normalizedReason,
            resetNextRetryAt: true,
          );

    await _storage.saveItem<Map<String, Object?>>(
      StorageBoxNames.syncMeta,
      operation.toJson(),
    );
    return operation;
  }

  @override
  Future<List<PendingSyncOperation>> pending({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    final operations = await _allOperations();
    return operations
        .where((operation) =>
            operation.nextRetryAt == null ||
            !operation.nextRetryAt!.isAfter(currentTime))
        .toList(growable: false)
      ..sort((left, right) => left.queuedAt.compareTo(right.queuedAt));
  }

  @override
  Future<void> markAttemptFailed({
    required PendingSyncOperation operation,
    required Object error,
  }) async {
    final attemptCount = operation.attemptCount + 1;
    final updated = operation.copyWith(
      attemptCount: attemptCount,
      lastError: error.toString(),
      nextRetryAt: _retryPolicy.nextRetryAt(attemptCount: attemptCount),
    );

    await _storage.saveItem<Map<String, Object?>>(
      StorageBoxNames.syncMeta,
      updated.toJson(),
    );
  }

  @override
  Future<void> remove(String operationId) async {
    await _storage.deleteItem(StorageBoxNames.syncMeta, operationId);
  }

  @override
  Future<void> clear() async {
    final operations = await _allOperations();
    for (final operation in operations) {
      await remove(operation.id);
    }
  }

  Future<PendingSyncOperation?> _operationForBox(String boxName) async {
    final operations = await _allOperations();
    for (final operation in operations) {
      if (operation.boxName == boxName) {
        return operation;
      }
    }
    return null;
  }

  Future<List<PendingSyncOperation>> _allOperations() async {
    final items = await _storage.getAllItems<Map<dynamic, dynamic>>(
      StorageBoxNames.syncMeta,
    );

    return items
        .where((item) => item.containsKey('boxName') && item.containsKey('queuedAt'))
        .map((item) => PendingSyncOperation.fromJson(
              Map<String, Object?>.from(item),
            ))
        .toList(growable: false);
  }

  void _validateBoxName(String boxName) {
    if (!StorageBoxNames.syncableBoxes.contains(boxName)) {
      throw ValidationException('"$boxName" is not a syncable storage box.');
    }
  }
}
