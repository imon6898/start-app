# app_attestation

Lets your backend tell your genuine app from a script, and stops a hostile network from reading your traffic.

Two independent pieces:

- **Attestation** — Play Integrity (Android) and App Attest/DeviceCheck (iOS) produce a token that your **server** verifies with Google/Apple. A Dio interceptor attaches it to a short allowlist of sensitive endpoints.
- **Certificate pinning** — SPKI pinning on the Dio `HttpClientAdapter`, replacing the `badCertificateCallback` TLS bypass that ships in `api_service.dart`.

## Read this first

Rate limiting and abuse prevention are **server** responsibilities. A mobile client cannot enforce them: an attacker patches the app, or skips it entirely and calls your API with curl. This module does not protect your API. It does exactly one useful thing for abuse prevention — it hands the server a **signal** it can use to tell a real install from a script — and it is worth nothing unless the server actually verifies that signal with Google/Apple and acts on the result.

Checking the attestation verdict in Dart would be security theatre. The client is the thing you do not trust.

An honest client can do three things about abuse, and this module is the third one:

1. **Be well-behaved** so normal use never trips a limit — here, caching, single-flight dedup and backoff around the native call, so the app never hammers Google/Apple.
2. **Degrade gracefully** when the server does limit you (429/503 → a clear message and a countdown, never a retry storm). **Not in this module** — it adds no 429 handling at all; that is the `api_resilience` and `abuse_guard` modules' job.
3. **Supply signals the server needs** to tell a real app from a script. That is what this module is for.

## Threat model

| Threat | Does this help? | Why |
| --- | --- | --- |
| Scripted API abuse (curl/Python against your endpoints) | **Helps** | A script has no Play Integrity token and no App Attest key. If the server requires a valid token on signup/login/OTP, the script has to drive a real device or a real app build instead. That raises cost; it does not make it impossible. |
| Credential stuffing | **Partially** | Same lever: it makes each attempt expensive rather than free. It does nothing about leaked passwords, and an attacker with one attested device can still try lists slowly. Per-account lockout and breached-password checks live on the server. |
| Emulator / device farms | **Partially** | Play Integrity reports `MEETS_DEVICE_INTEGRITY` only on a genuine, Play-certified device, so plain emulators fail. Physical device farms pass — they *are* real devices. Rooted-device and emulator detection is always defeatable given enough effort; treat the verdict as a risk score, not a gate. |
| MITM on hostile wifi | **Helps** | This is what `CertPinning` is for, and it is the strongest thing in this module. It also removes `badCertificateCallback => kDebugMode`, which disables validation outright in debug builds. Read the rotation warning before enabling. |
| A modified APK | **Partially** | Play Integrity's `MEETS_APP_INTEGRITY` covers "unmodified binary, installed from Play". A repackaged APK fails that check, so the server can refuse it. It does **not** stop a modified app from reading your `.env`, your pins, or your request format — those are in the binary and the binary belongs to the attacker. |

Short version: attestation raises the cost of abuse. It does not make abuse impossible, and every client-side check in it can eventually be defeated.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/attestation_service.dart` | `AttestationService` — GetxService over the platform channel. Caches, deduplicates and backs off so normal use never trips a quota. |
| `lib/app/services/attestation/attestation_token.dart` | `AttestationToken`, `AttestationKind`, `AttestationSkipReason`, `AttestationKeyRegistration` — and the header names the server reads. |
| `lib/app/services/attestation/attestation_interceptor.dart` | `AttestationInterceptor` — attaches the token to opted-in requests only. |
| `lib/app/services/domain/cert_pinning.dart` | `CertPinning` — SPKI pinning adapter, DER parser, persisted kill switch. |
| `platform/android/AttestationPlugin.kt` | Kotlin stub. **Not installed automatically** — copy it by hand. |
| `platform/ios/AttestationPlugin.swift` | Swift stub. **Not installed automatically** — copy it by hand. |

No UI, no routes, no user-facing strings.

## Install

```bash
dart run tool/add_module.dart app_attestation
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
cp modules/app_attestation/lib/app/services/attestation_service.dart            lib/app/services/
mkdir -p lib/app/services/attestation
cp modules/app_attestation/lib/app/services/attestation/attestation_token.dart       lib/app/services/attestation/
cp modules/app_attestation/lib/app/services/attestation/attestation_interceptor.dart lib/app/services/attestation/
cp modules/app_attestation/lib/app/services/domain/cert_pinning.dart           lib/app/services/domain/
```

Then the dependency, the `.env` keys, the native code, and the wiring below.

### 1. pubspec.yaml

```yaml
dependencies:
  crypto: ^3.0.7
```

`dio`, `get`, `shared_preferences` and `flutter_dotenv` are already in the template core.

### 2. .env

```env
PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=123456789012
CERT_PINNING_ENABLED=false
```

`PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER` is the Google Cloud project number linked in Play Console (Release → App integrity). It is not a secret — it identifies who may decrypt the token. Empty means Android attestation stays off and `tokenFor()` returns null.

`CERT_PINNING_ENABLED` is read by your own bootstrap code (see Wiring). Ship it `false` until you have verified your pins on a real device.

### 3. Native code — required

**There is no verified first-party Flutter package for Play Integrity or App Attest.** Neither Google nor Apple publishes one, and this module does not depend on a third-party wrapper it cannot vouch for. `AttestationService` talks to a `MethodChannel` named `flutter_starter/attestation`, and **you must ship the native side yourself**. Without it, `init()` logs `off — native side not installed` and every `tokenFor()` returns null — the app still works, it just sends no attestation signal.

#### Android

```bash
cp modules/app_attestation/platform/android/AttestationPlugin.kt \
   android/app/src/main/kotlin/com/easital/starter/
```

Fix the `package` line if your `applicationId` is not `com.easital.starter`. Then:

`android/app/build.gradle.kts`, inside `dependencies { }` (add the block if it is not there yet — the template has none):

```kotlin
dependencies {
    implementation("com.google.android.play:integrity:1.5.0")
}
```

`android/app/src/main/kotlin/com/easital/starter/MainActivity.kt`:

```kotlin
package com.easital.starter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AttestationPlugin())
    }
}
```

`android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

In Play Console → Release → App integrity: enable the Integrity API, link the Google Cloud project, and register your release signing key. Play Integrity only returns a usable verdict for a build **installed from Play** — an internal testing track counts, a sideloaded debug APK does not. That failure is correct behaviour, not a bug.

#### iOS

```bash
cp modules/app_attestation/platform/ios/AttestationPlugin.swift ios/Runner/
```

Add the file to the **Runner** target in Xcode (drag it into the project navigator with "Add to targets: Runner" ticked), or it silently will not compile into the app.

Xcode → Runner target → Signing & Capabilities → **+ Capability → App Attest**. Set the environment to `production` for App Store builds.

`ios/Runner/AppDelegate.swift`:

```swift
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    AttestationPlugin.register(                                        // add
      with: engineBridge.pluginRegistry.registrar(forPlugin: "AttestationPlugin")!
    )
  }
```

App Attest needs iOS 14+ and a **physical device**; the simulator always fails. The stub falls back to DeviceCheck (iOS 11+) when App Attest is unavailable or no key is registered yet.

The template deploys to iOS 13.0, so every `DCAppAttestService` call in the plugin is wrapped in `if #available(iOS 14.0, *)`. Verified: `swiftc -typecheck -target arm64-apple-ios13.0` against the iOS SDK is clean, and the file compiles into the Runner Swift module in a real `flutter build ios`. Do not remove those guards unless you also raise `IPHONEOS_DEPLOYMENT_TARGET`.

Unrelated pre-existing gotcha you will hit first: `flutter build ios` fails on this template regardless of this module, because `file_picker_darwin` needs iOS 14 while `ios/Runner.xcodeproj` and the Podfile are pinned to 13.0. Raise both to 14.0 (`platform :ios, '14.0'` plus the three `IPHONEOS_DEPLOYMENT_TARGET` entries) before you try to build.

## Wiring

Three edits to core, all in files the template already has.

### `lib/bootstrap.dart`

Add the imports:

```dart
import 'app/services/attestation_service.dart';
import 'app/services/domain/cert_pinning.dart';
```

Then, immediately after `await CacheManager.init();`:

```dart
    // Arm pinning before the first request. See the module README before
    // setting CERT_PINNING_ENABLED=true — a stale pin bricks installed clients.
    CertPinning.configure(
      hosts: const {'api.example.com'},
      pins: const {
        'REPLACE_WITH_CURRENT_SPKI_SHA256_BASE64',
        'REPLACE_WITH_BACKUP_SPKI_SHA256_BASE64',
      },
      enabled: Env.optional('CERT_PINNING_ENABLED').toLowerCase() == 'true',
    );
    await CertPinning.restoreKillSwitch();

    // Warms the attestation provider. Never throws; leaves attestation off on failure.
    unawaited(AttestationService.to.init());
```

`unawaited` is already imported in `bootstrap.dart` via `dart:async`.

### `lib/app/services/domain/api_service.dart`

Add the imports:

```dart
import '../attestation/attestation_interceptor.dart';
import 'cert_pinning.dart';
```

Replace this block in the constructor (just after `_dio = Dio(options);`):

```dart
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final HttpClient client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => kDebugMode;
        return client;
      },
    );
```

with:

```dart
    // Pinned adapter. Fails closed on an untrusted chain, in debug builds too.
    _dio.httpClientAdapter = CertPinning.adapter();

    // Attestation on sensitive endpoints only — the API is quota-limited.
    _dio.interceptors.add(
      AttestationInterceptor(
        paths: const [
          ApiConstant.signupUserUri,
          ApiConstant.loginUri,
          ApiConstant.sentOtpUri,
          ApiConstant.reSentOtpUri,
        ],
      ),
    );
```

Then delete `import 'package:dio/io.dart';` from the top of the file — nothing else uses it, and the analyzer will flag it. Keep `dart:io` (still used by the upload methods) and `package:flutter/foundation.dart` (still used by `kDebugMode` for the logger).

That is the whole install. Nothing else in core changes.

If the `api_resilience` module is also installed, its interceptor is added after the token-refresh wrapper and this one before it. They do not overlap: attestation only touches `onRequest` headers, resilience only touches retries and `onError`. Order does not matter.

## Usage

The interceptor does the work; most apps never call the service directly.

```dart
// Per-request opt-in when you are driving Dio yourself. The template's
// ApiService.post() takes no Options, so the path allowlist is the normal route.
dio.post(
  '/acc/auth/login',
  data: body,
  options: Options(extra: {AttestationInterceptor.extraKey: true}),
);
```

Manual token, e.g. before a payment confirmation:

```dart
final hash = AttestationService.hashFor('POST', ApiConstant.loginUri, body);
final token = await AttestationService.to.tokenFor(hash);
if (token != null) {
  headers.addAll(token.toHeaders());
}
```

iOS App Attest key registration — once per install, with a server-issued single-use challenge:

```dart
final challenge = await authRepo.fetchAttestChallenge();      // your endpoint
final reg = await AttestationService.to.registerKey(challenge);
if (reg != null) await authRepo.registerAttestKey(reg.toJson());
```

Until that POST succeeds, iOS falls back to a DeviceCheck token. On Android `registerKey()` returns null — Play Integrity needs no registration step.

Call `AttestationService.to.invalidate()` when the server rejects a token, and `resetKey()` after a sign-out that should not carry the key forward.

### What the server must do

The headers are meaningless unless the backend acts on them.

| Header | Contents |
| --- | --- |
| `X-Attestation-Kind` | `playIntegrity`, `appAttestAssertion` or `deviceCheck` — picks the verifier. |
| `X-Attestation-Token` | Opaque token. Base64 for iOS, the raw JWT-like blob for Play Integrity. |
| `X-Attestation-Key-Id` | iOS only, the App Attest key the assertion was signed with. |
| `X-Attestation-Request-Hash` | URL-safe base64 `SHA-256("METHOD\npath\njsonBody")`. |
| `X-Attestation-Skipped` | Sent **instead** of a token, with the reason, when none was available. |

1. Verify the token with Google's Play Integrity API or Apple's App Attest/DeviceCheck verification, server-side. Never trust a client-supplied verdict.
2. Recompute `X-Attestation-Request-Hash` from the request you actually received and compare. On Android it must equal Play Integrity's `requestDetails.requestHash`; on iOS the assertion's `clientDataHash` is `SHA-256` of the **header value's bytes**, and for `attestKey` it is `SHA-256` of the raw challenge string.
3. Reject replays — bind the token to a nonce/challenge you issued and use it once.
4. Decide policy per endpoint. An unattested request is not automatically an attacker (old app versions, no Play Services, a Huawei device), so choose per route: allow, allow-with-stricter-rate-limit, or block.

## Certificate pinning — read before enabling

### Getting your pins

The current leaf key:

```bash
openssl s_client -servername api.example.com -connect api.example.com:443 </dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
```

Every certificate in the served chain, so you can see what the CA sends:

```bash
openssl s_client -servername api.example.com -connect api.example.com:443 -showcerts </dev/null 2>/dev/null \
  | awk '/BEGIN CERT/,/END CERT/' > chain.pem
csplit -z -f cert- -b '%02d.pem' chain.pem '/-----BEGIN CERTIFICATE-----/' '{*}'
for f in cert-*.pem; do
  printf '%s  ' "$f"
  openssl x509 -in "$f" -pubkey -noout | openssl pkey -pubin -outform der \
    | openssl dgst -sha256 -binary | openssl enc -base64
done
```

A **backup pin**, from a key pair you have generated but not deployed. Keep the private key offline:

```bash
openssl ecparam -genkey -name prime256v1 -out backup.key
openssl pkey -in backup.key -pubout -outform der \
  | openssl dgst -sha256 -binary | openssl enc -base64
```

These are the same values `CertPinning.spkiSha256()` computes from `X509Certificate.der`, so you can assert them in a test.

### The hazard

**A pin that stops matching bricks every installed client.** The app cannot reach the server at all, so you cannot fix it with a server deploy, a config change, or a push notification. You fix it by shipping a new build and waiting for users to update — days at best. Do not enable pinning on a Friday.

Four rules:

1. **Pin the key, not the certificate.** SPKI pinning survives certificate renewal *as long as the key is reused*. Renew with the same key pair (`openssl req -new -key current.key`) and your pin never changes. If your CA or your ACME client rotates the key on every renewal — Let's Encrypt via certbot does by default; `--reuse-key` turns that off — your pin dies every 60–90 days. Check this before anything else.
2. **Always ship a backup pin.** At least two values in `pins`, one of them a key you have not deployed yet. Then key rotation is: switch the server to the backup key, ship a new build with a new backup, repeat.
3. **Prefer pinning the CA when the leaf key is out of your control.** Dio's `validateCertificate` only ever sees the **leaf** — Dart never exposes the full peer chain — so you cannot check an intermediate there. Pin a CA instead by passing `trustAnchorsPem`, which replaces the system trust store for those connections:

   ```dart
   CertPinning.configure(
     hosts: const {'api.example.com'},
     pins: const {},                       // no leaf pin; the CA is the pin
     trustAnchorsPem: await rootBundle.loadString('assets/certs/intermediate.pem'),
   );
   ```

   Weaker than SPKI pinning — any certificate that CA issues is accepted — but it survives leaf rotation. Combining both (CA anchor + leaf key pins) is the usual answer.
4. **Ship a kill switch, and host it somewhere unpinned.** `hosts` scopes pinning, so leave your kill-switch host out of that set. If the flag lives behind the pinned API, a bad pin blocks the very request that would have saved you.

   ```dart
   // Any host NOT in CertPinning.pinnedHosts — an object store or CDN works.
   final res = await Dio().get('https://cdn.example.com/app/pinning.json');
   if (res.data['disabled'] == true) await CertPinning.setEnabled(false);
   ```

   `setEnabled` persists to SharedPreferences and `restoreKillSwitch()` reads it at boot, so the disable survives a restart. Without persistence the app re-bricks on next launch.

### It replaces the TLS bypass

The template's `api_service.dart` currently does this:

```dart
client.badCertificateCallback =
    (X509Certificate cert, String host, int port) => kDebugMode;
```

That accepts **any** certificate in a debug build — including an attacker's, including a proxy's. It is the pattern that leaks into release builds when someone flips a flag to debug a staging cert, and it must never ship. `CertPinning.adapter()` sets no `badCertificateCallback` at all, so an untrusted chain fails the connection in every build. If you need to intercept traffic with a proxy locally, add the proxy CA to the device trust store; do not reintroduce the bypass.

## What this does NOT protect against

- **Anything, if the backend does not verify the token.** The headers are inert until the server calls Google/Apple, checks the verdict, and rejects what it does not like. This module is half of a feature; the other half is not in Dart.
- **Rate limiting.** It does not add any. A client cannot rate-limit itself in a way an attacker must respect — they patch the app or skip it. Limits belong in the server, or in a WAF/API gateway in front of it.
- **A determined attacker.** Play Integrity and App Attest raise cost; they do not make abuse impossible. Real devices can be farmed, tokens can be relayed from a genuine device to a script, and every root/emulator check ever shipped has eventually been bypassed. Treat the verdict as a risk score feeding a decision, not as a gate that cannot be opened.
- **Secrets in the binary.** Your `.env`, your pins, your endpoints and your request format are all in the APK/IPA, which belongs to the attacker. Nothing here changes that.
- **Users you locked out.** No Play Services, a device that has never talked to Play, an old OS, a corporate MITM proxy — all of these produce no token or a failing chain. That is why the interceptor fails **open** by default and why pinning has a kill switch.
- **Platforms other than Android and iOS.** `isSupportedPlatform` is false everywhere else and everything no-ops.

## Notes and gotchas

- **Attestation is quota-limited and slow.** This is the main operational gotcha and the reason the interceptor takes an allowlist rather than attaching a token to everything. Play Integrity standard requests are cheap *after* `prepareIntegrityToken` has run, but the warm-up itself is rate-limited; classic requests are limited hard enough that per-request use is not viable. Apple throttles App Attest key generation aggressively (one key per install is the design), while assertions are cheap. The published numbers change — check the current Google and Apple docs before widening `paths`.
- The service defends itself accordingly: a 5-minute token TTL, a 10-second floor between native calls, single-flight deduplication of concurrent callers, and exponential backoff from 30s to 15min after failures. Tune `tokenTtl`, `minInterval`, `baseBackoff` and `maxBackoff` on the instance.
- **Fail-open is deliberate.** When no token is available the interceptor sends `X-Attestation-Skipped: <reason>` and lets the request through. Pass `failOpen: false` to reject locally instead, but be clear about what you are choosing: a client that refuses to send is a client that locks users out during a Play Services outage, and it stops nothing — the attacker's build simply does not have your check.
- The iOS App Attest key id is stored in **SharedPreferences**, not encrypted storage. It is an identifier, not a secret (the private key stays in the Secure Enclave and never leaves it). If you would rather keep it out of plaintext prefs, the `secure_storage` module is the place for it.
- **It coexists with the 401 token-refresh retry, it does not fight it.** That retry calls `_dio.fetch(opts)`, and `fetch` re-runs the request interceptors — so `onRequest` fires a second time for the same request. The interceptor sees `X-Attestation-Token` already set and leaves it alone, so a refresh costs no extra attestation call. `Options(extra: {AttestationInterceptor.skipKey: true})` forces a skip if you need one.
- `hashFor()` cannot hash `FormData` or a stream, so multipart uploads are bound to `METHOD\npath` only. Do not put file uploads on the attestation allowlist and expect body binding.
- Play Integrity's `requestHash` is a string with a length budget (Google documents a recommended cap, currently 500 bytes); a base64 SHA-256 is 44 characters, so this is never a problem here.
- `CertPinning` logs a warning through `devPrint` when you arm it with fewer than two pins. Take that seriously.

## Why it is not in core

Attestation cannot work without native code, a Play Console configuration, a Cloud project and an App Attest capability — none of which a fresh template has, and most projects starting from it never will. Turning it on with nothing on the server that verifies the token adds latency and quota consumption for zero security benefit.

Certificate pinning is kept out for the opposite reason: it is easy to enable and catastrophic to get wrong. A template that shipped pins armed by default would brick the first app whose certificate rotated. Opting in should be a decision someone makes deliberately, having read the rotation rules above.
