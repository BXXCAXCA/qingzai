import '../models/syncable_model.dart';
import '../services/encryption_service.dart';
import '../services/storage_service.dart';
import '../services/webdav_service.dart';
import 'sync_result.dart';

abstract interface class SyncManager {
  Future<SyncResult> performSync({List<String> boxNames});

  SyncableModel resolveConflict(SyncableModel local, SyncableModel remote);
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
