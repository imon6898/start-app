import 'package:flutter_starter/app/services/sync/sync_record.dart';

/// The worked example entity. Note the shape: a client-generated `id`, a server
/// `updated_at`, and nothing else the sync engine needs to know about.
class NoteModel {
  const NoteModel({
    required this.id,
    this.title,
    this.body,
    this.updatedAt,
    this.pending = false,
  });

  final String id;
  final String? title;
  final String? body;
  final DateTime? updatedAt;

  /// True while this row has edits the server has not acknowledged.
  final bool pending;

  NoteModel copyWith({String? title, String? body, bool? pending}) => NoteModel(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    updatedAt: updatedAt,
    pending: pending ?? this.pending,
  );

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
    id: (json['id'] ?? '').toString(),
    title: json['title'] as String?,
    body: json['body'] as String?,
    updatedAt: SyncRecord.parseTimestamp(json['updated_at'] ?? json['updatedAt']),
  );

  /// Local store row -> model. `dirty` becomes the "not yet synced" badge.
  factory NoteModel.fromRecord(SyncRecord record) => NoteModel(
    id: record.id,
    title: record.data['title'] as String?,
    body: record.data['body'] as String?,
    updatedAt: record.updatedAt,
    pending: record.dirty,
  );

  /// What goes into the outbox payload — never include `updated_at`, the server
  /// owns it.
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body};
}
