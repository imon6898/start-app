import 'package:flutter/material.dart';
import 'package:flutter_starter/app/services/background/background_run_log.dart';
import 'package:flutter_starter/app/services/background/background_task_service.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Settings-row view of the last background run, with a "Run now" nudge.
/// Drop it into a settings screen; it hides itself when the service is absent
/// or the platform has no background scheduler.
class BackgroundSyncTile extends StatelessWidget {
  const BackgroundSyncTile({super.key, this.showCounters = false});

  /// Adds the lifetime run / failure counts — the only way to see whether the
  /// OS is actually waking the app on a real device.
  final bool showCounters;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<BackgroundTaskService>()) {
      return const SizedBox.shrink();
    }
    final service = Get.find<BackgroundTaskService>();
    if (!service.isSupported) return const SizedBox.shrink();

    return Obx(() {
      final info = service.lastRun.value;
      final (icon, color) = _presentation(info.outcome);

      return Padding(
        padding: R.pad(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: R.sp(18), color: color),
            SizedBox(width: R.w(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Background sync'.tr,
                    style: CustomTextStyles.medium14.dark,
                  ),
                  SizedBox(height: R.h(2)),
                  Text(
                    _subtitle(info),
                    style: CustomTextStyles.regular12.gray,
                  ),
                  if (showCounters && info.hasRun) ...[
                    SizedBox(height: R.h(2)),
                    Text(
                      '${info.runCount} / ${info.failureCount}',
                      style: CustomTextStyles.regular10.gray,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: R.w(8)),
            SizedBox(
              width: R.w(96),
              child: CustomButton(
                text: 'Run now'.tr,
                onPressed: service.requestSyncSoon,
                textStyle: CustomTextStyles.medium12.onAccent,
              ),
            ),
          ],
        ),
      );
    });
  }

  String _subtitle(BackgroundRunInfo info) {
    if (!info.hasRun) return 'Never run'.tr;
    final when = DateFormat('MMM d, h:mm a').format(info.at!.toLocal());
    return '${_outcomeLabel(info.outcome)} · $when';
  }

  String _outcomeLabel(BackgroundOutcome? outcome) => switch (outcome) {
    BackgroundOutcome.success => 'Succeeded'.tr,
    BackgroundOutcome.retry => 'Will retry'.tr,
    BackgroundOutcome.failure => 'Failed'.tr,
    BackgroundOutcome.stopped => 'Stopped by the system'.tr,
    null => 'Never run'.tr,
  };

  (IconData, Color) _presentation(BackgroundOutcome? outcome) =>
      switch (outcome) {
        BackgroundOutcome.success => (
          LucideIcons.circleCheck,
          CustomColors.success(),
        ),
        BackgroundOutcome.retry => (LucideIcons.clock, CustomColors.warning()),
        BackgroundOutcome.stopped => (
          LucideIcons.clock,
          CustomColors.warning(),
        ),
        BackgroundOutcome.failure => (
          LucideIcons.circleAlert,
          CustomColors.error(),
        ),
        null => (LucideIcons.refreshCw, CustomColors.textGray()),
      };
}
