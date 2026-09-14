# extra_widgets

Alternate/duplicate UI widgets removed from the template core: overlay dropdowns, a paginated grid, a loading overlay, a list-state indicator, and an empty-state view.

## Install

One command:

```bash
dart run tool/add_module.dart extra_widgets
```

Manual:

1. Copy the files you want from `modules/extra_widgets/lib/` into `lib/app/widgets/`.
2. Nothing to add to `pubspec.yaml` — see below.
3. Run `flutter analyze`.

Each file is independent. Copy only what you need.

## Dependencies

None beyond what the template already ships. Every file imports only `package:flutter/material.dart` plus template core (`app_colors.dart`, `app_fonts.dart`, `responsive_utils.dart`, `enums.dart`, `custom_image.dart`).

`empty_data_view.dart` uses `CustomImage`, which relies on dependencies already in the template:

```yaml
  cached_network_image: ^4.0.0
  flutter_svg: ^2.3.0
```

## Platform config

None. No permissions, keys, or native setup.

## Files

| File | Widget | Notes |
| --- | --- | --- |
| `custom_dropdown_button.dart` | `CustomDropdownButton` | Single-select overlay dropdown, optional local or API search |
| `custom_multi_select_dropdown.dart` | `CustomMultiSelectDropdown` | Multi-select overlay dropdown with search + infinite scroll |
| `paginated_list_view.dart` | `PaginatedGridView<T>` | Self-contained grid with load-more and pull-to-refresh |
| `loading_overlay.dart` | `LoadingOverlay` | Swaps child for a spinner when `isLoading` |
| `my_indicator.dart` | `MyIndicator`, `IndicatorStatus` | Loading / error / empty / no-more-load states for lists |
| `empty_data_view.dart` | `EmptyDataView` | Centered image + title + subtitle empty state |

## Usage

```dart
// Single-select with search
CustomDropdownButton(
  labelText: "Country",
  isRequired: true,
  valueText: selectedCountry,
  itemList: countries,
  showSearch: true,
  validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
  onChange: (v) => setState(() => selectedCountry = v),
)

// Multi-select with paged search
CustomMultiSelectDropdown(
  labelText: "Skills",
  itemList: skills,
  selectedItems: picked,
  isSearchRequired: true,
  hasMore: controller.hasMore,
  isLoadingMore: controller.isLoadingMore,
  onChangedSearch: controller.search,
  onScrollEnd: controller.loadMore,
  onItemToggle: (s) => setState(() =>
      picked.contains(s) ? picked.remove(s) : picked.add(s)),
)

// Paginated grid
PaginatedGridView<Product>(
  items: controller.items,
  hasMore: controller.hasMore,
  isLoading: controller.isLoading,
  onLoadMore: controller.loadMore,
  onRefresh: controller.refreshAll,
  itemBuilder: (context, item) => ProductCard(item),
)

// List state
MyIndicator(
  controller.items.isEmpty ? IndicatorStatus.empty : IndicatorStatus.none,
  tryAgain: controller.refreshAll,
  emptyWidget: const EmptyDataView(
    title: "Nothing here yet",
    subtitle: "Pull down to refresh",
  ),
)

// Loading overlay
LoadingOverlay(isLoading: controller.isLoading, child: MyForm())
```

## Why it is not in core

Each one duplicates a widget the core already ships — `CustomSelectSection` covers both dropdowns, `PaginationView` + `PaginationHelper` cover the grid and list states, and skeleton loaders cover the overlay — so the core keeps one implementation of each.

## When you would want it back

- **`custom_dropdown_button` / `custom_multi_select_dropdown`** — you need a `List<String>` API instead of core's `Map<T, String>`, or you need the popup to render in an `Overlay` (so it can escape a clipped/scrolling parent and flip above the field when the keyboard opens). Core's `CustomSelectSection` uses a bottom sheet.
- **`paginated_list_view`** — you want pagination with zero extra packages. Core's `PaginationView` pulls in `lazy_load_scrollview` and `skeletonizer`, and requires a `PaginationHelper`.
- **`loading_overlay`** — simplest possible gate; core prefers skeletonizer placeholders.
- **`my_indicator`** — sliver-aware footer/full-screen states for a hand-rolled `CustomScrollView`.
- **`empty_data_view`** — a standalone empty state you can drop anywhere, not tied to a pagination helper.

---

## Note: `own_icon_icons.dart` is intentionally not shipped

The original `OwnIcon` class was a Fontello/FlutterIcon custom icon font. It is **not** included here because:

1. The `OwnIcon.ttf` font file does not exist anywhere in this repo, so the class would render nothing but blank boxes.
2. All 13 glyphs are delivery-domain (vehicle types, rider documents, payout methods) and have no place in a generic starter.

Use `lucide_icons_flutter` (`^3.1.19`, already a template dependency) instead:

```dart
import 'package:lucide_icons_flutter/lucide_icons.dart';

Icon(LucideIcons.bike, size: 24)
```

| Old `OwnIcon` glyph | Replacement |
| --- | --- |
| `OwnIcon.bicycle` | `LucideIcons.bike` |
| `OwnIcon.private_car` | `LucideIcons.car` |
| `OwnIcon.bike` (motorcycle) | `LucideIcons.motorbike` |
| `OwnIcon.scooter` | `LucideIcons.scooter` |
| `OwnIcon.check_mark` | `LucideIcons.check` |
| `OwnIcon.driving_licence` | `LucideIcons.idCard` |
| `OwnIcon.chash` (cash) | `LucideIcons.banknote` |
| `OwnIcon.online_walet` | `LucideIcons.wallet` |
| `OwnIcon.documents` | `LucideIcons.files` |
| `OwnIcon.email` | `LucideIcons.mail` |
| `OwnIcon.location` | `LucideIcons.mapPin` |
| `OwnIcon.phone` | `LucideIcons.phone` |
| `OwnIcon.edit` | `LucideIcons.pencil` |

If you genuinely need the original font back, recover it with `git show b860a8e:lib/app/widgets/own_icon_icons.dart` and source the matching `.ttf` from fluttericon.com.
