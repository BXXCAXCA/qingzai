import 'package:flutter_test/flutter_test.dart';
import 'package:qingzai/core/services/default_platform_service.dart';
import 'package:qingzai/core/services/platform_service.dart';

void main() {
  group('platform compatibility contract', () {
    test('maps every supported platform family to stable capabilities', () async {
      final cases = <String, _ExpectedCapabilities>{
        'android': const _ExpectedCapabilities(
          platform: QingZaiPlatform.android,
          clipboard: true,
          lan: true,
          inAppVersionFlow: false,
        ),
        'ios': const _ExpectedCapabilities(
          platform: QingZaiPlatform.ios,
          clipboard: false,
          lan: true,
          inAppVersionFlow: false,
        ),
        'windows': const _ExpectedCapabilities(
          platform: QingZaiPlatform.windows,
          clipboard: true,
          lan: true,
          inAppVersionFlow: true,
        ),
        'harmonyos-phone': const _ExpectedCapabilities(
          platform: QingZaiPlatform.harmonyPhone,
          clipboard: false,
          lan: true,
          inAppVersionFlow: true,
        ),
        'harmonyos-tablet': const _ExpectedCapabilities(
          platform: QingZaiPlatform.harmonyTablet,
          clipboard: false,
          lan: true,
          inAppVersionFlow: true,
        ),
        'harmonyos-watch': const _ExpectedCapabilities(
          platform: QingZaiPlatform.harmonyWatch,
          clipboard: false,
          lan: false,
          inAppVersionFlow: true,
        ),
      };

      for (final entry in cases.entries) {
        final service = DefaultPlatformService(
          deviceIdStore: _MemoryDeviceIdStore(),
          platformSnapshot: PlatformSnapshot(
            operatingSystem: entry.key,
            hostname: '',
          ),
        );

        expect(service.currentPlatform, entry.value.platform, reason: entry.key);
        expect(service.supportsClipboardWatch, entry.value.clipboard, reason: entry.key);
        expect(service.supportsLanTransfer, entry.value.lan, reason: entry.key);
        expect(
          service.supportsInAppVersionFlow,
          entry.value.inAppVersionFlow,
          reason: entry.key,
        );

        final firstId = await service.getDeviceId();
        final secondId = await service.getDeviceId();
        expect(firstId, secondId, reason: entry.key);
        expect(firstId, matches(RegExp(r'^[0-9a-f-]{36}$')), reason: entry.key);
      }
    });
  });
}

class _ExpectedCapabilities {
  const _ExpectedCapabilities({
    required this.platform,
    required this.clipboard,
    required this.lan,
    required this.inAppVersionFlow,
  });

  final QingZaiPlatform platform;
  final bool clipboard;
  final bool lan;
  final bool inAppVersionFlow;
}

class _MemoryDeviceIdStore implements DeviceIdStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
