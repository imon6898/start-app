import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:workmanager/workmanager.dart';

import 'background_handlers.dart';
import 'background_policy.dart';
import 'background_run_log.dart';

/// The background isolate's entry point.
///
/// MUST stay a top-level function with `@pragma('vm:entry-point')`. A closure,
/// an instance method or a static method compiles fine and then never runs in
/// release: the tree shaker drops code no Dart call site reaches.
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask(
    (String taskName, Map<String, dynamic>? inputData) async {
      final handlers = backgroundHandlers();
      final resolved = BackgroundPolicy.resolveTaskName(
        taskName,
        handlers.keys.toSet(),
      );

      if (resolved == null) {
        // Queued by an older build. Returning false would make Android retry a
        // task nothing here can ever run.
        devPrint('background: no handler for "$taskName" — dropped');
        return true;
      }

      try {
        return await handlers[resolved]!(inputData);
      } catch (e, stack) {
        devPrint('background: $resolved threw — $e\n$stack');
        await BackgroundRunLog.record(
          task: resolved,
          outcome: BackgroundOutcome.failure,
          message: '$e',
        );
        return false;
      }
    },
    // Android only: WorkManager killed the worker mid-run. Persist and return
    // fast — the engine is torn down as soon as this completes.
    onTaskStopped: (String taskName, StopReason reason) async {
      devPrint('background: $taskName stopped — ${reason.name}');
      await BackgroundRunLog.record(
        task: taskName,
        outcome: BackgroundOutcome.stopped,
        message: reason.name,
      );
    },
  );
}
