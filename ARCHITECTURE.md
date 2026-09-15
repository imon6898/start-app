# Architecture

How this template is organised and how to add to it.

New here? Read §1 and §2, then follow §3 once end to end. That is the whole job — everything after
§3 is reference you look up when you need it.

| | |
|---|---|
| §1 | [The idea in 60 seconds](#1-the-idea-in-60-seconds) |
| §2 | [Where things live](#2-where-things-live) |
| §3 | [**Add a feature — full walkthrough**](#3-add-a-feature--full-walkthrough) |
| §4 | [Copy-paste templates](#4-copy-paste-templates) |
| §5 | [Naming rules](#5-naming-rules) |
| §6 | [The house helpers](#6-the-house-helpers) |
| §6b | [**Widget catalog** — every shared widget](#6b-widget-catalog) |
| §6c | [**Module catalog** — every optional feature](#6c-module-catalog) |
| §7 | [The five layers in detail](#7-the-five-layers-in-detail) |
| §8 | [Errors — what you must code around](#8-errors--what-you-must-code-around) |
| §9 | [Storing things](#9-storing-things) |
| §10 | [Text and languages](#10-text-and-languages) |
| §11 | [Guardrails — the tests that keep this true](#11-guardrails--the-tests-that-keep-this-true) |
| §12 | [I want to… (quick answers)](#12-i-want-to-quick-answers) |
| §13 | [Startup order](#13-startup-order) |

---

## 1. The idea in 60 seconds

**A feature is a folder.** Everything one feature needs — its screens, its state, its API calls, its
data shapes — lives in `lib/app/feature/<name>/` and nowhere else. Delete the folder and the feature
is gone.

**Data flows one direction.** Each layer talks only to the one directly below it:

```
Screen        what the user sees          →  no logic, no HTTP, no state
   ↓
Controller    what the app remembers      →  state, form fields, loading flags
   ↓
Repo          which endpoint to call      →  picks the URL, unwraps the envelope
   ↓
Impl          how to call it              →  the HTTP verb
   ↓
ApiService    the network itself          →  auth header, retries, errors
```

A screen never calls a Repo. A controller never builds an HTTP client. Keep that and the codebase
stays readable no matter how many features you add.

**Four folders per feature**, always named after the feature:

```
feature/orders/
├── orders_presentation/   screens the user sees
├── orders_controllers/    state and logic
├── orders_logic/          API calls
└── orders_models/         data shapes
```

The prefix is not decoration. Open twenty files in your editor and `orders_controller.dart` tells you
where you are; twenty files called `controller.dart` do not.

---

## 2. Where things live

```
lib/
├── main.dart                     one line — calls bootstrap()
├── bootstrap.dart                everything that must happen before the first frame
└── app/
    ├── app.dart                  the GetMaterialApp: routes, theme, language
    │
    ├── feature/                  ← YOUR WORK GOES HERE
    │   ├── auth/                 worked example: sign in, sign up, OTP, reset password
    │   ├── splash/               worked example: the smallest possible feature
    │   └── placeholder/          a stand-in screen for routes you haven't built yet
    │
    ├── widgets/                  shared UI, grouped by what it does
    │   ├── appbar_widgets/       app bars, back buttons, status bar styling
    │   ├── buttons/              CustomButton, CustomOutlinedButton
    │   ├── feedback/             snackbars, dialogs, badges, loading dots
    │   ├── inputs/               text fields, phone field, pickers, file upload
    │   ├── layout/               cards, section headers, bottom sheets, dividers
    │   ├── media/                images
    │   ├── pagination/           paged list view
    │   └── widgets.dart          barrel — one import gets you all of it
    │
    ├── routes/
    │   ├── app_routes.dart       the route name constants
    │   └── app_pages.dart        name → screen, with transitions
    │
    ├── bindings/
    │   └── view_model_binding.dart   every controller registered here
    │
    ├── services/
    │   ├── domain/               api_service · api_const · dev_tools
    │   └── local_data/           cache_manager
    │
    ├── core/
    │   ├── config/               env · app_flavor
    │   ├── di/                   user_di — the signed-in user
    │   ├── models/               shared models: BaseResponse, UserResponse, Country
    │   ├── network/              ApiResponse
    │   ├── enums/                shared enums
    │   └── helpers/              pagination helper
    │
    ├── themes/                   app_theme · theme_controller
    ├── localization/             app_translations + locales/en_us.dart, bn_bd.dart
    └── utils/
        ├── responsive_utils.dart     R — all sizing
        ├── validator.dart            Validators — all form rules
        └── constants/                app_colors · app_fonts · app_assets · app_constants
```

**The rule of thumb:** if only one feature uses it, it belongs in that feature's folder. The moment a
second feature needs it, move it to `widgets/`, `core/models/`, or `utils/`.

---

## 3. Add a feature — full walkthrough

We'll build an **orders** feature: a screen that loads a list of orders from the API. Follow all
seven steps and you'll have touched every part of the system exactly once.

Prefer to skip the reading? Run the scaffolder instead — it writes steps 1–5 for you:

```bash
dart run tool/new_feature.dart orders
```

### Step 1 — Make the folders

```
lib/app/feature/orders/
├── orders_models/
├── orders_logic/
├── orders_controllers/
└── orders_presentation/
```

Only create the folders you'll actually fill. A feature with no API calls doesn't need
`orders_logic/`; a feature with no data shapes doesn't need `orders_models/`.

### Step 2 — Describe the data

`orders_models/order_model.dart`

```dart
class OrderModel {
  final String? id;
  final String? status;
  final double? total;
  final DateTime? placedAt;

  OrderModel({this.id, this.status, this.total, this.placedAt});

  OrderModel copyWith({String? id, String? status, double? total, DateTime? placedAt}) {
    return OrderModel(
      id: id ?? this.id,
      status: status ?? this.status,
      total: total ?? this.total,
      placedAt: placedAt ?? this.placedAt,
    );
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      // Backends disagree on casing — accept both.
      id: json['id'] ?? json['order_id'],
      status: json['status'],
      total: (json['total'] as num?)?.toDouble(),
      placedAt: json['placed_at'] != null
          ? DateTime.tryParse(json['placed_at'])
          : null,
    );
  }
}
```

Four rules that make models predictable:

- **Every field `final` and nullable.** A response can always be missing a field; a nullable model
  never throws at parse time.
- **`copyWith` always.** You will want it the first time you edit one item in a list.
- **`fromJson` accepts both casings** where the backend is inconsistent — `json['order_id'] ?? json['orderId']`.
- **Lists default to `[]`, never `null`** — `json['items'] == null ? [] : List<...>.from(...)`.

Name the file after *the thing*, not the feature: `order_model.dart`, not `orders_model.dart`. Use
the `_response.dart` suffix only for a literal API envelope.

### Step 3 — Add the endpoints

`lib/app/services/domain/api_const.dart` — add a section at the bottom:

```dart
  // ── Orders ──
  static const String ordersUri = '/orders';
  static String orderDetailUri(String id) => '/orders/$id';
```

A URL string is written **once, here**. Never type a path in a controller or a screen.

### Step 4 — Write the API trio

`orders_logic/orders_api_service.dart` — all three classes in **one file**:

```dart
import 'package:flutter_starter/app/services/domain/api_const.dart';
import 'package:flutter_starter/app/services/domain/api_service.dart';

/// What the orders feature can ask the network to do.
abstract class OrdersApiService {
  Future fetchOrders(String url, {Map<String, dynamic>? params});
  Future fetchOrderDetail(String url);
}

/// The only place ApiService is constructed for this feature.
class OrdersImpl extends OrdersApiService {
  @override
  Future fetchOrders(String url, {Map<String, dynamic>? params}) async {
    final dynamic response = await ApiService().get(url, params: params);
    return response;
  }

  @override
  Future fetchOrderDetail(String url) async {
    final dynamic response = await ApiService().get(url);
    return response;
  }
}

/// Picks the endpoint and unwraps the envelope. Controllers talk to this.
class OrdersRepo {
  final OrdersApiService ordersApiService = OrdersImpl();

  Future<dynamic>? fetchOrders({int page = 1}) async {
    dynamic responseData = await ordersApiService.fetchOrders(
      ApiConstant.ordersUri,
      params: {'page': page},
    );
    return responseData = responseData.data;
  }

  Future<dynamic>? fetchOrderDetail(String id) async {
    dynamic responseData = await ordersApiService.fetchOrderDetail(
      ApiConstant.orderDetailUri(id),
    );
    return responseData = responseData.data;
  }
}
```

**Why three classes instead of one?** The `abstract` class is the contract, so a test can swap in a
fake without mocking Dio. The `Impl` is a dumb HTTP shim you rarely touch. The `Repo` is where
endpoint choice lives, so you can see every URL a feature uses by reading one class.

**Two contract rules you must not break:**

- **The Repo passes the URL down.** The `Impl` never reaches for `ApiConstant` itself. (If you've
  seen the other style, don't mix them — one abstract class must use one style.)
- **The return type stays `dynamic`.** No `Result<T>`, no `Either`. Every controller and every
  module in `modules/` depends on this shape.

Calling a second backend? Choose it in the `Impl`, never the Repo:
`ApiService(secondaryBaseUrl: true).get(url)`.

### Step 5 — Write the controller

`orders_controllers/orders_controller.dart`

```dart
import 'package:get/get.dart';
import 'package:flutter_starter/app/core/models/base_response.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import '../orders_logic/orders_api_service.dart';
import '../orders_models/order_model.dart';

class OrdersController extends GetxController {
  final OrdersRepo _ordersRepo = OrdersRepo();

  final RxList<OrderModel> orders = <OrderModel>[].obs;
  final RxBool isLoadingOrders = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadOrders();
  }

  Future<void> loadOrders() async {
    isLoadingOrders.value = true;
    errorMessage.value = '';
    try {
      final response = await _ordersRepo.fetchOrders();
      // Repo returns null when offline or on a swallowed Dio error.
      if (response == null) {
        errorMessage.value = 'Could not load orders'.tr;
        return;
      }
      final parsed = BaseResponse<List<OrderModel>>.fromJson(
        response,
        (data) => (data as List).map((e) => OrderModel.fromJson(e)).toList(),
      );
      orders.assignAll(parsed.data ?? []);
    } catch (e) {
      devPrint('$e', tag: 'OrdersController');
      errorMessage.value = 'Something went wrong. Please try again.'.tr;
    } finally {
      isLoadingOrders.value = false;
    }
  }
}
```

The controller's whole job: **flip the loading flag → call the Repo → null-check → parse → store →
always reset the flag in `finally`.**

If the feature has a form, its `TextEditingController`s and `GlobalKey<FormState>` live here too,
and get disposed:

```dart
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController noteController = TextEditingController();

  @override
  void onClose() {
    noteController.dispose();
    super.onClose();
  }
```

Anything you create, you dispose — `TextEditingController`, `ScrollController`, `FocusNode`,
`StreamSubscription`, `Timer`.

### Step 6 — Write the screen

`orders_presentation/orders_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/widgets.dart';
import '../orders_controllers/orders_controller.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<OrdersController>(
      builder: (controller) => Scaffold(
        backgroundColor: CustomColors.artboardColor(),
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
          child: AppBarWidget(title: 'Orders'.tr),
        ),
        body: _body(context, controller),
      ),
    );
  }

  Widget _body(BuildContext context, OrdersController controller) {
    return Obx(() {
      if (controller.isLoadingOrders.value) {
        return const LoadingWidget();
      }
      if (controller.errorMessage.value.isNotEmpty) {
        return EmptyStateWidget(message: controller.errorMessage.value);
      }
      return ListView.separated(
        padding: R.pad(horizontal: 16, vertical: 12),
        itemCount: controller.orders.length,
        separatorBuilder: (_, _) => SizedBox(height: R.h(12)),
        itemBuilder: (_, i) => _orderTile(controller.orders[i]),
      );
    });
  }

  Widget _orderTile(OrderModel order) {
    return CardContainer(
      child: Row(
        children: [
          Expanded(
            child: Text(order.id ?? '', style: CustomTextStyles.medium16),
          ),
          StatusBadge(label: order.status ?? ''),
        ],
      ),
    );
  }
}
```

Six rules, and every one of them is checked by a test:

| Rule | Why |
|---|---|
| `StatelessWidget`, always | State belongs in the controller. `StatefulWidget` only for a `TabController`/`AnimationController`/scanner lifecycle |
| `GetBuilder` is the shell, `Obx` is inside it | `Obx` around the whole `Scaffold` rebuilds everything on every keystroke |
| Split the body into `_x(context, controller)` helpers | No 400-line `build()` |
| Sizing via `R.*` | A raw `16` is one device size; `R.h(16)` is every device |
| Colours via `CustomColors.*()`, type via `CustomTextStyles.*` | Dark mode, one place to change |
| Every visible string ends in `.tr` | §10 |

`R.pad()` already scales internally — write `R.pad(horizontal: 16)`, **never**
`R.pad(horizontal: R.w(16))`, which scales twice and renders too wide everywhere but your design
device.

### Step 7 — Wire it up (3 small edits)

**7a. Route name** — `lib/app/routes/app_routes.dart`

```dart
  /// Orders
  static const String OrdersScreen = '/ordersScreen';
```

**7b. Route → screen** — `lib/app/routes/app_pages.dart`

```dart
import '../feature/orders/orders_presentation/orders_screen.dart';
// …
    _page(AppRoutes.OrdersScreen, () => const OrdersScreen()),
```

**7c. Register the controller** — `lib/app/bindings/view_model_binding.dart`

```dart
import '../feature/orders/orders_controllers/orders_controller.dart';
// …inside dependencies():
    // Orders
    _lazy<OrdersController>(() => OrdersController());
```

`_lazy` registers with `fenix: true`, which means the controller is rebuilt automatically if it was
disposed when the route popped. Never call `Get.put()` inside a `build()`.

### Step 8 — Add your strings

Every `.tr` string needs the same key in **every** locale file — `locales/en_us.dart` **and**
`locales/bn_bd.dart`. In English the value equals the key:

```dart
  // Orders
  'Orders': 'Orders',
  'Could not load orders': 'Could not load orders',
```

### Done — verify

```bash
flutter analyze   # must be 0 errors
flutter test      # the guardrails tell you what you forgot
```

If you missed the route, the binding, a translation key, or used a raw pixel, a test fails **by
name** and tells you which file. That's the point of them.

**The checklist:**

- [ ] Folders prefixed with the feature name
- [ ] All three API classes in one `*_api_service.dart`
- [ ] Endpoints in `ApiConstant`, not inline
- [ ] Controller disposes what it creates
- [ ] Screen is `StatelessWidget` + `GetBuilder`
- [ ] Route constant **and** `GetPage` **and** binding entry
- [ ] Strings in every locale file
- [ ] `flutter analyze` clean, `flutter test` green

---

## 4. Copy-paste templates

Skeletons with the boilerplate already correct. Replace `Thing`/`thing`.

<details>
<summary><b>Model</b> — <code>thing_models/thing_model.dart</code></summary>

```dart
class ThingModel {
  final String? id;
  final String? name;

  ThingModel({this.id, this.name});

  ThingModel copyWith({String? id, String? name}) =>
      ThingModel(id: id ?? this.id, name: name ?? this.name);

  factory ThingModel.fromJson(Map<String, dynamic> json) => ThingModel(
        id: json['id'],
        name: json['name'],
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
```
</details>

<details>
<summary><b>API trio</b> — <code>thing_logic/thing_api_service.dart</code></summary>

```dart
import 'package:flutter_starter/app/services/domain/api_const.dart';
import 'package:flutter_starter/app/services/domain/api_service.dart';

abstract class ThingApiService {
  Future fetchThings(String url, {Map<String, dynamic>? params});
  Future createThing(String url, Map<String, dynamic> params);
}

class ThingImpl extends ThingApiService {
  @override
  Future fetchThings(String url, {Map<String, dynamic>? params}) async {
    final dynamic response = await ApiService().get(url, params: params);
    return response;
  }

  @override
  Future createThing(String url, Map<String, dynamic> params) async {
    final dynamic response = await ApiService().post(url, params);
    return response;
  }
}

class ThingRepo {
  final ThingApiService thingApiService = ThingImpl();

  Future<dynamic>? fetchThings() async {
    dynamic responseData =
        await thingApiService.fetchThings(ApiConstant.thingsUri);
    return responseData = responseData.data;
  }

  Future<dynamic>? createThing(Map<String, dynamic> params) async {
    dynamic responseData =
        await thingApiService.createThing(ApiConstant.thingsUri, params);
    return responseData = responseData.data;
  }
}
```
</details>

<details>
<summary><b>Controller</b> — <code>thing_controllers/thing_controller.dart</code></summary>

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/core/models/base_response.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import '../thing_logic/thing_api_service.dart';
import '../thing_models/thing_model.dart';

class ThingController extends GetxController {
  final ThingRepo _thingRepo = ThingRepo();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();

  final RxList<ThingModel> things = <ThingModel>[].obs;
  final RxBool isLoadingThings = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadThings();
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }

  Future<void> loadThings() async {
    isLoadingThings.value = true;
    try {
      final response = await _thingRepo.fetchThings();
      if (response == null) return;
      final parsed = BaseResponse<List<ThingModel>>.fromJson(
        response,
        (data) => (data as List).map((e) => ThingModel.fromJson(e)).toList(),
      );
      things.assignAll(parsed.data ?? []);
    } catch (e) {
      devPrint('$e', tag: 'ThingController');
    } finally {
      isLoadingThings.value = false;
    }
  }
}
```
</details>

<details>
<summary><b>Screen</b> — <code>thing_presentation/thing_screen.dart</code></summary>

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/widgets.dart';
import '../thing_controllers/thing_controller.dart';

class ThingScreen extends StatelessWidget {
  const ThingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThingController>(
      builder: (controller) => Scaffold(
        backgroundColor: CustomColors.artboardColor(),
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
          child: AppBarWidget(title: 'Things'.tr),
        ),
        body: _body(context, controller),
      ),
    );
  }

  Widget _body(BuildContext context, ThingController controller) {
    return Obx(
      () => controller.isLoadingThings.value
          ? const LoadingWidget()
          : ListView.builder(
              padding: R.pad(horizontal: 16, vertical: 12),
              itemCount: controller.things.length,
              itemBuilder: (_, i) => Text(controller.things[i].name ?? ''),
            ),
    );
  }
}
```
</details>

<details>
<summary><b>Form submit</b> — the pattern for any save/submit button</summary>

```dart
  Future<void> submit(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    isLoadingSubmit.value = true;
    try {
      final response = await _thingRepo.createThing({'name': nameController.text});
      if (response == null) return;

      final parsed = BaseResponse.fromJson(response, (d) => d);
      if (parsed.statusCode == 200 || parsed.statusCode == 201) {
        showCustomSnackBar(
          context: context,
          type: SnackBarType.Success,
          title: 'Success'.tr,
          description: 'Saved'.tr,
        );
        Get.back();
      } else {
        showCustomSnackBar(
          context: context,
          type: SnackBarType.Failure,
          title: 'Error'.tr,
          description: parsed.message,
        );
      }
    } finally {
      isLoadingSubmit.value = false;
    }
  }
```
</details>

---

## 5. Naming rules

| Thing | Rule | Example |
|---|---|---|
| Folder | `snake_case`, prefixed with the feature | `orders_controllers/` |
| File | `snake_case`, named after its main class — or the group, when it holds a related pair | `order_model.dart` → `OrderModel`; `custom_primary_button.dart` → `CustomButton` + `CustomOutlinedButton` |
| Class | `PascalCase` | `OrdersController` |
| Screen | `<Name>Screen` | `OrdersScreen` |
| Controller | `<Name>Controller` | `OrdersController` |
| API trio | `<Name>ApiService` / `<Name>Impl` / `<Name>Repo` | `OrdersRepo` |
| Model | named after the thing, not the feature | `order_model.dart`, not `orders_model.dart` |
| Loading flag | `isLoading<Action>` | `isLoadingOrders` |
| Endpoint | `<name>Uri`, or `<name>Uri(id)` for a path param | `ordersUri` |
| Route constant | `PascalCase` matching the screen class | `AppRoutes.OrdersScreen` |
| Repo method | plain verb | `fetchOrders`, `createTicket` |

Two deliberate exceptions, both enforced by tests so nobody "fixes" them:

- **Route constants are `PascalCase`** (`AppRoutes.SigninScreen`) — the file opts out of the lint at
  the top. They're pinned across projects.
- **`auth_logic` uses a `…Repo` method suffix** (`postLoginRepo`). Match it when editing that file;
  use the plain verb everywhere new.

---

## 6. The house helpers

Never hand-roll these. Import and use.

| Need | Use | Example |
|---|---|---|
| Any size | `R` | `R.h(16)` `R.w(12)` `R.sp(14)` `R.r(8)` `R.pad(horizontal: 16)` |
| Any colour | `CustomColors` — **methods, with `()`** | `CustomColors.primary()` `CustomColors.artboardColor()` |
| Any text style | `CustomTextStyles` | `CustomTextStyles.medium16` `.bold20.primary` |
| Any asset path | `ImageUtils` | `ImageUtils.appIcon` |
| Any endpoint | `ApiConstant` | `ApiConstant.ordersUri` |
| Any form rule | `Validators` | `Validators.emailValidator.call` |
| Any stored value | `CacheManager` | `CacheManager.token` |
| The signed-in user | `UserDi` | `Get.find<UserDi>().isLoggedIn` |
| A message to the user | `showCustomSnackBar` | `type: SnackBarType.Success` |
| A debug log | `devPrint` | `devPrint('$e', tag: 'OrdersController')` |
| Any shared widget | `widgets/widgets.dart` | one import for the whole kit |
| Icons | `LucideIcons` | `LucideIcons.package` |

Three traps worth memorising:

```dart
R.pad(horizontal: R.w(16))   // ✗ scales twice — too wide on every other device
R.pad(horizontal: 16)        // ✓ R.pad scales for you

CustomColors.primary         // ✗ that's the function, not the colour
CustomColors.primary()       // ✓ call it

Text('Orders')               // ✗ never translated
Text('Orders'.tr)            // ✓
```

---

## 6b. Widget catalog

Everything in `lib/app/widgets/`. One import gets you all of it:

```dart
import 'package:flutter_starter/app/widgets/widgets.dart';
```

Required params are marked **bold**. Anything not listed is optional.

### `appbar_widgets/` — top of the screen

| Widget | What it does | Key params |
|---|---|---|
| `AppBarWidget` | The standard app bar. Use it in a `PreferredSize` of `kToolbarHeight + R.h(10)`. | `title`, `titleWidget`, `toolbarActions`, `onLeadingTap`, `centerTitle` (default `true`) |
| `AppBarLeading` | The back chevron. Platform-aware; usually built for you by `AppBarWidget`. | **`isForcefullyShow`**, `onLeadingTap`, `icon` |
| `AppStatusBar` | Wraps a screen to control status-bar / nav-bar icon colour per route. | **`child`**, **`style`** |

```dart
appBar: PreferredSize(
  preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
  child: AppBarWidget(title: 'Orders'.tr),
),
```

### `buttons/` — actions

| Widget | What it does | Key params |
|---|---|---|
| `CustomButton` | The filled primary button. Handles its own loading state. | `text`, **`onPressed`**, `backgroundColor`, `textStyle`, `borderRadius` (6.0) |
| `CustomOutlinedButton` | The bordered secondary button, same API. | `text`, **`onPressed`**, `borderColor`, `textColor`, `borderRadius` (6.0) |

> The file is `custom_primary_button.dart` but the classes are `CustomButton` /
> `CustomOutlinedButton` — it holds a related pair, so the file is named for the group.

```dart
CustomButton(text: 'Save'.tr, onPressed: () => controller.submit(context))
```

### `feedback/` — telling the user what happened

| Widget / function | What it does | Key params |
|---|---|---|
| `showCustomSnackBar()` | **The only way to show a message.** Never use raw `ScaffoldMessenger`. | **`context`**, **`type`**, **`title`**, **`description`** |
| `showSuccessDialog()` | Full-screen success confirmation with an action. | see the file |
| `showDeleteConfirmationDialog()` | "Are you sure?" before a destructive action. | see the file |
| `StatusBadge` | Small coloured pill for a state — Pending, Paid, Failed. | **`label`**, `tone`, `height` (26) |
| `StripedProgressBar` | Determinate progress with a striped fill. | **`width`**, **`height`**, **`percent`**, `stripeColor`, `fillColor` |
| `ThinkingDots` | Animated "…" for a pending or streaming state. | `title` |

```dart
showCustomSnackBar(
  context: context,
  type: SnackBarType.Success,   // Success | Failure | Warning
  title: 'Saved'.tr,
  description: 'Your order was placed'.tr,
);
```

### `inputs/` — forms

| Widget | What it does | Key params |
|---|---|---|
| `CustomTextField` | The standard text field: heading, hint, validator, focus chaining. | `hintText`, `controller`, `focusNode`, `nextFocus`, `prefixImage` |
| `CustomPhoneTextField` | Phone input with a country-code picker; auto-detects country by IP. | `hintText`, `textHeading`, `controller`, `validator` |
| `CustomCountryPicker` | Standalone country dropdown with search. | `textHeading`, `onCountryChanged`, `initialCountry`, `required` |
| `CustomSelectSection<T>` | One widget for single **and** multi select — set `SelectionMode.single` or `.multi`. | generic over `T` |
| `DatePickerButton` | Date / time picker styled as a button. | `onDatePicked`, `style`, `icon`, `height` |
| `FileUploadWidget` | Dotted drop zone: pick a file, show name/size, remove it. | `title`, `hint`, `allowedExtensions` |

```dart
CustomTextField(
  textHeading: 'Email'.tr,
  hintText: 'you@example.com',
  controller: controller.emailController,
  validator: Validators.emailValidator.call,
)
```

### `layout/` — structure

| Widget / function | What it does | Key params |
|---|---|---|
| `CardContainer` | Rounded surface with the standard padding and shadow. Your default row/tile wrapper. | **`child`**, `padding`, `margin`, `backgroundColor`, `borderRadius` |
| `SectionHeader` | Title + optional subtitle and trailing action above a group. | **`title`**, `subtitle`, `trailing`, `titleStyle` |
| `CustomDivider` | Themed divider with sane default spacing. | `height`, `thickness`, `color`, `padding` |
| `LoadingWidget` | Centred spinner with an optional message. **Your loading state.** | `message`, `size` |
| `EmptyStateWidget` | Icon + title + optional subtitle and action. **Your empty and error state.** | **`icon`**, **`title`**, `subtitle`, `action` |
| `CustomTextRow` | Label-on-left, value-on-right row for detail screens. | **`label`**, **`value`** |
| `showCustomBottomSheet<T>()` | Themed modal bottom sheet, returns the chosen value. | generic over `T` |

```dart
if (controller.isLoadingOrders.value) return const LoadingWidget();

if (controller.orders.isEmpty) {
  return EmptyStateWidget(
    icon: LucideIcons.inbox,
    title: 'No orders yet'.tr,
    subtitle: 'Your orders will appear here'.tr,
  );
}
```

### `media/` — images

| Widget | What it does | Key params |
|---|---|---|
| `CustomImage` | One widget for network, asset and SVG. Caches, and falls back to a placeholder. | **`image`**, `height`, `width`, `onTap`, `borderColor` |

### `pagination/` — long lists

| Widget | What it does |
|---|---|
| `PaginationView<T>` | Infinite-scroll list: loads the next page near the bottom, and renders its own loading, empty and error states. |
| `PaginationGridView<T>` | The same, as a grid. |

Pair either with `core/helpers/pagination_helper.dart`, which tracks page number, `hasMore` and
the in-flight flag so your controller doesn't have to.

**Adding a widget:** put it in the folder that matches what it does, export it from that folder's
barrel (`buttons/buttons.dart`), and it's reachable through `widgets.dart` everywhere. A loose file
at the widgets root won't be exported.

---

## 6c. Module catalog

Optional features that stay **out of `pubspec.yaml`** until you ask for them — which is why a fresh
clone builds in seconds. Each lives in `modules/<name>/` with its own `README.md`.

```bash
dart run tool/add_module.dart                      # list every module
dart run tool/add_module.dart realtime_socket      # install one
dart run tool/add_module.dart webview --dry-run    # preview first
```

Installing copies the files into `lib/`, adds the dependencies, and prints any platform setup it
can't do for you (API keys, `Info.plist` entries, `AndroidManifest` permissions).

### AI & data

| Module | What it gives you |
|---|---|
| `ai_assistant` | Claude chat client — streaming replies, tool use, conversation state. Talks to **your backend**, which holds the API key. Uses the existing `dio`, no new packages. |
| `offline_first` | Local-first writes with a sync outbox: mutate offline, replay when online, idempotency keys, conflict resolution. |
| `http_cache` | Dio cache interceptor honouring `ETag`, `Cache-Control` and `Vary`, with stale-while-revalidate. |

### Auth & security

| Module | What it gives you |
|---|---|
| `social_auth` | Google and Apple sign-in, returning a token your backend verifies. |
| `secure_storage` | Moves tokens from plaintext prefs into Keychain / EncryptedSharedPreferences, with a one-time migration. |
| `biometric_lock` | Face ID / fingerprint app lock with a background timeout and a safe fallback. |
| `app_attestation` | Play Integrity / App Attest so your backend can tell a real app from a script. Includes cert pinning. |

### Realtime & messaging

| Module | What it gives you |
|---|---|
| `realtime_socket` | Socket.IO client as a `GetxService`: auth-aware connect, backoff reconnect, typed subscriptions. |
| `push_notifications` | FCM + local notifications, with tap-to-route on cold and warm start. |
| `deep_links` | Universal / app links mapped onto `AppRoutes`, with an auth-guard resume. |

### Reliability

| Module | What it gives you |
|---|---|
| `api_resilience` | 429 `Retry-After`, jittered backoff, request dedup, circuit breaker. Retries only idempotent requests. |
| `abuse_guard` | Cooldowns, debounce, single-flight and a failed-login lockout — all persisted. |
| `connectivity_banner` | Offline banner plus an `isOnline` stream for fail-fast checks. |

### Commerce

| Module | What it gives you |
|---|---|
| `payment_stripe` | Stripe PaymentSheet checkout. Publishable key only; your backend creates the intent. |
| `in_app_purchase` | Store subscriptions and one-off purchases, with server-side receipt validation and restore. |

### App lifecycle

| Module | What it gives you |
|---|---|
| `app_update_gate` | Force / soft update gate with proper semver comparison. |
| `crash_analytics` | Sentry wired into the existing error hooks, with PII scrubbed before send. |
| `observability` | Structured logging, `traceparent` propagation, and jank detection. |
| `feature_flags` | Remote config, kill switches, and deterministic A/B bucketing. |
| `background_sync` | WorkManager / BGTaskScheduler periodic work, isolate-safe. |

### UI & design

| Module | What it gives you |
|---|---|
| `design_system` | Design tokens generated from JSON, plus a live component catalog screen. |
| `adaptive_layout` | Phone / tablet / foldable / desktop layouts: nav rail, master-detail, hinge-aware. |
| `settings_ui` | A settings screen driving the theme and language controllers the template already has. |
| `location_picker` | Google Maps + Places picker with a location service. |
| `media_viewer` | Fullscreen image and video gallery with zoom. |
| `webview` | In-app browser with progress, share and external-open. |
| `rich_text_editor` | Quill WYSIWYG field. |
| `html_view` | Renders HTML strings as themed widgets. |

### Quality & reference

| Module | What it gives you |
|---|---|
| `golden_tests` | Visual-regression harness across a device matrix, plus integration tests and a mock `ApiService`. |
| `multi_step_onboarding` | A worked multi-step form: page state, per-step validation, file upload. Copy the structure, replace the fields. |
| `extra_widgets` | Alternate widget implementations kept out of core — other dropdowns, loading and empty variants. |

**Writing your own module:** `modules/README.md` documents the
`modules/<name>/{lib, README.md, module.yaml}` layout. When you strip something from a project,
shelve it as a module instead of deleting it.

---

## 7. The five layers in detail

| Layer | Owns | Must never |
|---|---|---|
| **Screen** | layout, `GetBuilder`/`Obx`, navigation | hold state, call a Repo, build a `TextEditingController`, inline a hex or a raw pixel |
| **Controller** | `Rx*` state, form keys, text controllers, one `final _repo = XRepo();` | construct `ApiService()`, import a widget file |
| **Repo** | endpoint choice, unwrapping `.data` | build a Dio client, decide UI state |
| **Impl** | the HTTP verb, which backend | choose the endpoint — the Repo passes the URL |
| **ApiService** | base URL, auth header, 401 refresh, connectivity, logging | know anything about a feature |

**Why this split earns its keep:** the `Impl` is stubbable without mocking Dio, every URL a feature
touches is visible in one class, and a controller can't accidentally fire at the wrong backend.

---

## 8. Errors — what you must code around

Each failure is handled at the lowest layer that can do something useful about it.

| What went wrong | Who handles it | What you see |
|---|---|---|
| `.env` key missing | `Env.load()` → `bootstrap()` catches | a readable error screen, not a black one |
| No internet | `ApiService.checkInternet()` | warning snackbar; **the call returns `null`** |
| Server error (non-401) | `ApiService.errorHandle()` | logged; **returns `null`** |
| 401, refresh token valid | `ApiService` interceptor | silently refreshes and retries once |
| 401, refresh failed | `ApiService` | tokens cleared, user sent to sign-in |
| Bad JSON | your `try/catch` | up to you — snackbar |
| Widget crash | `ErrorWidget.builder` | red screen in debug, calm box in release |
| Uncaught async | `runZonedGuarded` | `devPrint` with the `Uncaught` tag |

**The four things this means for your code:**

1. **A Repo can return `null`.** Always null-check before parsing.
2. **Always reset loading in `finally`** — an early `return` on null otherwise leaves a spinner forever.
3. **Never sign the user out yourself** on a 401. The interceptor owns that, and it's single-flight:
   twenty parallel 401s trigger exactly one refresh.
4. **User-visible failures go through `showCustomSnackBar`**, never raw `ScaffoldMessenger`.

---

## 9. Storing things

`CacheManager` is the only `SharedPreferences` surface in the app.

```dart
await CacheManager.setToken(token);
final token = CacheManager.token;
await CacheManager.removeAll();          // logout
```

**Adding a value takes two edits:** a `CacheKeys` enum entry, and a getter/setter/remove trio. Never
touch `SharedPreferences` directly — that's how key strings drift apart.

**For the signed-in user, use `UserDi`,** not raw `CacheManager.userData`:

```dart
final user = Get.find<UserDi>();
user.isLoggedIn;  user.isGuest;  user.hasRole('admin');
await user.refreshUser();   // after a profile update
```

Two limits worth knowing: `CacheManager` stores *session facts*, not response bodies — if you need an
offline database, install the `offline_first` module. And never store a password; the
`security_test` guardrail fails the build if you try.

---

## 10. Text and languages

**Keys are the English sentence itself**, not symbolic ids:

```dart
Text('Could not load orders'.tr)
```

A string with no entry renders as readable English instead of `orders.error.load` — so a missed key
degrades gracefully. The trade-off is that duplicates are invisible (`'Login'` and `'Log In'` are two
different keys), which is why the guardrail keeps every locale file in exact sync.

```
localization/
├── app_translations.dart     locale plumbing — add a language with one line in _locales
└── locales/
    ├── en_us.dart            source: every value equals its key
    └── bn_bd.dart            worked example of a translation
```

Three rules that keep it from rotting:

```dart
'Total: '.tr                          // ✗ trailing space in the key
'${'Total'.tr}: '                     // ✓ punctuation lives in the widget

'You have $n orders'.tr               // ✗ interpolation makes a new key every time
'You have @n orders'.trParams({'n': '$n'})   // ✓

class Order { String get label => 'Pending'.tr; }   // ✗ never translate in a model
Text(order.status.tr)                              // ✓ translate where it's shown
```

---

## 11. Guardrails — the tests that keep this true

`test/` holds guardrails, not a coverage target. They exist so the conventions in this file fail
loudly in CI instead of quietly rotting.

```bash
flutter test
```

| Test file | Fails when you… |
|---|---|
| `routes_test.dart` | add a route constant with no `GetPage`, or a duplicate path |
| `bindings_test.dart` | add a controller and forget `ViewModelBinding` |
| `localization_test.dart` | use `.tr` with no key, leave locale files out of sync, or pad a key with whitespace |
| `assets_exist_test.dart` | point `ImageUtils` at a file that isn't there |
| `responsive_test.dart` | write `R.pad(horizontal: R.w(16))` |
| `file_naming_test.dart` | name a file `MyWidget.dart` |
| `security_test.dart` | store a password, bypass TLS, hardcode a key, or use `http://` |
| `no_donor_branding_test.dart` | leave a previous project's name in the code |

A failing guardrail names the file and line. Treat it as a checklist, not an obstacle — it's telling
you which of §3's eight steps you skipped.

---

## 12. I want to… (quick answers)

| I want to | Do this | Not this |
|---|---|---|
| Add a screen | §3 — folder, route, `GetPage`, binding | drop a file in `widgets/` |
| Add an endpoint | constant in `ApiConstant` → `Impl` method → `Repo` method | call `ApiService()` from a controller |
| Add a config value | getter on `Env` + a line in `.env.example` | `dotenv.get(...)` at the call site |
| Add a shared widget | a folder under `widgets/` + export from its barrel | a loose file at the widgets root |
| Add a colour | a method on `CustomColors` returning the light/dark pair | `Color(0xFF...)` in a screen |
| Add a string | `.tr` + the key in **every** locale file | a bare literal |
| Add a language | copy `en_us.dart`, translate, add one line to `_locales` | a second `supportedLocales` list |
| Share a model between features | move it to `core/models/` | import across feature folders |
| Add a big dependency | install a module from `modules/` | grow `pubspec.yaml` for everyone |
| Store a value | `CacheKeys` entry + `CacheManager` trio | `SharedPreferences` directly |
| Change the Repo return type | don't | `Result<T>` / `Either` |

**Optional features live in `modules/`** — 31 of them, installed on demand:

```bash
dart run tool/add_module.dart                  # list them
dart run tool/add_module.dart realtime_socket  # install one
```

Socket.IO, push notifications, Stripe, offline sync, maps, an AI chat client and more. They stay out
of `pubspec.yaml` until you ask for them, which is why a fresh clone builds in seconds.

---

## 13. Startup order

You will rarely touch this, but when something breaks before the first frame, this is the order.

```
main()  →  bootstrap()                       lib/bootstrap.dart, inside runZonedGuarded
             ├─ FlutterError.onError + ErrorWidget.builder
             ├─ await Env.load()             throws EnvException if a required key is missing
             ├─ await CacheManager.init()    SharedPreferences handle
             ├─ SystemChrome                 orientation + status bar
             ├─ IpLocationService.preload()  fire-and-forget, never awaited
             ├─ ViewModelBinding().dependencies()
             └─ runApp(App())                app.dart → GetMaterialApp
```

`App` wires `AppPages.pages`, `AppPages.unknownRoute`, `AppTranslations`, the Material localisation
delegates, and light/dark themes driven by `ThemeController` — wrapped in `Obx` so a theme change
rebuilds the `GetMaterialApp` itself.

**Anything that must finish before the first frame goes in `bootstrap()`** — not in `main()`, and not
in `App.build`.

### Configuration

| Concern | Owner | Notes |
|---|---|---|
| `.env` values | `Env` | `requiredKeys` abort startup when missing; everything else via `Env.optional(key)` |
| Build flavor | `AppFlavor` | `--dart-define=FLAVOR=dev\|staging\|prod`; no flag ⇒ release is prod, else dev |
| Hosts + endpoints | `ApiConstant` | `activeBaseUrl` resolves per flavor |

```dart
dotenv.get('BASE_URL')          // ✗ never
Env.baseUrl                     // ✓ typed, fails fast
ApiConstant.activeBaseUrl       // ✓ at a call site — respects the flavor
```

Every new key needs a getter on `Env` **and** a placeholder line in `.env.example`. `.env` itself is
gitignored and holds live keys — it never gets committed.
