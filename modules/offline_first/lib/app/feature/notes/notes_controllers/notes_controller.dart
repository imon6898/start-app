import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_starter/app/feature/notes/notes_models/note_model.dart';
import 'package:flutter_starter/app/services/sync/sync_record.dart';
import 'package:flutter_starter/app/services/sync/sync_service.dart';
import 'package:get/get.dart';

/// Reads the LOCAL store only. The server never blocks the UI: every write is
/// applied here first and replayed by SyncService in the background.
class NotesController extends GetxController {
  static const String collection = 'notes';

  final RxList<NoteModel> notes = <NoteModel>[].obs;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  SyncService get sync => Get.find<SyncService>();

  StreamSubscription<List<SyncRecord>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _sub = sync.watch(collection).listen(_onRows);
    sync.read(collection).then(_onRows);
    sync.syncNow();
  }

  @override
  void onClose() {
    _sub?.cancel();
    titleController.dispose();
    bodyController.dispose();
    super.onClose();
  }

  void _onRows(List<SyncRecord> rows) =>
      notes.assignAll(rows.map(NoteModel.fromRecord));

  /// Returns instantly — the row is in the list before the request is sent.
  Future<void> addNote() async {
    final title = titleController.text.trim();
    if (title.isEmpty) return;
    // The id is generated here, not by the server — that is what makes an
    // offline create a real row you can edit and reference immediately.
    final id = sync.newId();
    await sync.save(
      collection,
      id: id,
      data: NoteModel(id: id, title: title, body: bodyController.text.trim()).toJson(),
    );
    titleController.clear();
    bodyController.clear();
  }

  Future<void> renameNote(NoteModel note, String title) => sync.save(
    collection,
    id: note.id,
    data: {...note.toJson(), 'title': title},
  );

  Future<void> deleteNote(NoteModel note) => sync.delete(collection, note.id);

  /// Pull-to-refresh.
  Future<void> refreshNotes() => sync.syncNow();
}
