import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'http_cache_policy.dart';

/// How the body was handed to us, so it can be rebuilt in the same shape.
enum CacheBodyKind { json, text, bytes }

/// One stored response plus the metadata the protocol needs to reuse it.
class CacheEntry implements CacheEntryMatch {
  CacheEntry({
    required this.key,
    required this.primaryKey,
    required this.varyNames,
    required this.varySignature,
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.bodyKind,
    required this.storedAt,
    required this.lastUsedAt,
    this.dateHeader,
    this.expires,
    this.maxAgeSeconds,
    this.ageSeconds = 0,
    this.etag,
    this.lastModified,
    this.noCache = false,
    this.mustRevalidate = false,
    this.staleWhileRevalidateSeconds,
    this.staleIfErrorSeconds,
    this.hits = 0,
  }) : size = body.lengthInBytes + _metaBytes(headers, key);

  final String key;
  final String primaryKey;

  @override
  final List<String> varyNames;

  @override
  final String varySignature;

  final int statusCode;
  final Map<String, List<String>> headers;
  final Uint8List body;
  final CacheBodyKind bodyKind;

  /// When this response was received (local clock).
  final DateTime storedAt;
  final DateTime lastUsedAt;

  /// Server-sent Date, used to correct the age.
  final DateTime? dateHeader;
  final DateTime? expires;
  final int? maxAgeSeconds;
  final int ageSeconds;
  final String? etag;
  final String? lastModified;
  final bool noCache;
  final bool mustRevalidate;
  final int? staleWhileRevalidateSeconds;
  final int? staleIfErrorSeconds;
  final int hits;

  /// Bytes charged against the store's cap.
  final int size;

  bool get hasValidator => etag != null || lastModified != null;

  /// max-age wins; otherwise Expires - Date. null means "no freshness info".
  Duration? get freshnessLifetime {
    final maxAge = maxAgeSeconds;
    if (maxAge != null) return Duration(seconds: maxAge);
    final expiresAt = expires;
    if (expiresAt != null) {
      final delta = expiresAt.difference(dateHeader ?? storedAt.toUtc());
      return delta.isNegative ? Duration.zero : delta;
    }
    return null;
  }

  /// RFC 9111 age: the larger of the Age header and the transit gap, plus
  /// however long it has sat here.
  Duration ageAt(DateTime now) {
    final stored = storedAt.toUtc();
    final apparent = dateHeader == null
        ? Duration.zero
        : stored.difference(dateHeader!);
    final claimed = Duration(seconds: ageSeconds);
    final initial = apparent > claimed ? apparent : claimed;
    final resident = now.toUtc().difference(stored);
    final total = initial + (resident.isNegative ? Duration.zero : resident);
    return total.isNegative ? Duration.zero : total;
  }

  bool isFreshAt(DateTime now) {
    if (noCache) return false;
    final lifetime = freshnessLifetime;
    if (lifetime == null) return false;
    return ageAt(now) < lifetime;
  }

  /// Serve-now-refresh-later is allowed only when the server did not forbid it.
  bool canServeStaleAt(DateTime now, Duration clientWindow) {
    if (noCache || mustRevalidate) return false;
    final lifetime = freshnessLifetime;
    if (lifetime == null) return false;
    final swr = staleWhileRevalidateSeconds;
    final window = swr != null ? Duration(seconds: swr) : clientWindow;
    if (window <= Duration.zero) return false;
    return ageAt(now) < lifetime + window;
  }

  /// stale-if-error: the network failed, so a slightly old answer beats none.
  bool canServeOnErrorAt(DateTime now, Duration clientWindow) {
    if (noCache || mustRevalidate) return false;
    final sie = staleIfErrorSeconds;
    final window = sie != null ? Duration(seconds: sie) : clientWindow;
    if (window <= Duration.zero) return false;
    return ageAt(now) < (freshnessLifetime ?? Duration.zero) + window;
  }

  /// Too old for anyone to use — delete rather than revalidate.
  bool isExpiredBeyond(DateTime now, Duration maxStale) =>
      ageAt(now) > (freshnessLifetime ?? Duration.zero) + maxStale;

  /// The stored body, rebuilt. A fresh object each call, so a caller mutating
  /// the result cannot corrupt the cache.
  dynamic decodeBody() {
    switch (bodyKind) {
      case CacheBodyKind.json:
        if (body.isEmpty) return null;
        return jsonDecode(utf8.decode(body));
      case CacheBodyKind.text:
        return utf8.decode(body);
      case CacheBodyKind.bytes:
        return Uint8List.fromList(body);
    }
  }

  Response<dynamic> toResponse(
    RequestOptions options, {
    Map<String, dynamic> extra = const {},
  }) => Response<dynamic>(
    data: decodeBody(),
    requestOptions: options,
    statusCode: statusCode,
    statusMessage: 'OK (cached)',
    headers: Headers.fromMap({
      ...headers,
      'x-cache': const ['HIT'],
    }),
    extra: {
      // Internal keys start with '_' and stay out of the caller's response.
      for (final e in options.extra.entries)
        if (!e.key.startsWith('_')) e.key: e.value,
      ...extra,
    },
  );

  /// A 304 updates the metadata and keeps the stored body.
  CacheEntry revalidatedWith(Response<dynamic> response, {DateTime? now}) {
    final fresh = HttpCachePolicy.storableHeaders(response.headers);
    final merged = {...headers};
    // Only the headers the server actually re-sent are updated.
    fresh.forEach((name, values) {
      if (name == 'content-length') return;
      merged[name] = values;
    });
    final cc = HttpCachePolicy.responseCacheControl(response.headers);
    final at = (now ?? DateTime.now()).toUtc();
    return CacheEntry(
      key: key,
      primaryKey: primaryKey,
      varyNames: varyNames,
      varySignature: varySignature,
      statusCode: statusCode,
      headers: merged,
      body: body,
      bodyKind: bodyKind,
      storedAt: at,
      lastUsedAt: at,
      dateHeader:
          HttpCachePolicy.httpDate(response.headers['date']) ?? dateHeader,
      expires: HttpCachePolicy.httpDate(response.headers['expires']) ?? expires,
      maxAgeSeconds: cc.maxAge ?? maxAgeSeconds,
      ageSeconds:
          int.tryParse(response.headers['age']?.firstOrNull ?? '') ?? 0,
      etag: response.headers['etag']?.firstOrNull ?? etag,
      lastModified:
          response.headers['last-modified']?.firstOrNull ?? lastModified,
      noCache: cc.noCache,
      mustRevalidate: cc.mustRevalidate,
      staleWhileRevalidateSeconds:
          cc.staleWhileRevalidate ?? staleWhileRevalidateSeconds,
      staleIfErrorSeconds: cc.staleIfError ?? staleIfErrorSeconds,
      hits: hits,
    );
  }

  CacheEntry touched(DateTime at) => CacheEntry(
    key: key,
    primaryKey: primaryKey,
    varyNames: varyNames,
    varySignature: varySignature,
    statusCode: statusCode,
    headers: headers,
    body: body,
    bodyKind: bodyKind,
    storedAt: storedAt,
    lastUsedAt: at,
    dateHeader: dateHeader,
    expires: expires,
    maxAgeSeconds: maxAgeSeconds,
    ageSeconds: ageSeconds,
    etag: etag,
    lastModified: lastModified,
    noCache: noCache,
    mustRevalidate: mustRevalidate,
    staleWhileRevalidateSeconds: staleWhileRevalidateSeconds,
    staleIfErrorSeconds: staleIfErrorSeconds,
    hits: hits + 1,
  );

  /// Builds an entry from a live response. null when the body cannot be
  /// serialised (a stream, or a type the transformer produced that we cannot
  /// rebuild) — in that case nothing is stored.
  static CacheEntry? fromResponse({
    required Response<dynamic> response,
    required String primaryKey,
    required List<String> varyNames,
    required String varySignature,
    Duration? defaultMaxAge,
    DateTime? now,
  }) {
    final encoded = _encodeBody(response.data);
    if (encoded == null) return null;
    final cc = HttpCachePolicy.responseCacheControl(response.headers);
    final at = (now ?? DateTime.now()).toUtc();
    final explicitMaxAge = cc.maxAge;
    final hasExpires = response.headers['expires'] != null;
    return CacheEntry(
      key: HttpCachePolicy.storageKey(primaryKey, varySignature),
      primaryKey: primaryKey,
      varyNames: varyNames,
      varySignature: varySignature,
      statusCode: response.statusCode ?? 200,
      headers: HttpCachePolicy.storableHeaders(response.headers),
      body: encoded.bytes,
      bodyKind: encoded.kind,
      storedAt: at,
      lastUsedAt: at,
      dateHeader: HttpCachePolicy.httpDate(response.headers['date']),
      expires: HttpCachePolicy.httpDate(response.headers['expires']),
      maxAgeSeconds: explicitMaxAge ??
          (hasExpires ? null : defaultMaxAge?.inSeconds),
      ageSeconds:
          int.tryParse(response.headers['age']?.firstOrNull ?? '') ?? 0,
      etag: response.headers['etag']?.firstOrNull,
      lastModified: response.headers['last-modified']?.firstOrNull,
      noCache: cc.noCache,
      mustRevalidate: cc.mustRevalidate,
      staleWhileRevalidateSeconds: cc.staleWhileRevalidate,
      staleIfErrorSeconds: cc.staleIfError,
    );
  }

  static _EncodedBody? _encodeBody(dynamic data) {
    if (data == null) return _EncodedBody(Uint8List(0), CacheBodyKind.text);
    if (data is String) {
      return _EncodedBody(
        Uint8List.fromList(utf8.encode(data)),
        CacheBodyKind.text,
      );
    }
    if (data is Uint8List) return _EncodedBody(data, CacheBodyKind.bytes);
    if (data is List<int>) {
      return _EncodedBody(Uint8List.fromList(data), CacheBodyKind.bytes);
    }
    if (data is Map || data is List) {
      try {
        return _EncodedBody(
          Uint8List.fromList(utf8.encode(jsonEncode(data))),
          CacheBodyKind.json,
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static int _metaBytes(Map<String, List<String>> headers, String key) {
    var bytes = key.length;
    headers.forEach((name, values) {
      bytes += name.length + 2;
      for (final value in values) {
        bytes += value.length + 2;
      }
    });
    return bytes;
  }

  // ── Row mapping, shared by every SQL-backed store ──

  Map<String, Object?> toRow() => {
    'key': key,
    'primary_key': primaryKey,
    'vary_names': varyNames.join(','),
    'vary_signature': varySignature,
    'status': statusCode,
    'headers': jsonEncode(headers),
    'body': body,
    'body_kind': bodyKind.name,
    'stored_at': storedAt.toUtc().millisecondsSinceEpoch,
    'last_used_at': lastUsedAt.toUtc().millisecondsSinceEpoch,
    'date_at': dateHeader?.toUtc().millisecondsSinceEpoch,
    'expires_at': expires?.toUtc().millisecondsSinceEpoch,
    'max_age': maxAgeSeconds,
    'age': ageSeconds,
    'etag': etag,
    'last_modified': lastModified,
    'no_cache': noCache ? 1 : 0,
    'must_revalidate': mustRevalidate ? 1 : 0,
    'swr': staleWhileRevalidateSeconds,
    'sie': staleIfErrorSeconds,
    'hits': hits,
    'size': size,
  };

  static CacheEntry fromRow(Map<String, Object?> row) {
    final varyRaw = (row['vary_names'] as String?) ?? '';
    final bodyRaw = row['body'];
    return CacheEntry(
      key: row['key'] as String,
      primaryKey: row['primary_key'] as String,
      varyNames: varyRaw.isEmpty ? const [] : varyRaw.split(','),
      varySignature: (row['vary_signature'] as String?) ?? '',
      statusCode: (row['status'] as int?) ?? 200,
      headers: _decodeHeaders(row['headers'] as String?),
      body: bodyRaw is Uint8List
          ? bodyRaw
          : Uint8List.fromList(List<int>.from(bodyRaw as List? ?? const [])),
      bodyKind: CacheBodyKind.values.firstWhere(
        (k) => k.name == row['body_kind'],
        orElse: () => CacheBodyKind.json,
      ),
      storedAt: _dateFrom(row['stored_at']) ?? DateTime.now().toUtc(),
      lastUsedAt: _dateFrom(row['last_used_at']) ?? DateTime.now().toUtc(),
      dateHeader: _dateFrom(row['date_at']),
      expires: _dateFrom(row['expires_at']),
      maxAgeSeconds: row['max_age'] as int?,
      ageSeconds: (row['age'] as int?) ?? 0,
      etag: row['etag'] as String?,
      lastModified: row['last_modified'] as String?,
      noCache: (row['no_cache'] as int?) == 1,
      mustRevalidate: (row['must_revalidate'] as int?) == 1,
      staleWhileRevalidateSeconds: row['swr'] as int?,
      staleIfErrorSeconds: row['sie'] as int?,
      hits: (row['hits'] as int?) ?? 0,
    );
  }

  static DateTime? _dateFrom(Object? millis) => millis is int
      ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
      : null;

  static Map<String, List<String>> _decodeHeaders(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (name, values) =>
            MapEntry(name, List<String>.from(values as List<dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }
}

class _EncodedBody {
  const _EncodedBody(this.bytes, this.kind);
  final Uint8List bytes;
  final CacheBodyKind kind;
}

/// Size and count of what is on disk. Runtime counters live in HttpCacheMetrics.
class HttpCacheStoreStats {
  const HttpCacheStoreStats({
    required this.entryCount,
    required this.totalBytes,
    required this.maxBytes,
    this.oldestStoredAt,
  });

  final int entryCount;
  final int totalBytes;
  final int maxBytes;
  final DateTime? oldestStoredAt;
}

/// Storage contract. Two implementations ship: sqflite (persistent) and
/// memory (the default, and what the tests use).
abstract class HttpCacheStore {
  /// Bytes the store will hold before evicting.
  int get maxBytes;

  /// Every entry filed under this primary key — one per Vary combination.
  Future<List<CacheEntry>> candidates(String primaryKey);

  /// Writes the entry, then evicts least-recently-used entries until the cap
  /// is respected. Returns how many were evicted.
  Future<int> put(CacheEntry entry);

  Future<void> touch(CacheEntry entry, DateTime at);

  Future<void> delete(String key);

  /// Drops everything matching a url prefix — for "this screen's data changed".
  Future<int> invalidatePrefix(String urlPrefix);

  Future<void> clear();

  Future<HttpCacheStoreStats> stats();

  Future<void> close();
}

/// In-process store. Survives nothing, needs no plugin, and is what runs in
/// unit tests and on any platform where you do not want a database.
class MemoryHttpCacheStore implements HttpCacheStore {
  MemoryHttpCacheStore({this.maxBytes = 4 * 1024 * 1024});

  @override
  final int maxBytes;

  final Map<String, CacheEntry> _entries = {};

  @override
  Future<List<CacheEntry>> candidates(String primaryKey) async => _entries
      .values
      .where((entry) => entry.primaryKey == primaryKey)
      .toList();

  @override
  Future<int> put(CacheEntry entry) async {
    _entries[entry.key] = entry;
    return _evict();
  }

  @override
  Future<void> touch(CacheEntry entry, DateTime at) async {
    if (_entries.containsKey(entry.key)) {
      _entries[entry.key] = entry.touched(at);
    }
  }

  @override
  Future<void> delete(String key) async => _entries.remove(key);

  @override
  Future<int> invalidatePrefix(String urlPrefix) async {
    final doomed = _entries.values
        .where((entry) => entry.primaryKey.contains(urlPrefix))
        .map((entry) => entry.key)
        .toList();
    for (final key in doomed) {
      _entries.remove(key);
    }
    return doomed.length;
  }

  @override
  Future<void> clear() async => _entries.clear();

  @override
  Future<HttpCacheStoreStats> stats() async {
    DateTime? oldest;
    for (final entry in _entries.values) {
      if (oldest == null || entry.storedAt.isBefore(oldest)) {
        oldest = entry.storedAt;
      }
    }
    return HttpCacheStoreStats(
      entryCount: _entries.length,
      totalBytes: _totalBytes,
      maxBytes: maxBytes,
      oldestStoredAt: oldest,
    );
  }

  @override
  Future<void> close() async => _entries.clear();

  int get _totalBytes =>
      _entries.values.fold(0, (sum, entry) => sum + entry.size);

  int _evict() {
    var evicted = 0;
    while (_totalBytes > maxBytes && _entries.isNotEmpty) {
      final oldest = _entries.values.reduce(
        (a, b) => a.lastUsedAt.isBefore(b.lastUsedAt) ? a : b,
      );
      _entries.remove(oldest.key);
      evicted++;
    }
    return evicted;
  }
}

/// Process-wide counters. The interceptor is built per ApiService() call, so
/// per-instance counters would always read zero.
class HttpCacheMetrics {
  HttpCacheMetrics._();

  static int hits = 0;
  static int misses = 0;
  static int revalidations = 0;
  static int staleServed = 0;
  static int staleOnError = 0;
  static int stores = 0;
  static int evictions = 0;
  static int backgroundRefreshes = 0;

  static void reset() {
    hits = 0;
    misses = 0;
    revalidations = 0;
    staleServed = 0;
    staleOnError = 0;
    stores = 0;
    evictions = 0;
    backgroundRefreshes = 0;
  }
}

/// Everything a settings screen wants to show.
class HttpCacheStats {
  const HttpCacheStats({
    required this.entryCount,
    required this.totalBytes,
    required this.maxBytes,
    required this.hits,
    required this.misses,
    required this.revalidations,
    required this.staleServed,
    required this.evictions,
    this.oldestStoredAt,
  });

  const HttpCacheStats.empty()
    : entryCount = 0,
      totalBytes = 0,
      maxBytes = 0,
      hits = 0,
      misses = 0,
      revalidations = 0,
      staleServed = 0,
      evictions = 0,
      oldestStoredAt = null;

  final int entryCount;
  final int totalBytes;
  final int maxBytes;
  final int hits;
  final int misses;
  final int revalidations;
  final int staleServed;
  final int evictions;
  final DateTime? oldestStoredAt;

  int get lookups => hits + misses;

  double get hitRate => lookups == 0 ? 0 : hits / lookups;

  String get formattedHitRate => '${(hitRate * 100).toStringAsFixed(0)}%';

  String get formattedSize => formatBytes(totalBytes);

  String get formattedMaxSize => formatBytes(maxBytes);

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static HttpCacheStats from(HttpCacheStoreStats store) => HttpCacheStats(
    entryCount: store.entryCount,
    totalBytes: store.totalBytes,
    maxBytes: store.maxBytes,
    hits: HttpCacheMetrics.hits,
    misses: HttpCacheMetrics.misses,
    revalidations: HttpCacheMetrics.revalidations,
    staleServed: HttpCacheMetrics.staleServed,
    evictions: HttpCacheMetrics.evictions,
    oldestStoredAt: store.oldestStoredAt,
  );
}

/// The store the interceptor uses. Static because ApiService — and therefore
/// the interceptor — is constructed per call.
class HttpCache {
  HttpCache._();

  static HttpCacheStore? _store;

  /// Defaults to memory so the interceptor works before bootstrap swaps in
  /// the sqflite store.
  static HttpCacheStore get store => _store ??= MemoryHttpCacheStore();

  static void use(HttpCacheStore store) => _store = store;

  static bool get isInitialised => _store != null;

  static Future<void> clear() => store.clear();

  static Future<HttpCacheStats> stats() async =>
      HttpCacheStats.from(await store.stats());

  /// Drops the cache and the counters — call on sign-out.
  static Future<void> reset() async {
    await store.clear();
    HttpCacheMetrics.reset();
  }
}
