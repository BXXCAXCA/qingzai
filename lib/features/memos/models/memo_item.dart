import 'package:hive/hive.dart';

import '../../../core/models/model_validation.dart';
import '../../../core/models/syncable_model.dart';

@HiveType(typeId: 6)
class MemoItem implements SyncableModel {
  MemoItem({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.lastModified,
    required this.deviceId,
    this.attachments = const <String>[],
    this.lamportClock = 0,
    this.isDeleted = false,
  }) {
    validateUuid(id);
    validateNonEmptyString(content, 'content');
    validateDeviceId(deviceId);
    validateNonNegativeClock(lamportClock);
  }

  factory MemoItem.fromJson(Map<String, dynamic> json) {
    return MemoItem(
      id: parseRequiredString(json['id'], 'id'),
      content: parseRequiredString(json['content'], 'content'),
      createdAt: parseRequiredDateTime(json['createdAt'], 'createdAt'),
      lastModified: parseRequiredDateTime(
        json['lastModified'],
        'lastModified',
      ),
      deviceId: parseRequiredString(json['deviceId'], 'deviceId'),
      attachments: parseStringList(
        json['attachments'],
        fieldName: 'attachments',
      ),
      lamportClock: parseInt(json['lamportClock'], 'lamportClock'),
      isDeleted: parseBool(json['isDeleted'], 'isDeleted'),
    );
  }

  @HiveField(0)
  @override
  final String id;

  @HiveField(1)
  final String content;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  @override
  final DateTime lastModified;

  @HiveField(4)
  @override
  final String deviceId;

  @HiveField(5)
  final List<String> attachments;

  @HiveField(6)
  @override
  final int lamportClock;

  @HiveField(7)
  @override
  final bool isDeleted;

  MemoItem copyWith({
    String? content,
    List<String>? attachments,
    DateTime? lastModified,
    int? lamportClock,
    bool? isDeleted,
  }) {
    return MemoItem(
      id: id,
      content: content ?? this.content,
      createdAt: createdAt,
      lastModified: lastModified ?? DateTime.now(),
      deviceId: deviceId,
      attachments: attachments ?? this.attachments,
      lamportClock: lamportClock ?? this.lamportClock + 1,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'lastModified': lastModified.toIso8601String(),
        'deviceId': deviceId,
        'attachments': attachments,
        'lamportClock': lamportClock,
        'isDeleted': isDeleted,
      };
}
