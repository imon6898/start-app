import 'package:sqflite/sqflite.dart';

import 'dev_tools.dart';
import 'http_cache_store.dart';

/// Persistent HttpCacheStore: one sqflite table, a byte cap, LRU eviction.
class SqfliteHttpCacheStore implements HttpCacheStore {
  SqfliteHttpCacheStore._(this._db, this.maxBytes);

  static const String table = 'http_cache';
  static const int schemaVersion = 1;

  final Database _db;

  @override
  final int maxBytes;

  /// Opens (and creates) the cache database. [directory] defaults to the
  /// platform database folder; pass one from path_provider if you prefer
  /// Library/Caches on iOS so the OS may reclaim it.
  static Future<SqfliteHttpCacheStore> open({
    int maxBytes = 8 * 1024 * 1024,
    String fileName = 'http_cache.db',
    String? directory,
  }) async {
    final dir = directory ?? await getDatabasesPath();
    final db = await openDatabase(
      '$dir/$fileName',
      version: schemaVersion,
      onCreate: (db, version) => _createSchema(db),
      // A cache is disposable: a schema change drops it instead of migrating.
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS $table');
        await _createSchema(db);
      },
      onDowngrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS $table');
        await _createSchema(db);
      },
    );
    return SqfliteHttpCacheStore._(db, maxBytes);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $table (
        key TEXT PRIMARY KEY,
        primary_key TEXT NOT NULL,
        vary_names TEXT NOT NULL,
        vary_signature TEXT NOT NULL,
        status INTEGER NOT NULL,
        headers TEXT NOT NULL,
        body BLOB NOT NULL,
        body_kind TEXT NOT NULL,
        stored_at INTEGER NOT NULL,
        last_used_at INTEGER NOT NULL,
        date_at INTEGER,
        expires_at INTEGER,
        max_age INTEGER,
        age INTEGER NOT NULL DEFAULT 0,
        etag TEXT,
        last_modified TEXT,
        no_cache INTEGER NOT NULL DEFAULT 0,
        must_revalidate INTEGER NOT NULL DEFAULT 0,
        swr INTEGER,
        sie INTEGER,
        hits INTEGER NOT NULL DEFAULT 0,
        size INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_${table}_primary ON $table (primary_key)',
    );
    await db.execute('CREATE INDEX idx_${table}_lru ON $table (last_used_at)');
  }

  @override
  Future<List<CacheEntry>> candidates(String primaryKey) async {
    final rows = await _db.query(
      table,
      where: 'primary_key = ?',
      whereArgs: [primaryKey],
    );
    return rows.map(CacheEntry.fromRow).toList();
  }

  @override
  Future<int> put(CacheEntry entry) async {
    await _db.insert(
      table,
      entry.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return _evict();
  }

  @override
  Future<void> touch(CacheEntry entry, DateTime at) async {
    await _db.update(
      table,
      {
        'last_used_at': at.toUtc().millisecondsSinceEpoch,
        'hits': entry.hits + 1,
      },
      where: 'key = ?',
      whereArgs: [entry.key],
    );
  }

  @override
  Future<void> delete(String key) async {
    await _db.delete(table, where: 'key = ?', whereArgs: [key]);
  }

  @override
  Future<int> invalidatePrefix(String urlPrefix) async {
    // LIKE, so % and _ in the argument are wildcards — pass a plain path.
    return _db.delete(
      table,
      where: 'primary_key LIKE ?',
      whereArgs: ['%$urlPrefix%'],
    );
  }

  @override
  Future<void> clear() async {
    await _db.delete(table);
  }

  @override
  Future<HttpCacheStoreStats> stats() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c, COALESCE(SUM(size), 0) AS s, MIN(stored_at) AS o '
      'FROM $table',
    );
    final row = rows.isEmpty ? const <String, Object?>{} : rows.first;
    final oldest = row['o'];
    return HttpCacheStoreStats(
      entryCount: (row['c'] as int?) ?? 0,
      totalBytes: (row['s'] as int?) ?? 0,
      maxBytes: maxBytes,
      oldestStoredAt: oldest is int
          ? DateTime.fromMillisecondsSinceEpoch(oldest, isUtc: true)
          : null,
    );
  }

  @override
  Future<void> close() => _db.close();

  Future<int> _totalBytes() async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(size), 0) AS s FROM $table',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Drops least-recently-used rows until the cap is respected.
  Future<int> _evict() async {
    var total = await _totalBytes();
    if (total <= maxBytes) return 0;
    var evicted = 0;
    while (total > maxBytes) {
      final rows = await _db.query(
        table,
        columns: ['key', 'size'],
        orderBy: 'last_used_at ASC',
        limit: 16,
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        await _db.delete(table, where: 'key = ?', whereArgs: [row['key']]);
        total -= (row['size'] as int?) ?? 0;
        evicted++;
        if (total <= maxBytes) break;
      }
    }
    devPrint('HttpCache: evicted $evicted entr${evicted == 1 ? 'y' : 'ies'}');
    return evicted;
  }
}
