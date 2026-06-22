enum QingZaiPlatform {
  android,
  ios,
  windows,
  harmonyPhone,
  harmonyTablet,
  harmonyWatch,
  unknown,
}

abstract interface class PlatformService {
  QingZaiPlatform get currentPlatform;

  Future<String> getDeviceId();

  bool get supportsLocalClipboard;

  bool get supportsLanTransfer;

  bool get supportsInAppPatchUpdate;
}
