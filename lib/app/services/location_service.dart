import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_constant.dart';
import 'ip_location_service.dart';

class LocationService extends GetxService {
  static LocationService get to => Get.find();

  final _positionStreamController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionStreamController.stream;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // Show a custom dialog explaining why we need location permission
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

  bool _serviceEnabled = false;
  LocationPermission? _permissionGranted;

  /// Check if location services are enabled and request permission if needed
  /// Returns true if we have location access, false otherwise
  Future<bool> checkAndRequestLocationPermission() async {
    try {
      print('Checking location services and permissions...');

      // 1. First check current permission status
      _permissionGranted = await Geolocator.checkPermission();
      print('Initial permission status: $_permissionGranted');

      // 2. If permission is not granted, keep asking
      while (_permissionGranted == LocationPermission.denied) {
        print('Requesting location permission...');
        _permissionGranted = await Geolocator.requestPermission();
        print('User responded with: $_permissionGranted');

        if (_permissionGranted == LocationPermission.denied) {
          // Show explanation and ask again
          final shouldRetry = await _showPermissionExplanationDialog();
          if (!shouldRetry) break;
        }
      }

      // 2. After handling permissions, check if location is enabled
      _serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('Location services enabled: $_serviceEnabled');

      if (!_serviceEnabled) {
        print('Prompting user to enable location...');
        _serviceEnabled = await Geolocator.openLocationSettings();

        if (!_serviceEnabled) {
          print('User chose not to enable location services.');
          // Even if location is off, we still have permission - we can ask again later
          if (_permissionGranted == LocationPermission.whileInUse ||
              _permissionGranted == LocationPermission.always) {
            print(
              'But we have location permission. The user can enable location later.',
            );
            return true;
          }
          // No permission and no location - use IP
          await _getApproximateLocation();
          return false;
        }
      }

      // 3. Handle denied forever case
      if (_permissionGranted == LocationPermission.deniedForever) {
        print('Location permission denied forever. Showing settings dialog...');
        // Show dialog to guide user to app settings
        await _showPermissionDeniedDialog();
        await _getApproximateLocation();
        return false;
      }

      // 5. If we have permissions, get the current location
      print('Location permission granted. Getting current location...');
      final position = await getCurrentLocation();

      if (position != null) {
        print(
          'Successfully got GPS location: ${position.latitude}, ${position.longitude}',
        );
        startLocationUpdates(); // Start continuous updates
        return true;
      } else {
        print('Failed to get GPS location. Falling back to IP location...');
        await _getApproximateLocation();
        return false;
      }
    } catch (e) {
      print('Error in location permission check: $e');
      await _getApproximateLocation();
      return false;
    }
  }

  /// Get the current position
  Future<Position?> getCurrentLocation() async {
    try {
      print('Getting current location...');
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print(
        'Got location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
      );

      // Update LocationConstants with new position
      LocationConstants.latitude = _currentPosition!.latitude;
      LocationConstants.longitude = _currentPosition!.longitude;

      _positionStreamController.add(_currentPosition!);
      return _currentPosition;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Start listening to location updates
  StreamSubscription<Position>? _positionStreamSubscription;

  void startLocationUpdates() {
    if (_permissionGranted != LocationPermission.denied &&
        _permissionGranted != LocationPermission.deniedForever) {
      _positionStreamSubscription?.cancel();

      print('Starting location updates...');
      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10, // Update when device moves 10 meters
            ),
          ).listen(
            (Position position) {
              _currentPosition = position;
              _positionStreamController.add(position);
              print('=== LOCATION UPDATE ===');
              print('Latitude: ${position.latitude}');
              print('Longitude: ${position.longitude}');
              print('Accuracy: ${position.accuracy} meters');
              print('Timestamp: ${position.timestamp}');
              print('========================');
            },
            onError: (error) {
              print('Location update error: $error');
              // Try to get approximate location if there's an error
              _getApproximateLocation();
            },
          );
    }
  }

  /// Stop listening to location updates
  void stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
  }

  /// Get approximate location using IP address when GPS is not available
  Future<void> _getApproximateLocation() async {
    try {
      final ipLocation = IpLocationService.to;
      final locationData = await ipLocation.getApproximateLocation();
      if (locationData != null) {
        print('Approximate location from IP:');
        print('Latitude: ${locationData['latitude']}');
        print('Longitude: ${locationData['longitude']}');
        print('City: ${locationData['city']}');
        print('Country: ${locationData['country']}');
        print('IP: ${locationData['ip']}');

        // Update LocationConstants with approximate location
        LocationConstants.latitude = locationData['latitude'];
        LocationConstants.longitude = locationData['longitude'];
        LocationConstants.locationName =
            '${locationData['city']}, ${locationData['country']}';

        // Create a Position-like object for IP location
        final position = Position(
          latitude: locationData['latitude'],
          longitude: locationData['longitude'],
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );

        _currentPosition = position;
        _positionStreamController.add(position);
      }
    } catch (e) {
      print('Error getting approximate location: $e');
    }
  }

  // Show dialog when permission is permanently denied
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
      onCancel: () {
        Get.back();
      },
      barrierDismissible: false,
    );
  }

  @override
  void onClose() {
    stopLocationUpdates();
    _positionStreamController.close();
    super.onClose();
  }

  /// Get location data from IP address (always works without permission)
  Future<Map<String, dynamic>> _getIpLocationData() async {
    try {
      final ipLocation = await IpLocationService.to.getApproximateLocation();
      if (ipLocation != null) {
        final lat = ipLocation['latitude'] as double;
        final lon = ipLocation['longitude'] as double;
        final address = "${ipLocation['city']}, ${ipLocation['country']}";

        // Cache the IP location
        LocationConstants.latitude = lat;
        LocationConstants.longitude = lon;
        LocationConstants.locationName = address;

        // Update current position
        _currentPosition = Position(
          latitude: lat,
          longitude: lon,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );

        print('📍 Got IP location: $lat, $lon ($address)');

        return {
          "lat": lat,
          "lon": lon,
          "address": address,
        };
      }
    } catch (e) {
      print('Error getting IP location: $e');
    }

    // Default if everything fails
    return {"lat": 0.0, "lon": 0.0, "address": ""};
  }

  /// Get user location silently without showing permission dialogs
  /// This is useful for getting location in background (GPS if available, otherwise IP)
  /// Always returns a valid location (never 0.0, 0.0 unless IP service also fails)
  Future<Map<String, dynamic>> getUserLocationSilent() async {
    try {
      // First check if we already have a cached location
      if (LocationConstants.hasLocation) {
        print('📍 Using cached location: ${LocationConstants.latitude}, ${LocationConstants.longitude}');
        return {
          "lat": LocationConstants.latitude ?? 0.0,
          "lon": LocationConstants.longitude ?? 0.0,
          "address": LocationConstants.locationName ?? "",
        };
      }

      // Check if we have current position from GPS
      if (_currentPosition != null) {
        print('📍 Using current GPS position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
        return {
          "lat": _currentPosition!.latitude,
          "lon": _currentPosition!.longitude,
          "address": LocationConstants.locationName ?? "",
        };
      }

      // Check permission status without requesting (no dialog shown)
      final permission = await Geolocator.checkPermission();
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      print('📍 Permission: $permission, Service enabled: $serviceEnabled');

      // If we have permission and service is enabled, try GPS
      if (serviceEnabled &&
          (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always)) {
        try {
          print('📍 Trying to get GPS location...');
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(const Duration(seconds: 10));

          _currentPosition = position;
          LocationConstants.latitude = position.latitude;
          LocationConstants.longitude = position.longitude;

          print('📍 Got GPS location: ${position.latitude}, ${position.longitude}');

          return {
            "lat": position.latitude,
            "lon": position.longitude,
            "address": LocationConstants.locationName ?? "",
          };
        } catch (e) {
          print('📍 GPS location failed, falling back to IP: $e');
        }
      }

      // No GPS permission or GPS failed - use IP location
      print('📍 Using IP-based location...');
      return await _getIpLocationData();
    } catch (e) {
      print("Error getting silent location: $e");
      // Last resort - try IP location
      return await _getIpLocationData();
    }
  }

  /// Get user location - shows permission dialogs if needed
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
      } else {
        // Fallback: IP location (already called in checkAndRequestLocationPermission)
        // But we check again to make sure we return valid data
        if (LocationConstants.hasLocation) {
          return {
            "lat": LocationConstants.latitude ?? 0.0,
            "lon": LocationConstants.longitude ?? 0.0,
            "address": LocationConstants.locationName ?? "",
          };
        }
        return await _getIpLocationData();
      }
    } catch (e) {
      print("Error getting location: $e");
      // Fallback to IP location on any error
      return await _getIpLocationData();
    }
  }
}
