import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_starter/app/services/observability/app_logger.dart';
import 'package:flutter_starter/app/services/observability/log_redactor.dart';
import 'package:flutter_starter/app/services/observability/perf_monitor.dart';
import 'package:flutter_starter/app/services/observability/trace_interceptor.dart';
import 'package:flutter_starter/app/services/observability_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Captures records instead of printing them.
class _CaptureSink implements LogSink {
  final List<LogRecord> records = <LogRecord>[];
  int flushes = 0;

  @override
  void write(LogRecord record) => records.add(record);

  @override
  Future<void> flush() async => flushes++;

  List<LogRecord> of(String message) =>
      records.where((r) => r.message == message).toList();
}

class _ThrowingSink implements LogSink {
  @override
  void write(LogRecord record) => throw StateError('transport down');

  @override
  Future<void> flush() async {}
}

/// Returns a canned response per call and records what was sent.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  final Future<ResponseBody> Function(RequestOptions options, int callIndex)
  responder;
  final List<RequestOptions> calls = <RequestOptions>[];

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

FrameTiming _frame({required int buildMs, required int rasterMs}) {
  const vsyncStart = 0;
  const buildStart = 1000;
  final buildFinish = buildStart + buildMs * 1000;
  final rasterStart = buildFinish;
  final rasterFinish = rasterStart + rasterMs * 1000;
  return FrameTiming(
    vsyncStart: vsyncStart,
    buildStart: buildStart,
    buildFinish: buildFinish,
    rasterStart: rasterStart,
    rasterFinish: rasterFinish,
    rasterFinishWallTime: rasterFinish,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CaptureSink sink;

  setUp(() {
    sink = _CaptureSink();
    AppLogger.sinks = <LogSink>[sink];
    AppLogger.minLevel = LogLevel.trace;
    AppLogger.context = <String, Object?>{};
    AppLogger.traceIdProvider = null;
    PerfMonitor.reset();
    PerfMonitor.frameBudget = const Duration(milliseconds: 16);
    PerfMonitor.freezeBudget = const Duration(milliseconds: 700);
    PerfMonitor.jankLogInterval = const Duration(seconds: 2);
  });

  tearDown(() {
    PerfMonitor.stop();
    PerfMonitor.reset();
    AppLogger.sinks = <LogSink>[const ConsoleLogSink()];
    if (Get.isRegistered<ObservabilityService>()) {
      Get.delete<ObservabilityService>(force: true);
    }
  });

  group('LogRedactor text', () {
    test('strips bearer tokens, JWTs, emails and phone numbers', () {
      expect(
        LogRedactor.scrubText('Authorization: Bearer abc.def-123'),
        'Authorization: Bearer [redacted]',
      );
      expect(
        LogRedactor.scrubText('token eyJhbGciOi.eyJzdWIi.sig'),
        'token [redacted]',
      );
      expect(
        LogRedactor.scrubText('mail to a.user+tag@example.co.uk now'),
        'mail to [redacted] now',
      );
      expect(LogRedactor.scrubText('call +44 20 7946 0958'), 'call [redacted]');
      expect(LogRedactor.scrubText('id 0123456789'), 'id [redacted]');
    });

    test('leaves short numbers and ordinary text alone', () {
      expect(
        LogRedactor.scrubText('status 404 in 1200 ms'),
        'status 404 in 1200 ms',
      );
      expect(LogRedactor.scrubText(''), '');
      expect(LogRedactor.scrubText(null), isNull);
    });
  });

  group('LogRedactor keys', () {
    test('matches sensitive names in every casing style', () {
      for (final key in [
        'accessToken',
        'refresh_token',
        'Authorization',
        'password',
        'user_password',
        'Email',
        'phoneNumber',
        'api_key',
        'apiKey',
        'Cookie',
        'user_pin',
        'otp',
        'card_number',
        'session_id',
        'latitude',
      ]) {
        expect(LogRedactor.isSensitiveKey(key), isTrue, reason: key);
      }
    });

    test('does not match names that merely contain a short needle', () {
      for (final key in [
        'spinner',
        'spinCount',
        'mailboxCount2',
        'userId',
        'status',
      ]) {
        expect(LogRedactor.isSensitiveKey(key), isFalse, reason: key);
      }
    });

    test('scrubFields redacts by key and walks nested values', () {
      final out = LogRedactor.scrubFields({
        'password': 'hunter2',
        'user': {'email': 'a@b.com', 'name': 'Ada'},
        'notes': ['write to a@b.com', 7],
        'status': 200,
      });

      expect(out['password'], LogRedactor.redacted);
      expect((out['user'] as Map)['email'], LogRedactor.redacted);
      expect((out['user'] as Map)['name'], 'Ada');
      expect((out['notes'] as List).first, 'write to [redacted]');
      expect(out['status'], 200);
    });

    test('stops at maxDepth instead of recursing forever', () {
      final cyclic = <String, Object?>{};
      cyclic['self'] = cyclic;
      final out = LogRedactor.scrubFields(cyclic, maxDepth: 2);
      expect(out.containsKey('self'), isTrue);
    });
  });

  group('AppLogger', () {
    test('drops records below minLevel and counts them', () {
      Get.put(ObservabilityService(), permanent: true);
      AppLogger.minLevel = LogLevel.warn;

      AppLogger.debug('quiet');
      AppLogger.warn('loud');

      expect(sink.records.map((r) => r.message), ['loud']);
      expect(Get.find<ObservabilityService>().droppedLogCount.value, 1);
    });

    test('redacts the message, the fields and the error', () {
      AppLogger.error(
        'login failed for a@b.com',
        fields: {'authorization': 'Bearer xyz', 'attempt': 2},
        error: Exception('rejected eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.sig'),
      );

      final record = sink.records.single;
      expect(record.message, 'login failed for [redacted]');
      expect(record.fields['authorization'], LogRedactor.redacted);
      expect(record.fields['attempt'], 2);
      expect(record.error, contains('[redacted]'));
    });

    test('merges context, and a per-call field wins', () {
      AppLogger.context = {'flavor': 'dev', 'build': '1.0.0'};
      AppLogger.info('hello', fields: {'build': '2.0.0'});

      final record = sink.records.single;
      expect(record.fields['flavor'], 'dev');
      expect(record.fields['build'], '2.0.0');
    });

    test('uses traceIdProvider when no id is passed', () {
      AppLogger.traceIdProvider = () => '0' * 31 + '1';
      AppLogger.info('ambient');
      expect(sink.records.single.traceId, '0' * 31 + '1');
    });

    test('a broken sink never breaks the caller', () {
      AppLogger.sinks = <LogSink>[_ThrowingSink(), sink];
      expect(() => AppLogger.info('still logged'), returnsNormally);
      expect(sink.records.single.message, 'still logged');
    });

    test('flush reaches every sink', () async {
      await AppLogger.flush();
      expect(sink.flushes, 1);
    });

    test('toJsonLine is valid JSON carrying level, message and time', () {
      AppLogger.warn('disk low', logger: 'storage', fields: {'free_mb': 12});

      final decoded =
          jsonDecode(sink.records.single.toJsonLine()) as Map<String, dynamic>;
      expect(decoded['level'], 'warn');
      expect(decoded['msg'], 'disk low');
      expect(decoded['logger'], 'storage');
      expect(decoded['free_mb'], 12);
      expect(DateTime.parse(decoded['ts'] as String).isUtc, isTrue);
    });

    test(
      'a non-encodable field falls back to toString instead of throwing',
      () {
        AppLogger.info('odd', fields: {'when': const Duration(seconds: 1)});
        expect(() => sink.records.single.toJsonLine(), returnsNormally);
      },
    );
  });

  group('TraceContext', () {
    final shape = RegExp(r'^00-[0-9a-f]{32}-[0-9a-f]{16}-0[01]$');

    test('generated header matches the W3C shape', () {
      final context = TraceContext.generate();
      expect(context.headerValue, matches(shape));
      expect(context.traceId.length, 32);
      expect(context.spanId.length, 16);
      expect(context.flags, '01');
    });

    test('ids differ between calls', () {
      final ids = List.generate(20, (_) => TraceContext.generate().traceId);
      expect(ids.toSet().length, 20);
    });

    test('unsampled sets the flags byte to 00', () {
      expect(
        TraceContext.generate(sampled: false).headerValue,
        endsWith('-00'),
      );
    });

    test('an inherited trace id is reused with a fresh span id', () {
      final root = TraceContext.generate();
      final child = TraceContext.generate(traceId: root.traceId);
      expect(child.traceId, root.traceId);
      expect(child.spanId, isNot(root.spanId));
    });

    test('an invalid inherited id is replaced, not trusted', () {
      final context = TraceContext.generate(traceId: 'not-hex');
      expect(context.traceId, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('parse round-trips and reads the sampled flag', () {
      final context = TraceContext.generate(sampled: false);
      final parsed = TraceContext.parse(context.headerValue)!;
      expect(parsed.traceId, context.traceId);
      expect(parsed.spanId, context.spanId);
      expect(parsed.sampled, isFalse);
    });

    test('rejects malformed, ff-version and all-zero values', () {
      expect(TraceContext.parse(null), isNull);
      expect(TraceContext.parse('00-abc-def-01'), isNull);
      expect(TraceContext.parse('ff-${'a' * 32}-${'b' * 16}-01'), isNull);
      expect(TraceContext.parse('00-${'0' * 32}-${'b' * 16}-01'), isNull);
      expect(TraceContext.parse('00-${'a' * 32}-${'0' * 16}-01'), isNull);
      expect(TraceContext.parse('00-${'A' * 32}-${'b' * 16}-01'), isNull);
    });
  });

  group('TraceInterceptor', () {
    Dio dioWith(_FakeAdapter adapter, {TraceInterceptor? interceptor}) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(interceptor ?? TraceInterceptor());
      return dio;
    }

    test('sets a valid traceparent on every request', () async {
      final adapter = _FakeAdapter(
        (options, _) async => ResponseBody.fromString('{}', 200),
      );
      final dio = dioWith(adapter);

      await dio.get('/orders');
      await dio.get('/orders');

      final sent = adapter.calls
          .map((c) => c.headers[TraceContext.header] as String)
          .toList();
      expect(sent.every((h) => TraceContext.parse(h) != null), isTrue);
      expect(
        sent.map((h) => TraceContext.parse(h)!.traceId).toSet().length,
        2,
        reason: 'each request is its own trace',
      );
    });

    test('sampleRate 0 marks the flags byte unsampled', () async {
      final adapter = _FakeAdapter(
        (options, _) async => ResponseBody.fromString('{}', 200),
      );
      await dioWith(
        adapter,
        interceptor: TraceInterceptor(sampleRate: 0),
      ).get('/x');

      expect(
        adapter.calls.single.headers[TraceContext.header],
        endsWith('-00'),
      );
    });

    test('a replay keeps the trace id and mints a new span id', () async {
      // A replay reuses the same RequestOptions instance, so the header has to
      // be read as it goes out, not off the recorded object afterwards.
      final sent = <String>[];
      final adapter = _FakeAdapter((options, _) async {
        sent.add(options.headers[TraceContext.header] as String);
        return ResponseBody.fromString('{}', 200);
      });
      final dio = dioWith(adapter);

      final first = await dio.get('/orders');
      await dio.fetch(first.requestOptions); // what the refresh retry does

      final a = TraceContext.parse(sent.first)!;
      final b = TraceContext.parse(sent.last)!;
      expect(b.traceId, a.traceId);
      expect(b.spanId, isNot(a.spanId));
    });

    test('a caller-supplied trace id joins the same trace', () async {
      final adapter = _FakeAdapter(
        (options, _) async => ResponseBody.fromString('{}', 200),
      );
      final dio = dioWith(adapter);
      final traceId = TraceContext.generate().traceId;

      await dio.get(
        '/a',
        options: Options(extra: {TraceInterceptor.extraTraceId: traceId}),
      );
      await dio.get(
        '/b',
        options: Options(extra: {TraceInterceptor.extraTraceId: traceId}),
      );

      final ids = adapter.calls
          .map(
            (c) => TraceContext.parse(
              c.headers[TraceContext.header] as String,
            )!.traceId,
          )
          .toSet();
      expect(ids, {traceId});
    });

    test(
      'logs one response line with status and duration, no query string',
      () async {
        final adapter = _FakeAdapter(
          (options, _) async => ResponseBody.fromString('{}', 201),
        );
        await dioWith(
          adapter,
        ).get('/orders', queryParameters: {'token': 'secret'});

        final record = sink.of('response').single;
        expect(record.fields['status'], 201);
        expect(record.fields['path'], '/orders');
        expect(record.fields.containsKey('query'), isFalse);
        expect(record.toJsonLine(), isNot(contains('secret')));
        expect(record.traceId, isNotNull);
      },
    );

    test('a slow response is logged at warn', () async {
      final adapter = _FakeAdapter(
        (options, _) async => ResponseBody.fromString('{}', 200),
      );
      await dioWith(
        adapter,
        interceptor: TraceInterceptor(slowRequestThreshold: Duration.zero),
      ).get('/slow');

      expect(sink.of('slow response').single.level, LogLevel.warn);
    });

    test('4xx logs at warn, a transport failure at error', () async {
      final adapter = _FakeAdapter(
        (options, _) async => ResponseBody.fromString('{}', 404),
      );
      await expectLater(
        dioWith(adapter).get('/missing'),
        throwsA(isA<DioException>()),
      );
      expect(sink.of('request failed').single.level, LogLevel.warn);

      sink.records.clear();
      final broken = _FakeAdapter(
        (options, _) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'no route',
        ),
      );
      await expectLater(
        dioWith(broken).get('/down'),
        throwsA(isA<DioException>()),
      );
      expect(sink.of('request failed').single.level, LogLevel.error);
    });

    test('traceIdOf reads the id back off a response', () async {
      final adapter = _FakeAdapter(
        (options, _) async => ResponseBody.fromString('{}', 200),
      );
      final response = await dioWith(adapter).get('/orders');
      expect(TraceInterceptor.traceIdOf(response), isNotNull);
      expect(TraceInterceptor.traceIdOf('nonsense'), isNull);
    });

    test('feeds the service counters', () async {
      final service = Get.put(ObservabilityService(), permanent: true);
      final adapter = _FakeAdapter(
        (options, _) async => ResponseBody.fromString('{}', 200),
      );
      await dioWith(adapter).get('/orders');

      expect(service.requestCount.value, 1);
      expect(service.failedRequestCount.value, 0);
      expect(service.lastTraceId.value.length, 32);
    });
  });

  group('PerfMonitor frames', () {
    test('frameCost is build plus raster', () {
      expect(
        PerfMonitor.frameCost(_frame(buildMs: 6, rasterMs: 4)),
        const Duration(milliseconds: 10),
      );
    });

    test('jank is measured against the budget', () {
      expect(PerfMonitor.isJank(_frame(buildMs: 8, rasterMs: 6)), isFalse);
      expect(PerfMonitor.isJank(_frame(buildMs: 12, rasterMs: 9)), isTrue);
      expect(
        PerfMonitor.isJank(
          _frame(buildMs: 8, rasterMs: 6),
          budget: const Duration(milliseconds: 8),
        ),
        isTrue,
      );
    });

    test('a freeze is always logged, jank is rate limited', () {
      PerfMonitor.onTimings([
        _frame(buildMs: 20, rasterMs: 5),
        _frame(buildMs: 25, rasterMs: 5),
        _frame(buildMs: 400, rasterMs: 400),
      ]);

      expect(sink.of('jank').length, 1, reason: 'throttled to one per window');
      expect(sink.of('frame freeze').length, 1);
    });

    test('a healthy frame logs nothing', () {
      PerfMonitor.onTimings([_frame(buildMs: 5, rasterMs: 5)]);
      expect(sink.records, isEmpty);
    });

    test('frames land in the service counters and percentiles', () {
      final service = Get.put(ObservabilityService(), permanent: true);

      PerfMonitor.onTimings([
        for (var i = 0; i < 10; i++) _frame(buildMs: 4, rasterMs: 4),
        _frame(buildMs: 30, rasterMs: 10),
      ]);
      service.publishNow();

      expect(service.framesObserved.value, 11);
      expect(service.jankFrames.value, 1);
      expect(service.worstFrameMs.value, 40);
      expect(service.p50FrameMs.value, 8);
      expect(service.p95FrameMs.value, 40);
      expect(service.jankPercent, closeTo(9.09, 0.01));
    });
  });

  group('PerfMonitor spans and TTI', () {
    test('endSpan returns a duration and logs once', () {
      PerfMonitor.startSpan('load-orders');
      expect(PerfMonitor.endSpan('load-orders'), isNotNull);
      expect(sink.of('span').single.fields['name'], 'load-orders');
    });

    test('a duplicate start is refused and an unknown end is null', () {
      expect(PerfMonitor.startSpan('a'), isTrue);
      expect(PerfMonitor.startSpan('a'), isFalse);
      PerfMonitor.endSpan('a');
      expect(PerfMonitor.endSpan('never-opened'), isNull);
    });

    test('span() closes even when the body throws', () async {
      await expectLater(
        PerfMonitor.span('boom', () async => throw StateError('x')),
        throwsStateError,
      );
      expect(sink.of('span').single.fields['name'], 'boom');
      expect(PerfMonitor.startSpan('boom'), isTrue, reason: 'span was closed');
    });

    test('spanSync returns the body value', () {
      expect(PerfMonitor.spanSync('calc', () => 41 + 1), 42);
    });

    test('markInteractive is a no-op before start and fires once after', () {
      PerfMonitor.markInteractive(route: '/home');
      expect(sink.of('time to interactive'), isEmpty);

      PerfMonitor.start();
      PerfMonitor.markInteractive(route: '/home');
      PerfMonitor.markInteractive(route: '/home');
      expect(sink.of('time to interactive').length, 1);
    });
  });

  group('ObservabilityService', () {
    test('reporters no-op when the service is not registered', () {
      expect(
        () => ObservabilityService.reportFrame(
          const Duration(milliseconds: 30),
          budget: const Duration(milliseconds: 16),
        ),
        returnsNormally,
      );
    });

    test('recentLogs is capped and reset clears everything', () {
      final service = Get.put(ObservabilityService(), permanent: true);
      ObservabilityService.recentLogCapacity = 5;

      for (var i = 0; i < 20; i++) {
        AppLogger.info('line $i');
      }

      expect(service.recentLogs.length, 5);
      expect(service.logCount.value, 20);
      expect(service.recentLogs.last.message, 'line 19');

      service.clear();
      expect(service.recentLogs, isEmpty);
      expect(service.logCount.value, 0);
      ObservabilityService.recentLogCapacity = 50;
    });

    test('percentile of an empty window is zero', () {
      final service = Get.put(ObservabilityService(), permanent: true);
      expect(service.percentile(95), 0);
      expect(service.jankPercent, 0);
      expect(service.requestFailurePercent, 0);
    });
  });
}
