abstract interface class PlatformService {
  Future<String> getDeviceId();

  Future<String> getDeviceName();

  QingZaiPlatform get currentPlatform;

  bool get supportsClipboardWatch;

  bool get supportsLanTransfer;

  bool get supportsInAppVersionFlow;
}

enum QingZaiPlatform {
  android,
  ios,
  windows,
  harmonyPhone,
  harmonyTablet,
  harmonyWatch,
  unknown,
}
