import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/device_provider.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/services/storage_service.dart';
import '../models/todo_item.dart';

final todoProvider = StateNotifierProvider<TodoController, AsyncValue<List<TodoItem>>>((ref) {
  return TodoController(
    storage: ref.watch(storageServiceProvider),
    deviceId: ref.watch(deviceIdProvider),
  );
});

class TodoController extends StateNotifier<AsyncValue<List<TodoItem>>> {
  TodoController({
    required StorageService storage,
    required String deviceId,
    Uuid? uuid,
  })  : _storage = storage,
        _deviceId = deviceId,
        _uuid = uuid ?? const Uuid(),
        super(const AsyncValue.loading());

  final StorageService _storage;
  final String _deviceId;
  final Uuid _uuid;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final items = await _storage.getAllItems<TodoItem>(StorageBoxNames.todos);
      return _sortVisible(items);
    });
  }

  Future<TodoItem> createTodo({
    required String title,
    String? description,
    DateTime? dueDate,
    int priority = 0,
    List<String> tags = const <String>[],
  }) async {
    final now = DateTime.now();
    final item = TodoItem(
      id: _uuid.v4(),
      title: title,
      description: description,
      createdAt: now,
      dueDate: dueDate,
      priority: priority,
      tags: tags,
      lastModified: now,
      deviceId: _deviceId,
      lamportClock: 1,
    );

    await _storage.saveItem(StorageBoxNames.todos, item);
    await _replaceInState(item);
    return item;
  }

  Future<TodoItem> updateTodo(
    String id, {
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? dueDate,
    int? priority,
    List<String>? tags,
  }) async {
    final current = await _requireTodo(id);
    final updated = current.copyWith(
      title: title,
      description: description,
      isCompleted: isCompleted,
      dueDate: dueDate,
      priority: priority,
      tags: tags,
    );

    await _storage.saveItem(StorageBoxNames.todos, updated);
    await _replaceInState(updated);
    return updated;
  }

  Future<TodoItem> toggleCompleted(String id) async {
    final current = await _requireTodo(id);
    return updateTodo(id, isCompleted: !current.isCompleted);
  }

  Future<TodoItem> deleteTodo(String id) async {
    final current = await _requireTodo(id);
    final deleted = current.copyWith(isDeleted: true);
    await _storage.saveItem(StorageBoxNames.todos, deleted);
    await _replaceInState(deleted);
    return deleted;
  }

  Future<TodoItem> _requireTodo(String id) async {
    final item = await _storage.getItemById<TodoItem>(StorageBoxNames.todos, id);
    if (item == null || item.isDeleted) {
      throw StateError('Todo not found: $id');
    }
    return item;
  }

  Future<void> _replaceInState(TodoItem item) async {
    final existing = state.valueOrNull ?? await _storage.getAllItems<TodoItem>(StorageBoxNames.todos);
    final byId = <String, TodoItem>{for (final current in existing) current.id: current};
    byId[item.id] = item;
    state = AsyncValue.data(_sortVisible(byId.values));
  }

  List<TodoItem> _sortVisible(Iterable<TodoItem> items) {
    final visible = items.where((item) => !item.isDeleted).toList()
      ..sort((a, b) {
        final completionCompare = a.isCompleted == b.isCompleted ? 0 : (a.isCompleted ? 1 : -1);
        if (completionCompare != 0) return completionCompare;
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        return b.lastModified.compareTo(a.lastModified);
      });
    return visible;
  }
}
