import 'dart:math';

import 'package:flutter_starter/app/services/sync/memory_sync_store.dart';
import 'package:flutter_starter/app/services/sync/outbox_op.dart';
import 'package:flutter_starter/app/services/sync/sync_backoff.dart';
import 'package:flutter_starter/app/services/sync/sync_conflict_resolver.dart';
import 'package:flutter_starter/app/services/sync/sync_config.dart';
import 'package:flutter_starter/app/services/sync/sync_record.dart';
import 'package:flutter_starter/app/services/sync/sync_service.dart';
import 'package:flutter_starter/app/services/sync/sync_status.dart';
import 'package:flutter_starter/app/services/sync/sync_transport.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scripted transport: one outcome per push call, and a canned pull page.
class FakeTransport implements SyncTransport {
  FakeTransport({this.outcomes = const [], this.page = const SyncPullPage()});

  /// Consumed in order; the last one repeats once exhausted.
  List<SyncPushOutcome> outcomes;
  SyncPullPage page;

  final List<OutboxOp> pushed = [];
  int pullCalls = 0;
  DateTime? lastSince;
  Object? pullError;

  @override
  Future<SyncPushOutcome> push(OutboxOp op) async {
    pushed.add(op);
    if (outcomes.isEmpty) return const SyncPushAccepted();
    final index = pushed.length - 1;
    return outcomes[index < outcomes.length ? index : outcomes.length - 1];
  }

  @override
  Future<SyncPullPage> pull(
    String collection, {
    DateTime? since,
    String? cursor,
    int limit = 200,
  }) async {
    pullCalls++;
    lastSince = since;
    if (pullError != null) throw pullError!;
    return page;
  }
}

const String kNotes = 'notes';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fastBackoff = SyncBackoff(
    base: Duration(milliseconds: 1),
    max: Duration(milliseconds: 2),
    maxAttempts: 3,
  );
  const fastConfig = SyncConfig(
    backoff: fastBackoff,
    minRetryDelay: Duration(milliseconds: 1),
    syncOnResume: false,
    syncOnReconnect: false,
  );

  late MemorySyncStore store;
  late SyncService sync;
  var started = false;

  /// Builds a started service. `online` false exercises the offline gate.
  Future<SyncService> build({
    FakeTransport? transport,
    SyncConflictResolver? resolver,
    bool online = true,
    SyncConfig config = fastConfig,
  }) async {
    store = MemorySyncStore();
    sync = SyncService(store: store, config: config, isOnline: () async => online);
    sync.register(kNotes, transport ?? FakeTransport(), resolver: resolver);
    sync.onInit();
    started = true;
    await Future<void>.delayed(Duration.zero);
    return sync;
  }

  tearDown(() {
    if (started) sync.onClose();
    started = false;
  });

  group('SyncBackoff', () {
    test('full jitter stays inside random(0, base * 2^attempt)', () {
      const backoff = SyncBackoff(base: Duration(seconds: 2), max: Duration(minutes: 5));
      final rng = Random(7);
      for (var attempt = 0; attempt < 6; attempt++) {
        final ceiling = 2000 * (1 << attempt);
        for (var i = 0; i < 50; i++) {
          final delay = backoff.delayFor(attempt, random: rng).inMilliseconds;
          expect(delay, inInclusiveRange(0, ceiling));
        }
      }
    });

    test('never exceeds max', () {
      const backoff = SyncBackoff(base: Duration(seconds: 2), max: Duration(seconds: 10));
      for (var i = 0; i < 200; i++) {
        expect(backoff.delayFor(20).inMilliseconds, lessThanOrEqualTo(10000));
      }
    });

    test('exhaustion is inclusive of maxAttempts', () {
      const backoff = SyncBackoff(maxAttempts: 3);
      expect(backoff.isExhausted(2), isFalse);
      expect(backoff.isExhausted(3), isTrue);
    });
  });

  group('optimistic write', () {
    test('save writes locally and queues exactly one op', () async {
      await build();
      final id = sync.newId();
      await sync.save(kNotes, id: id, data: {'title': 'a'}, syncImmediately: false);

      final row = await store.find(kNotes, id);
      expect(row, isNotNull);
      expect(row!.dirty, isTrue);
      expect(row.data['title'], 'a');
      expect(await store.pendingCount(), 1);
      expect(sync.pendingCount.value, 1);
    });

    test('id is a client-generated uuid v4', () async {
      await build();
      expect(
        sync.newId(),
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('delete writes a tombstone, not a hard delete', () async {
      final transport = FakeTransport();
      await build(transport: transport);
      final id = sync.newId();
      await sync.save(kNotes, id: id, data: {'title': 'a'}, syncImmediately: false);
      await sync.syncNow(pull: false);
      await sync.delete(kNotes, id, syncImmediately: false);

      final row = await store.find(kNotes, id);
      expect(row!.deleted, isTrue);
      expect(await store.all(kNotes), isEmpty);
      expect(transport.pushed.last.kind, OutboxKind.create);
    });

    test('an un-sent update is coalesced instead of queued twice', () async {
      final transport = FakeTransport();
      await build(transport: transport);
      final id = sync.newId();
      await sync.save(kNotes, id: id, data: {'title': 'a'}, syncImmediately: false);
      await sync.syncNow(pull: false);

      await sync.save(kNotes, id: id, data: {'title': 'b'}, syncImmediately: false);
      await sync.save(kNotes, id: id, data: {'title': 'c'}, syncImmediately: false);

      final ops = await store.opsFor(kNotes, id);
      expect(ops.length, 1);
      expect(ops.single.payload['title'], 'c');
    });
  });

  group('idempotency', () {
    test('a replay after a timeout reuses the SAME op id', () async {
      final transport = FakeTransport(
        outcomes: const [SyncPushRetry('timeout'), SyncPushAccepted()],
      );
      await build(transport: transport);
      await sync.save(kNotes, id: 'n1', data: {'title': 'a'}, syncImmediately: false);

      await sync.syncNow(pull: false);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await sync.syncNow(pull: false);

      expect(transport.pushed.length, 2);
      expect(transport.pushed[0].opId, transport.pushed[1].opId);
      expect(await store.pendingCount(), 0);
    });

    test('the op id travels in the request body as op_id', () async {
      await build();
      final op = OutboxOp(
        opId: 'op-1',
        collection: kNotes,
        entityId: 'n1',
        kind: OutboxKind.update,
        payload: const {'title': 'a'},
        createdAt: DateTime.utc(2024),
        baseUpdatedAt: DateTime.utc(2023),
      );
      final body = op.toRequestBody();
      expect(body['op_id'], 'op-1');
      expect(body['kind'], 'update');
      expect(body['base_updated_at'], '2023-01-01T00:00:00.000Z');
      expect(body['title'], 'a');
    });

    test('accepted ops leave the outbox and clear the dirty flag', () async {
      await build(transport: FakeTransport());
      await sync.save(kNotes, id: 'n1', data: {'title': 'a'}, syncImmediately: false);
      await sync.syncNow(pull: false);

      expect((await store.find(kNotes, 'n1'))!.dirty, isFalse);
      expect(sync.pendingCount.value, 0);
      expect(sync.status.value, SyncStatus.idle);
      expect(sync.lastSyncedAt.value, isNotNull);
    });
  });

  group('rollback', () {
    test('a rejected update restores the previous snapshot', () async {
      final transport = FakeTransport(
        outcomes: const [SyncPushAccepted(), SyncPushRejected('422 title too long')],
      );
      await build(transport: transport);
      await sync.save(kNotes, id: 'n1', data: {'title': 'good'}, syncImmediately: false);
      await sync.syncNow(pull: false);

      await sync.save(kNotes, id: 'n1', data: {'title': 'bad'}, syncImmediately: false);
      await sync.syncNow(pull: false);

      final row = await store.find(kNotes, 'n1');
      expect(row!.data['title'], 'good');
      expect(row.dirty, isFalse);
      expect(await store.pendingCount(), 0);
      expect(sync.status.value, SyncStatus.error);
    });

    test('a rejected create purges the row — it never existed anywhere', () async {
      final transport = FakeTransport(outcomes: const [SyncPushRejected('403')]);
      await build(transport: transport);
      await sync.save(kNotes, id: 'n1', data: {'title': 'a'}, syncImmediately: false);
      await sync.syncNow(pull: false);

      expect(await store.find(kNotes, 'n1'), isNull);
    });
  });

  group('conflicts', () {
    final older = DateTime.utc(2024, 1, 1);
    final newer = DateTime.utc(2024, 6, 1);

    SyncConflict conflict({required DateTime local, required DateTime remote, bool tombstone = false}) =>
        SyncConflict(
          local: SyncRecord(
            collection: kNotes,
            id: 'n1',
            data: const {'title': 'local'},
            updatedAt: local,
            dirty: true,
          ),
          remote: SyncRecord(
            collection: kNotes,
            id: 'n1',
            data: const {'title': 'remote'},
            updatedAt: remote,
            deleted: tombstone,
          ),
        );

    test('last-write-wins picks the newer side', () {
      const resolver = LastWriteWinsResolver();
      expect(
        resolver.resolve(conflict(local: newer, remote: older)),
        isA<KeepLocal>(),
      );
      expect(
        resolver.resolve(conflict(local: older, remote: newer)),
        isA<KeepRemote>(),
      );
    });

    test('a tie goes to the server', () {
      expect(
        const LastWriteWinsResolver().resolve(conflict(local: newer, remote: newer)),
        isA<KeepRemote>(),
      );
    });

    test('a remote tombstone beats a newer local edit', () {
      expect(
        const LastWriteWinsResolver()
            .resolve(conflict(local: newer, remote: older, tombstone: true)),
        isA<KeepRemote>(),
      );
    });

    test('field merge visits every key on either side', () {
      final resolver = FieldMergeResolver((key, local, remote) => local ?? remote);
      final result = resolver.resolve(
        SyncConflict(
          local: SyncRecord(
            collection: kNotes,
            id: 'n1',
            data: const {'title': 'local'},
            updatedAt: newer,
          ),
          remote: SyncRecord(
            collection: kNotes,
            id: 'n1',
            data: const {'title': 'remote', 'body': 'server body'},
            updatedAt: older,
          ),
        ),
      );
      expect(result, isA<MergedResolution>());
      final merged = (result as MergedResolution).data;
      expect(merged['title'], 'local');
      expect(merged['body'], 'server body');
    });

    test('a 409 resolved as KeepRemote replaces the local row and drops the op', () async {
      final remote = SyncRecord(
        collection: kNotes,
        id: 'n1',
        data: const {'title': 'server'},
        updatedAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      final transport = FakeTransport(outcomes: [SyncPushConflict(remote)]);
      await build(transport: transport);
      await sync.save(kNotes, id: 'n1', data: {'title': 'mine'}, syncImmediately: false);
      await sync.syncNow(pull: false);

      final row = await store.find(kNotes, 'n1');
      expect(row!.data['title'], 'server');
      expect(row.dirty, isFalse);
      expect(await store.pendingCount(), 0);
    });

    test('a manual resolver parks the conflict and does not guess', () async {
      final remote = SyncRecord(
        collection: kNotes,
        id: 'n1',
        data: const {'title': 'server'},
        updatedAt: DateTime.now().toUtc(),
      );
      final transport = FakeTransport(outcomes: [SyncPushConflict(remote)]);
      await build(transport: transport, resolver: const ManualConflictResolver());
      await sync.save(kNotes, id: 'n1', data: {'title': 'mine'}, syncImmediately: false);
      await sync.syncNow(pull: false);

      expect(sync.pendingConflicts.length, 1);
      expect((await store.find(kNotes, 'n1'))!.data['title'], 'mine');
      expect(sync.deadLetterCount.value, 1);

      await sync.resolveConflict(sync.pendingConflicts.first, const KeepRemote());
      expect(sync.pendingConflicts, isEmpty);
      expect((await store.find(kNotes, 'n1'))!.data['title'], 'server');
    });
  });

  group('failure handling', () {
    test('an op is dead-lettered after maxAttempts and revived on retryFailed', () async {
      final transport = FakeTransport(outcomes: const [SyncPushRetry('500')]);
      await build(transport: transport);
      await sync.save(kNotes, id: 'n1', data: {'title': 'a'}, syncImmediately: false);

      for (var i = 0; i < 3; i++) {
        await sync.syncNow(pull: false);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect((await store.deadLetters()).length, 1);
      expect(sync.pendingCount.value, 0);
      expect(sync.deadLetterCount.value, 1);

      transport.outcomes = const [SyncPushAccepted()];
      await sync.retryFailed();
      expect(sync.deadLetterCount.value, 0);
      expect(sync.pendingCount.value, 0);
    });

    test('one stuck entity does not block a different one', () async {
      final transport = _PerEntityTransport(failing: 'n1');
      await build(transport: transport);
      await sync.save(kNotes, id: 'n1', data: {'title': 'a'}, syncImmediately: false);
      await sync.save(kNotes, id: 'n2', data: {'title': 'b'}, syncImmediately: false);

      await sync.syncNow(pull: false);

      expect((await store.opsFor(kNotes, 'n1')).length, 1);
      expect(await store.opsFor(kNotes, 'n2'), isEmpty);
      expect((await store.find(kNotes, 'n2'))!.dirty, isFalse);
    });

    test('offline short-circuits: status is offline and nothing is pushed', () async {
      final transport = FakeTransport();
      await build(transport: transport, online: false);
      await sync.save(kNotes, id: 'n1', data: {'title': 'a'}, syncImmediately: false);

      expect(await sync.syncNow(pull: false), isFalse);
      expect(transport.pushed, isEmpty);
      expect(sync.status.value, SyncStatus.offline);
      expect(sync.pendingCount.value, 1);
    });

    test('a failed pull does not advance the cursor', () async {
      final transport = FakeTransport()..pullError = Exception('boom');
      await build(transport: transport);

      expect(await sync.syncNow(), isFalse);
      expect(await store.lastPulledAt(kNotes), isNull);
      expect(sync.status.value, SyncStatus.error);
    });
  });

  group('pull', () {
    test('remote rows land clean and the cursor moves to the server clock', () async {
      final serverTime = DateTime.utc(2025, 3, 3);
      final transport = FakeTransport(
        page: SyncPullPage(
          records: [
            SyncRecord.fromServerJson(kNotes, {
              'id': 'r1',
              'title': 'from server',
              'updated_at': '2025-03-02T00:00:00Z',
            }),
          ],
          serverTime: serverTime,
        ),
      );
      await build(transport: transport);

      expect(await sync.syncNow(), isTrue);
      final row = await store.find(kNotes, 'r1');
      expect(row!.data['title'], 'from server');
      expect(row.dirty, isFalse);
      expect(await store.lastPulledAt(kNotes), serverTime);
    });

    test('a pull never clobbers a newer unsent local edit', () async {
      final transport = FakeTransport(
        page: SyncPullPage(
          records: [
            SyncRecord(
              collection: kNotes,
              id: 'n1',
              data: const {'title': 'stale server'},
              updatedAt: DateTime.utc(2020),
            ),
          ],
        ),
        outcomes: const [SyncPushRetry('offline-ish')],
      );
      await build(transport: transport);
      await sync.save(kNotes, id: 'n1', data: {'title': 'mine'}, syncImmediately: false);

      await sync.syncNow();
      expect((await store.find(kNotes, 'n1'))!.data['title'], 'mine');
    });

    test('a fresh tombstone is kept so it cannot be resurrected', () async {
      final transport = FakeTransport(
        page: SyncPullPage(
          records: [
            SyncRecord.fromServerJson(kNotes, {
              'id': 'r1',
              'deleted': true,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }),
          ],
        ),
      );
      await build(transport: transport);
      await sync.syncNow();

      expect(await store.all(kNotes), isEmpty);
      expect((await store.find(kNotes, 'r1'))!.deleted, isTrue);
    });

    test('a tombstone past the retention window is purged', () async {
      final transport = FakeTransport(
        page: SyncPullPage(
          records: [
            SyncRecord.fromServerJson(kNotes, {
              'id': 'r1',
              'deleted': true,
              'updated_at': DateTime.now()
                  .toUtc()
                  .subtract(const Duration(days: 40))
                  .toIso8601String(),
            }),
          ],
        ),
      );
      await build(transport: transport);
      await sync.syncNow();

      expect(await store.find(kNotes, 'r1'), isNull);
    });
  });

  group('timestamps', () {
    test('parses ISO-8601, epoch seconds and epoch millis', () {
      expect(
        SyncRecord.parseTimestamp('2025-03-02T00:00:00Z'),
        DateTime.utc(2025, 3, 2),
      );
      expect(
        SyncRecord.parseTimestamp(1740873600),
        DateTime.fromMillisecondsSinceEpoch(1740873600000, isUtc: true),
      );
      expect(
        SyncRecord.parseTimestamp(1740873600000),
        DateTime.fromMillisecondsSinceEpoch(1740873600000, isUtc: true),
      );
      expect(SyncRecord.parseTimestamp(null), isNull);
      expect(SyncRecord.parseTimestamp('not a date'), isNull);
    });
  });

  group('sign-out', () {
    test('wipe clears records, outbox and cursors', () async {
      await build();
      await sync.save(kNotes, id: 'n1', data: {'title': 'a'}, syncImmediately: false);
      await sync.wipe();

      expect(await store.all(kNotes), isEmpty);
      expect(await store.pendingCount(), 0);
      expect(sync.pendingCount.value, 0);
      expect(sync.lastSyncedAt.value, isNull);
    });
  });
}

/// Fails every push for one entity id, accepts the rest.
class _PerEntityTransport extends FakeTransport {
  _PerEntityTransport({required this.failing});

  final String failing;

  @override
  Future<SyncPushOutcome> push(OutboxOp op) async {
    pushed.add(op);
    return op.entityId == failing
        ? const SyncPushRetry('stuck')
        : const SyncPushAccepted();
  }
}
