# Modules — optional features, kept out of `lib/`

`lib/` is the lean starter template. Anything stripped out of it was **not deleted** — it was
repackaged here as a self-contained, drop-in module.

Nothing in `modules/` compiles, is analysed, or needs its packages installed. It sits on disk until
you ask for it. When a project needs a feature, you re-add it with one command.

```bash
dart run tool/add_module.dart                    # list what's available
dart run tool/add_module.dart <name> --dry-run   # see the plan, write nothing
dart run tool/add_module.dart <name>             # install it
flutter pub get
```

The installer copies the module's files into `lib/` at their proper paths, appends any missing
packages to `pubspec.yaml` (existing ones are skipped), and prints the platform setup you must do by
hand. It refuses to overwrite an existing file unless you pass `--force`.

---

## Index

**21 modules.** Two columns tell you how much work an install is:

- **Platform?** — native config needed (manifest, plist, Gradle, API keys, console setup).
- **Core wiring?** — you must hand-edit a file in `lib/` (`bootstrap.dart`, `app.dart`,
  `view_model_binding.dart`, `app_routes.dart` / `app_pages.dart`, `api_service.dart`).
  Every module documents the exact lines under **Wiring** in its own README.

### Auth & Security

| Module | What it does | Packages it adds | Platform? | Core wiring? |
|---|---|---|---|---|
| **social_auth** | Google + Apple sign-in for the existing auth feature: a `GetxService` that collects the provider token, a Repo/Impl/ApiService trio that POSTs it to **your** backend, and ready-made buttons. The client result alone is never a login. | `google_sign_in`, `sign_in_with_apple` | Yes — OAuth client IDs, URL scheme, Apple capability | Yes — binding, both auth controllers, both auth screens |
| **secure_storage** | `SecureStore` — access + refresh token in the Android KeyStore / iOS Keychain instead of plaintext `SharedPreferences`, with a one-time migration of an existing plaintext token on next launch. | `flutter_secure_storage` | Yes — Keychain sharing / `minSdk` | Yes — 6 files (`bootstrap`, `api_service`, `user_di`, 3 controllers) |
| **biometric_lock** | Face ID / Touch ID / fingerprint app lock: `BiometricService` over `local_auth` mapping every platform error to a clear message, plus an `app_lock` feature that locks on cold start and after a background timeout. Opt-in, off by default. | `local_auth` | Yes — `FlutterFragmentActivity`, AppCompat theme, `USE_BIOMETRIC` | Yes — `app.dart` builder, bootstrap, binding, route |
| **app_attestation** | Play Integrity (Android) / App Attest (iOS) tokens attached by a Dio interceptor to opted-in sensitive endpoints only, for **your backend** to verify. Plus `CertPinning`, which replaces the `badCertificateCallback` TLS bypass with SPKI pinning that fails closed. | `crypto` | Yes — **hand-written native plugin**, Play Console, Xcode capability | Yes — bootstrap + `api_service.dart` |
| **abuse_guard** | Client-side politeness guards: persisted cooldowns, debounce/throttle, single-flight double-submit guard, escalating failed-login lockout — plus a provider-agnostic CAPTCHA hook with a WebView-backed Cloudflare Turnstile implementation. | `webview_flutter` | Yes — INTERNET, `compileSdk` 34+ | Yes — register `CaptchaService`, optional `GuardCache.init()` |

### Realtime & Comms

| Module | What it does | Packages it adds | Platform? | Core wiring? |
|---|---|---|---|---|
| **realtime_socket** | Socket.IO client as a `GetxService`: auth-aware connect/disconnect, reconnect with exponential backoff, reactive `SocketStatus`, and a typed `on<T>`/`emit` registry whose handlers survive reconnects. Ships an example controller + screen. | `socket_io_client` | No | Yes — bootstrap, binding, route |
| **push_notifications** | FCM + `flutter_local_notifications`: permission request (iOS + Android 13 `POST_NOTIFICATIONS`), token POSTed to **your** backend, foreground messages on a high-importance channel, taps routed onto `AppRoutes` from both cold and warm starts. | `firebase_core`, `firebase_messaging`, `flutter_local_notifications` | Yes — `google-services.json` / `GoogleService-Info.plist`, APNs key | Yes — bootstrap (`Firebase.initializeApp` + `Get.putAsync`) |
| **deep_links** | Deep links, App Links and iOS Universal Links routed onto the existing `AppRoutes` table: a declarative pattern map (`'/product/:id'`), path + query params as `Get.arguments`, an auth guard that bounces through sign-in and resumes, fall-through to `unknownRoute`. Ships 7 tests. | `app_links` | Yes — intent-filters, `assetlinks.json` / AASA | Yes — bootstrap + splash |

### Commerce

| Module | What it does | Packages it adds | Platform? | Core wiring? |
|---|---|---|---|---|
| **payment_stripe** | Stripe PaymentSheet checkout: checkout screen, result screen, sealed `PaymentResult`, Repo/Impl/ApiService trio. The app holds only the **publishable** key — your backend creates the PaymentIntent and the webhook confirms it. | `flutter_stripe` | Yes — `FlutterFragmentActivity`, AppCompat theme, iOS 13 | Yes — bootstrap, binding, routes |

### App Lifecycle

| Module | What it does | Packages it adds | Platform? | Core wiring? |
|---|---|---|---|---|
| **app_update_gate** | Force / soft update gate. Asks **your** backend for the version contract, compares it to the running build with real semver comparison, then either blocks with a non-dismissible screen or offers a snoozable sheet. Store launch via `url_launcher`. | `package_info_plus`, `url_launcher` | Yes — `url_launcher` `<queries>` | Yes — binding + splash |
| **connectivity_banner** | Offline awareness: a `ConnectivityService` with a reactive `isOnline`, an animated offline banner that drops into `GetMaterialApp.builder`, and a `ConnectivityGuard` that short-circuits actions while offline. | `connectivity_plus` *(already in core — installer adds nothing)* | Yes — INTERNET for release builds | Yes — bootstrap + `app.dart` builder |
| **crash_analytics** | Crash reporting behind a provider-agnostic `GetxService`. One Sentry implementation, a PII scrubber that strips tokens/emails/phone numbers before send, slotted into the `FlutterError` / `runZonedGuarded` hooks `bootstrap.dart` already has. Release-only by default. | `sentry_flutter` (+ optional dev dep `sentry_dart_plugin`) | Yes — DSN, INTERNET; note the Kotlin Gradle Plugin warning | Yes — bootstrap |
| **api_resilience** | Dio interceptor that makes the app a well-behaved API client: in-flight GET coalescing, `Retry-After`-aware 429 handling with a live countdown, full-jitter exponential backoff (idempotent requests only), per-host circuit breaker. Ships 32 tests. | none | No | Yes — one edit to `api_service.dart` |

### UI & Content

| Module | What it does | Packages it adds | Platform? | Core wiring? |
|---|---|---|---|---|
| **settings_ui** | The settings screen the template is missing: theme switcher driving the existing `ThemeController`, language switcher driving `AppTranslations.setLocale`, notification toggle, app version, privacy/terms links, clear cache, logout. Built from the shared widget kit. | `package_info_plus`, `url_launcher` | Yes — `url_launcher` `<queries>` | Yes — binding + route |
| **location_picker** | Google Places autocomplete + a Google Map whose centre pin is the selected point, plus GPS/permission/IP location services. | `geolocator`, `permission_handler`, `google_maps_flutter`, `google_places_flutter`, `geocoding` | Yes — Maps API key, location permissions | Yes — register `LocationService` |
| **media_viewer** | Fullscreen image/video gallery + inline thumbnail. Pinch/double-tap zoom, custom video player with double-tap seek and a scrubbable progress bar. Network, file and asset sources. | `cached_network_image`, `video_player` | Yes — INTERNET, cleartext/ATS for http | No |
| **webview** | `CustomWebView` in-app browser: progress bar, title/host app bar, nav bottom bar, share, open externally, copy link, tel/mailto/sms handoff. | `flutter_inappwebview`, `share_plus`, `url_launcher` | Yes — INTERNET, `url_launcher` queries/schemes | No |
| **rich_text_editor** | `CustomQuilTextField` — themed WYSIWYG form field with optional heading, configurable toolbar, bordered editor box. | `flutter_quill` | No | No |
| **html_view** | `AppHtmlView` — renders HTML strings as widgets: theme-aware colors, tappable tel/mailto/sms/web links, WhatsApp-style markdown, auto-linkify, Scripture/USFM styling, HTML→text utils. | `flutter_html`, `html_unescape`, `google_fonts`, `url_launcher` | Yes — `url_launcher` queries/schemes | No |

### Reference — copy the pattern, don't ship it as-is

| Module | What it does | Packages it adds | Platform? | Core wiring? |
|---|---|---|---|---|
| **multi_step_onboarding** | Rider + merchant registration wizards: PageView step machine, per-step validation, multipart upload, cascading location dropdowns, Repo/Impl API split. Copy the structure, replace the fields. | `image_picker`, `file_picker`, `pinput`, `intl`, `permission_handler`, `lucide_icons_flutter`, `flutter_svg`, `shared_preferences` | Yes — camera/photo permissions, API endpoints | Yes — routes + bindings |
| **extra_widgets** | Six alternate UI widgets: overlay single/multi-select dropdowns, dependency-free paginated grid, loading overlay, list-state indicator, empty-state view. | none | No | No |

Every module has its own `README.md` with the full API, usage examples and the verbatim manifest /
plist snippets. Read it after installing.

### Notes on combinations

- **`GetMaterialApp` has one `builder` slot.** `connectivity_banner` and `biometric_lock` both want
  it. Installing both, then pasting both README lines, silently loses one feature. Compose them in
  `lib/app/app.dart` instead:
  ```dart
  builder: (context, child) => AppLockGate(child: OfflineBanner.builder()(context, child)),
  ```
- **`Firebase.initializeApp()` must appear exactly once** in `bootstrap.dart`. Both
  `push_notifications` and any other Firebase-backed module would add it.
- `secure_storage` + `social_auth` touch the **same** `Future.wait` block in `signin_controller.dart`.
  Apply `secure_storage`'s token swap to `social_auth`'s `_completeSocialSignIn` body too, or the
  social login path keeps writing the token in plaintext.
- Anything on the **first-frame path** must read `SecureStore`'s sync mirrors (`SecureStore.tokenSync`),
  never `await SecureStore.token`. A `MethodChannel` read inside `testWidgets` never completes and
  hangs `app_boot_test.dart`. See that module's README.
- `multi_step_onboarding` needs `CustomDropdownButton`, which ships inside **extra_widgets** —
  install that first. Its map step needs **location_picker** (optional).
- `html_view` opens web links in the external browser by default. Install **webview** and set
  `AppHtmlView.webViewOpener = CustomWebView.open` at startup to open them in-app instead.
- `app_attestation` + `api_resilience` + `abuse_guard` are complementary, not overlapping:
  attestation only sets request headers, resilience only handles retries and errors, abuse_guard only
  gates the UI. Install in any order.
- `app_update_gate`, `settings_ui` and `html_view`/`webview` all want a `url_launcher` `<queries>`
  block. The template **already ships one** (for `PROCESS_TEXT`) — add the `<intent>` entries to the
  existing block rather than pasting a second one.
- `payment_stripe` is useless on its own: it needs two endpoints on **your** backend, which is where
  the Stripe secret key lives. Never put an `sk_...` key in the app.
- `payment_stripe` and `biometric_lock` both require `FlutterFragmentActivity` + an AppCompat theme.
  Doing it once satisfies both.
- Modules assume the template's core files exist (`app_colors.dart`, `app_fonts.dart`,
  `responsive_utils.dart`, …). The installer prints the exact list per module; if you're dropping a
  module into a different project, copy those first.
- Anything client-side (`abuse_guard`, `app_attestation`, `api_resilience`) is a **signal, not an
  enforcement**. Rate limiting, lockout and token verification happen on the server. A patched app
  skips all of it.

---

## How to add your OWN module

Whenever you strip something out of `lib/` again, park it here instead of deleting it. The installer
picks up any new folder automatically — no code changes needed.

### Layout

```
modules/<your_module>/
├── lib/            the Dart files, as they should end up in the project
├── module.yaml     the manifest the installer reads
└── README.md       how to use it, with the platform snippets
```

### `module.yaml`

```yaml
name: your_module
description: >-
  One or two sentences. This is what `add_module.dart` prints in the list.

# Two ways to declare files — pick one.

# A) Mirror layout: the path under modules/<name>/ IS the path in lib/.
files:
  - lib/app/widgets/your_widget.dart
  - lib/app/services/your_service.dart

# B) Flat layout: keep files at modules/<name>/lib/*.dart and say where they land.
install_dir: lib/app/widgets
files:
  - lib/your_widget.dart

# C) Per-file, when a name changes on the way in.
files:
  - source: lib/your_widget.dart
    target: lib/app/widgets/renamed_widget.dart

# Appended to pubspec.yaml. Already-present packages are skipped.
dependencies:
  some_package: ^1.0.0

# Printed, never installed. For "only if you use feature X".
optional_dependencies:
  another_package: ^2.0.0

# Template files this module imports. Printed as a checklist.
core_dependencies:
  - lib/app/utils/constants/app_colors.dart

# Printed under MANUAL STEPS. String or nested android:/ios:/notes: map.
platform_config: >-
  None required.
```

Optional keys, all printed under **MANUAL STEPS** when present:

| Key | Use it for |
|---|---|
| `kind: reference` | Marks the module as pattern-only domain code; prints a warning on install. |
| `env` | `.env` keys the module reads. |
| `setup` | Startup wiring, e.g. `Get.put(...)` calls. |
| `routes` / `bindings` | What to register in `AppRoutes` / `AppPages` / `ViewModelBinding`. |
| `requires` / `requires_core` | Same as `core_dependencies` (any of the three works). |
| `requires_modules` | Other modules that must be installed first. |
| `optional_integration` | Nice-to-have hookups with other modules. |
| `notes` | Anything else — API changes made during repackaging, gotchas. |

### Rules that keep this working

1. **Modules never live in `lib/`.** That's the whole point — they stay uncompiled and their heavy
   packages stay out of `pubspec.yaml` until someone asks.
2. **No relative imports that escape the module.** Use `package:flutter_starter/...` so the file
   resolves wherever it lands.
3. **Installing a module must not require editing a core file to compile.** New endpoints go in the
   module's own `*_api_const.dart`, new cache keys in its own store. Where core wiring genuinely *is*
   needed, document the exact pastable lines under a **Wiring** heading in the README — never depend
   on a core edit silently.
4. **Name the real file.** `main()` is a one-liner here; startup wiring goes in `lib/bootstrap.dart`.
5. **Write the README with copy-pasteable snippets** — manifest blocks, plist keys, a usage example.
   Future-you will not remember the setup.
6. **Verify before committing:**
   ```bash
   dart run tool/add_module.dart                     # your module appears in the list
   dart run tool/add_module.dart <your_module> --dry-run
   ```
   Better: install it into a throwaway copy of the repo, apply your own Wiring steps verbatim, and
   run `flutter analyze` + `flutter test`. `modules/` is excluded from `analysis_options.yaml`, so
   nothing here is checked until someone installs it.

The parser in `tool/add_module.dart` is a small YAML subset (nested maps, `-` lists, `|` and `>`
block scalars, inline `{}`). Keep the manifest plain and it will parse.
