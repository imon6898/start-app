# biometric_lock

Face ID / Touch ID / fingerprint app lock: a `GetxService` over `local_auth` with every platform error code mapped to a sentence you can show a user, and an `app_lock` feature that locks on cold start and after a configurable time in the background.

Opt-in, off by default — and it turns itself off rather than trap someone whose device can no longer authenticate. That last part is the whole reason this module is more than fifty lines.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/biometric_service.dart` | `BiometricService` — `canCheckBiometrics()`, `canAuthenticate()`, `availableBiometrics()`, `refreshCapability()`, `authenticate(reason:)`. Every `PlatformException` code becomes one `BiometricStatus` + one message. |
| `lib/app/feature/app_lock/app_lock_logic/app_lock_store.dart` | `AppLockStore` — module-local SharedPreferences keys (`app_lock_enabled`, `app_lock_timeout_seconds`). Does not touch `CacheManager`. |
| `lib/app/feature/app_lock/app_lock_controllers/app_lock_controller.dart` | `AppLockController` — lifecycle observer, cold-start lock, background timeout, opt-in toggle, sign-out escape, lockout recovery. |
| `lib/app/feature/app_lock/app_lock_presentation/app_lock_gate.dart` | `AppLockGate` — goes in `GetMaterialApp.builder` so the lock sits **above** the Navigator and no route change can dismiss it. |
| `lib/app/feature/app_lock/app_lock_presentation/app_lock_screen.dart` | The lock screen: badge, status copy, error box, Unlock, recovery button, "Sign out instead". |
| `lib/app/feature/app_lock/app_lock_presentation/app_lock_settings_screen.dart` | `AppLockSettingsScreen` — the toggle, the "lock after" chooser, a live capability warning, "Lock now". |

## Install

```bash
dart run tool/add_module.dart biometric_lock
flutter pub get
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
cp modules/biometric_lock/lib/app/services/biometric_service.dart                                    lib/app/services/
mkdir -p lib/app/feature/app_lock/app_lock_logic lib/app/feature/app_lock/app_lock_controllers lib/app/feature/app_lock/app_lock_presentation
cp modules/biometric_lock/lib/app/feature/app_lock/app_lock_logic/app_lock_store.dart                lib/app/feature/app_lock/app_lock_logic/
cp modules/biometric_lock/lib/app/feature/app_lock/app_lock_controllers/app_lock_controller.dart     lib/app/feature/app_lock/app_lock_controllers/
cp modules/biometric_lock/lib/app/feature/app_lock/app_lock_presentation/*.dart                      lib/app/feature/app_lock/app_lock_presentation/
```

Then add the dependency, do the wiring, do the platform config, and `flutter pub get`.

### 1. pubspec.yaml

```yaml
dependencies:
  local_auth: ^2.3.0
```

`get`, `shared_preferences` and `lucide_icons_flutter` are already in the template core. Nothing else is added — `local_auth_android`, `local_auth_darwin` and `local_auth_windows` come in as endorsed implementations and are never imported directly.

No `.env` key, no backend.

## Wiring

Four edits to core files. Paste them verbatim.

### 2.1 `lib/bootstrap.dart` — load the flag before the first frame

```dart
import 'app/feature/app_lock/app_lock_logic/app_lock_store.dart';   // add
```

```dart
    await CacheManager.init();
    await AppLockStore.init();      // add — synchronous getters after this
```

Skipping this is not fatal: the controller loads the store itself and locks one frame later. You just get a flash of app content on a cold start.

### 2.2 `lib/app/bindings/view_model_binding.dart` — register the controller

```dart
import '../feature/app_lock/app_lock_controllers/app_lock_controller.dart';   // add
```

Inside `dependencies()`, above the `// Auth` block:

```dart
    // App lock — permanent: the lifecycle observer must outlive every route.
    if (!Get.isRegistered<AppLockController>()) {
      Get.put(AppLockController(), permanent: true);
    }
```

`permanent`, not `_lazy`: the controller *is* the `WidgetsBindingObserver`, so it has to exist before the first frame and survive every `Get.offAllNamed`. Registering it here also puts it first in the binding's observer list, which is what lets `didPopRoute` swallow the Android back button while the app is locked.

`BiometricService` registers itself on first use — no entry needed.

### 2.3 `lib/app/app.dart` — put the lock above the Navigator

```dart
import 'feature/app_lock/app_lock_presentation/app_lock_gate.dart';   // add
```

One line inside `GetMaterialApp`, next to `getPages`:

```dart
        getPages: AppPages.pages,
        builder: (context, child) => AppLockGate(child: child),   // add
```

This is the only placement that actually holds. A lock pushed as a route is removed by the next `Get.offAllNamed` — and the template's `SplashScreen` calls exactly that two seconds after launch.

`GetMaterialApp` takes exactly one `builder`. If another module already claims it —
`connectivity_banner` wants `builder: OfflineBanner.builder()` — compose them rather than adding a
second argument, keeping `AppLockGate` outermost so the lock covers everything:

```dart
        builder: (context, child) =>
            AppLockGate(child: OfflineBanner.builder()(context, child)),
```

### 2.4 Routes — only for the bundled settings screen

`lib/app/routes/app_routes.dart`:

```dart
  /// App lock
  static const String AppLockSettingsScreen = '/appLockSettingsScreen';
```

`lib/app/routes/app_pages.dart`:

```dart
import '../feature/app_lock/app_lock_presentation/app_lock_settings_screen.dart';   // add
```

```dart
    // App lock
    _page(
      AppRoutes.AppLockSettingsScreen,
      () => const AppLockSettingsScreen(),
    ),
```

The lock screen itself is never routed.

### 3. Android — `MainActivity.kt`

`local_auth` needs a `FragmentActivity`. The template's `android/app/src/main/kotlin/com/easital/starter/MainActivity.kt` currently reads:

```kotlin
package com.easital.starter

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```

Change **both** lines:

```kotlin
package com.easital.starter

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

Without it, `authenticate()` throws `PlatformException(code: 'no_fragment_activity')`, which this module reports as `BiometricStatus.misconfigured`.

### 4. Android — `AndroidManifest.xml`

Inside `<manifest>`, next to the existing `<queries>` block:

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

### 5. Android — `res/values/styles.xml`

`LaunchTheme`'s parent must be an AppCompat theme or the biometric dialog crashes on Android 8 and below. The template ships `@android:style/Theme.Light.NoTitleBar`:

```xml
<style name="LaunchTheme" parent="Theme.AppCompat.DayNight">
    <item name="android:windowBackground">@drawable/launch_background</item>
</style>
```

Do the same in `android/app/src/main/res/values-night/styles.xml`. Then a full rebuild — hot reload will not pick any of this up.

### 6. iOS — `ios/Runner/Info.plist`

```xml
<key>NSFaceIDUsageDescription</key>
<string>Unlock the app with Face ID.</string>
```

Without it iOS shows "this app has not been updated to use Face ID" instead of the prompt. Touch ID and the passcode fallback need nothing extra, and there is no runtime permission dialog.

## Usage

Everything after the wiring is optional — the lock works with zero calls, because the user turns it on from the settings screen.

```dart
Get.toNamed(AppRoutes.AppLockSettingsScreen);
```

Drive it yourself:

```dart
final lock = AppLockController.to;

await lock.setEnabled(true);          // prompts first; returns the resulting state
await lock.setTimeoutSeconds(60);     // 0, 15, 30, 60, 300 are what the UI offers
lock.lockNow();                       // show the lock screen right now
await lock.unlock();                  // prompt, and clear the lock on success

lock.isEnabled.value;                 // opt-in flag, persisted
lock.isLocked.value;                  // the gate watches this
lock.capability.value;                // BiometricStatus for the current device
```

The service on its own, for a step-up check before a destructive action:

```dart
final result = await BiometricService.to.authenticate(
  reason: 'Confirm to delete your account'.tr,
);
if (!result.success) {
  showCustomSnackBar(
    context: context,
    type: SnackBarType.Failure,
    title: 'Not confirmed'.tr,
    description: result.message,     // already user-facing
  );
}
```

```dart
await BiometricService.to.refreshCapability();   // BiometricStatus
BiometricService.to.biometricLabel;              // 'Face ID' / 'Touch ID' / 'Fingerprint'
BiometricService.to.enrolledTypes;               // List<BiometricType>
```

Send a signed-out user somewhere other than the sign-in screen:

```dart
AppLockController.onSignOut = () async {
  await CacheManager.removeAll();
  Get.offAllNamed(AppRoutes.OnboardingScreen);
};
```

### Error handling

Every code from `local_auth 2.3.0`, `local_auth_android 1.0.56` and `local_auth_darwin 1.6.1` is mapped:

| Platform code | `BiometricStatus` | What the user sees |
| --- | --- | --- |
| `NotAvailable`, `BiometricNotAvailable` | `noHardware` | "This device cannot verify you — it has no biometrics and no screen lock" |
| `NotEnrolled` | `notEnrolled` | "No fingerprint or face is set up. Add one in device settings, or use your device passcode" |
| `PasscodeNotSet` | `passcodeNotSet` | "Set a screen lock on this device before turning on app lock" |
| `LockedOut` | `lockedOut` | "Too many attempts. Wait about 30 seconds, then try again" |
| `PermanentlyLockedOut` | `permanentlyLockedOut` | "Biometrics are locked. Use your device passcode to unlock them again" |
| `UserCancelled`, `UserFallback` | `cancelled` | "Authentication was cancelled" |
| `no_fragment_activity`, `no_activity` | `misconfigured` | "App lock is not set up correctly in this build" |
| `OtherOperatingSystem`, `biometricOnlyNotSupported` | `unsupportedPlatform` | "App lock is not available on this platform" |
| `auth_in_progress`, plain `false` | `failed` | "We could not verify it is you. Try again" |
| anything else, `MissingPluginException` | `unknown` / `unsupportedPlatform` | "Something went wrong while verifying you" |

## Never locked out of your own app

This is the failure mode worth designing for: the lock is on, the sensor stops working, and the app becomes unopenable. Four things prevent it.

1. **The passcode is always in play.** `biometricOnly` is `false` on every call, so the OS prompt itself offers the device PIN / pattern / passcode. A wiped fingerprint, a cracked sensor, a `PermanentlyLockedOut` biometric — the passcode still gets in. (`local_auth` has no passcode-only mode, so there is no separate button for it; the lock screen says so in words instead.)
2. **A device that cannot authenticate disables the lock.** If `authenticate()` returns `noHardware`, `passcodeNotSet`, `misconfigured` or `unsupportedPlatform`, `AppLockController` writes `enabled = false`, unlocks, and warns with a snackbar. A lock nobody can pass is not security, it is a brick.
3. **An explicit recovery button**, shown on the lock screen *only* for those statuses, and re-checked against `canAuthenticate()` before it does anything — so a healthy device can never use it as a bypass.
4. **"Sign out instead" is always there.** Worst case the user ends the session and signs in again. They lose the session, never the app.

Turning the lock **off** also survives a dead sensor: `setEnabled(false)` normally requires a passing check, but if the device reports it cannot authenticate at all, the flag is cleared anyway.

## Notes and gotchas

- **`isAuthenticating` gates the lifecycle handler.** The OS prompt backgrounds the app on both platforms; without that guard the resume handler would re-lock on top of its own prompt, forever.
- **The timeout is measured from `paused`/`hidden` to `resumed`.** `inactive` (the iOS app switcher peek, a notification shade pull) does not start the clock. `0` means lock on every resume.
- **Nothing route-based on the lock screen.** `AppLockGate` renders above the Navigator, so `Get.dialog`, `Get.snackbar` and `Navigator.of(context)` would land *underneath* the lock. The sign-out confirmation is an inline two-tap instead, and the recovery snackbar goes through `ScaffoldMessenger`.
- **Android back is swallowed** by `AppLockController.didPopRoute` while locked — which only works because the controller registers as an observer before `WidgetsApp` does, i.e. inside `ViewModelBinding().dependencies()` in `bootstrap()`. Android 13+ predictive-back gestures on the first route are handled by the system and close the app, which is safe.
- **Prompt strings are the platform defaults.** Customising them means importing `local_auth_android` and `local_auth_darwin` directly and adding both to `pubspec.yaml`; this module keeps the dependency list at one package.
- **The store is separate from `CacheManager`** on purpose, so installing this module needs no edit to a core file. Call `AppLockStore.clear()` next to `CacheManager.removeAll()` in your own logout — `AppLockController.signOut()` already does.
- **`isDeviceSupported()` is always false below Android SDK 23**, and the iOS Simulator can report `OtherOperatingSystem`. Test on a device.
- **Content is still visible in the app switcher.** Hiding it needs `FLAG_SECURE` on Android and a snapshot overlay on iOS — both are native-side changes this module does not make.
- Verified: `flutter analyze` clean and the 35 template tests pass with the module installed and all four wiring edits applied.

## Why it is not in core

Most apps built from this template do not need a lock screen, and the ones that do need platform edits — `FlutterFragmentActivity`, an AppCompat launch theme, `NSFaceIDUsageDescription` — that would otherwise be forced on every project.
