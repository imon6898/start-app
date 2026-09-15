/// Where the sync engine is right now. `offline` is not an error — it is the
/// normal resting state of an offline-first app.
enum SyncStatus { idle, syncing, offline, error }

extension SyncStatusX on SyncStatus {
  bool get isBusy => this == SyncStatus.syncing;
  bool get isHealthy => this == SyncStatus.idle;
}
