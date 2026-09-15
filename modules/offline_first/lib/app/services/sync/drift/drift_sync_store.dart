import 'dart:convert';

import 'package:drift/drift.dart';

import '../outbox_op.dart';
import '../sync_record.dart';
import '../sync_store.dart';
import 'sync_database.dart';

/// [SyncStore] on sqlite via drift. The only file in this module that knows SQL.
class DriftSyncStore implements SyncStore {
  DriftSyncStore([SyncDatabase? database]) : db = database ?? SyncDatabase();

  final SyncDatabase db;

  @override
  Future<void> init() async {
    // Opens the file and runs migrations; LazyDatabase does it on first query.
    await db.customSelect('SELECT 1').get();
  }

  // ── Records ──

  @override
  Future<List<SyncRecord>> all(String collection, {bool includeDeleted = false}) async =>
      (await _recordQuery(collection, includeDeleted).get()).map(_toRecord).toList();

  SimpleSelectStatement<$SyncRecordsTable, SyncRecordRow> _recordQuery(
    String collection,
    bool includeDeleted,
  ) => db.select(db.syncRecords)
    ..where(
      (t) => includeDeleted
          ? t.collection.equals(collection)
          : t.collection.equals(collection) & t.deleted.equals(false),
    )
    ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);

  @override
  Future<SyncRecord?> find(String collection, String id) async {
    final row = await (db.select(db.syncRecords)
          ..where((t) => t.collection.equals(collection) & t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toRecord(row);
  }

  @override
  Future<void> upsert(SyncRecord record) =>
      db.into(db.syncRecords).insertOnConflictUpdate(_toCompanion(record));

  @override
  Future<void> upsertAll(Iterable<SyncRecord> records) => db.batch((batch) {
    batch.insertAllOnConflictUpdate(
      db.syncRecords,
      records.map(_toCompanion).toList(),
    );
  });

  @override
  Future<void> purge(String collection, String id) async {
    await (db.delete(db.syncRecords)
          ..where((t) => t.collection.equals(collection) & t.id.equals(id)))
        .go();
  }

  @override
  Future<int> purgeTombstones({required Duration olderThan}) {
    final cutoff = DateTime.now().toUtc().subtract(olderThan).millisecondsSinceEpoch;
    return (db.delete(db.syncRecords)..where(
          (t) =>
              t.deleted.equals(true) &
              t.dirty.equals(false) &
              t.updatedAt.isSmallerThanValue(cutoff),
        ))
        .go();
  }

  @override
  Stream<List<SyncRecord>> watch(String collection, {bool includeDeleted = false}) =>
      _recordQuery(collection, includeDeleted)
          .watch()
          .map((rows) => rows.map(_toRecord).toList());

  // ── Outbox ──

  @override
  Future<void> enqueue(OutboxOp op) =>
      db.into(db.outboxOps).insertOnConflictUpdate(_toOpCompanion(op));

  @override
  Future<void> updateOp(OutboxOp op) =>
      db.into(db.outboxOps).insertOnConflictUpdate(_toOpCompanion(op));

  @override
  Future<void> deleteOp(String opId) async {
    await (db.delete(db.outboxOps)..where((t) => t.opId.equals(opId))).go();
  }

  @override
  Future<List<OutboxOp>> readyOps({DateTime? now, int limit = 100}) async {
    final at = (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    final rows = await (db.select(db.outboxOps)
          ..where(
            (t) =>
                t.deadLettered.equals(false) &
                (t.nextAttemptAt.isNull() | t.nextAttemptAt.isSmallerOrEqualValue(at)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
    return rows.map(_toOp).toList();
  }

  @override
  Future<List<OutboxOp>> opsFor(String collection, String entityId) async {
    final rows = await (db.select(db.outboxOps)
          ..where((t) => t.collection.equals(collection) & t.entityId.equals(entityId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_toOp).toList();
  }

  @override
  Future<int> pendingCount() async {
    final rows = await (db.select(db.outboxOps)
          ..where((t) => t.deadLettered.equals(false)))
        .get();
    return rows.length;
  }

  @override
  Future<List<OutboxOp>> deadLetters() async {
    final rows = await (db.select(db.outboxOps)
          ..where((t) => t.deadLettered.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_toOp).toList();
  }

  @override
  Future<void> reviveDeadLetters() async {
    await (db.update(db.outboxOps)..where((t) => t.deadLettered.equals(true))).write(
      OutboxOpsCompanion(
        deadLettered: const Value(false),
        attempts: const Value(0),
        nextAttemptAt: const Value(null),
        lastError: const Value(null),
      ),
    );
  }

  // ── Cursor ──

  @override
  Future<DateTime?> lastPulledAt(String collection) async {
    final row = await _meta(collection);
    final ms = row?.lastPulledAt;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  @override
  Future<void> setLastPulledAt(String collection, DateTime at) =>
      db.into(db.syncMetas).insertOnConflictUpdate(
        SyncMetasCompanion(
          collection: Value(collection),
          lastPulledAt: Value(at.toUtc().millisecondsSinceEpoch),
        ),
      );

  @override
  Future<String?> pullCursor(String collection) async => (await _meta(collection))?.cursor;

  @override
  Future<void> setPullCursor(String collection, String? cursor) =>
      db.into(db.syncMetas).insertOnConflictUpdate(
        SyncMetasCompanion(collection: Value(collection), cursor: Value(cursor)),
      );

  Future<SyncMetaRow?> _meta(String collection) => (db.select(db.syncMetas)
        ..where((t) => t.collection.equals(collection)))
      .getSingleOrNull();

  @override
  Future<void> clear() async {
    await db.delete(db.syncRecords).go();
    await db.delete(db.outboxOps).go();
    await db.delete(db.syncMetas).go();
  }

  @override
  Future<void> close() => db.close();

  // ── Mapping ──

  SyncRecord _toRecord(SyncRecordRow row) => SyncRecord(
    collection: row.collection,
    id: row.id,
    data: _decode(row.payload),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
    deleted: row.deleted,
    dirty: row.dirty,
  );

  SyncRecordsCompanion _toCompanion(SyncRecord r) => SyncRecordsCompanion(
    collection: Value(r.collection),
    id: Value(r.id),
    payload: Value(r.encodeData()),
    updatedAt: Value(r.updatedAt.toUtc().millisecondsSinceEpoch),
    deleted: Value(r.deleted),
    dirty: Value(r.dirty),
  );

  OutboxOp _toOp(OutboxRow row) => OutboxOp(
    opId: row.opId,
    collection: row.collection,
    entityId: row.entityId,
    kind: OutboxKind.values.firstWhere(
      (k) => k.name == row.kind,
      orElse: () => OutboxKind.update,
    ),
    payload: _decode(row.payload),
    rollback: row.rollback == null ? null : _decode(row.rollback!),
    baseUpdatedAt: row.baseUpdatedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.baseUpdatedAt!, isUtc: true),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    attempts: row.attempts,
    nextAttemptAt: row.nextAttemptAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.nextAttemptAt!, isUtc: true),
    lastError: row.lastError,
    deadLettered: row.deadLettered,
  );

  OutboxOpsCompanion _toOpCompanion(OutboxOp op) => OutboxOpsCompanion(
    opId: Value(op.opId),
    collection: Value(op.collection),
    entityId: Value(op.entityId),
    kind: Value(op.kind.name),
    payload: Value(op.encodePayload()),
    rollback: Value(op.encodeRollback()),
    baseUpdatedAt: Value(op.baseUpdatedAt?.toUtc().millisecondsSinceEpoch),
    createdAt: Value(op.createdAt.toUtc().millisecondsSinceEpoch),
    attempts: Value(op.attempts),
    nextAttemptAt: Value(op.nextAttemptAt?.toUtc().millisecondsSinceEpoch),
    lastError: Value(op.lastError),
    deadLettered: Value(op.deadLettered),
  );

  Map<String, dynamic> _decode(String raw) {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }
}
