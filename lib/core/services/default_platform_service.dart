import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'platform_service.dart';

class DefaultPlatformService implements PlatformService {
  DefaultPlatformService({
    DeviceIdStore? deviceIdStore,
    PlatformSnapshot? platformSnapshot,
    Uuid? uuid,
  })  : _deviceIdStore = deviceIdStore ?? const SecureDeviceIdStore(),
        _platformSnapshot = platformSnapshot ?? PlatformSnapshot.current(),
        _uuid = uuid ?? const Uuid();

  static const _deviceIdKey = 'qingzai.device_id';

  final DeviceIdStore _deviceIdStore;
  final PlatformSnapshot _platformSnapshot;
  final Uuid _uuid;

  @override
  QingZaiPlatform get currentPlatform => _platformSnapshot.qingZaiPlatform;

  @override
  bool get supportsClipboardWatch {
    return switch (currentPlatform) {
      QingZaiPlatform.android || QingZaiPlatform.windows => true,
      QingZaiPlatform.ios ||
      QingZaiPlatform.harmonyPhone ||
      QingZaiPlatform.harmonyTablet ||
      QingZaiPlatform.harmonyWatch ||
      QingZaiPlatform.unknown => false,
    };
  }

  @override
  bool get supportsLanTransfer {
    return switch (currentPlatform) {
      QingZaiPlatform.android ||
      QingZaiPlatform.ios ||
      QingZaiPlatform.windows ||
      QingZaiPlatform.harmonyPhone ||
      QingZaiPlatform.harmonyTablet => true,
      QingZaiPlatform.harmonyWatch || QingZaiPlatform.unknown => false,
    };
  }

  @override
  bool get supportsInAppVersionFlow {
    return switch (currentPlatform) {
      QingZaiPlatform.windows || QingZaiPlatform.harmonyPhone ||
      QingZaiPlatform.harmonyTablet || QingZaiPlatform.harmonyWatch => true,
      QingZaiPlatform.android || QingZaiPlatform.ios || QingZaiPlatform.unknown => false,
    };
  }

  @override
  Future<String> getDeviceId() async {
    final existing = await _deviceIdStore.read(_deviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }

    final generated = _uuid.v4();
    await _deviceIdStore.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  @override
  Future<String> getDeviceName() async {
    final hostname = _platformSnapshot.hostname.trim();
    if (hostname.isNotEmpty) {
      return hostname;
    }

    return switch (currentPlatform) {
      QingZaiPlatform.android => 'Android Device',
      QingZaiPlatform.ios => 'iOS Device',
      QingZaiPlatform.windows => 'Windows Device',
      QingZaiPlatform.harmonyPhone => 'HarmonyOS Phone',
      QingZaiPlatform.harmonyTablet => 'HarmonyOS Tablet',
      QingZaiPlatform.harmonyWatch => 'HarmonyOS Watch',
      QingZaiPlatform.unknown => 'Unknown Device',
    };
  }
}

abstract interface class DeviceIdStore {
  Future<String?> read(String key);

  Future<void> write({required String key, required String value});
}

class SecureDeviceIdStore implements DeviceIdStore {
  const SecureDeviceIdStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }
}

class PlatformSnapshot {
  const PlatformSnapshot({
    required this.operatingSystem,
    required this.hostname,
  });

  factory PlatformSnapshot.current() {
    return PlatformSnapshot(
      operatingSystem: Platform.operatingSystem,
      hostname: Platform.localHostname,
    );
  }

  final String operatingSystem;
  final String hostname;

  QingZaiPlatform get qingZaiPlatform {
    final normalized = operatingSystem.toLowerCase();
    return switch (normalized) {
      'android' => QingZaiPlatform.android,
      'ios' => QingZaiPlatform.ios,
      'windows' => QingZaiPlatform.windows,
      'ohos' || 'harmonyos' || 'harmony' => QingZaiPlatform.harmonyPhone,
      _ => QingZaiPlatform.unknown,
    };
  }
}
