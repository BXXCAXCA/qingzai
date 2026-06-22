import 'package:hive/hive.dart';

import '../../../core/models/model_validation.dart';
import '../../../core/models/syncable_model.dart';

@HiveType(typeId: 2)
enum ClipboardType {
  @HiveField(0)
  text,

  @HiveField(1)
  image,

  @HiveField(2)
  file,
}

@HiveType(typeId: 1)
class ClipboardItem implements SyncableModel {
  ClipboardItem({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    required this.deviceId,
    this.isFavorite = false,
    this.thumbnail,
    this.lastModified,
    this.lamportClock = 0,
    this.isDeleted = false,
  }) : lastModified = lastModified ?? timestamp {
    validateUuid(id);
    validateNonEmptyString(content, 'content');
    validateDeviceId(deviceId);
    validateNonNegativeClock(lamportClock);
  }

  factory ClipboardItem.fromJson(Map<String, dynamic> json) {
    final timestamp = parseRequiredDateTime(json['timestamp'], 'timestamp');

    return ClipboardItem(
      id: parseRequiredString(json['id'], 'id'),
      type: ClipboardType.values.byName(
        parseRequiredString(json['type'], 'type'),
      ),
      content: parseRequiredString(json['content'], 'content'),
      timestamp: timestamp,
      deviceId: parseRequiredString(json['deviceId'], 'deviceId'),
      isFavorite: parseBool(json['isFavorite'], 'isFavorite'),
      thumbnail: parseOptionalString(json['thumbnail'], 'thumbnail'),
      lastModified: parseOptionalDateTime(
            json['lastModified'],
            'lastModified',
          ) ??
          timestamp,
      lamportClock: parseInt(json['lamportClock'], 'lamportClock'),
      isDeleted: parseBool(json['isDeleted'], 'isDeleted'),
    );
  }

  @HiveField(0)
  @override
  final String id;

  @HiveField(1)
  final ClipboardType type;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  @override
  final String deviceId;

  @HiveField(5)
  final bool isFavorite;

  @HiveField(6)
  final String? thumbnail;

  @HiveField(7)
  @override
  final DateTime lastModified;

  @HiveField(8)
  @override
  final int lamportClock;

  @HiveField(9)
  @override
  final bool isDeleted;

  ClipboardItem copyWith({
    ClipboardType? type,
    String? content,
    bool? isFavorite,
    String? thumbnail,
    DateTime? lastModified,
    int? lamportClock,
    bool? isDeleted,
  }) {
    return ClipboardItem(
      id: id,
      type: type ?? this.type,
      content: content ?? this.content,
      timestamp: timestamp,
      deviceId: deviceId,
      isFavorite: isFavorite ?? this.isFavorite,
      thumbnail: thumbnail ?? this.thumbnail,
      lastModified: lastModified ?? DateTime.now(),
      lamportClock: lamportClock ?? this.lamportClock + 1,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'deviceId': deviceId,
        'isFavorite': isFavorite,
        'thumbnail': thumbnail,
        'lastModified': lastModified.toIso8601String(),
        'lamportClock': lamportClock,
        'isDeleted': isDeleted,
      };
}
