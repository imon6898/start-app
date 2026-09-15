# Architecture

The layer contract for this template. Read [README.md](README.md) first for the tour; this file is
the rulebook. Every rule here exists because breaking it has cost someone a debugging afternoon.

---

## 1. Startup

`main.dart` is one line on purpose — startup order lives in exactly one place.

```
main()  →  bootstrap()          lib/bootstrap.dart, inside runZonedGuarded
             ├─ FlutterError.onError + ErrorWidget.builder   red screen in debug, calm box in release
             ├─ await Env.load()                             throws EnvException on a missing key
             ├─ await CacheManager.init()                    SharedPreferences handle
             ├─ SystemChrome orientation + overlay style
             ├─ ViewModelBinding().dependencies()            App.build does Get.find<ThemeController>
             └─ runApp(App())                                app.dart → GetMaterialApp
```

`App` (`lib/app/app.dart`) wires `AppPages.pages`, `AppPages.unknownRoute`, `AppTranslations`,
`AppTheme.lightTheme` / `darkTheme` and `ThemeController.themeModeRx`, wrapped in `Obx` so a theme
change rebuilds the `GetMaterialApp` itself.

If `Env.load()` throws, the app shows `_FatalErrorApp` with the reason instead of a black screen —
and in release it shows a generic message rather than leaking config detail.

### Configuration

| Concern | Owner | Notes |
|---|---|---|
| `.env` values | `Env` — `lib/app/core/config/env.dart` | `Env.requiredKeys` (`BASE_URL`, `DEV_BASE_URL`) abort startup when empty. Everything else goes through `Env.optional(key)`. |
| Build flavor | `AppFlavor` — `lib/app/core/config/app_flavor.dart` | `--dart-define=FLAVOR=dev\|staging\|prod`. No flag: release ⇒ prod, otherwise dev. |
| Endpoints + host selection | `ApiConstant` | `activeBaseUrl` / `activeSocketUrl` resolve per flavor. Paths are `static const`. |

Rules:

- **Never call `dotenv` directly.** Add a getter to `Env`; add the key to `requiredKeys` if the app
  genuinely cannot boot without it, otherwise use `optional`.
- **Never hardcode a host.** Read `ApiConstant.activeBaseUrl`, never `Env.baseUrl` at a call site.
- Add every new key to `.env.example` with a **placeholder** and a one-line comment. `.env` is
  gitignored and holds live keys — it never gets committed or copied into docs.

---

## 2. The layers

```
Screen        StatelessWidget + GetBuilder<XController>
   │            renders state, forwards intent — no logic, no HTTP, no TextEditingController
   ▼
Controller    GetxController
   │            owns state, form keys, text controllers, loading flags; parses the response
   ▼
Repo          picks the ApiConstant endpoint, unwraps `response.data`, returns raw JSON
   │
   ▼
Impl          one method per endpoint — the only place ApiService is constructed
   │
   ▼
ApiService    Dio: base URL, auth header, 401 refresh+retry, connectivity, errors, logging
```

One direction only. A layer may call the one directly below it and nothing else.

| Layer | Owns | Must never |
|---|---|---|
| **Screen** | layout, `GetBuilder`/`Obx`, navigation calls | hold mutable state, call a Repo, build a `TextEditingController`, inline a hex color or raw pixel |
| **Controller** | `Rx*` fields, `GlobalKey<FormState>`, `TextEditingController`s, one `final _repo = XRepo();` | construct `ApiService()`, import a widget file, know about `BuildContext` beyond passing it to a snackbar |
| **Repo** | endpoint choice, envelope unwrapping | build a Dio client, decide UI state, catch-and-swallow silently |
| **Impl** | the HTTP verb + which backend flag | choose the endpoint (Style A — the Repo passes the URL) |
| **ApiService** | transport concerns | know about a feature |

### Why layers, not just a service class

The split buys three things: the Impl is stubbable in a test without a Dio mock, the endpoint map
lives in exactly one place per feature, and a controller never accidentally fires a raw request at
the wrong base URL.

---

## 3. Style-A API trio

All three classes live in **one file**: `feature/<name>/<name>_logic/<name>_api_service.dart`.

**Style A** means the Repo owns the endpoint and passes the URL down; the Impl is a thin, reusable
HTTP shim. This is the template's convention — do not introduce the alternative where the Impl
hardcodes `ApiConstant.xUri`, and never mix both in one abstract class.

Real example, trimmed from `lib/app/feature/auth/auth_logic/auth_api_service.dart`:

```dart
import 'package:flutter_starter/app/services/domain/api_const.dart';
import 'package:flutter_starter/app/services/domain/api_service.dart';

/// Abstract class for Auth API Service
abstract class AuthApiService {
  Future postSignin(String url, Map<String, dynamic> params);
  Future postVerifyOtp(String url, Map<String, dynamic> params);
}

/// Implementation of AuthApiService
class AuthImpl extends AuthApiService {
  @override
  Future postSignin(String url, Map<String, dynamic> params) async {
    final dynamic response = await ApiService().post(url, params);
    return response;
  }

  @override
  Future postVerifyOtp(String url, Map<String, dynamic> params) async {
    final dynamic response = await ApiService().post(url, params);
    return response;
  }
}

/// Repository for Auth
class AuthRepo {
  final AuthApiService authApiService = AuthImpl();

  Future<dynamic>? postLoginRepo(Map<String, dynamic> params) async {
    dynamic responseData = await authApiService.postSignin(ApiConstant.loginUri, params);
    return responseData = responseData.data;
  }

  Future<dynamic>? postVerifyOtpRepo(Map<String, dynamic> params) async {
    dynamic responseData = await authApiService.postVerifyOtp(ApiConstant.verifyOtpUri, params);
    return responseData = responseData.data;
  }
}
```

Contract notes, all load-bearing:

- **Return type is `dynamic`.** No `Result<T>`, no `Either`, no typed envelope at this boundary.
  The Repo hands back decoded JSON; the controller turns it into a model. Changing this breaks every
  existing controller and every module in `modules/`.
- **The Repo unwraps `.data`** off the Dio `Response`. Screens and controllers never see a `Response`.
- **Method naming.** New repos use the plain verb (`fetchOrders`, `createTicket`). The `…Repo`
  suffix (`postLoginRepo`) survives only in `auth_logic` — match a file you're extending, don't
  spread the suffix to new features.
- **Multiple backends** are selected in the Impl, never in the Repo:
  `ApiService(secondaryBaseUrl: true)` or `ApiService(googleBaseUrl: true)`.
- **Endpoints belong in `ApiConstant`** under a `// <Section>` comment. A URL string is never typed
  twice and never typed in a controller.

### Controller side of the contract

```dart
class SigninController extends GetxController {
  final GlobalKey<FormState> signInFormKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final RxBool isLoadingSignIn = false.obs;
  final _authRepo = AuthRepo();

  @override
  void onClose() {
    emailController.dispose();
    super.onClose();
  }
}
```

The controller validates the form, flips the loading flag, calls the Repo, parses into a model
(`BaseResponse<T>` when the backend uses the standard envelope), caches what needs caching, and
navigates. That is the whole job.

---

## 4. State management rules

**Screens are `StatelessWidget`.** A `StatefulWidget` is justified only by a lifecycle the
controller cannot own — `TabController`, `AnimationController`, a scanner. Never for data.

**Shell is `GetBuilder`, reactive slices are `Obx`.**

```dart
class SigninScreen extends StatelessWidget {
  const SigninScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SigninController>(
      builder: (c) => Scaffold(
        backgroundColor: CustomColors.artboardColor(),
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
          child: AppBarWidget(title: 'Login'.tr),
        ),
        body: _body(context, c),
      ),
    );
  }

  Widget _body(BuildContext context, SigninController controller) { /* … */ }
}
```

`GetBuilder` gives you the instance and rebuilds on `update()`. `Obx(() => …)` goes **inside** it,
wrapping only the widget that depends on an `Rx` — a button's spinner, a counter, a list. Wrapping
the whole `Scaffold` in `Obx` rebuilds everything on every keystroke.

**Split the body.** Helper methods take `(BuildContext context, XController controller)`. No
monolithic `build()`.

**Controllers own disposables.** Every `TextEditingController`, `ScrollController`, `FocusNode`,
`StreamSubscription` and `Timer` is created as a field and released in `onClose()`. Load initial
data in `onInit()`. `update()` after mutating a non-reactive field; an `Rx` assignment needs no call.

**Registration.** Controllers go in `ViewModelBinding` with `Get.lazyPut(fenix: true)` under a
`// <Feature>` comment. `fenix: true` matters: a controller deleted when its route pops is rebuilt
on the next visit instead of throwing. Never `Get.put()` inside a `build()`.

**Unfocus before submit or navigate:** `FocusScope.of(context).unfocus();`.

**Styling is non-negotiable.** Sizing through `R.*`, colors through `CustomColors.*()`, type through
`CustomTextStyles.*`, asset paths through `ImageUtils`, user-facing strings end in `.tr` and get a
key in every locale map. Note `R.pad()` / `R.margin()` already scale internally —
`R.pad(horizontal: 16)`, never `R.pad(horizontal: R.w(16))`, which double-scales and renders wide on
any device that isn't the design width.

**Localization keys are the English source strings**, not symbolic ids. A missed key renders as
readable English instead of `auth.signin.title`, which is why the fallback is safe to rely on. The
cost is that duplicates are invisible — `'Login'` and `'Log In'` are two keys — so `en_US` is kept
as an exact mirror of its own keys and the guardrail fails on any drift:

```
lib/app/localization/
├── app_translations.dart   locale plumbing: supported, initialLocale, setLocale
└── locales/
    ├── en_us.dart          source language — every value equals its key
    └── bn_bd.dart          worked example for a second language
```

Three rules that keep it from rotting: never pad a key with whitespace (add the space in the widget,
`'${'I agree to the'.tr} '`), never interpolate into a key (use `.trParams` with `@n`), and never
localize inside a model — `.tr` belongs at the display site.

---

## 5. Error handling

Errors are handled at the lowest layer that can do something useful about them.

| Failure | Handled by | What the caller sees |
|---|---|---|
| Missing/invalid `.env` | `Env.load()` throws `EnvException`; `bootstrap()` catches | fatal-error screen instead of a black one |
| Uncaught async error | `runZonedGuarded` in `bootstrap()` | `devPrint` with the `Uncaught` tag |
| Widget build crash | `ErrorWidget.builder` | red screen in debug, calm box in release |
| No connectivity | `ApiService` — `checkInternet()` before every verb | warning snackbar, method returns `null` |
| `DioException` non-401 | `ApiService.errorHandle()` logs + surfaces the message | `null` (or `e.response` on `post`) |
| 401 with a refresh token | `ApiService` interceptor: refresh, retry once with `extra['isRetry']` | transparent success, or the original error |
| 401 refresh failed | `_handleSessionExpired()` clears tokens, `Get.offAllNamed(SigninScreen)` after the frame | user lands on sign-in |
| Malformed payload | Controller's `try/catch` around model parsing | failure snackbar |

Consequences you must code around:

- **A Repo can return `null`.** Connectivity failures and swallowed Dio errors both yield `null`.
  Null-check in the controller before parsing, and always reset the loading flag in a `finally`.
- **Don't sign the user out yourself** on a 401 — the interceptor owns that path.
- **The refresh is single-flight.** A static `_isRefreshing` flag plus a `Completer` means twenty
  parallel 401s trigger one refresh; the rest await it. Don't add a second refresh path.
- **Debug logging** goes through `devPrint(message, tag: '…')` (`services/domain/dev_tools.dart`),
  which is a no-op in release. `PrettyDioLogger` is only attached under `kDebugMode`.
- **User-visible failures** go through `showCustomSnackBar(context:, type: SnackBarType.Failure,
  title:, description:)`. Don't use raw `ScaffoldMessenger`.

---

## 6. Caching

`CacheManager` (`services/local_data/cache_manager.dart`) is the only `SharedPreferences` surface.
It is static, keyed by a `CacheKeys` enum, and initialised once in `bootstrap()` via
`await CacheManager.init()` before `runApp`.

| Concern | API |
|---|---|
| Auth | `token` / `refreshToken` — getters plus `setX` / `removeX` |
| Identity | `userData` (JSON string), `userType`, `rolesList` / `setRoles(jsonList)` |
| Session mode | `isGuest`, `hasSeenOnboarding` |
| Remember-me | `getLoginEmail`, `getLoginPassword` |
| Theme | `getThemeId` — read by `ThemeController` on init |
| Logout | `removeAll()`, or `UserDi.clearUserData()` for the user-scoped subset |

Rules:

- **Never touch `SharedPreferences` directly.** Add a typed getter/setter pair to `CacheManager`
  and a `CacheKeys` entry instead — it keeps key strings from drifting.
- **Cached user goes through `UserDi`,** not raw `CacheManager.userData`. `UserDi` is a
  `GetxController` that decodes `UserResponse` once and exposes `isLoggedIn`, `isGuest`, `roles`,
  `hasRole(…)`, `userType`. Call `refreshUser()` after a profile write.
- **`ApiService` reads `CacheManager.token` per request** in the `onRequest` interceptor, so writing
  a new token takes effect immediately — no client rebuild needed.
- `CacheManager` is a *cache of session facts*, not an offline database. Response bodies don't go
  in it; add a real local store if you need one.

---

## 7. Guardrail tests

`test/` holds guardrails, not a coverage target. They exist to make the conventions above fail loudly
in CI instead of silently rotting.

```
test/
├── guardrails/   architecture invariants — the conventions in this file, asserted
├── unit/         pure logic: Validators, R scaling, model fromJson, Env
└── widget/       renders a screen and checks it wires to its controller
```

```bash
flutter test
```

What the guardrails lock down:

| Guard | Catches |
|---|---|
| Route wiring | an `AppRoutes` constant with no matching `GetPage` in `AppPages.pages`, and duplicate paths |
| Binding coverage | a controller under `feature/*/*_controllers/` never registered in `ViewModelBinding` |
| Pinned names | a rename/move of `ViewModelBinding`, `UserDi`, `ApiConstant`, `ApiService`, `CacheManager`, `Validators`, `R`, `CustomColors`, `CustomTextStyles`, `ImageUtils` |
| Layer flow | `ApiService()` constructed outside a `*_logic/` file; a screen importing a Repo |
| Style conventions | raw hex colors, raw pixel literals, `R.pad(horizontal: R.w(…))` double-scaling |
| Config | a key used by `Env` that is missing from `.env.example` |
| Localization | a `.tr` string with no key, a key nothing calls, a locale map out of sync with `en_US`, a key padded with whitespace |

Adding a feature means adding its route, its binding entry and its folder prefix — the guardrails
tell you which one you forgot. Before declaring any change done:

```bash
flutter analyze   # must stay at 0 errors
flutter test
```

---

## 8. Extending without breaking the contract

| You want to | Do this | Not this |
|---|---|---|
| Add a screen | new `feature/<name>/` with prefixed subfolders, route + binding | drop a widget file in `lib/app/widgets/` |
| Add an endpoint | constant in `ApiConstant`, method on the Impl, method on the Repo | call `ApiService()` from the controller |
| Add a config value | getter on `Env` + a placeholder line in `.env.example` | `dotenv.get(...)` at the call site |
| Add a shared widget | a folder under `lib/app/widgets/` with a barrel file, re-exported from `widgets.dart` | a loose file at the widgets root |
| Add a color | a method on `CustomColors` returning the light/dark pair | a `Color(0xFF…)` at the call site |
| Add a string | `.tr` at the call site + the same key in every map under `localization/locales/` | a bare string literal |
| Add a language | translate a copy of `locales/en_us.dart` + one line in `AppTranslations._locales` | a second `supportedLocales` list |
| Add a heavy dependency | package it under `modules/` with a `module.yaml` | grow `pubspec.yaml` for everyone |
| Change the Repo return type | don't | `Result<T>` / `Either` |
