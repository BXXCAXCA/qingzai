import 'dart:convert';

import '../../features/clipboard/models/clipboard_item.dart';
import '../../features/memos/models/memo_item.dart';
import '../../features/notes/models/note_item.dart';
import '../../features/pomodoro/models/pomodoro_session.dart';
import '../../features/todos/models/todo_item.dart';
import '../errors/app_exception.dart';
import '../models/syncable_model.dart';
import '../services/encryption_service.dart';
import '../services/storage_service.dart';
import '../services/webdav_service.dart';
import 'sync_result.dart';

abstract interface class SyncManager {
  Future<SyncResult> performSync({
    List<String> boxNames = StorageBoxNames.syncableBoxes,
  });

  SyncableModel resolveConflict(SyncableModel local, SyncableModel remote);
}

class DefaultSyncManager implements SyncManager {
  DefaultSyncManager({
    required StorageService storage,
    required WebDavService webDav,
    required EncryptionService encryption,
    ConflictResolver conflictResolver = const ConflictResolver(),
  })  : _storage = storage,
        _webDav = webDav,
        _encryption = encryption,
        _conflictResolver = conflictResolver;

  final StorageService _storage;
  final WebDavService _webDav;
  final EncryptionService _encryption;
  final ConflictResolver _conflictResolver;

  @override
  Future<SyncResult> performSync({
    List<String> boxNames = StorageBoxNames.syncableBoxes,
  }) async {
    var uploaded = 0;
    var downloaded = 0;
    final errors = <String>[];
    final metadata = await _loadMetadata();

    for (final boxName in boxNames) {
      try {
        await _ensureRemoteDirectory(boxName);

        final remoteChanges = await _getRemoteChanges(boxName, metadata);
        final conflictWinnersToUpload = <String, SyncableModel>{};
        for (final remoteFile in remoteChanges) {
          final outcome = await _downloadAndMergeItem(
            boxName: boxName,
            remotePath: remoteFile.path,
          );
          downloaded++;
          metadata.setEtag(remoteFile.path, remoteFile.etag);

          if (outcome.shouldUploadWinner) {
            conflictWinnersToUpload[outcome.item.id] = outcome.item;
          } else {
            metadata.recordClock(boxName, outcome.item.lamportClock);
          }
        }

        final localChanges = await _getLocalChanges(boxName, metadata);
        final itemsToUpload = <String, SyncableModel>{
          for (final item in localChanges) item.id: item,
          ...conflictWinnersToUpload,
        }.values;

        for (final item in itemsToUpload) {
          final remotePath = _remotePathFor(boxName, item.id);
          final uploadResult = await _uploadItem(
            boxName: boxName,
            item: item,
            etag: metadata.etagFor(remotePath),
          );

          if (uploadResult.success) {
            uploaded++;
            metadata.setEtag(remotePath, uploadResult.etag);
            metadata.recordClock(boxName, item.lamportClock);
          } else {
            errors.add(
              'Error uploading $boxName/${item.id}: '
              '${uploadResult.errorMessage ?? 'unknown error'}',
            );
          }
        }
      } catch (error) {
        errors.add('Error syncing $boxName: $error');
      }
    }

    try {
      await _saveMetadata(metadata);
    } catch (error) {
      errors.add('Error saving sync metadata: $error');
    }

    return SyncResult(
      uploaded: uploaded,
      downloaded: downloaded,
      errors: List<String>.unmodifiable(errors),
      completedAt: DateTime.now(),
    );
  }

  @override
  SyncableModel resolveConflict(SyncableModel local, SyncableModel remote) {
    return _conflictResolver.resolve(local, remote);
  }

  Future<List<SyncableModel>> _getLocalChanges(
    String boxName,
    _SyncMetadata metadata,
  ) async {
    final lastSyncedClock = metadata.clockFor(boxName);
    final items = await _storage.getAllItems<SyncableModel>(boxName);

    return items
        .where((item) => item.lamportClock > lastSyncedClock)
        .toList(growable: false);
  }

  Future<UploadResult> _uploadItem({
    required String boxName,
    required SyncableModel item,
    String? etag,
  }) async {
    final jsonString = jsonEncode(item.toJson());
    final plainData = utf8.encode(jsonString);
    final encryptedData = await _encryption.encryptBytes(plainData);

    return _webDav.uploadFile(
      remotePath: _remotePathFor(boxName, item.id),
      data: encryptedData.toBytes(),
      etag: etag,
    );
  }

  Future<List<FileMetadata>> _getRemoteChanges(
    String boxName,
    _SyncMetadata metadata,
  ) async {
    final remoteFiles = await _webDav.listDirectory(boxName);

    return remoteFiles
        .where((file) => !file.isDirectory)
        .where((file) => file.path.endsWith('.enc'))
        .where((file) => metadata.etagFor(file.path) != file.etag)
        .toList(growable: false);
  }

  Future<_MergeOutcome> _downloadAndMergeItem({
    required String boxName,
    required String remotePath,
  }) async {
    final downloadResult = await _webDav.downloadFile(remotePath);
    final encryptedData = EncryptedData.fromBytes(downloadResult.data);
    final plainData = await _encryption.decryptBytes(encryptedData);
    final json = jsonDecode(utf8.decode(plainData));

    if (json is! Map<String, dynamic>) {
      throw const SyncException('Remote sync payload is not a JSON object.');
    }

    final remoteItem = _deserializeItem(boxName, json);
    final existingItem = await _storage.getItemById<SyncableModel>(
      boxName,
      remoteItem.id,
    );

    if (existingItem == null) {
      await _storage.saveItem<SyncableModel>(boxName, remoteItem);
      return _MergeOutcome(item: remoteItem, shouldUploadWinner: false);
    }

    final winner = _conflictResolver.resolve(existingItem, remoteItem);
    await _storage.saveItem<SyncableModel>(boxName, winner);

    return _MergeOutcome(
      item: winner,
      shouldUploadWinner: identical(winner, existingItem),
    );
  }

  SyncableModel _deserializeItem(String boxName, Map<String, dynamic> json) {
    return switch (boxName) {
      StorageBoxNames.todos => TodoItem.fromJson(json),
      StorageBoxNames.clipboard => ClipboardItem.fromJson(json),
      StorageBoxNames.notes => NoteItem.fromJson(json),
      StorageBoxNames.pomodoro => PomodoroSession.fromJson(json),
      StorageBoxNames.memos => MemoItem.fromJson(json),
      _ => throw SyncException('Unsupported sync box "$boxName".'),
    };
  }

  Future<void> _ensureRemoteDirectory(String boxName) async {
    try {
      await _webDav.createDirectory(boxName);
    } catch (_) {
      // Directory creation is best-effort here. Some WebDAV servers return an
      // error when the directory already exists; list/upload operations will
      // surface real connectivity or permission failures afterwards.
    }
  }

  String _remotePathFor(String boxName, String itemId) => '$boxName/$itemId.enc';

  Future<_SyncMetadata> _loadMetadata() async {
    final stored = await _storage.getItemById<Map<dynamic, dynamic>>(
      StorageBoxNames.syncMeta,
      _SyncMetadata.storageId,
    );

    if (stored == null) {
      return _SyncMetadata.empty();
    }

    return _SyncMetadata.fromStorageMap(stored);
  }

  Future<void> _saveMetadata(_SyncMetadata metadata) async {
    await _storage.saveItem<Map<String, Object?>>(
      StorageBoxNames.syncMeta,
      metadata.toStorageMap(),
    );
  }
}

class ConflictResolver {
  const ConflictResolver();

  SyncableModel resolve(SyncableModel local, SyncableModel remote) {
    if (local.isDeleted != remote.isDeleted) {
      return local.isDeleted ? local : remote;
    }

    if (local.lamportClock != remote.lamportClock) {
      return local.lamportClock > remote.lamportClock ? local : remote;
    }

    return local.deviceId.compareTo(remote.deviceId) >= 0 ? local : remote;
  }
}

class SyncDependencies {
  const SyncDependencies({
    required this.storage,
    required this.webDav,
    required this.encryption,
  });

  final StorageService storage;
  final WebDavService webDav;
  final EncryptionService encryption;
}

class _MergeOutcome {
  const _MergeOutcome({
    required this.item,
    required this.shouldUploadWinner,
  });

  final SyncableModel item;
  final bool shouldUploadWinner;
}

class _SyncMetadata {
  _SyncMetadata({
    required this.boxClocks,
    required this.etags,
  });

  static const storageId = '00000000-0000-4000-8000-000000000001';

  final Map<String, int> boxClocks;
  final Map<String, String> etags;

  factory _SyncMetadata.empty() {
    return _SyncMetadata(
      boxClocks: <String, int>{},
      etags: <String, String>{},
    );
  }

  factory _SyncMetadata.fromStorageMap(Map<dynamic, dynamic> map) {
    final rawClocks = map['boxClocks'];
    final rawEtags = map['etags'];

    return _SyncMetadata(
      boxClocks: rawClocks is Map
          ? Map<String, int>.fromEntries(
              rawClocks.entries.map(
                (entry) => MapEntry(
                  entry.key.toString(),
                  entry.value is int ? entry.value as int : 0,
                ),
              ),
            )
          : <String, int>{},
      etags: rawEtags is Map
          ? Map<String, String>.fromEntries(
              rawEtags.entries.map(
                (entry) => MapEntry(entry.key.toString(), entry.value.toString()),
              ),
            )
          : <String, String>{},
    );
  }

  int clockFor(String boxName) => boxClocks[boxName] ?? -1;

  void recordClock(String boxName, int lamportClock) {
    final current = clockFor(boxName);
    if (lamportClock > current) {
      boxClocks[boxName] = lamportClock;
    }
  }

  String? etagFor(String remotePath) => etags[remotePath];

  void setEtag(String remotePath, String? etag) {
    if (etag == null || etag.isEmpty) {
      etags.remove(remotePath);
      return;
    }
    etags[remotePath] = etag;
  }

  Map<String, Object?> toStorageMap() => <String, Object?>{
        'id': storageId,
        'boxClocks': Map<String, int>.unmodifiable(boxClocks),
        'etags': Map<String, String>.unmodifiable(etags),
      };
}
