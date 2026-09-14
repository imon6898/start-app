# multi_step_onboarding

Rider and merchant registration wizards, kept as a **pattern reference** for building multi-step forms with validation, file upload and step indicators in Flutter + GetX.

> **Read this first.** This is delivery/logistics **domain code**. It is not a generic onboarding library and you are not expected to install it verbatim. Copy the **structure** — the step state machine, per-step validation, upload handling, Repo/Impl API split — and replace the business fields with your own. See [What to copy vs what to throw away](#what-to-copy-vs-what-to-throw-away).

## What is in here

| File | Pattern it demonstrates |
| --- | --- |
| `rider_signup_controller.dart` | 5-step state machine: `currentStep`, `PageController`, `nextStep()/previousStep()`, one `GlobalKey<FormState>` per step, a `switch` that validates only the current step |
| `merchant_signup_controller.dart` | Same machine with a different field set, plus a map-location step |
| `rider_signup_screen.dart` | `GetBuilder` + `PageView` + step-indicator header + sticky bottom Next/Back bar |
| `merchant_signup_screen.dart` | Same shell; step 3 embeds a map location picker |
| `rider_registration_info_screen.dart` | Pre-wizard explainer: "here is what you need to have ready" |
| `merchant_registration_info_screen.dart` | Same, merchant variant |
| `rider_api_service.dart` | One API call per wizard step (`POST` create, then `PATCH` per step), abstract / Impl / Repo split |
| `merchant_api_service.dart` | Multipart document upload, with a parallel JSON-URL path for pre-hosted files |
| `location_api_service.dart` | Cascading dropdown source: parish -> city -> zone |
| `onboarding_api_const.dart` | Endpoint placeholders (added by this module — see [Notes](#notes)) |
| `onboarding_validators.dart` | TRN / NIS validators (Jamaica-specific — see [Notes](#notes)) |
| `pending_login_cache.dart` | Stashes signup credentials for auto-login after OTP (added by this module) |

## Install

```bash
dart run tool/add_module.dart multi_step_onboarding
```

Manual equivalent:

1. Copy `modules/multi_step_onboarding/lib/app/` over your project's `lib/app/` (paths already mirror the template layout, so it is a straight merge).
2. Add the dependencies below to `pubspec.yaml`, then `flutter pub get`.
3. Add the routes and bindings (snippets below).
4. Apply the platform config below.
5. Repoint `OnboardingEndpoints` at your backend.

### Dependencies

```yaml
  image_picker: ^1.2.0
  file_picker: ^13.0.0
  pinput: ^5.0.1
  intl: ^0.20.2
  permission_handler: ^13.0.2
  lucide_icons_flutter: ^3.1.19
  flutter_svg: ^2.3.0
  shared_preferences: ^2.5.5

  # Only if you keep the merchant map step:
  google_maps_flutter: ^2.18.0
```

`file_picker`, `pinput`, `intl`, `lucide_icons_flutter`, `flutter_svg` and `shared_preferences` already ship with the template — versions above match what it pins. `image_picker` was never pinned in the template; any 1.x works.

### Also required

- **`custom_dropdown_button` module** (required) — both signup screens use `CustomDropdownButton` for the parish/city/zone and bank pickers. Install it, or swap in your own dropdown.
- **`location_picker` module** (optional) — only `merchant_signup_screen.dart` step 3 (`ProfileLocationPicker`) and the `LatLng` fields in `merchant_signup_controller.dart`. Both import sites carry a one-line comment. Delete them and you drop `google_maps_flutter`, `geolocator`, `geocoding` and `google_places_flutter` entirely.

### Routes

```dart
// lib/app/routes/app_routes.dart
static const String RiderRegistrationInfoScreen = '/riderRegistrationInfoScreen';
static const String RiderSignupScreen = '/riderSignupScreen';
static const String MerchantRegistrationInfoScreen = '/merchantRegistrationInfoScreen';
static const String MerchantSignupScreen = '/merchantSignupScreen';

// lib/app/routes/app_pages.dart
_page(AppRoutes.RiderRegistrationInfoScreen, () => const RiderRegistrationInfoScreen()),
_page(AppRoutes.RiderSignupScreen, () => const RiderSignupScreen()),
_page(AppRoutes.MerchantRegistrationInfoScreen, () => const MerchantRegistrationInfoScreen()),
_page(AppRoutes.MerchantSignupScreen, () => const MerchantSignupScreen()),
```

### Bindings

```dart
// lib/app/bindings/view_model_binding.dart
Get.lazyPut(() => RiderSignupController(), fenix: true);
Get.lazyPut(() => MerchantSignupController(), fenix: true);
```

## Platform config

**Android** — `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>
```

`minSdk` must be 21 or higher in `android/app/build.gradle.kts` (`image_picker` + `file_picker`).

**iOS** — `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to take your profile photo and document photos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to attach identity and address documents.</string>
```

**Backend** — all three services call `ApiService(logisticsBaseUrl: true)`, which reads `LOGISTICS_BASE_URL` from `.env`. Set it, and edit the paths in `onboarding_api_const.dart`.

**Google Maps** — only if you keep the optional location picker: `com.google.android.geo.API_KEY` meta-data in `AndroidManifest.xml`, `GMSServices.provideAPIKey(...)` in `ios/Runner/AppDelegate.swift`, and `GOOGLE_MAPS_API_KEY_ALL_IN_ONE` in `.env`.

## Usage

Navigate into the flow:

```dart
Get.toNamed(AppRoutes.RiderRegistrationInfoScreen); // explainer -> wizard
```

The wizard shell is the whole point — this is the shape to copy:

```dart
GetBuilder<RiderSignupController>(
  builder: (c) => Scaffold(
    appBar: AppBarWidget(
      title: 'Rider Registration'.tr,
      leadingWidget: IconButton(
        onPressed: () => c.currentStep.value > 0 ? c.previousStep() : Get.back(),
        icon: const Icon(Icons.arrow_back_ios),
      ),
    ),
    body: Column(
      children: [
        _buildStepIndicator(c),            // segmented bar + "Step N of M" + "% complete"
        Expanded(
          child: PageView(
            controller: c.pageController,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (i) => c.currentStep.value = i,
            children: [
              _buildPersonalInfoStep(context, c), // each wrapped in its own Form
              _buildDocumentsStep(context, c),    // + formKey from the controller
              // ...
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: _buildBottomBar(context, c), // Back / Next -> c.nextStep()
  ),
);
```

And the gate that makes it work — `nextStep()` refuses to advance until the current step validates, and the last step submits instead:

```dart
void nextStep() {
  if (!_validateCurrentStep()) return;
  if (currentStep.value < totalSteps - 1) {
    currentStep.value++;
    pageController.animateToPage(currentStep.value,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  } else {
    submitRegistration();
  }
}
```

`_validateCurrentStep()` switches on `currentStep` and runs only that step's `formKey.currentState!.validate()`, then any non-form checks (a file was picked, a chip was selected, terms accepted) with a specific snackbar per failure.

## What to copy vs what to throw away

**Genuinely reusable — take this as-is:**

- The step state machine in the controllers: `currentStep` / `totalSteps`, `PageController` sync, `nextStep()` / `previousStep()`.
- Per-step `GlobalKey<FormState>` plus a `switch`-based `_validateCurrentStep()`. Validating one step at a time is the thing most multi-step forms get wrong.
- Non-form validation returning a **specific** message ("Please upload TRN Card") instead of a generic one. The rider controller is the better of the two here — its `specificMessageShown` flag stops you showing two snackbars for one failure; the merchant controller lacks it.
- The step indicator (segmented progress bar + "Step N of M" + percent, derived purely from `currentStep` / `totalSteps`) + `PageView` + sticky bottom bar layout.
- `Rxn<File>` fields driving `FileUploadWidget`, and the `Map<String, File>` -> multipart assembly in the Repo layer.
- The abstract service / `Impl` / `Repo` split, and `_parseResponse()` tolerating both `{status, data}` and a bare object.
- The cascading dropdown pattern in `location_api_service.dart` + `onParishSelected` / `onCitySelected`: selecting a parent clears children and refetches.
- Submitting a long form as several sequential calls (create, then PATCH per step) so a partial registration survives.
- `formatPhone()` joining a dial code to a national number.
- Controller `onClose()` disposing every `TextEditingController`.

**Jamaica-specific — replace before you ship anywhere else:**

- **TRN** (Taxpayer Registration Number) and **NIS** (National Insurance Scheme) — the numbers, the card uploads, and `OnboardingValidators.trnValidator` / `nisValidator` (both hardcode "exactly 9 digits").
- **Parish** as the top address tier. Outside Jamaica this is state / province / governorate. The parish -> city -> zone cascade is reusable; the word "parish" is not.
- The hardcoded bank list in `rider_signup_controller.dart` (`banks`) — NCB, Scotiabank Jamaica, Sagicor, JMMB, JN Bank, Victoria Mutual.
- Default map centre `LatLng(18.1096, -77.2975)` in `merchant_signup_controller.dart`.
- Phone dial-code fallback `'+1'` in `formatPhone()`.

**Delivery-domain — replace with your own business fields:**

- Rider: vehicle type chips (`BIKE`/`SCOOTER`/`CAR`/`VAN`/`TRUCK`/`MINI TRUCK`/`BICYCLE`), the `isBicycle` branch that skips license fields, driver's-licence number/expiry/photo, preferred zone.
- Merchant: business type and category maps, business registration number, ID proof front/back, address proof, bank statement.
- Every field name in the `submitRegistration()` payload maps (`dlExpiryDate`, `bankBranchCode`, `preferredZoneId`, ...).
- Both `*_registration_info_screen.dart` explainers are pure copy about delivery documents.

## Notes

Three files in `lib/` are **new**, not recovered — the stripped code referenced things the template core never actually defined:

- `onboarding_api_const.dart` — the original called `ApiConstant.riderStep1`, `ApiConstant.parishesUri`, etc., which were never in `ApiConstant`. Placeholder paths are supplied so the module compiles; **repoint them at your backend**.
- `onboarding_validators.dart` — `Validators.trnValidator` / `nisValidator` were removed from core as country-specific. Kept here, renamed to `OnboardingValidators`.
- `pending_login_cache.dart` — the original called `CacheManager.setLoginEmail` / `setLoginPassword`, which never existed. Replaced with a small `SharedPreferences` store. It holds a plaintext password until OTP completes — call `PendingLoginCache.clear()` the moment auto-login succeeds, or drop it and pass the credentials as route arguments instead.

## Why it is not in core

It is delivery/logistics business logic with Jamaica-specific identity fields — valuable as a multi-step-form pattern, wrong as a default in a generic starter.
