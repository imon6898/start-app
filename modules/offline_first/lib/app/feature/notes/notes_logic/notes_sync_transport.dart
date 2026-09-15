import 'package:dio/dio.dart';
import 'package:flutter_starter/app/services/sync/outbox_op.dart';
import 'package:flutter_starter/app/services/sync/sync_record.dart';
import 'package:flutter_starter/app/services/sync/sync_transport.dart';

import 'notes_api_service.dart';

/// Server side of the `notes` collection. Copy this file per synced entity —
/// only the Repo and the collection name change.
class NotesSyncTransport implements SyncTransport {
  NotesSyncTransport({NotesRepo? repo}) : _repo = repo ?? NotesRepo();

  final NotesRepo _repo;

  static const String collection = 'notes';

  @override
  Future<SyncPullPage> pull(
    String collection, {
    DateTime? since,
    String? cursor,
    int limit = 200,
  }) async {
    final res = await _repo.fetchChanges(since: since, cursor: cursor, limit: limit);
    // ApiService.get swallows DioException and returns null — treat it as a
    // failed pull so the engine backs off instead of advancing the cursor.
    if (res is! Response) throw const SyncPullFailure('notes pull returned nothing');

    final body = _envelope(res.data);
    final rawList = (body['changes'] ?? body['records'] ?? body['items'] ?? const []);
    final records = <SyncRecord>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          records.add(SyncRecord.fromServerJson(collection, item));
        }
      }
    }

    return SyncPullPage(
      records: records,
      nextCursor: body['next_cursor'] as String?,
      serverTime: SyncRecord.parseTimestamp(body['server_time']),
    );
  }

  @override
  Future<SyncPushOutcome> push(OutboxOp op) async {
    final res = await _repo.pushOp(op.toRequestBody());
    // post() returns e.response on a DioException and null when offline.
    if (res is! Response) return const SyncPushRetry('no response from server');

    final code = res.statusCode ?? 0;
    final body = _envelope(res.data);

    if (code == 200 || code == 201 || code == 204) {
      final row = body['record'] ?? body['note'];
      return SyncPushAccepted(
        record: row is Map<String, dynamic>
            ? SyncRecord.fromServerJson(op.collection, row)
            : null,
      );
    }

    // 409 must carry the server's current row, or there is nothing to resolve.
    if (code == 409) {
      final row = body['record'] ?? body['note'] ?? body['current'];
      if (row is Map<String, dynamic>) {
        return SyncPushConflict(SyncRecord.fromServerJson(op.collection, row));
      }
      return const SyncPushRetry('409 without the server record');
    }

    if (code == 408 || code == 425 || code == 429 || code >= 500) {
      return SyncPushRetry('server said $code', retryAfter: _retryAfter(res));
    }

    if (code >= 400) {
      return SyncPushRejected(
        '${body['message'] ?? body['error'] ?? 'Rejected'} ($code)',
      );
    }
    return SyncPushRetry('unexpected status $code');
  }

  /// Accepts both `{data: {...}}` and a bare object.
  Map<String, dynamic> _envelope(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is Map<String, dynamic>) return inner;
      return raw;
    }
    if (raw is List) return {'changes': raw};
    return const {};
  }

  Duration? _retryAfter(Response res) {
    final header = res.headers.value('retry-after');
    final seconds = int.tryParse(header ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }
}

/// Thrown so the engine records a failed pull instead of advancing the cursor.
class SyncPullFailure implements Exception {
  const SyncPullFailure(this.message);
  final String message;

  @override
  String toString() => 'SyncPullFailure: $message';
}
