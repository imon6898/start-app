// Distributed tracing, client side. Tags every request with a W3C traceparent
// so a slow screen can be matched to the server spans it caused.

import 'dart:math';

import 'package:dio/dio.dart';

import '../observability_service.dart';
import 'app_logger.dart';

/// One W3C trace-context value: `00-<32 hex trace-id>-<16 hex span-id>-<flags>`.
///
/// version `00`, trace-id = the whole request tree, span-id = this one hop,
/// flags `01` sampled / `00` not. Ids are correlation handles, not secrets, but
/// they are visible to every proxy — never derive them from user data.
class TraceContext {
  const TraceContext({
    required this.traceId,
    required this.spanId,
    this.sampled = true,
  });

  /// Header name from the W3C Trace Context recommendation.
  static const String header = 'traceparent';
  static const String version = '00';

  final String traceId;
  final String spanId;
  final bool sampled;

  static final Random _random = Random();
  static final RegExp _shape = RegExp(
    r'^[0-9a-f]{2}-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}$',
  );
  static final RegExp _hex32 = RegExp(r'^[0-9a-f]{32}$');

  /// New root span. Pass [traceId] to add a hop to an existing trace.
  factory TraceContext.generate({String? traceId, bool sampled = true}) {
    final trace = (traceId != null && _hex32.hasMatch(traceId))
        ? traceId
        : randomHex(16);
    return TraceContext(traceId: trace, spanId: randomHex(8), sampled: sampled);
  }

  String get flags => sampled ? '01' : '00';

  String get headerValue => '$version-$traceId-$spanId-$flags';

  /// Null when the value is malformed, uses the forbidden `ff` version, or
  /// carries an all-zero id — all invalid per the spec.
  static TraceContext? parse(String? value) {
    if (value == null || !_shape.hasMatch(value)) return null;
    final parts = value.split('-');
    if (parts[0] == 'ff') return null;
    if (parts[1] == '0' * 32 || parts[2] == '0' * 16) return null;
    return TraceContext(
      traceId: parts[1],
      spanId: parts[2],
      sampled: int.parse(parts[3], radix: 16) & 0x01 == 1,
    );
  }

  static String randomHex(int bytes) => List<String>.generate(
    bytes,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  @override
  String toString() => headerValue;
}

/// Adds `traceparent` to every request and logs one structured line per call.
/// Method, host, path and duration only — never the query string or the body.
class TraceInterceptor extends Interceptor {
  TraceInterceptor({
    this.sampleRate = 1.0,
    this.slowRequestThreshold = const Duration(seconds: 2),
    this.logger = 'http',
  });

  /// Fraction of requests marked sampled in the flags byte. 1.0 = all.
  final double sampleRate;

  /// Responses at or over this are logged at warn and counted as slow.
  final Duration slowRequestThreshold;

  /// `logger` field on the emitted records.
  final String logger;

  /// Set this on a request to join an existing trace: `Options(extra: {...})`.
  static const String extraTraceId = 'observability.traceId';
  static const String extraTrace = 'observability.trace';
  static const String extraWatch = 'observability.watch';

  final Random _random = Random();

  /// Trace id carried by a RequestOptions / Response / DioException, so an
  /// error message can quote the id support will search for.
  static String? traceIdOf(Object? source) {
    Map<String, dynamic>? extra;
    if (source is RequestOptions) extra = source.extra;
    if (source is Response) extra = source.requestOptions.extra;
    if (source is DioException) extra = source.requestOptions.extra;
    return (extra?[extraTrace] as TraceContext?)?.traceId;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final previous = options.extra[extraTrace] as TraceContext?;
    final TraceContext context;
    if (previous != null) {
      // A replay (token refresh, resilience retry): same trace, new span.
      context = TraceContext.generate(
        traceId: previous.traceId,
        sampled: previous.sampled,
      );
      options.headers[TraceContext.header] = context.headerValue;
    } else {
      final caller = TraceContext.parse(
        options.headers[TraceContext.header]?.toString(),
      );
      context =
          caller ??
          TraceContext.generate(
            traceId: options.extra[extraTraceId] as String?,
            sampled: _sampled(),
          );
      options.headers[TraceContext.header] = context.headerValue;
    }

    options.extra[extraTrace] = context;
    options.extra[extraWatch] = Stopwatch()..start();

    AppLogger.debug(
      'request',
      logger: logger,
      traceId: context.traceId,
      fields: {
        'method': options.method,
        'host': options.uri.host,
        'path': options.uri.path,
      },
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final options = response.requestOptions;
    final elapsed = _elapsed(options);
    final traceId = (options.extra[extraTrace] as TraceContext?)?.traceId;
    final slow = elapsed >= slowRequestThreshold;

    ObservabilityService.reportRequest(
      elapsed: elapsed,
      status: response.statusCode,
      failed: false,
      slow: slow,
      traceId: traceId,
    );

    AppLogger.log(
      slow ? LogLevel.warn : LogLevel.info,
      slow ? 'slow response' : 'response',
      logger: logger,
      traceId: traceId,
      fields: {
        'method': options.method,
        'path': options.uri.path,
        'status': response.statusCode,
        'ms': elapsed.inMilliseconds,
      },
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final elapsed = _elapsed(options);
    final traceId = (options.extra[extraTrace] as TraceContext?)?.traceId;
    final status = err.response?.statusCode;

    ObservabilityService.reportRequest(
      elapsed: elapsed,
      status: status,
      failed: true,
      slow: elapsed >= slowRequestThreshold,
      traceId: traceId,
    );

    // A 4xx is the server answering; no response at all is our problem.
    final level = (status != null && status < 500)
        ? LogLevel.warn
        : LogLevel.error;
    AppLogger.log(
      level,
      'request failed',
      logger: logger,
      traceId: traceId,
      error: err.message ?? err.type.name,
      fields: {
        'method': options.method,
        'path': options.uri.path,
        'status': status,
        'type': err.type.name,
        'ms': elapsed.inMilliseconds,
      },
    );
    handler.next(err);
  }

  bool _sampled() {
    if (sampleRate >= 1) return true;
    if (sampleRate <= 0) return false;
    return _random.nextDouble() < sampleRate;
  }

  Duration _elapsed(RequestOptions options) =>
      (options.extra[extraWatch] as Stopwatch?)?.elapsed ?? Duration.zero;
}
