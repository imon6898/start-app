// THIS IS THE FILE YOU EDIT. Every function here runs in the BACKGROUND
// isolate: no Get, no controllers, no warm caches. Re-init what you touch.

import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_starter/app/core/config/env.dart';
import 'package:flutter_starter/app/services/domain/api_const.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:flutter_starter/app/services/local_data/cache_manager.dart';

import 'background_policy.dart';
import 'background_run_log.dart';
import 'background_task_ids.dart';

/// Returns true when the work is done, false to let Android retry it.
typedef BackgroundHandler = Future<bool> Function(Map<String, dynamic>? inputData);

/// Task name -> handler. The key must match the name you schedule with.
Map<String, BackgroundHandler> backgroundHandlers() => {
  BackgroundTasks.syncOutbox: syncOutboxTask,
  BackgroundTasks.refreshContent: refreshContentTask,
  BackgroundTasks.cleanupCache: cleanupCacheTask,
};

/// Rebuilds, in this isolate, the startup state `bootstrap()` builds in the UI
/// one. Cheap and idempotent — call it first in every handler.
Future<void> prepareBackgroundIsolate() async {
  // Needed for rootBundle (dotenv) and for plugin channels to have a binding.
  WidgetsFlutterBinding.ensureInitialized();
  // Registers plugins for THIS isolate; without it every channel call fails.
  DartPluginRegistrant.ensureInitialized();

  await CacheManager.init();

  try {
    await Env.load();
  } on EnvException catch (e) {
    // ApiConstant.activeBaseUrl throws without .env, so fail the task cleanly.
    devPrint('background: .env unavailable — ${e.message}');
  }
}

/// Time-boxes a handler. An overrun is a hard kill on iOS and counts against
/// how often BGTaskScheduler wakes you again.
Future<bool> withBudget(
  Future<bool> Function() body, {
  Duration limit = BackgroundPolicy.taskBudget,
}) => body().timeout(
  limit,
  onTimeout: () {
    devPrint('background: budget of ${limit.inSeconds}s exceeded');
    return false;
  },
);

/// Pushes queued writes. Replace the body — the README has the offline_first
/// version, which drains that module's outbox.
Future<bool> syncOutboxTask(Map<String, dynamic>? inputData) async {
  await prepareBackgroundIsolate();

  // Signed out: nothing to push, and retrying cannot change that.
  final token = CacheManager.token;
  if (token == null || token.isEmpty) {
    await BackgroundRunLog.record(
      task: BackgroundTasks.syncOutbox,
      outcome: BackgroundOutcome.success,
      message: 'no session',
    );
    return true;
  }

  return withBudget(() async {
    try {
      // TODO(app): do the actual work here. Use a bare Dio, not ApiService —
      // see the README: ApiService shows a snackbar on Get.context! when
      // offline, which is null in this isolate.
      devPrint('background: sync against ${ApiConstant.activeBaseUrl}');

      await BackgroundRunLog.record(
        task: BackgroundTasks.syncOutbox,
        outcome: BackgroundOutcome.success,
        message: inputData?[BackgroundTasks.keyReason]?.toString() ?? '',
      );
      return true;
    } catch (e) {
      await BackgroundRunLog.record(
        task: BackgroundTasks.syncOutbox,
        outcome: BackgroundOutcome.retry,
        message: '$e',
      );
      return false;
    }
  });
}

/// Warms whatever the next cold start would otherwise wait for.
Future<bool> refreshContentTask(Map<String, dynamic>? inputData) async {
  await prepareBackgroundIsolate();

  return withBudget(() async {
    try {
      // TODO(app): fetch and cache. Write results to SharedPreferences or the
      // local DB — in-memory state dies with this isolate.
      await BackgroundRunLog.record(
        task: BackgroundTasks.refreshContent,
        outcome: BackgroundOutcome.success,
      );
      return true;
    } catch (e) {
      await BackgroundRunLog.record(
        task: BackgroundTasks.refreshContent,
        outcome: BackgroundOutcome.retry,
        message: '$e',
      );
      return false;
    }
  });
}

/// Local-only housekeeping: no network constraint needed when you schedule it.
Future<bool> cleanupCacheTask(Map<String, dynamic>? inputData) async {
  await prepareBackgroundIsolate();

  return withBudget(() async {
    // TODO(app): prune old rows, expired images, stale tombstones.
    await BackgroundRunLog.record(
      task: BackgroundTasks.cleanupCache,
      outcome: BackgroundOutcome.success,
    );
    return true;
  });
}
