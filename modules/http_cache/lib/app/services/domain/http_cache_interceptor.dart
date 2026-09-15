import 'package:dio/dio.dart';

import 'dev_tools.dart';
import 'http_cache_policy.dart';
import 'http_cache_store.dart';

/// Dio interceptor that caches GET responses the way HTTP says to: ETag /
/// Last-Modified revalidation, Cache-Control freshness, Vary-aware keys, and
/// stale-while-revalidate.
///
/// Register it BEFORE ApiResilienceInterceptor — see the module README.
class HttpCacheInterceptor extends Interceptor {
  HttpCacheInterceptor(
    this._dio, {
    this.config = const HttpCacheConfig(),
    this.store,
  });

  /// The entry being revalidated, carried from onRequest to onResponse/onError.
  static const String entryExtra = '_httpCacheEntry';

  /// Marks the silent refresh so it does not read the cache it is refreshing.
  static const String backgroundExtra = '_httpCacheBackground';

  /// Entry keys with a background refresh already on the wire.
  static final Set<String> _refreshing = {};

  /// Clears shared in-flight state — call between tests.
  static void resetShared() => _refreshing.clear();

  final Dio _dio;
  final HttpCacheConfig config;

  /// Overrides the process-wide store — tests pass a memory store here.
  final HttpCacheStore? store;

  HttpCacheStore get _store => store ?? HttpCache.store;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isCacheable(options)) return handler.next(options);

    final requestCc = HttpCachePolicy.requestCacheControl(options);
    if (requestCc.noStore) return handler.next(options);

    final primaryKey = HttpCachePolicy.primaryKeyFor(options);
    options.extra[HttpCachePolicy.primaryKeyExtra] = primaryKey;

    if (options.extra[backgroundExtra] == true) return handler.next(options);

    CacheEntry? entry;
    try {
      entry = HttpCachePolicy.selectMatch(
        await _store.candidates(primaryKey),
        options,
      );
    } catch (e) {
      devPrint('HttpCache: read failed, going to the network: $e');
    }

    final now = DateTime.now();

    if (entry != null && entry.isExpiredBeyond(now, config.maxStale)) {
      await _safeDelete(entry.key);
      entry = null;
    }

    if (entry == null) {
      HttpCacheMetrics.misses++;
      if (requestCc.onlyIfCached) {
        return handler.reject(_notInCache(options));
      }
      return handler.next(options);
    }

    final age = entry.ageAt(now).inSeconds;
    final mustGoOut = requestCc.noCache || requestCc.maxAge == 0;

    if (!mustGoOut && entry.isFreshAt(now)) {
      HttpCacheMetrics.hits++;
      await _safeTouch(entry, now);
      return handler.resolve(
        entry.toResponse(
          options,
          extra: {
            HttpCachePolicy.fromCacheExtra: true,
            HttpCachePolicy.cacheAgeExtra: age,
          },
        ),
      );
    }

    // only-if-cached forbids the network, so stale beats an error here.
    if (requestCc.onlyIfCached) {
      HttpCacheMetrics.hits++;
      await _safeTouch(entry, now);
      return handler.resolve(
        entry.toResponse(
          options,
          extra: {
            HttpCachePolicy.fromCacheExtra: true,
            HttpCachePolicy.staleExtra: true,
            HttpCachePolicy.cacheAgeExtra: age,
          },
        ),
      );
    }

    // Stale-while-revalidate: answer instantly, refresh behind the user.
    if (!mustGoOut && entry.canServeStaleAt(now, config.staleWhileRevalidate)) {
      HttpCacheMetrics.hits++;
      HttpCacheMetrics.staleServed++;
      await _safeTouch(entry, now);
      _refreshInBackground(options, entry);
      return handler.resolve(
        entry.toResponse(
          options,
          extra: {
            HttpCachePolicy.fromCacheExtra: true,
            HttpCachePolicy.staleExtra: true,
            HttpCachePolicy.cacheAgeExtra: age,
          },
        ),
      );
    }

    // Conditional request: a 304 costs a round trip and no body.
    options.extra[entryExtra] = entry;
    _attachValidators(options, entry);
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final options = response.requestOptions;
    final entry = options.extra[entryExtra];

    // Only reached when the caller widened validateStatus to accept 304.
    if (response.statusCode == 304 && entry is CacheEntry) {
      final refreshed = await _acceptNotModified(entry, response);
      return handler.next(_revalidatedResponse(refreshed, options));
    }

    await _maybeStore(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final entry = options.extra[entryExtra];

    // 304 is a cache hit, not a failure. Dio's default validateStatus sends it
    // here, so this is the path that actually runs.
    if (err.response?.statusCode == 304) {
      if (entry is! CacheEntry) return handler.next(err);
      final refreshed = await _acceptNotModified(entry, err.response!);
      return handler.resolve(_revalidatedResponse(refreshed, options));
    }

    if (entry is CacheEntry &&
        _isNetworkFailure(err) &&
        entry.canServeOnErrorAt(DateTime.now(), config.staleIfError)) {
      HttpCacheMetrics.staleOnError++;
      devPrint('HttpCache: ${err.type} on ${options.path}, serving stale');
      return handler.resolve(
        entry.toResponse(
          options,
          extra: {
            HttpCachePolicy.fromCacheExtra: true,
            HttpCachePolicy.staleExtra: true,
            HttpCachePolicy.staleOnErrorExtra: true,
            HttpCachePolicy.cacheAgeExtra: entry.ageAt(DateTime.now()).inSeconds,
          },
        ),
      );
    }

    handler.next(err);
  }

  bool _isCacheable(RequestOptions options) {
    if (options.extra[HttpCachePolicy.noCacheExtra] == true) return false;
    if (options.responseType == ResponseType.stream) return false;
    return config.cacheableMethods.contains(options.method.toUpperCase());
  }

  /// stale-if-error covers a dead connection and the 5xx family.
  bool _isNetworkFailure(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        return status == 500 || status == 502 || status == 503 || status == 504;
      default:
        return false;
    }
  }

  void _attachValidators(RequestOptions options, CacheEntry entry) {
    final etag = entry.etag;
    final lastModified = entry.lastModified;
    if (etag != null) options.headers['If-None-Match'] = etag;
    if (lastModified != null) {
      options.headers['If-Modified-Since'] = lastModified;
    }
  }

  Future<CacheEntry> _acceptNotModified(
    CacheEntry entry,
    Response<dynamic> response,
  ) async {
    HttpCacheMetrics.revalidations++;
    final refreshed = entry.revalidatedWith(response);
    try {
      HttpCacheMetrics.evictions += await _store.put(refreshed);
    } catch (e) {
      devPrint('HttpCache: could not persist the revalidated entry: $e');
    }
    return refreshed;
  }

  Response<dynamic> _revalidatedResponse(
    CacheEntry entry,
    RequestOptions options,
  ) => entry.toResponse(
    options,
    extra: {
      HttpCachePolicy.fromCacheExtra: true,
      HttpCachePolicy.revalidatedExtra: true,
      HttpCachePolicy.cacheAgeExtra: 0,
    },
  );

  Future<void> _maybeStore(Response<dynamic> response) async {
    final options = response.requestOptions;
    if (!_isCacheable(options)) return;
    if (!config.cacheableStatusCodes.contains(response.statusCode ?? 0)) return;
    if (HttpCachePolicy.requestCacheControl(options).noStore) return;

    final responseCc = HttpCachePolicy.responseCacheControl(response.headers);
    if (responseCc.noStore) return;

    // Vary: * says this response is never reusable for another request.
    final varyNames = HttpCachePolicy.varyNamesOf(response.headers);
    if (varyNames == null) {
      devPrint('HttpCache: Vary:* on ${options.path}, not storing');
      return;
    }

    final entry = CacheEntry.fromResponse(
      response: response,
      primaryKey:
          (options.extra[HttpCachePolicy.primaryKeyExtra] as String?) ??
          HttpCachePolicy.primaryKeyFor(options),
      varyNames: varyNames,
      varySignature: HttpCachePolicy.varySignature(varyNames, options),
      defaultMaxAge: config.defaultMaxAge,
    );
    if (entry == null) return;

    // Nothing to gain: no freshness info and no way to revalidate.
    if (entry.freshnessLifetime == null && !entry.hasValidator) return;
    if (entry.size > _store.maxBytes) return;

    try {
      HttpCacheMetrics.evictions += await _store.put(entry);
      HttpCacheMetrics.stores++;
    } catch (e) {
      devPrint('HttpCache: write failed: $e');
    }
  }

  /// Replays the request silently so the next caller gets fresh data.
  void _refreshInBackground(RequestOptions options, CacheEntry entry) {
    if (_refreshing.contains(entry.key)) return;
    _refreshing.add(entry.key);
    HttpCacheMetrics.backgroundRefreshes++;
    final refresh = options.copyWith(
      extra: {...options.extra, backgroundExtra: true, entryExtra: entry},
    );
    _attachValidators(refresh, entry);
    _runRefresh(refresh, entry.key);
  }

  Future<void> _runRefresh(RequestOptions options, String key) async {
    try {
      await _dio.fetch<dynamic>(options);
    } catch (e) {
      devPrint('HttpCache: background refresh of ${options.path} failed: $e');
    } finally {
      _refreshing.remove(key);
    }
  }

  Future<void> _safeTouch(CacheEntry entry, DateTime at) async {
    try {
      await _store.touch(entry, at);
    } catch (e) {
      devPrint('HttpCache: touch failed: $e');
    }
  }

  Future<void> _safeDelete(String key) async {
    try {
      await _store.delete(key);
    } catch (e) {
      devPrint('HttpCache: delete failed: $e');
    }
  }

  DioException _notInCache(RequestOptions options) => DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    error: 'only-if-cached: no stored response',
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: 504,
      statusMessage: 'Gateway Timeout (only-if-cached)',
    ),
  );
}
