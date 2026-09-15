import 'background_task_ids.dart';

/// Pure scheduling rules — no plugins, no channels, unit-testable.
class BackgroundPolicy {
  const BackgroundPolicy._();

  /// Android's WorkManager floor for a periodic worker. A shorter frequency is
  /// silently raised by the OS, so raise it here where it is visible.
  static const Duration minPeriodicFrequency = Duration(minutes: 15);

  static const Duration defaultFrequency = Duration(hours: 1);

  /// iOS kills an app-refresh task that overruns (~30s) and scores it a
  /// failure, which makes BGTaskScheduler wake you less often.
  static const Duration taskBudget = Duration(seconds: 25);

  static Duration clampFrequency(Duration requested) =>
      requested < minPeriodicFrequency ? minPeriodicFrequency : requested;

  /// workmanager names a legacy iOS background-fetch wakeup itself
  /// (`iOSPerformFetch`). Matching the prefix survives that constant changing.
  static bool isIosSystemTask(String taskName) => taskName.startsWith('iOS');

  /// Maps an incoming task name onto a registered handler key, or null when
  /// nothing can run it — a task queued by an older build, most likely.
  ///
  /// Handles all three spellings the platforms use: the task name (Android, and
  /// iOS one-off), the uniqueName (iOS periodic and processing), and the iOS
  /// background-fetch name.
  static String? resolveTaskName(String incoming, Set<String> known) {
    if (known.contains(incoming)) return incoming;

    final alias = BackgroundTasks.uniqueNameAliases[incoming];
    if (alias != null && known.contains(alias)) return alias;

    if (isIosSystemTask(incoming) && known.contains(BackgroundTasks.iosFallback)) {
      return BackgroundTasks.iosFallback;
    }
    return null;
  }
}
