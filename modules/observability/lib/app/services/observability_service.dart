import 'package:get/get.dart';

import 'observability/log_record.dart';

/// Rx mirror of what the logger, the tracer and the frame monitor are seeing,
/// so a debug overlay (or a diagnostics screen) can render it.
///
/// Optional: every static reporter no-ops when the service is not registered,
/// so logging and tracing work with or without it.
class ObservabilityService extends GetxService {
  /// Frame counters are published at most this often — an overlay that
  /// rebuilt on every frame would itself be the jank.
  static Duration publishInterval = const Duration(milliseconds: 500);

  /// Frame samples kept for the percentiles.
  static int windowSize = 120;

  /// Records kept for a log viewer.
  static int recentLogCapacity = 50;

  // Logs
  final RxInt logCount = 0.obs;
  final RxInt warnCount = 0.obs;
  final RxInt errorCount = 0.obs;
  final RxInt droppedLogCount = 0.obs;
  final RxList<LogRecord> recentLogs = <LogRecord>[].obs;

  // Frames
  final RxInt framesObserved = 0.obs;
  final RxInt jankFrames = 0.obs;
  final RxInt worstFrameMs = 0.obs;
  final RxInt lastFrameMs = 0.obs;
  final RxInt p50FrameMs = 0.obs;
  final RxInt p95FrameMs = 0.obs;

  // Startup
  final RxInt firstFrameMs = 0.obs;
  final RxInt timeToInteractiveMs = 0.obs;

  // Requests
  final RxInt requestCount = 0.obs;
  final RxInt failedRequestCount = 0.obs;
  final RxInt slowRequestCount = 0.obs;
  final RxInt lastRequestMs = 0.obs;
  final RxString lastTraceId = ''.obs;

  // Spans
  final RxMap<String, int> spanMs = <String, int>{}.obs;
  final RxInt openSpanCount = 0.obs;

  int _frames = 0;
  int _jank = 0;
  int _worstUs = 0;
  final List<int> _window = <int>[];
  DateTime? _lastPublish;

  /// Share of observed frames that missed the budget.
  double get jankPercent => framesObserved.value == 0
      ? 0
      : 100 * jankFrames.value / framesObserved.value;

  double get requestFailurePercent => requestCount.value == 0
      ? 0
      : 100 * failedRequestCount.value / requestCount.value;

  static ObservabilityService? get _instance =>
      Get.isRegistered<ObservabilityService>()
      ? Get.find<ObservabilityService>()
      : null;

  static void reportLog(LogRecord record) => _instance?._onLog(record);

  static void reportDroppedLog() => _instance?.droppedLogCount.value++;

  static void reportFrame(Duration cost, {required Duration budget}) =>
      _instance?._onFrame(cost, budget);

  static void reportFirstFrame(Duration elapsed) =>
      _instance?.firstFrameMs.value = elapsed.inMilliseconds;

  static void reportTimeToInteractive(Duration elapsed) =>
      _instance?.timeToInteractiveMs.value = elapsed.inMilliseconds;

  static void reportSpanStart(String name) => _instance?.openSpanCount.value++;

  static void reportSpanEnd(String name, Duration elapsed) =>
      _instance?._onSpanEnd(name, elapsed);

  static void reportRequest({
    required Duration elapsed,
    required bool failed,
    required bool slow,
    int? status,
    String? traceId,
  }) => _instance?._onRequest(elapsed, failed, slow, traceId);

  static void reset() => _instance?.clear();

  void _onLog(LogRecord record) {
    logCount.value++;
    if (record.level == LogLevel.warn) warnCount.value++;
    if (record.level == LogLevel.error) errorCount.value++;
    recentLogs.add(record);
    if (recentLogs.length > recentLogCapacity) recentLogs.removeAt(0);
  }

  void _onFrame(Duration cost, Duration budget) {
    _frames++;
    if (cost > budget) _jank++;
    if (cost.inMicroseconds > _worstUs) _worstUs = cost.inMicroseconds;
    _window.add(cost.inMilliseconds);
    if (_window.length > windowSize) _window.removeAt(0);
    lastFrameMs.value = cost.inMilliseconds;
    _publishThrottled();
  }

  void _onSpanEnd(String name, Duration elapsed) {
    spanMs[name] = elapsed.inMilliseconds;
    if (openSpanCount.value > 0) openSpanCount.value--;
  }

  void _onRequest(Duration elapsed, bool failed, bool slow, String? traceId) {
    requestCount.value++;
    if (failed) failedRequestCount.value++;
    if (slow) slowRequestCount.value++;
    lastRequestMs.value = elapsed.inMilliseconds;
    if (traceId != null) lastTraceId.value = traceId;
  }

  /// Pushes the accumulated frame numbers into Rx, honouring the throttle.
  void _publishThrottled() {
    final now = DateTime.now();
    final last = _lastPublish;
    if (last != null && now.difference(last) < publishInterval) return;
    _lastPublish = now;
    publishNow();
  }

  /// Forces a publish; the overlay calls this so it never shows stale numbers
  /// after a quiet period.
  void publishNow() {
    framesObserved.value = _frames;
    jankFrames.value = _jank;
    worstFrameMs.value = (_worstUs / 1000).round();
    p50FrameMs.value = percentile(50);
    p95FrameMs.value = percentile(95);
  }

  /// Nearest-rank percentile over the frame window, in milliseconds.
  int percentile(int p) {
    if (_window.isEmpty) return 0;
    final sorted = List<int>.from(_window)..sort();
    final index = ((p / 100) * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  void clear() {
    _frames = 0;
    _jank = 0;
    _worstUs = 0;
    _window.clear();
    _lastPublish = null;
    for (final counter in [
      logCount,
      warnCount,
      errorCount,
      droppedLogCount,
      framesObserved,
      jankFrames,
      worstFrameMs,
      lastFrameMs,
      p50FrameMs,
      p95FrameMs,
      firstFrameMs,
      timeToInteractiveMs,
      requestCount,
      failedRequestCount,
      slowRequestCount,
      lastRequestMs,
      openSpanCount,
    ]) {
      counter.value = 0;
    }
    recentLogs.clear();
    spanMs.clear();
    lastTraceId.value = '';
  }

  @override
  void onClose() {
    clear();
    super.onClose();
  }
}
