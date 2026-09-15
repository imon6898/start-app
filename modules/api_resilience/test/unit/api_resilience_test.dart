import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/app/services/domain/api_resilience_interceptor.dart';
import 'package:flutter_starter/app/services/domain/circuit_breaker.dart';
import 'package:flutter_starter/app/services/domain/retry_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns a canned ResponseBody per call and counts what was sent.
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
  String body = '{"ok":true}',
  Map<String, List<String>>? headers,
}) async => ResponseBody.fromString(
  body,
  statusCode,
  headers: {
    'content-type': ['application/json'],
    ...?headers,
  },
);

void main() {
  group('Retry-After: delay-seconds form', () {
    test('parses a plain second count', () {
      expect(RetryPolicy.parseRetryAfter('120'), const Duration(seconds: 120));
      expect(RetryPolicy.parseRetryAfter(' 30 '), const Duration(seconds: 30));
    });

    test('clamps zero and negative values to zero', () {
      expect(RetryPolicy.parseRetryAfter('0'), Duration.zero);
      expect(RetryPolicy.parseRetryAfter('-5'), Duration.zero);
    });

    test('returns null when absent or unparseable', () {
      expect(RetryPolicy.parseRetryAfter(null), isNull);
      expect(RetryPolicy.parseRetryAfter(''), isNull);
      expect(RetryPolicy.parseRetryAfter('soon'), isNull);
    });
  });

  group('Retry-After: HTTP-date form', () {
    // The form everyone forgets: an absolute instant, not a duration.
    final DateTime now = DateTime.utc(2015, 10, 21, 7, 26, 0);

    test('parses IMF-fixdate into the remaining wait', () {
      expect(
        RetryPolicy.parseRetryAfter('Wed, 21 Oct 2015 07:28:00 GMT', now: now),
        const Duration(seconds: 120),
      );
    });

    test('a date already in the past means retry now', () {
      expect(
        RetryPolicy.parseRetryAfter('Wed, 21 Oct 2015 07:00:00 GMT', now: now),
        Duration.zero,
      );
    });

    test('works with a local-time now', () {
      final DateTime localNow = now.toLocal();
      expect(
        RetryPolicy.parseRetryAfter(
          'Wed, 21 Oct 2015 07:28:00 GMT',
          now: localNow,
        ),
        const Duration(seconds: 120),
      );
    });

    test('rejects the RFC 850 two-digit year instead of trusting it', () {
      // HttpDate reads "94" as year 0094, which would look like "retry now".
      expect(
        RetryPolicy.parseRetryAfter('Sunday, 06-Nov-94 08:49:37 GMT'),
        isNull,
      );
    });

    test('reads the header off a response', () {
      final response = Response<dynamic>(
        requestOptions: RequestOptions(path: '/orders'),
        statusCode: 429,
        headers: Headers.fromMap({
          'retry-after': ['Wed, 21 Oct 2015 07:28:00 GMT'],
        }),
      );
      expect(
        RetryPolicy.retryAfterOf(response, now: now),
        const Duration(seconds: 120),
      );
      expect(RetryPolicy.retryAfterOf(null), isNull);
    });
  });

  group('Full-jitter backoff', () {
    const config = ResilienceConfig();

    test('every delay lands in [0, min(base * 2^attempt, maxDelay)]', () {
      final random = Random(7);
      for (var attempt = 0; attempt < 6; attempt++) {
        final ceiling = RetryPolicy.backoffCeiling(attempt, config: config);
        for (var i = 0; i < 200; i++) {
          final delay = RetryPolicy.backoffDelay(
            attempt,
            config: config,
            random: random,
          );
          expect(delay, greaterThanOrEqualTo(Duration.zero));
          expect(delay, lessThanOrEqualTo(ceiling));
        }
      }
    });

    test('the ceiling doubles per attempt and then caps', () {
      expect(RetryPolicy.backoffCeiling(0), const Duration(milliseconds: 500));
      expect(RetryPolicy.backoffCeiling(1), const Duration(seconds: 1));
      expect(RetryPolicy.backoffCeiling(2), const Duration(seconds: 2));
      expect(RetryPolicy.backoffCeiling(5), const Duration(seconds: 8));
      expect(RetryPolicy.backoffCeiling(40), const Duration(seconds: 8));
    });

    test('delays actually vary — that is what breaks the thundering herd', () {
      final random = Random(11);
      final samples = List.generate(
        50,
        (_) => RetryPolicy.backoffDelay(3, random: random).inMilliseconds,
      );
      expect(samples.toSet().length, greaterThan(1));
    });
  });

  group('Retry eligibility', () {
    RequestOptions options(String method, {Map<String, dynamic>? extra}) =>
        RequestOptions(path: '/x', method: method, extra: extra);

    test('GET, HEAD and OPTIONS are idempotent', () {
      expect(RetryPolicy.isIdempotent(options('GET')), isTrue);
      expect(RetryPolicy.isIdempotent(options('head')), isTrue);
      expect(RetryPolicy.isIdempotent(options('OPTIONS')), isTrue);
    });

    test('POST, PUT, PATCH and DELETE are not — unless opted in', () {
      expect(RetryPolicy.isIdempotent(options('POST')), isFalse);
      expect(RetryPolicy.isIdempotent(options('PUT')), isFalse);
      expect(RetryPolicy.isIdempotent(options('PATCH')), isFalse);
      expect(RetryPolicy.isIdempotent(options('DELETE')), isFalse);
      expect(
        RetryPolicy.isIdempotent(options('POST', extra: {'idempotent': true})),
        isTrue,
      );
    });

    DioException badResponse(int code) => DioException.badResponse(
      statusCode: code,
      requestOptions: RequestOptions(path: '/x'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: code,
      ),
    );

    test('only 408 and 5xx are transient', () {
      for (final code in [408, 500, 502, 503, 504]) {
        expect(RetryPolicy.isTransient(badResponse(code)), isTrue);
      }
      for (final code in [400, 401, 403, 404, 409, 422]) {
        expect(RetryPolicy.isTransient(badResponse(code)), isFalse);
      }
    });

    test('429 is rate limiting, not a transient failure', () {
      expect(RetryPolicy.isTransient(badResponse(429)), isFalse);
      expect(RetryPolicy.isRateLimited(badResponse(429)), isTrue);
    });

    test('timeouts and connection errors are transient, cancel is not', () {
      final request = RequestOptions(path: '/x');
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(
          RetryPolicy.isTransient(
            DioException(requestOptions: request, type: type),
          ),
          isTrue,
        );
      }
      expect(
        RetryPolicy.isTransient(
          DioException(requestOptions: request, type: DioExceptionType.cancel),
        ),
        isFalse,
      );
    });
  });

  group('CircuitBreaker', () {
    late DateTime clock;
    late CircuitBreaker breaker;

    setUp(() {
      clock = DateTime.utc(2026, 1, 1);
      breaker = CircuitBreaker(
        failureThreshold: 3,
        openDuration: const Duration(seconds: 30),
        clock: () => clock,
      );
    });

    test('opens after N consecutive failures and then fails fast', () {
      for (var i = 0; i < 3; i++) {
        expect(breaker.allowRequest('api.test'), isTrue);
        breaker.onFailure('api.test');
      }
      expect(breaker.stateOf('api.test'), CircuitState.open);
      expect(breaker.allowRequest('api.test'), isFalse);
      expect(breaker.cooldownOf('api.test'), const Duration(seconds: 30));
    });

    test('a success resets the failure count', () {
      breaker
        ..onFailure('api.test')
        ..onFailure('api.test')
        ..onSuccess('api.test');
      expect(breaker.failureCountOf('api.test'), 0);
      breaker.onFailure('api.test');
      expect(breaker.stateOf('api.test'), CircuitState.closed);
    });

    test('half-open lets exactly one probe through after the cooldown', () {
      for (var i = 0; i < 3; i++) {
        breaker.onFailure('api.test');
      }
      clock = clock.add(const Duration(seconds: 31));
      expect(breaker.allowRequest('api.test'), isTrue);
      expect(breaker.stateOf('api.test'), CircuitState.halfOpen);
      expect(breaker.allowRequest('api.test'), isFalse);
    });

    test('a successful probe closes the circuit', () {
      for (var i = 0; i < 3; i++) {
        breaker.onFailure('api.test');
      }
      clock = clock.add(const Duration(seconds: 31));
      breaker.allowRequest('api.test');
      breaker.onSuccess('api.test');
      expect(breaker.stateOf('api.test'), CircuitState.closed);
      expect(breaker.allowRequest('api.test'), isTrue);
    });

    test('a failed probe reopens for another full cooldown', () {
      for (var i = 0; i < 3; i++) {
        breaker.onFailure('api.test');
      }
      clock = clock.add(const Duration(seconds: 31));
      breaker.allowRequest('api.test');
      breaker.onFailure('api.test');
      expect(breaker.stateOf('api.test'), CircuitState.open);
      expect(breaker.cooldownOf('api.test'), const Duration(seconds: 30));
      expect(breaker.allowRequest('api.test'), isFalse);
    });

    test('hosts are tracked independently', () {
      for (var i = 0; i < 3; i++) {
        breaker.onFailure('dead.test');
      }
      expect(breaker.allowRequest('dead.test'), isFalse);
      expect(breaker.allowRequest('healthy.test'), isTrue);
    });

    test('state changes are reported to the listener', () {
      final events = <String>[];
      final watched = CircuitBreaker(
        failureThreshold: 2,
        clock: () => clock,
        onStateChanged: (host, state, cooldown) =>
            events.add('$host:${state.name}'),
      );
      watched
        ..onFailure('api.test')
        ..onFailure('api.test')
        ..onSuccess('api.test');
      expect(events, ['api.test:open', 'api.test:closed']);
    });
  });

  group('ApiResilienceInterceptor', () {
    // Near-zero delays keep the test fast; jitter bounds are covered above.
    const fast = ResilienceConfig(
      baseDelay: Duration(milliseconds: 1),
      maxDelay: Duration(milliseconds: 2),
    );

    // Dedup map and default breaker are process-wide.
    setUp(ApiResilienceInterceptor.resetShared);

    Dio buildDio(
      _FakeAdapter adapter, {
      ResilienceConfig config = fast,
      CircuitBreaker? breaker,
    }) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        ApiResilienceInterceptor(dio, config: config, breaker: breaker),
      );
      return dio;
    }

    test('retries a transient 503 GET and succeeds', () async {
      final adapter = _FakeAdapter((_, i) => _json(i == 0 ? 503 : 200));
      final response = await buildDio(adapter).get<dynamic>('/orders');
      expect(response.statusCode, 200);
      expect(adapter.calls.length, 2);
    });

    test('stops after maxAttempts tries', () async {
      final adapter = _FakeAdapter((_, _) => _json(503));
      await expectLater(
        buildDio(adapter).get<dynamic>('/orders'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls.length, fast.maxAttempts);
    });

    test('never blind-retries a POST', () async {
      final adapter = _FakeAdapter((_, _) => _json(503));
      await expectLater(
        buildDio(adapter).post<dynamic>('/payments', data: {'amount': 100}),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls.length, 1);
    });

    test('retries a POST that explicitly opted in', () async {
      final adapter = _FakeAdapter((_, i) => _json(i == 0 ? 503 : 200));
      final response = await buildDio(adapter).post<dynamic>(
        '/reports',
        data: {'id': 1},
        options: Options(extra: {'idempotent': true}),
      );
      expect(response.statusCode, 200);
      expect(adapter.calls.length, 2);
    });

    test('fails a 400 immediately', () async {
      final adapter = _FakeAdapter((_, _) => _json(400));
      await expectLater(
        buildDio(adapter).get<dynamic>('/orders'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls.length, 1);
    });

    test('honours a short Retry-After on 429', () async {
      final adapter = _FakeAdapter(
        (_, i) => i == 0
            ? _json(
                429,
                headers: {
                  'retry-after': ['0'],
                },
              )
            : _json(200),
      );
      final response = await buildDio(adapter).get<dynamic>('/orders');
      expect(response.statusCode, 200);
      expect(adapter.calls.length, 2);
    });

    test('surfaces a long Retry-After instead of hanging', () async {
      final adapter = _FakeAdapter(
        (_, _) => _json(
          429,
          headers: {
            'retry-after': ['600'],
          },
        ),
      );
      await expectLater(
        buildDio(adapter).get<dynamic>('/orders'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls.length, 1);
    });

    test('coalesces two identical in-flight GETs into one call', () async {
      final gate = Completer<void>();
      final adapter = _FakeAdapter((_, _) async {
        await gate.future;
        return _json(200);
      });
      final dio = buildDio(adapter);

      final first = dio.get<dynamic>('/orders', queryParameters: {'page': 1});
      await Future<void>.delayed(Duration.zero);
      final second = dio.get<dynamic>('/orders', queryParameters: {'page': 1});
      gate.complete();

      final responses = await Future.wait([first, second]);
      expect(adapter.calls.length, 1);
      expect(responses.every((r) => r.statusCode == 200), isTrue);
      expect(responses.last.extra['coalesced'], isTrue);
    });

    test(
      'opens the circuit and then fails fast without a network call',
      () async {
        final adapter = _FakeAdapter((_, _) => _json(500));
        final breaker = CircuitBreaker(
          failureThreshold: 2,
          openDuration: const Duration(seconds: 30),
        );
        // maxAttempts 1 = no retries, so each call counts as exactly one failure.
        final dio = buildDio(
          adapter,
          config: const ResilienceConfig(maxAttempts: 1),
          breaker: breaker,
        );

        for (var i = 0; i < 2; i++) {
          await expectLater(
            dio.get<dynamic>('/orders'),
            throwsA(isA<DioException>()),
          );
        }
        expect(breaker.stateOf('api.test'), CircuitState.open);

        await expectLater(
          dio.get<dynamic>('/orders'),
          throwsA(
            isA<DioException>().having(
              (e) => e.error,
              'error',
              isA<CircuitOpenException>(),
            ),
          ),
        );
        expect(adapter.calls.length, 2);
      },
    );
  });
}
