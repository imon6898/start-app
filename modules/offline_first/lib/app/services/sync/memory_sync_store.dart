import 'dart:async';

import 'outbox_op.dart';
import 'sync_record.dart';
import 'sync_store.dart';

/// In-memory [SyncStore]. Used by the unit tests and handy for a UI spike
/// before drift's codegen is wired up — it loses everything on restart.
class MemorySyncStore implements SyncStore {
  final Map<String, SyncRecord> _records = {};
  final Map<String, OutboxOp> _ops = {};
  final Map<String, DateTime> _lastPulled = {};
  final Map<String, String?> _cursors = {};
  final Map<String, StreamController<List<SyncRecord>>> _watchers = {};

  String _key(String collection, String id) => '$collection/$id';

  @override
  Future<void> init() async {}

  @override
  Future<List<SyncRecord>> all(String collection, {bool includeDeleted = false}) async =>
      _all(collection, includeDeleted: includeDeleted);

  List<SyncRecord> _all(String collection, {bool includeDeleted = false}) => _records.values
      .where((r) => r.collection == collection && (includeDeleted || !r.deleted))
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<SyncRecord?> find(String collection, String id) async =>
      _records[_key(collection, id)];

  @override
  Future<void> upsert(SyncRecord record) async {
    _records[_key(record.collection, record.id)] = record;
    _emit(record.collection);
  }

  @override
  Future<void> upsertAll(Iterable<SyncRecord> records) async {
    final touched = <String>{};
    for (final r in records) {
      _records[_key(r.collection, r.id)] = r;
      touched.add(r.collection);
    }
    touched.forEach(_emit);
  }

  @override
  Future<void> purge(String collection, String id) async {
    _records.remove(_key(collection, id));
    _emit(collection);
  }

  @override
  Future<int> purgeTombstones({required Duration olderThan}) async {
    final cutoff = DateTime.now().toUtc().subtract(olderThan);
    final dead = _records.values
        .where((r) => r.deleted && !r.dirty && r.updatedAt.isBefore(cutoff))
        .toList();
    for (final r in dead) {
      _records.remove(_key(r.collection, r.id));
    }
    dead.map((r) => r.collection).toSet().forEach(_emit);
    return dead.length;
  }

  @override
  Stream<List<SyncRecord>> watch(String collection, {bool includeDeleted = false}) {
    final controller = _watchers.putIfAbsent(
      collection,
      () => StreamController<List<SyncRecord>>.broadcast(),
    );
    return controller.stream.map(
      (rows) => includeDeleted ? rows : rows.where((r) => !r.deleted).toList(),
    );
  }

  void _emit(String collection) =>
      _watchers[collection]?.add(_all(collection, includeDeleted: true));

  @override
  Future<void> enqueue(OutboxOp op) async => _ops[op.opId] = op;

  @override
  Future<void> updateOp(OutboxOp op) async => _ops[op.opId] = op;

  @override
  Future<void> deleteOp(String opId) async => _ops.remove(opId);

  @override
  Future<List<OutboxOp>> readyOps({DateTime? now, int limit = 100}) async {
    final at = now ?? DateTime.now().toUtc();
    return (_ops.values
            .where((o) => !o.deadLettered)
            .where((o) => o.nextAttemptAt == null || !o.nextAttemptAt!.isAfter(at))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
        .take(limit)
        .toList();
  }

  @override
  Future<List<OutboxOp>> opsFor(String collection, String entityId) async =>
      _ops.values
          .where((o) => o.collection == collection && o.entityId == entityId)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<int> pendingCount() async => _ops.values.where((o) => !o.deadLettered).length;

  @override
  Future<List<OutboxOp>> deadLetters() async =>
      _ops.values.where((o) => o.deadLettered).toList();

  @override
  Future<void> reviveDeadLetters() async {
    for (final op in _ops.values.where((o) => o.deadLettered).toList()) {
      _ops[op.opId] = op.copyWith(
        deadLettered: false,
        attempts: 0,
        clearNextAttempt: true,
        clearError: true,
      );
    }
  }

  @override
  Future<DateTime?> lastPulledAt(String collection) async => _lastPulled[collection];

  @override
  Future<void> setLastPulledAt(String collection, DateTime at) async =>
      _lastPulled[collection] = at.toUtc();

  @override
  Future<String?> pullCursor(String collection) async => _cursors[collection];

  @override
  Future<void> setPullCursor(String collection, String? cursor) async =>
      _cursors[collection] = cursor;

  @override
  Future<void> clear() async {
    final collections = _records.values.map((r) => r.collection).toSet();
    _records.clear();
    _ops.clear();
    _lastPulled.clear();
    _cursors.clear();
    collections.forEach(_emit);
  }

  @override
  Future<void> close() async {
    for (final c in _watchers.values) {
      await c.close();
    }
    _watchers.clear();
  }
}
