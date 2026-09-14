import 'dart:async';
import 'dart:developer';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_starter/app/services/ip_geo_location.dart';
import 'package:flutter_starter/app/services/ip_location_service.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_constant.dart';

/// GPS location service with IP fallback. Register with `Get.put(LocationService(), permanent: true)`.
class LocationService extends GetxService {
  static LocationService get to => Get.find();

  final _positionStreamController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionStreamController.stream;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  bool _serviceEnabled = false;
  LocationPermission? _permissionGranted;
  StreamSubscription<Position>? _positionStreamSubscription;

  /// Requests permission + service, falls back to IP. True if GPS location is usable.
  Future<bool> checkAndRequestLocationPermission() async {
    try {
      _permissionGranted = await Geolocator.checkPermission();

      // Keep asking while the user only soft-denies.
      while (_permissionGranted == LocationPermission.denied) {
        _permissionGranted = await Geolocator.requestPermission();
        if (_permissionGranted == LocationPermission.denied) {
          final shouldRetry = await _showPermissionExplanationDialog();
          if (!shouldRetry) break;
        }
      }

      _serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await Geolocator.openLocationSettings();
        if (!_serviceEnabled) {
          // Permission held but GPS off — caller can retry later.
          if (_permissionGranted == LocationPermission.whileInUse ||
              _permissionGranted == LocationPermission.always) {
            return true;
          }
          await _getApproximateLocation();
          return false;
        }
      }

      if (_permissionGranted == LocationPermission.deniedForever) {
        await _showPermissionDeniedDialog();
        await _getApproximateLocation();
        return false;
      }

      final position = await getCurrentLocation();
      if (position != null) {
        startLocationUpdates();
        return true;
      }

      await _getApproximateLocation();
      return false;
    } catch (e) {
      log('LocationService: permission check failed - $e');
      await _getApproximateLocation();
      return false;
    }
  }

  /// One-shot GPS fix. Null if unavailable.
  Future<Position?> getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      LocationConstants.latitude = _currentPosition!.latitude;
      LocationConstants.longitude = _currentPosition!.longitude;

      _positionStreamController.add(_currentPosition!);
      return _currentPosition;
    } catch (e) {
      log('LocationService: getCurrentLocation failed - $e');
      return null;
    }
  }

  /// Streams positions every 10 metres of movement.
  void startLocationUpdates() {
    if (_permissionGranted == LocationPermission.denied ||
        _permissionGranted == LocationPermission.deniedForever) {
      return;
    }

    _positionStreamSubscription?.cancel();
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          (Position position) {
            _currentPosition = position;
            LocationConstants.latitude = position.latitude;
            LocationConstants.longitude = position.longitude;
            _positionStreamController.add(position);
          },
          onError: (error) {
            log('LocationService: position stream error - $error');
            _getApproximateLocation();
          },
        );
  }

  void stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
  }

  /// Best location without ever showing a dialog: cache -> GPS (if already allowed) -> IP.
  Future<Map<String, dynamic>> getUserLocationSilent() async {
    try {
      if (LocationConstants.hasLocation) {
        return {
          "lat": LocationConstants.latitude ?? 0.0,
          "lon": LocationConstants.longitude ?? 0.0,
          "address": LocationConstants.locationName ?? "",
        };
      }

      if (_currentPosition != null) {
        return {
          "lat": _currentPosition!.latitude,
          "lon": _currentPosition!.longitude,
          "address": LocationConstants.locationName ?? "",
        };
      }

      final permission = await Geolocator.checkPermission();
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (serviceEnabled &&
          (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always)) {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          ).timeout(const Duration(seconds: 10));

          _currentPosition = position;
          LocationConstants.latitude = position.latitude;
          LocationConstants.longitude = position.longitude;

          return {
            "lat": position.latitude,
            "lon": position.longitude,
            "address": LocationConstants.locationName ?? "",
          };
        } catch (e) {
          log('LocationService: silent GPS failed, using IP - $e');
        }
      }

      return await _getIpLocationData();
    } catch (e) {
      log('LocationService: getUserLocationSilent failed - $e');
      return await _getIpLocationData();
    }
  }

  /// Same as [getUserLocationSilent] but prompts for permission first.
  Future<Map<String, dynamic>> getUserLocation() async {
    try {
      final hasLocation = await checkAndRequestLocationPermission();
      if (hasLocation && currentPosition != null) {
        final pos = currentPosition!;
        return {
          "lat": pos.latitude,
          "lon": pos.longitude,
          "address": LocationConstants.locationName ?? "",
        };
      }

      if (LocationConstants.hasLocation) {
        return {
          "lat": LocationConstants.latitude ?? 0.0,
          "lon": LocationConstants.longitude ?? 0.0,
          "address": LocationConstants.locationName ?? "",
        };
      }
      return await _getIpLocationData();
    } catch (e) {
      log('LocationService: getUserLocation failed - $e');
      return await _getIpLocationData();
    }
  }

  /// IP fallback that also caches into [LocationConstants] and the position stream.
  Future<void> _getApproximateLocation() async {
    try {
      final locationData = await IpLocationService.to.getApproximateLocation();
      if (locationData == null) return;

      final lat = (locationData['latitude'] as num).toDouble();
      final lon = (locationData['longitude'] as num).toDouble();

      LocationConstants.latitude = lat;
      LocationConstants.longitude = lon;
      LocationConstants.locationName =
          '${locationData['city']}, ${locationData['country']}';

      final position = _positionFrom(lat, lon);
      _currentPosition = position;
      _positionStreamController.add(position);
    } catch (e) {
      log('LocationService: IP location failed - $e');
    }
  }

  /// IP lookup shaped as the `{lat, lon, address}` map callers expect.
  Future<Map<String, dynamic>> _getIpLocationData() async {
    try {
      final ipLocation = await IpLocationService.to.getApproximateLocation();
      if (ipLocation != null) {
        final lat = (ipLocation['latitude'] as num).toDouble();
        final lon = (ipLocation['longitude'] as num).toDouble();
        final address = "${ipLocation['city']}, ${ipLocation['country']}";

        LocationConstants.latitude = lat;
        LocationConstants.longitude = lon;
        LocationConstants.locationName = address;
        _currentPosition = _positionFrom(lat, lon);

        return {"lat": lat, "lon": lon, "address": address};
      }
    } catch (e) {
      log('LocationService: IP location failed - $e');
    }
    return {"lat": 0.0, "lon": 0.0, "address": ""};
  }

  /// Builds a zero-accuracy [Position] for non-GPS (IP) coordinates.
  Position _positionFrom(double latitude, double longitude) => Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: 0,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
  );

  /// Soft-denied: explain and offer a retry.
  Future<bool> _showPermissionExplanationDialog() async {
    bool shouldRetry = false;
    await Get.defaultDialog<bool>(
      barrierDismissible: false,
      title: 'Location Permission Required',
      middleText:
          'This app needs access to your location to provide location-based services. Please enable location permission to continue.',
      textConfirm: 'Try Again',
      textCancel: 'Use App Without Location',
      confirmTextColor: CustomColors.white(),
      onConfirm: () {
        shouldRetry = true;
        Get.back(result: true);
      },
      onCancel: () {
        shouldRetry = false;
        Get.back(result: false);
      },
    );
    return shouldRetry;
  }

  /// Denied forever: send the user to app settings.
  Future<void> _showPermissionDeniedDialog() async {
    await Get.defaultDialog(
      title: 'Location Permission Required',
      middleText:
          'Location permission is required for this feature. Please enable it in app settings to continue.',
      textConfirm: 'Open Settings',
      textCancel: 'Cancel',
      confirmTextColor: CustomColors.white(),
      onConfirm: () async {
        await openAppSettings();
        Get.back();
      },
      onCancel: () => Get.back(),
      barrierDismissible: false,
    );
  }

  @override
  void onClose() {
    stopLocationUpdates();
    _positionStreamController.close();
    super.onClose();
  }
}
