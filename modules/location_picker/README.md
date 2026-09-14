# location_picker

Map-based location selection: Google Places autocomplete + a Google Map whose centre pin is the picked point, with GPS/IP location services behind it.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/widgets/profile_location_picker.dart` | `ProfileLocationPicker` — search field + map + centre pin + my-location/zoom buttons. |
| `lib/app/widgets/map_interaction_listener.dart` | `MapInteractionListener` — flips an `RxBool` while the user touches the map (stops the parent scroll view fighting the map). |
| `lib/app/services/location_service.dart` | `LocationService` — permission flow, one-shot fix, position stream, IP fallback. |
| `lib/app/services/ip_geo_location.dart` | Extension that adds `getApproximateLocation()` (lat/lon from IP) to the core `IpLocationService`, which only keeps the country-ISO lookup. |

## Install

```bash
dart run tool/add_module.dart location_picker
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
cp modules/location_picker/lib/app/widgets/profile_location_picker.dart lib/app/widgets/
cp modules/location_picker/lib/app/widgets/map_interaction_listener.dart lib/app/widgets/
cp modules/location_picker/lib/app/services/location_service.dart       lib/app/services/
cp modules/location_picker/lib/app/services/ip_geo_location.dart        lib/app/services/
```

Then add the dependencies, do the platform config, and `flutter pub get`.

### 1. pubspec.yaml

```yaml
dependencies:
  geolocator: ^14.0.3
  permission_handler: ^13.0.2
  google_maps_flutter: ^2.18.0
  google_places_flutter: ^2.1.1
  geocoding: ^5.0.0
```

`dio`, `get` and `flutter_dotenv` are already in the template core.

### 2. .env

```env
GOOGLE_MAPS_API_KEY_ALL_IN_ONE=your_key_here
```

Read via `ApiConstant.gapikey` (already in core, `lib/app/services/domain/api_const.dart`). The key needs **Maps SDK for Android**, **Maps SDK for iOS**, **Places API** and **Geocoding API** enabled.

### 3. Register the services

In `main()` (or a binding) before the picker is shown:

```dart
Get.put(IpLocationService(), permanent: true);
Get.put(LocationService(), permanent: true);
```

### 4. Android — `android/app/src/main/AndroidManifest.xml`

Permissions go directly inside `<manifest>`, the API key inside `<application>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.INTERNET"/>

    <application ...>
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_ANDROID_MAPS_API_KEY"/>
        ...
    </application>
</manifest>
```

`minSdk` must be 21 or higher (`android/app/build.gradle.kts`). The Flutter default is already above that.

### 5. iOS — `ios/Runner/AppDelegate.swift`

```swift
import Flutter
import UIKit
import GoogleMaps   // add

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_IOS_MAPS_API_KEY")   // add, before super
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  ...
}
```

### 6. iOS — `ios/Runner/Info.plist`

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We use your location to set your address on the map.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We use your location to set your address on the map.</string>
```

Uncomment and raise the platform line in `ios/Podfile` to `platform :ios, '14.0'` (minimum for `google_maps_flutter_ios`), then `cd ios && pod install`.

## Usage

```dart
class MyController extends GetxController {
  final addressController = TextEditingController();
  final selectedLocation = const LatLng(0, 0).obs;
  final isMapInteracting = false.obs;
}

// In the screen — wrap in MapInteractionListener when it sits inside a scroll view.
MapInteractionListener(
  isInteracting: controller.isMapInteracting,
  child: ProfileLocationPicker(
    addressController: controller.addressController,
    selectedLocation: controller.selectedLocation,
    isMapInteracting: controller.isMapInteracting,
    title: 'Shop address',
    required: true,
    mapHeight: 220,
    onAddressChanged: (address) => log(address),
    onLocationChanged: (latLng) => log('${latLng.latitude}, ${latLng.longitude}'),
  ),
)
```

Location without any UI:

```dart
final loc = await LocationService.to.getUserLocationSilent(); // {lat, lon, address}, never prompts
final pos = await LocationService.to.getCurrentLocation();    // Position? after permission is granted
LocationService.to.positionStream.listen((p) => print(p.latitude));
```

### Custom centre pin

The pin defaults to `Icons.location_on`. To use your own asset, pass `pinIcon`:

```dart
ProfileLocationPicker(
  ...,
  pinIcon: SvgPicture.asset('assets/svg/location_pin.svg', width: R.w(40), height: R.h(50)),
)
```

(The original code referenced `ImageUtils.LocationPickerMarker`, an asset that no longer ships with the template — hence the `pinIcon` parameter.)

## Notes and gotchas

- The selected point is always the **centre of the map**, not a tapped marker. Tapping recentres; when the camera goes idle the centre is reverse-geocoded into the address field.
- `geocoding ^5.0.0` removed the top-level `placemarkFromCoordinates()` function — this module uses the `Geocoding()` instance API. On geocoding 2.x/3.x, call the top-level function instead.
- `geolocator ^14` removed `desiredAccuracy:` — this module passes `locationSettings: LocationSettings(...)`.
- Location resolution order everywhere: GPS → IP (`ip-api.com`, no key) → hardcoded fallback `23.8103, 90.4125` (change `_fallbackLatLng` in `profile_location_picker.dart`).
- `ip_geo_location.dart` is an extension, so it does not overwrite the core `IpLocationService` that `CustomPhoneTextField` relies on.

## Why it is not in core

It pulls five heavy native plugins and requires Google Maps API keys plus platform permission config, which most projects starting from this template never need.
