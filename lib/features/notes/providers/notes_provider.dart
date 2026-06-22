import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/device_provider.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/services/storage_service.dart';
import '../models/note_item.dart';

final notesProvider = StateNotifierProvider<NotesController, AsyncValue<List<NoteItem>>>((ref) {
  return NotesController(
    storage: ref.watch(storageServiceProvider),
    deviceId: ref.watch(deviceIdProvider),
  );
});

class NotesController extends StateNotifier<AsyncValue<List<NoteItem>>> {
  NotesController({
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
      final items = await _storage.getAllItems<NoteItem>(StorageBoxNames.notes);
      return _sortVisible(items);
    });
  }

  Future<NoteItem> createNote({
    required String title,
    required String content,
    List<String> tags = const <String>[],
    bool isPinned = false,
    String? color,
  }) async {
    final now = DateTime.now();
    final item = NoteItem(
      id: _uuid.v4(),
      title: title,
      content: content,
      createdAt: now,
      lastModified: now,
      tags: tags,
      isPinned: isPinned,
      deviceId: _deviceId,
      color: color,
      lamportClock: 1,
    );

    await _storage.saveItem(StorageBoxNames.notes, item);
    await _replaceInState(item);
    return item;
  }

  Future<NoteItem> updateNote(
    String id, {
    String? title,
    String? content,
    List<String>? tags,
    bool? isPinned,
    String? color,
  }) async {
    final current = await _requireNote(id);
    final updated = current.copyWith(
      title: title,
      content: content,
      tags: tags,
      isPinned: isPinned,
      color: color,
    );

    await _storage.saveItem(StorageBoxNames.notes, updated);
    await _replaceInState(updated);
    return updated;
  }

  Future<NoteItem> togglePinned(String id) async {
    final current = await _requireNote(id);
    return updateNote(id, isPinned: !current.isPinned);
  }

  Future<NoteItem> deleteNote(String id) async {
    final current = await _requireNote(id);
    final deleted = current.copyWith(isDeleted: true);
    await _storage.saveItem(StorageBoxNames.notes, deleted);
    await _replaceInState(deleted);
    return deleted;
  }

  List<NoteItem> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return state.valueOrNull ?? const <NoteItem>[];
    }

    return (state.valueOrNull ?? const <NoteItem>[]).where((note) {
      return note.title.toLowerCase().contains(normalized) ||
          note.content.toLowerCase().contains(normalized) ||
          note.tags.any((tag) => tag.toLowerCase().contains(normalized));
    }).toList();
  }

  Future<NoteItem> _requireNote(String id) async {
    final item = await _storage.getItemById<NoteItem>(StorageBoxNames.notes, id);
    if (item == null || item.isDeleted) {
      throw StateError('Note not found: $id');
    }
    return item;
  }

  Future<void> _replaceInState(NoteItem item) async {
    final existing = state.valueOrNull ?? await _storage.getAllItems<NoteItem>(StorageBoxNames.notes);
    final byId = <String, NoteItem>{for (final current in existing) current.id: current};
    byId[item.id] = item;
    state = AsyncValue.data(_sortVisible(byId.values));
  }

  List<NoteItem> _sortVisible(Iterable<NoteItem> items) {
    return items.where((item) => !item.isDeleted).toList()
      ..sort((a, b) {
        final pinnedCompare = a.isPinned == b.isPinned ? 0 : (a.isPinned ? -1 : 1);
        if (pinnedCompare != 0) return pinnedCompare;
        return b.lastModified.compareTo(a.lastModified);
      });
  }
}
