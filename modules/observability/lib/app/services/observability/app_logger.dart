// Structured logging. Replaces raw devPrint once an app needs levels, fields
// and a transport that survives release builds.
//   AppLogger.info('order placed', logger: 'orders', fields: {'id': 42});

import 'package:flutter/foundation.dart';

import '../domain/dev_tools.dart';
import '../observability_service.dart';
import 'log_record.dart';
import 'log_redactor.dart';

export 'log_record.dart' show LogLevel, LogRecord;

/// Where records go. Implement this to ship logs anywhere.
abstract class LogSink {
  void write(LogRecord record);

  /// Called by `AppLogger.flush()`; override for a buffering transport.
  Future<void> flush() async {}
}

/// Default sink: JSON to the debug console, `debugPrint` elsewhere.
class ConsoleLogSink implements LogSink {
  const ConsoleLogSink({this.json = true});

  final bool json;

  @override
  void write(LogRecord record) {
    final line = json ? record.toJsonLine() : record.toLine();
    // devPrint is dart:developer and compiles out of release; debugPrint does not.
    if (kDebugMode) {
      devPrint(line, tag: 'log');
    } else {
      debugPrint(line);
    }
  }

  @override
  Future<void> flush() async {}
}

/// Keeps the last [capacity] records in memory. Useful for a "send diagnostics"
/// button — never persisted, so nothing survives a restart.
class MemoryLogSink implements LogSink {
  MemoryLogSink({this.capacity = 200});

  final int capacity;
  final List<LogRecord> records = <LogRecord>[];

  @override
  void write(LogRecord record) {
    records.add(record);
    if (records.length > capacity) records.removeAt(0);
  }

  @override
  Future<void> flush() async {}

  void clear() => records.clear();
}

/// Leveled structured logger. Every message and field is redacted before it
/// reaches a sink; see [LogRedactor] for exactly what is stripped.
class AppLogger {
  AppLogger._();

  /// Records below this level are dropped and counted, never formatted.
  static LogLevel minLevel = kReleaseMode ? LogLevel.info : LogLevel.debug;

  /// Fan-out targets. Replace the list to change transports.
  static List<LogSink> sinks = <LogSink>[const ConsoleLogSink()];

  /// Merged into every record: build number, flavor, device, opaque user id.
  /// Set it once at startup; it is redacted like any other field.
  static Map<String, Object?> context = <String, Object?>{};

  /// Ambient trace id for lines logged during a request. There is no Zone
  /// propagation — wire this only if you track the current trace yourself.
  static String? Function()? traceIdProvider;

  static void trace(
    String message, {
    String? logger,
    Map<String, Object?> fields = const {},
    String? traceId,
  }) => log(
    LogLevel.trace,
    message,
    logger: logger,
    fields: fields,
    traceId: traceId,
  );

  static void debug(
    String message, {
    String? logger,
    Map<String, Object?> fields = const {},
    String? traceId,
  }) => log(
    LogLevel.debug,
    message,
    logger: logger,
    fields: fields,
    traceId: traceId,
  );

  static void info(
    String message, {
    String? logger,
    Map<String, Object?> fields = const {},
    String? traceId,
  }) => log(
    LogLevel.info,
    message,
    logger: logger,
    fields: fields,
    traceId: traceId,
  );

  static void warn(
    String message, {
    String? logger,
    Map<String, Object?> fields = const {},
    String? traceId,
    Object? error,
  }) => log(
    LogLevel.warn,
    message,
    logger: logger,
    fields: fields,
    traceId: traceId,
    error: error,
  );

  static void error(
    String message, {
    String? logger,
    Map<String, Object?> fields = const {},
    String? traceId,
    Object? error,
    StackTrace? stack,
  }) => log(
    LogLevel.error,
    message,
    logger: logger,
    fields: fields,
    traceId: traceId,
    error: error,
    stack: stack,
  );

  /// The one emit path. Never throws: a broken sink must not break a feature.
  static void log(
    LogLevel level,
    String message, {
    String? logger,
    Map<String, Object?> fields = const {},
    String? traceId,
    Object? error,
    StackTrace? stack,
  }) {
    if (level.index < minLevel.index) {
      ObservabilityService.reportDroppedLog();
      return;
    }

    final record = LogRecord(
      level: level,
      message: LogRedactor.scrubText(message) ?? message,
      time: DateTime.now(),
      logger: logger,
      fields: LogRedactor.scrubFields(<String, Object?>{...context, ...fields}),
      traceId: traceId ?? traceIdProvider?.call(),
      // Stack frames are passed through unredacted; only the message is scrubbed.
      error: error == null ? null : LogRedactor.scrubText(error.toString()),
      stack: stack,
    );

    ObservabilityService.reportLog(record);
    for (final sink in sinks) {
      try {
        sink.write(record);
      } catch (e) {
        devPrint('sink ${sink.runtimeType} failed: $e', tag: 'AppLogger');
      }
    }
  }

  /// Flushes every buffering sink; call before a deliberate exit or on logout.
  static Future<void> flush() async {
    for (final sink in sinks) {
      try {
        await sink.flush();
      } catch (e) {
        devPrint('flush ${sink.runtimeType} failed: $e', tag: 'AppLogger');
      }
    }
  }
}
