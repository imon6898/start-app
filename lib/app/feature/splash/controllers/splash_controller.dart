import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../../../services/local_data/cache_manager.dart';
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

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }
}
