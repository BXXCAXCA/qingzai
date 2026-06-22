import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/aes_gcm_encryption_service.dart';
import '../services/dio_version_service.dart';
import '../services/dio_webdav_service.dart';
import '../services/encryption_service.dart';
import '../services/hive_storage_service.dart';
import '../services/lan_transfer_service.dart';
import '../services/platform_service.dart';
import '../services/socket_lan_transfer_service.dart';
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
  final service = SocketLanTransferService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

final versionServiceProvider = Provider<VersionService>((ref) {
  return DioVersionService();
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

final syncManagerProvider = Provider<SyncManager>((ref) {
  final dependencies = ref.watch(syncDependenciesProvider);

  return DefaultSyncManager(
    storage: dependencies.storage,
    webDav: dependencies.webDav,
    encryption: dependencies.encryption,
    conflictResolver: ref.watch(conflictResolverProvider),
  );
});