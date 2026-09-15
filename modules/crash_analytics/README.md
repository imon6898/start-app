# crash_analytics

Crash reporting and error analytics behind a provider-agnostic `GetxService`, with one Sentry implementation and a PII scrubber in front of it. It plugs into the error plumbing `lib/bootstrap.dart` already has instead of installing a second set of handlers.

Off in debug. Off without a DSN. Every call is a silent no-op until both are true.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/crash_service.dart` | `CrashService` (GetxService) + the `CrashReporter` interface + `CrashLevel`. The only file your app code imports. |
| `lib/app/services/crash/sentry_crash_reporter.dart` | The one concrete reporter. The only file that imports `sentry_flutter`. |
| `lib/app/services/crash/crash_pii_scrubber.dart` | `beforeSend` / `beforeBreadcrumb` filters — the last gate before anything leaves the device. |

The interface is four calls:

```dart
CrashService.to.recordError(error, stack, reason: 'checkout', fatal: false, tags: {'flow': 'pay'});
CrashService.to.setUserId(user.id);        // null on logout
CrashService.to.log('cart restored', level: CrashLevel.info);
CrashService.to.addBreadcrumb('tapped pay', category: 'ui', data: {'amount': 4200});
```

Plus `init()`, `shutdown()` and `isEnabled`.

## Install

```bash
dart run tool/add_module.dart crash_analytics
flutter pub get
```

Manual equivalent:

```bash
mkdir -p lib/app/services/crash
cp modules/crash_analytics/lib/app/services/crash_service.dart            lib/app/services/
cp modules/crash_analytics/lib/app/services/crash/sentry_crash_reporter.dart lib/app/services/crash/
cp modules/crash_analytics/lib/app/services/crash/crash_pii_scrubber.dart    lib/app/services/crash/
```

### 1. pubspec.yaml

```yaml
dependencies:
  sentry_flutter: ^9.28.0
```

`get` and `flutter_dotenv` are already in the template core. Optional, for symbol upload only:

```yaml
dev_dependencies:
  sentry_dart_plugin: ^3.4.0
```

### 2. .env and .env.example

Add all three to `.env.example` (with empty values), and the real DSN to `.env`:

```env
# Sentry project DSN. Empty = crash reporting stays off.
SENTRY_DSN=https://examplePublicKey@o0.ingest.sentry.io/0

# Report from debug/profile builds too. Anything but true = release-only.
SENTRY_ENABLE_IN_DEBUG=

# Performance tracing sample rate, 0..1. Empty = 0 = errors only.
SENTRY_TRACES_SAMPLE_RATE=
```

`SENTRY_DSN` is **not** added to `Env.requiredKeys` — a missing DSN must not stop the app booting. The keys are read through the existing `Env.optional(...)` escape hatch, so no core file changes.

The DSN is a public write-only key. It is still worth keeping out of git, like every other `.env` value.

## Wiring

Two lines in `lib/bootstrap.dart`. Nothing else in core changes.

**a. The import**, next to the other service imports:

```dart
import 'app/services/crash_service.dart';
```

**b. Init**, right after `await CacheManager.init();` and after `Env.load()` (it needs the DSN):

```dart
    await CacheManager.init();

    // Crash reporting. No-ops in debug and without a DSN.
    await CrashService.to.init();
```

**c. The zone handler** — replace the existing one-liner at the bottom of `bootstrap()`:

```dart
  }, (error, stack) {
    devPrint('$error\n$stack', tag: 'Uncaught');
    unawaited(CrashService.to.recordError(error, stack, fatal: true));
  });
```

`unawaited` and `dart:async` are already imported in `bootstrap.dart`.

**d. `FlutterError.onError` — leave it exactly as it is.** Sentry's `FlutterErrorIntegration` saves whatever handler is installed when `init()` runs and calls it *after* it reports, so the existing `devPrint` keeps firing and framework errors are not reported twice. Because bootstrap sets `FlutterError.onError` before `CrashService.to.init()`, the chain is already in the right order. Adding a manual `recordError` there would duplicate every framework error.

Why the zone handler still needs an explicit call: on mobile, Sentry catches uncaught async errors through `PlatformDispatcher.onError`, which only fires for errors that reach the root zone. `bootstrap()` runs the app inside `runZonedGuarded`, so those errors are caught by *its* handler first and never reach Sentry on their own.

**AppRoutes / AppPages:** nothing to add — this module ships no screens.

**ViewModelBinding:** nothing to add. `CrashService.to` puts itself in the container as `permanent` on first use, which has to happen in `bootstrap()` before `ViewModelBinding().dependencies()` runs. If you want it listed there for visibility, use the guarded form (the same shape `UserDi` uses) so the initialised instance is not replaced by a fresh one:

```dart
    if (!Get.isRegistered<CrashService>()) Get.put(CrashService(), permanent: true);
```

### Android — `android/app/src/main/AndroidManifest.xml`

The template manifest declares no permissions. Release builds cannot upload events without this:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>

    <application ...>
```

`sentry-android` 8.x needs `minSdk 21` / `compileSdk 36`; the Flutter defaults the template uses already satisfy both. No `<meta-data>` is needed — the DSN is passed from Dart.

Expect one build warning on Flutter 3.44: `sentry_flutter` still applies the Kotlin Gradle Plugin, which future Flutter versions will reject. The debug and release builds succeed today; watch the `sentry_flutter` changelog for a Built-in Kotlin release.

### iOS — `ios/Podfile`

`sentry-cocoa` needs iOS 12 or newer. Uncomment line 2 and leave it at 13.0:

```ruby
platform :ios, '13.0'
```

Then `cd ios && pod install`. No `Info.plist` keys are required.

### Release builds and obfuscation

Obfuscated Dart stack traces arrive unreadable unless you upload the debug symbols:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

Then add a top-level `sentry:` block to `pubspec.yaml` (read by `sentry_dart_plugin`) and run the upload:

```yaml
sentry:
  upload_debug_symbols: true
  project: your-project
  org: your-org
  # auth_token: read from the SENTRY_AUTH_TOKEN env var instead of committing it
```

```bash
dart run sentry_dart_plugin
```

Skip the whole step and stack traces stay readable — the binary is just not obfuscated.

## What the scrubber strips

`CrashPiiScrubber.beforeSend` runs on every event and `beforeBreadcrumb` on every crumb. Both are pure functions, so they are easy to unit-test.

| Where | What happens |
| --- | --- |
| `event.user` | Only `id` survives. `email`, `username`, `name`, `ipAddress` and `geo` are nulled; `data` goes through the key filter. |
| `event.request` | Bodies (`data`) dropped wholesale. `cookies` dropped. `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie`, `X-Api-Key`, `X-Auth-Token`, `X-Refresh-Token` headers dropped. URL reduced to scheme + host + path, so userinfo, query string and fragment go. |
| `event.tags`, `event.extra`, breadcrumb `data` | Any key containing `auth`, `token`, `jwt`, `bearer`, `credential`, `password`, `secret`, `apikey`, `signature`, `cookie`, `session`, `email`, `mail`, `phone`, `mobile`, `msisdn`, `otp`, `pin`, `ssn`, `address`, `card`, `cvv`, `cvc` or `iban` has its value replaced with `[redacted]`. Nested maps recurse. |
| `event.message`, exception values, breadcrumb messages | Free text is regex-redacted: emails, `Bearer …`, JWTs (`eyJ….….…`), `+`-prefixed phone numbers and any run of 9+ consecutive digits. |

Plus, at the SDK level: `sendDefaultPii = false` (no IP address, no device name) and `attachScreenshot = false` (a screenshot of a half-filled form is PII). `attachViewHierarchy` is left at its `false` default.

Verified behaviour, straight from a run against the real package:

```
in : user{id: u_42, email: jane.doe@acme.com, username: jane, ip: 1.2.3.4}
out: {id: u_42}

in : 'login failed for jane.doe@acme.com +8801712345678'
out: 'login failed for [redacted] [redacted]'

in : POST https://api.example.com/acc/auth/login?token=secret123
     headers {Authorization: Bearer eyJhbG.cioJ.xyz, Accept: application/json}
     body {password: hunter2}
out: {url: https://api.example.com/acc/auth/login, method: POST,
      headers: {Accept: application/json}}
```

The digit rule is deliberately blunt: a 9-digit order id or an epoch-millis timestamp inside an error message will also come out as `[redacted]`. Tune `CrashPiiScrubber.sensitiveKeys` and the regexes at the top of the file if that costs you more than it buys.

## Usage

Reporting a caught error from a controller:

```dart
try {
  final response = await _repo.fetchOrders();
  ...
} catch (e, s) {
  await CrashService.to.recordError(e, s, reason: 'orders.fetch', tags: {'screen': 'orders'});
  showCustomSnackBar('Could not load orders'.tr, type: SnackBarType.Failure);
}
```

Tying events to a user — pass the backend id, never an email or phone:

```dart
await CrashService.to.setUserId(user.id);   // after sign-in
await CrashService.to.setUserId(null);      // on sign-out
```

A trail that gets attached to the next error:

```dart
await CrashService.to.addBreadcrumb('opened checkout', category: 'nav');
await CrashService.to.addBreadcrumb('payment sheet dismissed', category: 'payment');
```

`log()` sends a standalone, searchable message event; `addBreadcrumb()` only attaches context to the *next* error. Use `log()` sparingly — every call is an event against your quota.

Checking whether it is live (useful for a debug settings screen):

```dart
if (CrashService.to.isEnabled) { ... }
```

Testing it end to end — build in release with a DSN set, then throw:

```dart
CrashService.to.recordError(Exception('sentry smoke test'), StackTrace.current);
```

## Swapping the provider

`CrashService` never mentions Sentry. Write a second `CrashReporter` and hand it to `init()`:

```dart
class CrashlyticsReporter implements CrashReporter {
  @override
  bool get isConfigured => true;   // Firebase config is a file, not a DSN

  @override
  Future<void> init() => FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

  @override
  Future<void> recordError(Object error, StackTrace? stack, {String? reason, bool fatal = false, Map<String, String> tags = const {}}) =>
      FirebaseCrashlytics.instance.recordError(error, stack, reason: reason, fatal: fatal);
  // setUserId -> setUserIdentifier(id ?? ''), it takes a non-null String
  // log        -> log(message), there is no level
  // addBreadcrumb -> log(message), Crashlytics has no breadcrumb type
  // close      -> no-op
}

// bootstrap.dart
await CrashService.to.init(reporter: CrashlyticsReporter());
```

Nothing else changes. Note what you give up: Crashlytics needs `firebase_core` + `google-services.json` + `GoogleService-Info.plist`, has no `beforeSend` hook (so the scrubbing above has to move to each call site), and its breadcrumbs are just log lines.

## Notes and gotchas

- `SentryFlutter.init` is called **without** `appRunner`. The module never wraps `runApp` — `bootstrap()` owns that.
- Errors thrown before `CrashService.to.init()` returns (i.e. during `Env.load()` or `CacheManager.init()`) are not reported. Move the init call earlier if that matters, but it must stay after `Env.load()`.
- `options.environment` is set from `AppFlavor.name`, so Sentry splits `dev` / `staging` / `prod`. Set the flavor with `--dart-define=FLAVOR=prod`.
- `release` and `dist` are filled in by Sentry's `LoadReleaseIntegration` from `package_info_plus`, which the SDK pulls in itself.
- `tracesSampleRate` defaults to `0` — performance tracing costs quota and is off until you set `SENTRY_TRACES_SAMPLE_RATE`.
- Every `CrashService` method is wrapped in a try/catch that only `devPrint`s. A reporting failure never becomes the app's failure.
- API verified against `sentry_flutter` 9.28.0 in `~/.pub-cache`, and analysed + exercised against 9.30.0 (`flutter analyze`: no issues; the scrubber output above is real).

## Why it is not in core

A starter template should not open a network connection to a third-party SaaS, or pull the Sentry Android/Cocoa native SDKs into every build, before anyone has decided who hosts the crash data.
