import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/device_provider.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/services/storage_service.dart';
import '../models/memo_item.dart';

final memoProvider = StateNotifierProvider<MemoController, AsyncValue<List<MemoItem>>>((ref) {
  return MemoController(
    storage: ref.watch(storageServiceProvider),
    deviceId: ref.watch(deviceIdProvider),
  );
});

class MemoController extends StateNotifier<AsyncValue<List<MemoItem>>> {
  MemoController({
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
      final items = await _storage.getAllItems<MemoItem>(StorageBoxNames.memos);
      return _sortVisible(items);
    });
  }

  Future<MemoItem> createMemo({
    required String content,
    List<String> attachments = const <String>[],
  }) async {
    final now = DateTime.now();
    final memo = MemoItem(
      id: _uuid.v4(),
      content: content,
      createdAt: now,
      lastModified: now,
      deviceId: _deviceId,
      attachments: attachments,
      lamportClock: 1,
    );

    await _storage.saveItem(StorageBoxNames.memos, memo);
    await _replaceInState(memo);
    return memo;
  }

  Future<MemoItem> updateMemo(
    String id, {
    String? content,
    List<String>? attachments,
  }) async {
    final current = await _requireMemo(id);
    final updated = current.copyWith(content: content, attachments: attachments);

    await _storage.saveItem(StorageBoxNames.memos, updated);
    await _replaceInState(updated);
    return updated;
  }

  Future<MemoItem> addAttachment(String id, String attachmentPath) async {
    final current = await _requireMemo(id);
    final attachments = <String>[...current.attachments, attachmentPath];
    return updateMemo(id, attachments: attachments);
  }

  Future<MemoItem> deleteMemo(String id) async {
    final current = await _requireMemo(id);
    final deleted = current.copyWith(isDeleted: true);
    await _storage.saveItem(StorageBoxNames.memos, deleted);
    await _replaceInState(deleted);
    return deleted;
  }

  Future<MemoItem> _requireMemo(String id) async {
    final item = await _storage.getItemById<MemoItem>(StorageBoxNames.memos, id);
    if (item == null || item.isDeleted) {
      throw StateError('Memo not found: $id');
    }
    return item;
  }

  Future<void> _replaceInState(MemoItem item) async {
    final existing = state.valueOrNull ?? await _storage.getAllItems<MemoItem>(StorageBoxNames.memos);
    final byId = <String, MemoItem>{for (final current in existing) current.id: current};
    byId[item.id] = item;
    state = AsyncValue.data(_sortVisible(byId.values));
  }

  List<MemoItem> _sortVisible(Iterable<MemoItem> items) {
    return items.where((item) => !item.isDeleted).toList()
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
  }
}
