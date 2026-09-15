import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/api_resilience_service.dart';
import '../../utils/constants/app_colors.dart';
import '../../utils/constants/app_fonts.dart';
import '../../utils/responsive_utils.dart';

/// Shows a live countdown while the server is rate limiting us or a host
/// circuit is open. Renders nothing when everything is healthy.
class ApiResilienceBanner extends StatelessWidget {
  const ApiResilienceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ApiResilienceService>()) {
      return const SizedBox.shrink();
    }
    final ApiResilienceService service = Get.find<ApiResilienceService>();

    return Obx(() {
      if (service.isRateLimited.value) {
        return _bar(
          icon: LucideIcons.clock,
          background: CustomColors.warningSnackBar(),
          title: 'Too many requests'.tr,
          detail: service.isWaitUnknown
              ? 'Please slow down and try again shortly'.tr
              : '${'Try again in'.tr} ${service.formattedTime}',
        );
      }
      if (service.isCircuitOpen) {
        return _bar(
          icon: LucideIcons.serverCrash,
          background: CustomColors.failureSnackBar(),
          title: 'Server unreachable'.tr,
          detail: '${'Reconnecting in'.tr} ${service.circuitCooldownText}',
        );
      }
      return const SizedBox.shrink();
    });
  }

  Widget _bar({
    required IconData icon,
    required Color background,
    required String title,
    required String detail,
  }) {
    return Container(
      width: double.infinity,
      padding: R.pad(horizontal: 16, vertical: 12),
      color: background,
      child: Row(
        children: [
          Icon(icon, size: R.w(18), color: CustomColors.textPrimary()),
          SizedBox(width: R.w(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: CustomTextStyles.medium14.copyWith(
                    color: CustomColors.textPrimary(),
                  ),
                ),
                Text(
                  detail,
                  style: CustomTextStyles.regular14.copyWith(
                    color: CustomColors.paragraph(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
