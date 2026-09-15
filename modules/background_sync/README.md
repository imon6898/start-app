# background_sync

Background execution: work that runs when your app is closed. A `GetxService` over [`workmanager`](https://pub.dev/packages/workmanager) that registers periodic tasks, deferred one-offs and iOS processing tasks with real constraints (network required, charging, battery-not-low), a correctly shaped background entry point, a handler registry that rebuilds the background isolate from nothing, and a SharedPreferences mailbox so the UI can show what the last run actually did.

**Read this first — the honest version of what background execution gives you.**

- **iOS gives you no guarantee at all.** `BGTaskScheduler` decides when a periodic task runs based on how the user actually uses the app. It may run in 20 minutes, in two days, or never. There is no way to force it and no API to ask why.
- **Android's floor is 15 minutes**, and Doze, App Standby buckets and OEM battery managers routinely stretch that to hours. A device in the `restricted` bucket runs your job approximately never.
- **On iOS a one-off task is not really background work.** It rides `UIApplication.beginBackgroundTask`, so it dies with the app. Only periodic (`BGAppRefreshTask`) and processing (`BGProcessingTask`) tasks survive termination there.
- Therefore: **design for eventual execution.** A background task is an *optimisation* — "the data was already fresh when they opened the app". It is never the mechanism that makes a feature correct. If something must happen, it happens on the server, or on next launch in the foreground.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/background/background_task_service.dart` | `BackgroundTaskService` — the `GetxService`: init, `schedulePeriodicSync`, `scheduleOneOff`, `scheduleProcessing`, `cancel`/`cancelAll`, `statusOf`, and an `Rx<BackgroundRunInfo>` of the last run. |
| `lib/app/services/background/background_dispatcher.dart` | `backgroundCallbackDispatcher` — the top-level `@pragma('vm:entry-point')` entry point, plus the `onTaskStopped` hook. |
| `lib/app/services/background/background_handlers.dart` | **The file you edit.** `prepareBackgroundIsolate()`, `withBudget()`, and the three task handlers. |
| `lib/app/services/background/background_task_ids.dart` | `BackgroundTasks` — task names, unique names / BGTaskScheduler identifiers, the iOS alias map, `inputData` keys. Shared verbatim by both isolates. |
| `lib/app/services/background/background_policy.dart` | `BackgroundPolicy` — pure rules: frequency clamp, task-name resolution across the three platform spellings, the iOS time budget. |
| `lib/app/services/background/background_run_log.dart` | `BackgroundRunLog` + `BackgroundRunInfo` + `BackgroundOutcome` — the cross-isolate mailbox. |
| `lib/app/widgets/feedback/background_sync_tile.dart` | `BackgroundSyncTile` — settings row showing the last run, with a "Run now" button. |
| `test/unit/background_sync_test.dart` | 15 tests: frequency clamping, the three task-name spellings, run-log encoding and counters. No workmanager, no channels, no network. |

## Install

```bash
dart run tool/add_module.dart background_sync
flutter pub get
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
cp modules/background_sync/lib/app/services/background/*.dart              lib/app/services/background/
cp modules/background_sync/lib/app/widgets/feedback/background_sync_tile.dart lib/app/widgets/feedback/
cp modules/background_sync/test/unit/background_sync_test.dart             test/unit/
```

### pubspec.yaml

```yaml
dependencies:
  workmanager: ^0.10.10
```

`workmanager` is federated as of 0.9: `flutter pub get` pulls `workmanager_android`, `workmanager_apple` and the platform interface on its own. **Do not** list them yourself.

## Platform config

### Android

**1. `android/app/src/main/AndroidManifest.xml`** — release builds need `INTERNET`; only the debug and profile manifests declare it today. Above `<application>`:

```xml
    <uses-permission android:name="android.permission.INTERNET"/>
```

**2. `minSdk` 23 or higher.** `workmanager_android` requires it; the Flutter default (`flutter.minSdkVersion`) already satisfies this, so there is usually nothing to change.

**3. Nothing else — but know what arrives on its own.** The plugin's manifest is merged into yours and declares `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_SHORT_SERVICE`; `androidx.work` adds `WAKE_LOCK` and `RECEIVE_BOOT_COMPLETED` (which is what reschedules periodic work after a reboot). If a Play Store listing review asks about those permissions, that is where they come from. No custom `Application` class is needed.

**4. Do not disable `androidx.startup`'s `InitializationProvider`.** Some plugin guides tell you to add `tools:node="remove"` to it. That stops WorkManager from ever initialising, and then no task runs, with no error anywhere.

### iOS

**1. Bump the deployment target to 14.0.** `workmanager_apple` declares `ios.deployment_target = '14.0'`; the template currently ships 13.0. Both places:

```ruby
# ios/Podfile — uncomment and raise
platform :ios, '14.0'
```

Xcode > Runner target > General > Minimum Deployments > iOS 14.0. Then `cd ios && pod install`.

**2. `ios/Runner/Info.plist`** — both keys. iOS rejects a `BGTaskScheduler` identifier that is not listed here:

```xml
	<key>UIBackgroundModes</key>
	<array>
		<string>fetch</string>
		<string>processing</string>
	</array>
	<key>BGTaskSchedulerPermittedIdentifiers</key>
	<array>
		<string>com.easital.starter.periodicSync</string>
		<string>com.easital.starter.processing</string>
	</array>
```

These strings must equal the `uniqueName` constants in `BackgroundTasks`. If you change the bundle id, change both.

**3. Xcode capability.** Runner target > Signing & Capabilities > **+ Capability** > **Background Modes**, then tick **Background fetch** and **Background processing**. (This writes `UIBackgroundModes` for you; step 2 exists because `BGTaskSchedulerPermittedIdentifiers` has no checkbox.)

**4. `ios/Runner/AppDelegate.swift`** — two required calls. The full file for this project's shape:

```swift
import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // This app uses the UIScene lifecycle, so Flutter registers plugins during
    // scene connection — too late for BGTaskScheduler, which only delivers a
    // task if its launch handler was registered inside didFinishLaunching.
    WorkmanagerPlugin.registerLaunchHandlers()

    // Gives the headless background engine its plugins. Without it every
    // channel call inside a handler fails (SharedPreferences, Dio, …).
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
```

`registerLaunchHandlers()` is the one people miss. The plugin re-registers handlers from its own persisted state in its `application(_:didFinishLaunchingWithOptions:)` callback — but a UIScene app (this one: `Info.plist` has `UIApplicationSceneManifest` and a `SceneDelegate`) registers plugins after `didFinishLaunching` has already returned. Without the explicit call, a relaunched app silently never receives its scheduled task.

If `import workmanager_apple` does not resolve, check the module name in `ios/Pods` — it was `workmanager` before the 0.9 federation split.

## Wiring

One core file changes: `lib/bootstrap.dart`. (Plus the two localisation maps, if you keep the widget.)

**1. Imports** — next to the existing ones:

```dart
import 'package:get/get.dart';
import 'app/services/background/background_task_service.dart';
```

**2. Register and schedule**, inside `bootstrap()`, after `await CacheManager.init();` and before `ViewModelBinding().dependencies();`:

```dart
    // Background execution. initialize() only registers the entry point; it
    // schedules nothing on its own.
    final background = await Get.putAsync(
      () => BackgroundTaskService().init(),
      permanent: true,
    );
    // Safe on every launch: the Android policy is `update`, which keeps the
    // existing period instead of restarting it.
    unawaited(
      background.schedulePeriodicSync(frequency: const Duration(hours: 1)),
    );
```

`unawaited` is already imported (`dart:async`). `init()` swallows its own failures, so a device without the plugin — or a `testWidgets` run — boots normally; every later call then no-ops through `_ready()`. Nothing goes into `ViewModelBinding`: `BackgroundTaskService` is a `GetxService`, not a screen controller, so `test/guardrails/bindings_test.dart` does not ask for it.

**3. Write the actual work.** `lib/app/services/background/background_handlers.dart` ships three handlers with `TODO` bodies. Filling them in is the install — see [Usage](#usage) and [Pairing with offline_first](#pairing-with-offline_first).

**4. Localisation — required if you keep the tile.** `test/guardrails/localization_test.dart` fails on a `.tr` literal with no entry, and on any locale whose key set differs. Add to `lib/app/localization/locales/en_us.dart`:

```dart
  // Background sync
  'Background sync': 'Background sync',
  'Never run': 'Never run',
  'Run now': 'Run now',
  'Succeeded': 'Succeeded',
  'Will retry': 'Will retry',
  'Failed': 'Failed',
  'Stopped by the system': 'Stopped by the system',
```

And to `lib/app/localization/locales/bn_bd.dart`:

```dart
  // Background sync
  'Background sync': 'ব্যাকগ্রাউন্ড সিঙ্ক',
  'Never run': 'কখনও চলেনি',
  'Run now': 'এখনই চালান',
  'Succeeded': 'সফল হয়েছে',
  'Will retry': 'আবার চেষ্টা করা হবে',
  'Failed': 'ব্যর্থ হয়েছে',
  'Stopped by the system': 'সিস্টেম বন্ধ করে দিয়েছে',
```

Deleting `background_sync_tile.dart` instead is fine — nothing under `lib/app/services/background/` imports it.

**5. Optional — sign-out.** A queued task still carries the previous account's work:

```dart
await Get.find<BackgroundTaskService>().cancelAll();
```

**6. Optional — the widget barrel.** To reach the tile through `package:flutter_starter/app/widgets/widgets.dart`, add one line to `lib/app/widgets/feedback/feedback.dart`:

```dart
export 'background_sync_tile.dart';
```

## Usage

### The two mistakes that cost a day each

**1. The entry point must be top-level and carry the pragma.**

```dart
// Correct — and already shipped in background_dispatcher.dart.
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async { /* … */ });
}

// All three of these compile, pass review, work in debug, and never run in release:
void main() {
  Workmanager().initialize(() { /* closure */ });          // no
}
class Foo { static void dispatcher() { /* … */ } }          // no
@pragma('vm:entry-point') class Foo { void run() {} }       // no — must be a function
```

The native side looks the callback up by its Dart entry-point handle. Nothing in your Dart code calls it, so without `@pragma('vm:entry-point')` the AOT tree shaker removes it, and the only symptom is that background tasks stop happening in release builds.

**2. The background isolate shares nothing with your app.**

It is a fresh isolate in a fresh engine. `Get` is empty. No controller exists. `CacheManager`'s `SharedPreferences` handle is not warm. `dotenv` is unloaded, so `ApiConstant.activeBaseUrl` throws. `bootstrap()` never ran. That is what `prepareBackgroundIsolate()` is for:

```dart
Future<void> prepareBackgroundIsolate() async {
  WidgetsFlutterBinding.ensureInitialized();   // rootBundle (dotenv) + channels
  DartPluginRegistrant.ensureInitialized();    // registers plugins for THIS isolate
  await CacheManager.init();
  try {
    await Env.load();
  } on EnvException catch (e) {
    devPrint('background: .env unavailable — ${e.message}');
  }
}
```

Call it first in every handler. Anything you want the UI to know afterwards has to be written to disk — see [The cross-isolate mailbox](#the-cross-isolate-mailbox).

### Writing a handler

```dart
Future<bool> syncOutboxTask(Map<String, dynamic>? inputData) async {
  await prepareBackgroundIsolate();

  final token = CacheManager.token;
  if (token == null || token.isEmpty) {
    // Signed out: nothing to push, and retrying cannot change that.
    await BackgroundRunLog.record(
      task: BackgroundTasks.syncOutbox,
      outcome: BackgroundOutcome.success,
      message: 'no session',
    );
    return true;
  }

  return withBudget(() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstant.activeBaseUrl,
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 10),
      ));
      await dio.post('/sync', data: {...});

      await BackgroundRunLog.record(
        task: BackgroundTasks.syncOutbox,
        outcome: BackgroundOutcome.success,
      );
      return true;
    } catch (e) {
      await BackgroundRunLog.record(
        task: BackgroundTasks.syncOutbox,
        outcome: BackgroundOutcome.retry,
        message: '$e',
      );
      return false;   // Android retries with the exponential backoff policy
    }
  });
}
```

**A bare `Dio`, not `ApiService`.** `ApiService` calls `showCustomSnackBar(context: Get.context!, …)` when its connectivity check fails, and `Get.context` is `null` in the background isolate. That is a crash, which the OS records as a failed task — and on iOS a failed task makes `BGTaskScheduler` wake you *less* often. The token-refresh interceptor is equally unusable there: on refresh failure it navigates to the sign-in route.

`withBudget` time-boxes the body (25s by default). iOS hard-kills an app-refresh task that overruns ~30 seconds; returning `false` yourself is strictly better than being killed.

### Registering a new task

Three places, all in `lib/app/services/background/`:

```dart
// 1. background_task_ids.dart — the name, and the iOS alias if it gets its own slot.
static const String uploadPhotos = 'uploadPhotos';
static const String uploadId = 'com.easital.starter.uploadPhotos';
static const Map<String, String> uniqueNameAliases = {
  // …
  uploadId: uploadPhotos,
};

// 2. background_handlers.dart — the handler, and the registry entry.
Map<String, BackgroundHandler> backgroundHandlers() => {
  // …
  BackgroundTasks.uploadPhotos: uploadPhotosTask,
};

// 3. Info.plist — add uploadId to BGTaskSchedulerPermittedIdentifiers.
```

### Scheduling

```dart
final background = BackgroundTaskService.to;

// Recurring. 15 min floor on Android; iOS ignores `frequency` and treats
// `initialDelay` as BGTaskScheduler's earliest-begin hint.
await background.schedulePeriodicSync(
  frequency: const Duration(hours: 6),
  requiresNetwork: true,
  requiresBatteryNotLow: true,
  requiresCharging: false,
);

// Deferred one-shot. Real WorkManager work on Android; app-lifetime only on iOS.
await background.scheduleOneOff(
  task: BackgroundTasks.refreshContent,
  uniqueName: 'com.easital.starter.refresh',
  initialDelay: const Duration(minutes: 30),
  inputData: {BackgroundTasks.keyReason: 'pull_to_refresh'},
);

// Long, idle-time work. BGProcessingTask on iOS; a plain one-off on Android.
await background.scheduleProcessing(requiresCharging: true);

// "Sync soon" — queued like anything else, NOT immediate.
await background.requestSyncSoon(reason: 'manual');

// Teardown.
await background.cancel(BackgroundTasks.periodicSyncId);
await background.cancelAll();                 // sign-out
```

`inputData` crosses a platform channel: `int`, `bool`, `double`, `String` and lists of those. Anything else must be a JSON string — an `assert` catches it in debug.

### The cross-isolate mailbox

`SharedPreferences` is the only state both isolates see, and each isolate caches it in memory, so the UI isolate needs a `reload()` to notice a background write. `BackgroundRunLog` does that on every read, and `BackgroundTaskService` refreshes on app resume:

```dart
await BackgroundRunLog.record(
  task: BackgroundTasks.syncOutbox,
  outcome: BackgroundOutcome.success,
  message: 'pushed 3',
);

// In the UI isolate:
final info = BackgroundTaskService.to.lastRun.value;
info.outcome;        // success | retry | failure | stopped
info.at;             // DateTime? — null means "never ran on this device"
info.runCount;       // lifetime counters: the only honest proof the OS wakes you
info.failureCount;
```

`reload()` is process-wide — it refreshes `CacheManager`'s view of the same store too. That is harmless (it pulls the truth from disk) but worth knowing.

### The UI

```dart
// In a settings screen body:
const BackgroundSyncTile(showCounters: true),
```

It hides itself when the service is not registered or the platform has no scheduler. Or read the state directly:

```dart
Obx(() {
  final info = BackgroundTaskService.to.lastRun.value;
  return Text(
    info.hasRun ? '${info.runCount} runs' : 'Never run'.tr,
    style: CustomTextStyles.regular12.gray,
  );
});
```

And WorkManager's own view, when you need more than the last result:

```dart
final work = await BackgroundTaskService.to.statusOf(BackgroundTasks.periodicSyncId);
work?.state;   // scheduled | running | succeeded | failed | cancelled
```

Authoritative on Android. On iOS it is the plugin's own best-effort record, because `BGTaskScheduler` has no query API. `isScheduled()` is Android-only and returns `false` elsewhere — which is *not* the same as "not queued".

## How to test it

You cannot wait for the OS. Trigger it.

### Android

```bash
# What is actually queued, and in which state.
adb shell dumpsys jobscheduler | grep -A 25 com.easital.starter

# Ask WorkManager to dump its own diagnostics, then read them back.
adb shell am broadcast -a "androidx.work.diagnostics.REQUEST_DIAGNOSTICS" \
  -p com.easital.starter
adb logcat -d -s WM-DiagnosticsWrkr

# Force-run a queued job. Take <jobId> from the dumpsys output above.
adb shell cmd jobscheduler run -f com.easital.starter <jobId>

# Simulate the hostile cases.
adb shell dumpsys deviceidle force-idle          # Doze
adb shell am set-standby-bucket com.easital.starter restricted
adb shell cmd appops set com.easital.starter RUN_ANY_IN_BACKGROUND ignore
```

`-f` in `jobscheduler run` means "ignore the constraints", so a run that only succeeds with `-f` tells you a constraint is never being met.

### iOS

Simulator and device both need the debugger, because `BGTaskScheduler` will not deliver on demand. Launch the app, background it (Cmd+Shift+H), pause in Xcode, then:

```
(lldb) e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.easital.starter.periodicSync"]
```

Continue, and the handler runs. Same call with `_simulateExpirationForTaskWithIdentifier:` to test what happens when iOS pulls the plug mid-task. To see what the plugin thinks is queued:

```dart
devPrint(await Workmanager().printScheduledTasks());   // iOS 13+ only
```

Xcode's **Debug > Simulate Background Fetch** exercises the legacy background-fetch path only, which is disabled once `BGTaskSchedulerPermittedIdentifiers` exists — so on this setup it will not fire your periodic task.

### The one thing you must test on a real device

Run counters. Ship the tile with `showCounters: true` to a physical phone for two days of normal use and look at `runCount`. Everything else is a simulation; that number is the truth about whether the OS ever wakes your app.

## Behaviour, exactly

**Constraints.** `Constraints(networkType:, requiresCharging:, requiresBatteryNotLow:)`. Android honours all of them. **iOS reads only `networkType` and `requiresCharging`** — `requiresBatteryNotLow` is silently ignored there. A constraint that is never satisfied means a task that never runs, with no error: `requiresCharging: true` on a phone that lives at 80% on a desk is a real way to lose a feature.

**Periodic re-registration.** `ExistingPeriodicWorkPolicy.update`, so calling `schedulePeriodicSync()` on every launch preserves the existing period. `replace` would restart it, and an app the user opens every ten minutes would then never reach its first run. iOS needs the request resubmitted anyway, so "call it every launch" is the right shape on both.

**Frequency clamp.** Anything under 15 minutes is raised to 15 in Dart, with a `devPrint`, instead of being silently raised by Android where you cannot see it.

**Retries.** Returning `false` from a handler makes Android retry with `BackoffPolicy.exponential` from a 1 minute base (30s for one-offs). **iOS ignores the return value entirely** — to retry there you must schedule another task yourself.

**Task names arrive spelled three different ways.** Android sends the `taskName`. An iOS one-off also sends the `taskName`. An iOS periodic or processing task sends the **`uniqueName`**, because that is the `BGTaskScheduler` identifier. A legacy iOS background-fetch wakeup sends `iOSPerformFetch`. `BackgroundPolicy.resolveTaskName` maps all four onto a handler key via `BackgroundTasks.uniqueNameAliases` plus an `iOS`-prefix fallback. **Keep that alias map in sync when you add a task**, or your iOS periodic task will be resolved to `null` and dropped.

**An unknown task is dropped, not retried.** A task queued by an older build has no handler here. The dispatcher returns `true` so Android forgets it, rather than retrying forever something nothing can run.

**`onTaskStopped`.** Android tells us when WorkManager killed a running worker — timeout, preempted, Doze, App Standby, background restriction. The dispatcher records it as `BackgroundOutcome.stopped` with the reason, which is how you find out the OS is throttling you. iOS has no equivalent.

**`cancelByTag` is a no-op on iOS.** `cancelAll()` therefore cancels each known `uniqueName` first and only then falls back to the tag for anything else tagged on Android.

**Time budget.** `withBudget` defaults to 25s against iOS's ~30s app-refresh allowance. A processing task gets minutes instead, so raise the limit for those explicitly.

## Pairing with offline_first

This is what the module exists for: drain the outbox while the app is closed. Replace `syncOutboxTask`'s body with:

```dart
import 'package:flutter_starter/app/feature/notes/notes_logic/notes_sync_transport.dart';
import 'package:flutter_starter/app/services/domain/api_service.dart';
import 'package:flutter_starter/app/services/sync/drift/drift_sync_store.dart';
import 'package:flutter_starter/app/services/sync/sync_service.dart';
import 'package:get/get.dart';

Future<bool> syncOutboxTask(Map<String, dynamic>? inputData) async {
  await prepareBackgroundIsolate();

  final token = CacheManager.token;
  if (token == null || token.isEmpty) return true;

  return withBudget(() async {
    final store = DriftSyncStore();
    try {
      await store.init();
      // Get works here — it is plain Dart — but it is a FRESH container.
      final sync = Get.put(SyncService(store: store, isOnline: checkInternet));
      sync.register(NotesSyncTransport.collection, NotesSyncTransport());

      final ok = await sync.syncNow();
      await BackgroundRunLog.record(
        task: BackgroundTasks.syncOutbox,
        outcome: ok ? BackgroundOutcome.success : BackgroundOutcome.retry,
        message: 'pending ${sync.pendingCount.value}',
      );
      return ok;
    } catch (e) {
      await BackgroundRunLog.record(
        task: BackgroundTasks.syncOutbox,
        outcome: BackgroundOutcome.retry,
        message: '$e',
      );
      return false;
    } finally {
      await Get.delete<SyncService>();
      await store.close();
    }
  });
}
```

Then, in the UI isolate, refresh after a background run so the screen is not showing a stale outbox depth — `BackgroundTaskService` already re-reads its own log on resume, but `SyncService` has its own counters:

```dart
// Wherever you handle resume, e.g. after background.refreshLastRun():
await Get.find<SyncService>().syncNow();
```

**The sqlite caveat, plainly.** `sync.sqlite` is one file and this opens it from a second isolate. SQLite locks correctly, but with the default journal mode a writer blocks and you get `SqliteException(5): database is locked` if the app happens to be running. Three mitigations, in order of preference:

1. Enable WAL once, in `SyncDatabase`'s migration or `beforeOpen`: `await customStatement('PRAGMA journal_mode=WAL');`. Readers and one writer then coexist.
2. Keep the background transaction short — `withBudget` already forces this.
3. Treat a lock error as a retry (return `false`), which the `catch` above already does. A background sync that loses the race and runs 15 minutes later is a non-event.

`api_resilience` does **not** apply to the `Dio` that `SyncService` builds inside this isolate unless you add its interceptor there too — interceptors are per-`Dio`, and nothing bootstrap() configured exists here.

## What this does NOT give you

- **No guaranteed execution, on either platform.** Android promises "eventually, subject to constraints and Doze"; iOS promises nothing at all. There is no API anywhere that means "run in exactly 15 minutes".
- **No sub-15-minute periodic work.** If you need a tighter loop the answer is a foreground service with a visible notification (Android) or a server-driven silent push, not this.
- **A force-stop kills everything.** If the user force-stops the app from Settings, Android cancels its queued work and (on 12+) drops the app into the `restricted` bucket. Nothing runs again until the user opens the app.
- **OEM battery managers are not covered by any of the above.** Xiaomi, Huawei, Oppo and Samsung ship killers that ignore the documented WorkManager contract. See [dontkillmyapp.com](https://dontkillmyapp.com). There is no code fix; the fix is asking the user to allow-list your app.
- **The background isolate is not your app.** No `Get`, no controllers, no navigation, no snackbars, no `BuildContext`. Anything you touch there must be re-initialised, and anything you learn there must be written to disk.
- **Not a scheduler for user-visible timing.** "Remind me at 9am" is a local notification, not a background task.
- **Nothing here is secure.** A background task runs with the same plaintext `SharedPreferences` token the app uses. Pair with `secure_storage` if that matters; note its README's warning about sync mirrors.
- **iOS one-offs do not survive termination.** They are `beginBackgroundTask` work. Use `schedulePeriodicSync` or `scheduleProcessing` for anything that must outlive the process there.

## Notes and gotchas

- `initialize(isInDebugMode:)` is deprecated in workmanager 0.10 and has **no effect**; this module does not pass it. Debug notifications are configured on the native side now (`WorkmanagerDebug`), not from Dart.
- `Workmanager().initialize()` must happen before any `register*` call — the native side validates the stored callback handle and fails the registration otherwise. `_ready()` guards every method, and logs when it refuses.
- `BackgroundTaskService.init()` never rethrows. A missing plugin, a simulator, or a `testWidgets` run leaves `_initialized` false and every later call becomes a logged no-op, so `app_boot_test.dart` keeps passing with the bootstrap wiring in place.
- `isSupported` is Android + iOS only. workmanager also ships experimental web (service worker) and Linux (systemd) backends; widen that getter if you want them.
- Renaming a task name or a unique name orphans whatever an older build already queued. The old task keeps firing until the OS gives up, and lands in the dispatcher's "no handler" branch. That is why the dispatcher returns `true` there.
- `DartPluginRegistrant.ensureInitialized()` is from `dart:ui`. `executeTask` already calls `WidgetsFlutterBinding.ensureInitialized()` internally, but `prepareBackgroundIsolate()` calls both explicitly — it is idempotent, and being explicit is cheaper than debugging a `MissingPluginException` in a log you cannot attach a debugger to.
- The run log is a single JSON string under one key, and a malformed value decodes to an empty `BackgroundRunInfo` instead of throwing. A handler must never die because an older build wrote a different shape.
- `flutter test test/unit/background_sync_test.dart` — 15 tests over `BackgroundPolicy` and `BackgroundRunLog` with `SharedPreferences.setMockInitialValues`. No workmanager import, so nothing there needs a device.
- Verified against `workmanager 0.10.10`, `workmanager_android 0.10.9`, `workmanager_apple 0.9.11`, `workmanager_platform_interface 0.10.5`. If `pub` resolves something older, expect `NetworkType.not_required` instead of `notRequired`, `ExistingWorkPolicy` where `ExistingPeriodicWorkPolicy` is used, and no `onTaskStopped` / `getWorkInfo` / `registerProcessingTask`.

## Why it is not in core

Background execution is a platform negotiation, not a library call. It needs `Info.plist` identifiers, an Xcode capability, a raised iOS deployment target, two `AppDelegate` lines, and an `AndroidManifest` permission — none of which a starter template should force on a project that will never schedule a task. It also drags in `androidx.work` and a handful of permissions that show up in a Play Store review.

More importantly, it is the one feature most likely to be wired up wrong and believed anyway: a missing `@pragma('vm:entry-point')` works perfectly in debug, and a handler that reaches for `Get.find<SomeController>()` looks completely reasonable until it runs in an isolate where nothing exists. That deserves a README you read before you trust it — which is exactly what a module is, and what a default is not.
