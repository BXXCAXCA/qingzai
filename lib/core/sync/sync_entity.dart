abstract interface class SyncEntity {
  String get id;

  String get deviceId;

  int get lamportClock;

  bool get isDeleted;

  DateTime get lastModified;

  Map<String, dynamic> toJson();
}

enum ConflictResolutionStrategy {
  deleteWins,
  lamportClockThenDeviceId,
}

T resolveSyncConflict<T extends SyncEntity>(T local, T remote) {
  if (local.isDeleted != remote.isDeleted) {
    return local.isDeleted ? local : remote;
  }

  if (local.lamportClock != remote.lamportClock) {
    return local.lamportClock > remote.lamportClock ? local : remote;
  }

  return local.deviceId.compareTo(remote.deviceId) >= 0 ? local : remote;
}
