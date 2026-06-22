import 'package:hive/hive.dart';

import '../../../core/models/model_validation.dart';
import '../../../core/models/syncable_model.dart';

@HiveType(typeId: 3)
class NoteItem implements SyncableModel {
  NoteItem({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.lastModified,
    this.tags = const <String>[],
    this.isPinned = false,
    required this.deviceId,
    this.color,
    this.lamportClock = 0,
    this.isDeleted = false,
  }) {
    validateUuid(id);
    validateNonEmptyString(title, 'title');
    validateDeviceId(deviceId);
    validateNonNegativeClock(lamportClock);
  }

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      id: parseRequiredString(json['id'], 'id'),
      title: parseRequiredString(json['title'], 'title'),
      content: parseRequiredString(json['content'], 'content'),
      createdAt: parseRequiredDateTime(json['createdAt'], 'createdAt'),
      lastModified: parseRequiredDateTime(
        json['lastModified'],
        'lastModified',
      ),
      tags: parseStringList(json['tags'], fieldName: 'tags'),
      isPinned: parseBool(json['isPinned'], 'isPinned'),
      deviceId: parseRequiredString(json['deviceId'], 'deviceId'),
      color: parseOptionalString(json['color'], 'color'),
      lamportClock: parseInt(json['lamportClock'], 'lamportClock'),
      isDeleted: parseBool(json['isDeleted'], 'isDeleted'),
    );
  }

  @HiveField(0)
  @override
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  @override
  final DateTime lastModified;

  @HiveField(5)
  final List<String> tags;

  @HiveField(6)
  final bool isPinned;

  @HiveField(7)
  @override
  final String deviceId;

  @HiveField(8)
  final String? color;

  @HiveField(9)
  @override
  final int lamportClock;

  @HiveField(10)
  @override
  final bool isDeleted;

  NoteItem copyWith({
    String? title,
    String? content,
    List<String>? tags,
    bool? isPinned,
    String? color,
    DateTime? lastModified,
    int? lamportClock,
    bool? isDeleted,
  }) {
    return NoteItem(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      lastModified: lastModified ?? DateTime.now(),
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      deviceId: deviceId,
      color: color ?? this.color,
      lamportClock: lamportClock ?? this.lamportClock + 1,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'lastModified': lastModified.toIso8601String(),
        'tags': tags,
        'isPinned': isPinned,
        'deviceId': deviceId,
        'color': color,
        'lamportClock': lamportClock,
        'isDeleted': isDeleted,
      };
}
