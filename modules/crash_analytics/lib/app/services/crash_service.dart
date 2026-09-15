// Provider-agnostic crash reporting. Screens and controllers talk to
// CrashService; only lib/app/services/crash/ knows which SaaS is behind it.
//   await CrashService.to.init();                 // once, in bootstrap
//   CrashService.to.recordError(e, s);            // anywhere

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../core/config/env.dart';
import 'crash/sentry_crash_reporter.dart';
import 'domain/dev_tools.dart';

/// Severity shared by every backend; each reporter maps it to its own scale.
enum CrashLevel { debug, info, warning, error, fatal }

/// The contract a crash backend must satisfy. Swap the implementation without
/// touching a single call site.
abstract class CrashReporter {
  /// False when no DSN/key is set — the service then stays off.
  bool get isConfigured;

  /// Boots the SDK. Called at most once.
  Future<void> init();

  /// Reports a caught or uncaught error.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, String> tags = const {},
  });

  /// Attaches (or clears, with null) the signed-in user's opaque id.
  Future<void> setUserId(String? id);

  /// Sends a standalone message event.
  Future<void> log(String message, {CrashLevel level = CrashLevel.info});

  /// Records a trail entry attached to the next error.
  Future<void> addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
    CrashLevel level = CrashLevel.info,
  });

  /// Flushes and shuts the SDK down.
  Future<void> close();
}

/// Facade over [CrashReporter]. Every method is a silent no-op until [init]
/// succeeds, so calling it from a debug run or an unconfigured build is safe.
class CrashService extends GetxService {
  /// `.env` flag that opts debug/profile builds into reporting.
  static const String debugOptInKey = 'SENTRY_ENABLE_IN_DEBUG';

  /// Self-registering: bootstrap's error handlers run before ViewModelBinding.
  static CrashService get to => Get.isRegistered<CrashService>()
      ? Get.find<CrashService>()
      : Get.put(CrashService(), permanent: true);

  CrashReporter? _reporter;

  /// True once a configured reporter is live.
  bool get isEnabled => _reporter != null;

  /// Release-only by default; local runs stay quiet.
  static bool get isAllowedInThisBuild =>
      kReleaseMode || Env.optional(debugOptInKey).toLowerCase() == 'true';

  /// Call once from bootstrap, after `Env.load()`. Never throws; a failure
  /// here just leaves reporting off.
  Future<CrashService> init({CrashReporter? reporter}) async {
    if (_reporter != null) return this;

    try {
      if (!isAllowedInThisBuild) {
        devPrint(
          'off — debug build, set $debugOptInKey=true to override',
          tag: 'CrashService',
        );
        return this;
      }

      final candidate = reporter ?? SentryCrashReporter();
      if (!candidate.isConfigured) {
        devPrint('off — no DSN in .env', tag: 'CrashService');
        return this;
      }

      await candidate.init();
      _reporter = candidate;
      devPrint('reporting enabled', tag: 'CrashService');
    } catch (e) {
      devPrint('init failed: $e', tag: 'CrashService');
    }
    return this;
  }

  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, String> tags = const {},
  }) => _guard(
    () => _reporter!.recordError(
      error,
      stack,
      reason: reason,
      fatal: fatal,
      tags: tags,
    ),
  );

  /// Pass the backend id, never an email or phone number.
  Future<void> setUserId(String? id) => _guard(() => _reporter!.setUserId(id));

  Future<void> log(String message, {CrashLevel level = CrashLevel.info}) =>
      _guard(() => _reporter!.log(message, level: level));

  Future<void> addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
    CrashLevel level = CrashLevel.info,
  }) => _guard(
    () => _reporter!.addBreadcrumb(
      message,
      category: category,
      data: data,
      level: level,
    ),
  );

  /// Flushes pending events; call on logout or teardown.
  Future<void> shutdown() async {
    final reporter = _reporter;
    if (reporter == null) return;
    _reporter = null;
    try {
      await reporter.close();
    } catch (e) {
      devPrint('close failed: $e', tag: 'CrashService');
    }
  }

  /// A reporting failure must never become the app's failure.
  Future<void> _guard(Future<void> Function() action) async {
    if (_reporter == null) return;
    try {
      await action();
    } catch (e) {
      devPrint('reporter call failed: $e', tag: 'CrashService');
    }
  }
}
