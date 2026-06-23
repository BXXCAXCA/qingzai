import 'dart:async';
import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qingzai/core/models/syncable_model.dart';
import 'package:qingzai/core/services/encryption_service.dart';
import 'package:qingzai/core/services/storage_service.dart';
import 'package:qingzai/core/services/webdav_service.dart';
import 'package:qingzai/core/sync/sync_manager.dart';
import 'package:qingzai/features/todos/models/todo_item.dart';

void main() {
  group('full sync flow integration', () {
    test('syncs local WebDAV remote changes across two devices', () async {
      final remote = _IntegrationWebDavService();
      final encryption = _PassthroughEncryptionService();
      final deviceAStorage = _IntegrationStorageService()
        ..put(StorageBoxNames.todos, _todo(id: _todoId, deviceId: 'device-a', clock: 1));
      final deviceBStorage = _IntegrationStorageService();

      final deviceAManager = DefaultSyncManager(
        storage: deviceAStorage,
        webDav: remote,
        encryption: encryption,
      );
      final deviceBManager = DefaultSyncManager(
        storage: deviceBStorage,
        webDav: remote,
        encryption: encryption,
      );

      final uploadResult = await deviceAManager.performSync(
        boxNames: const [StorageBoxNames.todos],
      );

      expect(uploadResult.isSuccess, isTrue);
      expect(uploadResult.uploaded, 1);
      expect(remote.files.keys, contains('todos/$_todoId.enc'));

      final downloadResult = await deviceBManager.performSync(
        boxNames: const [StorageBoxNames.todos],
      );

      expect(downloadResult.isSuccess, isTrue);
      expect(downloadResult.downloaded, 1);

      final replicated = await deviceBStorage.getItemById<TodoItem>(
        StorageBoxNames.todos,
        _todoId,
      );
      expect(replicated, isNotNull);
      expect(replicated!.title, 'Replicate me');
      expect(replicated.deviceId, 'device-a');

      final editedOnB = replicated.copyWith(
        title: 'Edited on B',
        lamportClock: 2,
        lastModified: DateTime.utc(2026, 1, 2),
      );
      await deviceBStorage.saveItem(StorageBoxNames.todos, editedOnB);

      final secondUpload = await deviceBManager.performSync(
        boxNames: const [StorageBoxNames.todos],
      );
      expect(secondUpload.uploaded, 1);

      final pullBackToA = await deviceAManager.performSync(
        boxNames: const [StorageBoxNames.todos],
      );
      expect(pullBackToA.isSuccess, isTrue);

      final finalOnA = await deviceAStorage.getItemById<TodoItem>(
        StorageBoxNames.todos,
        _todoId,
      );
      expect(finalOnA!.title, 'Edited on B');
      expect(finalOnA.lamportClock, 2);
    });
  });
}

const _todoId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

TodoItem _todo({
  required String id,
  required String deviceId,
  required int clock,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return TodoItem(
    id: id,
    title: 'Replicate me',
    createdAt: now,
    lastModified: now,
    deviceId: deviceId,
    lamportClock: clock,
  );
}

class _IntegrationStorageService implements StorageService {
  final _boxes = <String, Map<String, Object?>>{
    for (final boxName in StorageBoxNames.allBoxes) boxName: <String, Object?>{},
  };

  void put(String boxName, SyncableModel item) {
    _boxes[boxName]![item.id] = item;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> saveItem<T>(String boxName, T item) async {
    if (item is SyncableModel) {
      _boxes[boxName]![item.id] = item;
      return true;
    }
    if (item is Map<String, Object?>) {
      _boxes[boxName]![item['id']! as String] = item;
      return true;
    }
    throw StateError('Unsupported in-memory item: ${item.runtimeType}');
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
      await saveItem<T>(boxName, item);
    }
    return items.length;
  }

  @override
  Future<void> clearBox(String boxName) async {
    _boxes[boxName]!.clear();
  }

  @override
  Future<int> getItemCount(String boxName) async => _boxes[boxName]!.length;

  @override
  Stream<BoxEvent> watchBox(String boxName) => const Stream<BoxEvent>.empty();
}

class _IntegrationWebDavService implements WebDavService {
  final files = <String, _RemoteFile>{};
  var _uploadCounter = 0;

  @override
  Future<bool> connect(WebDavConfig config) async => true;

  @override
  Future<UploadResult> uploadFile({
    required String remotePath,
    required List<int> data,
    String? etag,
  }) async {
    final current = files[remotePath];
    if (etag != null && current != null && current.etag != etag) {
      return const UploadResult(success: false, errorMessage: 'ETag mismatch');
    }

    final nextEtag = 'etag-${++_uploadCounter}';
    files[remotePath] = _RemoteFile(path: remotePath, etag: nextEtag, data: data);
    return UploadResult(success: true, etag: nextEtag);
  }

  @override
  Future<DownloadResult> downloadFile(String remotePath) async {
    final file = files[remotePath]!;
    return DownloadResult(data: file.data, metadata: file.metadata);
  }

  @override
  Future<List<FileMetadata>> listDirectory(String remotePath) async {
    final prefix = remotePath.endsWith('/') ? remotePath : '$remotePath/';
    return files.values
        .where((file) => file.path.startsWith(prefix))
        .map((file) => file.metadata)
        .toList(growable: false);
  }

  @override
  Future<bool> deleteFile(String remotePath) async => files.remove(remotePath) != null;

  @override
  Future<bool> fileExists(String remotePath) async => files.containsKey(remotePath);

  @override
  Future<FileMetadata?> getFileMetadata(String remotePath) async => files[remotePath]?.metadata;

  @override
  Future<bool> createDirectory(String remotePath) async => true;
}

class _RemoteFile {
  const _RemoteFile({
    required this.path,
    required this.etag,
    required this.data,
  });

  final String path;
  final String etag;
  final List<int> data;

  FileMetadata get metadata => FileMetadata(
        path: path,
        etag: etag,
        lastModified: DateTime.utc(2026, 1, 1),
        size: data.length,
        isDirectory: false,
      );
}

class _PassthroughEncryptionService implements EncryptionService {
  EncryptedData encryptSynchronously(List<int> plainData) {
    return EncryptedData(
      ciphertext: List<int>.from(plainData),
      iv: const [1],
      authTag: const [2],
    );
  }

  @override
  Future<void> initialize(String secret) async {}

  @override
  Future<EncryptedData> encryptBytes(List<int> plainData) async {
    return encryptSynchronously(gzip.encode(plainData));
  }

  @override
  Future<List<int>> decryptBytes(EncryptedData encryptedData) async {
    final data = encryptedData.ciphertext;
    try {
      return gzip.decode(data);
    } on FormatException {
      return data;
    }
  }

  @override
  Future<String> encryptText(String plainText) async => plainText;

  @override
  Future<String> decryptText(String encryptedText) async => encryptedText;

  @override
  List<int> generateRandomBytes(int length) => List<int>.filled(length, 1);

  @override
  String calculateSha256(List<int> data) => 'sha256:${data.length}';
}
