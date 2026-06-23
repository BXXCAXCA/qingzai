import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../errors/app_exception.dart';
import '../models/model_validation.dart';
import '../models/syncable_model.dart';
import 'hive_model_adapters.dart';
import 'storage_service.dart';

class HiveStorageService implements StorageService {
  HiveStorageService({this.storageDirectory});

  final String? storageDirectory;

  bool _initialized = false;
  Future<void>? _initializing;
  final _openingBoxes = <String, Future<Box<dynamic>>>{};

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final inFlight = _initializing;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    _initializing = _initializeInternal();
    try {
      await _initializing;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initializeInternal() async {
    try {
      await Hive.initFlutter(storageDirectory);
      registerQingZaiHiveAdapters();
      _initialized = true;
    } catch (error) {
      throw StorageException('Failed to initialize local storage.', cause: error);
    }
  }

  @override
  Future<bool> saveItem<T>(String boxName, T item) async {
    final box = await _box(boxName);
    final id = _extractAndValidateId(item);

    try {
      await box.put(id, item);
      return true;
    } catch (error) {
      throw StorageException('Failed to save item to "$boxName".', cause: error);
    }
  }

  @override
  Future<List<T>> getAllItems<T>(String boxName) async {
    final box = await _box(boxName);

    try {
      return box.values.cast<T>().toList(growable: false);
    } catch (error) {
      throw StorageException(
        'Failed to read items from "$boxName" as requested type.',
        cause: error,
      );
    }
  }

  Future<List<T>> getItemsPage<T>(
    String boxName, {
    int offset = 0,
    int limit = 50,
  }) async {
    if (offset < 0) {
      throw const ValidationException('Page offset must not be negative.');
    }
    if (limit <= 0) {
      throw const ValidationException('Page limit must be positive.');
    }

    final box = await _box(boxName);
    try {
      return box.values
          .skip(offset)
          .take(limit)
          .cast<T>()
          .toList(growable: false);
    } catch (error) {
      throw StorageException(
        'Failed to read paged items from "$boxName".',
        cause: error,
      );
    }
  }

  Future<List<T>> getSyncableChangesAfter<T extends SyncableModel>(
    String boxName, {
    required int lamportClock,
  }) async {
    final box = await _box(boxName);
    try {
      final changed = <T>[];
      for (final value in box.values) {
        if (value is T && value.lamportClock > lamportClock) {
          changed.add(value);
        }
      }
      changed.sort((left, right) {
        final clockComparison = left.lamportClock.compareTo(right.lamportClock);
        if (clockComparison != 0) {
          return clockComparison;
        }
        return left.id.compareTo(right.id);
      });
      return List<T>.unmodifiable(changed);
    } catch (error) {
      throw StorageException(
        'Failed to read indexed changes from "$boxName".',
        cause: error,
      );
    }
  }

  Future<Map<String, T>> getItemsByIds<T>(
    String boxName,
    Iterable<String> ids,
  ) async {
    final box = await _box(boxName);
    final result = <String, T>{};

    try {
      for (final id in ids) {
        validateNonEmptyString(id, 'id');
        final value = box.get(id);
        if (value == null) {
          continue;
        }
        if (value is! T) {
          throw StorageException(
            'Stored item "$id" in "$boxName" is ${value.runtimeType}, not $T.',
          );
        }
        result[id] = value;
      }
      return Map<String, T>.unmodifiable(result);
    } catch (error) {
      if (error is StorageException) {
        rethrow;
      }
      throw StorageException('Failed to read indexed ids from "$boxName".', cause: error);
    }
  }

  @override
  Future<T?> getItemById<T>(String boxName, String id) async {
    validateNonEmptyString(id, 'id');
    final box = await _box(boxName);
    final value = box.get(id);

    if (value == null) {
      return null;
    }

    if (value is! T) {
      throw StorageException(
        'Stored item "$id" in "$boxName" is ${value.runtimeType}, not $T.',
      );
    }

    return value;
  }

  @override
  Future<bool> deleteItem(String boxName, String id) async {
    validateNonEmptyString(id, 'id');
    final box = await _box(boxName);
    final existed = box.containsKey(id);

    try {
      await box.delete(id);
      return existed;
    } catch (error) {
      throw StorageException('Failed to delete item "$id" from "$boxName".', cause: error);
    }
  }

  @override
  Future<int> saveItemsBatch<T>(String boxName, List<T> items) async {
    if (items.isEmpty) {
      return 0;
    }

    final box = await _box(boxName);
    final entries = <String, T>{
      for (final item in items) _extractAndValidateId(item): item,
    };

    try {
      await box.putAll(entries);
      return entries.length;
    } catch (error) {
      throw StorageException('Failed to batch save items to "$boxName".', cause: error);
    }
  }

  @override
  Future<void> clearBox(String boxName) async {
    final box = await _box(boxName);

    try {
      await box.clear();
    } catch (error) {
      throw StorageException('Failed to clear "$boxName".', cause: error);
    }
  }

  @override
  Future<int> getItemCount(String boxName) async {
    final box = await _box(boxName);
    return box.length;
  }

  @override
  Stream<BoxEvent> watchBox(String boxName) {
    _validateBoxName(boxName);
    return Stream.fromFuture(_box(boxName)).asyncExpand((box) => box.watch());
  }

  Future<void> compactBox(String boxName) async {
    final box = await _box(boxName);
    await box.compact();
  }

  Future<void> close() async {
    if (!_initialized) {
      return;
    }

    await Hive.close();
    _openingBoxes.clear();
    _initialized = false;
  }

  Future<Box<dynamic>> _box(String boxName) async {
    _validateBoxName(boxName);
    if (!_initialized) {
      await initialize();
    }

    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<dynamic>(boxName);
    }

    final opening = _openingBoxes[boxName];
    if (opening != null) {
      return opening;
    }

    final future = Hive.openBox<dynamic>(boxName);
    _openingBoxes[boxName] = future;
    try {
      return await future;
    } finally {
      _openingBoxes.remove(boxName);
    }
  }

  void _validateBoxName(String boxName) {
    validateNonEmptyString(boxName, 'boxName');

    if (!StorageBoxNames.allBoxes.contains(boxName)) {
      throw StorageException('Unknown storage box "$boxName".');
    }
  }

  String _extractAndValidateId(Object? item) {
    if (item is SyncableModel) {
      validateUuid(item.id);
      return item.id;
    }

    if (item is Map<String, Object?>) {
      final id = item['id'];
      if (id is! String) {
        throw const StorageException('Map item must contain a string "id" field.');
      }
      validateUuid(id);
      return id;
    }

    throw StorageException(
      'Stored item must implement SyncableModel or contain a string "id" field; got ${item.runtimeType}.',
    );
  }
}
