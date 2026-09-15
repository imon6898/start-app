# abuse_guard

Client-side guards that stop **your own app** generating abusive traffic, plus a CAPTCHA hook.

Read this first, because it frames everything below:

> **Rate limiting and abuse prevention are server responsibilities.** A mobile client cannot enforce
> them — an attacker patches the app, or skips it entirely and calls your API with `curl`. This module
> does three honest things and nothing more:
>
> 1. **Be well behaved** — a persisted cooldown, a debouncer, a throttler and a single-flight guard so
>    normal use never trips a server limit.
> 2. **Degrade gracefully** — a failed-login lockout that gives the user a clear message and a
>    countdown instead of hammering `/login` five times a second.
> 3. **Supply a signal** — a CAPTCHA token your **backend** verifies, so the server can tell a real app
>    from a script.
>
> Nothing here protects the API. See [What this does NOT protect against](#what-this-does-not-protect-against).

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/core/helpers/action_throttle.dart` | `GuardCache`, `ActionCooldown`, `Debouncer`, `Throttler`, `SingleFlight`. |
| `lib/app/core/helpers/attempt_limiter.dart` | `AttemptLimiter` + `AttemptGate` — escalating, persisted failed-attempt lockout. |
| `lib/app/services/captcha_service.dart` | `CaptchaService` (abstract `GetxService`), `CaptchaToken`, `NoCaptchaService`, `TurnstileCaptchaService`. |
| `lib/app/widgets/feedback/captcha_challenge_sheet.dart` | `showCaptchaChallenge()` — the WebView-backed Turnstile challenge bottom sheet. |

`ActionCooldown` is the timer already living in
`auth_controllers/verify_otp_controller.dart` (`countdownTime` / `canResend`), generalised and
**persisted**. That matters: an in-memory cooldown is cleared by force-quitting the app, so it is a
fake cooldown. This one survives a restart.

## Install

```bash
dart run tool/add_module.dart abuse_guard
flutter pub get
```

Manual equivalent — copy each path in `module.yaml > files` to the same path in the project:

```bash
cp modules/abuse_guard/lib/app/core/helpers/action_throttle.dart          lib/app/core/helpers/
cp modules/abuse_guard/lib/app/core/helpers/attempt_limiter.dart          lib/app/core/helpers/
cp modules/abuse_guard/lib/app/services/captcha_service.dart             lib/app/services/
cp modules/abuse_guard/lib/app/widgets/feedback/captcha_challenge_sheet.dart lib/app/widgets/feedback/
```

Only the last two files need `webview_flutter`. If you want the cooldown/lockout helpers and no
CAPTCHA, copy the first two and skip the dependency entirely.

### 1. pubspec.yaml

```yaml
dependencies:
  webview_flutter: ^4.9.0
```

`get`, `shared_preferences` and `flutter_dotenv` are already in the template core.

### 2. .env

```env
TURNSTILE_SITE_KEY=0x4AAAAAAA_your_site_key
# Optional:
TURNSTILE_HOST=https://localhost
TURNSTILE_CHALLENGE_URL=
```

Read through the core `Env.optional(...)` escape hatch — **no edit to `env.dart` is needed**. With
`TURNSTILE_SITE_KEY` unset, `TurnstileCaptchaService.isConfigured` is `false` and `getToken()` returns
`null` without showing anything, so the app still builds and runs.

### 3. Platform config

**Android** — `android/app/src/main/AndroidManifest.xml` (usually already present):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

`minSdk` 21+ and `compileSdk` 34+ for `webview_flutter_android`. The Flutter defaults already satisfy both.

**iOS** — nothing. No `Info.plist` key, no `AppDelegate` change; WKWebView needs no ATS exception for an
`https` challenge page. `webview_flutter_wkwebview` 3.26.1 (what `^4.9.0` resolves to today) needs deployment target 13.0; the template is already there, so nothing to change. Then `cd ios && pod install`.

Pre-existing and unrelated to this module: `flutter build ios` fails on the untouched template because `file_picker_darwin` (a core dependency) requires iOS 14 while the project is pinned to 13.0. Raise `platform :ios, '14.0'` in `ios/Podfile` and the three `IPHONEOS_DEPLOYMENT_TARGET` entries in `ios/Runner.xcodeproj/project.pbxproj` before you expect an iOS build to succeed.

The two helper files need no platform config at all.

## Wiring

Exact pastable lines. Everything else is constructed inside the controller that uses it.

**`lib/bootstrap.dart`** — optional but recommended, so a restored cooldown is readable on the first frame.
(`main()` is a one-liner that just calls `bootstrap()`; all startup work lives in `bootstrap.dart`.)

Add the import next to the existing relative imports:

```dart
import 'app/core/helpers/action_throttle.dart';
```

Then, immediately after `await CacheManager.init();` inside the `try` block:

```dart
    await GuardCache.init();
```

Skip it if you prefer: every write calls `GuardCache.init()` itself, and `ActionCooldown.restore()` /
`AttemptLimiter.check()` are `async` and await it.

**`lib/app/bindings/view_model_binding.dart`** (or `bootstrap.dart`) — register the CAPTCHA provider once,
inside `dependencies()`:

```dart
import 'package:flutter_starter/app/services/captcha_service.dart';

// Abuse guard
Get.put<CaptchaService>(TurnstileCaptchaService(), permanent: true);
```

Use `NoCaptchaService()` instead while the backend does not verify tokens yet — the call sites do not change.

**Logout** — `CacheManager.removeAll()` calls `SharedPreferences.clear()`, which already wipes the
`guard.` keys. To clear guard state *without* logging out:

```dart
await GuardCache.clearAll();
```

## Usage

### ActionCooldown — the OTP resend timer, generalised and persisted

```dart
class SentOtpController extends GetxController {
  final resendCooldown = ActionCooldown(
    name: 'otp_resend',
    duration: const Duration(seconds: 60),
  );

  @override
  void onInit() {
    super.onInit();
    resendCooldown.restore();   // picks the timer back up after a restart
  }

  @override
  void onClose() {
    resendCooldown.dispose();
    super.onClose();
  }

  Future<void> resendOtp() async {
    final sent = await resendCooldown.run(() async {
      await _authRepo.rePostSentOtpRepo({'email': email});
    });

    if (!sent) {
      showCustomSnackBar(
        context: Get.context!,
        title: 'Please wait'.tr,
        description: '${'You can request a new code in'.tr} ${resendCooldown.formattedTime}',
        type: SnackBarType.Warning,
      );
    }
  }
}
```

In the screen — `canRun` is the old `canResend`, `countdownTime` is the old `countdownTime`:

```dart
Obx(() => TextButton(
      onPressed: controller.resendCooldown.canRun.value ? controller.resendOtp : null,
      child: Text(
        controller.resendCooldown.canRun.value
            ? 'Resend code'.tr
            : '${'Resend in'.tr} ${controller.resendCooldown.formattedTime}',
        style: CustomTextStyles.medium14,
      ),
    ))
```

### Debouncer and Throttler

```dart
final _search = Debouncer(delay: const Duration(milliseconds: 400));
final _tap = Throttler(interval: const Duration(milliseconds: 800));

void onQueryChanged(String query) => _search(() => fetchResults(query));

void onRefreshTapped() {
  final ran = _tap(() => loadDashboard());
  if (!ran) devPrint('refresh tap swallowed');
}

@override
void onClose() {
  _search.dispose();
  _tap.dispose();
  super.onClose();
}
```

### SingleFlight — double-submit guard

```dart
final _submit = SingleFlight();

Future<void> save() async {
  final result = await _submit.run(() => _repo.createTicket(params));
  if (result == null) return;   // a save was already running; this tap is dropped
  // ...
}
```

Bind the button to it: `Obx(() => CustomButton(loading: _submit.inFlight.value, ...))`.

### AttemptLimiter — failed-login lockout

Defaults: 5 attempts, then 1 min → 5 min → 15 min, and the counter is forgotten after 24 h of quiet.

```dart
final loginLimiter = AttemptLimiter(
  name: 'signin',
  maxAttempts: 5,
  steps: const [Duration(minutes: 1), Duration(minutes: 5), Duration(minutes: 15)],
);

final gate = await loginLimiter.check(email);
if (!gate.allowed) {
  // gate.remaining, gate.formattedTime, gate.attemptsLeft
}
await loginLimiter.recordFailure(email);   // returns the new gate
await loginLimiter.recordSuccess(email);   // clears the counter and the lock
```

`loginLimiter.isLocked` / `loginLimiter.lockRemaining` / `loginLimiter.formattedTime` are reactive and
tick once a second against the wall clock, so a countdown stays correct across backgrounding.

### CAPTCHA

```dart
final token = await CaptchaService.to.getToken(action: 'signup');
final params = {
  'email': emailController.text,
  'password': passwordController.text,
  ...?token?.toParams(),        // {captcha_token, captcha_provider, captcha_action}
};
```

`token` is `null` when the user cancelled, the challenge errored or timed out, or no site key is
configured. **Decide deliberately** whether that blocks the request or is sent without a token — the
backend is the thing that actually enforces it.

## Worked example — signin controller with AttemptLimiter + SingleFlight

The module cannot edit core files, so this is a diff to apply by hand to
`lib/app/feature/auth/auth_controllers/signin_controller.dart`. Only the guard-related lines are shown.

```dart
import 'package:flutter_starter/app/core/helpers/action_throttle.dart';
import 'package:flutter_starter/app/core/helpers/attempt_limiter.dart';
import 'package:flutter_starter/app/services/captcha_service.dart';

class SigninController extends GetxController {
  // ... existing fields ...

  final _signInFlight = SingleFlight();
  final loginLimiter = AttemptLimiter(name: 'signin');

  @override
  void onInit() {
    super.onInit();
    _loadSavedCredentials();
    loginLimiter.check(emailController.text);   // resume a lock left from last session
  }

  @override
  void onClose() {
    loginLimiter.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<void> signIn() async {
    if (!signInFormKey.currentState!.validate()) return;
    FocusScope.of(Get.context!).unfocus();

    final identifier = emailController.text.trim();

    // 1. Local lockout — a courtesy to the server, not a security control.
    final gate = await loginLimiter.check(identifier);
    if (!gate.allowed) {
      showCustomSnackBar(
        context: Get.context!,
        title: 'Too many attempts'.tr,
        description: '${'Try again in'.tr} ${gate.formattedTime}',
        type: SnackBarType.Failure,
      );
      return;
    }

    // 2. Single-flight — a second tap while the first request is open is dropped.
    await _signInFlight.run(() async {
      isLoadingSignIn.value = true;
      try {
        // 3. Optional signal for the backend to verify.
        final captcha = await CaptchaService.to.getToken(action: 'login');

        final response = await _authRepo.postLoginRepo({
          'identifier': identifier,
          'password': passwordController.text,
          ...?captcha?.toParams(),
        });

        final baseResponse = BaseResponse<LoginData>.fromJson(
          response!,
          (data) => LoginData.fromJson(data),
        );

        if (baseResponse.statusCode == 201) {
          await loginLimiter.recordSuccess(identifier);
          // ... existing success path ...
        } else {
          final next = await loginLimiter.recordFailure(identifier);
          showCustomSnackBar(
            context: Get.context!,
            title: 'Authentication failed'.tr,
            description: next.allowed
                ? '${'Attempts left'.tr}: ${next.attemptsLeft}'
                : '${'Too many attempts. Try again in'.tr} ${next.formattedTime}',
            type: SnackBarType.Failure,
          );
        }
      } finally {
        isLoadingSignIn.value = false;
      }
    });
  }
}
```

Bind the button to the same flag so the UI cannot fire a second request:

```dart
Obx(() => CustomButton(
      text: 'Sign in'.tr,
      loading: controller._signInFlight.inFlight.value,
      onPressed: controller.signIn,
    ))
```

(Make the field public, or expose `RxBool get isSubmitting => _signInFlight.inFlight;`.)

## Why Turnstile, and how to swap it

**Chosen: Cloudflare Turnstile.** It is free at any volume, needs no Google account, is usually
invisible (no image grids), and verification is a single server-side `POST` to
`https://challenges.cloudflare.com/turnstile/v0/siteverify`. reCAPTCHA v3 returns a score rather than a
pass/fail, which means tuning a threshold on the backend before it is useful — more work for the same
client-side plumbing.

**It is a WebView, honestly.** There is no well-maintained first-party Flutter plugin for Turnstile, and
none for reCAPTCHA v3 either (Google ships native Android/iOS SDKs, not a Flutter one). Rather than name
a package that may be abandoned, `captcha_challenge_sheet.dart` renders Cloudflare's own
`api.js` in a `webview_flutter` WebView and posts the token back over a JavaScript channel. The
`webview_flutter` API used here (`WebViewController`, `loadHtmlString`, `addJavaScriptChannel`,
`NavigationDelegate`, `WebViewWidget`) was verified against `webview_flutter` 4.x in the local pub
cache; the **Turnstile JS** (`render=explicit`, `appearance: 'interaction-only'`, the
`before-interactive-callback` / `error-callback` / `expired-callback` hooks) is written from Cloudflare's
documented API and was **not** verified against a live challenge — check it against their current docs
before shipping.

**To swap provider:** write a new `class XCaptchaService extends CaptchaService`, implement `provider`,
`isConfigured` and `getToken(action:)`, and change the one `Get.put<CaptchaService>(...)` line. No call
site changes, because callers only ever see `CaptchaService.to`.

**If the challenge never renders on a device:** the inline HTML is loaded with a synthesised origin
(`TURNSTILE_HOST`, default `https://localhost`), which must be in the widget's allowed-hostnames list.
The robust alternative is to host a two-line challenge page on your own domain and set
`TURNSTILE_CHALLENGE_URL` — the sheet then loads that URL instead and everything else is unchanged.

## What this does NOT protect against

Be blunt with yourself about this list.

- **Anything that is not your app.** `curl`, Postman, a Python script or a repackaged APK never runs
  this code. Every guard here is advisory.
- **A rooted/jailbroken device or a patched build.** Cooldowns live in SharedPreferences; clearing app
  data, reinstalling, or editing the prefs file resets them instantly.
- **Device-clock changes.** Expiry is stored as a wall-clock timestamp. Setting the clock forward clears
  a cooldown or a lockout. There is no trustworthy monotonic clock across process restarts on mobile;
  a server-issued `Retry-After` is the only honest source of truth.
- **Logout.** `CacheManager.removeAll()` clears all of SharedPreferences, including `guard.` keys, so
  signing out resets the lockout. That is deliberate — a client-side lockout that outlived logout would
  only punish honest users.
- **Credential stuffing across accounts.** `AttemptLimiter` is keyed per identifier on one device. An
  attacker spreading one password across 10 000 accounts trips it zero times. Per-IP and per-account
  limits belong on the server.
- **A CAPTCHA token on its own.** The client only fetches a token. If the backend does not call
  `siteverify`, the token is decorative and an attacker simply omits the field.
- **Server-side rate limiting.** This module does not handle `429`/`503`, `Retry-After`, backoff, jitter
  or request dedup — the core `ApiService` treats only 200/201 as success and has no 429 path. That work
  belongs in the API layer, not here.
- **Scraping, enumeration and spam.** Nothing client-side slows down account enumeration or content
  scraping.

What it *does* buy you: users stop double-charging themselves with a double tap, search boxes stop
firing a request per keystroke, a fat-fingered password stops producing eight login calls in four
seconds, and your server gets a signal it can actually verify.

## Why it is not in core

Every project wants the guards; every project wants different numbers, and most of the value only
appears once the backend enforces the matching rules. The CAPTCHA half also pulls `webview_flutter` plus
a Cloudflare account, which a template must not impose. Shipping it opt-in keeps core free of a native
plugin and keeps the cooldown constants in the app that owns them rather than baked into the template.
