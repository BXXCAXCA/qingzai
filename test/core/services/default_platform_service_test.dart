import 'package:flutter_test/flutter_test.dart';
import 'package:qingzai/core/services/default_platform_service.dart';
import 'package:qingzai/core/services/platform_service.dart';

void main() {
  group('DefaultPlatformService', () {
    test('persists and reuses generated device id', () async {
      final store = _MemoryDeviceIdStore();
      final service = DefaultPlatformService(
        deviceIdStore: store,
        platformSnapshot: const PlatformSnapshot(
          operatingSystem: 'android',
          hostname: 'phone',
        ),
      );

      final first = await service.getDeviceId();
      final second = await service.getDeviceId();

      expect(first, isNotEmpty);
      expect(second, first);
      expect(store.values, hasLength(1));
    });

    test('uses existing persisted device id', () async {
      final store = _MemoryDeviceIdStore({'qingzai.device_id': 'device-123'});
      final service = DefaultPlatformService(
        deviceIdStore: store,
        platformSnapshot: const PlatformSnapshot(
          operatingSystem: 'windows',
          hostname: 'pc',
        ),
      );

      expect(await service.getDeviceId(), 'device-123');
    });

    test('returns hostname as device name', () async {
      final service = DefaultPlatformService(
        deviceIdStore: _MemoryDeviceIdStore(),
        platformSnapshot: const PlatformSnapshot(
          operatingSystem: 'windows',
          hostname: 'QingZai-PC',
        ),
      );

      expect(await service.getDeviceName(), 'QingZai-PC');
    });

    test('falls back to platform device name when hostname is empty', () async {
      final service = DefaultPlatformService(
        deviceIdStore: _MemoryDeviceIdStore(),
        platformSnapshot: const PlatformSnapshot(
          operatingSystem: 'ios',
          hostname: ' ',
        ),
      );

      expect(await service.getDeviceName(), 'iOS Device');
    });

    test('maps known operating systems to QingZai platforms', () {
      expect(
        const PlatformSnapshot(operatingSystem: 'android', hostname: '').qingZaiPlatform,
        QingZaiPlatform.android,
      );
      expect(
        const PlatformSnapshot(operatingSystem: 'ios', hostname: '').qingZaiPlatform,
        QingZaiPlatform.ios,
      );
      expect(
        const PlatformSnapshot(operatingSystem: 'windows', hostname: '').qingZaiPlatform,
        QingZaiPlatform.windows,
      );
      expect(
        const PlatformSnapshot(operatingSystem: 'ohos', hostname: '').qingZaiPlatform,
        QingZaiPlatform.harmonyPhone,
      );
      expect(
        const PlatformSnapshot(operatingSystem: 'harmony-tablet', hostname: '').qingZaiPlatform,
        QingZaiPlatform.harmonyTablet,
      );
      expect(
        const PlatformSnapshot(operatingSystem: 'harmony-watch', hostname: '').qingZaiPlatform,
        QingZaiPlatform.harmonyWatch,
      );
      expect(
        const PlatformSnapshot(operatingSystem: 'linux', hostname: '').qingZaiPlatform,
        QingZaiPlatform.unknown,
      );
    });

    test('exposes platform capabilities', () {
      final windows = DefaultPlatformService(
        deviceIdStore: _MemoryDeviceIdStore(),
        platformSnapshot: const PlatformSnapshot(
          operatingSystem: 'windows',
          hostname: 'pc',
        ),
      );
      final ios = DefaultPlatformService(
        deviceIdStore: _MemoryDeviceIdStore(),
        platformSnapshot: const PlatformSnapshot(
          operatingSystem: 'ios',
          hostname: 'phone',
        ),
      );
      final watch = DefaultPlatformService(
        deviceIdStore: _MemoryDeviceIdStore(),
        platformSnapshot: const PlatformSnapshot(
          operatingSystem: 'harmony-watch',
          hostname: 'watch',
        ),
      );

      expect(windows.supportsClipboardWatch, isTrue);
      expect(windows.supportsLanTransfer, isTrue);
      expect(windows.supportsInAppVersionFlow, isTrue);

      expect(ios.supportsClipboardWatch, isFalse);
      expect(ios.supportsLanTransfer, isTrue);
      expect(ios.supportsInAppVersionFlow, isFalse);

      expect(watch.currentPlatform, QingZaiPlatform.harmonyWatch);
      expect(watch.supportsLanTransfer, isFalse);
      expect(watch.supportsInAppVersionFlow, isTrue);
    });
  });
}

class _MemoryDeviceIdStore implements DeviceIdStore {
  _MemoryDeviceIdStore([Map<String, String>? seed]) : values = {...?seed};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
