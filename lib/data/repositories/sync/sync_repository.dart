/// Cloud sync boundary — Phase 1 stub only (Local First).
abstract class SyncRepository {
  Future<void> pushPendingChanges();

  Future<void> pullRemoteChanges();

  Stream<bool> get isSyncing;

  bool get isEnabled;
}

class NoOpSyncRepository implements SyncRepository {
  @override
  bool get isEnabled => false;

  @override
  Stream<bool> get isSyncing => Stream.value(false);

  @override
  Future<void> pullRemoteChanges() async {}

  @override
  Future<void> pushPendingChanges() async {}
}
