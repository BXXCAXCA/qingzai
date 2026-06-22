import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/device_provider.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/services/storage_service.dart';
import '../models/clipboard_item.dart';

final clipboardProvider = StateNotifierProvider<ClipboardController, AsyncValue<List<ClipboardItem>>>((ref) {
  return ClipboardController(
    storage: ref.watch(storageServiceProvider),
    deviceId: ref.watch(deviceIdProvider),
  );
});

class ClipboardController extends StateNotifier<AsyncValue<List<ClipboardItem>>> {
  ClipboardController({
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
      final items = await _storage.getAllItems<ClipboardItem>(StorageBoxNames.clipboard);
      return _sortVisible(items);
    });
  }

  Future<ClipboardItem> addClipboardItem({
    required ClipboardType type,
    required String content,
    bool isFavorite = false,
    String? thumbnail,
  }) async {
    final now = DateTime.now();
    final item = ClipboardItem(
      id: _uuid.v4(),
      type: type,
      content: content,
      timestamp: now,
      deviceId: _deviceId,
      isFavorite: isFavorite,
      thumbnail: thumbnail,
      lastModified: now,
      lamportClock: 1,
    );

    await _storage.saveItem(StorageBoxNames.clipboard, item);
    await _replaceInState(item);
    return item;
  }

  Future<ClipboardItem> toggleFavorite(String id) async {
    final current = await _requireItem(id);
    final updated = current.copyWith(isFavorite: !current.isFavorite);
    await _storage.saveItem(StorageBoxNames.clipboard, updated);
    await _replaceInState(updated);
    return updated;
  }

  Future<ClipboardItem> deleteClipboardItem(String id) async {
    final current = await _requireItem(id);
    final deleted = current.copyWith(isDeleted: true);
    await _storage.saveItem(StorageBoxNames.clipboard, deleted);
    await _replaceInState(deleted);
    return deleted;
  }

  List<ClipboardItem> get favorites {
    return (state.valueOrNull ?? const <ClipboardItem>[]).where((item) => item.isFavorite).toList();
  }

  Future<ClipboardItem> _requireItem(String id) async {
    final item = await _storage.getItemById<ClipboardItem>(StorageBoxNames.clipboard, id);
    if (item == null || item.isDeleted) {
      throw StateError('Clipboard item not found: $id');
    }
    return item;
  }

  Future<void> _replaceInState(ClipboardItem item) async {
    final existing = state.valueOrNull ?? await _storage.getAllItems<ClipboardItem>(StorageBoxNames.clipboard);
    final byId = <String, ClipboardItem>{for (final current in existing) current.id: current};
    byId[item.id] = item;
    state = AsyncValue.data(_sortVisible(byId.values));
  }

  List<ClipboardItem> _sortVisible(Iterable<ClipboardItem> items) {
    return items.where((item) => !item.isDeleted).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
}
