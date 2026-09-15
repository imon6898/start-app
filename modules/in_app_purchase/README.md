# in_app_purchase

Subscriptions and one-time purchases through the App Store and Google Play. On mobile this is not one payment option among several — for digital goods it is **the only one Apple allows** (see [Why Stripe cannot be used](#why-stripe-cannot-be-used-for-digital-goods-on-ios)).

**Read this first: receipt validation is server-side, and that is not negotiable.**

The store tells the app that money moved. It does not tell the app who is allowed to use the paid feature — your backend does, after it hands the receipt to Apple or Google and gets a signed answer. Any client that decides its own entitlement is bypassed in about five minutes: someone patches the binary, `purchased == true` returns true, and your paid tier is free. What a patched app *cannot* do is forge a receipt Apple or Google will vouch for.

So this module is built around one rule: **the client carries the receipt, the server decides.** `PurchasesService` never sets an entitlement from a store response. It posts the receipt to your API, and whatever comes back is the answer.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/purchases_service.dart` | `PurchasesService` — the `GetxService`. Owns the purchase stream from launch, verifies every receipt against your backend, holds the `Rx` entitlement, exposes `buy` / `restore` / `refreshEntitlement` / `hasAccess`. |
| `lib/app/feature/purchases/purchases_logic/purchases_store_client.dart` | `PurchasesStoreClient` — the only file that imports `in_app_purchase`. Every method is overridable so tests can fake the store. |
| `lib/app/feature/purchases/purchases_logic/purchases_api_service.dart` | `PurchasesApiService` / `PurchasesImpl` / `PurchasesRepo` — the Style-A trio for the three backend endpoints. |
| `lib/app/feature/purchases/purchases_logic/purchases_api_const.dart` | `PurchasesApiConst` — the endpoints, kept out of core `api_const.dart`. |
| `lib/app/feature/purchases/purchases_logic/purchases_catalog.dart` | `PurchasesCatalog`, `PurchaseProductConfig`, `PurchaseKind` — which product ids exist and how each must be bought. |
| `lib/app/feature/purchases/purchases_logic/entitlement_store.dart` | `EntitlementStore` — the offline entitlement cache, with a staleness cap. Own `SharedPreferences` handle, no `CacheManager` edit. |
| `lib/app/feature/purchases/purchases_models/entitlement_model.dart` | `EntitlementModel`, `EntitlementState` — the server's verdict, tolerant `fromJson`, `toJson` for the cache. |
| `lib/app/feature/purchases/purchases_models/purchase_outcome.dart` | `PurchaseOutcome` — sealed result the UI switches on exhaustively. |
| `lib/app/feature/purchases/purchases_controllers/paywall_controller.dart` | `PaywallController` — tile selection, snackbars per outcome. No store or network code. |
| `lib/app/feature/purchases/purchases_presentation/paywall_screen.dart` | `PaywallScreen` — plans, restore, legal links, renewal disclosure. |
| `lib/app/feature/purchases/purchases_presentation/purchases_widgets/purchase_product_tile.dart` | `PurchaseProductTile` — one selectable plan, priced from the store. |
| `lib/app/feature/purchases/purchases_presentation/purchases_widgets/entitlement_banner.dart` | `EntitlementBanner` — active / trial / grace / on-hold / paused / expired / refunded, plus the offline notice. |
| `test/unit/purchases_test.dart` | 24 tests: parsing, access rules, cache staleness, catalog. No channels, no network. |
| `test/widget/paywall_screen_test.dart` | 6 tests on the degraded path: no store, no products, restore and legal links still present, hung query falls back to the empty state. |

## Install

```bash
dart run tool/add_module.dart in_app_purchase
flutter pub get
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
mkdir -p lib/app/feature/purchases/{purchases_logic,purchases_models,purchases_controllers,purchases_presentation/purchases_widgets}
cp -R modules/in_app_purchase/lib/app/feature/purchases/. lib/app/feature/purchases/
cp modules/in_app_purchase/lib/app/services/purchases_service.dart  lib/app/services/
cp modules/in_app_purchase/test/unit/purchases_test.dart            test/unit/
cp modules/in_app_purchase/test/widget/paywall_screen_test.dart     test/widget/
```

### pubspec.yaml

```yaml
dependencies:
  in_app_purchase: ^3.3.0
```

That is the whole list. `get`, `intl`, `shared_preferences` and `lucide_icons_flutter` are already in the template core. You do **not** need `in_app_purchase_android` or `in_app_purchase_storekit` as direct dependencies — nothing here imports them, which is why the module works with the plain façade.

### Environment (`.env`)

All optional. With zero `.env` changes the catalog falls back to the placeholder ids in `purchases_catalog.dart`, which the store will report in `notFoundIDs` until you create the real ones. Add placeholders to `.env.example` for whichever you use:

```dotenv
IAP_SUBSCRIPTION_IDS=pro_monthly,pro_yearly
IAP_NON_CONSUMABLE_IDS=pro_lifetime
IAP_CONSUMABLE_IDS=
```

Read through `Env.optional(...)`, so **no `Env` getter needs adding** and `Env.requiredKeys` is untouched. Calling `PurchasesCatalog.configure([...])` from bootstrap overrides both.

## Platform config

### Android

`android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

```xml
    <uses-permission android:name="com.android.vending.BILLING" />
```

- **`minSdk` 21 or higher.** The plugin bundles Play Billing Library 8.0.0.
- The build must be **uploaded to a Play Console track** (internal testing is enough) and signed with the same key. A debug build side-loaded over `adb` with a different signature resolves **no products at all**.
- Products live in **Play Console → Monetise with Play → Products**. A subscription needs at least one **active base plan**; a product with no active base plan is invisible to `queryProductDetails`.
- Add testers under **Play Console → Monetise with Play → Setup → Licence testing** so their purchases are not charged and renew on a compressed schedule (a monthly subscription renews every 5 minutes for a licence tester).

### iOS

- **iOS 13.0 minimum** in `ios/Podfile` and the Runner deployment target.
- **App Store Connect → Business → Paid Applications Agreement must be ACTIVE.** Until it is, `queryProductDetails` returns an empty list *with no error*, which is the single most common "my products don't load" cause.
- Products live in **App Store Connect → your app → Subscriptions / In-App Purchases**. Fill in *every* metadata field including the review screenshot and localisation, then get each one to **Ready to Submit**. An incomplete product is not queryable.
- Subscriptions need a **subscription group**. Plans in one group are upgrade/downgrade paths for each other; plans in different groups can be owned at the same time.
- Create a sandbox tester under **Users and Access → Sandbox → Test Accounts**. On the device, sign out of the real App Store account first (**Settings → App Store → Sandbox Account** on iOS 14+), then buy — the sandbox prompt appears at purchase time.
- Sandbox subscription periods are compressed: 1 week renews every 3 minutes, 1 month every 5, 1 year every hour, and a sandbox subscription auto-cancels after 6 renewals. Do not read those as bugs.
- **StoreKit 2 is the default** in `in_app_purchase_storekit` 0.4.x. That changes the receipt format your backend receives — see [Backend contract](#backend-contract).

### macOS

Same StoreKit implementation. Add the **In-App Payments** entitlement to both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`.

## Wiring

Four core files change, plus the two locale maps.

**1. `lib/bootstrap.dart`** — add the imports:

```dart
import 'package:get/get.dart';
```

```dart
import 'app/services/purchases_service.dart';
```

Then, right after `await CacheManager.init();`:

```dart
    // Subscribes to the purchase stream before the first frame, so an
    // interrupted purchase is picked up on launch.
    await Get.putAsync(() => PurchasesService().init(), permanent: true);
```

**Placement matters.** The plugin delivers an unfinished transaction as soon as the stream has a listener. A user who paid and then killed the app mid-flight only gets their access when that event is caught — register late and the event fires before anyone is listening. `PurchasesService.ensure()` will register it lazily if you skip this step (so the paywall still works), but it logs a warning and the launch-time replay is missed.

**2. `lib/app/bindings/view_model_binding.dart`** — add the import, then register the controller inside `dependencies()`:

```dart
import '../feature/purchases/purchases_controllers/paywall_controller.dart';
```

```dart
    // Purchases
    _lazy<PaywallController>(() => PaywallController());
```

`_lazy` already passes `fenix: true`. `PurchasesService` is a `GetxService`, not a screen controller, so `test/guardrails/bindings_test.dart` does not ask for it — it goes in bootstrap with `permanent: true` instead.

**3. `lib/app/routes/app_routes.dart`** — add the constant:

```dart
  /// Purchases
  static const String PaywallScreen = '/paywallScreen';
```

**4. `lib/app/routes/app_pages.dart`** — add the import next to the others, and the page inside `AppPages.pages`:

```dart
import '../feature/purchases/purchases_presentation/paywall_screen.dart';
```

```dart
    // Purchases
    _page(AppRoutes.PaywallScreen, () => const PaywallScreen()),
```

`AppRoutes.TermsOfServiceScreen` and `AppRoutes.PrivacyPolicyScreen` already exist in core — the paywall links to them by default, so there is nothing to add for the legal links.

**5. `lib/app/localization/locales/en_us.dart` and `bn_bd.dart`** — append this block to **both** files, just before the closing `};`. The localization guardrail requires every `.tr` string to have an `en_US` entry *and* every locale to carry exactly the same keys, so pasting it in only one file fails `flutter test`. Translate the `bn_bd` values later; English placeholders pass:

```dart
  // Purchases
  'Subscription': 'Subscription',
  'Loading plans': 'Loading plans',
  'No plans available': 'No plans available',
  'The store returned no products. Check the product ids and that the build is signed with the right bundle id.':
      'The store returned no products. Check the product ids and that the build is signed with the right bundle id.',
  'Try again': 'Try again',
  'One-time purchase': 'One-time purchase',
  'Change plan': 'Change plan',
  'Restore purchases': 'Restore purchases',
  'Restoring…': 'Restoring…',
  'Manage': 'Manage',
  'Terms of Service': 'Terms of Service',
  'Payment is charged to your store account at confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the period ends. Manage or cancel in your store account settings.':
      'Payment is charged to your store account at confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the period ends. Manage or cancel in your store account settings.',
  'In-app purchases are not available on this device':
      'In-app purchases are not available on this device',
  'A payment is waiting for approval. Access unlocks automatically once the store settles it.':
      'A payment is waiting for approval. Access unlocks automatically once the store settles it.',
  'Unknown product ids': 'Unknown product ids',
  'Subscription active': 'Subscription active',
  'Free trial active': 'Free trial active',
  'Payment problem': 'Payment problem',
  'Subscription on hold': 'Subscription on hold',
  'Subscription paused': 'Subscription paused',
  'Subscription expired': 'Subscription expired',
  'Purchase refunded': 'Purchase refunded',
  'Waiting for approval': 'Waiting for approval',
  'Renews on': 'Renews on',
  'Access ends on': 'Access ends on',
  'Offline — using the last confirmed status':
      'Offline — using the last confirmed status',
  'Offline — last confirmed': 'Offline — last confirmed',
  'days ago': 'days ago',
  'Purchases restored': 'Purchases restored',
  'You are all set': 'You are all set',
  'Your subscription is active': 'Your subscription is active',
  'The store has not completed this payment yet. Access unlocks as soon as it does.':
      'The store has not completed this payment yet. Access unlocks as soon as it does.',
  'Purchase cancelled': 'Purchase cancelled',
  'Nothing was charged': 'Nothing was charged',
  'Could not confirm the purchase': 'Could not confirm the purchase',
  'The store charge was not accepted. Contact support with your receipt.':
      'The store charge was not accepted. Contact support with your receipt.',
  'You were charged but we could not reach the server. It will finish automatically.':
      'You were charged but we could not reach the server. It will finish automatically.',
  'Purchase failed': 'Purchase failed',
  'Nothing to restore': 'Nothing to restore',
  'This store account has no previous purchase':
      'This store account has no previous purchase',
  'Store unavailable': 'Store unavailable',
```

`Continue` and `Privacy Policy` are already in the template's locales and are reused as-is — don't paste them again, a duplicate key in a `const` map is a Dart compile error.

The `PaywallScreen` constructor defaults (`Go Pro`, `Unlock everything, cancel any time`, `Unlimited projects`, `Priority support`, `No ads`, and the `Best value` badge) are `.tr`'d at runtime but their literals live in a `const` default, so the guardrail cannot see them and they fall through to the English key. That is intentional — they are placeholder marketing copy you will replace. Add locale entries once your real copy is settled.

**6. Sign-out** — wherever you clear the session, next to `CacheManager.removeAll()`:

```dart
await Get.find<PurchasesService>().clear();
```

Without it the next account on the device inherits the previous user's cached entitlement until the server contradicts it.

Verified end to end: with these steps applied, `flutter analyze` reports 0 issues and `flutter test` is **75 passing** (45 template + 30 from this module).

## Backend contract

Three endpoints on **your** API. None of them exists in the template, and the module is useless without them — this is the same shape as `payment_stripe`, for the same reason: the credential that can verify a purchase must never be in the app.

### `POST /billing/purchases/verify`

Sent once per purchased or restored transaction.

```json
{
  "platform": "ios",
  "source": "app_store",
  "product_id": "pro_yearly",
  "purchase_id": "2000000512345678",
  "transaction_date": "1767225845000",
  "receipt": "<serverVerificationData>",
  "is_restore": false
}
```

The server must:

1. **Authenticate the caller.** The module sends `Authorization: Bearer <CacheManager.token>` — the same session token as the rest of the app. Reject anything else, or one user's receipt grants another user access.
2. **Verify the receipt with the store** (below). Never trust `product_id` from the body — read it out of the verified receipt.
3. **Reject a replay.** Store the transaction id (`originalTransactionId` on Apple, `orderId`/purchase token on Google) with a unique index. A receipt already bound to a different account is fraud, not a restore.
4. **Return the entitlement** in the template's `BaseResponse` envelope:

```json
{
  "status": true,
  "statusCode": 200,
  "message": "",
  "path": "/billing/purchases/verify",
  "data": {
    "active": true,
    "state": "active",
    "product_id": "pro_yearly",
    "tier": "pro",
    "expires_at": "2027-01-02T03:04:05Z",
    "will_renew": true,
    "store": "app_store"
  }
}
```

`state` accepts `active`, `trial`/`in_trial`, `grace_period`, `on_hold`, `paused`, `expired`/`cancelled`, `refunded`/`revoked`/`chargeback`, `pending`/`deferred`. `expires_at` takes ISO-8601, epoch seconds, or epoch milliseconds (so Apple's `expires_date_ms` can be passed straight through). Keys are read snake_case first, camelCase second.

A `200` with `active: false` is an **explicit refusal** and the client finishes the transaction. A non-200, a timeout, or an unreachable host leaves the transaction open for retry. Do not answer `active: false` for a transient failure — you would burn a real receipt.

### `GET /billing/entitlement`

The source of truth. Called on launch, on paywall open, and after a restore. Returns the same `data` object. This is what picks up a renewal, a cancellation, a refund or an expiry that happened while the app was closed — your webhook learned about it, the device did not.

### `POST /billing/purchases/sync`

Batch variant for restore, wired through `PurchasesRepo.syncPurchases`. `PurchasesService` does not call it by default (restore verifies each receipt individually and then re-reads the entitlement), but the Repo method is there for a backend that prefers one round trip.

### Verifying with the stores

| Platform | What `serverVerificationData` contains | What the server calls |
| --- | --- | --- |
| Android | the Play **purchase token** | Play Developer API: `GET /androidpublisher/v3/applications/{package}/purchases/subscriptionsv2/tokens/{token}` for subscriptions, `.../purchases/products/{productId}/tokens/{token}` for one-time products. Authenticate with a service account granted **View financial data** in Play Console. |
| iOS / macOS, **StoreKit 2** (the default) | the **JWS signed transaction** | Verify the JWS signature against Apple's root certificates, or call the **App Store Server API** (`api.storekit.itunes.apple.com`, sandbox `api.storekit-sandbox.itunes.apple.com`) with a signed JWT from an App Store Connect API key. |
| iOS / macOS, **StoreKit 1** (opt-in) | the **base64 app receipt** | The legacy `verifyReceipt` endpoint (`buy.itunes.apple.com` / `sandbox.itunes.apple.com`), or decode the receipt yourself. Apple has deprecated `verifyReceipt`; new work should target the Server API. |

**This table is the usual cause of "verification always fails".** Teams write the backend for a base64 app receipt, the plugin ships StoreKit 2, and the server gets a JWS it cannot parse. Confirm which one you are on before blaming the client. Store endpoints and API shapes change — check Apple's and Google's current docs rather than trusting this table forever.

### Webhooks — not optional

A renewal, a cancellation, a refund and a subscription going on hold all happen **while your app is closed**. There is no client event for them. Both stores will tell your server if you ask:

- **Apple — App Store Server Notifications V2.** Set the production and sandbox URLs in App Store Connect. Apple POSTs a `signedPayload` (JWS); verify it, then update the entitlement. `DID_RENEW`, `EXPIRED`, `DID_FAIL_TO_RENEW` (grace period), `REFUND`, `REVOKE`, `GRACE_PERIOD_EXPIRED` are the ones that matter.
- **Google — Real-time developer notifications.** Create a Cloud Pub/Sub topic and set it in Play Console → Monetisation setup. Google publishes `SUBSCRIPTION_RENEWED`, `SUBSCRIPTION_CANCELED`, `SUBSCRIPTION_EXPIRED`, `SUBSCRIPTION_IN_GRACE_PERIOD`, `SUBSCRIPTION_ON_HOLD`, `SUBSCRIPTION_PAUSED` and `VOIDED_PURCHASE`.

Without them, a user who cancelled or was refunded keeps access until the next time the client happens to ask — and a refunded user who never opens the app keeps it forever.

## Usage

### Gating a feature

```dart
final PurchasesService purchases = Get.find<PurchasesService>();

Obx(() => purchases.entitlement.value.grantsAccess
    ? const ProContent()
    : UpgradePrompt(onTap: () => Get.toNamed(AppRoutes.PaywallScreen)));
```

`purchases.hasAccess` is the same check plus the local expiry, for non-reactive code:

```dart
if (!purchases.hasAccess) {
  Get.toNamed(AppRoutes.PaywallScreen);
  return;
}
```

### Opening the paywall

```dart
Get.toNamed(AppRoutes.PaywallScreen);
```

Or with your own copy:

```dart
Get.to(() => PaywallScreen(
      headline: 'Unlock Pro',
      subhead: 'Everything, on every device',
      benefits: const ['Unlimited exports', 'Offline maps', 'Priority support'],
      onManageSubscription: _openStoreSubscriptions,
    ));
```

### Your own product ids

Either the `.env` keys above, or in `bootstrap()` before `runApp`:

```dart
PurchasesCatalog.configure(const [
  PurchaseProductConfig(id: 'com.acme.pro.monthly', kind: PurchaseKind.subscription),
  PurchaseProductConfig(
    id: 'com.acme.pro.yearly',
    kind: PurchaseKind.subscription,
    badge: 'Save 40%',
    highlighted: true,
  ),
  PurchaseProductConfig(id: 'com.acme.pro.lifetime', kind: PurchaseKind.nonConsumable),
  PurchaseProductConfig(id: 'com.acme.credits.100', kind: PurchaseKind.consumable),
]);
```

`kind` is not cosmetic. `consumable` routes through `buyConsumable(autoConsume: true)` so the product can be bought again; `nonConsumable` and `subscription` go through `buyNonConsumable`. Get it wrong and a coin pack can only ever be bought once.

### Restore

Already on the paywall, and required there. To trigger it from elsewhere (a settings row, a support flow):

```dart
await Get.find<PurchasesService>().restore();
```

### Reacting to an outcome yourself

```dart
final sub = purchases.outcomes.listen((outcome) {
  switch (outcome) {
    case PurchaseGranted(restored: final bool restored):
      Get.back();
      if (!restored) Get.toNamed(AppRoutes.DashboardScreen);
    case PurchaseAwaitingApproval():
      // Ask to Buy / cash payment. Nothing to unlock yet.
      break;
    case PurchaseUnverified(serverReachable: false):
      // Charged, not yet confirmed. It retries on its own.
      break;
    case PurchaseUnverified() ||
          PurchaseFailed() ||
          PurchaseCancelled() ||
          PurchaseNothingToRestore() ||
          PurchaseStoreUnavailable():
      break;
  }
});
// Cancel it in onClose().
```

`PurchaseOutcome` is `sealed`, so a new case makes the switch a compile error rather than a silent fall-through.

### Linking a purchase to your user

```dart
// An opaque hash. Apple and Google both forbid putting an email here.
purchases.applicationUserName = sha256Hex(userId);
```

On Android this lands in `accountId` on the billing flow; on iOS it is the `applicationUserName` and must be passed to `restorePurchases` too, which the service does automatically.

### Manage / cancel subscription

Neither store lets an app cancel a subscription; you deep-link to the store. `url_launcher` is not in core, so pass a callback:

```dart
Future<void> _openStoreSubscriptions() async {
  final url = Platform.isIOS
      ? 'https://apps.apple.com/account/subscriptions'
      : 'https://play.google.com/store/account/subscriptions'
          '?sku=${purchases.entitlement.value.productId}'
          '&package=com.acme.app';
  await launchUrlString(url, mode: LaunchMode.externalApplication);
}
```

Install **settings_ui** or **webview** if you want `url_launcher` in the project, and remember the `<queries>` note in `modules/README.md`.

## Behaviour, exactly

**The stream is the API, not the return value.** `buy()` kicks off a native modal and returns `true` only meaning *the request reached the store*. The result arrives later on `purchaseStream`. `PurchasesService.buy()` bridges that: it registers a `Completer` keyed by product id, the stream handler completes it, and the caller gets a single `PurchaseOutcome`. After `purchaseTimeout` (3 minutes) it resolves as `PurchaseAwaitingApproval` — long enough for a user reading the 3DS SMS, short enough not to leak a pending future forever. A later settled event still reaches `outcomes`.

**Launch-time replay.** Registering in bootstrap is what makes an interrupted purchase work: the user paid, the app died before the receipt was verified, and on the next launch the store re-delivers the transaction. The service verifies it and grants access with no user action at all. Subscribe late and you miss the event.

**Pending and deferred.** `PurchaseStatus.pending` means the store accepted the order but has not settled it — Ask to Buy waiting for a parent, a cash/voucher payment in Play, a card needing extra authentication. The purchase is recorded in `awaitingApproval` and the paywall says so. It is **never** completed: `completePurchase` on a pending purchase throws. A second stream event arrives when the payment settles (which may be days later, in a different app session), and that is what grants access.

**Completion is ordered on purpose.** `completePurchase` is what removes the transaction from the store queue. The service calls it:

- **after** the server has granted the entitlement — so if verification fails, the receipt stays in the queue and is retried on the next launch instead of being thrown away;
- **also** on an explicit server refusal (a `200` with `active: false`) — so the store stops re-delivering a receipt that will never be accepted, and Google does not auto-refund an unacknowledged purchase after three days;
- **never** for `pending`, and never for `canceled`/`error`. With StoreKit 2 `completePurchase` resolves `Transaction.finish(int.parse(purchaseID))`, and a cancelled purchase has no transaction id — completing it would throw. On Android the plugin asserts the purchase is a `GooglePlayPurchaseDetails`, which an error event may not be.

On iOS a transaction you never complete is re-delivered on **every** launch and makes the next purchase of the same product fail with a duplicate-transaction error. That is the bug behind most "the second purchase never works" reports.

**Restore.** `restorePurchases()` replays owned non-consumables and active subscriptions onto the stream with `PurchaseStatus.restored`, each of which is verified like a fresh purchase. Two platform differences the module smooths over:

- **iOS emits nothing when there is nothing to restore.** No event, no error, no completion. Waiting on the stream would hang forever, so restore waits `restoreGrace` (8 s), then asks `GET /billing/entitlement` and reports `PurchaseNothingToRestore` if access still is not granted.
- **Android throws.** A failed `queryPurchases` raises `InAppPurchaseException`, which is caught and surfaced as `PurchaseFailed`.

**Entitlement refresh.** On launch, on paywall open, and after restore, the service calls `GET /billing/entitlement` and overwrites local state with the answer. Server wins, always — including when the server says access is gone.

**Offline.** The last granted entitlement is cached by `EntitlementStore` and loaded before the first frame, so a plane-mode launch does not lock a paying user out. The cache is withheld once it is older than `EntitlementStore.maxCacheAge` (7 days), and `grantsAccessAt(DateTime.now())` also respects `expires_at`. The paywall shows a "last confirmed N days ago" line whenever it is running on cached data.

**Product loading.** `queryProductDetails` is called with every id in the catalog. Ids the store does not know come back in `notFoundIDs` and are shown on the paywall as `Unknown product ids` — during setup that list is your fastest diagnostic. The query is capped at `productQueryTimeout` (20 s) so a store that never answers shows the empty state with a retry instead of an endless spinner.

**Prices come from the store.** `ProductDetails.price` is already formatted in the user's currency and locale. Never hardcode a price or do your own currency maths on `rawPrice` — App Store review rejects a mismatch between the displayed price and the charged one.

## Why Stripe cannot be used for digital goods on iOS

App Store Review Guideline **3.1.1** requires in-app purchase for unlocking features, content, subscriptions or anything consumed inside the app. A Stripe (or PayPal, or your own card form) checkout for a digital subscription is a **guaranteed rejection**, and shipping a link out to a web checkout to dodge it has its own narrow rules (3.1.3 "reader" apps, external purchase entitlements in some jurisdictions) that almost certainly do not apply to you.

The dividing line is what the user gets:

| Selling… | Use |
| --- | --- |
| Subscriptions, premium features, ad removal, in-game currency, extra storage | **this module** |
| Physical goods, food delivery, ride-hailing, real-world services, person-to-person payments | **payment_stripe** |

Google Play's Payments policy is equivalent for digital goods, with more exceptions and an alternative-billing programme in some regions. The practical answer is the same: digital goods go through the stores.

The 15–30% store fee is the cost of the only route Apple permits. Budget for it; do not architect around it.

## What this does NOT protect against

- **Nothing here is enforcement.** Every guard in this module is a UI decision on a device the user controls. `hasAccess`, `grantsAccess`, the whole `EntitlementModel` — a patched binary returns whatever it likes from all of it. The only real gate is your server refusing to serve paid content to an account it has not granted. **Gate the data, not the screen.** If the paid feature is purely local (an offline filter, a theme), accept that a determined user will get it for free; that is the honest ceiling on client-side gating.
- **The device clock is not a source of truth.** `grantsAccessAt` compares `expires_at` to `DateTime.now()`, which a user can move. It exists to stop an honest cached entitlement outliving its term, not to stop anyone.
- **The offline cache is a window of trust.** For up to `maxCacheAge` (7 days) a user who cancels and then stays offline keeps access. Shorten it if that matters more to you than travellers keeping their subscription; there is no setting that gives you both.
- **Receipt verification is only as good as your backend.** A server that returns `active: true` without calling Apple or Google has changed nothing — the receipt is now just a longer password. Verify the signature, check the bundle id / package name, bind the transaction to exactly one account, and reject a replay.
- **A refund is invisible to the client.** Apple and Google refund without telling the app. Only the webhook catches it. Without one, a refunded user keeps paid access indefinitely.
- **`is_restore` is a hint, not a claim.** It comes from the client and can be flipped. The server must decide whether a receipt is a restore by looking up the transaction id it already stored.
- **Consumables are not restorable.** `restorePurchases` never returns a consumed product — Apple and Google consider it gone. If a user must not lose their coin balance on reinstall, that balance lives on your server, and this module's job ends at telling the server that a coin pack was bought.
- **Android subscriptions can return several `ProductDetails` for one id.** One entry per base-plan/offer combination, each with its own `offerToken`, all sharing the same `id`. The paywall renders them all and the plugin picks the right offer token automatically, but if you want to show only one you must filter — and if you want to *label* the base plans (billing period, intro pricing) you need `GooglePlayProductDetails.productDetails.subscriptionOfferDetails`, which means adding `in_app_purchase_android` as a direct dependency. This module deliberately does not.
- **Upgrades, downgrades and proration are not implemented.** Changing between plans in one subscription group works on iOS by simply buying the other product; on Android it needs `ChangeSubscriptionParam` with a `replacementMode`, which requires the `in_app_purchase_android` package. The paywall's "Change plan" button starts a plain purchase — correct on iOS, and on Android only correct for a same-group change your backend then reconciles.
- **Promo codes, offer codes and win-back offers are not wired up.** They exist in the plugin (`presentCodeRedemptionSheet`, `Sk2PurchaseParam.fromOffer`, `isIntroductoryOfferEligible`) but need the platform packages.
- **`isAvailable() == false` is not always an error.** An emulator without Play Services, a device with parental restrictions, and a signed-out store account all report it. The paywall says so rather than pretending the buy button will work.

## Notes and gotchas

- **`PurchasesStoreClient` is the seam.** Every plugin call goes through it and `InAppPurchase.instance` is a lazy getter, so a test subclass never triggers platform registration. That is why the shipped tests touch no channels.
- `PurchasesService.init()` is idempotent, so a stray `ensure()` cannot open a second stream subscription.
- Stream events are serialised through an internal future chain. Two receipts arriving in one event never verify concurrently — which matters because both would write the same entitlement.
- `PurchasesRepo` returns `null` when `ApiService` returned `null` (the offline guard), rather than blowing up on `response.data`. `refreshEntitlement` treats that as "keep the cache", not "access revoked".
- The entitlement cache lives in plain `SharedPreferences` on purpose. It is not a secret — the server re-checks it, and moving it to the Keychain would protect nothing while adding a `MethodChannel` read to the first-frame path. If you install **secure_storage** anyway, note that `EntitlementStore` is read synchronously after `init()` for exactly that reason.
- `EntitlementState.parse` maps unknown strings to `none`, never to `active`. A backend typo costs a user their access until you fix it, which is the right direction to fail.
- The paywall's product tiles use `ProductDetails.title` and `.description` straight from the store, so your App Store Connect / Play Console copy *is* the paywall copy. Write it there, not in Dart.
- `flutter test test/unit/purchases_test.dart` is pure logic. `flutter test test/widget/paywall_screen_test.dart` overrides `PurchasesService.productQueryTimeout` to 50 ms so it can pump past the timeout — without that a pending timer outlives the test and `flutter_test` fails the run.
- **You cannot test purchases in the simulator or on a fresh debug APK.** iOS needs a real device with a sandbox account (StoreKit Testing in Xcode works in the simulator but bypasses the plugin's server path). Android needs a Play-installed build from a console track. Budget setup time before assuming the code is broken.

## Why it is not in core

Most apps built from this template never sell anything, and the ones that do are split between digital goods (this module) and physical goods (`payment_stripe`) — shipping both in core would put `com.android.vending.BILLING` and a StoreKit dependency in every project that has no products at all.

More importantly, this module cannot work alone. It needs three endpoints and two webhooks on a backend that holds an App Store Connect API key and a Play service account, plus completed product metadata in two consoles and an active Paid Applications Agreement. A core feature that is inert until a week of store admin is done is not a core feature — it is an opt-in with a checklist. The checklist is above.
