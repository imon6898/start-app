# app_update_gate

Force / soft update gate — the thing you always need and always add too late.

On launch it asks **your** backend for a version contract, compares it against the running build with real **semver** comparison, and then does one of three things: nothing, a dismissible sheet you can snooze, or a non-dismissible screen whose only exit is the store.

Failure is always **open**. A network error, an unparseable payload, a missing version — all resolve to "no update". A broken gate must never lock users out of your app.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/feature/app_update/app_update_models/semantic_version.dart` | `SemanticVersion` — numeric semver parse + compare. `"1.10.0" > "1.9.0"`, which string compare gets backwards. |
| `lib/app/feature/app_update/app_update_models/app_update_info.dart` | `AppUpdateInfo` — the backend payload, plus the `AppUpdateAction { none, soft, force }` enum. |
| `lib/app/feature/app_update/app_update_logic/app_update_api_const.dart` | `AppUpdateApiConst.versionGateUri` — the module's own endpoint, so core `api_const.dart` stays untouched. |
| `lib/app/feature/app_update/app_update_logic/app_update_api_service.dart` | `AppUpdateApiService` / `AppUpdateImpl` / `AppUpdateRepo` — the usual trio, Style A (the Repo passes the url). |
| `lib/app/feature/app_update/app_update_logic/app_update_store.dart` | `AppUpdateStore` — module-local SharedPreferences snooze keys. Core `CacheManager` stays untouched. |
| `lib/app/feature/app_update/app_update_controllers/app_update_controller.dart` | `AppUpdateController` — fetch, decide, show, launch the store, snooze. |
| `lib/app/feature/app_update/app_update_presentation/force_update_screen.dart` | `ForceUpdateScreen` — `PopScope(canPop: false)`, no app bar, one button. |
| `lib/app/feature/app_update/app_update_presentation/soft_update_sheet.dart` | `SoftUpdateSheet` — body of the dismissible sheet: "Update now" / "Remind me later". |

## Install

```bash
dart run tool/add_module.dart app_update_gate
flutter pub get
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
mkdir -p lib/app/feature/app_update/{app_update_models,app_update_logic,app_update_controllers,app_update_presentation}
cp -R modules/app_update_gate/lib/app/feature/app_update/. lib/app/feature/app_update/
```

### 1. pubspec.yaml

```yaml
dependencies:
  package_info_plus: ^10.2.1
  url_launcher: ^6.3.2
```

`get`, `dio`, `shared_preferences` and `lucide_icons_flutter` are already in the template core. **`url_launcher` is not** — the installer adds it. If another module (`webview`, `html_view`) already pulled it in, the installer skips it.

### 2. Android — `android/app/src/main/AndroidManifest.xml`

Android 11+ (API 30) hides other apps unless you declare what you intend to open. Without this, `launchUrl` silently returns `false` on a Play Store link. The block is a direct child of `<manifest>`, a sibling of `<application>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="market"/>
        </intent>
    </queries>

    <application ...>
        ...
    </application>
</manifest>
```

The template manifest already ships a `<queries>` block for `PROCESS_TEXT`. Either drop these two
`<intent>` entries inside it or leave a second block — the manifest merger unions both (verified in the
merged debug manifest).

`package_info_plus` needs no permission — it reads `versionName` / `versionCode` off the installed package.

### 3. iOS — `ios/Runner/Info.plist`

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>https</string>
    <string>itms-apps</string>
</array>
```

`package_info_plus` reads `CFBundleShortVersionString` / `CFBundleVersion` and needs no plist change. Neither plugin needs a `MainActivity` or `AppDelegate` edit.

## Wiring

These are the only core edits. Paste them verbatim.

### `lib/app/bindings/view_model_binding.dart`

Both screens are `GetBuilder<AppUpdateController>`, so they throw on first build without this.

```dart
import '../feature/app_update/app_update_controllers/app_update_controller.dart';
```

then, inside `dependencies()`:

```dart
    // App update
    _lazy<AppUpdateController>(() => AppUpdateController());
```

### `lib/app/feature/splash/splash_controllers/splash_controller.dart`

The gate needs a live `Navigator`, so run it from the splash controller — but **do not await it**. It makes an HTTP call, and awaiting it before `Get.offAllNamed` parks the user on the splash until the request answers (up to `fetchTimeout`, and the shipped `test/widget/app_boot_test.dart` fails because the splash never routes).

```dart
import '../../app_update/app_update_controllers/app_update_controller.dart';
```

then, at the **end** of the `try` block in `_routeFromSession()`, after the `Get.offAllNamed` branches:

```dart
      // Fire and forget: the gate takes over the stack itself once it decides.
      Get.find<AppUpdateController>().runGate();
```

`runGate()` pushes `ForceUpdateScreen` with `Get.offAll` when the backend says force, so it supersedes whatever the splash routed to; a soft update opens its sheet over the screen the user landed on. `unawaited_futures` is off in this template's `analysis_options.yaml`, so the bare call analyzes clean — wrap it in `unawaited(...)` (plus `import 'dart:async';`) if you turn that lint on.

### `lib/bootstrap.dart` (optional)

You can warm the check before the first frame, but **only** with `showUi: false` — there is no `Navigator` before `runApp()`. `bootstrap.dart` does not import GetX yet, so add both:

```dart
import 'package:get/get.dart';

import 'app/feature/app_update/app_update_controllers/app_update_controller.dart';
```

```dart
    // Warms the version gate; the UI is shown later from the splash controller.
    unawaited(Get.find<AppUpdateController>().runGate(showUi: false));
```

Put it after `ViewModelBinding().dependencies();`. Calling `runGate()` again from splash is cheap and re-reads the decision.

Skip this if you already wired the splash call — one fire-and-forget gate per launch is enough.

### `AppRoutes` / `AppPages` (optional)

Not required — `runGate()` pushes the blocking screen with `Get.offAll(() => const ForceUpdateScreen())`, so the module installs without touching the router. If your project routes by name only:

`lib/app/routes/app_routes.dart`

```dart
  /// App update gate
  static const String ForceUpdateScreen = '/forceUpdateScreen';
```

`lib/app/routes/app_pages.dart`

```dart
import '../feature/app_update/app_update_presentation/force_update_screen.dart';
```

```dart
    // App update
    _page(AppRoutes.ForceUpdateScreen, () => const ForceUpdateScreen()),
```

then swap the one line in `AppUpdateController.runGate()`:

```dart
      Get.offAllNamed(AppRoutes.ForceUpdateScreen);
```

That swap also changes the controller's imports: add
`package:flutter_starter/app/routes/app_routes.dart` and **delete**
`package:flutter_starter/app/feature/app_update/app_update_presentation/force_update_screen.dart`,
which is now unused. This template promotes `unused_import` to an error, so leaving it behind fails
`flutter analyze`.

## Backend contract

One endpoint. Change the path in `app_update_api_const.dart` to match yours.

```
GET {baseUrl}/app/version?platform=android&current_version=1.4.2&build_number=42
```

| Query param | Value |
| --- | --- |
| `platform` | `android` or `ios` |
| `current_version` | `CFBundleShortVersionString` / `versionName`, e.g. `1.4.2` |
| `build_number` | `CFBundleVersion` / `versionCode`, e.g. `42` |

Response — the four required keys:

```json
{
  "min_supported_version": "1.4.0",
  "latest_version": "1.10.0",
  "update_url": "https://play.google.com/store/apps/details?id=com.you.app",
  "force": false
}
```

Optional keys the parser also understands:

```json
{
  "android_update_url": "https://play.google.com/store/apps/details?id=com.you.app",
  "ios_update_url": "https://apps.apple.com/app/id123456789",
  "ios_app_id": "123456789",
  "title": "Time to update",
  "message": "We fixed the thing that kept logging you out.",
  "release_notes": ["Faster sync", "Fewer crashes"]
}
```

Notes on the contract:

- A **bare object** and a `BaseResponse` envelope (`{"status":true,"data":{…}}`) both parse.
- camelCase spellings (`minSupportedVersion`, `latestVersion`, …) are accepted as a fallback.
- `force` accepts `true`, `"true"`, `1`, `"1"`, `"yes"`.
- Serve the right numbers **per platform** — Android and iOS releases drift apart. That is what `platform` is for.
- `update_url` is optional if you send `ios_app_id`, or on Android at all: with no link the controller builds `https://play.google.com/store/apps/details?id=<packageName>` from `package_info_plus`.

### The decision table

| Condition (checked in order) | Result |
| --- | --- |
| Fetch failed / payload unparseable / running version unreadable | `none` |
| `running < min_supported_version` | **`force`** |
| `force == true` **and** `running < latest_version` | **`force`** |
| `running >= latest_version` | `none` |
| Snoozed on this exact `latest_version`, within the window | `none` |
| Otherwise | **`soft`** |

### Why semver, not string compare

`"1.10.0".compareTo("1.9.0")` is **negative** — lexically `'1' < '9'`, so a string-comparing gate thinks 1.10.0 is older than 1.9.0 and force-updates every user on your newest build. `SemanticVersion` compares `major`/`minor`/`patch` as integers.

It also handles: `"1"` and `"1.4"` widen to `1.0.0` / `1.4.0`; a leading `v` is stripped; build metadata is ignored for precedence (`"1.2.3+45"` and `"1.2.3 (45)"` both equal `1.2.3`); pre-releases rank below their own release and compare per semver 2.0 (`1.2.3-beta.9 < 1.2.3-beta.10 < 1.2.3`).

## Snooze ("remind me later")

The soft sheet must not nag on every cold start, so any dismissal — the button, the X, a tap on the barrier — writes the snooze.

- Keys live in this module's `AppUpdateStore`: `app_update_snoozed_version`, `app_update_snoozed_at`. Core `CacheManager` is not touched.
- The snooze is keyed to the **version it was taken on**. Ship `1.11.0` and the sheet comes back at once, even mid-window.
- Window is 24h. Change it once, anywhere before the first `runGate()`:

```dart
AppUpdateController.snoozeFor = const Duration(days: 3);
```

- `await Get.find<AppUpdateController>().resetSnooze();` re-arms it immediately.

## Usage

The one call that does everything:

```dart
final action = await Get.find<AppUpdateController>().runGate();
if (action == AppUpdateAction.force) return;  // the gate owns the stack now
```

Decide without any UI — e.g. to put a badge in Settings:

```dart
final controller = Get.find<AppUpdateController>();
final action = await controller.runGate(showUi: false);

Obx(() => controller.isLoadingCheck.value
    ? const SizedBox.shrink()
    : Text(action == AppUpdateAction.none ? 'Up to date'.tr : 'Update available'.tr));
```

Show the sheet on demand from a "check for updates" row:

```dart
await Get.find<AppUpdateController>().showSoftUpdateSheet();
```

Send the user to the store yourself:

```dart
await Get.find<AppUpdateController>().openStore();
```

## Testing both paths locally

No backend needed. `AppUpdateController` has two static test hooks that short-circuit the fetch and the real build version. Set them **before** `runGate()`, and delete them before you ship.

```dart
import 'package:flutter_starter/app/feature/app_update/app_update_controllers/app_update_controller.dart';
import 'package:flutter_starter/app/feature/app_update/app_update_models/app_update_info.dart';

// FORCE — blocking screen, no way out but the store button.
AppUpdateController.debugCurrentVersion = '1.0.0';
AppUpdateController.debugInfo = const AppUpdateInfo(
  minSupportedVersion: '1.4.0',
  latestVersion: '1.10.0',
  updateUrl: 'https://play.google.com/store/apps/details?id=com.easital.starter',
);

// SOFT — dismissible sheet, snoozed for 24h on any dismissal.
AppUpdateController.debugCurrentVersion = '1.9.0';
AppUpdateController.debugInfo = const AppUpdateInfo(
  minSupportedVersion: '1.0.0',
  latestVersion: '1.10.0',
  updateUrl: 'https://play.google.com/store/apps/details?id=com.easital.starter',
  releaseNotes: ['Faster sync', 'Fewer crashes'],
);

// NONE — nothing happens. Prove the semver fix: 1.10.0 is NOT older than 1.9.0.
AppUpdateController.debugCurrentVersion = '1.10.0';
AppUpdateController.debugInfo = const AppUpdateInfo(
  minSupportedVersion: '1.0.0',
  latestVersion: '1.9.0',
);
```

To re-show the soft sheet after you have snoozed it:

```dart
await Get.find<AppUpdateController>().resetSnooze();
```

Against a real-ish backend, `python3 -m http.server` over a static JSON file works — point `AppUpdateApiConst.versionGateUri` at it and set `DEV_BASE_URL` in `.env` to your machine (`http://10.0.2.2:8000` from the Android emulator). Remember that Android 9+ blocks cleartext HTTP unless `android:usesCleartextTraffic="true"` is on `<application>`.

The store button on an emulator without Play Services will fail to launch — that is the emulator, not the gate. The warning snackbar it shows is the expected fallback.

## Notes and gotchas

- **Do not call `runGate()` with UI from `bootstrap.dart`.** There is no `Navigator` before `runApp()`; `Get.offAll` would throw. Use `showUi: false` there and show the UI from splash.
- `package_info_plus` caches `PackageInfo.fromPlatform()` per process, so calling `runGate()` repeatedly costs one HTTP request, not a platform channel round-trip.
- On Android, `pkg.version` is `versionName` and `pkg.buildNumber` is `versionCode`. The gate compares `versionName` — keep it semver-shaped in `pubspec.yaml` (`version: 1.4.2+42`).
- `force: true` alone does **not** block a user who is already on `latest_version`; the running build must actually be older. That stops a stale flag from bricking your newest release.
- The force screen has no app bar and `canPop: false`, so the Android hardware back button does nothing. That is the point. It does **not** block the OS-level app switcher — nothing in a Flutter app can.
- Both screens read `info` off the controller, so pushing `ForceUpdateScreen` by hand without a prior `runGate()` renders the default copy and an empty version line.

## Why it is not in core

Every project's version endpoint, store links and "how hard do we push" policy are different, and a gate that ships unconfigured is a gate that either does nothing or blocks everyone.
