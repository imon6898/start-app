# golden_tests

The test infrastructure almost nobody ships: **golden (screenshot) tests** for the shared widget kit across a phone/tablet × light/dark × 1×/2× text-scale matrix, a real **end-to-end integration test** that boots the app on a device and walks splash → sign-in, and a **network-free mock + fixture kit** so a controller or repo can be tested without a socket.

It adds **no golden-test package**. Neither `golden_toolkit` nor `alchemist` is in this machine's pub cache — their APIs could not be verified, and both would be a dependency for behaviour `flutter_test` already has. The harness is `matchesGoldenFile` plus ~90 lines of helper.

**Read this first.** Goldens are platform-specific rasterisations. A PNG written on macOS will not match one written on a Linux CI runner — different font hinting, different anti-aliasing — and the failure looks like a bug in your code when it is only a difference in machines. This module files goldens per OS (`test/golden/goldens/<os>/`) so the two sets never fight. See [CI](#ci) and pick a policy before you turn this on.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `test/golden/golden_harness.dart` | `loadAppFonts()`, `GoldenScenario` + the matrix, `pumpGolden()`, `goldenMatrixTest()`, `expectGolden()`, `TolerantGoldenComparator`. |
| `test/golden/flutter_test_config.dart` | Runs before every test **in `test/golden/` only**: loads fonts, optionally installs the tolerant comparator. |
| `test/golden/buttons_golden_test.dart` | `CustomButton` — default, disabled, loading, secondary. |
| `test/golden/inputs_golden_test.dart` | `CustomTextField` — empty, filled, password, disabled, validation error. |
| `test/golden/feedback_golden_test.dart` | `StatusBadge` (all six tones), `StripedProgressBar`, `ThinkingDots`. |
| `test/helpers/test_bootstrap.dart` | `initTestApp()` — the `bootstrap()` sequence a test needs, with seedable `SharedPreferences`. |
| `test/helpers/mock_api_service.dart` | `MockAuthApiService`, `MockApiService`, `apiResponse()`, `apiError()`, `registerApiFallbacks()`. |
| `test/helpers/fixtures.dart` | `fixtureJson()` / `fixtureString()` / `fixtureJsonList()`. |
| `test/fixtures/login_{success,unverified,error}.json` | Real-shaped login envelopes for `BaseResponse<LoginData>`. |
| `test/unit/auth_fixture_test.dart` | 6 tests proving the kit works: fixtures parse into the real models, a mocked `AuthApiService` answers with no network. |
| `integration_test/app_boot_flow_test.dart` | 3 tests on a real device: splash → sign-in, splash → onboarding, sign-in validation blocks submit. |
| `tool/update_goldens.sh` | Regenerates the goldens for the current OS and tells you to look at them. |

**46 golden tests + 6 unit tests + 3 device tests**, on top of the 45 the template already has.

## Install

```bash
dart run tool/add_module.dart golden_tests
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
mkdir -p test/golden test/helpers test/fixtures test/unit integration_test tool
cp modules/golden_tests/test/golden/*.dart          test/golden/
cp modules/golden_tests/test/helpers/*.dart         test/helpers/
cp modules/golden_tests/test/fixtures/*.json        test/fixtures/
cp modules/golden_tests/test/unit/*.dart            test/unit/
cp modules/golden_tests/integration_test/*.dart     integration_test/
cp modules/golden_tests/tool/update_goldens.sh      tool/
```

### pubspec.yaml

These are **dev** dependencies. `add_module.dart` only writes to the `dependencies:` block, so add them yourself:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mocktail: ^1.0.5

  flutter_lints: ^6.0.0
```

`integration_test` ships with the Flutter SDK — no version, no download. Then:

```bash
flutter pub get
chmod +x tool/update_goldens.sh
```

### Platform config

None for the golden tests — they are pure `flutter test`, no native code, no permissions, no `.env` key of their own.

The **integration test** needs a connected device or emulator. It builds and installs a debug APK/IPA, so the usual Android/iOS toolchain must already work:

```bash
flutter devices                                                   # confirm a target
flutter test integration_test/app_boot_flow_test.dart             # picks the only device
flutter test integration_test/app_boot_flow_test.dart -d <id>     # pick explicitly
```

Plain `flutter test` **skips** `integration_test/` — it only walks `test/`. That is deliberate: your normal test run stays a two-second VM run.

### .gitignore

Failure diffs are generated, not source. Add:

```gitignore
test/golden/**/failures/
```

Do **not** ignore `test/golden/goldens/` — the baselines are the point.

## Wiring

**Nothing in `lib/` has to change.** Every file lands under `test/`, `integration_test/` or `tool/`, no route, no binding, no service.

One thing is worth doing, and it is a one-liner.

### Optional: make a Repo mockable

`AuthRepo` hardcodes its implementation, so a test cannot swap in a mock:

```dart
class AuthRepo {
  final AuthApiService authApiService = AuthImpl();   // ← not injectable
```

In `lib/app/feature/auth/auth_logic/auth_api_service.dart`, replace that line with:

```dart
class AuthRepo {
  AuthRepo({AuthApiService? api}) : authApiService = api ?? AuthImpl();

  final AuthApiService authApiService;
```

Every existing call site (`AuthRepo()`) keeps working — the parameter is optional and defaults to the real `AuthImpl`. With it, a controller test can do:

```dart
final repo = AuthRepo(api: MockAuthApiService());
```

Apply the same two lines to any other feature's Repo you want to test. Without them, the mock kit is still useful — you just drive the abstract `*ApiService` directly, as `test/unit/auth_fixture_test.dart` does.

### Optional: tolerant comparison

Set an environment variable; nothing to edit:

```bash
GOLDEN_TOLERANCE=0.5 flutter test test/golden    # allow 0.5% of pixels to differ
```

Unset — the default — is flutter's exact pixel compare. See [the caveat](#tolerance-is-a-band-aid).

## Usage

### Adding a golden for your own widget

```dart
// test/golden/orders_golden_test.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/feature/orders/orders_presentation/order_card.dart';

import 'golden_harness.dart';

void main() {
  goldenMatrixTest(
    'order_card',
    () => SizedBox(width: R.w(320), child: OrderCard(order: fakeOrder)),
  );
}
```

That is six tests and six PNGs — one per matrix row. `flutter test --update-goldens test/golden` writes them; from then on `flutter test` compares.

**The subject is a closure, not a widget.** `CustomTextStyles`, `CustomColors.*()` and `R.*` all read live state (the active `ThemeController`, the live `MediaQuery`). Building eagerly would bake in the phone scale and the light palette for every row.

### The matrix

| Row | Size | Brightness | Text scale |
| --- | --- | --- | --- |
| `phone_light` | 375 × 812 | light | 1.0 |
| `phone_dark` | 375 × 812 | dark | 1.0 |
| `phone_text_2x` | 375 × 812 | light | 2.0 |
| `tablet_light` | 834 × 1112 | light | 1.0 |
| `tablet_dark` | 834 × 1112 | dark | 1.0 |
| `tablet_text_2x` | 834 × 1112 | light | 2.0 |

375 × 812 is the Figma size `R` derives its scale from, so `phone_light` is the design reference; the tablet rows exercise `R`'s `clamp(0.9, 1.6)` tablet branch.

Use `kPhoneOnlyMatrix` where a tablet render adds nothing, or write your own:

```dart
goldenMatrixTest('order_card', builder, matrix: kPhoneOnlyMatrix);

goldenMatrixTest(
  'order_card',
  builder,
  matrix: const [
    GoldenScenario(name: 'small_phone', size: Size(320, 568)),
    GoldenScenario(name: 'huge_text', textScale: 3.0),
  ],
);
```

Every row is a PNG in the repo forever. Six rows × twenty widgets is 120 images that a padding change invalidates at once. Be stingy.

### A one-off golden with setup

`goldenMatrixTest` covers the common case. When a state needs a few taps first, use `pumpGolden` + `expectGolden` directly:

```dart
testWidgets('order_card_expanded — phone_light', (tester) async {
  await pumpGolden(
    tester,
    () => OrderCard(order: fakeOrder),
    scenario: const GoldenScenario(name: 'phone_light'),
  );

  await tester.tap(find.byType(OrderCard));
  await tester.pumpAndSettle();

  await expectGolden('order_card_expanded_phone_light');
});
```

### Animated widgets

`pumpAndSettle` never returns for an `AnimationController` that `repeat()`s. Pass `settle: false` and a fixed slice is pumped instead:

```dart
goldenMatrixTest('thinking_dots', () => const ThinkingDots(), settle: false);
goldenMatrixTest('spinner', builder, settle: false, pumpFor: const Duration(milliseconds: 120));
```

It is deterministic under `flutter test` — the automated binding runs on fake time, so the same pump always lands on the same frame.

### Testing without a network

```dart
import '../helpers/fixtures.dart';
import '../helpers/mock_api_service.dart';

void main() {
  setUpAll(registerApiFallbacks);

  test('signIn parses the login envelope', () async {
    final api = MockAuthApiService();
    when(() => api.postSignin(any(), any()))
        .thenAnswer((_) async => apiResponse(fixtureJson('login_success.json')));

    final repo = AuthRepo(api: api);               // needs the optional wiring above
    final data = await repo.postLoginRepo({'identifier': 'a@b.c', 'password': 'x'});

    expect(data['data']['access_token'], 'fixture-access-token');
    verify(() => api.postSignin(ApiConstant.loginUri, any())).called(1);
  });
}
```

Error branches:

```dart
when(() => api.postSignin(any(), any()))
    .thenThrow(apiError(statusCode: 401, body: fixtureJson('login_error.json')));

when(() => api.postSignin(any(), any()))
    .thenThrow(apiError(type: DioExceptionType.connectionTimeout));
```

### Booting the real app in a test

```dart
await initTestApp(prefs: const {'hasSeenOnboarding': true});
await tester.pumpWidget(const App());
```

`initTestApp` runs the same steps as `bootstrap()`, in the same order — `SharedPreferences` mock, `Env.load()`, `CacheManager.init()`, `ViewModelBinding().dependencies()` — minus the orientation lock and the `IpLocationService` preload. Seed `prefs` to choose the branch splash takes:

| `prefs` | Splash goes to |
| --- | --- |
| `{}` | `OnboardingScreen` |
| `{'hasSeenOnboarding': true}` | `SigninScreen` |
| `{'token': '…', 'userData': '{…}'}` | `DashboardScreen` |

Keys are the `CacheKeys` enum names; `setMockInitialValues` adds the `flutter.` prefix itself.

## CI

**Goldens must be generated and compared on the same OS.** Nothing else about this is negotiable.

```yaml
# .github/workflows/test.yml
jobs:
  test:
    # Match whatever OS wrote test/golden/goldens/. macos-latest if that is where
    # you run tool/update_goldens.sh. Changing this line breaks every golden.
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.8'
          channel: stable
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test                       # unit + widget + guardrails + goldens

      # Goldens that failed leave diff images behind — upload them or you are
      # debugging a pixel count with no picture.
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: golden-failures
          path: test/golden/**/failures/
```

Three workable policies, in order of preference:

1. **One OS.** Generate on the same OS the CI uses. Simplest, and the only one with no duplication. If your team is on macOS and CI is on Linux, run `tool/update_goldens.sh` inside a Linux container.
2. **Two sets.** Commit `goldens/macos/` *and* `goldens/linux/`, each generated on its own machine. Honest, but every visual change has to be regenerated twice or CI fails on the half nobody updated.
3. **Skip goldens in CI.** `flutter test test/unit test/widget test/guardrails`. Cheap, and gives up the only thing this module is for.

The per-OS directory layout means a wrong-platform run fails with *"Could not be compared against non-existent file: goldens/linux/…"* — an obviously-missing baseline — instead of a pixel diff that reads like a real regression.

**Do not run `--update-goldens` in CI.** It cannot fail: it overwrites the baseline with whatever the code currently renders, so the check silently becomes a no-op.

## What the matrix caught immediately

The first `tool/update_goldens.sh` run on this template produced `custom_button_default_phone_text_2x.png`, in which the word "Sign In" is **visibly clipped top and bottom**. `CustomButton` sizes itself with `SizedBox(height: R.h(34))`, which does not grow with the OS text-scale setting, so at the 2× accessibility scale the label does not fit.

That is not a bug this module introduced. It is a real accessibility defect that had been in the widget the whole time, invisible to every `expect(find.text(...), findsOneWidget)` assertion — the text *is* there, it is just unreadable. Fixing it is out of scope here (it means giving `CustomButton` a `minHeight` constraint instead of a fixed `height`); catching it is the entire argument for golden tests.

## Notes and gotchas

### `loadAppFonts()` — the classic one

`flutter test` boots the engine with only the placeholder **FlutterTest** font registered. Every `TextStyle(fontFamily: 'Inter')` — which is *every* `CustomTextStyles` entry — and every Lucide or Material glyph falls back to it and renders as a **filled box**. A golden written that way is a picture of rectangles; it still passes, it just tests nothing about your typography.

`loadAppFonts()` reads `FontManifest.json` out of the test asset bundle (`flutter test` generates one at `build/unit_test_assets/`) and `FontLoader`s every family in it. Package fonts keep their `packages/<pkg>/<Family>` prefix, because that is the exact string `TextStyle.fontFamily` will ask for; the handful of engine-overridable families (`Roboto`, `.SF UI Text`, …) keep their bare name. `flutter_test_config.dart` calls it once per test file, so you never call it yourself — but if you copy `pumpGolden` into a suite outside `test/golden/`, you must.

Symptom to recognise: **boxes instead of letters** in the generated PNG.

### There is no HTTP seam below the Repo

`AuthImpl` constructs `ApiService()` inline, and `ApiService.get/post` start with `checkInternet()`, which does a live `InternetAddress.lookup('google.com')`. Neither can be intercepted from a test. So:

- Mock the abstract **`<Name>ApiService`**, which is the real seam. `MockAuthApiService` is the template.
- `MockApiService` is included for completeness, but it only helps where an `ApiService` is *injected* rather than constructed — nothing in the template does that today.
- A test that reaches `ApiService` will do real DNS, be slow, and behave differently on a plane. Treat that as a bug in the test.

### Scoped test config

`test/golden/flutter_test_config.dart` applies to `test/golden/` and below only — `flutter_tools` walks up from each test file to the first `flutter_test_config.dart` it finds, stopping at `pubspec.yaml`. The template's existing 45 tests are untouched and keep stock exact-compare behaviour. Moving that file to `test/` would apply font loading (and the tolerance knob) to everything.

### Tolerance is a band-aid

`GOLDEN_TOLERANCE=0.5` allows 0.5% of pixels to differ. It exists so a CI image upgrade that shifts anti-aliasing by a hair does not block a release. It is **not** a fix for cross-platform goldens: the phone_light image here differs from its dark counterpart by 99.8% of pixels, but a genuine one-pixel padding regression can be well under 0.5% — tolerance hides exactly the class of bug you installed this for. Use it temporarily, with a reason, and take it back out.

### `R` and the first frame

`R` reads `MediaQuery.of(Get.context!)`, and `Get.context` is null until the first frame is up — before that it falls back to the 375 × 812 Figma size. `pumpGolden` pumps, then marks `GoldenSurface` dirty and pumps again, so the subject is built a second time against the real MediaQuery. Without that, every tablet golden would be laid out at phone scale. If you write your own pump helper, keep the second pump.

### Other things worth knowing

- **The module ships no `.png` files.** The first run has nothing to compare against — generate the baseline with `tool/update_goldens.sh` and *look at every image* before committing. A baseline committed unreviewed locks in whatever was broken that day.
- **`matchesGoldenFile` rasterises at pixel ratio 1.0** regardless of `tester.view.devicePixelRatio`, so there is no DPR row in the matrix — it would produce a byte-identical PNG. Verified: two such rows hashed the same.
- **Goldens capture the whole device frame**, not just the widget, because that is what catches a layout regression. Expect a lot of empty background in each image.
- **`GoldenScenario.textScale` uses `TextScaler.linear`.** That is linear scaling, not the non-linear curve newer Android/iOS apply at large sizes, so 2.0 here is a close approximation of the OS setting, not an exact reproduction.
- **`integration_test` runs on the device's real clock.** `tester.pump(Duration(seconds: 3))` in `app_boot_flow_test.dart` really waits three seconds — the live binding does not fake time the way `flutter test` does. Keep device tests few.
- **`integration_test/` imports `../test/helpers/test_bootstrap.dart` relatively.** Files under `test/` are not reachable via `package:flutter_starter/…`, so there is no alternative. If you move either directory, fix that import.
- **`Get.reset()` runs before and after every golden.** If you register singletons a widget needs, do it inside the test after `pumpGolden`, not in `setUpAll`.
- **Adding a font to `pubspec.yaml` changes every golden**, because `loadAppFonts` registers whatever the manifest lists. That is correct, but budget for the regeneration.
- Run one file at a time while iterating: `flutter test test/golden/buttons_golden_test.dart`.

## What this does NOT give you

- **It is not a design review.** A golden proves the render did not *change*; it says nothing about whether it was right to begin with. Review the baseline images by eye, once, properly.
- **It does not test behaviour.** A widget can be pixel-perfect and completely dead. Keep the `expect(taps, 1)` style tests in `test/widget/`.
- **It does not catch platform-specific rendering bugs.** Every golden here is rendered by the host machine's Skia/Impeller, not by an Android or iOS device. A font that falls back differently on a real phone will not show up.
- **It will not survive a Flutter upgrade unchanged.** Engine text-layout changes move pixels. A minor-version bump routinely invalidates a whole golden suite; that is the maintenance cost, and it is real.
- **The three device tests are a smoke test, not coverage.** They prove the app boots, routes and validates. They do not prove a feature works.
- **Nothing here mocks the platform.** `initTestApp` mocks `SharedPreferences` only. A widget that touches another plugin channel still needs its own `setMockMethodCallHandler`.

## Why it is not in core

A golden suite is a maintenance commitment, not a free safety net. Every committed PNG is a file that a padding tweak, a font swap, a theme change or a Flutter upgrade invalidates — and a team that has not agreed to regenerate and *review* those images will start passing `--update-goldens` reflexively, at which point the suite is worse than nothing because it looks like coverage.

It also forces a decision the template has no business making for you: which OS is the reference, and what CI runs on. Get that wrong and every build fails for cosmetic reasons until someone deletes the tests.

So the core template ships the 45 tests that cost nothing to keep green, and this module ships the 55 that are worth it once a project has a UI it cares about not changing by accident.
