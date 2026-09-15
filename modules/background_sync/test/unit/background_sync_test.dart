import 'package:flutter_starter/app/services/background/background_policy.dart';
import 'package:flutter_starter/app/services/background/background_run_log.dart';
import 'package:flutter_starter/app/services/background/background_task_ids.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No workmanager, no platform channels: only the pure policy and the
/// SharedPreferences mailbox the two isolates talk through.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundPolicy.clampFrequency', () {
    test('raises anything under the 15 minute OS floor', () {
      expect(
        BackgroundPolicy.clampFrequency(const Duration(minutes: 1)),
        BackgroundPolicy.minPeriodicFrequency,
      );
      expect(
        BackgroundPolicy.clampFrequency(Duration.zero),
        BackgroundPolicy.minPeriodicFrequency,
      );
    });

    test('leaves a legal frequency alone', () {
      expect(
        BackgroundPolicy.clampFrequency(const Duration(hours: 6)),
        const Duration(hours: 6),
      );
      expect(
        BackgroundPolicy.clampFrequency(const Duration(minutes: 15)),
        const Duration(minutes: 15),
      );
    });
  });

  group('BackgroundPolicy.resolveTaskName', () {
    final known = {BackgroundTasks.syncOutbox, BackgroundTasks.cleanupCache};

    test('passes a known task through', () {
      expect(
        BackgroundPolicy.resolveTaskName(BackgroundTasks.cleanupCache, known),
        BackgroundTasks.cleanupCache,
      );
    });

    test('maps a uniqueName onto its task — iOS periodic spelling', () {
      expect(
        BackgroundPolicy.resolveTaskName(BackgroundTasks.periodicSyncId, known),
        BackgroundTasks.syncOutbox,
      );
      expect(
        BackgroundPolicy.resolveTaskName(BackgroundTasks.processingId, known),
        BackgroundTasks.cleanupCache,
      );
    });

    test('maps a legacy iOS background fetch onto the fallback task', () {
      expect(
        BackgroundPolicy.resolveTaskName('iOSPerformFetch', known),
        BackgroundTasks.iosFallback,
      );
    });

    test('returns null for a task no handler can run', () {
      expect(BackgroundPolicy.resolveTaskName('taskFromOldBuild', known), isNull);
    });

    test('does not invent a fallback that is not registered', () {
      expect(
        BackgroundPolicy.resolveTaskName('iOSPerformFetch', {
          BackgroundTasks.cleanupCache,
        }),
        isNull,
      );
    });

    test('every alias points at a task some handler can claim', () {
      for (final task in BackgroundTasks.uniqueNameAliases.values) {
        expect(
          const [
            BackgroundTasks.syncOutbox,
            BackgroundTasks.refreshContent,
            BackgroundTasks.cleanupCache,
          ],
          contains(task),
        );
      }
    });
  });

  group('BackgroundRunInfo', () {
    test('survives a map round trip', () {
      final at = DateTime.utc(2026, 3, 4, 5, 6, 7);
      final info = BackgroundRunInfo(
        task: BackgroundTasks.syncOutbox,
        outcome: BackgroundOutcome.retry,
        at: at,
        message: 'timeout',
        runCount: 9,
        failureCount: 2,
      );

      final decoded = BackgroundRunInfo.fromMap(info.toMap());

      expect(decoded.task, BackgroundTasks.syncOutbox);
      expect(decoded.outcome, BackgroundOutcome.retry);
      expect(decoded.at, at);
      expect(decoded.message, 'timeout');
      expect(decoded.runCount, 9);
      expect(decoded.failureCount, 2);
      expect(decoded.hasRun, isTrue);
    });

    test('tolerates a map written by an older shape', () {
      final decoded = BackgroundRunInfo.fromMap(const {'outcome': 'gone'});

      expect(decoded.outcome, isNull);
      expect(decoded.at, isNull);
      expect(decoded.hasRun, isFalse);
      expect(decoded.runCount, 0);
    });
  });

  group('BackgroundRunLog', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('starts empty', () async {
      final info = await BackgroundRunLog.read();

      expect(info.hasRun, isFalse);
      expect(info.runCount, 0);
    });

    test('record round-trips through the store', () async {
      await BackgroundRunLog.record(
        task: BackgroundTasks.syncOutbox,
        outcome: BackgroundOutcome.success,
        message: 'pushed 3',
      );

      final info = await BackgroundRunLog.read();

      expect(info.task, BackgroundTasks.syncOutbox);
      expect(info.outcome, BackgroundOutcome.success);
      expect(info.message, 'pushed 3');
      expect(info.hasRun, isTrue);
    });

    test('counts runs, and failures separately', () async {
      await BackgroundRunLog.record(
        task: BackgroundTasks.syncOutbox,
        outcome: BackgroundOutcome.success,
      );
      await BackgroundRunLog.record(
        task: BackgroundTasks.syncOutbox,
        outcome: BackgroundOutcome.retry,
      );
      await BackgroundRunLog.record(
        task: BackgroundTasks.syncOutbox,
        outcome: BackgroundOutcome.failure,
      );

      final info = await BackgroundRunLog.read();

      expect(info.runCount, 3);
      expect(info.failureCount, 2);
      expect(info.outcome, BackgroundOutcome.failure);
    });

    test('clear wipes the log', () async {
      await BackgroundRunLog.record(
        task: BackgroundTasks.cleanupCache,
        outcome: BackgroundOutcome.success,
      );

      await BackgroundRunLog.clear();

      expect((await BackgroundRunLog.read()).hasRun, isFalse);
    });

    test('a stopped run counts as a failure', () async {
      await BackgroundRunLog.record(
        task: BackgroundTasks.syncOutbox,
        outcome: BackgroundOutcome.stopped,
        message: 'timeout',
      );

      final info = await BackgroundRunLog.read();

      expect(info.outcome, BackgroundOutcome.stopped);
      expect(info.failureCount, 1);
      expect(info.message, 'timeout');
    });
  });
}
