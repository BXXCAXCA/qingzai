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
  group('ConflictResolver', () {
    const resolver = ConflictResolver();

    test('uses delete-wins when only one side is tombstoned', () {
      final active = _todo(id: _id1, deviceId: 'device-a', clock: 2);
      final deleted = _todo(
        id: _id1,
        deviceId: 'device-b',
        clock: 1,
        isDeleted: true,
      );

      expect(resolver.resolve(active, deleted), same(deleted));
      expect(resolver.resolve(deleted, active), same(deleted));
    });

    test('uses the highest Lamport clock when neither side is deleted', () {
      final local = _todo(id: _id1, deviceId: 'device-a', clock: 2);
      final remote = _todo(id: _id1, deviceId: 'device-b', clock: 3);

      expect(resolver.resolve(local, remote), same(remote));
    });

    test('uses deviceId as a stable tie-breaker when clocks match', () {
      final local = _todo(id: _id1, deviceId: 'device-a', clock: 3);
      final remote = _todo(id: _id1, deviceId: 'device-z', clock: 3);

      expect(resolver.resolve(local, remote), same(remote));
    });
  });

  group('DefaultSyncManager', () {
    test('uploads local changes as compressed encrypted JSON files and records ETags', () async {
      final storage = _MemoryStorageService()
        ..put(StorageBoxNames.todos, _todo(id: _id1, clock: 1));
      final webDav = _MemoryWebDavService();
      final manager = DefaultSyncManager(
        storage: storage,
        webDav: webDav,
        encryption: _PassthroughEncryptionService(),
      );

      final result = await manager.performSync(boxNames: const [StorageBoxNames.todos]);

      expect(result.isSuccess, isTrue);
      expect(result.uploaded, 1);
      expect(result.downloaded, 0);
      expect(webDav.uploads, hasLength(1));
      expect(webDav.uploads.single.remotePath, 'todos/$_id1.enc');

      final uploadedPayload = EncryptedData.fromBytes(webDav.uploads.single.data);
      final uploadedJson = jsonDecode(
        utf8.decode(gzip.decode(uploadedPayload.ciphertext)),
      );
      expect(uploadedJson['id'], _id1);
      expect(uploadedJson['lamportClock'], 1);

      final metadata = storage.box(StorageBoxNames.syncMeta).values.single as Map<dynamic, dynamic>;
      expect(metadata['boxClocks'][StorageBoxNames.todos], 1);
      expect(metadata['etags']['todos/$_id1.enc'], 'etag-1');
    });

    test('downloads compressed remote changes, decrypts them, and saves new items locally', () async {
      final storage = _MemoryStorageService();
      final encryption = _PassthroughEncryptionService();
      final remoteTodo = _todo(id: _id2, deviceId: 'remote-device', clock: 5);
      final webDav = _MemoryWebDavService()
        ..addRemoteFile(
          path: 'todos/$_id2.enc',
          etag: 'remote-etag',
          data: _encryptedJsonBytes(encryption, remoteTodo.toJson()),
        );
      final manager = DefaultSyncManager(
        storage: storage,
        webDav: webDav,
        encryption: encryption,
      );

      final result = await manager.performSync(boxNames: const [StorageBoxNames.todos]);

      expect(result.isSuccess, isTrue);
      expect(result.uploaded, 0);
      expect(result.downloaded, 1);

      final saved = await storage.getItemById<TodoItem>(StorageBoxNames.todos, _id2);
      expect(saved, isNotNull);
      expect(saved!.deviceId, 'remote-device');
      expect(saved.lamportClock, 5);
    });

    test('still accepts legacy uncompressed remote sync payloads', () async {
      final storage = _MemoryStorageService();
      final encryption = _PassthroughEncryptionService();
      final remoteTodo = _todo(id: _id2, deviceId: 'legacy-device', clock: 4);
      final webDav = _MemoryWebDavService()
        ..addRemoteFile(
          path: 'todos/$_id2.enc',
          etag: 'legacy-etag',
          data: _legacyEncryptedJsonBytes(encryption, remoteTodo.toJson()),
        );
      final manager = DefaultSyncManager(
        storage: storage,
        webDav: webDav,
        encryption: encryption,
      );

      final result = await manager.performSync(boxNames: const [StorageBoxNames.todos]);

      expect(result.isSuccess, isTrue);
      final saved = await storage.getItemById<TodoItem>(StorageBoxNames.todos, _id2);
      expect(saved!.deviceId, 'legacy-device');
    });

    test('keeps deterministic local winner when remote item has lower clock', () async {
      final local = _todo(id: _id1, deviceId: 'local-device', clock: 10);
      final remote = _todo(id: _id1, deviceId: 'remote-device', clock: 3);
      final storage = _MemoryStorageService()..put(StorageBoxNames.todos, local);
      final encryption = _PassthroughEncryptionService();
      final webDav = _MemoryWebDavService()
        ..addRemoteFile(
          path: 'todos/$_id1.enc',
          etag: 'remote-etag',
          data: _encryptedJsonBytes(encryption, remote.toJson()),
        );
      final manager = DefaultSyncManager(
        storage: storage,
        webDav: webDav,
        encryption: encryption,
      );

      final result = await manager.performSync(boxNames: const [StorageBoxNames.todos]);

      expect(result.isSuccess, isTrue);
      final saved = await storage.getItemById<TodoItem>(StorageBoxNames.todos, _id1);
      expect(saved, same(local));
    });

    test('aggregates per-box errors instead of throwing the whole sync', () async {
      final storage = _MemoryStorageService();
      final webDav = _MemoryWebDavService()..failListDirectory = true;
      final manager = DefaultSyncManager(
        storage: storage,
        webDav: webDav,
        encryption: _PassthroughEncryptionService(),
      );

      final result = await manager.performSync(boxNames: const [StorageBoxNames.todos]);

      expect(result.hasErrors, isTrue);
      expect(result.errors.single, contains('Error syncing todos'));
    });
  });
}

const _id1 = '11111111-1111-4111-8111-111111111111';
const _id2 = '22222222-2222-4222-8222-222222222222';

TodoItem _todo({
  required String id,
  String deviceId = 'device-a',
  int clock = 0,
  bool isDeleted = false,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return TodoItem(
    id: id,
    title: 'Sync me',
    createdAt: now,
    lastModified: now,
    deviceId: deviceId,
    lamportClock: clock,
    isDeleted: isDeleted,
  );
}

List<int> _encryptedJsonBytes(
  _PassthroughEncryptionService encryption,
  Map<String, dynamic> json,
) {
  final compressedJson = gzip.encode(utf8.encode(jsonEncode(json)));
  final encrypted = encryption.encryptSynchronously(compressedJson);
  return encrypted.toBytes();
}

List<int> _legacyEncryptedJsonBytes(
  _PassthroughEncryptionService encryption,
  Map<String, dynamic> json,
) {
  final encrypted = encryption.encryptSynchronously(utf8.encode(jsonEncode(json)));
  return encrypted.toBytes();
}

class _MemoryStorageService implements StorageService {
  final Map<String, Map<String, Object?>> _boxes = <String, Map<String, Object?>>{
    for (final boxName in StorageBoxNames.allBoxes) boxName: <String, Object?>{},
  };

  Map<String, Object?> box(String boxName) => _boxes[boxName]!;

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
    final value = _boxes[boxName]![id];
    return value == null ? null : value as T;
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

class _MemoryWebDavService implements WebDavService {
  final Map<String, _RemoteFile> files = <String, _RemoteFile>{};
  final List<_UploadCall> uploads = <_UploadCall>[];
  var _uploadCounter = 0;
  bool failListDirectory = false;

  void addRemoteFile({
    required String path,
    required String etag,
    required List<int> data,
  }) {
    files[path] = _RemoteFile(path: path, etag: etag, data: data);
  }

  @override
  Future<bool> connect(WebDavConfig config) async => true;

  @override
  Future<UploadResult> uploadFile({
    required String remotePath,
    required List<int> data,
    String? etag,
  }) async {
    uploads.add(_UploadCall(remotePath: remotePath, data: data, etag: etag));
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
    if (failListDirectory) {
      throw StateError('listing failed');
    }

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

class _UploadCall {
  const _UploadCall({
    required this.remotePath,
    required this.data,
    required this.etag,
  });

  final String remotePath;
  final List<int> data;
  final String? etag;
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
      iv: const <int>[1],
      authTag: const <int>[2],
    );
  }

  @override
  Future<void> initialize(String secret) async {}

  @override
  Future<EncryptedData> encryptBytes(List<int> plainData) async {
    return encryptSynchronously(plainData);
  }

  @override
  Future<List<int>> decryptBytes(EncryptedData encryptedData) async {
    return encryptedData.ciphertext;
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
