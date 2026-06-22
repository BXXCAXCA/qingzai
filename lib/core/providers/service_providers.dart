import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/aes_gcm_encryption_service.dart';
import '../services/dio_webdav_service.dart';
import '../services/encryption_service.dart';
import '../services/hive_storage_service.dart';
import '../services/lan_transfer_service.dart';
import '../services/platform_service.dart';
import '../services/storage_service.dart';
import '../services/version_service.dart';
import '../services/webdav_service.dart';
import '../sync/sync_manager.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return HiveStorageService();
});

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return AesGcmEncryptionService();
});

final webDavServiceProvider = Provider<WebDavService>((ref) {
  return DioWebDavService();
});

final lanTransferServiceProvider = Provider<LanTransferService>((ref) {
  throw UnimplementedError('LanTransferService implementation is not registered.');
});

final versionServiceProvider = Provider<VersionService>((ref) {
  throw UnimplementedError('VersionService implementation is not registered.');
});

final platformServiceProvider = Provider<PlatformService>((ref) {
  throw UnimplementedError('PlatformService implementation is not registered.');
});

final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  return const ConflictResolver();
});

final syncDependenciesProvider = Provider<SyncDependencies>((ref) {
  return SyncDependencies(
    storage: ref.watch(storageServiceProvider),
    webDav: ref.watch(webDavServiceProvider),
    encryption: ref.watch(encryptionServiceProvider),
  );
});
