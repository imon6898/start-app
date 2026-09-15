// Performance monitoring: jank from real frame timings, time-to-interactive,
// and named spans for anything you want to time.

import 'package:flutter/scheduler.dart';

import '../observability_service.dart';
import 'app_logger.dart';

/// Frame timing, TTI and span timing. Static because the engine hands frame
/// timings to one process-wide callback list, not to a widget.
class PerfMonitor {
  PerfMonitor._();

  static const String _logger = 'perf';

  /// build + raster over this is jank. 16ms ~ 60Hz; set 8ms on a 120Hz target.
  static Duration frameBudget = const Duration(milliseconds: 16);

  /// A frame this slow is a visible freeze, always logged at warn.
  static Duration freezeBudget = const Duration(milliseconds: 700);

  /// A scroll can produce hundreds of janky frames; log at most one per window.
  static Duration jankLogInterval = const Duration(seconds: 2);

  static bool _started = false;
  static final Stopwatch _sinceStart = Stopwatch();
  static bool _firstFrameReported = false;
  static bool _interactiveReported = false;
  static DateTime? _lastJankLog;
  static final Map<String, Stopwatch> _spans = <String, Stopwatch>{};

  static bool get isRunning => _started;

  /// Elapsed since [start] — the startup clock TTI is measured against.
  static Duration get sinceStart => _sinceStart.elapsed;

  /// Starts frame monitoring. Call from `bootstrap()` after
  /// `WidgetsFlutterBinding.ensureInitialized()`. Idempotent.
  static void start({Duration? budget, Duration? freeze}) {
    if (budget != null) frameBudget = budget;
    if (freeze != null) freezeBudget = freeze;
    if (_started) return;
    _started = true;
    _sinceStart
      ..reset()
      ..start();
    SchedulerBinding.instance.addTimingsCallback(onTimings);
    SchedulerBinding.instance.addPostFrameCallback((_) => _reportFirstFrame());
  }

  static void stop() {
    if (!_started) return;
    SchedulerBinding.instance.removeTimingsCallback(onTimings);
    _sinceStart.stop();
    _started = false;
  }

  /// What the user actually waited for: UI build plus GPU raster.
  static Duration frameCost(FrameTiming timing) =>
      timing.buildDuration + timing.rasterDuration;

  static bool isJank(FrameTiming timing, {Duration? budget}) =>
      frameCost(timing) > (budget ?? frameBudget);

  /// The engine callback. Public so a test can feed it synthetic timings.
  static void onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final cost = frameCost(timing);
      ObservabilityService.reportFrame(cost, budget: frameBudget);
      if (cost >= freezeBudget) {
        _logFrame('frame freeze', timing, cost);
      } else if (cost > frameBudget) {
        _logJankThrottled(timing, cost);
      }
    }
  }

  /// Marks the app usable: first screen painted with its real content. Call it
  /// once, from the first screen that has data — only the first call counts.
  static void markInteractive({String? route}) {
    if (_interactiveReported || !_started) return;
    _interactiveReported = true;
    final elapsed = _sinceStart.elapsed;
    ObservabilityService.reportTimeToInteractive(elapsed);
    AppLogger.info(
      'time to interactive',
      logger: _logger,
      fields: {'ms': elapsed.inMilliseconds, 'route': ?route},
    );
  }

  /// Opens a span. Returns false when one of that name is already open.
  static bool startSpan(String name) {
    if (_spans.containsKey(name)) return false;
    _spans[name] = Stopwatch()..start();
    ObservabilityService.reportSpanStart(name);
    return true;
  }

  /// Closes a span and logs its duration. Null when it was never opened.
  static Duration? endSpan(
    String name, {
    Map<String, Object?> fields = const {},
  }) {
    final watch = _spans.remove(name);
    if (watch == null) return null;
    watch.stop();
    final elapsed = watch.elapsed;
    ObservabilityService.reportSpanEnd(name, elapsed);
    AppLogger.info(
      'span',
      logger: _logger,
      fields: {'name': name, 'ms': elapsed.inMilliseconds, ...fields},
    );
    return elapsed;
  }

  /// Times an async body; the span closes even when [body] throws.
  static Future<T> span<T>(String name, Future<T> Function() body) async {
    startSpan(name);
    try {
      return await body();
    } finally {
      endSpan(name);
    }
  }

  /// Synchronous variant.
  static T spanSync<T>(String name, T Function() body) {
    startSpan(name);
    try {
      return body();
    } finally {
      endSpan(name);
    }
  }

  /// Drops open spans and the one-shot flags; for tests and sign-out.
  static void reset() {
    _spans.clear();
    _lastJankLog = null;
    _firstFrameReported = false;
    _interactiveReported = false;
  }

  static void _reportFirstFrame() {
    if (_firstFrameReported) return;
    _firstFrameReported = true;
    final elapsed = _sinceStart.elapsed;
    ObservabilityService.reportFirstFrame(elapsed);
    AppLogger.info(
      'first frame',
      logger: _logger,
      fields: {'ms': elapsed.inMilliseconds},
    );
  }

  static void _logJankThrottled(FrameTiming timing, Duration cost) {
    final now = DateTime.now();
    final last = _lastJankLog;
    if (last != null && now.difference(last) < jankLogInterval) return;
    _lastJankLog = now;
    _logFrame('jank', timing, cost);
  }

  static void _logFrame(String message, FrameTiming timing, Duration cost) {
    AppLogger.warn(
      message,
      logger: _logger,
      fields: {
        'total_ms': cost.inMilliseconds,
        'build_ms': timing.buildDuration.inMilliseconds,
        'raster_ms': timing.rasterDuration.inMilliseconds,
        'vsync_ms': timing.vsyncOverhead.inMilliseconds,
        'budget_ms': frameBudget.inMilliseconds,
      },
    );
  }
}
