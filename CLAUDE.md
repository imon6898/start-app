# CLAUDE.md — instructions for AI agents in this repo

This is `flutter_starter`: a reusable Flutter 3.44.x + GetX **starter template** that gets cloned to
begin new projects. Optimise for a clean, conventional, copy-pasteable baseline — not for clever code.

Read [ARCHITECTURE.md](ARCHITECTURE.md) before changing anything under `lib/`.
The full scaffolding recipe lives in the user's global skill: `~/.claude/skills/getx-feature/SKILL.md`.
Invoke it (`getx-feature`) whenever you add or refactor a feature, screen, controller or API service.

---

## Hard rules

1. **`flutter analyze` must stay at 0 errors.** Verify before you say you're done.
2. **Run `flutter test`** too. Both, every time, no exceptions.
3. **Never rename or move a pinned file or class** (table below).
4. **Never change the Style-A Repo contract** — no `Result<T>`, no `Either`, no typed return.
5. **Don't touch `modules/` or `tool/`** unless explicitly asked. They are finished.
6. **Don't commit `.env`.** It holds live keys and is gitignored. Update `.env.example` with
   placeholders instead.
7. `lib/app/widgets/appbar_widgets/` is hand-written by the user. Treat its grouping style as the
   model for widget organisation; don't restructure it.

---

## Comment style — BRIEF, SHORT, CLEAR

One concise line. Keep a comment only when it explains **why** or flags a gotcha.

| Don't | Do |
|---|---|
| Multi-paragraph doc blocks | one line, or nothing |
| `// ── Section ──` divider art | a plain `// Auth` if a group needs a label |
| A comment restating the next line | delete it |
| Commented-out code left behind | delete it |

```dart
// Bad
/// Sets the loading flag to true, calls the repository, parses the response
/// into a model, caches the token, and finally navigates to the dashboard.
///
/// Returns nothing.
Future<void> signIn() async { … }

// Good
// Retry once after refresh; a second failure is the caller's problem.
Future<void> signIn() async { … }
```

---

## Pinned names and paths

Shared with the user's other projects. Renaming any of these breaks them.

| Path | Class / symbol |
|---|---|
| `lib/app/bindings/view_model_binding.dart` | `ViewModelBinding` |
| `lib/app/core/di/user_di.dart` | `UserDi` |
| `lib/app/services/domain/api_const.dart` | `ApiConstant` |
| `lib/app/services/domain/api_service.dart` | `ApiService` |
| `lib/app/services/domain/dev_tools.dart` | `devPrint` |
| `lib/app/services/local_data/cache_manager.dart` | `CacheManager` |
| `lib/app/utils/validator.dart` | `Validators` |
| `lib/app/utils/responsive_utils.dart` | `R` — `R.h/R.w/R.sp/R.r/R.pad` |
| `lib/app/utils/constants/app_colors.dart` | `CustomColors` — **method style**: `CustomColors.primary()` |
| `lib/app/utils/constants/app_fonts.dart` | `CustomTextStyles` — `CustomTextStyles.medium16` |
| `lib/app/utils/constants/app_assets.dart` | `ImageUtils` |
| `lib/app/routes/app_routes.dart`, `app_pages.dart` | `AppRoutes`, `AppPages` |
| `lib/app/widgets/feedback/custom_snack_bar.dart` | `showCustomSnackBar(...)`, `SnackBarType` |
| `lib/app/feature/<name>/<name>_{controllers,logic,models,presentation}/` | feature folder shape |

Template-local, not shared, but still don't move them casually: `lib/bootstrap.dart`,
`lib/app/app.dart`, `lib/app/core/config/{env.dart,app_flavor.dart}`,
`lib/app/localization/app_translations.dart`.

---

## Conventions

**Feature layout** — subfolders prefixed with the feature name, never generic:

```
lib/app/feature/orders/
├── orders_controllers/     GetxControllers
├── orders_logic/           abstract ApiService + Impl + Repo, one file
├── orders_models/          final fields, copyWith, fromJson
└── orders_presentation/    screens + feature-local widgets
```

**Flow** — `Screen → Controller → Repo → Impl → ApiService`. One direction, no shortcuts.
The Repo picks the `ApiConstant` endpoint and unwraps `response.data`; the Impl is the only place
`ApiService()` is constructed.

**Screens** — `StatelessWidget` + `GetBuilder<XController>`. `Obx` wraps only the reactive slice.
Body split into `_x(BuildContext context, XController controller)` helpers.
`backgroundColor: CustomColors.artboardColor()`.

**Controllers** — own every `TextEditingController` / `GlobalKey<FormState>`, dispose in `onClose()`,
load in `onInit()`. Register in `ViewModelBinding` with `lazyPut(fenix: true)`.

**Every widget line** — `R.*` for sizes (`R.pad(horizontal: 16)`, never `R.pad(horizontal: R.w(16))`),
`CustomColors.*()` for colors, `CustomTextStyles.*` for type, `ImageUtils` for asset paths,
`.tr` on every user-facing string. Reuse `lib/app/widgets/*` instead of re-implementing.

**New route** = constant in `AppRoutes` + `GetPage` in `AppPages.pages` + entry in `ViewModelBinding`.
Miss one and the guardrail tests fail.

**Config** — `.env` is read only through `Env` (`lib/app/core/config/env.dart`); hosts only through
`ApiConstant.activeBaseUrl`. A new key needs an `Env` getter **and** a placeholder line in
`.env.example`. Flavors come from `AppFlavor` (`--dart-define=FLAVOR=dev|staging|prod`).

**Startup** — anything that must run before the first frame belongs in `bootstrap()`
(`lib/bootstrap.dart`), not in `main()` and not in `App.build`.

---

## Before declaring done

```bash
cd /path/to/repo
flutter analyze   # 0 errors — hard requirement
flutter test
```

Then confirm: folders prefixed · trio in one file · Repo owns the endpoints · controller registered
with `fenix: true` · route constant + `GetPage` added · no raw pixels · no hex colors · strings `.tr`
· comments are one-liners · `.env` untouched.
