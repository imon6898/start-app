# deep_links

Deep links, Android App Links and iOS Universal Links routed onto the **existing** `AppRoutes` table —
a declarative pattern map, path/query params handed over as `Get.arguments`, a guard that bounces
auth-only links through sign-in and resumes them afterwards, and a fall-through to
`AppPages.unknownRoute` for anything unrecognised.

`https://example.com/product/42?ref=push` → `AppRoutes.ProductScreen` with
`Get.arguments = {'id': '42', 'ref': 'push', 'deepLinkUri': '...'}`.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/deep_link_config.dart` | `DeepLinkConfig` — the only file you edit: schemes, hosts, the pattern → route map, the auth-only set. Plus `DeepLinkMatch` (one resolved link) and the `DeepLinkGuard` typedef. |
| `lib/app/services/deep_link_service.dart` | `DeepLinkService` — a `GetxService` over `app_links`: cold-start link, warm-resume stream, pattern matching, guard + park/resume, unknown fall-through. |
| `test/services/deep_link_service_test.dart` | 7 VM tests over the matcher and the guard (no plugin channel, no widget tester). Delete it if you don't want it. |

## Install

```bash
dart run tool/add_module.dart deep_links --dry-run   # see the plan
dart run tool/add_module.dart deep_links             # install
flutter pub get
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the
project:

```bash
cp modules/deep_links/lib/app/services/deep_link_config.dart  lib/app/services/
cp modules/deep_links/lib/app/services/deep_link_service.dart lib/app/services/
mkdir -p test/services && cp modules/deep_links/test/services/deep_link_service_test.dart test/services/
```

### pubspec.yaml

The installer adds this for you; verbatim in case you are wiring it by hand:

```yaml
dependencies:
  # deep_links module
  app_links: ^7.1.1
```

`get` and `shared_preferences` are already in the template core. `app_links` 7.1.1 needs Flutter ≥ 3.44
and iOS ≥ 13 — the template is on Flutter 3.44.8, so nothing to bump.

---

## Wiring

Three core files get one line each, plus the link table you edit. Nothing else in `lib/` is touched.

### 1. `lib/bootstrap.dart` — register the service before the first frame

`app_links` must be instantiated early or the cold-start link is gone by the time anything listens.

```dart
import 'package:get/get.dart';                        // add — bootstrap has no get import yet
import 'app/services/deep_link_service.dart';         // add
```

```dart
    // App.build reads ThemeController, so register before the first frame.
    ViewModelBinding().dependencies();

    // Captures the cold-start link and starts the warm-resume stream.   ← add
    await Get.putAsync(() => DeepLinkService().init(), permanent: true); // ← add

    runApp(const App());
```

### 2. `lib/app/feature/splash/splash_controllers/splash_controller.dart` — open the cold link last

The splash finishes with `Get.offAllNamed`, which would wipe a link opened before it. Dispatch the
cold-start link *after* the session redirect, at the end of `_routeFromSession()`:

```dart
      } else {
        Get.offAllNamed(AppRoutes.OnboardingScreen);
      }

      // Cold-start deep link, now that the first real screen is on the stack.
      DeepLinkService.dispatchInitial();   // ← add
    } catch (e) {
```

plus the import:

```dart
import '../../../services/deep_link_service.dart';
```

### 3. `lib/app/feature/auth/auth_controllers/signin_controller.dart` — resume a parked link

In `signIn()`, straight after the successful-login redirect:

```dart
            Get.offAllNamed(AppRoutes.DashboardScreen);
            DeepLinkService.resume();   // ← add — opens the link that forced the sign-in
```

plus the import:

```dart
import 'package:flutter_starter/app/services/deep_link_service.dart';
```

`DeepLinkService.dispatchInitial()` and `DeepLinkService.resume()` are the static, never-throwing
wrappers around `dispatchInitialLink()` / `resumePending()`: both no-op when nothing is parked **and**
when the service was never registered, so widget tests that skip `bootstrap()` keep passing.

### 4. `ViewModelBinding` — nothing to add

`DeepLinkService` is a `GetxService`, not a screen controller; `bootstrap.dart` owns it. If you would
rather register it in `lib/app/bindings/view_model_binding.dart`, the line is:

```dart
    Get.putAsync(() => DeepLinkService().init(), permanent: true);
```

It is async there, so a cold-start link can arrive a frame later than the splash expects — the
bootstrap `await` above is the safer place.

### 5. `AppRoutes` / `AppPages` — nothing to add

This module never registers a route. It only navigates to names that already exist in `AppPages.pages`;
a pattern pointing at a route that is not registered lands on `AppPages.unknownRoute`, exactly like an
unmatched link.

---

## The link table

`lib/app/services/deep_link_config.dart` is the whole configuration:

```dart
class DeepLinkConfig {
  /// Custom schemes this app owns: flutterstarter://product/42
  static const Set<String> schemes = {'flutterstarter'};

  /// Hosts accepted on http/https links. Empty set = accept any host.
  static const Set<String> hosts = {'example.com', 'www.example.com'};

  static const Map<String, String> routes = {
    '/': AppRoutes.DashboardScreen,
    '/signin': AppRoutes.SigninScreen,
    '/terms': AppRoutes.TermsOfServiceScreen,
    '/privacy': AppRoutes.PrivacyPolicyScreen,
    '/verify/:email': AppRoutes.VerifyOtpScreen,
    '/reset-password/:token': AppRoutes.RetypePassScreen,
    '/product/:id': AppRoutes.DashboardScreen,   // → AppRoutes.ProductScreen once it exists
  };

  /// Routes that need a signed-in user; the default guard parks these.
  static const Set<String> authOnly = {AppRoutes.DashboardScreen};

  static const String signInRoute = AppRoutes.SigninScreen;
}
```

Pattern rules:

| Pattern piece | Matches | Lands in |
| --- | --- | --- |
| `product` | that exact segment, case-insensitive | — |
| `:id` | exactly one segment | `pathParams['id']` |
| `*` (trailing) | every remaining segment | `pathParams['rest']` |

Literal beats `:param` beats `*`, so `/product/new` wins over `/product/:id` regardless of map order.

`Get.arguments` is a `Map<String, dynamic>`: query params first, then path params (a path param wins a
name clash), plus `deepLinkUri` with the raw link.

---

## Usage

A screen opened by a link reads the parsed pieces from `Get.arguments`:

```dart
class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = (Get.arguments as Map?) ?? const {};
    final id = args['id'] as String?;      // from /product/:id
    final ref = args['ref'] as String?;    // from ?ref=push
    ...
  }
}
```

Open a link that did not come from the OS — a push payload, a QR scan, an in-app banner:

```dart
DeepLinkService.to.open('https://example.com/product/42?ref=push');
DeepLinkService.to.handle(uri, replace: true);   // offNamed instead of toNamed
```

Replace the guard with your own rule (roles, entitlements, a paywall):

```dart
DeepLinkService.to.guard = (match) {
  if (match.route == AppRoutes.PremiumScreen) return Get.find<UserDi>().hasRole('pro');
  return !DeepLinkConfig.authOnly.contains(match.route) || DeepLinkService.to.isSignedIn;
};
```

Returning `false` parks the link in `pendingLink` and sends the user to `signInRoute`; `resumePending()`
opens it afterwards. `clearPending()` drops it (call it if the user backs out of sign-in).

---

## Platform config

Replace `example.com` with your domain, `flutterstarter` with your scheme and `com.easital.starter`
with your `applicationId` throughout.

### 1. Android — `android/app/src/main/AndroidManifest.xml`

Inside the existing `<activity android:name=".MainActivity">`, next to the LAUNCHER intent-filter:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    ...>

    <!-- Flutter's own deep-link routing would fight GetX -->
    <meta-data android:name="flutter_deeplinking_enabled" android:value="false" />

    <!-- Verified App Links: https://example.com/... -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="http"  android:host="example.com" />
        <data android:scheme="https" android:host="example.com" />
        <data android:scheme="https" android:host="www.example.com" />
    </intent-filter>

    <!-- Custom scheme: flutterstarter://product/42 -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="flutterstarter" />
    </intent-filter>

    <!-- existing NormalTheme meta-data and LAUNCHER intent-filter stay as they are -->
</activity>
```

`android:launchMode="singleTop"` is already in the template — keep it, or every link starts a second
activity instead of resuming the running one.

### 2. Android — `https://example.com/.well-known/assetlinks.json`

Served over HTTPS as `application/json`, no redirects, no auth:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.easital.starter",
      "sha256_cert_fingerprints": [
        "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"
      ]
    }
  }
]
```

The fingerprint is the **signing** certificate's SHA-256, not the upload one:

```bash
# Play App Signing: Play Console → Test and release → App integrity → App signing key certificate
# Local keystore:
keytool -list -v -keystore ~/upload-keystore.jks -alias upload | grep SHA256
```

List the debug fingerprint too while developing (`~/.android/debug.keystore`, password `android`) — a
debug build is signed with a different key and will not verify otherwise.

### 3. iOS — Associated Domains entitlement

Xcode → **Runner** target → **Signing & Capabilities** → **+ Capability** → **Associated Domains**, then
add `applinks:example.com`. That creates `ios/Runner/Runner.entitlements` (the template ships none):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:example.com</string>
        <string>applinks:www.example.com</string>
    </array>
</dict>
</plist>
```

The App ID in your Apple Developer account must have the **Associated Domains** capability enabled, and
the provisioning profile must be regenerated after you turn it on.

### 4. iOS — `ios/Runner/Info.plist`

```xml
<!-- Flutter's own deep-link routing would fight GetX -->
<key>FlutterDeepLinkingEnabled</key>
<false/>

<!-- Custom scheme: flutterstarter://product/42 -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.easital.starter</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>flutterstarter</string>
        </array>
    </dict>
</array>
```

No `AppDelegate.swift` / `SceneDelegate.swift` change: `app_links` 7 registers itself as a scene
delegate and the template's `SceneDelegate` already extends `FlutterSceneDelegate`.

### 5. iOS — `https://example.com/.well-known/apple-app-site-association`

**No `.json` extension**, served as `application/json` over HTTPS, no redirects, no auth. `TEAMID` is
the 10-character Apple Team ID:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["TEAMID.com.easital.starter"],
        "components": [
          { "/": "/product/*", "comment": "Product pages" },
          { "/": "/order/*/track", "comment": "Order tracking" },
          { "/": "/reset-password/*" },
          { "/": "/verify/*" },
          { "/": "/terms" },
          { "/": "/privacy" },
          { "/": "/" }
        ]
      }
    ]
  }
}
```

Every path you list in `DeepLinkConfig.routes` must appear here, or iOS opens Safari instead of the app.

### 6. Test it

```bash
# Android — App Link and custom scheme
adb shell am start -a android.intent.action.VIEW \
  -c android.intent.category.BROWSABLE \
  -d "https://example.com/product/42?ref=push" com.easital.starter
adb shell am start -a android.intent.action.VIEW \
  -d "flutterstarter://product/42" com.easital.starter

# Android — did verification actually pass?
adb shell pm get-app-links com.easital.starter
adb shell pm verify-app-links --re-verify com.easital.starter

# iOS simulator
xcrun simctl openurl booted "flutterstarter://product/42"
xcrun simctl openurl booted "https://example.com/product/42"

# Is the association file reachable?
curl -sSI https://example.com/.well-known/assetlinks.json
curl -sS   https://example.com/.well-known/apple-app-site-association
```

On a device, typing the URL in Safari's address bar does **not** trigger a Universal Link — tap it from
Notes or Messages instead.

---

## Notes and gotchas

- **Cold start is a two-step.** `init()` only *captures* the initial link; `dispatchInitialLink()` opens
  it. Skip wiring step 2 and links that launch a cold app silently do nothing. `app_links` also replays
  that first link on its stream — the service drops the replay so it is never handled twice.
- **Custom schemes eat the first segment.** `Uri.parse('myapp://product/42')` gives host `product` and
  path `/42`. The matcher retries with the host prepended when the plain path matches nothing, so both
  `myapp://product/42` and `myapp://open.my.app/product/42` reach `/product/:id`.
- **Unknown links are visible, not silent.** An unmatched path, a foreign host or a foreign scheme goes
  to `AppPages.unknownRoute` with `{'deepLinkUri': ...}` in the arguments, plus a `devPrint` line tagged
  `DeepLink`.
- **The guard runs on the matched route, not the URL**, so a route listed in `authOnly` is protected no
  matter how many patterns point at it.
- **Links push, they don't replace.** `handle()` uses `Get.toNamed` so back returns to where the user
  was; pass `replace: true` for `Get.offNamed`.
- **Sign-in bounce, not sign-in wall.** A parked link survives in memory only. If the user kills the app
  at the sign-in screen, the link is gone — persist it yourself if that matters.
- **iOS caches the AASA file.** Reinstall the app after changing it, or enable
  Settings → Developer → Associated Domains Development and use `applinks:example.com?mode=developer`.
- **Android verification is asynchronous** and needs a network round-trip on install; `pm get-app-links`
  showing `verified` is the only proof that HTTPS links will open the app rather than Chrome.
- Verified against `app_links` 7.1.1 in the pub cache — `AppLinks()` singleton, `getInitialLink()`,
  `uriLinkStream`, and the iOS plugin's `initialLinkSent` replay behaviour.

## Why it is not in core

A link table is meaningless without a domain, an entitlement and two hosted association files — every
project's is different, and a template that shipped one would ship a dead `example.com` in three
platform files.
