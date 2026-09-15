# design_system

A real design-token layer for the template, plus a debug-only component catalog — a storybook with no `widgetbook` dependency.

**It extends the existing helpers; it does not replace them.** `CustomColors`, `CustomTextStyles` and `R` stay exactly as they are, and every widget in `lib/app/widgets/` keeps working untouched. What this module adds is the layer the template is missing: **named** spacing, radius, elevation, motion and semantic colour roles, generated from a single `tokens.json` so a Figma Variables export can drive them, reachable both statically (`DsSpace.lg`) and through `Theme.of(context)` (`context.ds`).

The catalog is the payoff. Without it, "we have a design system" is a claim about a folder. With it, you open one screen and see all 28 widgets rendering live, and you can flip light/dark, text scale and locale on top of them.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/themes/tokens/tokens.json` | **The source of truth.** 11 token groups. Not a Flutter asset, never read at runtime — codegen input only. |
| `tool/gen_tokens.dart` | `dart run tool/gen_tokens.dart` regenerates the Dart. `--check` fails when stale. Dependency-free (`dart:io` + `dart:convert`). |
| `lib/app/themes/tokens/design_tokens.dart` | **Generated.** `DsSpace`, `DsRadius`, `DsBorderWidth`, `DsOpacity`, `DsIconSize`, `DsElevation`, `DsDuration`, `DsCurve`, `DsMotion`, `DsRole`, `DsPalette`, `DsTokenMeta`. |
| `lib/app/themes/tokens/token_types.dart` | Hand-written value types the generated file instantiates: `DsColorToken` (light/dark pair), `DsShadowToken`, `DsMotionToken`. |
| `lib/app/themes/tokens/ds_resolve.dart` | `DsBrightness` plus the `.value` extensions that resolve a token for the *active* theme. |
| `lib/app/themes/tokens/ds_tokens_theme.dart` | `DsTokens extends ThemeExtension<DsTokens>` and the `context.ds` getter, with a fallback when the wiring step is skipped. |
| `lib/app/themes/tokens/tokens.dart` | Barrel — `import '.../app/themes/tokens/tokens.dart';` gets the whole layer. |
| `lib/app/themes/ds_theme.dart` | `DsTheme.withTokens(base)` / `.light` / `.dark` — attaches `DsTokens` to an existing `ThemeData` without rewriting anything else. |
| `lib/app/feature/catalog/…` | The catalog feature: `CatalogRoutes`, `CatalogEntry`, `CatalogController`, `CatalogRegistry` (28 entries), `CatalogScreen`, `CatalogTokensView`, `CatalogCase`, `CatalogToolbar`. |
| `test/guardrails/design_tokens_test.dart` | 8 tests: the generated file is regenerated in-memory and compared, aliases resolve, curves exist, motion references are live, names are Dart identifiers, scales ascend, hex is well-formed. |
| `test/guardrails/catalog_coverage_test.dart` | 3 tests: every public widget under `lib/app/widgets/` is catalogued, and every catalogued source path exists. |
| `test/widget/ds_tokens_test.dart` | 7 tests: the `ThemeExtension` round-trip, the fallback, unknown-name defaults, extension merging. |
| `test/widget/catalog_screen_test.dart` | 5 tests: all 28 demos build with no exception, the token gallery renders, search recovers. |

## Install

```bash
dart run tool/add_module.dart design_system
flutter pub get
```

Manual equivalent — copy each path in `module.yaml > files` to the same path in the project:

```bash
mkdir -p lib/app/themes/tokens \
         lib/app/feature/catalog/{catalog_controllers,catalog_models,catalog_presentation/catalog_widgets}
cp -R modules/design_system/lib/app/themes/tokens/.   lib/app/themes/tokens/
cp    modules/design_system/lib/app/themes/ds_theme.dart lib/app/themes/
cp -R modules/design_system/lib/app/feature/catalog/.  lib/app/feature/catalog/
cp    modules/design_system/tool/gen_tokens.dart       tool/
cp    modules/design_system/test/guardrails/*.dart     test/guardrails/
cp    modules/design_system/test/widget/*.dart         test/widget/
```

### pubspec.yaml

Nothing to add:

```yaml
# flutter, get and lucide_icons_flutter are already in the template core.
# tokens.json is NOT an asset — do not add it under `assets:`.
```

### Platform config

None. No native code, no permissions, no `.env` keys, no new bundled assets.

## Wiring

The **token layer needs no wiring at all** — `DsSpace.lg`, `DsRole.accent()` and `DsElevation.low.value` work the moment the files land. Steps 1 and 2 are only for the catalog screen; step 3 is optional.

### 1. `lib/app/bindings/view_model_binding.dart` — required for the catalog

Add the import next to the other feature-controller imports:

```dart
import '../feature/catalog/catalog_controllers/catalog_controller.dart';
```

and one line inside `dependencies()`:

```dart
    // Catalog (debug only; registration is lazy, so it costs nothing in release)
    _lazy<CatalogController>(() => CatalogController());
```

Not optional. `test/guardrails/bindings_test.dart` requires every `*Controller` under `lib/app/feature/` to appear in `ViewModelBinding`, and it does not care that the screen is debug-only.

### 2. `lib/app/routes/app_pages.dart` — required for the catalog

Add the imports:

```dart
import 'package:flutter/foundation.dart';
import '../feature/catalog/catalog_presentation/catalog_screen.dart';
import '../feature/catalog/catalog_route.dart';
```

and one entry at the end of `AppPages.pages`, inside the list literal:

```dart
    // Debug-only storybook; the collection-if drops it from release builds.
    if (kDebugMode)
      _page(CatalogRoutes.CatalogScreen, () => const CatalogScreen()),
```

**`app_routes.dart` is not touched.** The route name lives in `CatalogRoutes` (`lib/app/feature/catalog/catalog_route.dart`), so `test/guardrails/routes_test.dart` — which pairs every `AppRoutes` constant with a `GetPage` — stays green without a new constant, and a release build has no dangling route.

### 3. `lib/app/app.dart` — optional, for `Theme.of(context)` access

Add the import:

```dart
import 'themes/ds_theme.dart';
```

and wrap the two existing theme lines inside `GetMaterialApp`:

```dart
        theme: DsTheme.withTokens(AppTheme.lightTheme),
        darkTheme: DsTheme.withTokens(AppTheme.darkTheme),
```

Use `withTokens(...)` rather than `DsTheme.light` / `DsTheme.dark`: it keeps the `AppTheme` import in use, so `unused_import` (an **error** in this repo's `analysis_options.yaml`) does not fire. `DsTheme.light` / `.dark` exist for projects that reference `AppTheme` elsewhere in the file.

Skipping this step costs nothing measurable: `context.ds` falls back to the static token set for the ambient brightness, so no call site breaks.

### 4. Opening the catalog

From anywhere in debug — a long-press on a logo, a hidden gesture in a settings screen, a dev menu:

```dart
if (kDebugMode) Get.toNamed(CatalogRoutes.CatalogScreen);
```

## Usage

### Tokens, statically

```dart
import 'package:flutter_starter/app/themes/tokens/tokens.dart';

Container(
  // Raw Figma px straight into R.pad — it scales internally.
  padding: R.pad(all: DsSpace.lg),
  margin: R.margin(horizontal: DsSpace.md, bottom: DsSpace.sm),
  decoration: BoxDecoration(
    color: DsRole.surface(),                      // alias of CustomColors.card()
    borderRadius: BorderRadius.circular(R.r(DsRadius.lg)),
    border: Border.all(
      color: DsRole.borderSubtle(),
      width: DsBorderWidth.thin,                  // NOT scaled, on purpose
    ),
    boxShadow: DsElevation.low.value,             // .value resolves per theme
  ),
  child: Icon(LucideIcons.check, size: R.w(DsIconSize.md), color: DsRole.accent()),
);
```

### Motion

```dart
AnimatedContainer(
  duration: DsMotion.reveal.duration,
  curve: DsMotion.reveal.curve,
  height: R.h(expanded ? 180 : 0),
);

// Or the pieces separately.
AnimatedOpacity(duration: DsDuration.fast, curve: DsCurve.standard, opacity: 1);
```

### Tokens, through the theme

```dart
final ds = context.ds;                            // DsTokens for this subtree

Padding(
  padding: R.pad(all: ds.space('lg')),
  child: ColoredBox(color: ds.color('focusRing')),
);
```

`context.ds` is the escape hatch for code that must not hard-code a token name (a themed `switch`, a widget driven by a server-supplied style key) and for per-theme overrides:

```dart
theme: DsTheme.withTokens(AppTheme.lightTheme).copyWith(
  extensions: [DsTokens.of(Brightness.light).copyWith(spacing: compactSpacing)],
),
```

Unknown names return a documented default rather than throwing: `space` → `DsSpace.md`, `corner` → `DsRadius.md`, `duration` → `DsDuration.normal`, `color` → fully transparent.

### Adding a token

1. Add it to `lib/app/themes/tokens/tokens.json`. Names must be `lowerCamelCase` — a Figma export that emits `Space / MD` or `space-2x` is rejected with the offending name.

   ```jsonc
   "spacing": { …, "xxxl": 48, "gutter": 20 },

   // A role backed by an existing CustomColors method: the hex stays in
   // app_colors.dart, so dark mode keeps working and the brand is in one place.
   "colorAlias": { …, "chipSurface": "gray2" },

   // A role the core palette has no method for: explicit light/dark hex.
   "colorRole": { …, "overlayGlow": { "light": "#FFFFFF", "dark": "#1F1F1F" } }
   ```

2. Regenerate:

   ```bash
   dart run tool/gen_tokens.dart
   ```

3. Use it: `DsSpace.gutter`, `DsRole.chipSurface()`, `DsPalette.overlayGlow.value`.

That is the whole loop. `DsSpace.all`, `DsRole.all` … are regenerated too, so the token gallery in the catalog picks up the new entry with no further edits.

In CI:

```bash
dart run tool/gen_tokens.dart --check   # exits 1 when design_tokens.dart is stale
```

`test/guardrails/design_tokens_test.dart` does the same thing inside `flutter test`, so you get it for free.

The generator fails loudly and specifically:

```
ERROR: colorAlias.bogus: CustomColors has no noSuchMethod() method.
Add it to app_colors.dart, or declare the role under "colorRole" with an
explicit light/dark hex pair.

ERROR: curve.oops: "easeInOutQuintic" is not a known const Curves entry.
Allowed: linear, decelerate, ease, easeIn, easeOut, easeInOut, easeOutCubic,
easeInOutCubic, easeInOutCubicEmphasized, fastOutSlowIn, bounceOut, elasticOut

ERROR: Token name "Space MD" is not lowerCamelCase — rename it in tokens.json
```

### Adding a component to the catalog

One entry in `CatalogRegistry.entries` (`lib/app/feature/catalog/catalog_presentation/catalog_registry.dart`):

```dart
    CatalogEntry(
      name: 'MyWidget',                                    // exact class name
      group: _layout,                                      // an existing group const
      source: 'lib/app/widgets/layout/my_widget.dart',      // checked on disk by a test
      note: 'The one gotcha a reader needs before using it.', // optional
      demo: (context) => MyWidget(title: 'Sample', onTap: () {}),
    ),
```

Rules that keep the catalog honest:

- **`name` must match the class or function name exactly.** `catalog_coverage_test.dart` greps for `name: 'MyWidget'`, so a typo reads as "not catalogued".
- **Give the demo real content, not `Placeholder()`.** The point is to see the widget as it ships.
- **Demo state goes on `CatalogController`**, never in the registry. It already owns the `TextEditingController`s, the selection lists, the picked date and file, and a `PaginationHelper` primed with six fake rows — all disposed in `onClose()`.
- **Let demos shrink-wrap.** Use the `_fit(…)` helper (a `Row` with `MainAxisSize.min`) for a button rather than guessing a `SizedBox` width; a guessed width overflows the moment the text scale moves.
- **Anything that opens a dialog, sheet or snackbar gets a trigger button**, not a rendered copy — a modal cannot live inside a list.

Adding a widget to `lib/app/widgets/` without a `CatalogEntry` **fails the test suite**. That is deliberate; see [Limitations](#limitations-and-caveats).

## The catalog, exactly

Two tabs, one toolbar.

**Components** — 28 entries grouped by the folder they live in (App bar, Buttons, Feedback, Inputs, Layout, Media, Pagination). Each is a card with the class name, the installed source path, an optional gotcha, and the live widget on a sunken surface so padding and shadows read. Search filters on name, group and path; the group chips toggle.

**Tokens** — every group of `tokens.json` rendered as the thing it controls: colour swatches with resolved hex, spacing bars, radius corners, elevation cards with real shadows, motion rows you tap to replay, opacity steps, border rules, icon sizes. It reads `DsSpace.all`, `DsRole.all`, `DsMotion.all` … so a new token appears with no edit to the view.

**Three toggles.** Two are global, one is local, and the difference is not a design choice:

| Toggle | Scope | Why |
| --- | --- | --- |
| Light / Dark | **Global** — drives `ThemeController` | `CustomColors` resolves through `Get.find<ThemeController>()`, not `Theme.of(context)`. A local `Theme` override would repaint Material widgets and leave every `CustomColors.*()` call unchanged. |
| Locale | **Global** — `Get.updateLocale` | `.tr` resolves against `Get.locale`. A local `Localizations` override does not reach it. |
| Text scale ×1.0 / 1.3 / 1.6 / 2.0 | **Local** — a `MediaQuery` `textScaler` override | Text scaling *is* a `MediaQuery` concern, so this one can be scoped to the preview. |

`CatalogController` records the theme mode and locale in `onInit()` and restores them in `onClose()`, so popping the catalog leaves the app exactly as the user had it. The locale switch goes through `Get.updateLocale` rather than `AppTranslations.setLocale`, so it is **not** persisted; the theme switch does go through `ThemeController.changeTheme`, which writes to `CacheManager`, and the restore writes it back.

### What the text-scale toggle finds

Turn it to 2.0× and seven demos overflow:

| Widget | Why |
| --- | --- |
| `CustomButton` | `height: 34` is a fixed default and the label/icon `Row` has no flex. |
| `CustomOutlinedButton` | same, plus `width` defaults to `double.infinity`. |
| `CustomSnackBar` | fixed horizontal padding around an unbounded title/description `Row`. |
| `StatusBadge` | `height: 26` fixed; the label is `medium12` scaled up. |
| `DatePickerButton` | hardcodes `fontSize: 16` and `height: 45` — it never went through `R`. |
| `showCustomSnackBar` / `showCustomBottomSheet` triggers | a 2× button label is simply wider than 375 px. |

**That is the module working, not failing.** Those are pre-existing bugs in the widget kit that nothing in the repo surfaced before. The shipped smoke test therefore runs at the default text scale and asserts "builds with no exception"; asserting "no overflow at 2.0×" would just have meant deleting the finding.

## Design decisions worth knowing

**Two kinds of colour token, on purpose.** `colorAlias` points a semantic role at an existing `CustomColors` method — `"surface": "card"` generates `DsRole.surface() => CustomColors.card()`. The hex is never copied, so `app_colors.dart` stays the single place a brand colour is written and dark mode keeps working through `ThemeController`. `colorRole` carries an explicit light/dark pair, for roles the core palette has no method for (focus ring, scrim, skeleton shimmer) — those generate a `const DsColorToken`, resolved with `.value`.

**Raw px in, scaled px out.** Spacing, radius and icon sizes are **raw Figma px**. Pass them to `R.pad` / `R.margin` as-is (`R.pad(all: DsSpace.lg)`) and wrap them in `R.h()` / `R.w()` / `R.r()` anywhere else. Nothing here writes `R.pad(horizontal: R.w(...))`, which double-scales and which `test/guardrails/responsive_test.dart` forbids. Border widths are deliberately **not** scaled: a scaled 0.5 px hairline disappears on some devices.

**Shadows are always black.** `DsShadowToken` resolves its colour to `Color(0xFF000000)` with a per-theme alpha, never `CustomColors.black()` — that method inverts in dark mode and would paint a white shadow.

**`DsTheme.withTokens` is additive.** It does not rewrite `colorScheme` or `textTheme`, because `CustomColors` and `CustomTextStyles` remain the source of truth for every widget in the kit. Rewriting `colorScheme` would give you two competing palettes. It also strips any existing `DsTokens` before adding the new one, so calling it twice is safe.

**`ThemeExtension<dynamic>` cannot be written as a literal element type.** `ThemeExtension<T extends ThemeExtension<T>>` is F-bounded, and `<ThemeExtension<dynamic>>[...]` is rejected by the CFE (`flutter analyze` does *not* catch it — only a compile or `flutter test` does). `ds_theme.dart` omits the type argument and lets inference do the work. If you write your own extension-merging helper, do the same.

## Limitations and caveats

- **Side-by-side light/dark is impossible** without rewriting `CustomColors`. Because colours resolve through a global `ThemeController` rather than the widget tree, the only honest light/dark control is a global toggle. Two previews of the same widget in different themes on one screen would both render in the active theme. Same for locale.
- **The theme toggle persists while you are in the catalog.** `ThemeController.changeTheme` writes to `CacheManager`, so a crash or a force-quit inside the catalog leaves the app in the theme you last selected. `onClose()` restores it on a normal pop.
- **The catalog's own chrome is untranslated English.** It is developer copy. `test/guardrails/localization_test.dart` requires every `.tr` literal in `lib/` to have an `en_US` entry **and** every `en_US` entry to be used by something — so translating the storybook would push ~20 catalog-only strings into `en_us.dart` and `bn_bd.dart` and keep them there forever. The widget *demos* still show real translated copy, because the locale toggle switches the whole app. If you want the chrome translated anyway, add `.tr` and the matching entries to every file in `lib/app/localization/locales/`.
- **A new widget in `lib/app/widgets/` fails the build until it is catalogued.** `catalog_coverage_test.dart` is strict by design — a storybook that silently drifts out of date is worse than no storybook. The cost is real when you install another UI module (`adaptive_layout` alone adds six widgets to `lib/app/widgets/layout/`; also `extra_widgets`, `media_viewer`, `html_view`, `webview`, `api_resilience`'s banner): add a `CatalogEntry` for each of its widgets, or delete that one test file.
- **`DsTokens.lerp` snaps the scales.** Colours interpolate; spacing, radius and durations jump at `t = 0.5`. Interpolating a spacing scale mid-animation would reflow the whole screen for no benefit. The practical consequence: reading `context.ds` *during* a `MaterialApp` theme transition can return the outgoing token set for the first half of the animation. `test/widget/ds_tokens_test.dart` pumps a bare `Theme` rather than a `MaterialApp` for exactly this reason.
- **`DsTokens` does not override `==`.** It holds maps, so equality would be O(n) on every `ThemeData` comparison. The instances handed to `ThemeData` are cached per brightness, so identity comparison is correct in practice — but a `copyWith`-ed instance rebuilt every frame would defeat `ThemeData`'s change detection. Build it once.
- **`tokens.json` is not a Figma export format.** It is a small, readable schema that a Figma Variables export can be *mapped onto*; nothing here talks to the Figma API. Writing that mapping is a ~50-line script against `tool/gen_tokens.dart`'s input shape, and it is not included.
- **The generated file is not `dart format`-idempotent by construction.** It happens to match the formatter today and `flutter analyze` is clean, but if you change an emitter, run `dart format` on the output and diff before committing, or a formatter hook will fight the generator.
- **`DsRole.*()` needs a registered `ThemeController`.** Like every `CustomColors` call, it falls back to `Theme.of(Get.context!)` and then throws if neither exists. Do not call it from a pure unit test or before `bootstrap()`; `test/widget/ds_tokens_test.dart` covers the `ThemeExtension` path instead, which has no such dependency.
- **The catalog does not replace a golden test.** It shows you a widget; it does not assert what it looked like yesterday. Overflow, contrast and spacing regressions are still found by a human opening the screen.
- **`DsTokenMeta.version` is whatever `tokens.json` says.** Nothing enforces that you bump it. It exists so the token gallery can show the reader which revision they are looking at.

## Notes and gotchas

- Run just this module's tests: `flutter test test/guardrails/design_tokens_test.dart test/guardrails/catalog_coverage_test.dart test/widget/ds_tokens_test.dart test/widget/catalog_screen_test.dart`.
- `design_tokens_test.dart` imports the generator with a relative path (`import '../../tool/gen_tokens.dart';`) because `tool/` is outside `lib/` and has no `package:` URI. That is legal and intentional — the test regenerates and compares, so a hand edit to the generated file fails the suite instead of surviving to the next run.
- The catalog screen is `StatelessWidget` + `GetBuilder<CatalogController>` with `Obx` around only the reactive slices, per the house convention. The two `StatefulWidget`s in the module (`_MotionSample` in the token gallery) exist for a local tap-to-replay flag the controller has no business owning.
- `PaginationView` and `PaginationGridView` share one `PaginationHelper<String>` on the controller, set up with a fake fetcher that returns six rows. No network, no backend.
- `FileUploadWidget`'s demo opens the **real** system file picker on a device. `CustomCountryPicker` and `CustomSelectSection` open real overlays. These are live widgets, not screenshots.
- The route constant is `CatalogRoutes.CatalogScreen`, intentionally `PascalCase` to match the pinned `AppRoutes` style; the file opts out of `constant_identifier_names` with a one-line `ignore_for_file`, the same way `app_routes.dart` does.
- Verified on Flutter 3.44.8 / Dart 3.12.2: installed with `dart run tool/add_module.dart design_system` into a clean checkout, the three wiring steps applied verbatim, then `flutter analyze` → **0 issues** and `flutter test` → **68 tests passing** (45 core + 23 added). `dart run tool/gen_tokens.dart --check` → up to date.

## Why it is not in core

Three reasons, in order of weight.

**The catalog must not ship in a release build.** It imports every widget in the kit and builds 28 live demos; in `lib/` it would be tree-shake-resistant dead weight in every app built from the template, and a `Get.toNamed('/catalogScreen')` away from being reachable in production. Behind `if (kDebugMode)` in a module, it is opt-in, and a project that never installs it never pays for it.

**Tokens are a commitment, and the template is deliberately uncommitted.** `CustomColors` + `CustomTextStyles` + `R` are the pinned contract shared across the user's projects; they are intentionally a flat bag of helpers so any project can use them however it likes. A token layer imposes opinions — that spacing comes from a 9-step scale, that elevation is four recipes, that a card is `DsRole.surface()` and not `CustomColors.card()`. Those opinions are right for a project with a designer and a Figma file, and pure overhead for a three-screen internal tool. Forcing them on every clone would make the template less reusable, not more.

**Codegen in core means a build step in core.** `design_tokens.dart` has to be regenerated whenever `tokens.json` changes, and a stale generated file is a real failure mode. That is a cost worth paying deliberately — with a `--check` in CI and a guardrail test — and not worth inflicting on someone who cloned the template to ship one screen.

The core stays a lean, unopinionated baseline. This module is what you install the day the project gets a design system worth the name.
