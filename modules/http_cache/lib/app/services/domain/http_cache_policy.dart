import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';

/// Tunables for HttpCacheInterceptor. The size cap lives on the store.
class HttpCacheConfig {
  const HttpCacheConfig({
    this.cacheableMethods = const {'GET'},
    this.cacheableStatusCodes = const {200},
    this.staleWhileRevalidate = const Duration(seconds: 60),
    this.staleIfError = Duration.zero,
    this.defaultMaxAge,
    this.maxStale = const Duration(days: 7),
  });

  /// GET only by default. POST/PUT responses are not safe to replay.
  final Set<String> cacheableMethods;

  /// 203/300/301/404/410 are cacheable per RFC but surprising — opt in explicitly.
  final Set<int> cacheableStatusCodes;

  /// Client-side stale-while-revalidate window when the server sends no directive.
  /// Duration.zero turns the feature off; must-revalidate always wins over it.
  final Duration staleWhileRevalidate;

  /// Client-side stale-if-error window when the server sends no directive.
  final Duration staleIfError;

  /// Freshness to assume when the server sends neither max-age nor Expires.
  /// null means "store only if there is a validator, and always revalidate".
  final Duration? defaultMaxAge;

  /// Past freshness + this, an entry is deleted instead of revalidated.
  final Duration maxStale;
}

/// Parsed Cache-Control. Unknown directives are ignored, not an error.
class CacheControl {
  const CacheControl({
    this.noStore = false,
    this.noCache = false,
    this.mustRevalidate = false,
    this.private = false,
    this.public = false,
    this.immutable = false,
    this.onlyIfCached = false,
    this.maxAge,
    this.staleWhileRevalidate,
    this.staleIfError,
  });

  static const CacheControl empty = CacheControl();

  final bool noStore;
  final bool noCache;
  final bool mustRevalidate;
  final bool private;
  final bool public;
  final bool immutable;
  final bool onlyIfCached;
  final int? maxAge;
  final int? staleWhileRevalidate;
  final int? staleIfError;

  /// Multiple Cache-Control headers are equivalent to one comma-joined header.
  factory CacheControl.parse(Iterable<String>? values) {
    if (values == null || values.isEmpty) return empty;
    var noStore = false;
    var noCache = false;
    var mustRevalidate = false;
    var private = false;
    var public = false;
    var immutable = false;
    var onlyIfCached = false;
    int? maxAge;
    int? swr;
    int? sie;

    for (final directive in values.expand((v) => v.split(','))) {
      final token = directive.trim();
      if (token.isEmpty) continue;
      final eq = token.indexOf('=');
      final name = (eq < 0 ? token : token.substring(0, eq)).toLowerCase();
      final raw = eq < 0 ? null : _unquote(token.substring(eq + 1).trim());
      final seconds = raw == null ? null : int.tryParse(raw);
      switch (name) {
        case 'no-store':
          noStore = true;
        case 'no-cache':
          noCache = true;
        case 'must-revalidate':
        case 'proxy-revalidate':
          mustRevalidate = true;
        case 'private':
          private = true;
        case 'public':
          public = true;
        case 'immutable':
          immutable = true;
        case 'only-if-cached':
          onlyIfCached = true;
        case 'max-age':
          if (seconds != null) maxAge = seconds < 0 ? 0 : seconds;
        case 'stale-while-revalidate':
          if (seconds != null) swr = seconds < 0 ? 0 : seconds;
        case 'stale-if-error':
          if (seconds != null) sie = seconds < 0 ? 0 : seconds;
        // s-maxage is for shared caches; an app is a private cache. Ignored.
      }
    }

    return CacheControl(
      noStore: noStore,
      noCache: noCache,
      mustRevalidate: mustRevalidate,
      private: private,
      public: public,
      immutable: immutable,
      onlyIfCached: onlyIfCached,
      maxAge: maxAge,
      staleWhileRevalidate: swr,
      staleIfError: sie,
    );
  }

  static String _unquote(String v) =>
      (v.length > 1 && v.startsWith('"') && v.endsWith('"'))
      ? v.substring(1, v.length - 1)
      : v;
}

/// Pure cache-protocol decisions. No I/O, so every rule is unit-testable.
class HttpCachePolicy {
  HttpCachePolicy._();

  /// Options(extra: {'noHttpCache': true}) — skip read and write for one request.
  static const String noCacheExtra = 'noHttpCache';

  /// Options(extra: {'cacheIdentity': userId}) — explicit cache namespace.
  static const String identityExtra = 'cacheIdentity';

  /// response.extra flags the caller can read.
  static const String fromCacheExtra = 'fromCache';
  static const String staleExtra = 'servedStale';
  static const String revalidatedExtra = 'revalidated';
  static const String staleOnErrorExtra = 'staleOnError';
  static const String cacheAgeExtra = 'cacheAge';

  /// Internal: primary key carried from onRequest to onResponse.
  static const String primaryKeyExtra = '_httpCachePrimaryKey';

  static const Set<String> _hopByHop = {
    'connection',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
  };

  static CacheControl requestCacheControl(RequestOptions options) =>
      CacheControl.parse(headerValues(options.headers, 'cache-control'));

  static CacheControl responseCacheControl(Headers headers) =>
      CacheControl.parse(headers['cache-control']);

  /// Case-insensitive read of a Dio request header, which may hold a List.
  static List<String> headerValues(Map<String, dynamic> headers, String name) {
    final target = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() != target) continue;
      final value = entry.value;
      if (value == null) return const [];
      if (value is Iterable) {
        return value.map((v) => v.toString()).toList();
      }
      return [value.toString()];
    }
    return const [];
  }

  static String? headerValue(Map<String, dynamic> headers, String name) {
    final values = headerValues(headers, name);
    return values.isEmpty ? null : values.join(', ');
  }

  /// Primary key: method + canonical url + auth identity.
  ///
  /// The identity is what stops one signed-in user being served another user's
  /// cached response after an account switch on the same device.
  static String primaryKeyFor(RequestOptions options) =>
      '${options.method.toUpperCase()} ${canonicalUrl(options.uri)} '
      '@${identityOf(options)}';

  /// Query parameters sorted by name so ?a=1&b=2 and ?b=2&a=1 share one entry.
  static String canonicalUrl(Uri uri) {
    final params = uri.queryParametersAll;
    final port = uri.hasPort ? ':${uri.port}' : '';
    final stripped = '${uri.scheme}://${uri.host}$port${uri.path}';
    if (params.isEmpty) return stripped;
    final names = params.keys.toList()..sort();
    final parts = <String>[];
    for (final name in names) {
      for (final value in params[name]!) {
        parts.add('${Uri.encodeQueryComponent(name)}='
            '${Uri.encodeQueryComponent(value)}');
      }
    }
    return '$stripped?${parts.join('&')}';
  }

  /// 'anon', the caller-supplied identity, or a fingerprint of the credential.
  static String identityOf(RequestOptions options) {
    final explicit = options.extra[identityExtra];
    if (explicit != null && explicit.toString().isNotEmpty) {
      return 'id:${explicit.toString()}';
    }
    final credential =
        headerValue(options.headers, 'authorization') ??
        headerValue(options.headers, 'cookie') ??
        headerValue(options.headers, 'x-api-key');
    if (credential == null || credential.isEmpty) return 'anon';
    return 'tok:${fingerprint(credential)}';
  }

  /// Non-cryptographic 64-bit fingerprint (two FNV-1a passes). It namespaces
  /// entries per credential; it is not a secret and never leaves the device.
  static String fingerprint(String input) =>
      '${_fnv1a(input).toRadixString(16).padLeft(8, '0')}'
      '${_fnv1a('$input#2').toRadixString(16).padLeft(8, '0')}';

  static int _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Vary header names, lowercased and sorted. null means `Vary: *` — never reusable.
  static List<String>? varyNamesOf(Headers headers) {
    final raw = headers['vary'];
    if (raw == null || raw.isEmpty) return const [];
    final names = <String>{};
    for (final name in raw.expand((v) => v.split(','))) {
      final clean = name.trim().toLowerCase();
      if (clean.isEmpty) continue;
      if (clean == '*') return null;
      if (_hopByHop.contains(clean)) continue;
      names.add(clean);
    }
    return names.toList()..sort();
  }

  /// The selecting request headers, canonicalised. Ignoring this serves one
  /// user's (or one language's) response to another.
  static String varySignature(List<String> names, RequestOptions options) {
    if (names.isEmpty) return '';
    return names
        .map((n) => '$n=${headerValue(options.headers, n) ?? ''}')
        .join(' ');
  }

  /// Picks the stored entry whose Vary-selected headers match this request.
  static T? selectMatch<T extends CacheEntryMatch>(
    Iterable<T> candidates,
    RequestOptions options,
  ) {
    for (final candidate in candidates) {
      if (varySignature(candidate.varyNames, options) ==
          candidate.varySignature) {
        return candidate;
      }
    }
    return null;
  }

  /// Storage key for a primary key + Vary signature pair.
  static String storageKey(String primaryKey, String varySignature) =>
      varySignature.isEmpty
      ? primaryKey
      : '$primaryKey ||${fingerprint(varySignature)}';

  /// Response headers worth keeping. Hop-by-hop headers describe one connection.
  static Map<String, List<String>> storableHeaders(Headers headers) {
    final out = <String, List<String>>{};
    headers.forEach((name, values) {
      if (_hopByHop.contains(name.toLowerCase())) return;
      out[name.toLowerCase()] = List<String>.from(values);
    });
    return out;
  }

  /// Parses an HTTP-date header; null when absent or unparseable.
  static DateTime? httpDate(List<String>? values) {
    if (values == null || values.isEmpty) return null;
    try {
      return HttpDate.parse(values.first);
    } catch (_) {
      return DateTime.tryParse(values.first)?.toUtc();
    }
  }
}

/// The subset of a stored entry the Vary match needs, so the policy stays
/// independent of the storage layer.
abstract class CacheEntryMatch {
  List<String> get varyNames;
  String get varySignature;
}
