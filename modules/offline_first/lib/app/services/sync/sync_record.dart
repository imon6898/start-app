import 'dart:convert';

/// One row as the sync engine sees it: an opaque JSON body plus the four fields
/// the engine reasons about. Entities stay untyped here so a single table and a
/// single code path serve every collection.
class SyncRecord {
  const SyncRecord({
    required this.collection,
    required this.id,
    required this.data,
    required this.updatedAt,
    this.deleted = false,
    this.dirty = false,
  });

  /// Logical table name, e.g. `notes`.
  final String collection;

  /// Client-generated UUID — the primary key on both sides.
  final String id;

  final Map<String, dynamic> data;

  /// Server timestamp when the server has seen this row, local clock otherwise.
  final DateTime updatedAt;

  /// Tombstone. Deletes are never hard-deleted first, or the next pull revives them.
  final bool deleted;

  /// Has local changes the server has not acknowledged.
  final bool dirty;

  SyncRecord copyWith({
    Map<String, dynamic>? data,
    DateTime? updatedAt,
    bool? deleted,
    bool? dirty,
  }) => SyncRecord(
    collection: collection,
    id: id,
    data: data ?? this.data,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
  );

  /// Reads the server shape: `id`, `updated_at`, `deleted` — camelCase fallback.
  factory SyncRecord.fromServerJson(String collection, Map<String, dynamic> json) {
    final raw = json['updated_at'] ?? json['updatedAt'];
    return SyncRecord(
      collection: collection,
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      data: Map<String, dynamic>.from(json),
      updatedAt: parseTimestamp(raw) ?? DateTime.now().toUtc(),
      deleted: json['deleted'] == true || json['deleted_at'] != null,
    );
  }

  Map<String, dynamic> toJson() => {
    'collection': collection,
    'id': id,
    'data': data,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'deleted': deleted,
    'dirty': dirty,
  };

  String encodeData() => jsonEncode(data);

  /// Accepts ISO-8601, epoch seconds and epoch millis — servers disagree.
  static DateTime? parseTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is num) {
      final n = raw.toInt();
      // Anything under ~year 2286 in millis is seconds if it is this small.
      return DateTime.fromMillisecondsSinceEpoch(
        n < 100000000000 ? n * 1000 : n,
        isUtc: true,
      );
    }
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  @override
  String toString() =>
      'SyncRecord($collection/$id, updatedAt: $updatedAt, dirty: $dirty, deleted: $deleted)';
}
