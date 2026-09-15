import 'dart:convert';

/// Severity, ordered. Anything below `AppLogger.minLevel` is dropped.
enum LogLevel { trace, debug, info, warn, error }

/// One immutable log line. Already redacted: AppLogger scrubs before it builds
/// a record, so a sink can never see a raw token or email.
class LogRecord {
  const LogRecord({
    required this.level,
    required this.message,
    required this.time,
    this.logger,
    this.fields = const {},
    this.traceId,
    this.error,
    this.stack,
  });

  final LogLevel level;
  final String message;
  final DateTime time;

  /// Subsystem name, e.g. `http`, `perf`, `OrdersController`.
  final String? logger;
  final Map<String, Object?> fields;

  /// 32-hex W3C trace id this line belongs to, when one is known.
  final String? traceId;

  /// Stringified error; the object itself is never retained.
  final String? error;
  final StackTrace? stack;

  /// Flat map — a log pipeline indexes these keys.
  Map<String, Object?> toJson() => <String, Object?>{
    'ts': time.toUtc().toIso8601String(),
    'level': level.name,
    if (logger != null) 'logger': logger,
    'msg': message,
    if (traceId != null) 'trace_id': traceId,
    if (error != null) 'err': error,
    if (stack != null) 'stack': stack.toString(),
    ...fields,
  };

  /// One line of JSON — what Loki / Datadog / CloudWatch ingest.
  /// Non-encodable field values fall back to `toString()` instead of throwing.
  String toJsonLine() =>
      jsonEncode(toJson(), toEncodable: (Object? o) => o.toString());

  /// Human-readable form for the debug console.
  String toLine() {
    final buffer = StringBuffer('${level.name.toUpperCase().padRight(5)} ');
    if (logger != null) buffer.write('[$logger] ');
    buffer.write(message);
    if (traceId != null) buffer.write(' trace=${traceId!.substring(0, 8)}');
    for (final entry in fields.entries) {
      buffer.write(' ${entry.key}=${entry.value}');
    }
    if (error != null) buffer.write(' err=$error');
    return buffer.toString();
  }

  @override
  String toString() => toLine();
}
