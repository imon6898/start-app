// Wraps the app in GetMaterialApp.builder so the lock sits ABOVE the Navigator
// and no route change — including Get.offAllNamed — can dismiss it.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_starter/app/feature/app_lock/app_lock_controllers/app_lock_controller.dart';
import 'package:flutter_starter/app/feature/app_lock/app_lock_presentation/app_lock_screen.dart';

class AppLockGate extends StatelessWidget {
  final Widget? child;

  const AppLockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final Widget base = child ?? const SizedBox.shrink();
    // Not registered means the module is installed but not wired — fail open.
    if (!Get.isRegistered<AppLockController>()) return base;

    return Obx(() {
      if (!AppLockController.to.isLocked.value) return base;
      return Stack(
        children: [
          base,
          const Positioned.fill(child: AppLockScreen()),
        ],
      );
    });
  }
}
