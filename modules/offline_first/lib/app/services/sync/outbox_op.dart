import 'dart:convert';

enum OutboxKind { create, update, delete }

/// A pending mutation. [opId] is the idempotency key: it is generated once, on
/// this device, and never changes for the life of the op — so a replay after a
/// timeout is de-duplicated by the server instead of applied twice.
class OutboxOp {
  const OutboxOp({
    required this.opId,
    required this.collection,
    required this.entityId,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.rollback,
    this.baseUpdatedAt,
    this.attempts = 0,
    this.nextAttemptAt,
    this.lastError,
    this.deadLettered = false,
  });

  /// Idempotency key. Sent as the `Idempotency-Key` header and as `op_id`.
  final String opId;

  final String collection;
  final String entityId;
  final OutboxKind kind;

  /// The mutation body sent to the server.
  final Map<String, dynamic> payload;

  /// Snapshot of the row before the optimistic write, for rollback on rejection.
  final Map<String, dynamic>? rollback;

  /// `updated_at` this edit was based on, for server-side optimistic concurrency.
  final DateTime? baseUpdatedAt;

  final DateTime createdAt;
  final int attempts;

  /// Backoff gate — the op is skipped until this passes.
  final DateTime? nextAttemptAt;

  final String? lastError;

  /// Retries exhausted or resolution deferred. Skipped by the drain, surfaced in the UI.
  final bool deadLettered;

  OutboxOp copyWith({
    Map<String, dynamic>? payload,
    Map<String, dynamic>? rollback,
    DateTime? baseUpdatedAt,
    int? attempts,
    DateTime? nextAttemptAt,
    String? lastError,
    bool? deadLettered,
    bool clearNextAttempt = false,
    bool clearError = false,
  }) => OutboxOp(
    opId: opId,
    collection: collection,
    entityId: entityId,
    kind: kind,
    payload: payload ?? this.payload,
    rollback: rollback ?? this.rollback,
    baseUpdatedAt: baseUpdatedAt ?? this.baseUpdatedAt,
    createdAt: createdAt,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: clearNextAttempt ? null : (nextAttemptAt ?? this.nextAttemptAt),
    lastError: clearError ? null : (lastError ?? this.lastError),
    deadLettered: deadLettered ?? this.deadLettered,
  );

  /// The wire body. `op_id` is duplicated here for servers that cannot read headers.
  Map<String, dynamic> toRequestBody() => {
    'op_id': opId,
    'kind': kind.name,
    'id': entityId,
    if (baseUpdatedAt != null)
      'base_updated_at': baseUpdatedAt!.toUtc().toIso8601String(),
    ...payload,
  };

  String encodePayload() => jsonEncode(payload);
  String? encodeRollback() => rollback == null ? null : jsonEncode(rollback);

  @override
  String toString() =>
      'OutboxOp(${kind.name} $collection/$entityId, op: $opId, attempts: $attempts'
      '${deadLettered ? ', DEAD' : ''})';
}
