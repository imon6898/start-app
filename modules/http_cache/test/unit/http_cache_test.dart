import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/app/services/domain/http_cache_interceptor.dart';
import 'package:flutter_starter/app/services/domain/http_cache_policy.dart';
import 'package:flutter_starter/app/services/domain/http_cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns a canned ResponseBody per call and records what was sent.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  final Future<ResponseBody> Function(RequestOptions options, int callIndex)
  responder;
  final List<RequestOptions> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final index = calls.length;
    calls.add(options);
    return responder(options, index);
  }

  @override
  void close({bool force = false}) {}
}

Future<ResponseBody> _json(
  int statusCode, {
  String body = '{"v":1}',
  Map<String, List<String>> headers = const {},
}) async => ResponseBody.fromString(
  body,
  statusCode,
  headers: {
    'content-type': const ['application/json'],
    ...headers,
  },
);

Dio _dioWith(
  _FakeAdapter adapter,
  HttpCacheStore store, {
  HttpCacheConfig config = const HttpCacheConfig(
    staleWhileRevalidate: Duration.zero,
  ),
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(
    HttpCacheInterceptor(dio, store: store, config: config),
  );
  return dio;
}

RequestOptions _request({
  String path = '/items',
  Map<String, dynamic> headers = const {},
  Map<String, dynamic> extra = const {},
}) => RequestOptions(
  path: path,
  baseUrl: 'https://api.test',
  method: 'GET',
  headers: {...headers},
  extra: {...extra},
);

CacheEntry _entry({
  int? maxAge,
  DateTime? storedAt,
  DateTime? dateHeader,
  DateTime? expires,
  int ageSeconds = 0,
  String? etag,
  String? lastModified,
  bool noCache = false,
  bool mustRevalidate = false,
  int? swr,
  int? sie,
  List<String> varyNames = const [],
  String varySignature = '',
  String body = '{"v":1}',
  String primaryKey = 'GET https://api.test/items @anon',
}) {
  final at = storedAt ?? DateTime.now().toUtc();
  return CacheEntry(
    key: HttpCachePolicy.storageKey(primaryKey, varySignature),
    primaryKey: primaryKey,
    varyNames: varyNames,
    varySignature: varySignature,
    statusCode: 200,
    headers: const {
      'content-type': ['application/json'],
    },
    body: Uint8List.fromList(utf8.encode(body)),
    bodyKind: CacheBodyKind.json,
    storedAt: at,
    lastUsedAt: at,
    dateHeader: dateHeader,
    expires: expires,
    maxAgeSeconds: maxAge,
    ageSeconds: ageSeconds,
    etag: etag,
    lastModified: lastModified,
    noCache: noCache,
    mustRevalidate: mustRevalidate,
    staleWhileRevalidateSeconds: swr,
    staleIfErrorSeconds: sie,
  );
}

void main() {
  setUp(() {
    HttpCacheMetrics.reset();
    HttpCacheInterceptor.resetShared();
  });

  group('Cache-Control parsing', () {
    test('reads the directives that decide storability', () {
      final cc = CacheControl.parse(const [
        'private, no-cache, must-revalidate, max-age=300',
      ]);
      expect(cc.private, isTrue);
      expect(cc.noCache, isTrue);
      expect(cc.mustRevalidate, isTrue);
      expect(cc.maxAge, 300);
      expect(cc.noStore, isFalse);
    });

    test('no-store is distinct from no-cache', () {
      expect(CacheControl.parse(const ['no-store']).noStore, isTrue);
      expect(CacheControl.parse(const ['no-store']).noCache, isFalse);
      expect(CacheControl.parse(const ['no-cache']).noStore, isFalse);
    });

    test('reads stale-while-revalidate and stale-if-error', () {
      final cc = CacheControl.parse(const [
        'max-age=10, stale-while-revalidate=60, stale-if-error=120',
      ]);
      expect(cc.staleWhileRevalidate, 60);
      expect(cc.staleIfError, 120);
    });

    test('accepts quoted values and odd spacing', () {
      final cc = CacheControl.parse(const ['  MAX-AGE="42" ,  Public ']);
      expect(cc.maxAge, 42);
      expect(cc.public, isTrue);
    });

    test('multiple header lines behave as one comma-joined header', () {
      final cc = CacheControl.parse(const ['max-age=5', 'must-revalidate']);
      expect(cc.maxAge, 5);
      expect(cc.mustRevalidate, isTrue);
    });

    test('unknown directives and s-maxage are ignored, not fatal', () {
      final cc = CacheControl.parse(const ['s-maxage=600, surrogate-key=abc']);
      expect(cc.maxAge, isNull);
      expect(cc.noStore, isFalse);
    });

    test('a negative max-age is clamped to zero', () {
      expect(CacheControl.parse(const ['max-age=-3']).maxAge, 0);
    });

    test('an empty or absent header parses to empty', () {
      expect(CacheControl.parse(null).maxAge, isNull);
      expect(CacheControl.parse(const ['']).noStore, isFalse);
    });
  });

  group('cache key', () {
    test('query parameter order does not create a second entry', () {
      final a = HttpCachePolicy.canonicalUrl(
        Uri.parse('https://api.test/items?b=2&a=1'),
      );
      final b = HttpCachePolicy.canonicalUrl(
        Uri.parse('https://api.test/items?a=1&b=2'),
      );
      expect(a, b);
    });

    test('a different path is a different key', () {
      expect(
        HttpCachePolicy.primaryKeyFor(_request(path: '/items')),
        isNot(HttpCachePolicy.primaryKeyFor(_request(path: '/other'))),
      );
    });

    test('two users never share a key', () {
      final first = HttpCachePolicy.primaryKeyFor(
        _request(headers: {'Authorization': 'Bearer aaa'}),
      );
      final second = HttpCachePolicy.primaryKeyFor(
        _request(headers: {'Authorization': 'Bearer bbb'}),
      );
      expect(first, isNot(second));
    });

    test('an anonymous request is namespaced as anon', () {
      expect(HttpCachePolicy.identityOf(_request()), 'anon');
    });

    test('the raw credential never appears in the key', () {
      final key = HttpCachePolicy.primaryKeyFor(
        _request(headers: {'Authorization': 'Bearer super-secret'}),
      );
      expect(key.contains('super-secret'), isFalse);
      expect(key.contains('tok:'), isTrue);
    });

    test('an explicit cacheIdentity wins over the header', () {
      final key = HttpCachePolicy.identityOf(
        _request(
          headers: {'Authorization': 'Bearer aaa'},
          extra: {HttpCachePolicy.identityExtra: 'user-7'},
        ),
      );
      expect(key, 'id:user-7');
    });

    test('the fingerprint is stable and 16 hex chars', () {
      final once = HttpCachePolicy.fingerprint('Bearer aaa');
      expect(once, HttpCachePolicy.fingerprint('Bearer aaa'));
      expect(once, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(once, isNot(HttpCachePolicy.fingerprint('Bearer bbb')));
    });
  });

  group('Vary', () {
    Headers headersWith(String vary) =>
        Headers.fromMap({'vary': [vary]});

    test('names are lowercased, sorted and de-duplicated', () {
      expect(
        HttpCachePolicy.varyNamesOf(
          headersWith('Accept-Language, ACCEPT, accept-language'),
        ),
        ['accept', 'accept-language'],
      );
    });

    test('Vary: * means never reusable', () {
      expect(HttpCachePolicy.varyNamesOf(headersWith('*')), isNull);
    });

    test('hop-by-hop names are dropped', () {
      expect(
        HttpCachePolicy.varyNamesOf(headersWith('accept, connection')),
        ['accept'],
      );
    });

    test('no Vary header at all is an empty selector list', () {
      expect(HttpCachePolicy.varyNamesOf(Headers()), isEmpty);
    });

    test('the signature reads the request headers case-insensitively', () {
      final signature = HttpCachePolicy.varySignature(
        const ['accept-language'],
        _request(headers: {'ACCEPT-LANGUAGE': 'fr'}),
      );
      expect(signature, 'accept-language=fr');
    });

    test('a missing selecting header is recorded as empty, not skipped', () {
      expect(
        HttpCachePolicy.varySignature(const ['accept-language'], _request()),
        'accept-language=',
      );
    });

    test('selectMatch picks the entry whose selectors match', () {
      final en = _entry(
        varyNames: const ['accept-language'],
        varySignature: 'accept-language=en',
        body: '{"lang":"en"}',
      );
      final fr = _entry(
        varyNames: const ['accept-language'],
        varySignature: 'accept-language=fr',
        body: '{"lang":"fr"}',
      );
      final match = HttpCachePolicy.selectMatch(
        [en, fr],
        _request(headers: {'accept-language': 'fr'}),
      );
      expect(match?.varySignature, 'accept-language=fr');
    });

    test('selectMatch returns null when no stored variant matches', () {
      final en = _entry(
        varyNames: const ['accept-language'],
        varySignature: 'accept-language=en',
      );
      expect(
        HttpCachePolicy.selectMatch(
          [en],
          _request(headers: {'accept-language': 'de'}),
        ),
        isNull,
      );
    });
  });

  group('freshness', () {
    final now = DateTime.utc(2026, 1, 1, 12);

    test('max-age is the freshness lifetime', () {
      expect(_entry(maxAge: 60).freshnessLifetime, const Duration(seconds: 60));
    });

    test('Expires minus Date is used when there is no max-age', () {
      final entry = _entry(
        dateHeader: now,
        expires: now.add(const Duration(minutes: 5)),
        storedAt: now,
      );
      expect(entry.freshnessLifetime, const Duration(minutes: 5));
    });

    test('no max-age and no Expires means unknown, not forever', () {
      expect(_entry().freshnessLifetime, isNull);
      expect(_entry().isFreshAt(now), isFalse);
    });

    test('age counts residence time', () {
      final entry = _entry(
        maxAge: 60,
        storedAt: now.subtract(const Duration(seconds: 30)),
      );
      expect(entry.ageAt(now), const Duration(seconds: 30));
      expect(entry.isFreshAt(now), isTrue);
    });

    test('an Age header from an upstream proxy counts too', () {
      final entry = _entry(maxAge: 60, storedAt: now, ageSeconds: 70);
      expect(entry.ageAt(now), const Duration(seconds: 70));
      expect(entry.isFreshAt(now), isFalse);
    });

    test('a Date in the past ages the entry on arrival', () {
      final entry = _entry(
        maxAge: 60,
        storedAt: now,
        dateHeader: now.subtract(const Duration(seconds: 90)),
      );
      expect(entry.ageAt(now), const Duration(seconds: 90));
      expect(entry.isFreshAt(now), isFalse);
    });

    test('no-cache is never fresh, whatever max-age says', () {
      expect(_entry(maxAge: 600, noCache: true).isFreshAt(now), isFalse);
    });

    test('stale-while-revalidate uses the server window when present', () {
      final entry = _entry(
        maxAge: 10,
        swr: 120,
        storedAt: now.subtract(const Duration(seconds: 60)),
      );
      expect(entry.isFreshAt(now), isFalse);
      expect(entry.canServeStaleAt(now, Duration.zero), isTrue);
    });

    test('the client window applies only when the server sent none', () {
      final entry = _entry(
        maxAge: 10,
        storedAt: now.subtract(const Duration(seconds: 60)),
      );
      expect(
        entry.canServeStaleAt(now, const Duration(seconds: 120)),
        isTrue,
      );
      expect(entry.canServeStaleAt(now, Duration.zero), isFalse);
    });

    test('must-revalidate forbids serving stale at all', () {
      final entry = _entry(
        maxAge: 10,
        swr: 600,
        mustRevalidate: true,
        storedAt: now.subtract(const Duration(seconds: 60)),
      );
      expect(entry.canServeStaleAt(now, const Duration(days: 1)), isFalse);
      expect(entry.canServeOnErrorAt(now, const Duration(days: 1)), isFalse);
    });

    test('stale-if-error opens a separate window', () {
      final entry = _entry(
        maxAge: 10,
        sie: 300,
        storedAt: now.subtract(const Duration(seconds: 120)),
      );
      expect(entry.canServeStaleAt(now, Duration.zero), isFalse);
      expect(entry.canServeOnErrorAt(now, Duration.zero), isTrue);
    });

    test('past freshness + maxStale the entry is dead', () {
      final entry = _entry(
        maxAge: 10,
        storedAt: now.subtract(const Duration(days: 30)),
      );
      expect(entry.isExpiredBeyond(now, const Duration(days: 7)), isTrue);
      expect(entry.isExpiredBeyond(now, const Duration(days: 60)), isFalse);
    });
  });

  group('body round-trip', () {
    test('a JSON body is rebuilt as a new object each read', () {
      final entry = _entry(body: '{"v":1}');
      final first = entry.decodeBody() as Map<String, dynamic>;
      first['v'] = 99;
      final second = entry.decodeBody() as Map<String, dynamic>;
      expect(second['v'], 1);
    });

    test('the served response carries the cached status and a HIT header', () {
      final response = _entry(maxAge: 60).toResponse(_request());
      expect(response.statusCode, 200);
      expect(response.headers['x-cache']?.first, 'HIT');
    });
  });

  group('store', () {
    test('candidates are filed under the primary key', () async {
      final store = MemoryHttpCacheStore();
      await store.put(_entry(maxAge: 60));
      expect((await store.candidates('GET https://api.test/items @anon')).length, 1);
      expect(await store.candidates('GET https://api.test/other @anon'), isEmpty);
    });

    test('two Vary variants coexist under one primary key', () async {
      final store = MemoryHttpCacheStore();
      await store.put(
        _entry(
          maxAge: 60,
          varyNames: const ['accept-language'],
          varySignature: 'accept-language=en',
        ),
      );
      await store.put(
        _entry(
          maxAge: 60,
          varyNames: const ['accept-language'],
          varySignature: 'accept-language=fr',
        ),
      );
      expect((await store.candidates('GET https://api.test/items @anon')).length, 2);
    });

    test('the LRU victim is the least recently used entry', () async {
      final store = MemoryHttpCacheStore(maxBytes: 600);
      final old = _entry(
        maxAge: 60,
        primaryKey: 'GET https://api.test/a @anon',
        body: '{"pad":"${'x' * 200}"}',
        storedAt: DateTime.utc(2026, 1, 1),
      );
      final fresh = _entry(
        maxAge: 60,
        primaryKey: 'GET https://api.test/b @anon',
        body: '{"pad":"${'y' * 200}"}',
        storedAt: DateTime.utc(2026, 1, 2),
      );
      await store.put(old);
      await store.put(fresh);
      final evicted = await store.put(
        _entry(
          maxAge: 60,
          primaryKey: 'GET https://api.test/c @anon',
          body: '{"pad":"${'z' * 200}"}',
          storedAt: DateTime.utc(2026, 1, 3),
        ),
      );
      expect(evicted, greaterThan(0));
      expect(await store.candidates('GET https://api.test/a @anon'), isEmpty);
      expect(await store.candidates('GET https://api.test/c @anon'), isNotEmpty);
    });

    test('clear empties the store and stats report it', () async {
      final store = MemoryHttpCacheStore();
      await store.put(_entry(maxAge: 60));
      expect((await store.stats()).entryCount, 1);
      await store.clear();
      expect((await store.stats()).entryCount, 0);
    });

    test('invalidatePrefix drops matching urls only', () async {
      final store = MemoryHttpCacheStore();
      await store.put(
        _entry(maxAge: 60, primaryKey: 'GET https://api.test/orders @anon'),
      );
      await store.put(
        _entry(maxAge: 60, primaryKey: 'GET https://api.test/profile @anon'),
      );
      expect(await store.invalidatePrefix('/orders'), 1);
      expect(await store.candidates('GET https://api.test/profile @anon'), isNotEmpty);
    });
  });

  group('interceptor', () {
    test('a fresh entry is served without touching the network', () async {
      final adapter = _FakeAdapter(
        (options, index) => _json(
          200,
          body: '{"v":$index}',
          headers: const {
            'cache-control': ['max-age=60'],
          },
        ),
      );
      final dio = _dioWith(adapter, MemoryHttpCacheStore());

      final first = await dio.get<dynamic>('/items');
      final second = await dio.get<dynamic>('/items');

      expect(adapter.calls.length, 1);
      expect(second.data, first.data);
      expect(second.extra[HttpCachePolicy.fromCacheExtra], isTrue);
      expect(HttpCacheMetrics.hits, 1);
      expect(HttpCacheMetrics.misses, 1);
    });

    test('a no-store response is never written', () async {
      final adapter = _FakeAdapter(
        (options, index) => _json(
          200,
          headers: const {
            'cache-control': ['no-store'],
          },
        ),
      );
      final store = MemoryHttpCacheStore();
      final dio = _dioWith(adapter, store);

      await dio.get<dynamic>('/items');
      await dio.get<dynamic>('/items');

      expect(adapter.calls.length, 2);
      expect((await store.stats()).entryCount, 0);
    });

    test('a POST is not cached', () async {
      final adapter = _FakeAdapter(
        (options, index) => _json(
          200,
          headers: const {
            'cache-control': ['max-age=60'],
          },
        ),
      );
      final store = MemoryHttpCacheStore();
      final dio = _dioWith(adapter, store);

      await dio.post<dynamic>('/items', data: const {'a': 1});
      await dio.post<dynamic>('/items', data: const {'a': 1});

      expect(adapter.calls.length, 2);
      expect((await store.stats()).entryCount, 0);
    });

    test('noHttpCache bypasses read and write', () async {
      final adapter = _FakeAdapter(
        (options, index) => _json(
          200,
          headers: const {
            'cache-control': ['max-age=60'],
          },
        ),
      );
      final store = MemoryHttpCacheStore();
      final dio = _dioWith(adapter, store);

      await dio.get<dynamic>(
        '/items',
        options: Options(extra: const {HttpCachePolicy.noCacheExtra: true}),
      );
      expect((await store.stats()).entryCount, 0);
    });

    test('a response with no freshness and no validator is not stored', () async {
      final adapter = _FakeAdapter((options, index) => _json(200));
      final store = MemoryHttpCacheStore();
      final dio = _dioWith(adapter, store);

      await dio.get<dynamic>('/items');
      expect((await store.stats()).entryCount, 0);
    });

    test('Vary is respected: another language is a miss, not a wrong hit',
        () async {
      final adapter = _FakeAdapter((options, index) async {
        final language = options.headers['accept-language'];
        return _json(
          200,
          body: '{"lang":"$language"}',
          headers: const {
            'cache-control': ['max-age=60'],
            'vary': ['Accept-Language'],
          },
        );
      });
      final dio = _dioWith(adapter, MemoryHttpCacheStore());

      final en = await dio.get<dynamic>(
        '/items',
        options: Options(headers: const {'accept-language': 'en'}),
      );
      final fr = await dio.get<dynamic>(
        '/items',
        options: Options(headers: const {'accept-language': 'fr'}),
      );
      final enAgain = await dio.get<dynamic>(
        '/items',
        options: Options(headers: const {'accept-language': 'en'}),
      );

      expect(adapter.calls.length, 2);
      expect(en.data, const {'lang': 'en'});
      expect(fr.data, const {'lang': 'fr'});
      expect(enAgain.data, const {'lang': 'en'});
      expect(enAgain.extra[HttpCachePolicy.fromCacheExtra], isTrue);
    });

    test('Vary: * is never reused', () async {
      final adapter = _FakeAdapter(
        (options, index) => _json(
          200,
          headers: const {
            'cache-control': ['max-age=60'],
            'vary': ['*'],
          },
        ),
      );
      final store = MemoryHttpCacheStore();
      final dio = _dioWith(adapter, store);

      await dio.get<dynamic>('/items');
      await dio.get<dynamic>('/items');

      expect(adapter.calls.length, 2);
      expect((await store.stats()).entryCount, 0);
    });

    test('one user never receives another user\'s cached body', () async {
      final adapter = _FakeAdapter((options, index) async {
        final auth = options.headers['Authorization'];
        return _json(
          200,
          body: '{"who":"$auth"}',
          headers: const {
            'cache-control': ['private, max-age=60'],
          },
        );
      });
      final dio = _dioWith(adapter, MemoryHttpCacheStore());

      final first = await dio.get<dynamic>(
        '/me',
        options: Options(headers: const {'Authorization': 'Bearer aaa'}),
      );
      final second = await dio.get<dynamic>(
        '/me',
        options: Options(headers: const {'Authorization': 'Bearer bbb'}),
      );

      expect(adapter.calls.length, 2);
      expect(first.data, const {'who': 'Bearer aaa'});
      expect(second.data, const {'who': 'Bearer bbb'});
    });

    test('304 sends If-None-Match and serves the cached body as success',
        () async {
      final adapter = _FakeAdapter((options, index) async {
        if (index == 0) {
          return _json(
            200,
            body: '{"v":1}',
            headers: const {
              'cache-control': ['max-age=0'],
              'etag': ['"abc"'],
            },
          );
        }
        return _json(304, body: '');
      });
      final dio = _dioWith(adapter, MemoryHttpCacheStore());

      final first = await dio.get<dynamic>('/items');
      final second = await dio.get<dynamic>('/items');

      expect(adapter.calls.length, 2);
      expect(adapter.calls[1].headers['If-None-Match'], '"abc"');
      expect(second.statusCode, 200);
      expect(second.data, first.data);
      expect(second.extra[HttpCachePolicy.revalidatedExtra], isTrue);
      expect(HttpCacheMetrics.revalidations, 1);
    });

    test('Last-Modified produces an If-Modified-Since request', () async {
      const modified = 'Wed, 21 Oct 2015 07:28:00 GMT';
      final adapter = _FakeAdapter((options, index) async {
        if (index == 0) {
          return _json(
            200,
            headers: const {
              'cache-control': ['max-age=0'],
              'last-modified': [modified],
            },
          );
        }
        return _json(304, body: '');
      });
      final dio = _dioWith(adapter, MemoryHttpCacheStore());

      await dio.get<dynamic>('/items');
      await dio.get<dynamic>('/items');

      expect(adapter.calls[1].headers['If-Modified-Since'], modified);
    });

    test('a 304 refreshes freshness, so the next read is a pure cache hit',
        () async {
      final adapter = _FakeAdapter((options, index) async {
        if (index == 0) {
          return _json(
            200,
            headers: const {
              'cache-control': ['max-age=0'],
              'etag': ['"abc"'],
            },
          );
        }
        return _json(
          304,
          body: '',
          headers: const {
            'cache-control': ['max-age=300'],
          },
        );
      });
      final dio = _dioWith(adapter, MemoryHttpCacheStore());

      await dio.get<dynamic>('/items');
      await dio.get<dynamic>('/items');
      final third = await dio.get<dynamic>('/items');

      expect(adapter.calls.length, 2);
      expect(third.extra[HttpCachePolicy.fromCacheExtra], isTrue);
    });

    test('stale-while-revalidate answers instantly and refreshes once',
        () async {
      final adapter = _FakeAdapter(
        (options, index) => _json(
          200,
          body: '{"v":$index}',
          headers: const {
            'cache-control': ['max-age=0, stale-while-revalidate=120'],
            'etag': ['"v"'],
          },
        ),
      );
      final dio = _dioWith(
        adapter,
        MemoryHttpCacheStore(),
        config: const HttpCacheConfig(),
      );

      await dio.get<dynamic>('/items');
      final stale = await dio.get<dynamic>('/items');

      expect(stale.data, const {'v': 0});
      expect(stale.extra[HttpCachePolicy.staleExtra], isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(adapter.calls.length, 2);
      expect(HttpCacheMetrics.backgroundRefreshes, 1);
    });

    test('stale-if-error serves the cached body when the network dies',
        () async {
      final adapter = _FakeAdapter((options, index) async {
        if (index == 0) {
          return _json(
            200,
            body: '{"v":1}',
            headers: const {
              'cache-control': ['max-age=0, stale-if-error=300'],
              'etag': ['"abc"'],
            },
          );
        }
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        );
      });
      final dio = _dioWith(adapter, MemoryHttpCacheStore());

      await dio.get<dynamic>('/items');
      final offline = await dio.get<dynamic>('/items');

      expect(offline.data, const {'v': 1});
      expect(offline.extra[HttpCachePolicy.staleOnErrorExtra], isTrue);
      expect(HttpCacheMetrics.staleOnError, 1);
    });

    test('without stale-if-error a network failure still fails', () async {
      final adapter = _FakeAdapter((options, index) async {
        if (index == 0) {
          return _json(
            200,
            headers: const {
              'cache-control': ['max-age=0'],
              'etag': ['"abc"'],
            },
          );
        }
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        );
      });
      final dio = _dioWith(adapter, MemoryHttpCacheStore());

      await dio.get<dynamic>('/items');
      await expectLater(
        dio.get<dynamic>('/items'),
        throwsA(isA<DioException>()),
      );
    });

    test('a request no-cache header forces revalidation', () async {
      final adapter = _FakeAdapter(
        (options, index) => _json(
          200,
          body: '{"v":$index}',
          headers: const {
            'cache-control': ['max-age=600'],
            'etag': ['"abc"'],
          },
        ),
      );
      final dio = _dioWith(adapter, MemoryHttpCacheStore());

      await dio.get<dynamic>('/items');
      final forced = await dio.get<dynamic>(
        '/items',
        options: Options(headers: const {'cache-control': 'no-cache'}),
      );

      expect(adapter.calls.length, 2);
      expect(forced.data, const {'v': 1});
    });

    test('only-if-cached fails with 504 instead of hitting the network',
        () async {
      final adapter = _FakeAdapter((options, index) => _json(200));
      final dio = _dioWith(adapter, MemoryHttpCacheStore());

      await expectLater(
        dio.get<dynamic>(
          '/items',
          options: Options(headers: const {'cache-control': 'only-if-cached'}),
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            504,
          ),
        ),
      );
      expect(adapter.calls, isEmpty);
    });

    test('an entry past maxStale is deleted rather than revalidated', () async {
      final store = MemoryHttpCacheStore();
      await store.put(
        _entry(
          maxAge: 10,
          etag: '"old"',
          storedAt: DateTime.now().toUtc().subtract(const Duration(days: 40)),
        ),
      );
      final adapter = _FakeAdapter(
        (options, index) => _json(
          200,
          body: '{"v":9}',
          headers: const {
            'cache-control': ['max-age=60'],
          },
        ),
      );
      final dio = _dioWith(adapter, store);

      final response = await dio.get<dynamic>('/items');

      expect(adapter.calls.length, 1);
      expect(adapter.calls.first.headers.containsKey('If-None-Match'), isFalse);
      expect(response.data, const {'v': 9});
    });

    test('stats report what the store holds plus the counters', () async {
      final store = MemoryHttpCacheStore(maxBytes: 1024 * 1024);
      HttpCache.use(store);
      final adapter = _FakeAdapter(
        (options, index) => _json(
          200,
          headers: const {
            'cache-control': ['max-age=60'],
          },
        ),
      );
      final dio = _dioWith(adapter, store);

      await dio.get<dynamic>('/items');
      await dio.get<dynamic>('/items');

      final stats = await HttpCache.stats();
      expect(stats.entryCount, 1);
      expect(stats.hits, 1);
      expect(stats.misses, 1);
      expect(stats.formattedHitRate, '50%');
      expect(stats.totalBytes, greaterThan(0));

      await HttpCache.reset();
      expect((await HttpCache.stats()).entryCount, 0);
      expect(HttpCacheMetrics.hits, 0);
    });
  });
}
