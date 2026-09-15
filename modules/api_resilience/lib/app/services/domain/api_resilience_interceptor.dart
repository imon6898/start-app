import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import '../api_resilience_service.dart';
import 'circuit_breaker.dart';
import 'dev_tools.dart';
import 'retry_policy.dart';

/// Dio interceptor: coalesces duplicate GETs, honours Retry-After on 429,
/// retries transient failures with full jitter, and trips a per-host circuit.
///
/// This protects the SERVER from your app and the UX from retry storms.
/// It is not a client-side rate limiter — see the module README.
class ApiResilienceInterceptor extends Interceptor {
  ApiResilienceInterceptor(
    this._dio, {
    this.config = const ResilienceConfig(),
    CircuitBreaker? breaker,
    this.random,
  }) : breaker =
           breaker ??
           (sharedBreaker
             ..failureThreshold = config.failureThreshold
             ..openDuration = config.openDuration);

  /// Shared so a per-call `ApiService()` still sees one host's failure streak.
  static final CircuitBreaker sharedBreaker = CircuitBreaker(
    onStateChanged: ApiResilienceService.reportCircuit,
  );

  /// Identical GETs currently on the wire, keyed by method + url + query.
  /// Static for the same reason: ApiService is constructed per call.
  static final Map<String, Completer<Response<dynamic>>> _inFlight = {};

  /// Drops all shared state — call on sign-out, or between tests.
  static void resetShared() {
    _inFlight.clear();
    sharedBreaker.reset();
  }

  /// Attempt index carried across retries (0 = first try).
  static const String attemptKey = 'resilienceAttempt';

  /// Dedup slot this request owns, stamped on the RequestOptions that claimed it.
  static const String _ownerKey = 'resilienceDedupKey';

  final Dio _dio;
  final ResilienceConfig config;
  final CircuitBreaker breaker;

  /// Injectable for deterministic jitter in tests.
  final Random? random;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final host = options.uri.host;

    if (!breaker.allowRequest(host)) {
      final cooldown = breaker.cooldownOf(host);
      devPrint('Resilience: circuit open for $host, failing fast');
      return handler.reject(
        DioException.connectionError(
          requestOptions: options,
          reason: 'circuit open for $host',
          error: CircuitOpenException(host, cooldown),
        ),
      );
    }

    final key = _dedupKey(options);
    if (key != null) {
      final leader = _inFlight[key];
      if (leader != null) {
        devPrint('Resilience: coalescing duplicate $key');
        leader.future.then(
          (response) => handler.resolve(_copyFor(response, options)),
          onError: (Object error, StackTrace stack) => handler.reject(
            error is DioException
                ? error.copyWith(requestOptions: options)
                : DioException(requestOptions: options, error: error),
          ),
        );
        return;
      }
      final completer = Completer<Response<dynamic>>();
      _inFlight[key] = completer;
      options.extra[_ownerKey] = key;
      // Nobody may be listening yet; keep a failure from going unhandled.
      completer.future.ignore();
    }

    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    breaker.onSuccess(response.requestOptions.uri.host);
    _release(response.requestOptions, response: response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final host = options.uri.host;
    final attempt = (options.extra[attemptKey] as int?) ?? 0;
    final hasAttemptsLeft = attempt < config.maxAttempts - 1;
    final cancelled =
        err.type == DioExceptionType.cancel ||
        options.cancelToken?.isCancelled == true;

    // 429: the server set the pace. Never invent our own delay here.
    if (RetryPolicy.isRateLimited(err)) {
      final retryAfter = RetryPolicy.retryAfterOf(err.response);
      ApiResilienceService.reportRateLimit(host, retryAfter);
      final canWait =
          retryAfter != null &&
          retryAfter <= config.maxRetryAfterWait &&
          RetryPolicy.isIdempotent(options) &&
          hasAttemptsLeft &&
          !cancelled;
      if (canWait) {
        devPrint(
          'Resilience: 429 on ${options.path}, waiting ${retryAfter.inSeconds}s',
        );
        return _retryAfterDelay(err, handler, retryAfter, attempt);
      }
      devPrint('Resilience: 429 on ${options.path}, surfacing to the caller');
      _release(options, error: err);
      return handler.next(err);
    }

    if (!RetryPolicy.isTransient(err)) {
      // 400/401/403/404/… — retrying is pointless and looks like an attack.
      _release(options, error: err);
      return handler.next(err);
    }

    breaker.onFailure(host);

    // Only idempotent requests. A retried payment or signup double-charges.
    if (!RetryPolicy.isIdempotent(options) || !hasAttemptsLeft || cancelled) {
      _release(options, error: err);
      return handler.next(err);
    }

    final delay = RetryPolicy.backoffDelay(
      attempt,
      config: config,
      random: random,
    );
    devPrint(
      'Resilience: retry ${attempt + 1}/${config.maxAttempts - 1} '
      'for ${options.path} in ${delay.inMilliseconds}ms',
    );
    return _retryAfterDelay(err, handler, delay, attempt);
  }

  /// Waits, then replays the request through the full interceptor chain.
  Future<void> _retryAfterDelay(
    DioException err,
    ErrorInterceptorHandler handler,
    Duration delay,
    int attempt,
  ) async {
    await Future<void>.delayed(delay);
    final options = err.requestOptions;
    options.extra[attemptKey] = attempt + 1;
    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    } catch (e) {
      devPrint('Resilience: retry failed unexpectedly: $e');
      handler.next(err);
    }
  }

  /// Only plain GETs are coalesced; retries reuse the leader's slot.
  String? _dedupKey(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') return null;
    if (options.extra[RetryPolicy.noDedupKey] == true) return null;
    if (options.extra[attemptKey] != null) return null;
    if (options.extra['isRetry'] == true) return null;
    return 'GET ${options.uri}';
  }

  void _release(
    RequestOptions options, {
    Response<dynamic>? response,
    DioException? error,
  }) {
    final key = options.extra[_ownerKey] as String?;
    if (key == null) return;
    final completer = _inFlight.remove(key);
    if (completer == null || completer.isCompleted) return;
    if (response != null) {
      completer.complete(response);
    } else {
      completer.completeError(error ?? DioException(requestOptions: options));
    }
  }

  /// Same payload, but stamped with the follower's own RequestOptions.
  Response<dynamic> _copyFor(
    Response<dynamic> source,
    RequestOptions options,
  ) => Response<dynamic>(
    data: source.data,
    requestOptions: options,
    statusCode: source.statusCode,
    statusMessage: source.statusMessage,
    isRedirect: source.isRedirect,
    headers: source.headers,
    extra: {...source.extra, 'coalesced': true},
  );
}
