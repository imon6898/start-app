# social_auth

Google + Apple sign-in for the auth feature that already ships in `lib/`. A `GetxService` collects the provider token, a Repo/Impl/ApiService trio posts it to **your** backend, and two buttons drop into the sign-in / sign-up screens.

The client result is never a login. `SocialAuthService` hands you an `id_token` / `authorizationCode` and nothing else — your backend verifies it with Google or Apple and decides whether a session exists.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/social_auth_service.dart` | `SocialAuthService` (`GetxService`) — wraps `google_sign_in` and `sign_in_with_apple`. Returns `SocialAuthResult` (success / cancelled / failed) with `toParams()` ready for the API. |
| `lib/app/feature/auth/auth_logic/social_auth_api_service.dart` | `SocialAuthApiService` / `SocialAuthImpl` / `SocialAuthRepo` — Style-A trio, method names `postGoogleSignIn` / `postAppleSignIn`, repo methods `postGoogleSignInRepo` / `postAppleSignInRepo` (the names the original `auth_api_service.dart` used). |
| `lib/app/feature/auth/auth_logic/social_auth_api_const.dart` | `SocialAuthApiConst` — the two endpoint paths, kept out of core `api_const.dart` so installing needs no core edit. |
| `lib/app/widgets/buttons/social_auth_buttons.dart` | `GoogleSignInButton`, `AppleSignInButton`, `SocialAuthButtons` (both stacked, Apple auto-hidden off Apple platforms). |

## Install

```bash
dart run tool/add_module.dart social_auth
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
cp modules/social_auth/lib/app/feature/auth/auth_logic/social_auth_api_const.dart   lib/app/feature/auth/auth_logic/
cp modules/social_auth/lib/app/feature/auth/auth_logic/social_auth_api_service.dart lib/app/feature/auth/auth_logic/
cp modules/social_auth/lib/app/services/social_auth_service.dart                    lib/app/services/
cp modules/social_auth/lib/app/widgets/buttons/social_auth_buttons.dart             lib/app/widgets/buttons/
```

Then add the dependencies, do the platform config, and `flutter pub get`.

### 1. pubspec.yaml

```yaml
dependencies:
  google_sign_in: ^6.3.0
  sign_in_with_apple: ^8.1.0
```

`get`, `dio`, `lucide_icons_flutter` and `flutter_dotenv` are already in the template core.

> `google_sign_in` **7.x is a breaking redesign** (`GoogleSignIn.instance`, `initialize()`, `authenticate()`). `social_auth_service.dart` is written against the 6.x API and will not compile on 7.x. Keep the `^6.3.0` constraint or port the service.

### 2. .env

```env
GOOGLE_SERVER_CLIENT_ID=1234567890-xxxxxxxx.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=1234567890-yyyyyyyy.apps.googleusercontent.com
APPLE_SERVICE_ID=com.easital.starter.service
APPLE_REDIRECT_URI=https://api.example.com/acc/auth/apple/callback
```

| Key | Needed for | Notes |
| --- | --- | --- |
| `GOOGLE_SERVER_CLIENT_ID` | Google, all platforms | The **web** OAuth client ID. It is the `aud` of the `id_token` your backend verifies. **Without it Android returns no `id_token` at all.** |
| `GOOGLE_IOS_CLIENT_ID` | Google on iOS/macOS | Optional if you set `GIDClientID` in `Info.plist` instead. Ignored on Android. |
| `APPLE_SERVICE_ID` | Apple on Android/web | The Services ID from the Apple Developer portal. Not used on iOS. |
| `APPLE_REDIRECT_URI` | Apple on Android/web | Your backend callback URL, registered as a Return URL on the Services ID. Not used on iOS. |

All four are read with `Env.optional(...)` — do **not** add them to `Env.requiredKeys`, or projects without social login refuse to boot.

### 3. Android — Google

1. Google Cloud Console → Credentials: create an **Android** OAuth client for package `com.easital.starter` with the SHA-1 of your debug *and* release signing keys, plus a **Web** OAuth client.
   ```bash
   cd android && ./gradlew signingReport   # debug SHA-1
   ```
2. Put the **web** client ID in `.env` as `GOOGLE_SERVER_CLIENT_ID`.

Android identifies the app by package name + signing SHA-1, so `clientId` is ignored there (the service only passes it on Apple platforms). No manifest change is needed for Google.

### 4. Android — Apple

`MainActivity` must use `launchMode` `singleTop` or `singleTask` — the template already sets `singleTop`, nothing to do.

Add inside `<application>` in `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Sign in with Apple: callable from the browser redirect -->
<activity
    android:name="com.aboutyou.dart_packages.sign_in_with_apple.SignInWithAppleCallback"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="signinwithapple" />
        <data android:path="callback" />
    </intent-filter>
</activity>
```

Your `APPLE_REDIRECT_URI` endpoint must 302 back into the app:

```
intent://callback?<urlencoded callback body>#Intent;package=com.easital.starter;scheme=signinwithapple;end
```

### 5. iOS — `ios/Runner/Info.plist`

```xml
<key>GIDClientID</key>
<string>YOUR_IOS_CLIENT_ID</string>
<key>GIDServerClientID</key>
<string>YOUR_WEB_CLIENT_ID</string>

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- REVERSED_CLIENT_ID from GoogleService-Info.plist -->
            <string>com.googleusercontent.apps.1234567890-yyyyyyyy</string>
        </array>
    </dict>
</array>
```

The URL scheme is required even when you pass the client IDs from Dart.

### 6. iOS — Sign in with Apple capability

1. Sign in with Apple needs a **paid** Apple Developer Program membership.
2. Xcode → `Runner` → Signing & Capabilities → `+ Capability` → **Sign in with Apple**.
3. The App ID at developer.apple.com must have the same capability; refresh provisioning profiles if signing is not automatic.

Without the capability the sheet fails with no visible error. iOS 13 is the minimum; below that `SignInWithApple.isAvailable()` returns false and `SocialAuthButtons` hides the button.

## Wiring

Four core edits, all copy-paste. Nothing else in `lib/` needs to change.

### a. Register the service — `lib/app/bindings/view_model_binding.dart`

Import:

```dart
import '../services/social_auth_service.dart';
```

Inside `dependencies()`, above the `// Auth` block:

```dart
    // Social sign-in providers (social_auth module).
    if (!Get.isRegistered<SocialAuthService>()) {
      Get.put(SocialAuthService(), permanent: true);
    }
```

(Equivalent alternative: `Get.put(SocialAuthService(), permanent: true);` in `lib/bootstrap.dart` after `await CacheManager.init();` — that file does not import `get` yet, so add `import 'package:get/get.dart';` there too.)

### b. Controller — `lib/app/feature/auth/auth_controllers/signin_controller.dart`

Add the imports:

```dart
import 'package:flutter_starter/app/feature/auth/auth_logic/social_auth_api_service.dart';
import 'package:flutter_starter/app/services/social_auth_service.dart';
```

Add the repo next to `final _authRepo = AuthRepo();`:

```dart
  final _socialAuthRepo = SocialAuthRepo();
```

Replace the two TODO stubs `signInWithGoogle()` and `signInWithApple()` with:

```dart
  Future<void> signInWithGoogle() async {
    isLoadingGoogleSignIn.value = true;
    try {
      final result = await SocialAuthService.to.signInWithGoogle();
      if (result.isCancelled) return;
      if (!result.isSuccess) {
        showCustomSnackBar(
          context: Get.context!,
          type: SnackBarType.Failure,
          title: 'Google sign in failed'.tr,
          description: result.message ?? 'Please try again.'.tr,
        );
        return;
      }
      final response = await _socialAuthRepo.postGoogleSignInRepo(
        result.toParams(),
      );
      await _completeSocialSignIn(response);
    } finally {
      isLoadingGoogleSignIn.value = false;
    }
  }

  Future<void> signInWithApple() async {
    isLoadingAppleSignIn.value = true;
    try {
      final result = await SocialAuthService.to.signInWithApple();
      if (result.isCancelled) return;
      if (!result.isSuccess) {
        showCustomSnackBar(
          context: Get.context!,
          type: SnackBarType.Failure,
          title: 'Apple sign in failed'.tr,
          description: result.message ?? 'Please try again.'.tr,
        );
        return;
      }
      final response = await _socialAuthRepo.postAppleSignInRepo(
        result.toParams(),
      );
      await _completeSocialSignIn(response);
    } finally {
      isLoadingAppleSignIn.value = false;
    }
  }

  /// Only the session the backend returns counts as a login.
  Future<void> _completeSocialSignIn(dynamic response) async {
    if (response == null) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Error'.tr,
        description: 'No response from the server.'.tr,
      );
      return;
    }

    final baseResponse = BaseResponse<LoginData>.fromJson(
      response,
      (data) => LoginData.fromJson(data),
    );
    final token = baseResponse.data?.accessToken;

    if (token == null || token.isEmpty) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Authentication failed'.tr,
        description: baseResponse.message,
      );
      return;
    }

    final data = baseResponse.data!;
    await Future.wait([
      CacheManager.setToken(token),
      if (data.refreshToken != null)
        CacheManager.setRefreshToken(data.refreshToken!),
      CacheManager.setUserData(jsonEncode(data.user?.toJson())),
      CacheManager.removeIsGuest(),
      if (data.roles != null && data.roles!.isNotEmpty)
        CacheManager.setRoles(jsonEncode(data.roles)),
    ]);

    await Get.find<UserDi>().clearGuestMode();
    await Get.find<UserDi>().refreshUser();

    Get.offAllNamed(AppRoutes.DashboardScreen);
  }
```

`dart:convert`, `BaseResponse`, `LoginData`, `CacheManager`, `UserDi`, `AppRoutes` and `showCustomSnackBar` are already imported by that file.

`signup_controller.dart` takes the same three pieces, with two differences: keep its existing `if (!isAccept.value) { … return; }` guard at the top of each method, and add the imports it does not have yet:

```dart
import 'dart:convert';

import 'package:flutter_starter/app/core/di/user_di.dart';
import 'package:flutter_starter/app/core/models/base_response.dart';
import 'package:flutter_starter/app/feature/auth/auth_logic/social_auth_api_service.dart';
import 'package:flutter_starter/app/feature/auth/auth_models/auth_response.dart';
import 'package:flutter_starter/app/services/local_data/cache_manager.dart';
import 'package:flutter_starter/app/services/social_auth_service.dart';
```

### c. Screen — `lib/app/feature/auth/auth_presentation/signin_screen.dart`

The Google/Apple buttons are commented out at lines 116–121, and `buildGoogleSigninButton` / `buildAppleSigninButton` (lines 226 and 260) already render Lucide placeholders. Delete that commented block plus both helpers, then add the import:

```dart
import 'package:flutter_starter/app/widgets/buttons/social_auth_buttons.dart';
```

**Also delete the now-unused Lucide import from this file** — those two helpers were its only users, and `unused_import` is an **error** under this project's `analysis_options.yaml`:

```dart
import 'package:lucide_icons_flutter/lucide_icons.dart';   // delete
```

(`signup_screen.dart` keeps its Lucide import — other widgets there still use it.)

Call it in the body `Column`, just above `SizedBox(height: R.h(40))`:

```dart
            buildSocialAuthButtons(context, controller),
```

And add the helper next to the other `build*` methods:

```dart
  Widget buildSocialAuthButtons(
    BuildContext context,
    SigninController controller,
  ) {
    return Padding(
      padding: R.pad(horizontal: 16),
      child: Obx(
        () => SocialAuthButtons(
          onGooglePressed: controller.signInWithGoogle,
          onApplePressed: controller.signInWithApple,
          googleLoading: controller.isLoadingGoogleSignIn.value,
          appleLoading: controller.isLoadingAppleSignIn.value,
          enabled: !controller.isLoadingSignIn.value,
        ),
      ),
    );
  }
```

`signup_screen.dart` needs the same edit, except its buttons are live rather than commented: replace lines 50–55

```dart
              buildGoogleSigninButton(context, controller),

              SizedBox(height: R.h(10)),

              if (PlatformUtils.isIOS)
                buildAppleSigninButton(context, controller),
```

with `buildSocialAuthButtons(context, controller),`, delete its `buildGoogleSigninButton` / `buildAppleSigninButton` helpers (lines 299 and 333) and the now-unused `PlatformUtils` import. `SocialAuthButtons` does the iOS check itself. Keep the Lucide import — `buildInputField` still uses it.

Use this variant of the helper, **without** the `Padding`: `signup_screen`'s `_body` already wraps the column in `EdgeInsets.symmetric(horizontal: R.w(16))`, so the signin version's `R.pad(horizontal: 16)` would indent the buttons twice.

```dart
  Widget buildSocialAuthButtons(
    BuildContext context,
    SignupController controller,
  ) {
    return Obx(
      () => SocialAuthButtons(
        onGooglePressed: controller.signInWithGoogle,
        onApplePressed: controller.signInWithApple,
        googleLoading: controller.isLoadingGoogleSignIn.value,
        appleLoading: controller.isLoadingAppleSignIn.value,
        enabled: !controller.isLoadingSignIn.value,
      ),
    );
  }
```

### d. Optional — `lib/app/widgets/buttons/buttons.dart`

Direct imports work without this. To reach the buttons through the `widgets.dart` barrel, add:

```dart
export 'social_auth_buttons.dart';
```

### Routes / AppPages

Nothing to add. The module ships no screen.

## Usage

```dart
// Google
final result = await SocialAuthService.to.signInWithGoogle();
if (result.isSuccess) {
  final session = await SocialAuthRepo().postGoogleSignInRepo(result.toParams());
}

// Apple — a fresh nonce is generated per attempt unless you pass one
final apple = await SocialAuthService.to.signInWithApple();

// Hide the Apple button where the sheet cannot run
final canApple = await SocialAuthService.to.isAppleAvailable();

// Sign-out: clears the Google account cache. Apple has none — drop your session.
await SocialAuthService.to.signOut();
await SocialAuthService.to.disconnectGoogle(); // revokes consent too
```

`SocialAuthResult.toParams()` produces exactly this:

```jsonc
// Google
{ "id_token": "...", "access_token": "...", "server_auth_code": "...",
  "email": "a@b.com", "name": "Ada Lovelace" }

// Apple
{ "identity_token": "...", "authorization_code": "...", "nonce": "...",
  "user_identifier": "001234.abc...", "email": "a@b.com", "name": "Ada Lovelace" }
```

Null/empty values are dropped, so the server only sees what the provider actually returned.

## What your backend must do

**This is the part that makes it a login.** The app can only prove that *something* produced a token.

`POST /acc/auth/google`
1. Verify the `id_token` signature against Google's JWKS.
2. Check `aud` == your `GOOGLE_SERVER_CLIENT_ID` and `iss` == `accounts.google.com`, and that it has not expired.
3. Only then look up / create the user by the `sub` claim, and return the normal login envelope.

`POST /acc/auth/apple`
1. Redeem `authorization_code` with Apple's `/auth/token` **within 5 minutes**, using your Services key.
2. Verify the returned `id_token` against Apple's JWKS: `aud` == bundle ID (iOS) or Services ID (Android/web), `iss` == `https://appleid.apple.com`, `nonce` == the `nonce` the app sent.
3. Apple sends `email` / `name` on the **first** authorization only — persist them now or they are gone forever. Later sign-ins carry only `user_identifier`.
4. Store the Apple refresh token and re-check the grant daily; revoke your session when the user withdraws authorization.

Both endpoints should answer with the same envelope as `/acc/auth/login`:

```jsonc
{ "statusCode": 201, "message": "...", "data": {
    "access_token": "...", "refresh_token": "...", "user": { }, "roles": [] } }
```

Never trust `email` from the request body for account matching — it comes from the client. Match on the verified `sub` / `user_identifier`.

## Apple sign-in is mandatory

App Store Review Guideline **4.8**: an iOS app that offers *any* third-party or social login — Google included — must also offer Sign in with Apple. Ship both buttons or neither. That is why `SocialAuthButtons` renders Apple by default on iOS and macOS.

## Brand marks

The buttons use `LucideIcons.globe` and `LucideIcons.apple`. **No brand SVG ships with this module** — the original screens referenced `ImageUtils.GoogleIcon` / `ImageUtils.AppleIcon`, assets that no longer exist in the template.

Those glyphs are placeholders. Both companies require their own mark, wording and button styling in production:

- **Google** — use the official "G" mark and one of the sanctioned button styles from Google's Sign-In branding guidelines.
- **Apple** — `sign_in_with_apple` already exports a compliant `SignInWithAppleButton` (and an `AppleLogoPainter`). Swapping `AppleSignInButton` for it is a one-line change and is the safest route through review.

## Notes and gotchas

- **`google_sign_in` 6.x only.** Verified against 6.3.0 in the local pub cache; 7.x renames everything. See the pubspec note above.
- **No `id_token` on Android** is almost always a missing `GOOGLE_SERVER_CLIENT_ID`. The service returns a `failed` result saying exactly that instead of silently sending `null` to your API.
- **Cancellation is not an error.** Google throws `PlatformException(sign_in_canceled)` on iOS and returns `null` on Android; Apple throws `AuthorizationErrorCode.canceled`. All three map to `SocialAuthStatus.cancelled`, so no snackbar fires when the user backs out.
- **Android + Apple cancel** — if the user closes the Chrome Custom Tab, the platform future never resolves (documented package behaviour). The loading flag stays true until the next attempt; reset it on screen re-entry if that matters to you.
- **Nonce.** The raw nonce goes to both Apple and your backend. For the Firebase-style hashed variant, SHA-256 it before calling `signInWithApple(nonce: ...)` and send the raw value to the server — that needs the `crypto` package, which this module deliberately does not add.
- **Spinner colour.** The buttons put a tinted `CupertinoActivityIndicator` in the icon slot instead of using `CustomOutlinedButton.loading`, whose spinner is hard-coded white and invisible on the light Google button.
- **Duplicate endpoint paths.** Core's `ApiConstant` already declares `googleSignInUri` / `appleSignInUri` with the same values, and core's `AuthRepo` already has `postGoogleSignInRepo` / `postAppleSignInRepo`. `SocialAuthApiConst` + `SocialAuthRepo` duplicate them on purpose so the module installs without touching core — use whichever you prefer, they hit the same two paths.
- **macOS** additionally needs the `$(AppIdentifierPrefix)com.google.GIDSignIn` keychain access group; **web** needs Apple's `appleid.auth.js` in `index.html`. Neither platform is configured in this template.

## Why it is not in core

It pulls two native auth plugins and needs Google Cloud OAuth clients, a paid Apple Developer membership, two backend verification endpoints and per-platform signing config — none of which a project starting from this template has on day one.
