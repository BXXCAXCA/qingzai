import 'dart:io';

import 'package:path_provider/path_provider.dart';

class StorageHealth {
  const StorageHealth({
    required this.path,
    required this.usedBytes,
    required this.warningThresholdBytes,
  });

  final String path;
  final int usedBytes;
  final int warningThresholdBytes;

  bool get isAboveWarningThreshold => usedBytes >= warningThresholdBytes;
}

abstract interface class StorageSpaceService {
  Future<StorageHealth> checkAppStorage({int warningThresholdBytes});

  Future<int> calculateDirectorySize(Directory directory);
}

class AppStorageSpaceService implements StorageSpaceService {
  const AppStorageSpaceService();

  static const defaultWarningThresholdBytes = 500 * 1024 * 1024;

  @override
  Future<StorageHealth> checkAppStorage({
    int warningThresholdBytes = defaultWarningThresholdBytes,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final usedBytes = await calculateDirectorySize(directory);

    return StorageHealth(
      path: directory.path,
      usedBytes: usedBytes,
      warningThresholdBytes: warningThresholdBytes,
    );
  }

  @override
  Future<int> calculateDirectorySize(Directory directory) async {
    if (!await directory.exists()) {
      return 0;
    }

    var total = 0;
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }
}
