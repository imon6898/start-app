import 'dart:io' show HttpDate;
import 'dart:math';

import 'package:dio/dio.dart';

/// Tunables for ApiResilienceInterceptor. Defaults are deliberately conservative.
class ResilienceConfig {
  const ResilienceConfig({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 8),
    this.maxRetryAfterWait = const Duration(seconds: 60),
    this.failureThreshold = 5,
    this.openDuration = const Duration(seconds: 30),
  });

  /// Total tries per request, including the first one.
  final int maxAttempts;

  /// First backoff ceiling; doubles per attempt.
  final Duration baseDelay;

  /// Upper bound on any single backoff wait.
  final Duration maxDelay;

  /// Longer Retry-After values are surfaced to the UI instead of waited on.
  final Duration maxRetryAfterWait;

  /// Consecutive host failures before the circuit opens.
  final int failureThreshold;

  /// How long the circuit stays open before a half-open probe.
  final Duration openDuration;
}

/// Pure decision helpers — no I/O, so they are directly unit-testable.
class RetryPolicy {
  RetryPolicy._();

  static const String retryAfterHeader = 'retry-after';

  /// Opt a non-idempotent request into retries: Options(extra: {'idempotent': true}).
  static const String idempotentKey = 'idempotent';

  /// Opt out of in-flight coalescing: Options(extra: {'noDedup': true}).
  static const String noDedupKey = 'noDedup';

  static const Set<String> idempotentMethods = {'GET', 'HEAD', 'OPTIONS'};

  /// Transient server-side codes. 429 is handled separately, via Retry-After.
  static const Set<int> retryableStatusCodes = {408, 500, 502, 503, 504};

  static final Random _random = Random();

  /// Safe to send twice: no side effects, or the caller promised there are none.
  static bool isIdempotent(RequestOptions options) =>
      options.extra[idempotentKey] == true ||
      idempotentMethods.contains(options.method.toUpperCase());

  static bool isRateLimited(DioException e) => e.response?.statusCode == 429;

  /// Worth another try. Every other 4xx fails immediately by design.
  static bool isTransient(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        return retryableStatusCodes.contains(e.response?.statusCode);
      default:
        return false;
    }
  }

  /// Reads Retry-After off a response; null when absent or unparseable.
  static Duration? retryAfterOf(Response? response, {DateTime? now}) {
    final values = response?.headers[retryAfterHeader];
    if (values == null || values.isEmpty) return null;
    return parseRetryAfter(values.first, now: now);
  }

  /// Retry-After is either delay-seconds ("120") or an HTTP-date.
  static Duration? parseRetryAfter(String? raw, {DateTime? now}) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

    // Form 1: delay-seconds.
    final seconds = int.tryParse(value);
    if (seconds != null) {
      return seconds <= 0 ? Duration.zero : Duration(seconds: seconds);
    }

    // Form 2: HTTP-date, always GMT. HttpDate covers IMF-fixdate/RFC 850/asctime.
    DateTime? until;
    try {
      until = HttpDate.parse(value);
    } catch (_) {
      until = DateTime.tryParse(value)?.toUtc();
    }
    if (until == null) return null;

    // RFC 850's two-digit year parses as year 0094 — treat as unparseable.
    if (until.year < 2000) return null;

    final delta = until.difference((now ?? DateTime.now()).toUtc());
    return delta.isNegative ? Duration.zero : delta;
  }

  /// Full jitter: delay = random(0, min(base * 2^attempt, maxDelay)).
  /// Fixed backoff makes every client retry in lockstep; jitter spreads them out.
  static Duration backoffDelay(
    int attempt, {
    ResilienceConfig config = const ResilienceConfig(),
    Random? random,
  }) {
    final capped = attempt.clamp(0, 16);
    final exponential = config.baseDelay.inMilliseconds * (1 << capped);
    final ceiling = min(exponential, config.maxDelay.inMilliseconds);
    return Duration(milliseconds: (random ?? _random).nextInt(ceiling + 1));
  }

  /// Upper bound of backoffDelay for an attempt — used by tests and logs.
  static Duration backoffCeiling(
    int attempt, {
    ResilienceConfig config = const ResilienceConfig(),
  }) {
    final capped = attempt.clamp(0, 16);
    return Duration(
      milliseconds: min(
        config.baseDelay.inMilliseconds * (1 << capped),
        config.maxDelay.inMilliseconds,
      ),
    );
  }
}
