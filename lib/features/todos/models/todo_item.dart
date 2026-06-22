import 'package:hive/hive.dart';

import '../../../core/models/model_validation.dart';
import '../../../core/models/syncable_model.dart';

@HiveType(typeId: 0)
class TodoItem implements SyncableModel {
  TodoItem({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    required this.createdAt,
    this.dueDate,
    this.priority = 0,
    this.tags = const <String>[],
    required this.lastModified,
    required this.deviceId,
    this.lamportClock = 0,
    this.isDeleted = false,
  }) {
    validateUuid(id);
    validateNonEmptyString(title, 'title');
    validateDeviceId(deviceId);
    validatePriority(priority);
    validateNonNegativeClock(lamportClock);
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: parseRequiredString(json['id'], 'id'),
      title: parseRequiredString(json['title'], 'title'),
      description: parseOptionalString(json['description'], 'description'),
      isCompleted: parseBool(json['isCompleted'], 'isCompleted'),
      createdAt: parseRequiredDateTime(json['createdAt'], 'createdAt'),
      dueDate: parseOptionalDateTime(json['dueDate'], 'dueDate'),
      priority: parseInt(json['priority'], 'priority'),
      tags: parseStringList(json['tags'], fieldName: 'tags'),
      lastModified: parseRequiredDateTime(
        json['lastModified'],
        'lastModified',
      ),
      deviceId: parseRequiredString(json['deviceId'], 'deviceId'),
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
  final String? description;

  @HiveField(3)
  final bool isCompleted;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final DateTime? dueDate;

  @HiveField(6)
  final int priority;

  @HiveField(7)
  final List<String> tags;

  @HiveField(8)
  @override
  final DateTime lastModified;

  @HiveField(9)
  @override
  final String deviceId;

  @HiveField(10)
  @override
  final int lamportClock;

  @HiveField(11)
  @override
  final bool isDeleted;

  TodoItem copyWith({
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? dueDate,
    int? priority,
    List<String>? tags,
    DateTime? lastModified,
    int? lamportClock,
    bool? isDeleted,
  }) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      lastModified: lastModified ?? DateTime.now(),
      deviceId: deviceId,
      lamportClock: lamportClock ?? this.lamportClock + 1,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'description': description,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'priority': priority,
        'tags': tags,
        'lastModified': lastModified.toIso8601String(),
        'deviceId': deviceId,
        'lamportClock': lamportClock,
        'isDeleted': isDeleted,
      };
}
