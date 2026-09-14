# Flutter Starter

A batteries-included Flutter + GetX starter template: auth flow, themed design system, responsive
sizing, Dio API layer with token refresh, build flavors and a widget kit — clone it, rename it,
start building features.

- **GetX end-to-end** — routing, DI via `ViewModelBinding`, `.tr` translations, reactive state.
- **Feature-first architecture** — `feature/<name>/{_controllers,_logic,_models,_presentation}`.
- **Guarded startup** — `bootstrap()` loads `.env` through a typed `Env` reader, fails loudly on a
  missing required key, installs a global error zone and a release-safe `ErrorWidget`.
- **Build flavors** — `dev` / `staging` / `prod` via `--dart-define=FLAVOR=…`, picking the host.
- **Dio `ApiService`** — auth header injection, 401 refresh-and-retry with a single-flight guard,
  connectivity check, multipart upload, pretty logging in debug only.
- **Design system** — `CustomColors` (light/dark aware), `CustomTextStyles` (Inter, 10–30px),
  `R` responsive sizing scaled off a 375×812 Figma frame.
- **Widget kit** — app bars, buttons, text fields, phone + country pickers, date picker, file
  upload, bottom sheets, snackbars, dialogs, badges, pagination, skeleton-friendly images.
- **Auth feature included** — sign in, sign up, OTP send/verify, password reset, Google/Apple hooks.
- **7 optional modules** parked in `modules/`, installed on demand with one command.
- **0 analyzer errors**, guardrail tests, CI wired, one-command project rename.

---

## Quickstart

```bash
# 1. Clone and drop the template's git history
git clone <this-repo> my_app && cd my_app && rm -rf .git && git init

# 2. Rename the package and bundle id (dry-run first to see the plan)
./rename_project.sh --dry-run my_app com.mycompany.myapp
./rename_project.sh my_app com.mycompany.myapp

# 3. Create your environment file — BASE_URL and DEV_BASE_URL are required
cp .env.example .env

# 4. Install packages
flutter pub get

# 5. Run
flutter run                                    # dev flavor
flutter run --dart-define=FLAVOR=staging       # staging
flutter build apk --dart-define=FLAVOR=prod    # prod
```

Requires **Flutter 3.44.x** (Dart SDK `^3.12.2`).

---

## Architecture at a glance

```
lib/
├── main.dart                       one line — calls bootstrap()
├── bootstrap.dart                  Env.load() → CacheManager.init() → orientation →
│                                   ViewModelBinding → runApp(App()), all inside an error zone
└── app/
    ├── app.dart                    GetMaterialApp: routes, translations, themes
    ├── bindings/view_model_binding.dart   every controller, lazyPut(fenix: true)
    ├── core/
    │   ├── config/                 env.dart (typed .env reader) · app_flavor.dart
    │   ├── di/user_di.dart         cached user + roles + guest mode
    │   ├── enums/                  UserType, ImageType
    │   ├── helpers/                PaginationHelper
    │   ├── models/                 BaseResponse<T>, UserResponse, Country, …
    │   └── network/api_response.dart   ApiResponse<T> status wrapper
    ├── feature/
    │   ├── auth/
    │   │   ├── auth_controllers/   SigninController, SignupController, OTP, reset
    │   │   ├── auth_logic/         auth_api_service.dart (abstract + Impl + Repo)
    │   │   ├── auth_models/        auth_response.dart
    │   │   └── auth_presentation/  screens
    │   ├── splash/
    │   └── placeholder/            stub page for routes you haven't built yet
    ├── localization/               app_translations.dart — keys are the English strings
    ├── routes/                     app_routes.dart (constants) + app_pages.dart (GetPage list)
    ├── services/
    │   ├── domain/                 api_const.dart · api_service.dart · dev_tools.dart
    │   └── local_data/             cache_manager.dart (SharedPreferences)
    ├── themes/                     app_theme.dart + theme_controller.dart
    ├── utils/                      responsive_utils.dart (R) · validator.dart · constants/
    └── widgets/                    appbar_widgets · buttons · feedback · inputs · layout ·
                                    media · pagination  (barrel: widgets/widgets.dart)
```

Data flows one direction only:

```
Screen (StatelessWidget + GetBuilder)
  └─> Controller (GetxController — owns TextEditingControllers, Rx flags)
        └─> Repo (picks the ApiConstant endpoint, unwraps response.data)
              └─> Impl (one method per endpoint)
                    └─> ApiService (Dio: headers, 401 refresh, errors)
```

Full contract: **[ARCHITECTURE.md](ARCHITECTURE.md)**.

---

## Add a feature

Recipe for a feature called `orders`. Folders are **prefixed with the feature name**.

```
lib/app/feature/orders/
├── orders_controllers/orders_controller.dart
├── orders_logic/orders_api_service.dart      abstract + Impl + Repo, all three in one file
├── orders_models/order_model.dart            named after the thing, not the feature
└── orders_presentation/orders_screen.dart
```

| # | Step | File |
|---|---|---|
| 1 | Model — final fields, `copyWith`, `factory fromJson` | `orders_models/order_model.dart` |
| 2 | Endpoints under an `// Orders` comment | `lib/app/services/domain/api_const.dart` |
| 3 | `abstract class OrdersApiService` + `class OrdersImpl` + `class OrdersRepo` | `orders_logic/orders_api_service.dart` |
| 4 | `extends GetxController`, `final _repo = OrdersRepo();`, dispose in `onClose()` | `orders_controllers/orders_controller.dart` |
| 5 | `StatelessWidget` + `GetBuilder<OrdersController>` | `orders_presentation/orders_screen.dart` |
| 6 | Register under an `// Orders` comment | `lib/app/bindings/view_model_binding.dart` |
| 7 | Route constant + `GetPage` in `AppPages.pages` | `lib/app/routes/app_routes.dart` · `app_pages.dart` |
| 8 | New user-facing strings | `lib/app/localization/app_translations.dart` |

`_logic/` and `_models/` are optional when a feature has no API and no data class.
The API trio follows **Style A** — the Repo passes the URL down. Don't mix in Style B.

```dart
abstract class OrdersApiService {
  Future getOrders(String url, {Map<String, dynamic>? params});
}

class OrdersImpl extends OrdersApiService {
  @override
  Future getOrders(String url, {Map<String, dynamic>? params}) =>
      ApiService().get(url, params: params);
}

class OrdersRepo {
  final OrdersApiService _api = OrdersImpl();

  Future<dynamic> fetchOrders(Map<String, dynamic> params) async {
    final response = await _api.getOrders(ApiConstant.ordersUri, params: params);
    return response?.data;
  }
}
```

There is a skill for this: `~/.claude/skills/getx-feature/SKILL.md`.

---

## Optional modules

`lib/` stays lean. Stripped features live uncompiled in `modules/` with their heavy packages out of
`pubspec.yaml` until you ask for them.

```bash
dart run tool/add_module.dart                    # list
dart run tool/add_module.dart <name> --dry-run   # preview, writes nothing
dart run tool/add_module.dart <name>             # install, then flutter pub get
```

| Module | What it does | Adds packages | Native setup |
|---|---|---|---|
| `extra_widgets` | Overlay single/multi-select dropdowns, dependency-free paginated grid, loading overlay, list-state indicator, empty-state view. | none | No |
| `html_view` | `AppHtmlView` — HTML strings as widgets: theme colors, tappable tel/mailto/sms/web links, markdown, auto-linkify, HTML→text utils. | `flutter_html`, `html_unescape`, `google_fonts`, `url_launcher` | Yes |
| `location_picker` | Google Places autocomplete + map with a centre pin as the picked point, plus GPS/permission/IP location services. | `geolocator`, `permission_handler`, `google_maps_flutter`, `google_places_flutter`, `geocoding` | Yes |
| `media_viewer` | Fullscreen image/video gallery + inline thumbnail. Pinch/double-tap zoom, video player with double-tap seek. | `cached_network_image`, `video_player` | Yes |
| `multi_step_onboarding` | *Reference module.* Registration wizards: PageView step machine, per-step validation, multipart upload, cascading dropdowns. Copy the structure, replace the fields. | `image_picker`, `file_picker`, `pinput`, `intl`, `permission_handler`, `lucide_icons_flutter`, `flutter_svg`, `shared_preferences` | Yes |
| `rich_text_editor` | `CustomQuilTextField` — themed WYSIWYG form field with configurable toolbar. | `flutter_quill` | No |
| `webview` | `CustomWebView` in-app browser: progress bar, nav bar, share, open externally, copy link. | `flutter_inappwebview`, `share_plus`, `url_launcher` | Yes |

Combos worth knowing: `multi_step_onboarding` needs `CustomDropdownButton` from **extra_widgets**
(install it first) and optionally **location_picker**; **html_view** opens links externally unless you
install **webview** and set `AppHtmlView.webViewOpener = CustomWebView.open`.

Details, platform snippets and per-module READMEs: [`modules/README.md`](modules/README.md).

---

## Helper cheat-sheet

| Need | Use | Example |
|---|---|---|
| Color | `CustomColors` — **methods, with `()`** | `CustomColors.primary()`, `CustomColors.artboardColor()` |
| Text style | `CustomTextStyles` | `CustomTextStyles.medium16`, `.bold24` |
| Height / width | `R.h()` / `R.w()` | `SizedBox(height: R.h(16))` |
| Font size / radius | `R.sp()` / `R.r()` | `BorderRadius.circular(R.r(12))` |
| Padding / margin | `R.pad()` / `R.margin()` — **already scale** | `R.pad(horizontal: 16)` — never `R.pad(horizontal: R.w(16))` |
| Asset path | `ImageUtils` | `ImageUtils.appLogo`, `ImageUtils.platformBackIcon` |
| Endpoint | `ApiConstant` | `ApiConstant.loginUri`, `ApiConstant.activeBaseUrl` |
| HTTP | `ApiService` (from an Impl only) | `ApiService().post(url, params)` |
| `.env` value | `Env` | `Env.baseUrl`, `Env.optional('MY_KEY')` |
| Build flavor | `AppFlavor` | `AppFlavor.isProd`, `AppFlavor.name` |
| Local storage | `CacheManager` | `CacheManager.token`, `await CacheManager.setUserData(json)` |
| Form validation | `Validators` | `validator: Validators.emailValidator.call` |
| Toast | `showCustomSnackBar` | `showCustomSnackBar(context: ctx, type: SnackBarType.Failure, title: '…', description: '…')` |
| Localized string | `.tr` on every user-facing string | `Text("Login".tr)` |
| Debug log | `devPrint` | `devPrint('token: $token', tag: 'Auth')` |
| Platform check | `PlatformUtils` | `PlatformUtils.isIOS`, `PlatformUtils.isMobile` |

Device checks live on `R` too: `R.isPhone`, `R.isTablet`, `R.isDesktop`, `R.isLandscape`.
Whole widget kit in one import: `import 'package:flutter_starter/app/widgets/widgets.dart';`

---

## What's included / what's deliberately not

**Included**

| | |
|---|---|
| Auth | sign in · sign up · create account · OTP send/resend/verify · password reset · Google + Apple entry points |
| Startup | guarded `bootstrap()`, typed `Env` with required-key validation, flavors, global error zone, release-safe error widget |
| Networking | Dio client, flavor-aware host selection, 401 refresh with single-flight lock, session-expired redirect, multipart upload, connectivity guard |
| State | GetX controllers, `ViewModelBinding`, `UserDi` for cached user/roles/guest mode |
| Theming | light + dark `AppTheme`, `ThemeController` persisting to `CacheManager` |
| i18n | `AppTranslations` with device-locale detection and English + Bengali maps |
| UI | responsive `R`, Inter type scale, full widget kit, `PaginationHelper` + `PaginationView` |
| Tooling | `rename_project.sh`, `tool/add_module.dart`, guardrail tests, GitHub Actions CI |

**Deliberately not** — opinions you should pick per project, not inherit:

- No backend. Endpoints in `ApiConstant` are placeholder paths; `.env` hosts are yours.
- No `Result<T>` / `Either`. Repos return raw `dynamic` (Style A); controllers parse.
- No code generation — no `freezed`, `json_serializable`, `build_runner`. Models are hand-written.
- No Firebase, analytics, crash reporting, or push.
- No dashboard, profile, settings or onboarding screens — those routes hit `PlaceholderScreen`.
- No design tokens for a specific brand. `CustomColors` ships a neutral palette; repaint it.
- Heavy features (maps, webview, video, rich text, HTML) stay in `modules/` until installed.

---

## Scripts

| Command | Does |
|---|---|
| `./rename_project.sh <package_name> <bundle.id>` | Rewrites pubspec name, all `package:flutter_starter/` imports, Android namespace + applicationId + label, the Kotlin package dir, all 6 iOS bundle ids, display names, README title |
| `./rename_project.sh --dry-run …` | Prints the plan, writes nothing |
| `dart run tool/add_module.dart` | Lists / installs optional modules |
| `flutter analyze` | Must stay at **0 errors** |
| `flutter test` | Guardrail tests in `test/` |

---

## License

MIT — see [LICENSE](LICENSE).
