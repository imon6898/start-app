# payment_stripe

Stripe PaymentSheet checkout in the feature-first GetX layout — checkout screen, result screen, sealed
`PaymentResult`, and a Repo/Impl/ApiService trio that asks **your** backend for the `client_secret`.

---

## ⚠️ SECURITY — read this before anything else

This module is built around one rule: **a Stripe secret key must never exist inside a mobile app.**

An `sk_...` key compiled into an APK or IPA is extractable with `strings` in about ten seconds. Whoever
pulls it out can create charges, issue refunds, read your customer list and drain the account. There is
no obfuscation that fixes this — the binary runs on the attacker's device.

The four-point flow this module implements:

1. **Your backend creates the PaymentIntent.** It calls Stripe with the secret key and returns *only*
   the `client_secret`.
2. **The app only ever sees the publishable key + the client_secret.** `pk_...` is safe to ship; it can
   confirm a payment that the server already authorised and nothing else. `PaymentController._initStripe()`
   rejects any key that does not start with `pk_` — an `sk_` key in `.env` disables payments rather than
   leaking.
3. **The amount and currency are decided SERVER-side.** `CheckoutScreen` sends an amount, but it is a
   display hint for the order only. Re-derive the real charge on the server from the cart / plan / order
   id. A client-chosen amount is a client-chosen price.
4. **The webhook is the source of truth for fulfilment.** `PaymentSuccess` means the sheet closed without
   throwing — not that money settled. Ship the goods, grant the entitlement and mark the order paid from
   your `payment_intent.succeeded` webhook handler, never from the app's callback.

There is no `api.stripe.com` call anywhere in this module. Both endpoints in `PaymentApiConst` are
relative paths on your own backend, resolved through the template's `ApiService`.

---

## Install

```bash
dart run tool/add_module.dart payment_stripe --dry-run   # see the plan
dart run tool/add_module.dart payment_stripe             # install
flutter pub get
```

The installer copies seven files and appends `flutter_stripe` to `pubspec.yaml`. Everything below the
install line is manual.

### Files it installs

```
lib/app/feature/payment/
├── payment_models/payment_intent_model.dart
├── payment_models/payment_result.dart
├── payment_logic/payment_api_const.dart
├── payment_logic/payment_api_service.dart
├── payment_controllers/payment_controller.dart
├── payment_presentation/checkout_screen.dart
└── payment_presentation/payment_result_screen.dart
```

### pubspec.yaml

The installer adds this for you; here it is verbatim in case you are wiring it by hand:

```yaml
dependencies:
  # payment_stripe module
  flutter_stripe: ^12.6.0
```

`flutter_stripe` 12.6.0 requires Dart SDK `>=3.8.1` — the template is on 3.12.2, so no SDK bump is needed.

---

## Backend contract

Two endpoints on **your** server. Paths come from `PaymentApiConst` and are relative to `ApiService`'s
base URL.

### `POST /pay/stripe/payment-intent`

Request the app sends:

```json
{
  "amount": 2900,
  "currency": "usd",
  "description": "Pro plan"
}
```

Treat `amount` as a hint. Look up the real price server-side.

Response the app parses (the template's standard `BaseResponse` envelope):

```json
{
  "success": true,
  "message": "",
  "data": {
    "client_secret": "pi_3Xxxxx_secret_Yyyyy",
    "payment_intent_id": "pi_3Xxxxx",
    "amount": 2900,
    "currency": "usd",
    "status": "requires_payment_method"
  }
}
```

`customer_id` and `ephemeral_key` are optional — send them only if you created a Stripe Customer and an
ephemeral key, and the sheet will offer saved cards.

### `GET /pay/stripe/payment-status?payment_intent_id=pi_3Xxxxx`

Same envelope; `data.status` is whatever your webhook last recorded. This is a read-back for the UI, not
an authorisation check.

### Server-side, in Node

```js
// npm i stripe express
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY); // sk_... SERVER ONLY

app.post('/pay/stripe/payment-intent', requireAuth, async (req, res) => {
  // Never trust req.body.amount — derive the real figure from your own data.
  const order = await Orders.findForUser(req.user.id, req.body.order_id);
  const intent = await stripe.paymentIntents.create({
    amount: order.totalMinorUnits,
    currency: order.currency,
    metadata: { order_id: order.id, user_id: req.user.id },
    automatic_payment_methods: { enabled: true },
  });

  res.json({
    success: true,
    message: '',
    data: {
      client_secret: intent.client_secret,
      payment_intent_id: intent.id,
      amount: intent.amount,
      currency: intent.currency,
      status: intent.status,
    },
  });
});

// Fulfilment happens HERE, not in the app.
app.post('/webhooks/stripe', express.raw({ type: 'application/json' }), (req, res) => {
  const event = stripe.webhooks.constructEvent(
    req.body,
    req.headers['stripe-signature'],
    process.env.STRIPE_WEBHOOK_SECRET,
  );
  if (event.type === 'payment_intent.succeeded') {
    const pi = event.data.object;
    Orders.markPaid(pi.metadata.order_id, pi.id);
  }
  res.sendStatus(200);
});
```

Note the two things the app can never do: choose `amount`, and decide that an order is paid.

---

## `.env`

```env
# Publishable key only. pk_test_... in dev, pk_live_... in production.
STRIPE_PUBLISHABLE_KEY=pk_test_51Xxxxxxxxxxxxxxxxxxxx
```

Already present in `.env.example`, already exposed as `Env.stripePublishableKey` — no core edit needed.

Keep it an `optional()` getter. **Do not** add `STRIPE_PUBLISHABLE_KEY` to `Env.requiredKeys`, or every
project built on this template that does not take payments will refuse to boot.

---

## Platform config

Verified against `flutter_stripe` 12.6.0's own README in the pub cache (`~/.pub-cache/hosted/pub.dev/flutter_stripe-12.6.0/README.md`).

### Android

**1. minSdk 21+** — `android/app/build.gradle.kts` already uses `flutter.minSdkVersion`, which resolves
to 21 or higher. Usually nothing to change.

**2. Kotlin 1.8.0+ and AGP 8+** — this template is on Kotlin 2.3.20 and AGP 9.0.1. Nothing to change.

**3. `MainActivity` must extend `FlutterFragmentActivity`.** Stripe's Android SDK uses the support
fragment manager for the payment sheet, so `FlutterActivity` will not work.

`android/app/src/main/kotlin/com/easital/starter/MainActivity.kt` currently reads:

```kotlin
package com.easital.starter

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```

Change it to:

```kotlin
package com.easital.starter

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

**4. The activity theme must descend from `Theme.AppCompat`.** The template's themes inherit from
`@android:style/Theme.Light.NoTitleBar`, which is not AppCompat — Stripe's UI components will crash.

`android/app/src/main/res/values/styles.xml`:

```xml
<style name="NormalTheme" parent="Theme.AppCompat.Light.NoActionBar">
    <item name="android:windowBackground">?android:colorBackground</item>
</style>
```

`android/app/src/main/res/values-night/styles.xml`:

```xml
<style name="NormalTheme" parent="Theme.AppCompat.NoActionBar">
    <item name="android:windowBackground">?android:colorBackground</item>
</style>
```

(`LaunchTheme` is only shown before the engine starts and can stay as it is.)

**5. Proguard rules for release builds.** `android/app/proguard-rules.pro` does not exist in this
template — create it:

```proguard
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
-dontwarn kotlinx.parcelize.Parceler$DefaultImpls
-dontwarn kotlinx.parcelize.Parceler
-dontwarn kotlinx.parcelize.Parcelize
-keep class com.stripe.** { *; }
```

**6. Full rebuild.** Hot reload does not pick up any of the above.

### iOS

Minimum deployment target **iOS 13.0**.

`ios/Podfile` — the first line is commented out in this template; uncomment it:

```ruby
platform :ios, '13.0'
```

Then set `IPHONEOS_DEPLOYMENT_TARGET` to `13.0` in Xcode's Build Settings and run:

```bash
cd ios && pod install
```

Card scanning only (not used by this module's default flow) needs `NSCameraUsageDescription` in
`Info.plist`.

---

## Wiring the installer cannot do

### 1. Register the controller — `lib/app/bindings/view_model_binding.dart`

Both screens use `GetBuilder<PaymentController>`, so without this they throw on first build.

```dart
import '../feature/payment/payment_controllers/payment_controller.dart';
```

and inside `dependencies()`:

```dart
// Payment
_lazy<PaymentController>(() => PaymentController());
```

(`_lazy` is the template's helper for `Get.lazyPut<T>(create, fenix: true)`.)

This step is not optional: until you do it, `test/guardrails/bindings_test.dart` fails with
`PaymentController ... not registered in ViewModelBinding`. Adding the two lines above restores a
full green suite.

### 2. Optional named route — `lib/app/routes/app_routes.dart`

```dart
/// Payment
static const String CheckoutScreen = '/checkoutScreen';
```

and `lib/app/routes/app_pages.dart`:

```dart
import '../feature/payment/payment_presentation/checkout_screen.dart';
```

```dart
// Payment
_page(AppRoutes.CheckoutScreen, () => const CheckoutScreen()),
```

`PaymentResultScreen` takes a required `PaymentResult`, so keep pushing it as a widget rather than by
name.

---

## Usage

Widget-first, passing your own cart:

```dart
Get.to(
  () => CheckoutScreen(
    items: const [
      CheckoutLineItem(label: 'Pro plan', amountMinor: 4900),
      CheckoutLineItem(label: 'Extra seat', amountMinor: 900, quantity: 2),
    ],
    currency: 'usd',
    description: 'Pro plan + seats',
    merchantDisplayName: 'Your Store',
  ),
);
```

`CheckoutLineItem` is **illustrative**. Replace it with your project's cart model and delete the default
`items` value on `CheckoutScreen` so a real app cannot ship the demo prices.

Handle the outcome yourself instead of pushing the result screen:

```dart
CheckoutScreen(
  items: cartItems,
  currency: 'usd',
  onResult: (result) {
    switch (result) {
      case PaymentSuccess(:final paymentIntentId):
        devPrint('sheet completed for $paymentIntentId');
        Get.offAllNamed(AppRoutes.DashboardScreen);
      case PaymentCancelled():
        Get.back();
      case PaymentFailed():
        showPaymentResultDialog(context, result);
    }
  },
)
```

Or drive the controller directly, with no screen at all:

```dart
final controller = Get.find<PaymentController>();
controller.merchantDisplayName = 'Your Store';

final result = await controller.pay(
  amountMinor: 4900,   // display hint — the backend sets the real charge
  currency: 'usd',
  description: 'Pro plan',
);

if (result is PaymentSuccess) {
  // Sheet completed. Wait for your webhook before granting anything.
}
```

`PaymentResult` is sealed, so `switch` over it is exhaustive: `PaymentSuccess`, `PaymentCancelled`,
`PaymentFailed`.

---

## Test cards (test mode only)

Any future expiry date, any 3-digit CVC, any postcode.

| Card | What happens |
|---|---|
| `4242 4242 4242 4242` | Succeeds |
| `4000 0000 0000 0002` | Declined — `generic_decline` |
| `4000 0000 0000 9995` | Declined — `insufficient_funds` |
| `4000 0025 0000 3155` | Requires 3D Secure authentication, then succeeds |

`PaymentFailed.declineCode` carries Stripe's code, and `PaymentResultScreen` shows it.

---

## Gotchas

- **Zero-decimal currencies.** `CheckoutScreen.formatMinor()` divides by 100. JPY, KRW and VND have no
  minor unit — the divisor must be 1 or you will display ¥2,900 as ¥29.00. Fix it in `formatMinor()` if
  you sell in those markets.
- **`PaymentApiConst` is standalone**, so installing this module needs no edit to the core
  `lib/app/services/domain/api_const.dart`. Change the two paths there if your backend mounts them
  elsewhere.
- **Envelope assumption.** The controller parses responses through `BaseResponse<T>.fromJson`. If your
  payment backend returns a bare Stripe object with no `data` wrapper, either wrap it server-side or add
  a `data ?? json` fallback in the controller.

---

## Why it is not in core

Payments are opt-in: `flutter_stripe` drags in the native Stripe SDKs and forces `FlutterFragmentActivity`,
an AppCompat theme and an iOS 13 floor on every project that would otherwise never take a card.
