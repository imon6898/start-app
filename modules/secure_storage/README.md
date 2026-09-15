# secure_storage

Encrypted auth-token storage. `SecureStore` keeps the access and refresh token in the **Android KeyStore** / **iOS Keychain** instead of plaintext `SharedPreferences`, and drains any token already sitting in plaintext on the next launch.

This fixes a real weakness in the template: `CacheManager` writes `token` and `refreshToken` into `SharedPreferences`, which on Android is a world-readable-to-root XML file at `/data/data/<pkg>/shared_prefs/`, and on iOS an unencrypted plist in the app container. Read [Threat model](#threat-model) before you assume this solves more than it does.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/local_data/secure_store.dart` | `SecureStore` — static, `CacheManager`-shaped token API, but async. Plus `init()`, a one-time plaintext migration, and `tokenSync` / `refreshTokenSync` for call sites that cannot await. |

API surface:

```dart
await SecureStore.init();                    // bootstrap: migrate + warm the memory copy
await SecureStore.setToken(t);               // Future<bool>
final t = await SecureStore.token;           // Future<String?>
await SecureStore.removeToken();             // Future<bool>
await SecureStore.setRefreshToken(r);        // Future<bool>
final r = await SecureStore.refreshToken;    // Future<String?>
await SecureStore.removeRefreshToken();      // Future<bool>
await SecureStore.clearAll();                // Future<bool> — both keys, logout

SecureStore.tokenSync;                       // String? — valid after init()
SecureStore.refreshTokenSync;                // String?
SecureStore.isReady;                         // bool
```

## Install

```bash
dart run tool/add_module.dart secure_storage
flutter pub get
```

Manual equivalent:

```bash
cp modules/secure_storage/lib/app/services/local_data/secure_store.dart lib/app/services/local_data/
```

### 1. pubspec.yaml

```yaml
dependencies:
  flutter_secure_storage: ^11.1.1
```

`shared_preferences` is already in the template core — the migration reads the old plaintext keys through it.

> **Do not pin `^9.x`.** Version 9's Windows implementation depends on `win32 ^5`, while the template's `file_picker ^13` pulls `win32 ^6`. Pub cannot resolve the two together. v11 is the first line that works in this project. v10 removed the `encryptedSharedPreferences` option because `androidx.security.crypto` is deprecated; v11 Android storage is the plugin's own AES-GCM ciphertext with the data key wrapped by an RSA-OAEP KeyStore key. That is equivalent protection, KeyStore-backed either way.

### 2. Android — `android/app/build.gradle.kts`

The plugin sets `minSdk = 24`. The template inherits `flutter.minSdkVersion`, which is already at or above that; only act if you have pinned it lower:

```kotlin
defaultConfig {
    minSdk = 24
}
```

### 3. Android — backup

Auto Backup copies the encrypted prefs file but never the KeyStore key that unwraps it, so a restored install reads garbage. `resetOnError: true` is set in `SecureStore`, so the failure mode is a forced re-login rather than a crash loop — but the clean fix is to exclude it. In `android/app/src/main/AndroidManifest.xml`:

```xml
<application
    android:allowBackup="false"
    android:fullBackupContent="false"
    ... >
```

Keep backups enabled instead? Add a rules file and point `android:dataExtractionRules` / `android:fullBackupContent` at it, excluding the plugin's shared-prefs file.

### 4. iOS — `ios/Podfile`

```ruby
platform :ios, '13.0'
```

Then `cd ios && pod install`. No entitlement is needed — code signing already grants the default keychain access group.

> Keychain items **survive an app uninstall** on iOS. A reinstalled app can find the previous user's token. That is why logout must call `SecureStore.clearAll()`.

### 5. macOS only — entitlements

Add the Keychain Sharing capability to both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.your.bundle.id</string>
</array>
```

Android, iOS and macOS are the only platforms where this module is meaningfully secure. See [Threat model](#threat-model) for web.

---

## Wiring

Six core files change. Nothing here is optional — until the call sites move, the tokens are still written in plaintext by `CacheManager`.

### 1. `lib/bootstrap.dart`

```dart
import 'app/services/local_data/cache_manager.dart';
import 'app/services/local_data/secure_store.dart';   // add
```

```dart
    await CacheManager.init();
    await SecureStore.init();                          // add — migrates, then warms tokenSync
```

`init()` must run **before** anything reads a token, and before `ViewModelBinding().dependencies()`.

### 2. `lib/app/services/domain/api_service.dart`

Eleven token references, in ten edits. The constructor pair cannot await, so it uses `tokenSync`; the rest are already inside `async` bodies.

```dart
import '../local_data/cache_manager.dart';
import '../local_data/secure_store.dart';              // add
```

```diff
   // in the ApiService constructor (not async — use the sync mirror)
     try {
-      devPrint('token: ${CacheManager.token}');
-      options.headers['Authorization'] = 'Bearer ${CacheManager.token}';
+      devPrint('token: ${SecureStore.tokenSync}');
+      options.headers['Authorization'] = 'Bearer ${SecureStore.tokenSync}';
     } catch (e) {
```

```diff
   // onRequest interceptor — make the callback async
-        onRequest: (options, handler) {
-          final token = CacheManager.token;
+        onRequest: (options, handler) async {
+          final token = await SecureStore.token;
           if (token != null && token.isNotEmpty) {
             options.headers['Authorization'] = 'Bearer $token';
           }
           handler.next(options);
         },
```

```diff
   // onError — the guard that skips refresh for guests
-          final refreshToken = CacheManager.refreshToken;
+          final refreshToken = await SecureStore.refreshToken;
           if (refreshToken == null || refreshToken.isEmpty) {
```

```diff
   // both retry blocks (the "already refreshing" wait, and after a successful refresh)
             final opts = error.requestOptions;
-            opts.headers['Authorization'] = 'Bearer ${CacheManager.token}';
+            opts.headers['Authorization'] = 'Bearer ${await SecureStore.token}';
             opts.extra['isRetry'] = true;
```

```diff
   // static Future<bool> _refreshToken()
-      final refreshToken = CacheManager.refreshToken;
+      final refreshToken = await SecureStore.refreshToken;
```

```diff
         if (newAccessToken != null && newAccessToken.isNotEmpty) {
-          await CacheManager.setToken(newAccessToken);
+          await SecureStore.setToken(newAccessToken);
           devPrint('Access token refreshed successfully');
         }
         if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
-          await CacheManager.setRefreshToken(newRefreshToken);
+          await SecureStore.setRefreshToken(newRefreshToken);
```

```diff
   // static Future<void> _handleSessionExpired()
-    await CacheManager.removeToken();
-    await CacheManager.removeRefreshToken();
+    await SecureStore.clearAll();
     await CacheManager.removeUserData();
```

### 3. `lib/app/core/di/user_di.dart`

```dart
import 'package:flutter_starter/app/services/local_data/secure_store.dart';   // add
```

`isLoggedIn` is a **synchronous getter read from widget builders** — it cannot become a `Future` without rewriting every caller. Use the sync mirror:

```diff
   bool get isLoggedIn =>
       !isGuest &&
       userData != null &&
-      CacheManager.token != null &&
-      CacheManager.token!.isNotEmpty;
+      SecureStore.tokenSync != null &&
+      SecureStore.tokenSync!.isNotEmpty;
```

```diff
     await Future.wait([
-      CacheManager.removeToken(),
-      CacheManager.removeRefreshToken(),
+      SecureStore.clearAll(),
       CacheManager.removeUserData(),
       CacheManager.removeUserType(),
       CacheManager.removeIsGuest(),
       CacheManager.removeRoles(),
     ]);
```

### 4. `lib/app/feature/splash/splash_controllers/splash_controller.dart`

```dart
import '../../../services/local_data/secure_store.dart';   // add
```

Use the **sync mirror** here, not the async getter:

```diff
-      final hasToken = CacheManager.token?.isNotEmpty ?? false;
+      final hasToken = SecureStore.tokenSync?.isNotEmpty ?? false;
       final hasUserData = CacheManager.userData?.isNotEmpty ?? false;
```

`_routeFromSession()` is `async`, so `await SecureStore.token` would compile — but it
would also hang `test/widget/app_boot_test.dart`. See
[Tests](#tests-the-mirror-is-not-optional) below. `init()` has already warmed the
mirror by the time splash runs, so the value is identical.

### 5. `lib/app/feature/auth/auth_controllers/signin_controller.dart`

```dart
import 'package:flutter_starter/app/services/local_data/secure_store.dart';   // add
```

```diff
             await Future.wait([
-              CacheManager.setToken(token!),
+              SecureStore.setToken(token!),
               if (refreshToken != null)
-                CacheManager.setRefreshToken(refreshToken),
+                SecureStore.setRefreshToken(refreshToken),
               CacheManager.setUserData(jsonEncode(user?.toJson())),
```

Both return `Future<bool>`, so the `Future.wait` list type is unchanged.

### 6. `lib/app/feature/auth/auth_controllers/verify_otp_controller.dart`

```dart
import 'package:flutter_starter/app/services/local_data/secure_store.dart';   // add
```

```diff
       await Future.wait([
-        CacheManager.setToken(token),
+        SecureStore.setToken(token),
         if (loginData.refreshToken != null)
-          CacheManager.setRefreshToken(loginData.refreshToken!),
+          SecureStore.setRefreshToken(loginData.refreshToken!),
         if (user != null) CacheManager.setUserData(jsonEncode(user.toJson())),
```

### 7. Optional — retire the plaintext token members

Once every call site above has moved and the migration has shipped to every install, delete from `lib/app/services/local_data/cache_manager.dart`:

```dart
  static String? get token => ...
  static Future<bool> setToken(String value) => ...
  static Future<bool> removeToken() => ...
  static String? get refreshToken => ...
  static Future<bool> setRefreshToken(String value) => ...
  static Future<bool> removeRefreshToken() => ...
```

Leave the `CacheKeys.token` and `CacheKeys.refreshToken` enum entries alone until then — the migration drains exactly those key names (`'token'`, `'refreshToken'`), and removing them early orphans the plaintext values it is supposed to delete.

---

## The friction: the getters are async

That is the whole cost of this module, so it is worth stating plainly.

| Before | After |
| --- | --- |
| `CacheManager.token` → `String?` | `await SecureStore.token` → `Future<String?>` |
| `CacheManager.refreshToken` → `String?` | `await SecureStore.refreshToken` → `Future<String?>` |

A `String?` and a `Future<String?>` are not interchangeable. Every read site must sit in an `async` body, and `'Bearer ${SecureStore.token}'` compiles but yields the literal `Bearer Instance of 'Future<String?>'` — a silent 401 in production. **Grep for `${SecureStore.token}` after the migration and make sure every one has an `await`.**

Two escape hatches for sync call sites:

- `SecureStore.tokenSync` / `refreshTokenSync` — the in-memory copy, populated by `init()` and kept in step by every setter. Use it in the `ApiService` constructor, in `UserDi.isLoggedIn`, and in `SplashScreenController`. It returns `null` if `init()` has not finished, so it is only safe after bootstrap.
- Widget-level reads: hold the token in a controller field loaded in `onInit()`, and let `GetBuilder`/`Obx` rebuild.

Holding the token in memory is not a weakness here — the plaintext version was in memory too, and any process that can read your heap has already won.

## Tests: the mirror is not optional

`flutter_secure_storage` talks over a `MethodChannel`. Inside `testWidgets` the binding
runs on fake async, so a channel call with no registered handler **never completes** — it
does not even throw `MissingPluginException`. The `await` just hangs and the test times out
or, worse, silently never navigates.

Observed: wiring `await SecureStore.token` into `SplashScreenController._routeFromSession()`
makes `test/widget/app_boot_test.dart` fail with `Found 0 widgets with type
"PlaceholderScreen"`, because the splash never finished routing. Using
`SecureStore.tokenSync` there fixes it — 35/35 pass.

Rules that keep the suite green:

- Anything on the **first-frame path** (splash, `UserDi.isLoggedIn`, the `ApiService`
  constructor) reads `tokenSync` / `refreshTokenSync`, never the async getters.
- The async getters are fine in `ApiService`'s interceptors and in auth controllers —
  nothing under `test/` exercises those.
- If you do need a real read in a widget test, register a mock handler first:

  ```dart
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => call.method == 'read' ? null : <String, String>{},
  );
  ```

## Usage

```dart
// Login
await SecureStore.setToken(accessToken);
await SecureStore.setRefreshToken(refreshToken);

// Any async read
final token = await SecureStore.token;
if (token != null && token.isNotEmpty) {
  headers['Authorization'] = 'Bearer $token';
}

// Sync read, only after SecureStore.init()
final t = SecureStore.tokenSync;

// Logout
await SecureStore.clearAll();
```

Run the migration by hand (it is idempotent and normally called by `init()`):

```dart
await SecureStore.migrateFromPlaintext();
```

## How the migration works

Once, on the first launch after install:

1. Reads `secure_store_migrated_v1` from `SharedPreferences`. If `true`, returns immediately.
2. For `token` and `refreshToken`: reads the plaintext `SharedPreferences` value; if the secure store does not already hold that key, writes it there; then removes the plaintext key either way.
3. Sets the flag — **only if both moves succeeded**. A failed write leaves the plaintext value in place and retries next launch rather than silently losing the session.

Notes:

- An existing secure value always wins over a plaintext one, so a half-migrated install cannot be rolled back to a stale token.
- The flag lives in `SharedPreferences`, not in the secure store, because it is not a secret. `CacheManager.removeAll()` on logout wipes it, so the next launch re-runs a no-op migration. Harmless.
- `clearAll()` deletes only this module's two keys. It never calls `deleteAll()`, which would wipe secrets other plugins keep in the same store.

## Threat model

**What this mitigates**

- **Plaintext at rest.** A rooted Android device, an ADB backup, a jailbroken iOS device, or a filesystem image no longer yields a usable bearer token by `cat`-ing an XML/plist file.
- **Sloppy backup exports.** Android Auto Backup and iTunes/Finder backups pick up `SharedPreferences` wholesale. Keychain items marked `first_unlock_this_device` never migrate to another device, so a backup restored onto a new phone does not carry the token with it.
- **Cross-app snooping on a compromised device.** Another app that somehow reads your app's data directory gets ciphertext it cannot unwrap without your KeyStore key.
- **Casual forensic recovery.** Removing the plaintext copy shrinks the window where a stale token lingers in an old backup.

**What this does NOT mitigate**

- **A live, rooted or jailbroken device with your app running.** Frida, a debugger, or a hooked runtime reads `SecureStore.tokenSync` straight out of the heap, or just calls `read()` as your app. Encryption at rest is not runtime protection.
- **Malware with your app's identity** — same UID on Android, same keychain access group on iOS. The OS hands it the decrypted value.
- **A stolen token in flight.** Use TLS with certificate pinning for that. Note the template's `badCertificateCallback` returns `kDebugMode`, so debug builds accept any certificate — not this module's concern, but worth knowing.
- **Server-side token lifetime.** A leaked token stays valid until the backend revokes it. Short TTLs and refresh-token rotation are the actual control.
- **Web.** `flutter_secure_storage_web` keeps AES-GCM ciphertext in `localStorage` with the wrapping key in IndexedDB. Any script in the page reads both. Treat web builds as unencrypted; an XSS wins either way.
- **The rest of the cache.** `userData`, `roles`, `loginEmail` and `loginPassword` are still plaintext in `SharedPreferences`. `loginPassword` in particular ("remember me") is a bigger problem than the token was — move it here too, or stop storing it.
- **Screen recording, clipboard, notification previews, and everything else that leaks a token after it is decrypted.**

Net: this raises the bar from "trivially readable file" to "needs code execution as your app". It is a real, cheap improvement, not a security boundary.

## Notes and gotchas

- **First read is slow.** The first Keychain/KeyStore access takes tens of milliseconds and involves a platform channel. `init()` pays that cost once at startup so later `tokenSync` reads are free.
- **`resetOnError: true`.** If a value cannot be decrypted — algorithm change, restored backup, corrupted KeyStore — the plugin **permanently erases** the store instead of throwing. The user re-logs in. The alternative is an unrecoverable crash on launch, which is worse.
- **Unit tests.** There is no platform channel under `flutter test`; calls throw `MissingPluginException`. `SecureStore` catches and returns `null` / `false`, so tests do not crash, but they also cannot round-trip a value. Mock `FlutterSecureStoragePlatform` if you need real coverage.
- **`SecureStore` is a static class, not a `GetxService`.** That is deliberate: it mirrors `CacheManager`, sits beside it in `local_data/`, and is readable before GetX is initialised.
- **Android `storageNamespace`.** If you ever run two `FlutterSecureStorage` instances with different cipher settings, give them distinct namespaces or they fight over the same KeyStore alias.

## Why it is not in core

It adds a native plugin, raises `minSdk` to 24, needs Android backup and macOS entitlement config, and turns two synchronous getters into `Future`s across every auth call site — a migration each project should opt into deliberately.
