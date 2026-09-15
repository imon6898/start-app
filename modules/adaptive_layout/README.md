# adaptive_layout

Phone, tablet, foldable and desktop from one widget tree. Material window size classes, an `AdaptiveScaffold` that renders a bottom bar, a navigation rail or a pinned-open drawer from the **same** destination list, a `MasterDetailView` that stacks on a phone and splits on a tablet — with the back button working on both — hinge-aware splitting read out of `MediaQuery.displayFeatures`, and a grid whose column count comes from how wide a tile should be rather than a number you guessed.

**Read this first.** This module does not replace `R`. `lib/app/utils/responsive_utils.dart` already derives its scale from the live `MediaQuery` and already knows `R.isTablet`. `R` answers *"how big should this box be"*; this module answers *"which layout should I build"*. Those are different questions and they need different numbers — see [Why breakpoints are not R-scaled](#why-breakpoints-are-not-r-scaled). No `flutter_screenutil`, no second scaling system, no `ScreenUtilInit`.

And the real accessibility bar is not the tablet. It is a phone at **200% font scale**, which is a supported OS setting on both platforms. Text scaling is a first-class input to every decision here — see [Text scaling is the actual bar](#text-scaling-is-the-actual-bar).

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/widgets/layout/adaptive_breakpoints.dart` | `WindowSizeClass` (compact / medium / expanded), `AdaptiveBreakpoints` (the table + `widthClass` / `heightClass`), `WindowInfo` (one snapshot: size, both classes, orientation, text scale, display features), `context.windowInfo`. |
| `lib/app/widgets/layout/adaptive_hinge.dart` | `HingeInfo` — a fold or hinge parsed out of `MediaQuery.displayFeatures` — and `HingeAwareSplit`, two panes seamed on the hinge when there is one. |
| `lib/app/widgets/layout/adaptive_scaffold.dart` | `AdaptiveScaffold`, `AdaptiveDestination`, `AdaptiveNavigationStyle`, `AdaptiveScaffoldScope` (exposes how much chrome sits left of the body). |
| `lib/app/widgets/layout/master_detail_view.dart` | `MasterDetailView<T>`, `MasterDetailScope`, `AdaptiveDetailBackButton`. |
| `lib/app/widgets/layout/adaptive_grid.dart` | `AdaptiveGrid` — target tile width, not a column count. |
| `lib/app/widgets/layout/adaptive_layout.dart` | Barrel for all five. |
| `test/unit/adaptive_layout_test.dart` | 28 tests: every breakpoint boundary, the navigation-style matrix, the split rule including the 200%-text case, hinge parsing, column maths. |
| `test/widget/adaptive_layout_widget_test.dart` | 9 tests: the three renderings at four window sizes, stacked detail + back, **the Android system back gesture**, both panes on expanded, the seam landing on a simulated Surface-Duo hinge, and the grid regaining columns as the window grows. |

## Install

```bash
dart run tool/add_module.dart adaptive_layout
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
cp modules/adaptive_layout/lib/app/widgets/layout/adaptive_breakpoints.dart lib/app/widgets/layout/
cp modules/adaptive_layout/lib/app/widgets/layout/adaptive_hinge.dart       lib/app/widgets/layout/
cp modules/adaptive_layout/lib/app/widgets/layout/adaptive_scaffold.dart    lib/app/widgets/layout/
cp modules/adaptive_layout/lib/app/widgets/layout/master_detail_view.dart   lib/app/widgets/layout/
cp modules/adaptive_layout/lib/app/widgets/layout/adaptive_grid.dart        lib/app/widgets/layout/
cp modules/adaptive_layout/lib/app/widgets/layout/adaptive_layout.dart      lib/app/widgets/layout/
cp modules/adaptive_layout/test/unit/adaptive_layout_test.dart              test/unit/
cp modules/adaptive_layout/test/widget/adaptive_layout_widget_test.dart     test/widget/
```

### pubspec.yaml

Nothing to add:

```yaml
# flutter, get and lucide_icons_flutter are already in the template core.
```

### Platform config

None. No native code, no permissions, no manifest entries, no `.env` keys.

Foldable and desktop information arrives through `MediaQuery`, which Flutter already populates: display features come from Jetpack WindowManager on Android, and window resizing works out of the box on macOS, Windows, Linux and web. Nothing to enable.

## Wiring

**The module compiles and its tests pass with zero core edits.** Both items below are optional.

**1. Optional — the widget barrel.** Everything can be imported directly:

```dart
import 'package:flutter_starter/app/widgets/layout/adaptive_layout.dart';
```

To reach it through `package:flutter_starter/app/widgets/widgets.dart` instead, add one line to `lib/app/widgets/layout/layout.dart`:

```dart
export 'adaptive_layout.dart';
```

**2. Required only when you use `AdaptiveScaffold` — the destination labels.** `AdaptiveDestination.label` is a **translation key**; the bar, the rail and the drawer each call `.tr` on it. Add your keys to `lib/app/localization/locales/en_us.dart` and to every other locale file:

```dart
  'Home': 'Home',
  'Search': 'Search',
  'Profile': 'Profile',
```

`test/guardrails/localization_test.dart` enforces both directions — a `.tr` with no entry fails, and an entry nothing calls fails. The module itself ships **zero** translated string literals, so installing it on its own does not touch localization at all.

Nothing goes in `bootstrap.dart`, `ViewModelBinding`, `AppRoutes` or `AppPages`. There is no service to register and no route to add.

## Usage

### The window size class

```dart
final WindowInfo window = context.windowInfo;

if (window.widthClass.isExpanded) { … }

// One value per class; medium falls back to compact, expanded to medium.
final int columns = window.widthClass.pick(compact: 1, medium: 2, expanded: 4);

// Without a BuildContext — from a controller, like the rest of R:
if (AdaptiveBreakpoints.current.isCompact) { … }
```

| Class | Width | Typical |
| --- | --- | --- |
| `compact` | `< 600` | phone portrait, small split-screen |
| `medium` | `600 – 839` | phone landscape, small tablet, tablet split view |
| `expanded` | `>= 840` | tablet, desktop, unfolded foldable |

`AdaptiveBreakpoints.heightClass` uses the same enum against `480 / 900`, which is how a short landscape phone gets a rail instead of a bottom bar that eats the little height it has.

### AdaptiveScaffold — one API, three renderings

```dart
class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ShellController>(
      builder: (controller) {
        return Obx(
          () => AdaptiveScaffold(
            selectedIndex: controller.tabIndex.value,
            onDestinationSelected: controller.setTab,
            destinations: const [
              AdaptiveDestination(icon: LucideIcons.house, label: 'Home'),
              AdaptiveDestination(icon: LucideIcons.inbox, label: 'Inbox'),
              AdaptiveDestination(icon: LucideIcons.user, label: 'Profile'),
            ],
            // Keeps each tab's scroll position; the rail/drawer swap does not reset it.
            body: IndexedStack(
              index: controller.tabIndex.value,
              children: controller.tabs,
            ),
          ),
        );
      },
    );
  }
}
```

| Window | Rendering |
| --- | --- |
| compact | `NavigationBar` at the bottom |
| compact **and** short (`height < 480`) | `NavigationRail` — a bottom bar would take the last of the height |
| medium | `NavigationRail`, labels under the icons |
| expanded | `NavigationDrawer` pinned open beside the body |
| expanded + `useDrawerOnExpanded: false` | extended `NavigationRail` (icon + label in a row) |

`leading` / `trailing` put a logo, a search field or a FAB above and below the destinations in the rail and the drawer. They are not rendered on compact, where there is nowhere sensible to put them. `drawer` and `endDrawer` pass straight through to the `Scaffold`, for a modal sheet of *secondary* items that never belongs in the primary list.

Colors come from `CustomColors.navbar()`, `CustomColors.navbarSelected()`, `CustomColors.primary()` and `CustomColors.textGray()`, wired through `NavigationBarTheme`, `NavigationDrawerTheme` and the rail's own theme parameters, so all three renderings match the app instead of the default Material palette.

### MasterDetailView — stacked on a phone, side by side on a tablet

```dart
MasterDetailView<Order>(
  masterBuilder: (context, onSelect, selected) => Scaffold(
    appBar: AppBar(title: Text('Orders'.tr)),
    body: ListView.builder(
      itemCount: controller.orders.length,
      itemBuilder: (context, i) {
        final order = controller.orders[i];
        return ListTile(
          title: Text(order.code ?? ''),
          selected: order == selected,           // highlight what the pane shows
          onTap: () => onSelect(order),
        );
      },
    ),
  ),
  detailBuilder: (context, order, onClose) => Scaffold(
    appBar: AppBar(
      // Renders nothing when the detail is already beside the list.
      leading: const AdaptiveDetailBackButton(),
      title: Text(order.code ?? ''),
    ),
    body: OrderDetailBody(order: order),
  ),
  placeholderBuilder: (context) => Center(
    child: Text('Select an order'.tr, style: CustomTextStyles.regular14),
  ),
  onSelectionChanged: controller.setSelectedOrder,
)
```

- **Compact** — the master is a page, the detail is pushed on top of it on a **nested `Navigator`**. The iOS swipe-back and the Android back button both pop the detail and leave the screen alone. `NavigatorPopHandler` is what routes the system pop into the nested navigator instead of the root one; there is a test asserting exactly that. (Android's *predictive* back will not animate the nested pop — `NavigatorPopHandler` holds `canPop: false` on the outer route while the detail is up, which is the documented Flutter trade-off. The pop itself is correct.)
- **Expanded** — both panes, seamed on the hinge if there is one, `placeholderBuilder` in the right pane until something is selected. `onClose` is `null` here and `AdaptiveDetailBackButton` renders as empty space, because there is nothing to go back to.
- **Build each pane as its own `Scaffold`.** On compact it becomes a real page and needs the `AppBar` and the `Material` ancestor. Debug mode will tell you off (`ListTile background color or ink splashes may be invisible`) if you skip it.

Back navigation from inside a detail pane must **not** use `Get.back()` — see [Limitations](#limitations-and-caveats).

### Foldables

`HingeAwareSplit` is the piece underneath `MasterDetailView`, usable on its own for any two-pane layout:

```dart
HingeAwareSplit(
  startFraction: 0.4,                                  // used only when there is no hinge
  startMin: 320,                                       // logical px clamps on the fallback
  gap: 16,                                             // raw Figma px, scaled with R.w
  separator: ColoredBox(color: CustomColors.stroke()),
  viewOffset: AdaptiveScaffoldScope.navigationInsetOf(context),
  start: const OrdersList(),
  end: const OrderDetail(),
)
```

What it does, exactly:

- Reads `MediaQuery.displayFeaturesOf(context)` and keeps the first `hinge` or `fold` that **spans the window**. A `cutout` is ignored — it punches a hole, it does not divide the layout. A feature that stops short of both edges is a notch, not a divider.
- A feature taller than it is wide runs vertically and splits the screen left/right (`splitsSideBySide`); a wider one splits top/bottom.
- The seam is placed on the hinge, so the physical gap falls **between** the panes and no content, and no tap target, lands on it. A `fold` with zero thickness still gets a 1px separator (when you pass one, which `MasterDetailView` does by default), because a crease is exactly where a divider belongs.
- `viewOffset` maps the hinge rect (reported in *view* coordinates) into local ones. Inside an `AdaptiveScaffold` this is automatic: `MasterDetailView` reads `AdaptiveScaffoldScope.navigationInset`, so a rail or drawer to the left does not throw the seam off by its width.
- If honouring the hinge would leave either pane under 20% of the box, the hinge is ignored. A 60px sliver is worse than pretending the hardware isn't there.

For single-pane content that should sit on *one* screen of a dual-screen device, Flutter already ships the right widget — use it rather than this one:

```dart
DisplayFeatureSubScreen(child: const OnboardingCard())
```

### AdaptiveGrid — a target tile width, not a column count

```dart
AdaptiveGrid(
  itemCount: controller.products.length,
  targetTileWidth: 180,          // raw Figma px; column count is derived
  spacing: 12,                   // raw Figma px
  tileHeight: 220,               // prefer this over aspectRatio
  maxColumns: 6,                 // stop a 4K window from making 20 columns
  padding: R.pad(all: 16),
  itemBuilder: (context, i) => ProductCard(product: controller.products[i]),
)
```

Columns are `round((width + spacing) / (target + spacing))` — **rounded, not floored**, so a 380px window with a 180px target gives 2 columns of 184 rather than 1 of 380. `minColumns` / `maxColumns` clamp it. `columnsFor` is static and tested if you need the number for something else:

```dart
final int columns = AdaptiveGrid.columnsFor(
  width: 1200, targetTileWidth: 180, spacing: 12, maxColumns: 6,
);
```

Use `tileHeight` rather than `aspectRatio`. A fixed aspect ratio plus a large font scale is the classic grid overflow: the tile cannot grow, so the text clips. `tileHeight` is a real height, and it grows with the text scale.

## Text scaling is the actual bar

A layout that survives a tablet is easy. A layout that survives **200% font size on a phone** is the accessibility bar, and it is a supported OS setting: Android *Display size and text*, iOS *Larger Text* / Accessibility sizes. `WindowInfo.textScale` is the honest number — `textScaler.scale(16) / 16`, not the deprecated `textScaleFactor` — and every component reacts to it:

| Component | At `textScale >= 1.3` |
| --- | --- |
| `AdaptiveScaffold` bottom bar | labels hide (`NavigationDestinationLabelBehavior.alwaysHide`), tooltips stay, so screen readers and long-press still name every tab. Override with `labelBehavior:`. |
| `AdaptiveScaffold` rail | drops to `NavigationRailLabelType.none`; the rail is `scrollable: true` in every mode, so many destinations plus big text scrolls instead of overflowing. |
| `MasterDetailView` | needs `minPaneWidth * 2 * textScale` (capped at 1.5x) before it splits. A 900px tablet at 200% correctly falls back to **stacked** — one readable column beats two unreadable ones. |
| `AdaptiveGrid` | the target tile widens with the text scale, so columns drop and each tile has room for its label; `tileHeight` grows with it too. |

Test it in one line, no device and no OS settings:

```dart
await tester.pumpWidget(
  MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
    child: GetMaterialApp(home: MyScreen()),
  ),
);
```

Or on a running app, from DevTools: the Flutter inspector has a **text scale** slider, and `flutter run` accepts nothing for this — use the slider or the platform setting.

## How to test this without owning a tablet or a foldable

**1. Resize a desktop window.** The fastest loop by far, and it exercises every breakpoint continuously:

```bash
flutter run -d macos     # or -d windows, -d linux, -d chrome
```

Then drag the window edge from 400px to 1400px and watch the bottom bar become a rail become a drawer. Nothing else reproduces the *transition* this honestly. `flutter run -d chrome` plus the browser's device toolbar is the same trick with preset device sizes.

**2. Resize the view from a widget test.** This is what `test/widget/adaptive_layout_widget_test.dart` does — no emulator at all:

```dart
tester.view
  ..devicePixelRatio = 1.0
  ..physicalSize = const Size(1200, 900);
addTearDown(tester.view.reset);
```

Resizing `tester.view` rather than wrapping in a fake `MediaQuery` matters: `R` and `CustomColors` resolve through `Get.context`, so a hand-rolled `MediaQuery` further down would leave them looking at the old size.

**3. Fake a foldable, also in a widget test.** A Surface Duo is a 1114x705 window with a 34px hinge at x=540:

```dart
tester.view.displayFeatures = const <ui.DisplayFeature>[
  ui.DisplayFeature(
    bounds: Rect.fromLTRB(540, 0, 574, 705),
    type: ui.DisplayFeatureType.hinge,
    state: ui.DisplayFeatureState.postureFlat,
  ),
];
addTearDown(tester.view.reset);
```

A Galaxy Fold is a zero-width `fold` instead: `Rect.fromLTRB(442, 0, 442, 705)` with `DisplayFeatureType.fold`.

**4. Android emulator foldable profiles.** The AVD manager ships *7.6" Fold-in with outer display*, *8" Fold-out* and *Resizable (Experimental)*. The Resizable AVD has phone / unfolded / tablet presets you can switch live from the emulator toolbar, and it reports real display features. This is the only option in this list that exercises the actual Jetpack WindowManager path.

**5. Android split-screen.** Any two-app split gives you a genuine `medium` or `compact` window with a *short* height, on hardware you already have. It is the cheapest way to catch a layout that assumed portrait.

`device_preview` also works and needs no core wiring (wrap `GetMaterialApp` in its builder), but it is a package this module deliberately does not add — it fakes `MediaQuery` inside one real window, so it shows you sizes, not the platform's own display features or text scale.

## Why breakpoints are not R-scaled

`R.w(600)` is not 600. `R` multiplies by `width / 375` (clamped per device bucket), which is exactly what you want for a box drawn on a 375px Figma canvas and exactly what you must not do to a breakpoint: the threshold would move with the window it is measuring, and `width >= R.w(600)` is a different question at every width. `AdaptiveBreakpoints.mediumWidth` is a plain `600`, straight from Material, compared against raw logical pixels.

Rail and drawer widths are the one middle case. They are Material component metrics (72 / 256 / 360), not Figma units, so they are scaled with `R.w()` and then **clamped**: rail 72–112, drawer 280–360, extended rail 256–320. Unclamped, `R.w(72)` reaches 130 on a desktop window, which is a sidebar, not a rail. Pass `railWidth` / `drawerWidth` (logical pixels) to override.

Everything else in the module — padding, icon sizes, separators, gaps, tile sizes — goes through `R` like the rest of the codebase, and `gap` / `targetTileWidth` / `tileHeight` / `spacing` all take **raw Figma pixels** exactly like `R.pad()` does.

## Limitations and caveats

- **`Get.back()` does not work from inside a stacked detail pane.** `MasterDetailView` uses a nested `Navigator` on compact; `Get.back()` talks to the *root* GetX navigator and would pop the whole screen. Use `AdaptiveDetailBackButton`, the `onClose` callback, or `Navigator.of(context).pop()`. The system back gesture and the Android back button are handled correctly — that is what `NavigatorPopHandler` is for, and there is a test for it.
- **Crossing the split boundary rebuilds the detail.** Rotating a tablet from stacked to side-by-side destroys the nested `Navigator` and rebuilds the detail in the pane. The *selection* survives; scroll offset and un-submitted form state inside the detail do not. Put anything worth keeping in the controller, which is the house rule anyway.
- **`WindowSizeClass` has three values, Material now has five.** Material's newer guidance splits expanded into expanded / large / extra-large at 1200 / 1600. `WindowInfo.isLargeScreen` and `AdaptiveBreakpoints.largeWidth` expose the 1200 line without adding enum values you would have to handle everywhere. If you need genuinely different layouts above 1600, add the case yourself.
- **`HingeAwareSplit` assumes it is laid out at a known horizontal offset.** It maps the hinge from view coordinates using `viewOffset`, which `MasterDetailView` fills in from `AdaptiveScaffoldScope`. Nest it inside your own horizontal padding, a `Center`, or a `SafeArea` with left inset and the seam is off by that amount — pass the extra offset yourself, or put the padding *inside* each pane.
- **A pinned-open drawer plus a dual-screen device is a bad combination.** The drawer eats into the first screen, leaving a narrow master pane. On a foldable, prefer `useDrawerOnExpanded: false` (a 72px rail) or put the navigation inside the first pane.
- **`AdaptiveGrid` does not avoid the hinge.** Tiles are laid out across the whole box; one can straddle a hinge. Wrap two grids in a `HingeAwareSplit` if that matters, or use `DisplayFeatureSubScreen` to keep the grid on one screen.
- **Only vertical hinges drive `HingeAwareSplit`.** A horizontal fold (tabletop posture) falls back to the fraction split; the module does not currently offer a top/bottom variant. `HingeInfo` reports the axis, so you can branch on it yourself.
- **Display features are only as good as the platform.** Android reports them via Jetpack WindowManager; iOS, desktop and web report none, so every foldable path is simply inert there. `DisplayFeatureState` is also only `postureFlat` / `postureHalfOpened` / `unknown` — there is no "closed", and no hinge *angle*.
- **`NavigationBar`, not `BottomNavigationBar`.** The Material 3 component, which is what the adaptive guidance specifies and what gives per-state theming and `labelBehavior`. If you need the Material 2 look, it is a one-widget swap inside `_bottomBar`.
- **3–5 destinations on compact.** `NavigationBar` has no overflow behaviour; a sixth destination just gets thinner. Seven items are fine in a rail or drawer and wrong in a bottom bar — put the extras in a modal `drawer` or a "More" tab.
- **The body is yours.** `AdaptiveScaffold` does not manage the tab content, so nothing is preserved across a destination change unless you pass an `IndexedStack` (or keep the state in controllers). That is deliberate: guessing at state preservation is worse than not doing it.
- **It does not make a phone layout good on a desktop.** A single 1400px-wide column with one form field per row is *responsive* and still terrible. This module gives you the hooks; deciding that a desktop layout wants two columns of content is still design work.

## Notes and gotchas

- `WindowInfo.of(context)` subscribes to `size`, `orientation`, `textScaler` and `displayFeatures` only — via `MediaQuery.sizeOf` and friends, not `MediaQuery.of` — so an opening keyboard (`viewInsets`) does not rebuild the whole layout.
- Every rule is a pure static function: `AdaptiveBreakpoints.widthClass`, `AdaptiveScaffold.resolveStyle`, `MasterDetailView.shouldSplit`, `AdaptiveGrid.columnsFor`, `HingeInfo.fromFeatures`. That is why 28 of the 37 tests need no widget tree, no device and no fake `MediaQuery`.
- `AdaptiveScaffold.selectedIndex` is clamped internally, so shrinking the destination list at runtime cannot throw the `NavigationBar` assertion.
- `MasterDetailView<T>` requires `T extends Object` (so `T?` can mean "nothing selected") and compares selections with `==`. Give your model a real `==`/`hashCode`, or pass an id.
- `AdaptiveDestination.label` is passed through `.tr`. GetX returns the key when there is no translation, so an already-translated string is harmless — but keys are the intent.
- `AdaptiveScaffoldScope.navigationInsetOf(context)` returns `0` outside an `AdaptiveScaffold`, so `HingeAwareSplit` and `MasterDetailView` work standalone.
- Run the tests with `flutter test test/unit/adaptive_layout_test.dart test/widget/adaptive_layout_widget_test.dart`. No network, no goldens, no platform channels, nothing to mock.

## Why it is not in core

Most projects that start from this template ship a phone app, and `R` plus `R.isTablet` already covers "make it not look broken on an iPad". What this module adds is a *different layout per size class* — three navigation renderings, a two-pane view with its own nested `Navigator`, and a hinge parser — and every one of those is a decision that has to be understood before it is trusted: a nested navigator changes what `Get.back()` means, a split view changes what "the screen" is, and a bottom bar that silently becomes a drawer will surprise anyone who did not install this on purpose.

It also has a real cost in the other direction. Once a screen is an `AdaptiveScaffold` with a `MasterDetailView`, it has to be tested at four window sizes instead of one. That is the right trade for a product that genuinely targets tablets and desktop, and pure overhead for one that does not. The core stays a phone-shaped starter with a good scaling helper; this is the opt-in for when the product grows a second form factor.
