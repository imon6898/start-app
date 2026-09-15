# feature_flags

Remote config, kill switches and A/B experiments served by **your** backend. A `GetxService` fetches one flag document, caches it on disk, and exposes it through typed keys that are checked at compile time. Flags are `Rx`, so a value that flips mid-session rebuilds the UI. Experiments bucket deterministically, so a user sees the same variant on every launch and every device. A debug screen lets QA override any flag locally with no backend at all.

**Read this first — flags are not a security boundary.** A flag decides what the app *shows*, never what a user is *allowed to do*:

- The gated feature's code, strings and assets still ship in the binary. Anyone can unzip an IPA/APK and read them.
- The flag value is read from `SharedPreferences`. A rooted device, a patched build or a proxied response flips it.
- Therefore: never gate an entitlement, a price, a permission or a paid tier with a flag alone. The server must refuse the request independently. See [What this does NOT protect against](#what-this-does-not-protect-against).

What it *is* good for: shipping code dark, turning a broken feature off without a release, tuning a constant without a release, and measuring two variants honestly.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/feature_flags/feature_flag_keys.dart` | `FlagKey<T>` and its typed subclasses `BoolFlag` / `KillSwitch` / `IntFlag` / `StringFlag` / `JsonFlag`, `Experiment`, and the `FeatureFlags` registry you edit. |
| `lib/app/services/feature_flags/feature_flag_service.dart` | `FeatureFlagService` — the `GetxService`: cache hydration, fetch, typed `Rx` reads, rollouts, experiments, overrides. Plus `Flags`, a static passthrough that works when the service is not registered. |
| `lib/app/services/feature_flags/feature_flag_resolver.dart` | `FlagResolver` (the pure precedence ladder + type coercion), `FlagSource`, `FlagDocument`, `ExperimentConfig`. No Rx, no plugins. |
| `lib/app/services/feature_flags/feature_flag_bucketing.dart` | `FlagBucketing` — FNV-1a 32-bit hash, `bucketOf`, `variantOf`, `inRollout`. |
| `lib/app/services/feature_flags/feature_flag_store.dart` | `FeatureFlagStore` — module-owned `SharedPreferences` keys: cached document, fetch time, overrides, anonymous bucketing id. |
| `lib/app/services/feature_flags/feature_flags_api_service.dart` | Style-A trio: `FeatureFlagsApiService` / `FeatureFlagsImpl` / `FeatureFlagsRepo`. |
| `lib/app/services/feature_flags/feature_flags_api_const.dart` | `FeatureFlagsApiConst.flagsUri` — module-owned endpoint, so `ApiConstant` needs no edit. |
| `lib/app/services/feature_flags/feature_flags_debug_controller.dart` | `FeatureFlagsDebugController` — search, toggle, edit, reset, variant cycling. |
| `lib/app/services/feature_flags/feature_flags_debug_screen.dart` | `FeatureFlagsDebugScreen` — every flag with its resolved value, source badge and local override. |
| `test/unit/feature_flags_test.dart` | 37 tests: FNV-1a vectors, bucket determinism and spread, the precedence ladder, coercion of malformed remote values, document parsing, cache-survives-a-failed-fetch, and the debug screen. |

## Install

```bash
dart run tool/add_module.dart feature_flags
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
mkdir -p lib/app/services/feature_flags
cp modules/feature_flags/lib/app/services/feature_flags/*.dart lib/app/services/feature_flags/
cp modules/feature_flags/test/unit/feature_flags_test.dart     test/unit/
```

### pubspec.yaml

Nothing to add:

```yaml
# get, dio, shared_preferences and lucide_icons_flutter are already in core.
```

### Platform config

None. No native code, no permissions, no Gradle or plist changes.

### .env

One optional key. Add a placeholder to `.env.example`:

```dotenv
# feature_flags — path on the active base URL that serves the flag document.
# Absent or empty falls back to /config/flags.
FEATURE_FLAGS_PATH=/config/flags
```

It is read only through `Env.optional`, so a missing key is not a startup failure.

## Backend JSON contract

One `GET` on `ApiConstant.activeBaseUrl + FeatureFlagsApiConst.flagsUri`, with `?user_id=<id>` when a user id is set. Respond with:

```json
{
  "version": 12,
  "updated_at": "2026-09-15T10:00:00Z",
  "flags": {
    "checkout_enabled":     { "value": true },
    "social_login_enabled": { "value": false },
    "new_dashboard":        { "value": true, "rollout": 25 },
    "max_upload_mb":        { "value": 25 },
    "support_email":        { "value": "help@example.com" },
    "promo_banner":         { "value": { "title": "Spring sale", "deeplink": "/promo/1" } }
  },
  "experiments": {
    "onboarding_copy": {
      "variants": ["control", "short", "video"],
      "exposure": 50,
      "forced_variant": null
    }
  }
}
```

| Field | Meaning |
| --- | --- |
| `version` | Any integer you bump on every publish. Shown in the debug screen; useful in a support ticket. Optional. |
| `updated_at` | ISO-8601. Parsed if present, otherwise ignored. Optional. |
| `flags.<name>.value` | The value. Must match the type declared in `FeatureFlags`; a mismatch is ignored, not coerced into nonsense. |
| `flags.<name>.rollout` | `0`–`100`. Only meaningful on a bool flag: the value must be `true` **and** the user must fall inside the percentage. Out-of-range is clamped. Optional. |
| `experiments.<key>.variants` | Overrides the compiled variant list. Omit to keep the app's list. |
| `experiments.<key>.exposure` | `0`–`100`. Overrides the compiled exposure — this is how you ramp an experiment without a release. |
| `experiments.<key>.forced_variant` | Pins everyone to one variant. For QA and for landing a winner before you delete the experiment. |

Accepted shape variations, so you can keep an existing endpoint:

- The `flags` envelope is optional — a flat `{"checkout_enabled": true, "max_upload_mb": 25}` works, minus the keys `version`, `updated_at`, `experiments`.
- A bare value is allowed instead of `{"value": …}`: `"max_upload_mb": 25`. You then lose `rollout` on that flag.
- A `{"data": {…}}` envelope is unwrapped.
- Per flag, `true`/`"true"`/`1` all read as true; `25`/`"25"` both read as the int `25`; a JSON-encoded string is accepted for a json flag.

**One ambiguity to know about:** a json flag's payload is detected by *not* having a `value` key. If your payload genuinely needs a top-level `value` field, wrap it — `{"value": {"value": 1}}`.

## Wiring

### 1. `lib/bootstrap.dart` — required

Add the imports:

```dart
import 'package:get/get.dart';
import 'app/services/feature_flags/feature_flag_service.dart';
```

Then, right after `await CacheManager.init();` and before `ViewModelBinding().dependencies();`:

```dart
    // Cached flags are ready before the first frame; the fetch runs after it.
    await Get.putAsync(() => FeatureFlagService().init());
```

`init()` reads the cached document synchronously and schedules the network fetch in a post-frame callback, so startup is never gated on the network **and** the first frame already shows real values.

**Do not await the fetch here.** `ApiService` reports "no internet" through `showCustomSnackBar(context: Get.context!)`, and before `runApp` there is no context. `refresh()` catches that (it catches `Error` as well as `Exception`) but you would still be trading a slow launch for nothing. If you genuinely must block on it — a kill switch you refuse to run without — do it on the splash screen where a context exists:

```dart
await FeatureFlagService.to.refresh().timeout(
  const Duration(seconds: 3),
  onTimeout: () => false,
);
```

### 2. Identity — required for experiments

Buckets are derived from the id, so the id has to be the *server's* user id. Anything per-device means the same person gets different variants on their phone and tablet.

```dart
// After a successful sign-in:
FeatureFlagService.to.setUserId(Get.find<UserDi>().userData?.id);
await FeatureFlagService.to.refresh();   // re-fetch: targeting is per user

// After sign-out:
FeatureFlagService.to.setUserId(null);
// Only if your flag document is user-specific:
await FeatureFlagService.to.clearCachedDocument();
```

With no user id, bucketing falls back to a per-install anonymous id generated once and kept in `SharedPreferences`.

### 3. The debug screen — optional

`lib/app/routes/app_routes.dart`:

```dart
  /// feature_flags debug screen (dev builds only).
  static const String FeatureFlagsDebugScreen = '/featureFlagsDebugScreen';
```

`lib/app/routes/app_pages.dart` — import and page entry:

```dart
import '../services/feature_flags/feature_flags_debug_screen.dart';
```

```dart
    _page(
      AppRoutes.FeatureFlagsDebugScreen,
      () => const FeatureFlagsDebugScreen(),
    ),
```

Nothing goes in `ViewModelBinding`: the screen creates its controller with `GetBuilder(init:)`, and `FeatureFlagService` is a `GetxService`. Gate whatever opens the route on `kDebugMode` so the door does not ship.

### 4. Localization — required if you keep the debug screen

The screen's strings are not in `AppTranslations`, so `test/guardrails/localization_test.dart` fails until they are. Paste into `lib/app/localization/locales/en_us.dart`:

```dart
  // Feature flags (debug screen)
  'Feature flags': 'Feature flags',
  'Flags': 'Flags',
  'Experiments': 'Experiments',
  'Version': 'Version',
  'Last fetch': 'Last fetch',
  'Bucketing id': 'Bucketing id',
  'Bucket': 'Bucket',
  'never': 'never',
  'override': 'override',
  'remote': 'remote',
  'default': 'default',
  'Not enrolled': 'Not enrolled',
  'Local value': 'Local value',
  'Save': 'Save',
  'Clear override': 'Clear override',
  'Reset all overrides': 'Reset all overrides',
  'Invalid value': 'Invalid value',
  'It does not match the flag type.': 'It does not match the flag type.',
  'Flags updated': 'Flags updated',
  'The document was refreshed from the backend.':
      'The document was refreshed from the backend.',
  'Flag fetch failed': 'Flag fetch failed',
  'Cached values are still in use.': 'Cached values are still in use.',
  'Overrides are disabled in release builds.':
      'Overrides are disabled in release builds.',
  'FeatureFlagService is not registered.':
      'FeatureFlagService is not registered.',
```

And into `lib/app/localization/locales/bn_bd.dart` (every locale must carry exactly the `en_US` keys):

```dart
  // Feature flags (debug screen)
  'Feature flags': 'ফিচার ফ্ল্যাগ',
  'Flags': 'ফ্ল্যাগ',
  'Experiments': 'এক্সপেরিমেন্ট',
  'Version': 'সংস্করণ',
  'Last fetch': 'সর্বশেষ আনা হয়েছে',
  'Bucketing id': 'বাকেটিং আইডি',
  'Bucket': 'বাকেট',
  'never': 'কখনো নয়',
  'override': 'ওভাররাইড',
  'remote': 'রিমোট',
  'default': 'ডিফল্ট',
  'Not enrolled': 'অন্তর্ভুক্ত নয়',
  'Local value': 'স্থানীয় মান',
  'Save': 'সংরক্ষণ করুন',
  'Clear override': 'ওভাররাইড মুছুন',
  'Reset all overrides': 'সব ওভাররাইড রিসেট করুন',
  'Invalid value': 'অবৈধ মান',
  'It does not match the flag type.': 'এটি ফ্ল্যাগের ধরনের সাথে মেলে না।',
  'Flags updated': 'ফ্ল্যাগ হালনাগাদ হয়েছে',
  'The document was refreshed from the backend.':
      'ব্যাকএন্ড থেকে ডকুমেন্ট হালনাগাদ হয়েছে।',
  'Flag fetch failed': 'ফ্ল্যাগ আনা যায়নি',
  'Cached values are still in use.': 'ক্যাশে করা মান এখনও ব্যবহার হচ্ছে।',
  'Overrides are disabled in release builds.':
      'রিলিজ বিল্ডে ওভাররাইড নিষ্ক্রিয়।',
  'FeatureFlagService is not registered.':
      'FeatureFlagService নিবন্ধিত নয়।',
```

If you do not want the debug screen at all, delete `feature_flags_debug_screen.dart` and `feature_flags_debug_controller.dart` and skip this step — nothing else references them.

## Usage

### Declare the flags

Edit `FeatureFlags` in `feature_flag_keys.dart`. The name is the JSON key; the fallback is what a device with no cached document sees.

```dart
class FeatureFlags {
  FeatureFlags._();

  static const KillSwitch checkout = KillSwitch('checkout_enabled');
  static const BoolFlag newDashboard = BoolFlag('new_dashboard');            // ships dark
  static const IntFlag maxUploadMb = IntFlag('max_upload_mb', fallback: 10);
  static const StringFlag supportEmail =
      StringFlag('support_email', fallback: 'support@example.com');
  static const JsonFlag promoBanner = JsonFlag('promo_banner');

  static const List<FlagKey<Object>> all = [
    checkout, newDashboard, maxUploadMb, supportEmail, promoBanner,
  ];

  static const Experiment onboardingCopy = Experiment(
    'onboarding_copy',
    variants: ['control', 'short', 'video'],
    exposure: 50,
  );

  static const List<Experiment> experiments = [onboardingCopy];
}
```

`all` and `experiments` are what the debug screen shows — keep them in sync or QA cannot see the flag.

A typo is a compile error, not a silently-false flag: there is no `isEnabled('new_dashbord')` overload taking a string.

### Read a flag

```dart
final flags = Get.find<FeatureFlagService>();     // or FeatureFlagService.to

if (flags.isEnabled(FeatureFlags.newDashboard)) { ... }
final limitMb = flags.intOf(FeatureFlags.maxUploadMb);
final email   = flags.stringOf(FeatureFlags.supportEmail);
final banner  = flags.jsonOf(FeatureFlags.promoBanner);   // Map<String, dynamic>
```

### React to a flag flipping mid-session

Reads inside `Obx` register with the underlying `RxMap`, so a refresh rebuilds only that slice:

```dart
Obx(() => FeatureFlagService.to.isEnabled(FeatureFlags.newDashboard)
    ? const NewDashboardBody()
    : const LegacyDashboardBody());
```

### Read from somewhere the service may not exist

Early startup, a widget test, a utility with no DI. `Flags.*` falls back to the hardcoded default instead of throwing — at the cost of not being reactive:

```dart
if (Flags.isEnabled(FeatureFlags.checkout)) { ... }
```

### A kill switch

```dart
// In the controller that opens checkout:
if (FeatureFlagService.to.isKilled(FeatureFlags.checkout)) {
  showCustomSnackBar(
    context: Get.context!,
    type: SnackBarType.Warning,
    title: 'Temporarily unavailable'.tr,
    description: 'Checkout is paused while we fix an issue.'.tr,
  );
  return;
}
```

To kill it: set `"checkout_enabled": {"value": false}` on the backend. Clients pick it up on their next `refresh()` — next cold start, or immediately if you call `refresh()` on resume or from a silent push. **The value then persists in the cache**, so it stays off across restarts and offline launches. That is the whole mechanism; see [How the cache makes a kill switch honest](#how-the-cache-makes-a-kill-switch-honest).

### A percentage rollout

Ship the code dark, then ramp from the backend without a release:

```json
"new_dashboard": { "value": true, "rollout": 5 }
```

5% of users, chosen by bucket, not by luck: the same 5% stay in as you ramp to 10, 25, 100. Setting `"value": false` turns it off for everyone regardless of `rollout`.

### An experiment

```dart
final variant = FeatureFlagService.to.variantOf(FeatureFlags.onboardingCopy);

switch (variant) {
  case 'short':   return const ShortOnboarding();
  case 'video':   return const VideoOnboarding();
  case null:      return const ControlOnboarding();   // not enrolled
  default:        return const ControlOnboarding();   // control, or an unknown arm
}
```

`variantOf` returns `null` for a user outside `exposure`. Keep that distinct from the control arm — mixing "not in the experiment" into "control" is how an A/B test quietly reports a 0% effect. Use `variantOrControl` only for rendering, never for reporting.

Log the exposure with your own analytics, once, when the user actually sees the variant:

```dart
analytics.log('experiment_exposed', {
  'experiment': FeatureFlags.onboardingCopy.key,
  'variant': variant,
  'bucket': FeatureFlagService.to.bucketOf(FeatureFlags.onboardingCopy),
});
```

### The debug screen

```dart
Get.toNamed(AppRoutes.FeatureFlagsDebugScreen);
```

Per row: the flag name, its description, the resolved value (plus `· 25%` when a rollout applies), and a badge saying where the value came from — `override` / `remote` / `default`. Bool flags get a switch; int / string / json flags open a sheet with the raw value. The reset arrow drops that one override; **Reset all overrides** drops them all. Experiments show the resolved variant and the bucket, and the toggle button cycles none → variant 1 → variant 2 → none so QA can walk every arm.

Overrides persist across restarts and are ignored entirely in release builds.

## Behaviour, exactly

### The precedence ladder

Every read resolves in the same order, with no exceptions:

1. **Local override** — set from the debug screen, stored on disk. Skipped when `kReleaseMode`.
2. **Remote value** — from the live document, or from the cached copy of the last successful fetch. The code cannot tell those apart, and that is the point.
3. **Hardcoded fallback** — the value compiled into `FeatureFlags`.

A remote `false` beats a `true` fallback: presence, not truthiness, decides which rung wins.

### How the cache makes a kill switch honest

`refresh()` returns `bool` and **never clears anything on failure**. A failed fetch leaves the previous document in place and sets `lastError`.

This is not politeness, it is the entire contract. If a failed fetch reset flags to their compiled defaults, then a user with no signal would launch the app and get the feature you killed yesterday — the switch would fail *open*, which is not a switch. The ladder above is what makes "off" stick: the value was written to disk the moment it arrived, and nothing but a newer successful document overwrites it.

Two consequences worth stating plainly:

- **The first launch on a brand-new install has no cache.** It sees the hardcoded fallback until the first fetch lands. That is why `KillSwitch` takes a fallback: leave it `true` for a feature users already rely on, pass `fallback: false` for anything that must stay off on a device that has never reached your backend.
- **A kill switch is not instant.** It applies on the next successful `refresh()`. Call `refresh()` on app resume, or trigger it from a silent push, if "within seconds" matters.

### Type coercion, and what a bad backend edit does

The declared type wins. A value that cannot be read as that type is treated as absent, so the next rung down applies:

| Declared | Accepted | Ignored (falls through) |
| --- | --- | --- |
| `BoolFlag` | `true`, `false`, `"true"`, `"TRUE"`, `"false"`, `1`, `0` | `7`, `"yes"`, `"on"`, `{}` |
| `IntFlag` | `25`, `25.9` (→ `25`), `"25"` | `"abc"`, `true`, `{}` |
| `StringFlag` | any JSON string | `42`, `true`, `{}` — deliberately strict |
| `JsonFlag` | a JSON object, or a string containing one | an array, a scalar, malformed JSON |

So one fat-fingered backend edit degrades one flag to its previous or default value. It never throws, and it never takes the app down.

An unparseable *document* (truncated JSON, an HTML error page) is rejected whole by `FlagDocument.tryParse`, leaving the previous document intact.

### Deterministic bucketing

Non-deterministic bucketing invalidates the experiment: if a user is re-rolled on each launch they see both arms, their behaviour lands in both buckets, and the measured difference converges on zero. So the bucket is a pure function of the id and the key — no randomness, no timestamps, no device state.

```
bucket        = FNV1a32("<id>:<key>")          % 100     // enrolment, 0..99
variantBucket = FNV1a32("<id>:<key>#variant")  % 100     // which arm
variantIndex  = variantBucket * variants.length / 100    // integer division
enrolled      = bucket < exposure
```

FNV-1a 32-bit over the UTF-8 bytes, so your backend can compute the same bucket and target the same users:

```python
def fnv1a32(s: str) -> int:
    h = 0x811c9dc5
    for b in s.encode('utf-8'):
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h

bucket = fnv1a32(f'{user_id}:{experiment_key}') % 100
```

The tests pin the canonical vectors (`""` → `0x811c9dc5`, `"a"` → `0xe40c292c`, `"foobar"` → `0xbf9cf968`). **Changing the hash re-buckets every user**, which ends every running experiment. Treat it as frozen.

The **second salt for the variant** is deliberate: enrolment and arm selection are independent, so raising `exposure` from 10 to 50 pulls in new users without moving anyone already in a variant. With a single hash, every ramp reshuffles the arms and the data before the ramp becomes unusable.

## What this does NOT protect against

- **A flag is not authorization.** The feature's code is in the binary and the flag value is client-side. A modified client turns anything on. Gate entitlements, prices, limits and roles on the server; the flag decides only what the UI offers.
- **Neither is a kill switch.** It stops well-behaved clients from *calling* the broken thing. It does not stop a patched client from calling it. If an endpoint must stop serving traffic, turn it off at the endpoint.
- **A flag value is not a secret.** It is plaintext `SharedPreferences`, readable via `adb backup` on a device where backup is allowed, and visible in the response body. Never put a key, token or price-calculation rule in a flag.
- **Overrides are a dev tool.** They are ignored under `kReleaseMode` — but that is one bool (`FeatureFlagService.allowOverrides`), not a security control. Do not treat "release ignores overrides" as a guarantee against a modified build.
- **`rollout` and `exposure` are enforced on the client.** The client computes its own bucket, so a modified client can enrol itself. For a rollout that genuinely must be server-authoritative, have the backend send that user's resolved value and omit `rollout` entirely.
- **Bucketing is stable per id, not per human.** Signed-out users bucket on a per-install id: clearing app data, reinstalling, or using a second device is a new bucket. Signed-in users are stable across devices — which is why `setUserId` must get the server's id, not a device id.
- **`hash % 100` gives 1% granularity, and the split is approximate.** With three variants the 0–99 space divides 34/33/33, and small populations show real skew. The shipped test allows 850–1150 enrolled out of 2000 at 50%. This is a rollout mechanism, not a statistics engine — significance testing belongs in your analytics tool.
- **This module does not log exposures.** It resolves a variant; it does not tell your analytics that the user saw it. Nothing here measures anything on its own.
- **No polling, no streaming.** One fetch per `refresh()`. There is no long-lived connection, so a flag change reaches an already-running app only when you call `refresh()` again.
- **No targeting rules.** The client sends `user_id` (plus whatever you put in `FeatureFlagService.requestParams`) and the backend decides. There is no client-side rule engine for country, app version or cohort — deliberately: rule evaluation on the client is another thing a modified client can lie about.

## Notes and gotchas

- **Registration order.** `FeatureFlagService` must be registered before anything reads it. `Get.putAsync` in `bootstrap()` guarantees that for screens; for code that can run earlier, use `Flags.*`, which degrades to the default rather than throwing `"FeatureFlagService not found"`.
- **`init()` schedules the fetch in `addPostFrameCallback`.** In a widget test that never pumps a frame, the fetch simply never runs. Pass `fetchAfterFirstFrame: false` in tests to be explicit.
- **`refresh()` catches `Error`, not just `Exception`,** on purpose: `ApiService.get` dereferences `Get.context!` when offline, and an `Env` key missing from `.env` throws. Both would otherwise escape as an unhandled async error.
- **`refresh()` is single-flight.** A second call while one is in flight returns `false` immediately instead of stacking requests.
- **Install `api_resilience` and the flag fetch gets dedup, jittered retries and the circuit breaker for free** — it is a plain `GET`, so it is idempotent and retryable by that module's rules.
- **`FeatureFlagStore` caches the `SharedPreferences` instance.** A second `SharedPreferences.setMockInitialValues(...)` in the same test file has no effect on it. Seed through `FeatureFlagStore.setRawDocument(...)` instead; `test/unit/feature_flags_test.dart` shows the helper.
- **Module-owned cache keys.** Everything lives under the `feature_flags.` prefix in the shared `SharedPreferences` box, so no edit to `CacheManager` is needed. `CacheManager.removeAll()` on logout therefore also wipes the cached document, overrides and the anonymous id — the next launch starts from hardcoded defaults and a fresh bucket. If that matters, re-write the document after the wipe, or clear only what you mean to.
- **Deleting a flag from `FeatureFlags` leaves it in the backend document.** Harmless: unknown keys are kept in the map and simply never read. Removing it from the backend while the app still reads it is also safe — it falls back to the hardcoded default.
- **`documentVersion` is yours to use.** Surfacing it in a support screen turns "which config did this user have?" into one glance.
- **The debug screen lives next to the service, not under `lib/app/feature/`.** That is deliberate: `test/guardrails/bindings_test.dart` requires every `*Controller` under `feature/` to be registered in `ViewModelBinding`, and QA tooling should not force an edit to a core file. It is the one place this module departs from the house feature layout.
- Run the tests with `flutter test test/unit/feature_flags_test.dart` — 37 tests, no network, no sleeping.

## Why it is not in core

Most projects starting from this template have no flag backend, and a flag system with nothing serving it is worse than none: it adds a service to register, a document contract to honour, and a cache to reason about, in exchange for an endpoint that 404s on every launch.

It also forces two decisions core should not make for you. One is where the document comes from — this module assumes **your** API, which is the right default here, but Firebase Remote Config or LaunchDarkly are legitimate answers with different wiring. The other is the failure policy: `KillSwitch` defaults to *enabled* when there is no cache, and that is a product judgement, not a framework one.

And the honest reason: a flag system is only as good as the discipline around it. Flags that are never deleted become permanent untested branches, and gated code that ships in the binary looks like a security boundary to the next person reading it. That deserves an explicit opt-in, not a default.
