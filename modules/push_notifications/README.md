# push_notifications

Firebase Cloud Messaging + `flutter_local_notifications`: permission, token sync to your backend, foreground rendering on a real Android channel, and tap-to-route that works from a cold start as well as a warm one.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/push_notification_service.dart` | `PushNotificationService` — the `GetxService`. FCM init, permission, token + refresh listener, foreground rendering, tap routing. Also the two top-level background handlers. |
| `lib/app/services/push_notifications/push_notification_config.dart` | `PushChannel` (channel id/name/icon), `PushPayloadKeys`, `PushRoutes` — the slug → `AppRoutes` map you extend. |
| `lib/app/services/push_notifications/push_payload.dart` | `PushPayload` — the typed `data` map, with JSON encode/decode for local-notification payloads. |
| `lib/app/services/push_notifications/push_notification_api_const.dart` | `PushApiConst` — the two device-token endpoints, kept out of core `ApiConstant`. |
| `lib/app/services/push_notifications/push_notification_api_service.dart` | `PushApiService` / `PushImpl` / `PushRepo` — the Style-A trio that POSTs the token. |

## Install

```bash
dart run tool/add_module.dart push_notifications
flutter pub get
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
mkdir -p lib/app/services/push_notifications
cp modules/push_notifications/lib/app/services/push_notification_service.dart              lib/app/services/
cp modules/push_notifications/lib/app/services/push_notifications/*.dart                   lib/app/services/push_notifications/
```

### 1. pubspec.yaml

```yaml
dependencies:
  firebase_core: ^4.14.0
  firebase_messaging: ^16.6.0
  flutter_local_notifications: ^21.0.0
```

`get`, `dio` and `shared_preferences` are already in the template core.

`flutter_local_notifications` 21 requires **minSdk 24 / compileSdk 36** and **iOS 13**. The template already resolves `flutter.minSdkVersion = 24` and `flutter.compileSdkVersion = 36`, so Android needs no change.

### 2. Firebase console

1. Create the project, add an **Android** app using the `applicationId` in `android/app/build.gradle.kts` (`com.easital.starter`), and an **iOS** app with the same bundle id.
2. `google-services.json` → **`android/app/google-services.json`**.
3. `GoogleService-Info.plist` → **`ios/Runner/GoogleService-Info.plist`**, added through Xcode (drag onto the Runner target, *Copy items if needed*). Copying the file on disk alone does **not** add it to the build — the app will crash on `Firebase.initializeApp()`.
4. Both files identify your project. Gitignore them if the repo is public.

### 3. Android — `android/settings.gradle.kts`

```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    id("com.google.gms.google-services") version "4.4.4" apply false   // add
}
```

### 4. Android — `android/app/build.gradle.kts`

```kotlin
plugins {
    id("com.android.application")
    id("com.google.gms.google-services")   // add, before the Flutter plugin
    id("dev.flutter.flutter-gradle-plugin")
}
```

### 5. Android — `android/app/src/main/AndroidManifest.xml`

Permissions directly inside `<manifest>`, the channel/icon defaults inside `<application>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <application ...>
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="high_importance_channel"/>
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@mipmap/ic_launcher"/>
        ...
    </application>
</manifest>
```

The channel id must match `PushChannel.id`. Without it, notifications that arrive while the app is backgrounded land on Android's low-importance default channel and never make a sound.

**Icon.** `@mipmap/ic_launcher` works but Android renders the small icon as a white silhouette, so a coloured launcher icon turns into a white blob. The proper fix is a white-on-transparent drawable at `android/app/src/main/res/drawable/ic_notification.png`, then change both the manifest `default_notification_icon` and `PushChannel.androidIcon` to `@drawable/ic_notification`.

**Release builds** shrink resources. Keep the icon or notifications silently fail — `android/app/src/main/res/raw/keep.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/*,@mipmap/ic_launcher"/>
```

### 6. iOS — capabilities and the APNs key

1. Xcode → Runner → **Signing & Capabilities**: add **Push Notifications**, and **Background Modes** with *Remote notifications* ticked.
2. Apple Developer → **Keys** → create an **APNs Auth Key** (`.p8`, download it once — Apple will not show it again).
3. Firebase Console → Project settings → **Cloud Messaging** → *APNs Authentication Key* → upload the `.p8` with its **Key ID** and your **Team ID**.

Skip step 3 and iOS will happily hand you an FCM token and then never deliver a single message.

### 7. iOS — `ios/Runner/AppDelegate.swift`

This template runs the **UIScene** lifecycle (`SceneDelegate.swift`, `FlutterImplicitEngineDelegate`), so plugins register *after* `didFinishLaunchingWithOptions` returns — while Apple requires `UNUserNotificationCenter.delegate` to be set *before* it does. Both plugins document an explicit hook for this case:

```swift
import Flutter
import UIKit
import firebase_messaging                 // add
import flutter_local_notifications        // add

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()   // add, before super
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // add — lets the action isolate reach the plugins
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
```

Then uncomment the platform line in `ios/Podfile` so it reads `platform :ios, '13.0'` and run `cd ios && pod install`.

Push notifications do not work on the iOS Simulator. Test on a device.

## Wiring

### `lib/bootstrap.dart`

Inside `runZonedGuarded`, after `await CacheManager.init();` and **before** `runApp(const App())`:

```dart
await Firebase.initializeApp();
await Get.putAsync(() => PushNotificationService().init());
```

with the imports:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'app/services/push_notification_service.dart';
```

`Firebase.initializeApp()` with no arguments reads `google-services.json` / `GoogleService-Info.plist`. If you ran `flutterfire configure`, pass its output instead:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

### `ViewModelBinding` / `AppRoutes` / `AppPages`

Nothing to add. `PushNotificationService` is a `GetxService` owned by `bootstrap.dart`, not a screen controller, and the module ships no screens. Tap routing only ever navigates to constants that already exist in `AppRoutes`.

### After sign-in

The token is only POSTed once a session exists, so call this at the end of your login success path:

```dart
await PushNotificationService.to.syncToken();
```

### On logout

Before clearing the cache, so the request still carries the bearer token:

```dart
await PushNotificationService.to.unregisterToken();
```

### Your backend

```
POST /notify/devices/register     { "token": "...", "platform": "android" }
POST /notify/devices/unregister   { "token": "...", "platform": "android" }
```

Both are relative paths on `ApiService`'s base URL and carry the session bearer token, so the backend knows whose device it is. Change them in `push_notification_api_const.dart` — core `api_const.dart` is untouched.

## Usage

Nothing to call in a screen: once bootstrap runs, messages render and taps route on their own.

```dart
final service = PushNotificationService.to;

Obx(() => Text(service.token.value ?? 'no token'.tr));   // current FCM token
await service.requestPermission();                        // re-prompt (no-op once answered)
await service.syncToken();                                // after sign-in
await service.unregisterToken();                          // on logout
```

### Payload contract

Your backend sends a normal `notification` block plus a `data` map:

```json
{
  "notification": { "title": "Order #1042 shipped", "body": "Arriving Friday" },
  "data": { "route": "dashboard", "id": "1042" },
  "android": { "notification": { "channel_id": "high_importance_channel" } }
}
```

`route` is either a slug from `PushRoutes.bySlug` or a raw path that is already an `AppRoutes` value. Anything else is ignored — an unknown route never navigates. The whole `data` map arrives as `Get.arguments`:

```dart
final id = (Get.arguments as Map?)?['id'];
```

### Adding a screen to the deep-link map

`push_notification_config.dart`:

```dart
static final Map<String, String> bySlug = <String, String>{
  'dashboard': AppRoutes.DashboardScreen,
  'order': AppRoutes.OrderDetailsScreen,   // add yours
  ...
};
```

### Cold-start timing

A tap on a killed app arrives through `getInitialMessage()` before your splash has decided where to send the user. The service holds it and replays it `1500 ms` after the first frame. To drive the timing yourself:

```dart
// bootstrap.dart
await Get.putAsync(
  () => PushNotificationService(autoHandleInitialMessage: false).init(),
);

// splash_controller.dart, once the landing route is decided
PushNotificationService.to.flushPendingRoute();
```

## Notes and gotchas

- **The background handlers must stay top-level.** `pushBackgroundHandler` and `pushBackgroundTapHandler` are top-level functions annotated `@pragma('vm:entry-point')`. Firebase runs them in a fresh isolate; turning them into methods or closures, or dropping the annotation, breaks them in release builds with no error message. The handler re-initialises Firebase because that isolate has no app of its own.
- That isolate has no GetX and no navigator, so it cannot navigate. A tap on a backgrounded or killed app is replayed on the next launch through `getInitialMessage()` / `getNotificationAppLaunchDetails()`.
- **Foreground rendering.** Android never displays FCM notifications while the app is foregrounded — the module draws them. On iOS the OS would, so the service calls `setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false)`; leaving alerts on shows every message twice. That setting is **persisted by iOS**, so if you remove the module you must call it again with `alert: true` to undo it.
- **Data-only messages** (no `notification` block) are not rendered — `showForeground` returns early. Handle them there or listen to `FirebaseMessaging.onMessage` yourself.
- `syncToken()` is a no-op while `CacheManager.token` is empty; that is why the login path has to call it. The `onTokenRefresh` listener calls it too, and it is guarded against overlapping requests.
- Android 13+ `POST_NOTIFICATIONS` and the iOS prompt are the same call: `requestPermission()` asks FCM first, then nudges `flutter_local_notifications` on Android. Both are no-ops once the user has answered.
- `PushApiConst` is standalone, so installing this module needs no edit to core `lib/app/services/domain/api_const.dart`.

## Why it is not in core

It drags in the whole Firebase Android/iOS SDK, a `google-services.json`, an APNs key and a paid Apple membership — a hard dependency most projects starting from this template do not want on day one.
