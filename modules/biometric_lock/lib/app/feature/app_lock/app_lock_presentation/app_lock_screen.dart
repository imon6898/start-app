// Full-screen lock. Rendered by AppLockGate above the Navigator, so it must not
// use Get.dialog / Get.snackbar — those are routes and would land underneath.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_starter/app/feature/app_lock/app_lock_controllers/app_lock_controller.dart';
import 'package:flutter_starter/app/services/biometric_service.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';

class AppLockScreen extends StatelessWidget {
  const AppLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppLockController>(
      builder: (controller) {
        return Scaffold(
          backgroundColor: CustomColors.artboardColor(),
          // Scrollable so a large text scale or a short window never overflows.
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: R.pad(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - R.h(48),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBadge(context, controller),
                      SizedBox(height: R.h(24)),
                      _buildHeadline(context, controller),
                      SizedBox(height: R.h(12)),
                      _buildError(context, controller),
                      SizedBox(height: R.h(32)),
                      _buildActions(context, controller),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(BuildContext context, AppLockController controller) {
    return Obx(() {
      final bool busy = controller.isAuthenticating.value;
      return Center(
        child: Container(
          height: R.h(96),
          width: R.h(96),
          decoration: BoxDecoration(
            color: CustomColors.primary().withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            busy ? LucideIcons.scanFace : LucideIcons.lockKeyhole,
            size: R.sp(40),
            color: CustomColors.primary(),
          ),
        ),
      );
    });
  }

  Widget _buildHeadline(BuildContext context, AppLockController controller) {
    return Obx(() {
      final BiometricStatus status = controller.capability.value;
      final String hint = status == BiometricStatus.success
          ? '${'Unlock with'.tr} ${controller.biometrics.biometricLabel}'
          : 'Unlock with your device passcode'.tr;
      return Column(
        children: [
          Text(
            'App locked'.tr,
            textAlign: TextAlign.center,
            style: CustomTextStyles.semiBold20.copyWith(
              color: CustomColors.textPrimary(),
            ),
          ),
          SizedBox(height: R.h(8)),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: CustomTextStyles.regular14.copyWith(
              color: CustomColors.textGray(),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildError(BuildContext context, AppLockController controller) {
    return Obx(() {
      final String message = controller.errorMessage.value;
      if (message.isEmpty) return const SizedBox.shrink();
      return Container(
        padding: R.pad(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CustomColors.errorBg(),
          borderRadius: BorderRadius.circular(R.r(8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.triangleAlert,
              size: R.sp(16),
              color: CustomColors.error(),
            ),
            SizedBox(width: R.w(8)),
            Expanded(
              child: Text(
                message,
                style: CustomTextStyles.regular12.copyWith(
                  color: CustomColors.error(),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildActions(BuildContext context, AppLockController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(() {
          final bool busy = controller.isAuthenticating.value;
          return CustomButton(
            text: 'Unlock'.tr,
            height: 48,
            borderRadius: R.r(10),
            loading: busy,
            onPressed: busy ? null : controller.unlock,
            icon: Icon(
              LucideIcons.fingerprint,
              size: R.sp(18),
              color: CustomColors.white(),
            ),
          );
        }),
        SizedBox(height: R.h(12)),
        // The OS prompt offers the passcode itself; this only spells it out.
        Text(
          'The system prompt also accepts your device PIN, pattern or passcode'
              .tr,
          textAlign: TextAlign.center,
          style: CustomTextStyles.regular12.copyWith(
            color: CustomColors.textGray(),
          ),
        ),
        _buildRecovery(context, controller),
        SizedBox(height: R.h(4)),
        _buildSignOut(context, controller),
      ],
    );
  }

  /// Only rendered when the device itself cannot authenticate — the one case
  /// where staying locked would mean losing access to the app for good.
  Widget _buildRecovery(BuildContext context, AppLockController controller) {
    return Obx(() {
      final BiometricStatus status = controller.capability.value;
      final bool deviceUnusable =
          status == BiometricStatus.noHardware ||
          status == BiometricStatus.unsupportedPlatform ||
          status == BiometricStatus.misconfigured;
      if (!deviceUnusable) return const SizedBox.shrink();
      return TextButton(
        onPressed: controller.disableBecauseUnavailable,
        child: Text(
          'Turn off app lock and continue'.tr,
          textAlign: TextAlign.center,
          style: CustomTextStyles.medium14.copyWith(
            color: CustomColors.primary(),
          ),
        ),
      );
    });
  }

  Widget _buildSignOut(BuildContext context, AppLockController controller) {
    return Obx(() {
      final bool confirming = controller.isConfirmingSignOut.value;
      return TextButton(
        onPressed: () {
          if (!confirming) {
            controller.isConfirmingSignOut.value = true;
            return;
          }
          controller.signOut();
        },
        child: Text(
          confirming
              ? 'Tap again to sign out and clear this session'.tr
              : 'Sign out instead'.tr,
          textAlign: TextAlign.center,
          style: CustomTextStyles.medium14.copyWith(
            color: confirming ? CustomColors.error() : CustomColors.textGray(),
          ),
        ),
      );
    });
  }
}
