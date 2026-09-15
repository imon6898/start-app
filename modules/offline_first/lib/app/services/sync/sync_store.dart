import 'outbox_op.dart';
import 'sync_record.dart';

/// Local persistence contract. The engine never touches SQL, so a project can
/// swap drift for anything (Hive, Isar, a plain file) without changing the
/// sync logic. `MemorySyncStore` is the reference implementation for tests.
abstract class SyncStore {
  Future<void> init();

  // Records

  Future<List<SyncRecord>> all(String collection, {bool includeDeleted = false});
  Future<SyncRecord?> find(String collection, String id);
  Future<void> upsert(SyncRecord record);
  Future<void> upsertAll(Iterable<SyncRecord> records);

  /// Hard delete. Deletes normally go through a tombstone instead.
  Future<void> purge(String collection, String id);

  /// Drops tombstones older than [olderThan] — they only exist to stop a pull
  /// from resurrecting a deleted row.
  Future<int> purgeTombstones({required Duration olderThan});

  /// Live view for the UI. Emits on every local or synced change.
  Stream<List<SyncRecord>> watch(String collection, {bool includeDeleted = false});

  // Outbox

  Future<void> enqueue(OutboxOp op);
  Future<void> updateOp(OutboxOp op);
  Future<void> deleteOp(String opId);

  /// Ops eligible to run now: not dead-lettered, `nextAttemptAt` in the past.
  /// Ordered by `createdAt` so per-entity ordering is preserved.
  Future<List<OutboxOp>> readyOps({DateTime? now, int limit = 100});

  /// Every op for one entity, including dead-lettered ones.
  Future<List<OutboxOp>> opsFor(String collection, String entityId);

  /// Live ops only — excludes dead letters.
  Future<int> pendingCount();

  Future<List<OutboxOp>> deadLetters();

  /// Clears the dead-letter flag and the backoff gate so a manual retry works.
  Future<void> reviveDeadLetters();

  // Cursor

  Future<DateTime?> lastPulledAt(String collection);
  Future<void> setLastPulledAt(String collection, DateTime at);
  Future<String?> pullCursor(String collection);
  Future<void> setPullCursor(String collection, String? cursor);

  /// Wipes everything. Call on sign-out — the outbox belongs to one account.
  Future<void> clear();

  Future<void> close();
}
