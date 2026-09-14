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

| Module | What it does | Packages it adds | Platform config? |
|---|---|---|---|
| **extra_widgets** | Six alternate UI widgets: overlay single/multi-select dropdowns, dependency-free paginated grid, loading overlay, list-state indicator, empty-state view. | none | No |
| **html_view** | `AppHtmlView` — renders HTML strings as widgets: theme-aware colors, tappable tel/mailto/sms/web links, WhatsApp-style markdown, auto-linkify, Scripture/USFM styling, HTML→text utils. | `flutter_html`, `html_unescape`, `google_fonts`, `url_launcher` | Yes — `url_launcher` queries/schemes |
| **location_picker** | Google Places autocomplete + Google Map with a centre pin as the selected point, plus GPS/permission/IP location services. | `geolocator`, `permission_handler`, `google_maps_flutter`, `google_places_flutter`, `geocoding` | Yes — Maps API key, location permissions |
| **media_viewer** | Fullscreen image/video gallery + inline thumbnail. Pinch/double-tap zoom, custom video player with double-tap seek and scrubbable progress. Network, file and asset sources. | `cached_network_image`, `video_player` | Yes — INTERNET, cleartext/ATS for http |
| **multi_step_onboarding** | *Reference module.* Rider + merchant registration wizards: PageView step machine, per-step validation, multipart upload, cascading location dropdowns, Repo/Impl API split. Copy the structure, replace the fields. | `image_picker`, `file_picker`, `pinput`, `intl`, `permission_handler`, `lucide_icons_flutter`, `flutter_svg`, `shared_preferences` | Yes — camera/photo permissions, API endpoints |
| **rich_text_editor** | `CustomQuilTextField` — themed WYSIWYG form field with optional heading, configurable toolbar, bordered editor box. | `flutter_quill` | No |
| **webview** | `CustomWebView` in-app browser: progress bar, title/host app bar, nav bottom bar, share, open externally, copy link, tel/mailto/sms handoff. | `flutter_inappwebview`, `share_plus`, `url_launcher` | Yes — INTERNET, `url_launcher` queries/schemes |

Every module has its own `README.md` with the full API, usage examples and the verbatim manifest /
plist snippets. Read it after installing.

### Notes on combinations

- `multi_step_onboarding` needs `CustomDropdownButton`, which ships inside **extra_widgets** —
  install that first. Its map step needs **location_picker** (optional).
- `html_view` opens web links in the external browser by default. Install **webview** and set
  `AppHtmlView.webViewOpener = CustomWebView.open` at startup to open them in-app instead.
- Modules assume the template's core files exist (`app_colors.dart`, `app_fonts.dart`,
  `responsive_utils.dart`, …). The installer prints the exact list per module; if you're dropping a
  module into a different project, copy those first.

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
3. **Write the README with copy-pasteable snippets** — manifest blocks, plist keys, a usage example.
   Future-you will not remember the setup.
4. **Verify before committing:**
   ```bash
   dart run tool/add_module.dart                     # your module appears in the list
   dart run tool/add_module.dart <your_module> --dry-run
   ```

The parser in `tool/add_module.dart` is a small YAML subset (nested maps, `-` lists, `|` and `>`
block scalars, inline `{}`). Keep the manifest plain and it will parse.
