import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'sync_database.g.dart';

/// Every entity lives in one table as opaque JSON. One schema serves every
/// collection, so adding a synced entity needs no migration and no codegen.
@DataClassName('SyncRecordRow')
class SyncRecords extends Table {
  TextColumn get collection => text()();
  TextColumn get id => text()();
  TextColumn get payload => text()();

  /// Epoch millis, not `dateTime()` — drift's datetime storage mode is a
  /// project-wide build option, and this table must not depend on it.
  IntColumn get updatedAt => integer()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {collection, id};
}

/// The write queue. `opId` is the idempotency key and the primary key.
@DataClassName('OutboxRow')
class OutboxOps extends Table {
  TextColumn get opId => text()();
  TextColumn get collection => text()();
  TextColumn get entityId => text()();
  TextColumn get kind => text()();
  TextColumn get payload => text()();
  TextColumn get rollback => text().nullable()();
  IntColumn get baseUpdatedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptAt => integer().nullable()();
  TextColumn get lastError => text().nullable()();
  BoolColumn get deadLettered => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {opId};
}

/// Per-collection pull cursor.
@DataClassName('SyncMetaRow')
class SyncMetas extends Table {
  TextColumn get collection => text()();
  IntColumn get lastPulledAt => integer().nullable()();
  TextColumn get cursor => text().nullable()();

  @override
  Set<Column> get primaryKey => {collection};
}

@DriftDatabase(tables: [SyncRecords, OutboxOps, SyncMetas])
class SyncDatabase extends _$SyncDatabase {
  SyncDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// In-memory database for tests.
  SyncDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _open() => LazyDatabase(() async {
    // Application support, not documents: this is app state, not user files.
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/sync.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
