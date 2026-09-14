import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_starter/app/services/domain/api_const.dart';
import 'package:flutter_starter/app/services/ip_location_service.dart';
import 'package:flutter_starter/app/services/location_service.dart';
import 'package:flutter_starter/app/utils/constants/app_assets.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';

import '../utils/responsive_utils.dart';

class ProfileLocationPicker extends StatefulWidget {
  final TextEditingController addressController;
  final Rx<LatLng> selectedLocation;
  final RxBool isMapInteracting;
  final String title;
  final String? subTitle;
  final String hintText;
  final bool required;
  final double? mapHeight;
  final Function(String)? onAddressChanged;
  final Function(LatLng)? onLocationChanged;

  const ProfileLocationPicker({
    Key? key,
    required this.addressController,
    required this.selectedLocation,
    required this.isMapInteracting,
    this.title = "Address",
    this.subTitle,
    this.hintText = "Search for a location",
    this.required = false,
    this.mapHeight,
    this.onAddressChanged,
    this.onLocationChanged,
  }) : super(key: key);

  @override
  State<ProfileLocationPicker> createState() => _ProfileLocationPickerState();
}

class _ProfileLocationPickerState extends State<ProfileLocationPicker>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final RxBool _isLoadingLocation = false.obs;
  final RxBool _isAnimatingToCurrentLocation = false.obs;
  CameraPosition? _initialCameraPosition;

  Timer? _cameraIdleTimer;
  late AnimationController _pinAnimationController;
  late Animation<double> _pinAnimation;
  bool _isMapMoving = false;

  @override
  void initState() {
    super.initState();
    _testGeocodingOnInit();
    _initializeLocation();

    // Initialize pin animation controller
    _pinAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Bounce animation: goes up then down
    _pinAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: -20,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -20,
          end: 0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 50,
      ),
    ]).animate(_pinAnimationController);
  }

  @override
  void dispose() {
    _cameraIdleTimer?.cancel();
    _mapController?.dispose();
    _pinAnimationController.dispose();
    super.dispose();
  }

  Future<void> _testGeocodingOnInit() async {
    try {
      log('ProfileLocationPicker: Testing geocoding on iOS...');
      // Test with a known location (New York City)
      final testPlacemarks = await placemarkFromCoordinates(40.7128, -74.0060);
      log('ProfileLocationPicker: Geocoding test successful! Received ${testPlacemarks.length} placemarks');
      if (testPlacemarks.isNotEmpty) {
        final testPlace = testPlacemarks[0];
        log('ProfileLocationPicker: Test location - locality: ${testPlace.locality}, adminArea: ${testPlace.administrativeArea}, country: ${testPlace.country}');
      }
    } catch (e) {
      log('ProfileLocationPicker: Geocoding test FAILED - $e');
    }
  }

  Future<void> _initializeLocation() async {
    _isLoadingLocation.value = true;
    log('ProfileLocationPicker: Starting location initialization');

    try {
      // Check if we have existing location data
      if (widget.selectedLocation.value.latitude != 0 ||
          widget.selectedLocation.value.longitude != 0) {
        final latLng = widget.selectedLocation.value;
        log('ProfileLocationPicker: Using existing location: $latLng');
        _initialCameraPosition = CameraPosition(target: latLng, zoom: 14.0);
        _updateMarker(latLng);

        // Get address from coordinates if not already set
        if (widget.addressController.text.isEmpty) {
          await _getAddressFromLatLng(latLng);
        }
      } else {
        // Get current location
        log('ProfileLocationPicker: Getting current location');
        await _getCurrentLocation();
      }
    } catch (e) {
      log('Initialize location error: $e');
      // Fallback to default location
      const defaultLatLng = LatLng(23.8103, 90.4125);
      log('ProfileLocationPicker: Using fallback location: $defaultLatLng');
      _initialCameraPosition = const CameraPosition(
        target: defaultLatLng,
        zoom: 14.0,
      );
      _updateMarker(defaultLatLng);
    } finally {
      _isLoadingLocation.value = false;
      log('ProfileLocationPicker: Camera position set: ${_initialCameraPosition != null}');
      if (mounted) setState(() {});
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final gpsPosition = await _tryGetGpsLocation();

      if (gpsPosition != null) {
        await _updateLocationUI(gpsPosition);
      } else {
        final ipLocation = await _getIpBasedLocation();
        if (ipLocation != null) {
          await _updateLocationUI(ipLocation);
        } else {
          // Fallback: Default location
          await _updateLocationUI(
            Position(
              latitude: 23.8103,
              longitude: 90.4125,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            ),
          );
        }
      }
    } catch (e) {
      log('Get current location error: $e');
    }
  }

  Future<Position?> _tryGetGpsLocation() async {
    try {
      final position = await LocationService.to.getCurrentLocation();
      if (position != null) {
        log('Got GPS Location: ${position.latitude}, ${position.longitude}');
        return position;
      }
    } catch (e) {
      log('GPS Location error: $e');
    }
    return null;
  }

  Future<Position?> _getIpBasedLocation() async {
    try {
      final ipLocation = await IpLocationService.to.getApproximateLocation();
      if (ipLocation != null) {
        return Position(
          latitude: ipLocation['latitude'],
          longitude: ipLocation['longitude'],
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }
    } catch (e) {
      log('IP Location error: $e');
    }
    return null;
  }

  Future<void> _updateLocationUI(Position position) async {
    final latLng = LatLng(position.latitude, position.longitude);
    widget.selectedLocation.value = latLng;
    _initialCameraPosition = CameraPosition(target: latLng, zoom: 14.0);
    _updateMarker(latLng);
    await _getAddressFromLatLng(latLng);
    widget.onLocationChanged?.call(latLng);
  }

  void _updateMarker(LatLng position) {
    // No longer using map markers - using center-pinned marker instead
    _markers.clear();
    if (mounted) setState(() {});
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      log('ProfileLocationPicker: Getting address for ${position.latitude}, ${position.longitude}');
      
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      log('ProfileLocationPicker: Received ${placemarks.length} placemarks');

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        log('ProfileLocationPicker: Placemark details - '
            'street: ${place.street}, '
            'subLocality: ${place.subLocality}, '
            'locality: ${place.locality}, '
            'subAdminArea: ${place.subAdministrativeArea}, '
            'adminArea: ${place.administrativeArea}, '
            'postalCode: ${place.postalCode}, '
            'country: ${place.country}');
        
        final address = _buildFormattedAddress(place);
        log('ProfileLocationPicker: Formatted address: $address');
        
        widget.addressController.text = address;
        widget.onAddressChanged?.call(address);
      } else {
        log('ProfileLocationPicker: No placemarks found for location');
        widget.addressController.text = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      }
    } catch (e, stackTrace) {
      log('ProfileLocationPicker: Get address error: $e');
      log('ProfileLocationPicker: Stack trace: $stackTrace');
      // Fallback to coordinates if geocoding fails
      widget.addressController.text = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    }
  }

  String _buildFormattedAddress(Placemark place) {
    final parts = <String>[];

    // Add street/name
    if (place.street != null && place.street!.isNotEmpty) {
      if (place.street != 'Unnamed Road') {
        parts.add(place.street!);
      }
    } else if (place.name != null &&
        place.name!.isNotEmpty &&
        !RegExp(r'^\d+$').hasMatch(place.name!.trim())) {
      parts.add(place.name!);
    }

    // Add sub-locality
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      parts.add(place.subLocality!);
    }

    // Add locality (city)
    if (place.locality != null && place.locality!.isNotEmpty) {
      parts.add(place.locality!);
    }

    // Add sub-administrative area (county/district)
    if (place.subAdministrativeArea != null &&
        place.subAdministrativeArea!.isNotEmpty &&
        place.subAdministrativeArea != place.locality) {
      parts.add(place.subAdministrativeArea!);
    }

    // Add administrative area (state/province)
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      parts.add(place.administrativeArea!);
    }

    // Add postal code
    if (place.postalCode != null && place.postalCode!.isNotEmpty) {
      parts.add(place.postalCode!);
    }

    // Add country
    if (place.country != null && place.country!.isNotEmpty) {
      parts.add(place.country!);
    }

    return parts.join(', ');
  }

  Future<void> _goToCurrentLocation() async {
    try {
      _isLoadingLocation.value = true;
      _isAnimatingToCurrentLocation.value = true;

      final hasPermission =
          await LocationService.to.checkAndRequestLocationPermission();

      if (hasPermission) {
        final position = await LocationService.to.getCurrentLocation();
        if (position != null) {
          final latLng = LatLng(position.latitude, position.longitude);

          widget.selectedLocation.value = latLng;
          _updateMarker(latLng);
          await _getAddressFromLatLng(latLng);

          await _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(latLng, 14),
          );

          await Future.delayed(const Duration(milliseconds: 500));
          widget.onLocationChanged?.call(latLng);
        }
      } else {
        final ipLocation = await _getIpBasedLocation();
        if (ipLocation != null) {
          await _updateLocationUI(ipLocation);
          await _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(widget.selectedLocation.value, 14),
          );
        }
        Get.snackbar(
          'Location Permission',
          'Please enable location permission in settings for accurate location.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      log('Error getting current location: $e');
      Get.snackbar('Error', 'Could not get current location');
    } finally {
      _isLoadingLocation.value = false;
      _isAnimatingToCurrentLocation.value = false;
    }
  }

  /// Zoom in the map by one level
  Future<void> _zoomIn() async {
    if (_mapController != null) {
      await _mapController!.animateCamera(CameraUpdate.zoomIn());
    }
  }

  /// Zoom out the map by one level
  Future<void> _zoomOut() async {
    if (_mapController != null) {
      await _mapController!.animateCamera(CameraUpdate.zoomOut());
    }
  }

  void _onMapTap(LatLng position) {
    // Move map to tapped position - center pin will show the location
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  void _onCameraMove(CameraPosition position) {
    // Cancel timer and mark map as moving
    _cameraIdleTimer?.cancel();
    if (!_isMapMoving) {
      setState(() {
        _isMapMoving = true;
      });
    }
  }

  Future<void> _onCameraIdle() async {
    // Map stopped moving - get center position and update location
    setState(() {
      _isMapMoving = false;
    });

    // Trigger pin bounce animation
    _pinAnimationController.reset();
    _pinAnimationController.forward();

    // Get the center of the map (where the pin is pointing)
    if (_mapController != null) {
      final LatLngBounds visibleRegion =
          await _mapController!.getVisibleRegion();
      final LatLng center = LatLng(
        (visibleRegion.northeast.latitude + visibleRegion.southwest.latitude) /
            2,
        (visibleRegion.northeast.longitude +
                visibleRegion.southwest.longitude) /
            2,
      );

      // Update selected location to map center
      widget.selectedLocation.value = center;
      await _getAddressFromLatLng(center);
      widget.onLocationChanged?.call(center);
    }
  }

  void _handlePlaceSelection(Prediction prediction) {
    final lat = double.tryParse(prediction.lat ?? '');
    final lng = double.tryParse(prediction.lng ?? '');

    if (lat != null && lng != null) {
      final latLng = LatLng(lat, lng);

      widget.selectedLocation.value = latLng;
      _updateMarker(latLng);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14));

      // Update address
      final address = prediction.description ?? '';
      widget.addressController.text = address;
      widget.addressController.selection = TextSelection.collapsed(
        offset: widget.addressController.text.length,
      );
      widget.onAddressChanged?.call(address);
      widget.onLocationChanged?.call(latLng);
    }

    // Hide keyboard after selection
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          RichText(
            text: TextSpan(
              style: CustomTextStyles.medium14.copyWith(
                color: CustomColors.black(),
              ),
              children: [
                TextSpan(text: widget.title),
                if (widget.required)
                  TextSpan(
                    text: " *",
                    style: CustomTextStyles.medium14.copyWith(
                      color: CustomColors.error(),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            widget.subTitle ??
                "Search for a location or tap on the map to select.",
            style: CustomTextStyles.regular12.copyWith(
              color: CustomColors.textGray(),
            ),
            textAlign: TextAlign.left,
          ),
          SizedBox(height: R.h(8)),

          // Location search field with autocomplete suggestions
          Container(
            decoration: BoxDecoration(
              color: CustomColors.white(),
              borderRadius: BorderRadius.circular(R.r(8)),
              border: Border.all(color: CustomColors.whiteStroke(), width: 1),
            ),
            child: GooglePlaceAutoCompleteTextField(
              textEditingController: widget.addressController,
              textStyle: CustomTextStyles.regular14,
              googleAPIKey: ApiConstant.gapikey,
              inputDecoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: CustomTextStyles.regular14.copyWith(
                  color: CustomColors.textGray(),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: R.w(12),
                  vertical: R.h(8),
                ),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.location_on,
                  color: CustomColors.primary(),
                ),
                suffixIcon:
                    widget.addressController.text.isNotEmpty
                        ? IconButton(
                          icon: Icon(Icons.clear, color: CustomColors.error()),
                          onPressed: () {
                            widget.addressController.clear();
                            setState(() {});
                          },
                        )
                        : Icon(Icons.search, color: CustomColors.textGray()),
              ),
              debounceTime: 400,
              isLatLngRequired: true,
              getPlaceDetailWithLatLng: (Prediction prediction) {
                _handlePlaceSelection(prediction);
              },
              itemClick: (Prediction prediction) {
                // Set the text first
                widget.addressController.text = prediction.description ?? '';
                widget.addressController.selection = TextSelection.collapsed(
                  offset: widget.addressController.text.length,
                );
                // Close keyboard using SystemChannels
                SystemChannels.textInput.invokeMethod('TextInput.hide');
                FocusScope.of(Get.context!).unfocus();
                FocusManager.instance.primaryFocus?.unfocus();
                _handlePlaceSelection(prediction);
              },
              itemBuilder: (context, index, Prediction prediction) {
                return ConstrainedBox(
                  constraints: BoxConstraints(minHeight: R.h(50)),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: R.w(12),
                      vertical: R.h(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: R.h(2)),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: CustomColors.textGray(),
                            size: 20,
                          ),
                        ),
                        SizedBox(width: R.w(8)),
                        Expanded(
                          child: Text(
                            prediction.description ?? '',
                            style: CustomTextStyles.regular14.copyWith(
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              seperatedBuilder: Divider(height: 1, color: Colors.grey.shade200),
              isCrossBtnShown: false,
              containerHorizontalPadding: 0,
            ),
          ),

          // Map container
          Container(
            height: R.h(widget.mapHeight ?? 150),
            margin: EdgeInsets.only(top: R.h(12)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(R.r(8)),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(R.r(8)),
              child:
                  _isLoadingLocation.value && _initialCameraPosition == null
                      ? const Center(child: CircularProgressIndicator())
                      : _initialCameraPosition == null
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_off,
                              size: 40,
                              color: Colors.grey,
                            ),
                            SizedBox(height: R.h(8)),
                            const Text(
                              'Loading map...',
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: _initializeLocation,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                      : Stack(
                        children: [
                          GoogleMap(
                            key: const Key('google_map_profile_location_picker'),
                            initialCameraPosition: _initialCameraPosition!,
                            onMapCreated: (GoogleMapController controller) {
                              _mapController = controller;
                            },
                            onTap: _onMapTap,
                            onCameraMoveStarted: () {
                              if (!widget.isMapInteracting.value) {
                                widget.isMapInteracting.value = true;
                                FocusScope.of(context).unfocus();
                              }
                            },
                            onCameraMove: _onCameraMove,
                            onCameraIdle: () {
                              if (widget.isMapInteracting.value) {
                                widget.isMapInteracting.value = false;
                              }
                              _onCameraIdle();
                            },
                            markers: _markers,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            zoomGesturesEnabled: true,
                            scrollGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                            tiltGesturesEnabled: true,
                            mapType: MapType.normal,
                            compassEnabled: false,
                            buildingsEnabled: true,
                            indoorViewEnabled: false,
                            trafficEnabled: false,
                            mapToolbarEnabled: false,
                            minMaxZoomPreference: const MinMaxZoomPreference(
                              5,
                              20,
                            ),
                            gestureRecognizers:
                                <Factory<OneSequenceGestureRecognizer>>{
                                  Factory<OneSequenceGestureRecognizer>(
                                    () => EagerGestureRecognizer(),
                                  ),
                                  Factory<PanGestureRecognizer>(
                                    () => PanGestureRecognizer(),
                                  ),
                                  Factory<ScaleGestureRecognizer>(
                                    () => ScaleGestureRecognizer(),
                                  ),
                                  Factory<TapGestureRecognizer>(
                                    () => TapGestureRecognizer(),
                                  ),
                                  Factory<VerticalDragGestureRecognizer>(
                                    () => VerticalDragGestureRecognizer(),
                                  ),
                                  Factory<HorizontalDragGestureRecognizer>(
                                    () => HorizontalDragGestureRecognizer(),
                                  ),
                                },
                          ),
                          // Center-pinned marker (always in center of map)
                          Center(
                            child: AnimatedBuilder(
                              animation: _pinAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  // Offset marker up by half its height so tip is at center
                                  offset: Offset(
                                    0,
                                    _pinAnimation.value - R.h(25),
                                  ),
                                  child: child,
                                );
                              },
                              child: SvgPicture.asset(
                                ImageUtils.LocationPickerMarker,
                                width: R.w(40),
                                height: R.h(50),
                              ),
                            ),
                          ),
                          // Custom current location button
                          Positioned(
                            right: 10,
                            top: 10,
                            child: GestureDetector(
                              onTap: _goToCurrentLocation,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.my_location,
                                  color: CustomColors.primary(),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          // Zoom In button
                          Positioned(
                            right: 10,
                            bottom: 80,
                            child: GestureDetector(
                              onTap: _zoomIn,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: CustomColors.primary(),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          // Zoom Out button
                          Positioned(
                            right: 10,
                            bottom: 30,
                            child: GestureDetector(
                              onTap: _zoomOut,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.remove,
                                  color: CustomColors.primary(),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
