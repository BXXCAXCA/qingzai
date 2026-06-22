import 'syncable_model.dart';

class Tombstone implements SyncableModel {
  const Tombstone({
    required this.id,
    required this.deviceId,
    required this.lamportClock,
    required this.lastModified,
    required this.deletedAt,
    required this.modelType,
  });

  factory Tombstone.fromJson(Map<String, dynamic> json) {
    return Tombstone(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      lamportClock: json['lamportClock'] as int,
      lastModified: DateTime.parse(json['lastModified'] as String),
      deletedAt: DateTime.parse(json['deletedAt'] as String),
      modelType: json['modelType'] as String,
    );
  }

  @override
  final String id;

  @override
  final String deviceId;

  @override
  final int lamportClock;

  @override
  final DateTime lastModified;

  final DateTime deletedAt;
  final String modelType;

  @override
  bool get isDeleted => true;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceId': deviceId,
        'lamportClock': lamportClock,
        'lastModified': lastModified.toIso8601String(),
        'deletedAt': deletedAt.toIso8601String(),
        'modelType': modelType,
        'isDeleted': isDeleted,
      };
}
