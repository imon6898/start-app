import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:get/get.dart';
import 'package:workmanager/workmanager.dart';

import 'background_dispatcher.dart';
import 'background_policy.dart';
import 'background_run_log.dart';
import 'background_task_ids.dart';

/// Schedules OS-level background work and exposes what the last run did.
///
/// Register once, before the first frame:
///   await Get.putAsync(() => BackgroundTaskService().init(), permanent: true);
///
/// Nothing here promises timely execution. The OS decides when — and on iOS,
/// whether — a task runs at all. See the README.
class BackgroundTaskService extends GetxService with WidgetsBindingObserver {
  static BackgroundTaskService get to => Get.find();

  /// Last background result, refreshed on init and on every app resume.
  final Rx<BackgroundRunInfo> lastRun = const BackgroundRunInfo().obs;

  bool _initialized = false;

  /// This module targets Android and iOS. workmanager's web and Linux backends
  /// are experimental; opt in by widening this getter.
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<BackgroundTaskService> init() async {
    if (!isSupported) {
      devPrint('background: unsupported platform — scheduling is a no-op');
      return this;
    }
    try {
      // Only stores the entry point; it schedules nothing on its own.
      await Workmanager().initialize(backgroundCallbackDispatcher);
      _initialized = true;
      WidgetsBinding.instance.addObserver(this);
      await refreshLastRun();
    } catch (e) {
      devPrint('background: initialize failed — $e');
    }
    return this;
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The only moment the UI isolate can learn what the background one did.
    if (state == AppLifecycleState.resumed) refreshLastRun();
  }

  /// Re-reads the cross-isolate log. Safe to call often.
  Future<void> refreshLastRun() async {
    try {
      lastRun.value = await BackgroundRunLog.read();
    } catch (e) {
      devPrint('background: could not read run log — $e');
    }
  }

  /// The recurring task. Safe to call on every launch: the Android policy is
  /// `update`, which keeps the existing period instead of restarting it, and
  /// iOS needs the request resubmitted anyway.
  ///
  /// Android floor is 15 minutes. iOS ignores [frequency] entirely and uses
  /// [initialDelay] as BGTaskScheduler's earliest-begin hint.
  Future<void> schedulePeriodicSync({
    Duration frequency = BackgroundPolicy.defaultFrequency,
    String task = BackgroundTasks.syncOutbox,
    String uniqueName = BackgroundTasks.periodicSyncId,
    bool requiresNetwork = true,
    bool requiresCharging = false,
    bool requiresBatteryNotLow = true,
    Duration initialDelay = const Duration(minutes: 15),
    Map<String, dynamic>? inputData,
  }) async {
    if (!_ready('schedulePeriodicSync')) return;
    _assertPrimitives(inputData);

    final safeFrequency = BackgroundPolicy.clampFrequency(frequency);
    if (safeFrequency != frequency) {
      devPrint(
        'background: frequency raised to ${safeFrequency.inMinutes}m — '
        '15m is the OS floor',
      );
    }

    try {
      await Workmanager().registerPeriodicTask(
        uniqueName,
        task,
        frequency: safeFrequency,
        initialDelay: initialDelay,
        tag: BackgroundTasks.tag,
        // `update` preserves the original timing; `replace` restarts the period
        // on every launch, so a frequently opened app would never fire.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: _constraints(
          requiresNetwork: requiresNetwork,
          requiresCharging: requiresCharging,
          requiresBatteryNotLow: requiresBatteryNotLow,
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 1),
        inputData: inputData,
      );
    } catch (e) {
      devPrint('background: registerPeriodicTask failed — $e');
    }
  }

  /// Deferred one-shot. On Android it is real WorkManager work and survives
  /// termination; on iOS it rides `beginBackgroundTask`, so it only runs while
  /// the app is still alive — see the README.
  Future<void> scheduleOneOff({
    String task = BackgroundTasks.syncOutbox,
    String uniqueName = BackgroundTasks.oneOffSyncId,
    Duration initialDelay = Duration.zero,
    bool requiresNetwork = true,
    bool requiresCharging = false,
    bool requiresBatteryNotLow = false,
    Map<String, dynamic>? inputData,
  }) async {
    if (!_ready('scheduleOneOff')) return;
    _assertPrimitives(inputData);

    try {
      await Workmanager().registerOneOffTask(
        uniqueName,
        task,
        initialDelay: initialDelay,
        tag: BackgroundTasks.tag,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: _constraints(
          requiresNetwork: requiresNetwork,
          requiresCharging: requiresCharging,
          requiresBatteryNotLow: requiresBatteryNotLow,
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
        inputData: inputData,
      );
    } catch (e) {
      devPrint('background: registerOneOffTask failed — $e');
    }
  }

  /// Long, idle-time work. iOS-only in effect (BGProcessingTask); Android maps
  /// it onto ordinary one-off work.
  Future<void> scheduleProcessing({
    String task = BackgroundTasks.cleanupCache,
    String uniqueName = BackgroundTasks.processingId,
    Duration initialDelay = const Duration(hours: 1),
    bool requiresNetwork = false,
    bool requiresCharging = true,
    Map<String, dynamic>? inputData,
  }) async {
    if (!_ready('scheduleProcessing')) return;
    _assertPrimitives(inputData);

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Workmanager().registerProcessingTask(
          uniqueName,
          task,
          initialDelay: initialDelay,
          inputData: inputData,
          constraints: _constraints(
            requiresNetwork: requiresNetwork,
            requiresCharging: requiresCharging,
            requiresBatteryNotLow: false,
          ),
        );
        return;
      }
      await scheduleOneOff(
        task: task,
        uniqueName: uniqueName,
        initialDelay: initialDelay,
        requiresNetwork: requiresNetwork,
        requiresCharging: requiresCharging,
        inputData: inputData,
      );
    } catch (e) {
      devPrint('background: registerProcessingTask failed — $e');
    }
  }

  /// "Sync soon." Still not immediate — the OS queues it like any other task.
  Future<void> requestSyncSoon({String reason = 'manual'}) =>
      scheduleOneOff(inputData: {BackgroundTasks.keyReason: reason});

  /// WorkManager's own view of a task. Android is authoritative; iOS is the
  /// plugin's best-effort record; anything else returns null.
  Future<WorkInfo?> statusOf(String uniqueName) async {
    if (!_ready('statusOf')) return null;
    try {
      return await Workmanager().getWorkInfo(uniqueName);
    } catch (e) {
      devPrint('background: getWorkInfo failed — $e');
      return null;
    }
  }

  /// Android only; false everywhere else, which is not the same as "not queued".
  Future<bool> isScheduled(String uniqueName) async {
    if (!_ready('isScheduled')) return false;
    try {
      return await Workmanager().isScheduledByUniqueName(uniqueName);
    } catch (e) {
      devPrint('background: isScheduledByUniqueName failed — $e');
      return false;
    }
  }

  Future<void> cancel(String uniqueName) async {
    if (!_ready('cancel')) return;
    await Workmanager().cancelByUniqueName(uniqueName);
  }

  /// Everything this module scheduled. Call on sign-out — a queued task still
  /// holds the previous account's work.
  ///
  /// Cancels by unique name first because `cancelByTag` is a documented no-op
  /// on iOS; the tag call then catches anything else tagged on Android.
  Future<void> cancelAll() async {
    if (!_ready('cancelAll')) return;
    for (final uniqueName in BackgroundTasks.uniqueNameAliases.keys) {
      await Workmanager().cancelByUniqueName(uniqueName);
    }
    await Workmanager().cancelByTag(BackgroundTasks.tag);
    await BackgroundRunLog.clear();
    lastRun.value = const BackgroundRunInfo();
  }

  Constraints _constraints({
    required bool requiresNetwork,
    required bool requiresCharging,
    required bool requiresBatteryNotLow,
  }) => Constraints(
    // iOS only reads networkType and requiresCharging; the rest is Android.
    networkType: requiresNetwork ? NetworkType.connected : NetworkType.notRequired,
    requiresCharging: requiresCharging,
    requiresBatteryNotLow: requiresBatteryNotLow,
  );

  bool _ready(String caller) {
    if (!isSupported) return false;
    if (!_initialized) {
      devPrint('background: $caller before init() — ignored');
      return false;
    }
    return true;
  }

  /// inputData crosses a platform channel: int, bool, double, String and lists
  /// of those. Anything else must be encoded as a JSON string.
  void _assertPrimitives(Map<String, dynamic>? data) {
    assert(
      data == null || data.values.every(_isSupportedValue),
      'inputData supports int, bool, double, String and their lists only — '
      'encode anything else as a JSON string.',
    );
  }

  static bool _isSupportedValue(Object? value) =>
      value == null ||
      value is String ||
      value is int ||
      value is double ||
      value is bool ||
      (value is List && value.every(_isSupportedValue));
}
