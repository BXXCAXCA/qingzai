import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/device_provider.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/services/storage_service.dart';
import '../models/pomodoro_session.dart';

final pomodoroProvider = StateNotifierProvider<PomodoroController, AsyncValue<List<PomodoroSession>>>((ref) {
  return PomodoroController(
    storage: ref.watch(storageServiceProvider),
    deviceId: ref.watch(deviceIdProvider),
  );
});

class PomodoroController extends StateNotifier<AsyncValue<List<PomodoroSession>>> {
  PomodoroController({
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
      final items = await _storage.getAllItems<PomodoroSession>(StorageBoxNames.pomodoro);
      return _sortVisible(items);
    });
  }

  Future<PomodoroSession> startSession({
    required int duration,
    PomodoroType type = PomodoroType.work,
    String? taskId,
  }) async {
    final now = DateTime.now();
    final session = PomodoroSession(
      id: _uuid.v4(),
      startTime: now,
      duration: duration,
      type: type,
      taskId: taskId,
      deviceId: _deviceId,
      lastModified: now,
      lamportClock: 1,
    );

    await _storage.saveItem(StorageBoxNames.pomodoro, session);
    await _replaceInState(session);
    return session;
  }

  Future<PomodoroSession> completeSession(String id, {DateTime? endTime}) async {
    final current = await _requireSession(id);
    final completed = current.copyWith(
      endTime: endTime ?? DateTime.now(),
      isCompleted: true,
    );

    await _storage.saveItem(StorageBoxNames.pomodoro, completed);
    await _replaceInState(completed);
    return completed;
  }

  Future<PomodoroSession> updateSession(
    String id, {
    int? duration,
    PomodoroType? type,
    String? taskId,
  }) async {
    final current = await _requireSession(id);
    final updated = current.copyWith(
      duration: duration,
      type: type,
      taskId: taskId,
    );

    await _storage.saveItem(StorageBoxNames.pomodoro, updated);
    await _replaceInState(updated);
    return updated;
  }

  Future<PomodoroSession> deleteSession(String id) async {
    final current = await _requireSession(id);
    final deleted = current.copyWith(isDeleted: true);
    await _storage.saveItem(StorageBoxNames.pomodoro, deleted);
    await _replaceInState(deleted);
    return deleted;
  }

  List<PomodoroSession> get completedSessions {
    return (state.valueOrNull ?? const <PomodoroSession>[])
        .where((session) => session.isCompleted)
        .toList();
  }

  Future<PomodoroSession> _requireSession(String id) async {
    final item = await _storage.getItemById<PomodoroSession>(StorageBoxNames.pomodoro, id);
    if (item == null || item.isDeleted) {
      throw StateError('Pomodoro session not found: $id');
    }
    return item;
  }

  Future<void> _replaceInState(PomodoroSession item) async {
    final existing = state.valueOrNull ?? await _storage.getAllItems<PomodoroSession>(StorageBoxNames.pomodoro);
    final byId = <String, PomodoroSession>{for (final current in existing) current.id: current};
    byId[item.id] = item;
    state = AsyncValue.data(_sortVisible(byId.values));
  }

  List<PomodoroSession> _sortVisible(Iterable<PomodoroSession> items) {
    return items.where((item) => !item.isDeleted).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }
}
