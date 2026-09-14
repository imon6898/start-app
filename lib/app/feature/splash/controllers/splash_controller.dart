import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/custom_snack_bar.dart';
import '../../../services/data/cache_manager.dart';
import '../../../core/di/user_di.dart';

class SplashScreenController extends GetxController
    with GetTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> scaleAnimation;

  @override
  void onInit() {
    super.onInit();
    _initializeAnimations();
    _navigateToSignIn();
  }

  void _initializeAnimations() {
    animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeInOut),
    );

    animationController.forward();
  }

  Future<void> _navigateToSignIn() async {
    await Future.delayed(const Duration(seconds: 2));

    // Check location permissions
    await _checkLocationPermission();

    // Set guest mode and navigate to dashboard
    await _setGuestModeAndNavigate();
  }

  Future<void> _setGuestModeAndNavigate() async {
    try {
      // Check if user is already logged in
      final hasToken =
          CacheManager.token != null && CacheManager.token!.isNotEmpty;
      final hasUserData =
          CacheManager.userData != null && CacheManager.userData!.isNotEmpty;

      if (hasToken && hasUserData) {
        // User is already logged in, go to dashboard
        if (Get.isRegistered<UserDi>()) {
          await Get.find<UserDi>().refreshUser();
        } else {
          Get.put(UserDi(), permanent: true);
          await Get.find<UserDi>().refreshUser();
        }
        Get.offAllNamed(AppRoutes.DashboardScreen);
      } else {
        // Not logged in, check if onboarding has been seen
        if (CacheManager.hasSeenOnboarding) {
          Get.offAllNamed(AppRoutes.SigninScreen);
        } else {
          Get.offAllNamed(AppRoutes.OnboardingScreen);
        }
      }
    } catch (e) {
      Get.offAllNamed(AppRoutes.OnboardingScreen);
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are disabled, don't request permission
        return;
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          // Permission denied, show message
          _showLocationPermissionMessage();
        } else if (permission == LocationPermission.whileInUse) {
          // Permission granted for while in use, try to get background permission
          await _requestBackgroundLocationPermission();
        }
      } else if (permission == LocationPermission.whileInUse) {
        // Already have while in use permission, try to get background permission
        await _requestBackgroundLocationPermission();
      } else if (permission == LocationPermission.deniedForever) {
        // Permission permanently denied, show message
        _showLocationPermissionMessage();
      }
      // If permission is already always, no need to request again
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _requestBackgroundLocationPermission() async {
    try {
      // Request background location permission (Android 10+)
      await Geolocator.requestPermission();
    } catch (e) {
      // Handle error silently
    }
  }

  void _showLocationPermissionMessage() {
    showCustomSnackBar(
      context: Get.context!,
      type: SnackBarType.Warning,
      title: 'Location Permission',
      description:
          'Location permission is required for better app experience. Please enable it in settings.',
    );
  }

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }
}
