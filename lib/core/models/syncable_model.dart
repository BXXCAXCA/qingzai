abstract interface class SyncableModel {
  String get id;
  String get deviceId;
  int get lamportClock;
  bool get isDeleted;
  DateTime get lastModified;

  Map<String, dynamic> toJson();
}

mixin SyncableValidationMixin {
  void validateId(String id) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'ID must not be empty.');
    }
  }

  void validateDeviceId(String deviceId) {
    if (deviceId.trim().isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Device ID must not be empty.');
    }
  }

  void validateLamportClock(int lamportClock) {
    if (lamportClock < 0) {
      throw ArgumentError.value(
        lamportClock,
        'lamportClock',
        'Lamport clock must be non-negative.',
      );
    }
  }
}
