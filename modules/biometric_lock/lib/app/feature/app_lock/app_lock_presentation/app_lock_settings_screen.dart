// Opt-in toggle, background timeout chooser and a live capability read-out.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_starter/app/feature/app_lock/app_lock_controllers/app_lock_controller.dart';
import 'package:flutter_starter/app/feature/app_lock/app_lock_logic/app_lock_store.dart';
import 'package:flutter_starter/app/services/biometric_service.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/layout/layout_components.dart';

class AppLockSettingsScreen extends StatelessWidget {
  const AppLockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppLockController>(
      builder: (controller) {
        return Scaffold(
          backgroundColor: CustomColors.artboardColor(),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
            child: AppBarWidget(title: 'App lock'.tr),
          ),
          body: SingleChildScrollView(
            padding: R.pad(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildToggle(context, controller),
                SizedBox(height: R.h(16)),
                _buildTimeout(context, controller),
                SizedBox(height: R.h(16)),
                _buildCapability(context, controller),
                SizedBox(height: R.h(16)),
                _buildError(context, controller),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggle(BuildContext context, AppLockController controller) {
    return CardContainer(
      backgroundColor: CustomColors.card(),
      child: Obx(() {
        final bool busy = controller.isAuthenticating.value;
        return Row(
          children: [
            Icon(
              LucideIcons.fingerprint,
              size: R.sp(22),
              color: CustomColors.primary(),
            ),
            SizedBox(width: R.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'Require'.tr} ${controller.biometrics.biometricLabel}',
                    style: CustomTextStyles.semiBold14.copyWith(
                      color: CustomColors.textPrimary(),
                    ),
                  ),
                  SizedBox(height: R.h(4)),
                  Text(
                    'Ask to unlock on launch and after time in the background'
                        .tr,
                    style: CustomTextStyles.regular12.copyWith(
                      color: CustomColors.textGray(),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: controller.isEnabled.value,
              activeThumbColor: CustomColors.primary(),
              onChanged: busy ? null : (value) => controller.setEnabled(value),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTimeout(BuildContext context, AppLockController controller) {
    return Obx(() {
      if (!controller.isEnabled.value) return const SizedBox.shrink();
      return CardContainer(
        backgroundColor: CustomColors.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lock after'.tr,
              style: CustomTextStyles.semiBold14.copyWith(
                color: CustomColors.textPrimary(),
              ),
            ),
            SizedBox(height: R.h(4)),
            Text(
              'Time the app may stay in the background before it locks'.tr,
              style: CustomTextStyles.regular12.copyWith(
                color: CustomColors.textGray(),
              ),
            ),
            SizedBox(height: R.h(12)),
            Wrap(
              spacing: R.w(8),
              runSpacing: R.h(8),
              children: AppLockStore.timeoutOptions
                  .map((seconds) => _buildTimeoutChip(controller, seconds))
                  .toList(),
            ),
            SizedBox(height: R.h(12)),
            TextButton.icon(
              onPressed: controller.lockNow,
              icon: Icon(
                LucideIcons.lock,
                size: R.sp(16),
                color: CustomColors.primary(),
              ),
              label: Text(
                'Lock now'.tr,
                style: CustomTextStyles.medium14.copyWith(
                  color: CustomColors.primary(),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTimeoutChip(AppLockController controller, int seconds) {
    final bool selected = controller.timeoutSeconds.value == seconds;
    return GestureDetector(
      onTap: () => controller.setTimeoutSeconds(seconds),
      child: Container(
        padding: R.pad(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? CustomColors.primary()
              : CustomColors.artboardColor(),
          borderRadius: BorderRadius.circular(R.r(20)),
          border: Border.all(color: CustomColors.stroke()),
        ),
        child: Text(
          AppLockController.timeoutLabel(seconds),
          style: CustomTextStyles.medium12.copyWith(
            color: selected ? CustomColors.white() : CustomColors.textGray(),
          ),
        ),
      ),
    );
  }

  Widget _buildCapability(BuildContext context, AppLockController controller) {
    return Obx(() {
      final BiometricStatus status = controller.capability.value;
      if (status == BiometricStatus.success) return const SizedBox.shrink();
      return Container(
        padding: R.pad(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CustomColors.warningBg(),
          borderRadius: BorderRadius.circular(R.r(8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.triangleAlert,
              size: R.sp(16),
              color: CustomColors.warning(),
            ),
            SizedBox(width: R.w(8)),
            Expanded(
              child: Text(
                BiometricService.messageFor(status),
                style: CustomTextStyles.regular12.copyWith(
                  color: CustomColors.textPrimary(),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildError(BuildContext context, AppLockController controller) {
    return Obx(() {
      final String message = controller.errorMessage.value;
      if (message.isEmpty) return const SizedBox.shrink();
      return Text(
        message,
        style: CustomTextStyles.regular12.copyWith(color: CustomColors.error()),
      );
    });
  }
}
