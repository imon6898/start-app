# webview

A full in-app browser screen built on `flutter_inappwebview` — progress bar, live page title, nav bar, share, open-in-browser and copy link.

## Install

```bash
dart run tool/add_module.dart webview
```

Manual, if you prefer:

1. Copy `modules/webview/lib/app/widgets/custom_webview.dart` to `lib/app/widgets/custom_webview.dart` (the module mirrors the project tree, so the relative path is the destination).
2. Add the dependencies below to `pubspec.yaml`.
3. Apply the platform config below.
4. `flutter pub get`.

## Dependencies

Paste into `pubspec.yaml` under `dependencies:`:

```yaml
  flutter_inappwebview: ^6.1.5
  share_plus: ^13.3.0
  url_launcher: ^6.3.2
```

`get` is already in the template. Also required from core: `app_colors.dart`, `app_fonts.dart`, `appbar_widgets/appbar_widget.dart`.

## Platform config

No API keys. `flutter_inappwebview` 6.x auto-registers — no `MainActivity` or `AppDelegate` edits.

### Android

`android/app/build.gradle.kts` — `flutter_inappwebview` requires **minSdk 21+** and **compileSdk 34+**. Flutter's defaults already meet this; pin explicitly only if your app lowered them:

```kotlin
android {
    compileSdk = 34
    defaultConfig { minSdk = 21 }
}
```

`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

If you load plain-HTTP pages (Android 9+ blocks them by default), add to `<application>`:

```xml
<application android:usesCleartextTraffic="true" ... >
```

`url_launcher` needs a `<queries>` block as a direct child of `<manifest>` so `tel:`, `mailto:`, `sms:` and the external browser resolve:

```xml
<queries>
  <intent><action android:name="android.intent.action.VIEW"/>
    <data android:scheme="https"/></intent>
  <intent><action android:name="android.intent.action.DIAL"/>
    <data android:scheme="tel"/></intent>
  <intent><action android:name="android.intent.action.SENDTO"/>
    <data android:scheme="mailto"/></intent>
  <intent><action android:name="android.intent.action.SENDTO"/>
    <data android:scheme="sms"/></intent>
</queries>
```

### iOS

`ios/Podfile` — minimum deployment target **iOS 12**; the template is already on 13.0:

```ruby
platform :ios, '13.0'
```

`ios/Runner/Info.plist` — schemes `url_launcher` is allowed to probe:

```xml
<key>LSApplicationQueriesSchemes</key>
<array><string>tel</string><string>mailto</string><string>sms</string><string>https</string></array>
```

Plain-HTTP pages need an ATS exception (skip if everything is HTTPS):

```xml
<key>NSAppTransportSecurity</key>
<dict><key>NSAllowsArbitraryLoads</key><true/></dict>
```

## Usage

```dart
import 'package:flutter_starter/app/widgets/custom_webview.dart';

// One-liner via the built-in GetX navigation helper.
CustomWebView.open('https://example.com/terms', title: 'Terms of Service');

// Or embed the widget yourself.
Get.to(() => const CustomWebView(
      url: 'https://example.com/help',
      title: 'Help',
      enableShare: false,
      enableOpenInBrowser: true,
    ));
```

Hardware/system back navigates the web history first and only pops the route once the history is exhausted. `tel:`, `mailto:`, `sms:` and Play Store / App Store links are handed off to the OS instead of loading in the WebView.

## Why it is not in core

`flutter_inappwebview` ships a large native layer and raises the Android/iOS build floor, so it stays out of the lean template until the app really needs an in-app browser.

## Notes

Recovered from `lib/app/widgets/custom_webview.dart` at commit `b860a8e`. Two fixes applied so it compiles against the pinned versions: `Share.share(...)` → `SharePlus.instance.share(ShareParams(...))` (removed in share_plus 11+), and the "Copy Link" menu item — previously an empty stub — now writes to the clipboard via `Clipboard.setData`.
