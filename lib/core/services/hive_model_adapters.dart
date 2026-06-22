import 'package:hive/hive.dart';

import '../../features/clipboard/models/clipboard_item.dart';
import '../../features/memos/models/memo_item.dart';
import '../../features/notes/models/note_item.dart';
import '../../features/pomodoro/models/pomodoro_session.dart';
import '../../features/todos/models/todo_item.dart';
import '../models/tombstone.dart';

void registerQingZaiHiveAdapters() {
  _registerAdapter(TodoItemAdapter());
  _registerAdapter(ClipboardItemAdapter());
  _registerAdapter(ClipboardTypeAdapter());
  _registerAdapter(NoteItemAdapter());
  _registerAdapter(PomodoroSessionAdapter());
  _registerAdapter(PomodoroTypeAdapter());
  _registerAdapter(MemoItemAdapter());
  _registerAdapter(TombstoneAdapter());
}

void _registerAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter<T>(adapter);
  }
}

class TodoItemAdapter extends TypeAdapter<TodoItem> {
  @override
  final int typeId = 0;

  @override
  TodoItem read(BinaryReader reader) {
    final fields = _readFields(reader);
    return TodoItem(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      isCompleted: (fields[3] as bool?) ?? false,
      createdAt: fields[4] as DateTime,
      dueDate: fields[5] as DateTime?,
      priority: (fields[6] as int?) ?? 0,
      tags: _stringList(fields[7]),
      lastModified: fields[8] as DateTime,
      deviceId: fields[9] as String,
      lamportClock: (fields[10] as int?) ?? 0,
      isDeleted: (fields[11] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, TodoItem obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.isCompleted)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.dueDate)
      ..writeByte(6)
      ..write(obj.priority)
      ..writeByte(7)
      ..write(obj.tags)
      ..writeByte(8)
      ..write(obj.lastModified)
      ..writeByte(9)
      ..write(obj.deviceId)
      ..writeByte(10)
      ..write(obj.lamportClock)
      ..writeByte(11)
      ..write(obj.isDeleted);
  }
}

class ClipboardItemAdapter extends TypeAdapter<ClipboardItem> {
  @override
  final int typeId = 1;

  @override
  ClipboardItem read(BinaryReader reader) {
    final fields = _readFields(reader);
    return ClipboardItem(
      id: fields[0] as String,
      type: fields[1] as ClipboardType,
      content: fields[2] as String,
      timestamp: fields[3] as DateTime,
      deviceId: fields[4] as String,
      isFavorite: (fields[5] as bool?) ?? false,
      thumbnail: fields[6] as String?,
      lastModified: fields[7] as DateTime?,
      lamportClock: (fields[8] as int?) ?? 0,
      isDeleted: (fields[9] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ClipboardItem obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.deviceId)
      ..writeByte(5)
      ..write(obj.isFavorite)
      ..writeByte(6)
      ..write(obj.thumbnail)
      ..writeByte(7)
      ..write(obj.lastModified)
      ..writeByte(8)
      ..write(obj.lamportClock)
      ..writeByte(9)
      ..write(obj.isDeleted);
  }
}

class ClipboardTypeAdapter extends TypeAdapter<ClipboardType> {
  @override
  final int typeId = 2;

  @override
  ClipboardType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ClipboardType.text;
      case 1:
        return ClipboardType.image;
      case 2:
        return ClipboardType.file;
      default:
        return ClipboardType.text;
    }
  }

  @override
  void write(BinaryWriter writer, ClipboardType obj) {
    writer.writeByte(obj.index);
  }
}

class NoteItemAdapter extends TypeAdapter<NoteItem> {
  @override
  final int typeId = 3;

  @override
  NoteItem read(BinaryReader reader) {
    final fields = _readFields(reader);
    return NoteItem(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
      createdAt: fields[3] as DateTime,
      lastModified: fields[4] as DateTime,
      tags: _stringList(fields[5]),
      isPinned: (fields[6] as bool?) ?? false,
      deviceId: fields[7] as String,
      color: fields[8] as String?,
      lamportClock: (fields[9] as int?) ?? 0,
      isDeleted: (fields[10] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, NoteItem obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.lastModified)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.isPinned)
      ..writeByte(7)
      ..write(obj.deviceId)
      ..writeByte(8)
      ..write(obj.color)
      ..writeByte(9)
      ..write(obj.lamportClock)
      ..writeByte(10)
      ..write(obj.isDeleted);
  }
}

class PomodoroSessionAdapter extends TypeAdapter<PomodoroSession> {
  @override
  final int typeId = 4;

  @override
  PomodoroSession read(BinaryReader reader) {
    final fields = _readFields(reader);
    return PomodoroSession(
      id: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime?,
      duration: fields[3] as int,
      type: fields[4] as PomodoroType,
      isCompleted: (fields[5] as bool?) ?? false,
      taskId: fields[6] as String?,
      deviceId: fields[7] as String,
      lastModified: fields[8] as DateTime?,
      lamportClock: (fields[9] as int?) ?? 0,
      isDeleted: (fields[10] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, PomodoroSession obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.duration)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.taskId)
      ..writeByte(7)
      ..write(obj.deviceId)
      ..writeByte(8)
      ..write(obj.lastModified)
      ..writeByte(9)
      ..write(obj.lamportClock)
      ..writeByte(10)
      ..write(obj.isDeleted);
  }
}

class PomodoroTypeAdapter extends TypeAdapter<PomodoroType> {
  @override
  final int typeId = 5;

  @override
  PomodoroType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PomodoroType.work;
      case 1:
        return PomodoroType.shortBreak;
      case 2:
        return PomodoroType.longBreak;
      default:
        return PomodoroType.work;
    }
  }

  @override
  void write(BinaryWriter writer, PomodoroType obj) {
    writer.writeByte(obj.index);
  }
}

class MemoItemAdapter extends TypeAdapter<MemoItem> {
  @override
  final int typeId = 6;

  @override
  MemoItem read(BinaryReader reader) {
    final fields = _readFields(reader);
    return MemoItem(
      id: fields[0] as String,
      content: fields[1] as String,
      createdAt: fields[2] as DateTime,
      lastModified: fields[3] as DateTime,
      deviceId: fields[4] as String,
      attachments: _stringList(fields[5]),
      lamportClock: (fields[6] as int?) ?? 0,
      isDeleted: (fields[7] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, MemoItem obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.lastModified)
      ..writeByte(4)
      ..write(obj.deviceId)
      ..writeByte(5)
      ..write(obj.attachments)
      ..writeByte(6)
      ..write(obj.lamportClock)
      ..writeByte(7)
      ..write(obj.isDeleted);
  }
}

class TombstoneAdapter extends TypeAdapter<Tombstone> {
  @override
  final int typeId = 50;

  @override
  Tombstone read(BinaryReader reader) {
    final fields = _readFields(reader);
    return Tombstone(
      id: fields[0] as String,
      deviceId: fields[1] as String,
      lamportClock: fields[2] as int,
      lastModified: fields[3] as DateTime,
      deletedAt: fields[4] as DateTime,
      modelType: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Tombstone obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.deviceId)
      ..writeByte(2)
      ..write(obj.lamportClock)
      ..writeByte(3)
      ..write(obj.lastModified)
      ..writeByte(4)
      ..write(obj.deletedAt)
      ..writeByte(5)
      ..write(obj.modelType);
  }
}

Map<int, dynamic> _readFields(BinaryReader reader) {
  final fieldCount = reader.readByte();
  return <int, dynamic>{
    for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
  };
}

List<String> _stringList(Object? value) {
  if (value == null) {
    return const <String>[];
  }

  return List<String>.from(value as Iterable);
}
