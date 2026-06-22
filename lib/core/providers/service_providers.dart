import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/aes_gcm_encryption_service.dart';
import '../services/encryption_service.dart';
import '../services/lan_transfer_service.dart';
import '../services/platform_service.dart';
import '../services/storage_service.dart';
import '../services/version_service.dart';
import '../services/webdav_service.dart';
import '../sync/sync_manager.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService implementation is not registered.');
});

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return AesGcmEncryptionService();
});

final webDavServiceProvider = Provider<WebDavService>((ref) {
  throw UnimplementedError('WebDavService implementation is not registered.');
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
