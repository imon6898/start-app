# settings_ui

The settings screen the template is missing. `ThemeController` and `AppTranslations.setLocale()` already ship in core, already persist to `CacheManager`, and nothing in `lib/` ever calls them — this module is the UI that does.

Theme switcher, language switcher, notification toggle, app version, privacy/terms links, clear cache, logout. Built entirely from the existing widget kit (`SectionHeader`, `CardContainer`, `CustomDivider`, `showCustomBottomSheet`, `showDeleteConfirmationDialog`) — it adds no new widget class.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/feature/settings/settings_presentation/settings_screen.dart` | `SettingsScreen` — five sections of rows, two bottom-sheet pickers, two confirm dialogs. `StatelessWidget` + `GetBuilder`. |
| `lib/app/feature/settings/settings_controllers/settings_controller.dart` | `SettingsController` — owns every action. Talks to `ThemeController`, `AppTranslations`, `CacheManager`, `UserDi`, `url_launcher` and `package_info_plus`. |
| `lib/app/feature/settings/settings_logic/settings_store.dart` | `SettingsStore` — the notification flag, under the module's own SharedPreferences key. No edit to core `CacheManager`. |
| `lib/app/feature/settings/settings_logic/settings_links.dart` | `SettingsLinks` — privacy / terms / support URLs read through `Env.optional`. No edit to core `Env`. |

There is no `settings_models/` and no `*_api_service.dart`: the screen has no backend. Add the trio later if you sync preferences to a server.

## Install

```bash
dart run tool/add_module.dart settings_ui
flutter pub get
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
mkdir -p lib/app/feature/settings/{settings_logic,settings_controllers,settings_presentation}
cp modules/settings_ui/lib/app/feature/settings/settings_logic/settings_store.dart              lib/app/feature/settings/settings_logic/
cp modules/settings_ui/lib/app/feature/settings/settings_logic/settings_links.dart              lib/app/feature/settings/settings_logic/
cp modules/settings_ui/lib/app/feature/settings/settings_controllers/settings_controller.dart   lib/app/feature/settings/settings_controllers/
cp modules/settings_ui/lib/app/feature/settings/settings_presentation/settings_screen.dart      lib/app/feature/settings/settings_presentation/
```

### 1. pubspec.yaml

```yaml
dependencies:
  package_info_plus: ^10.2.1
  url_launcher: ^6.3.2
```

`get`, `shared_preferences` and `lucide_icons_flutter` are already in the template core. These two are the only additions — that is the point of this module.

> If you also install **app_update_gate**, it pins the same two packages at the same versions, so the installer just reports "already present".

### 2. .env — all three keys optional

```env
PRIVACY_POLICY_URL=https://example.com/privacy
TERMS_OF_SERVICE_URL=https://example.com/terms
SUPPORT_URL=https://example.com/support
```

Read through `Env.optional(...)`, so **leaving them out is a supported state**: an empty `PRIVACY_POLICY_URL` makes the row open the in-app `AppRoutes.PrivacyPolicyScreen` instead of the browser. Do not add them to `Env.requiredKeys`.

### 3. Android — `android/app/src/main/AndroidManifest.xml`

`url_launcher` needs a `<queries>` block as a direct child of `<manifest>` so `https:` resolves to a browser:

```xml
<queries>
  <intent><action android:name="android.intent.action.VIEW"/>
    <data android:scheme="https"/></intent>
</queries>
```

`package_info_plus` needs nothing — it reads `versionName` / `versionCode` from the build itself.

### 4. iOS — `ios/Runner/Info.plist`

```xml
<key>LSApplicationQueriesSchemes</key>
<array><string>https</string></array>
```

Add `<string>http</string>` only if you link to a plain-HTTP page. No `Podfile` bump and no `AppDelegate` change; `package_info_plus` reads `CFBundleShortVersionString` / `CFBundleVersion` with no config.

## Wiring

Three core files need an entry. These are the exact lines.

### `lib/app/bindings/view_model_binding.dart`

`SettingsScreen` is `GetBuilder<SettingsController>`, so it throws on first build without this.

```dart
import '../feature/settings/settings_controllers/settings_controller.dart';
```

```dart
    // Settings
    _lazy<SettingsController>(() => SettingsController());
```

### `lib/app/routes/app_routes.dart`

```dart
  /// Settings
  static const String SettingsScreen = '/settingsScreen';
```

### `lib/app/routes/app_pages.dart`

```dart
import '../feature/settings/settings_presentation/settings_screen.dart';
```

```dart
    // Settings
    _page(AppRoutes.SettingsScreen, () => const SettingsScreen()),
```

### `lib/bootstrap.dart` — nothing required

`SettingsController.onInit()` calls `SettingsStore.init()` itself, and `CacheManager.init()` already runs in `bootstrap()`. There is no startup call to add.

### Optional — hooks, set once after the controller resolves

```dart
final settings = Get.find<SettingsController>();
settings.logoutRoute = AppRoutes.SigninScreen;              // default
settings.keepPreferencesOnLogout = true;                    // default
settings.onNotificationsChanged = (enabled) async {         // your push SDK
  enabled ? await Messaging.subscribe() : await Messaging.unsubscribe();
};
settings.onClearCache = () async {                          // your disk cache
  await DefaultCacheManager().emptyCache();
};
```

### Optional — translations

The screen's strings are not in `AppTranslations`, so `.tr` falls through to the English key and the screen reads correctly out of the box. To localise it, paste into `lib/app/localization/app_translations.dart`:

```dart
    // 'en_US' block
      // Settings
      'Settings': 'Settings',
      'Appearance': 'Appearance',
      'Theme': 'Theme',
      'Light': 'Light',
      'Dark': 'Dark',
      'System default': 'System default',
      'Language': 'Language',
      'Notifications': 'Notifications',
      'Push notifications': 'Push notifications',
      'About': 'About',
      'App version': 'App version',
      'Terms of Service': 'Terms of Service',
      'Storage': 'Storage',
      'Clear cache': 'Clear cache',
      'Clear cache?': 'Clear cache?',
      'Cached images and temporary files will be removed.':
          'Cached images and temporary files will be removed.',
      'Clear': 'Clear',
      'Cancel': 'Cancel',
      'Cache cleared': 'Cache cleared',
      'Temporary files have been removed': 'Temporary files have been removed',
      'Could not clear cache': 'Could not clear cache',
      'Please try again': 'Please try again',
      'Could not open link': 'Could not open link',
      'Account': 'Account',
      'Log out': 'Log out',
      'Log out?': 'Log out?',
      'You will need to sign in again to continue.':
          'You will need to sign in again to continue.',
```

```dart
    // 'bn_BD' block
      // Settings
      'Settings': 'সেটিংস',
      'Appearance': 'অ্যাপিয়ারেন্স',
      'Theme': 'থিম',
      'Light': 'লাইট',
      'Dark': 'ডার্ক',
      'System default': 'সিস্টেম ডিফল্ট',
      'Language': 'ভাষা',
      'Notifications': 'বিজ্ঞপ্তি',
      'Push notifications': 'পুশ বিজ্ঞপ্তি',
      'About': 'সম্পর্কে',
      'App version': 'অ্যাপ সংস্করণ',
      'Terms of Service': 'সেবার শর্তাবলী',
      'Storage': 'স্টোরেজ',
      'Clear cache': 'ক্যাশ পরিষ্কার করুন',
      'Clear cache?': 'ক্যাশ পরিষ্কার করবেন?',
      'Cached images and temporary files will be removed.':
          'ক্যাশ করা ছবি ও অস্থায়ী ফাইল মুছে ফেলা হবে।',
      'Clear': 'পরিষ্কার',
      'Cancel': 'বাতিল',
      'Cache cleared': 'ক্যাশ পরিষ্কার হয়েছে',
      'Temporary files have been removed': 'অস্থায়ী ফাইল মুছে ফেলা হয়েছে',
      'Could not clear cache': 'ক্যাশ পরিষ্কার করা যায়নি',
      'Please try again': 'আবার চেষ্টা করুন',
      'Could not open link': 'লিঙ্কটি খোলা যায়নি',
      'Account': 'অ্যাকাউন্ট',
      'Log out': 'লগ আউট',
      'Log out?': 'লগ আউট করবেন?',
      'You will need to sign in again to continue.':
          'চালিয়ে যেতে আপনাকে আবার সাইন ইন করতে হবে।',
```

`'Privacy Policy'` and `'Terms'` already exist in both blocks. The **language names** (`English`, `বাংলা`) are deliberately not translated — a language lists itself in its own tongue.

## Usage

Navigate to it like any other screen:

```dart
Get.toNamed(AppRoutes.SettingsScreen);
```

Or, before you add the route, push it as a widget:

```dart
Get.to(() => const SettingsScreen());
```

Drive the same state from your own screens — the controller is the whole API:

```dart
final settings = Get.find<SettingsController>();

await settings.changeTheme(ThemeMode.dark);              // persists via ThemeController
await settings.changeLocale(const Locale('bn', 'BD'));   // persists via AppTranslations
await settings.setNotifications(false);                  // persists via SettingsStore
await settings.clearCache(context);
await settings.logout();                                 // wipes session, offAllNamed

settings.themeMode;                        // ThemeMode
settings.locale;                           // Locale
settings.supportedLocales;                 // AppTranslations.supported
settings.appVersion.value;                 // "1.0.0 (1)" — RxString
settings.notificationsEnabled.value;       // RxBool
```

### Adding a row

Rows are private helpers in the screen, not a widget class. Copy the shape:

```dart
_row(
  icon: LucideIcons.userRound,
  title: 'Edit profile'.tr,
  onTap: () => Get.toNamed(AppRoutes.DashboardScreen),
),
const CustomDivider(),
```

`_row` takes `icon`, `title`, optional `value` (grey text on the right), optional `trailing` (a widget, e.g. a `Switch`), optional `onTap`, optional `tint`. Without `trailing`, a chevron appears whenever `onTap` is set.

## Notes and gotchas

- **Theme changes are global and immediate.** `ThemeController.changeTheme` calls `Get.changeThemeMode` and then `Get.forceAppUpdate()` on the next frame, so the picker closes (`Get.back()`) *before* the change is applied — otherwise the sheet is rebuilt mid-dismiss.
- **The language picker matches on `languageCode` only.** `AppTranslations._parse` does the same, so `en_US` and `en_GB` are one entry. Fine until you ship two dialects of one language.
- **Logout keeps the look-and-feel.** `CacheManager.removeAll()` clears `themeId` and `locale` along with the tokens, which resets the app to English + system theme — a classic complaint. `logout()` reads both back before the wipe and re-writes them after. Set `keepPreferencesOnLogout = false` for a true factory reset.
- **The notification flag is wiped by logout**, because it lives in the same SharedPreferences box that `removeAll()` clears. It returns to its default (on). That is intentional: a signed-out device should not stay unsubscribed silently.
- **Clear cache is in-memory only.** It empties Flutter's `ImageCache` (`clear()` + `clearLiveImages()`), which needs no package. The disk cache behind `cached_network_image` is not touched — wire `onClearCache` to `DefaultCacheManager().emptyCache()` and add `flutter_cache_manager` to `pubspec.yaml` if you want that too.
- **The toggle does not subscribe anything by itself.** It persists a preference. `onNotificationsChanged` is where a push SDK goes; without it the flag is inert.
- **Version string is `"version (buildNumber)"`.** If `package_info_plus` throws (rare, but possible on a misconfigured desktop target) the row shows `—` instead of blanking the screen.
- **Links open externally** with `LaunchMode.externalApplication`. Install **webview** and route `openLink` through `CustomWebView.open` to keep users in the app.

## Why it is not in core

A settings screen is the most opinionated screen in any app — every project renames its sections, reorders its rows and adds its own — so the template ships the controllers it drives and leaves the screen to you.
