import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import 'outbox_op.dart';
import 'sync_conflict_resolver.dart';
import 'sync_config.dart';
import 'sync_record.dart';
import 'sync_status.dart';
import 'sync_store.dart';
import 'sync_transport.dart';

/// The sync engine. Writes land locally first and are queued in the outbox;
/// the queue is replayed to the server whenever the app is online.
///
/// Register it once in bootstrap: `Get.put(SyncService(store: ...), permanent: true)`.
class SyncService extends GetxService with WidgetsBindingObserver {
  SyncService({
    required this.store,
    this.config = const SyncConfig(),
    this.isOnline,
  });

  static SyncService get to => Get.find();

  final SyncStore store;
  final SyncConfig config;

  /// Optional reachability probe. Null means "assume online and let the
  /// transport fail" — pair with `connectivity_banner` instead, see README.
  final Future<bool> Function()? isOnline;

  final Rx<SyncStatus> status = SyncStatus.idle.obs;

  /// Live outbox depth. Dead letters are counted separately.
  final RxInt pendingCount = 0.obs;

  final Rx<DateTime?> lastSyncedAt = Rx<DateTime?>(null);

  /// Last failure message, for the banner. Empty when healthy.
  final RxString lastError = ''.obs;

  /// Ops that exhausted their retries, or conflicts deferred to a human.
  final RxInt deadLetterCount = 0.obs;

  /// Only populated when a collection uses `ManualConflictResolver`.
  final RxList<SyncConflict> pendingConflicts = <SyncConflict>[].obs;

  final Map<String, SyncTransport> _transports = {};
  final Map<String, SyncConflictResolver> _resolvers = {};
  final Set<String> _inFlight = {};
  final Uuid _uuid = const Uuid();

  Future<bool>? _currentRun;
  Timer? _retryTimer;
  StreamSubscription<bool>? _onlineSub;
  int _consecutiveFailures = 0;
  bool _wasOnline = true;

  /// Collections wired up with a transport.
  Iterable<String> get collections => _transports.keys;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  /// Never rethrows: a failed sqlite open (or a missing plugin under
  /// `flutter test`) must not take the first frame down with it.
  Future<void> _boot() async {
    try {
      await store.init();
      await _refreshCounters();
      lastSyncedAt.value = await _earliestLastPull();
    } catch (e) {
      devPrint('sync: local store unavailable — $e');
      lastError.value = '$e';
      status.value = SyncStatus.error;
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _onlineSub?.cancel();
    super.onClose();
  }

  /// Wire a collection to its server side. Defaults to last-write-wins.
  void register(
    String collection,
    SyncTransport transport, {
    SyncConflictResolver? resolver,
  }) {
    _transports[collection] = transport;
    _resolvers[collection] = resolver ?? const LastWriteWinsResolver();
  }

  /// Sync on reconnect. Pass `ConnectivityService.to.isOnline.stream`.
  void attachConnectivity(Stream<bool> onlineChanges) {
    _onlineSub?.cancel();
    _onlineSub = onlineChanges.listen((online) {
      final reconnected = online && !_wasOnline;
      _wasOnline = online;
      if (!online) {
        if (!status.value.isBusy) status.value = SyncStatus.offline;
        return;
      }
      if (reconnected && config.syncOnReconnect) syncNow();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && config.syncOnResume) syncNow();
  }

  // ── Reads ──

  Future<List<SyncRecord>> read(String collection) => store.all(collection);

  Stream<List<SyncRecord>> watch(String collection) => store.watch(collection);

  Future<SyncRecord?> findOne(String collection, String id) =>
      store.find(collection, id);

  /// Client-generated primary key. Generating it here — not on the server — is
  /// what lets a row be created, edited and referenced while offline.
  String newId() => _uuid.v4();

  // ── Writes ──

  /// Optimistic create-or-update: writes locally, queues the mutation, returns
  /// immediately. Pass the [id] from [newId] for a create.
  Future<SyncRecord> save(
    String collection, {
    required String id,
    required Map<String, dynamic> data,
    bool syncImmediately = true,
  }) async {
    final existing = await store.find(collection, id);
    final now = DateTime.now().toUtc();
    final record = SyncRecord(
      collection: collection,
      id: id,
      data: data,
      updatedAt: now,
      dirty: true,
    );
    await store.upsert(record);

    await _enqueue(
      OutboxOp(
        opId: _uuid.v4(),
        collection: collection,
        entityId: id,
        kind: existing == null ? OutboxKind.create : OutboxKind.update,
        payload: data,
        rollback: existing?.data,
        baseUpdatedAt: existing?.updatedAt,
        createdAt: now,
      ),
    );

    if (syncImmediately) _fireAndForget();
    return record;
  }

  /// Optimistic delete. Writes a tombstone locally so a pull cannot revive the
  /// row before the server has seen the delete.
  Future<void> delete(
    String collection,
    String id, {
    bool syncImmediately = true,
  }) async {
    final existing = await store.find(collection, id);
    final now = DateTime.now().toUtc();
    await store.upsert(
      SyncRecord(
        collection: collection,
        id: id,
        data: existing?.data ?? const {},
        updatedAt: now,
        deleted: true,
        dirty: true,
      ),
    );

    await _enqueue(
      OutboxOp(
        opId: _uuid.v4(),
        collection: collection,
        entityId: id,
        kind: OutboxKind.delete,
        payload: {'id': id},
        rollback: existing?.data,
        baseUpdatedAt: existing?.updatedAt,
        createdAt: now,
      ),
    );

    if (syncImmediately) _fireAndForget();
  }

  /// Coalesces an un-sent update into the pending one so a slider drag does not
  /// become 200 requests. Only ops that have never left the device qualify.
  Future<void> _enqueue(OutboxOp op) async {
    if (config.coalescePendingUpdates && op.kind == OutboxKind.update) {
      final existing = await store.opsFor(op.collection, op.entityId);
      final mergeable = existing.firstWhereOrNull(
        (o) =>
            o.kind == OutboxKind.update &&
            o.attempts == 0 &&
            !o.deadLettered &&
            !_inFlight.contains(o.opId),
      );
      if (mergeable != null) {
        // Keep the original op id: it was never transmitted, so it is unused.
        await store.updateOp(
          mergeable.copyWith(payload: op.payload, clearError: true),
        );
        await _refreshCounters();
        return;
      }
    }
    await store.enqueue(op);
    await _refreshCounters();
  }

  // ── Sync ──

  /// Runs a push-then-pull cycle. Concurrent calls share one run.
  Future<bool> syncNow({bool pull = true}) {
    final running = _currentRun;
    if (running != null) return running;
    final run = _run(pull: pull).whenComplete(() => _currentRun = null);
    _currentRun = run;
    return run;
  }

  /// Manual retry for dead letters: clears the flags, then syncs.
  Future<bool> retryFailed() async {
    await store.reviveDeadLetters();
    _consecutiveFailures = 0;
    await _refreshCounters();
    return syncNow();
  }

  void _fireAndForget() {
    syncNow().catchError((Object e) {
      devPrint('sync: unexpected error $e');
      return false;
    });
  }

  Future<bool> _run({required bool pull}) async {
    if (_transports.isEmpty) {
      devPrint('sync: no transport registered, nothing to do');
      return true;
    }
    if (!await _reachable()) {
      status.value = SyncStatus.offline;
      _scheduleRetry();
      return false;
    }

    status.value = SyncStatus.syncing;
    lastError.value = '';
    var ok = true;

    try {
      ok = await _drain();
      if (pull) ok = await _pullAll() && ok;
    } catch (e) {
      devPrint('sync: run failed $e');
      lastError.value = '$e';
      ok = false;
    }

    await _refreshCounters();

    if (ok) {
      _consecutiveFailures = 0;
      lastSyncedAt.value = DateTime.now().toUtc();
      status.value = SyncStatus.idle;
      _retryTimer?.cancel();
      if (pendingCount.value > 0) _scheduleRetry();
    } else {
      _consecutiveFailures++;
      status.value = SyncStatus.error;
      _scheduleRetry();
    }
    return ok;
  }

  Future<bool> _reachable() async {
    if (isOnline == null) return true;
    try {
      return await isOnline!();
    } catch (_) {
      return false;
    }
  }

  // ── Push ──

  Future<bool> _drain() async {
    final ops = await store.readyOps(
      now: DateTime.now().toUtc(),
      limit: config.pushBatchSize,
    );
    // An entity whose op failed is blocked for the rest of the run: replaying a
    // later edit before an earlier one would reorder writes on the server.
    final blocked = <String>{};
    var ok = true;

    for (final op in ops) {
      final key = '${op.collection}/${op.entityId}';
      if (blocked.contains(key)) continue;

      final transport = _transports[op.collection];
      if (transport == null) {
        devPrint('sync: no transport for "${op.collection}", skipping ${op.opId}');
        continue;
      }

      SyncPushOutcome outcome;
      _inFlight.add(op.opId);
      try {
        outcome = await transport.push(op);
      } catch (e) {
        outcome = SyncPushRetry('$e');
      } finally {
        _inFlight.remove(op.opId);
      }

      switch (outcome) {
        case SyncPushAccepted(:final record):
          await _onAccepted(op, record);
        case SyncPushConflict(:final remote):
          await _onPushConflict(op, remote);
        case SyncPushRejected(:final reason):
          await _onRejected(op, reason);
          lastError.value = reason;
          ok = false;
        case SyncPushRetry(:final reason, :final retryAfter):
          await _onRetry(op, reason, retryAfter);
          lastError.value = reason;
          blocked.add(key);
          ok = false;
      }
    }
    return ok;
  }

  Future<void> _onAccepted(OutboxOp op, SyncRecord? serverRecord) async {
    await store.deleteOp(op.opId);
    final remaining = await store.opsFor(op.collection, op.entityId);
    final stillQueued = remaining.any((o) => !o.deadLettered);

    if (serverRecord != null) {
      // Server timestamp is authoritative; keep dirty if more edits are queued.
      await store.upsert(serverRecord.copyWith(dirty: stillQueued));
      return;
    }
    if (stillQueued) return;
    final local = await store.find(op.collection, op.entityId);
    if (local != null) await store.upsert(local.copyWith(dirty: false));
  }

  Future<void> _onRetry(OutboxOp op, String reason, Duration? retryAfter) async {
    final attempts = op.attempts + 1;
    if (config.backoff.isExhausted(attempts)) {
      devPrint('sync: dead-lettering ${op.opId} after $attempts attempts — $reason');
      await store.updateOp(
        op.copyWith(attempts: attempts, lastError: reason, deadLettered: true),
      );
      return;
    }
    final delay = retryAfter ?? config.backoff.delayFor(attempts - 1);
    await store.updateOp(
      op.copyWith(
        attempts: attempts,
        lastError: reason,
        nextAttemptAt: DateTime.now().toUtc().add(delay),
      ),
    );
  }

  /// Permanent rejection: undo the optimistic write, but only when this op is
  /// the entity's last one — otherwise a later edit would be silently reverted.
  Future<void> _onRejected(OutboxOp op, String reason) async {
    await store.deleteOp(op.opId);
    final remaining = await store.opsFor(op.collection, op.entityId);
    if (remaining.isNotEmpty) {
      devPrint('sync: ${op.opId} rejected ($reason); newer ops queued, not rolling back');
      return;
    }
    if (op.rollback == null) {
      // Nothing to restore: the row only ever existed locally.
      await store.purge(op.collection, op.entityId);
      return;
    }
    await store.upsert(
      SyncRecord(
        collection: op.collection,
        id: op.entityId,
        data: op.rollback!,
        updatedAt: op.baseUpdatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _onPushConflict(OutboxOp op, SyncRecord remote) async {
    final local = await store.find(op.collection, op.entityId) ??
        SyncRecord(
          collection: op.collection,
          id: op.entityId,
          data: op.payload,
          updatedAt: op.createdAt,
          dirty: true,
        );
    await store.deleteOp(op.opId);
    await _applyResolution(
      SyncConflict(local: local, remote: remote, base: op.rollback),
      op: op,
    );
  }

  // ── Pull ──

  Future<bool> _pullAll() async {
    var ok = true;
    for (final entry in _transports.entries) {
      try {
        await _pull(entry.key, entry.value);
      } catch (e) {
        devPrint('sync: pull "${entry.key}" failed $e');
        lastError.value = '$e';
        ok = false;
      }
    }
    return ok;
  }

  Future<void> _pull(String collection, SyncTransport transport) async {
    final since = await store.lastPulledAt(collection);
    var cursor = await store.pullCursor(collection);
    DateTime? serverTime;

    for (var page = 0; page < config.maxPullPages; page++) {
      final result = await transport.pull(
        collection,
        since: since,
        cursor: cursor,
        limit: config.pullPageSize,
      );
      serverTime = result.serverTime ?? serverTime;
      for (final remote in result.records) {
        await _applyRemote(collection, remote);
      }
      cursor = result.nextCursor;
      await store.setPullCursor(collection, cursor);
      if (cursor == null) break;
    }

    // The server's clock, not ours — device skew would otherwise skip changes.
    await store.setLastPulledAt(collection, serverTime ?? DateTime.now().toUtc());
    await store.purgeTombstones(olderThan: config.tombstoneRetention);
  }

  Future<void> _applyRemote(String collection, SyncRecord remote) async {
    final local = await store.find(collection, remote.id);
    final queued = await store.opsFor(collection, remote.id);
    final hasLocalWork = (local?.dirty ?? false) || queued.any((o) => !o.deadLettered);

    if (local == null || !hasLocalWork) {
      await store.upsert(remote.copyWith(dirty: false));
      return;
    }
    if (remote.updatedAt.isBefore(local.updatedAt) && !remote.deleted) {
      // Our unsent edit is newer; the push will carry it.
      return;
    }
    await _applyResolution(SyncConflict(local: local, remote: remote));
  }

  // ── Conflicts ──

  Future<void> _applyResolution(SyncConflict conflict, {OutboxOp? op}) async {
    final resolver =
        _resolvers[conflict.collection] ?? const LastWriteWinsResolver();
    await resolveConflict(conflict, resolver.resolve(conflict), sourceOp: op);
  }

  /// Applies a resolution. Call it from the UI with the user's choice after a
  /// `ManualConflictResolver` parked a conflict in [pendingConflicts].
  Future<void> resolveConflict(
    SyncConflict conflict,
    SyncResolution resolution, {
    OutboxOp? sourceOp,
  }) async {
    pendingConflicts.removeWhere(
      (c) => c.collection == conflict.collection && c.id == conflict.id,
    );

    switch (resolution) {
      case KeepRemote():
        for (final o in await store.opsFor(conflict.collection, conflict.id)) {
          await store.deleteOp(o.opId);
        }
        await store.upsert(conflict.remote.copyWith(dirty: false));
      case KeepLocal():
        await _requeueOverwrite(conflict, conflict.local.data);
      case MergedResolution(:final data):
        await _requeueOverwrite(conflict, data);
      case ManualResolution():
        pendingConflicts.add(conflict);
        if (sourceOp != null) {
          // Park the op so it stops blocking the queue, keep the local edit.
          await store.enqueue(
            sourceOp.copyWith(
              deadLettered: true,
              lastError: 'Conflict awaiting manual resolution',
            ),
          );
        }
    }
    await _refreshCounters();
  }

  /// Re-queues a fresh op whose base is the server's version, so the next push
  /// is an intentional overwrite rather than another conflict.
  Future<void> _requeueOverwrite(
    SyncConflict conflict,
    Map<String, dynamic> data,
  ) async {
    for (final o in await store.opsFor(conflict.collection, conflict.id)) {
      await store.deleteOp(o.opId);
    }
    final now = DateTime.now().toUtc();
    await store.upsert(
      SyncRecord(
        collection: conflict.collection,
        id: conflict.id,
        data: data,
        updatedAt: now,
        dirty: true,
      ),
    );
    await store.enqueue(
      OutboxOp(
        opId: _uuid.v4(),
        collection: conflict.collection,
        entityId: conflict.id,
        kind: OutboxKind.update,
        payload: data,
        rollback: conflict.remote.data,
        baseUpdatedAt: conflict.remote.updatedAt,
        createdAt: now,
      ),
    );
  }

  // ── Housekeeping ──

  Future<void> _refreshCounters() async {
    pendingCount.value = await store.pendingCount();
    deadLetterCount.value = (await store.deadLetters()).length;
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final delay = config.backoff.delayFor(_consecutiveFailures);
    final wait = delay < config.minRetryDelay ? config.minRetryDelay : delay;
    _retryTimer = Timer(wait, () => syncNow());
  }

  Future<DateTime?> _earliestLastPull() async {
    DateTime? earliest;
    for (final c in _transports.keys) {
      final at = await store.lastPulledAt(c);
      if (at == null) continue;
      if (earliest == null || at.isBefore(earliest)) earliest = at;
    }
    return earliest;
  }

  /// Sign-out. The outbox holds one account's unsent writes — never carry it over.
  Future<void> wipe() async {
    _retryTimer?.cancel();
    await store.clear();
    pendingConflicts.clear();
    lastSyncedAt.value = null;
    lastError.value = '';
    _consecutiveFailures = 0;
    status.value = SyncStatus.idle;
    await _refreshCounters();
  }
}
