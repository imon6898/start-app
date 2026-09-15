import 'outbox_op.dart';
import 'sync_record.dart';

/// One page of server changes.
class SyncPullPage {
  const SyncPullPage({
    this.records = const [],
    this.nextCursor,
    this.serverTime,
  });

  final List<SyncRecord> records;

  /// Non-null when the server has more for this `since` window.
  final String? nextCursor;

  /// The server's clock at the moment of the read. Used as the next `since`, so
  /// clock skew on the device cannot skip a change.
  final DateTime? serverTime;
}

/// The result of replaying one outbox op.
sealed class SyncPushOutcome {
  const SyncPushOutcome();
}

/// Applied. [record] is the server's version of the row, when it returns one.
class SyncPushAccepted extends SyncPushOutcome {
  const SyncPushAccepted({this.record});
  final SyncRecord? record;
}

/// The server has a newer version — hand it to the conflict resolver.
class SyncPushConflict extends SyncPushOutcome {
  const SyncPushConflict(this.remote);
  final SyncRecord remote;
}

/// Permanently refused (validation, 403, 404, 422). Retrying cannot help, so
/// the engine rolls the optimistic write back.
class SyncPushRejected extends SyncPushOutcome {
  const SyncPushRejected(this.reason);
  final String reason;
}

/// Transient (timeout, 5xx, 429, no socket). The engine backs off and replays
/// the SAME op id, which is why the server must honour the idempotency key.
class SyncPushRetry extends SyncPushOutcome {
  const SyncPushRetry(this.reason, {this.retryAfter});
  final String reason;
  final Duration? retryAfter;
}

/// Server side of one collection. Implement it next to the feature's Repo — see
/// `lib/app/feature/notes/notes_logic/notes_sync_transport.dart`.
abstract class SyncTransport {
  /// Changes with `updated_at > since`, tombstones included.
  Future<SyncPullPage> pull(
    String collection, {
    DateTime? since,
    String? cursor,
    int limit = 200,
  });

  /// Replays one queued mutation. Must pass `op.opId` as the idempotency key.
  Future<SyncPushOutcome> push(OutboxOp op);
}
