import 'package:hive/hive.dart';

abstract interface class StorageService {
  Future<void> initialize();

  Future<bool> saveItem<T>(String boxName, T item);

  Future<List<T>> getAllItems<T>(String boxName);

  Future<T?> getItemById<T>(String boxName, String id);

  Future<bool> deleteItem(String boxName, String id);

  Future<int> saveItemsBatch<T>(String boxName, List<T> items);

  Future<void> clearBox(String boxName);

  Future<int> getItemCount(String boxName);

  Stream<BoxEvent> watchBox(String boxName);
}

class StorageBoxNames {
  const StorageBoxNames._();

  static const todos = 'todos';
  static const clipboard = 'clipboard';
  static const notes = 'notes';
  static const pomodoro = 'pomodoro';
  static const memos = 'memos';
  static const syncMeta = 'sync_meta';
  static const tombstones = 'tombstones';

  static const syncableBoxes = [
    todos,
    clipboard,
    notes,
    pomodoro,
    memos,
  ];
}
