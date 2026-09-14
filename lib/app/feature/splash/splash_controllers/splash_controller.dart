import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../../../services/local_data/cache_manager.dart';
import '../../../core/di/user_di.dart';
import '../../../services/domain/dev_tools.dart';

class SplashScreenController extends GetxController
    with GetTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> scaleAnimation;

  @override
  void onInit() {
    super.onInit();
    _initializeAnimations();
    _navigateAfterSplash();
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

  Future<void> _navigateAfterSplash() async {
    await Future.delayed(const Duration(seconds: 2));
    await _routeFromSession();
  }

  /// Picks the first real screen from cached session state.
  Future<void> _routeFromSession() async {
    try {
      final hasToken = CacheManager.token?.isNotEmpty ?? false;
      final hasUserData = CacheManager.userData?.isNotEmpty ?? false;

      if (hasToken && hasUserData) {
        // UserDi is a permanent singleton from ViewModelBinding.
        await Get.find<UserDi>().refreshUser();
        Get.offAllNamed(AppRoutes.DashboardScreen);
      } else if (CacheManager.hasSeenOnboarding) {
        Get.offAllNamed(AppRoutes.SigninScreen);
      } else {
        Get.offAllNamed(AppRoutes.OnboardingScreen);
      }
    } catch (e) {
      // A corrupt cache must not trap the user on the splash screen.
      devPrint('$e', tag: 'Splash');
      Get.offAllNamed(AppRoutes.OnboardingScreen);
    }
  }

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }
}
