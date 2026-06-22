import 'package:hive/hive.dart';

import '../../../core/models/model_validation.dart';
import '../../../core/models/syncable_model.dart';

@HiveType(typeId: 5)
enum PomodoroType {
  @HiveField(0)
  work,

  @HiveField(1)
  shortBreak,

  @HiveField(2)
  longBreak,
}

@HiveType(typeId: 4)
class PomodoroSession implements SyncableModel {
  PomodoroSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.duration,
    required this.type,
    this.isCompleted = false,
    this.taskId,
    required this.deviceId,
    this.lastModified,
    this.lamportClock = 0,
    this.isDeleted = false,
  }) : lastModified = lastModified ?? endTime ?? startTime {
    validateUuid(id);
    validateDuration(duration);
    validateDeviceId(deviceId);
    validateNonNegativeClock(lamportClock);
  }

  factory PomodoroSession.fromJson(Map<String, dynamic> json) {
    final startTime = parseRequiredDateTime(json['startTime'], 'startTime');

    return PomodoroSession(
      id: parseRequiredString(json['id'], 'id'),
      startTime: startTime,
      endTime: parseOptionalDateTime(json['endTime'], 'endTime'),
      duration: parseInt(json['duration'], 'duration'),
      type: PomodoroType.values.byName(
        parseRequiredString(json['type'], 'type'),
      ),
      isCompleted: parseBool(json['isCompleted'], 'isCompleted'),
      taskId: parseOptionalString(json['taskId'], 'taskId'),
      deviceId: parseRequiredString(json['deviceId'], 'deviceId'),
      lastModified: parseOptionalDateTime(
            json['lastModified'],
            'lastModified',
          ) ??
          startTime,
      lamportClock: parseInt(json['lamportClock'], 'lamportClock'),
      isDeleted: parseBool(json['isDeleted'], 'isDeleted'),
    );
  }

  @HiveField(0)
  @override
  final String id;

  @HiveField(1)
  final DateTime startTime;

  @HiveField(2)
  final DateTime? endTime;

  @HiveField(3)
  final int duration;

  @HiveField(4)
  final PomodoroType type;

  @HiveField(5)
  final bool isCompleted;

  @HiveField(6)
  final String? taskId;

  @HiveField(7)
  @override
  final String deviceId;

  @HiveField(8)
  @override
  final DateTime lastModified;

  @HiveField(9)
  @override
  final int lamportClock;

  @HiveField(10)
  @override
  final bool isDeleted;

  PomodoroSession copyWith({
    DateTime? endTime,
    int? duration,
    PomodoroType? type,
    bool? isCompleted,
    String? taskId,
    DateTime? lastModified,
    int? lamportClock,
    bool? isDeleted,
  }) {
    return PomodoroSession(
      id: id,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      type: type ?? this.type,
      isCompleted: isCompleted ?? this.isCompleted,
      taskId: taskId ?? this.taskId,
      deviceId: deviceId,
      lastModified: lastModified ?? DateTime.now(),
      lamportClock: lamportClock ?? this.lamportClock + 1,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'duration': duration,
        'type': type.name,
        'isCompleted': isCompleted,
        'taskId': taskId,
        'deviceId': deviceId,
        'lastModified': lastModified.toIso8601String(),
        'lamportClock': lamportClock,
        'isDeleted': isDeleted,
      };
}

void validateDuration(int duration) {
  if (duration <= 0) {
    throw ArgumentError.value(
      duration,
      'duration',
      'Duration must be greater than zero seconds.',
    );
  }
}
