import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';

import 'package:flutter_starter/app/services/domain/api_const.dart';
import 'package:flutter_starter/app/services/ip_geo_location.dart';
import 'package:flutter_starter/app/services/ip_location_service.dart';
import 'package:flutter_starter/app/services/location_service.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';

/// Places-autocomplete field + Google Map whose centre pin is the selected location.
class ProfileLocationPicker extends StatefulWidget {
  final TextEditingController addressController;
  final Rx<LatLng> selectedLocation;

  /// True while the user drags the map — let the parent scroll view stand down.
  final RxBool isMapInteracting;

  final String title;
  final String? subTitle;
  final String hintText;
  final bool required;
  final double? mapHeight;

  /// Centre pin widget. Defaults to a Material location icon.
  final Widget? pinIcon;

  final Function(String)? onAddressChanged;
  final Function(LatLng)? onLocationChanged;

  const ProfileLocationPicker({
    super.key,
    required this.addressController,
    required this.selectedLocation,
    required this.isMapInteracting,
    this.title = "Address",
    this.subTitle,
    this.hintText = "Search for a location",
    this.required = false,
    this.mapHeight,
    this.pinIcon,
    this.onAddressChanged,
    this.onLocationChanged,
  });

  @override
  State<ProfileLocationPicker> createState() => _ProfileLocationPickerState();
}

class _ProfileLocationPickerState extends State<ProfileLocationPicker>
    with SingleTickerProviderStateMixin {
  static const LatLng _fallbackLatLng = LatLng(23.8103, 90.4125);

  final Geocoding _geocoding = Geocoding();

  GoogleMapController? _mapController;
  CameraPosition? _initialCameraPosition;
  bool _isLoadingLocation = false;

  late AnimationController _pinAnimationController;
  late Animation<double> _pinAnimation;

  @override
  void initState() {
    super.initState();

    _pinAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Pin hops up then settles when the map stops moving.
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

    _initializeLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _pinAnimationController.dispose();
    super.dispose();
  }

  /// Starts on the passed-in location, else the device location, else a fallback.
  Future<void> _initializeLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final existing = widget.selectedLocation.value;
      if (existing.latitude != 0 || existing.longitude != 0) {
        _initialCameraPosition = CameraPosition(target: existing, zoom: 14.0);
        if (widget.addressController.text.isEmpty) {
          await _getAddressFromLatLng(existing);
        }
      } else {
        await _getCurrentLocation();
      }
    } catch (e) {
      log('ProfileLocationPicker: init failed - $e');
      _initialCameraPosition = const CameraPosition(
        target: _fallbackLatLng,
        zoom: 14.0,
      );
    } finally {
      _initialCameraPosition ??= const CameraPosition(
        target: _fallbackLatLng,
        zoom: 14.0,
      );
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  /// GPS, then IP, then fallback coordinates.
  Future<void> _getCurrentLocation() async {
    try {
      final gpsPosition = await _tryGetGpsLocation();
      if (gpsPosition != null) {
        await _updateLocationUI(
          LatLng(gpsPosition.latitude, gpsPosition.longitude),
        );
        return;
      }

      final ipLatLng = await _getIpBasedLocation();
      await _updateLocationUI(ipLatLng ?? _fallbackLatLng);
    } catch (e) {
      log('ProfileLocationPicker: current location failed - $e');
    }
  }

  Future<Position?> _tryGetGpsLocation() async {
    try {
      return await LocationService.to.getCurrentLocation();
    } catch (e) {
      log('ProfileLocationPicker: GPS failed - $e');
      return null;
    }
  }

  Future<LatLng?> _getIpBasedLocation() async {
    try {
      final ipLocation = await IpLocationService.to.getApproximateLocation();
      if (ipLocation != null) {
        return LatLng(
          (ipLocation['latitude'] as num).toDouble(),
          (ipLocation['longitude'] as num).toDouble(),
        );
      }
    } catch (e) {
      log('ProfileLocationPicker: IP location failed - $e');
    }
    return null;
  }

  /// Commits a location: camera, controller text and callbacks.
  Future<void> _updateLocationUI(LatLng latLng) async {
    widget.selectedLocation.value = latLng;
    _initialCameraPosition = CameraPosition(target: latLng, zoom: 14.0);
    await _getAddressFromLatLng(latLng);
    widget.onLocationChanged?.call(latLng);
  }

  /// Reverse-geocodes into the address field; falls back to raw coordinates.
  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final address = _buildFormattedAddress(placemarks.first);
        widget.addressController.text = address;
        widget.onAddressChanged?.call(address);
        return;
      }

      widget.addressController.text = _coordinateText(position);
    } catch (e) {
      log('ProfileLocationPicker: reverse geocode failed - $e');
      widget.addressController.text = _coordinateText(position);
    }
  }

  String _coordinateText(LatLng position) =>
      '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

  /// Joins the useful placemark parts into one readable address line.
  String _buildFormattedAddress(Placemark place) {
    final parts = <String>[];

    if (place.street != null && place.street!.isNotEmpty) {
      if (place.street != 'Unnamed Road') parts.add(place.street!);
    } else if (place.name != null &&
        place.name!.isNotEmpty &&
        !RegExp(r'^\d+$').hasMatch(place.name!.trim())) {
      parts.add(place.name!);
    }

    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      parts.add(place.subLocality!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      parts.add(place.locality!);
    }
    // Skip the district when it just repeats the city.
    if (place.subAdministrativeArea != null &&
        place.subAdministrativeArea!.isNotEmpty &&
        place.subAdministrativeArea != place.locality) {
      parts.add(place.subAdministrativeArea!);
    }
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      parts.add(place.administrativeArea!);
    }
    if (place.postalCode != null && place.postalCode!.isNotEmpty) {
      parts.add(place.postalCode!);
    }
    if (place.country != null && place.country!.isNotEmpty) {
      parts.add(place.country!);
    }

    return parts.join(', ');
  }

  /// "My location" button: GPS if permitted, otherwise IP.
  Future<void> _goToCurrentLocation() async {
    try {
      setState(() => _isLoadingLocation = true);

      final hasPermission = await LocationService.to
          .checkAndRequestLocationPermission();

      if (hasPermission) {
        final position = await LocationService.to.getCurrentLocation();
        if (position != null) {
          final latLng = LatLng(position.latitude, position.longitude);
          widget.selectedLocation.value = latLng;
          await _getAddressFromLatLng(latLng);
          await _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(latLng, 14),
          );
          widget.onLocationChanged?.call(latLng);
        }
      } else {
        final ipLatLng = await _getIpBasedLocation();
        if (ipLatLng != null) {
          await _updateLocationUI(ipLatLng);
          await _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(ipLatLng, 14),
          );
        }
        Get.snackbar(
          'Location Permission',
          'Please enable location permission in settings for accurate location.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      log('ProfileLocationPicker: go to current location failed - $e');
      Get.snackbar('Error', 'Could not get current location');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _zoomIn() async =>
      _mapController?.animateCamera(CameraUpdate.zoomIn());

  Future<void> _zoomOut() async =>
      _mapController?.animateCamera(CameraUpdate.zoomOut());

  /// Tapping re-centres the map; the centre pin is the selection.
  void _onMapTap(LatLng position) {
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  /// Map settled — the centre of the viewport becomes the selected location.
  Future<void> _onCameraIdle() async {
    _pinAnimationController.forward(from: 0);

    if (_mapController == null) return;

    final LatLngBounds region = await _mapController!.getVisibleRegion();
    final LatLng center = LatLng(
      (region.northeast.latitude + region.southwest.latitude) / 2,
      (region.northeast.longitude + region.southwest.longitude) / 2,
    );

    widget.selectedLocation.value = center;
    await _getAddressFromLatLng(center);
    widget.onLocationChanged?.call(center);
  }

  /// Autocomplete result selected — move the map and fill the address.
  void _handlePlaceSelection(Prediction prediction) {
    final lat = double.tryParse(prediction.lat ?? '');
    final lng = double.tryParse(prediction.lng ?? '');

    if (lat != null && lng != null) {
      final latLng = LatLng(lat, lng);
      widget.selectedLocation.value = latLng;
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14));

      final address = prediction.description ?? '';
      widget.addressController.text = address;
      widget.addressController.selection = TextSelection.collapsed(
        offset: address.length,
      );
      widget.onAddressChanged?.call(address);
      widget.onLocationChanged?.call(latLng);
    }

    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          _buildSearchField(),
          _buildMap(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
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
          prefixIcon: Icon(Icons.location_on, color: CustomColors.primary()),
          suffixIcon: widget.addressController.text.isNotEmpty
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
        getPlaceDetailWithLatLng: _handlePlaceSelection,
        itemClick: (Prediction prediction) {
          widget.addressController.text = prediction.description ?? '';
          widget.addressController.selection = TextSelection.collapsed(
            offset: widget.addressController.text.length,
          );
          SystemChannels.textInput.invokeMethod('TextInput.hide');
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
                      style: CustomTextStyles.regular14.copyWith(height: 1.4),
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
    );
  }

  Widget _buildMap() {
    return Container(
      height: R.h(widget.mapHeight ?? 150),
      margin: EdgeInsets.only(top: R.h(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(R.r(8)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(R.r(8)),
        child: _initialCameraPosition == null
            ? Center(
                child: _isLoadingLocation
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: _initializeLocation,
                        child: const Text('Retry'),
                      ),
              )
            : Stack(
                children: [
                  GoogleMap(
                    key: const Key('google_map_profile_location_picker'),
                    initialCameraPosition: _initialCameraPosition!,
                    onMapCreated: (controller) => _mapController = controller,
                    onTap: _onMapTap,
                    onCameraMoveStarted: () {
                      if (!widget.isMapInteracting.value) {
                        widget.isMapInteracting.value = true;
                        FocusScope.of(context).unfocus();
                      }
                    },
                    onCameraIdle: () {
                      widget.isMapInteracting.value = false;
                      _onCameraIdle();
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    minMaxZoomPreference: const MinMaxZoomPreference(5, 20),
                    // Claim the gestures so an outer scroll view cannot steal them.
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
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
                  _buildCenterPin(),
                  _buildMapButton(
                    top: 10,
                    icon: Icons.my_location,
                    onTap: _goToCurrentLocation,
                  ),
                  _buildMapButton(bottom: 80, icon: Icons.add, onTap: _zoomIn),
                  _buildMapButton(
                    bottom: 30,
                    icon: Icons.remove,
                    onTap: _zoomOut,
                  ),
                ],
              ),
      ),
    );
  }

  /// Pin sits at the map centre; offset up so its tip marks the exact point.
  Widget _buildCenterPin() {
    return Center(
      child: AnimatedBuilder(
        animation: _pinAnimation,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _pinAnimation.value - R.h(25)),
          child: child,
        ),
        child:
            widget.pinIcon ??
            Icon(
              Icons.location_on,
              size: R.h(50),
              color: CustomColors.primary(),
            ),
      ),
    );
  }

  Widget _buildMapButton({
    double? top,
    double? bottom,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Positioned(
      right: 10,
      top: top,
      bottom: bottom,
      child: GestureDetector(
        onTap: onTap,
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
          child: Icon(icon, color: CustomColors.primary(), size: 24),
        ),
      ),
    );
  }
}
