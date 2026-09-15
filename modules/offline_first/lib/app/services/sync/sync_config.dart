import 'sync_backoff.dart';

/// Engine tunables. Everything has a sane default; override what you need.
class SyncConfig {
  const SyncConfig({
    this.backoff = const SyncBackoff(),
    this.pushBatchSize = 50,
    this.pullPageSize = 200,
    this.maxPullPages = 20,
    this.tombstoneRetention = const Duration(days: 30),
    this.syncOnResume = true,
    this.syncOnReconnect = true,
    this.coalescePendingUpdates = true,
    this.minRetryDelay = const Duration(seconds: 5),
  });

  final SyncBackoff backoff;

  /// Ops replayed per run. Keeps one run from blocking the UI for minutes.
  final int pushBatchSize;

  final int pullPageSize;

  /// Guard against a server that keeps handing back a cursor forever.
  final int maxPullPages;

  /// How long a local tombstone is kept before `purgeTombstones` may drop it.
  /// Shorter than the server's retention and a pull will resurrect the row.
  final Duration tombstoneRetention;

  final bool syncOnResume;
  final bool syncOnReconnect;

  /// Replace an un-sent update for the same entity instead of queueing a second
  /// one. Off means every keystroke-level save becomes its own request.
  final bool coalescePendingUpdates;

  /// Floor for the scheduled retry timer.
  final Duration minRetryDelay;
}
