// The one concrete CrashReporter. Keep sentry_flutter imports inside this
// folder so swapping providers means writing one new file, not a refactor.

import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/config/app_flavor.dart';
import '../../core/config/env.dart';
import '../crash_service.dart';
import 'crash_pii_scrubber.dart';

/// Sentry-backed crash reporting, configured from `.env`.
class SentryCrashReporter implements CrashReporter {
  /// `.env` keys this module owns — nothing is added to core [Env].
  static const String dsnKey = 'SENTRY_DSN';
  static const String tracesSampleRateKey = 'SENTRY_TRACES_SAMPLE_RATE';

  /// Empty when the key is absent; [isConfigured] then keeps the SDK off.
  String get dsn => Env.optional(dsnKey);

  @override
  bool get isConfigured => dsn.isNotEmpty;

  @override
  Future<void> init() async {
    await SentryFlutter.init((options) {
      options.dsn = dsn;
      options.environment = AppFlavor.name;

      // No IP address, device name or automatic user context.
      options.sendDefaultPii = false;
      // A screenshot can capture a half-filled form. attachViewHierarchy is
      // left at its false default for the same reason.
      options.attachScreenshot = false;

      options.maxBreadcrumbs = 50;
      // Performance tracing is opt-in and off unless .env sets a rate.
      options.tracesSampleRate =
          double.tryParse(Env.optional(tracesSampleRateKey, fallback: '0')) ??
          0;

      // Last gate before anything leaves the device.
      options.beforeSend = CrashPiiScrubber.beforeSend;
      options.beforeBreadcrumb = CrashPiiScrubber.beforeBreadcrumb;
    });
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, String> tags = const {},
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: (scope) async {
        scope.level = fatal ? SentryLevel.fatal : SentryLevel.error;
        if (reason != null && reason.isNotEmpty) {
          await scope.setContexts('crash', {'reason': reason});
        }
        for (final tag in tags.entries) {
          await scope.setTag(tag.key, tag.value);
        }
      },
    );
  }

  @override
  Future<void> setUserId(String? id) async {
    final user = (id == null || id.isEmpty) ? null : SentryUser(id: id);
    await Sentry.configureScope((scope) => scope.setUser(user));
  }

  @override
  Future<void> log(String message, {CrashLevel level = CrashLevel.info}) async {
    await Sentry.captureMessage(message, level: _toSentryLevel(level));
  }

  @override
  Future<void> addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
    CrashLevel level = CrashLevel.info,
  }) async {
    await Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        data: data,
        level: _toSentryLevel(level),
      ),
    );
  }

  @override
  Future<void> close() => Sentry.close();

  SentryLevel _toSentryLevel(CrashLevel level) {
    switch (level) {
      case CrashLevel.debug:
        return SentryLevel.debug;
      case CrashLevel.info:
        return SentryLevel.info;
      case CrashLevel.warning:
        return SentryLevel.warning;
      case CrashLevel.error:
        return SentryLevel.error;
      case CrashLevel.fatal:
        return SentryLevel.fatal;
    }
  }
}
