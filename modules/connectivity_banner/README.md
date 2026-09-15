# connectivity_banner

Offline awareness in three pieces: a service that knows, a banner that tells the user, and a guard that stops a request before it wastes a spinner.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/connectivity_service.dart` | `ConnectivityService` — `GetxService` exposing `RxBool isOnline`, fed by the `connectivity_plus` stream and confirmed with a DNS probe. |
| `lib/app/services/connectivity_guard.dart` | `ConnectivityGuard` — static gate a controller calls before a network action; warns via `showCustomSnackBar` and returns `false`. |
| `lib/app/widgets/feedback/offline_banner.dart` | `OfflineBanner` — animated bar that slides in when the network drops and flashes a green "Back online" confirmation when it returns. |

## Install

```bash
dart run tool/add_module.dart connectivity_banner
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
cp modules/connectivity_banner/lib/app/services/connectivity_service.dart      lib/app/services/
cp modules/connectivity_banner/lib/app/services/connectivity_guard.dart        lib/app/services/
cp modules/connectivity_banner/lib/app/widgets/feedback/offline_banner.dart    lib/app/widgets/feedback/
```

### 1. pubspec.yaml

```yaml
dependencies:
  connectivity_plus: ^7.3.1
```

Already in the template core — the installer prints `already present` and changes nothing. `get` is core too. Nothing else is added.

### 2. Platform config

**Android** — `ACCESS_NETWORK_STATE` is merged in from the `connectivity_plus` manifest, so there is nothing to add for connectivity itself. The DNS probe needs `INTERNET`, which debug builds get for free but release builds do not. Add it to `android/app/src/main/AndroidManifest.xml` if it is not already there:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>

    <application ...>
```

**iOS** — nothing. No `Info.plist` keys, no entitlements.

**macOS** — tick *Incoming/Outgoing Connections (Client)* in both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`, or the probe always reports offline.

**Web** — not supported as shipped: the probe uses `dart:io`'s `InternetAddress.lookup`. Set `ConnectivityService.to.verifyReachability = false` to fall back to radio state only.

## Wiring

Three exact edits. Nothing else in core changes.

### `lib/bootstrap.dart` — register the service

```dart
import 'app/services/connectivity_service.dart';   // with the other app/ imports
import 'package:get/get.dart';                     // if not already imported
```

Then inside `bootstrap()`, next to the other startup registrations and **before** `runApp(const App())`:

```dart
    // Connectivity — permanent so ConnectivityService.to resolves anywhere.
    Get.put(ConnectivityService(), permanent: true);

    // App.build reads ThemeController, so register before the first frame.
    ViewModelBinding().dependencies();

    runApp(const App());
```

### `lib/app/app.dart` — wrap the app

```dart
import 'widgets/feedback/offline_banner.dart';
```

Add one line to `GetMaterialApp`:

```dart
      () => GetMaterialApp(
        title: 'Flutter Starter',
        debugShowCheckedModeBanner: false,
        builder: OfflineBanner.builder(),          // <-- add
        initialBinding: ViewModelBinding(),
        initialRoute: AppRoutes.SplashScreen,
```

The banner sits above the `Navigator`, so it stays put across route changes.

`GetMaterialApp` takes exactly one `builder`. If another module already claims it —
`biometric_lock` wants `builder: (context, child) => AppLockGate(child: child)` — compose them
instead of adding a second argument:

```dart
        builder: (context, child) =>
            AppLockGate(child: OfflineBanner.builder()(context, child)),
```

Outermost wins: the lock covers the banner, which is what you want while the app is locked.

### `ViewModelBinding` / `AppRoutes` / `AppPages`

**No entries.** This module ships no screens and no screen controller. `ConnectivityService` is a permanent `GetxService`, not a `GetxController`, so it does not belong in `ViewModelBinding` — but if you would rather keep all registration in one place, drop the same line into `ViewModelBinding.dependencies()` instead of `bootstrap.dart`:

```dart
    // Connectivity
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put(ConnectivityService(), permanent: true);
    }
```

### Optional — the widget barrel

`lib/app/widgets/feedback/feedback.dart` is a plain export list. Add:

```dart
export 'offline_banner.dart';
```

so `import 'package:flutter_starter/app/widgets/widgets.dart';` picks the banner up too.

## Usage

### Guard a network action in a controller

```dart
class ProfileController extends GetxController {
  final RxBool isLoadingSave = false.obs;

  Future<void> save() async {
    if (!await ConnectivityGuard.ensureOnline()) return;   // snackbar + bail
    isLoadingSave.value = true;
    ...
  }
}
```

Or wrap the call — `run` returns `null` when offline:

```dart
final response = await ConnectivityGuard.run(() => _repo.updateProfile(body));
if (response == null) return;
```

Cheap synchronous read when you only want to disable a button:

```dart
Obx(() => CustomButton(
  title: 'Submit'.tr,
  onTap: ConnectivityService.to.isOnline.value ? controller.submit : null,
))
```

### React to the flag anywhere

```dart
ever<bool>(ConnectivityService.to.isOnline, (online) {
  if (online) controller.retryFailedQueue();
});

await ConnectivityService.to.waitUntilOnline(timeout: const Duration(seconds: 20));
```

### Customise the banner

`OfflineBanner.builder()` takes the same knobs as the widget:

```dart
builder: OfflineBanner.builder(
  showRestored: true,
  restoredDuration: const Duration(seconds: 2),
  tapToRetry: true,
  offlineMessage: 'You are offline',
  restoredMessage: 'Connection restored',
),
```

Use the widget directly to scope the bar to one screen instead of the whole app:

```dart
OfflineBanner(child: MyScreenBody())
```

Both messages go through `.tr`, and `AppTranslations` falls back to the key, so nothing breaks if you never add them to the locale maps.

### Tune the service

```dart
ConnectivityService.to.verifyReachability = false;              // radio state only
ConnectivityService.to.probeHost = 'example.com';               // restricted network
ConnectivityService.to.probeTimeout = const Duration(seconds: 2);
ConnectivityGuard.title = 'Still offline';                      // reword the snackbar
ConnectivityGuard.message = 'Reconnect and try again.';
```

## Notes and gotchas

- **`connectivity_plus` v7 returns `List<ConnectivityResult>`.** Comparing it to a bare `ConnectivityResult.none` is always false — that exact bug once silently disabled the guard in `lib/app/services/domain/api_service.dart`. This module treats an empty list, or a list whose every entry is `none`, as offline, matching the corrected `checkInternet()`.
- **Radio up ≠ internet.** Captive-portal wifi reports `ConnectivityResult.wifi` with no egress, so `isOnline` is only set true after a DNS lookup of `probeHost` succeeds. Turn that off with `verifyReachability = false` if the probe is unwanted.
- Overlapping events are sequence-guarded: if a new connectivity event lands while a probe is in flight, the stale result is dropped instead of flipping the flag back.
- The banner registers `ConnectivityService` itself when it is missing, so dropping in `builder: OfflineBanner.builder()` works even before the `bootstrap.dart` edit. The explicit `Get.put` is still preferred — it makes the flag correct before the first frame.
- `ConnectivityService.isOnline` starts optimistic (`true`) and is corrected by the first check. A screen that renders in the first few hundred milliseconds will not flash the banner on a good connection.
- The bar is drawn above the `Navigator`, so it also covers dialogs and bottom sheets. `SafeArea` keeps it clear of the status bar and notch.
- `ConnectivityGuard.ensureOnline()` re-checks by default (`recheck: true`), which costs one DNS lookup. Pass `recheck: false` in a tight loop to read the cached flag.
- `checkInternet()` in the core `ApiService` is untouched and still runs per request — this module is the user-facing layer on top, not a replacement.

## Why it is not in core

Most apps built from this template are online-only and happy with the per-request `checkInternet()` guard; a persistent banner, a background DNS probe and an extra service in the startup path are a product decision, not a default.
