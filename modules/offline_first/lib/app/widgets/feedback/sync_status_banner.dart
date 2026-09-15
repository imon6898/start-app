import 'package:flutter/material.dart';
import 'package:flutter_starter/app/services/sync/sync_service.dart';
import 'package:flutter_starter/app/services/sync/sync_status.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Thin strip showing sync state and outbox depth. Hidden when idle and empty,
/// so a healthy app shows nothing.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key, this.showWhenIdle = false});

  /// Keep the "Synced" line visible instead of collapsing it.
  final bool showWhenIdle;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SyncService>()) return const SizedBox.shrink();
    final sync = Get.find<SyncService>();

    return Obx(() {
      final status = sync.status.value;
      final pending = sync.pendingCount.value;
      final failed = sync.deadLetterCount.value;

      if (!showWhenIdle && status == SyncStatus.idle && pending == 0 && failed == 0) {
        return const SizedBox.shrink();
      }

      final (icon, color, label) = _presentation(status, pending, failed);

      return Container(
        width: double.infinity,
        padding: R.pad(horizontal: 16, vertical: 8),
        color: color.withValues(alpha: 0.12),
        child: Row(
          children: [
            Icon(icon, size: R.sp(16), color: color),
            SizedBox(width: R.w(8)),
            Expanded(
              child: Text(
                label,
                style: CustomTextStyles.medium12.copyWith(color: color),
              ),
            ),
            if (failed > 0)
              GestureDetector(
                onTap: sync.retryFailed,
                child: Text(
                  'Retry'.tr,
                  style: CustomTextStyles.semiBold12.copyWith(
                    color: CustomColors.primary(),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  (IconData, Color, String) _presentation(SyncStatus status, int pending, int failed) {
    if (failed > 0) {
      return (LucideIcons.triangleAlert, CustomColors.error(), 'Sync failed'.tr);
    }
    switch (status) {
      case SyncStatus.syncing:
        return (LucideIcons.refreshCw, CustomColors.primary(), 'Syncing'.tr);
      case SyncStatus.offline:
        return (
          LucideIcons.cloudOff,
          CustomColors.warning(),
          'Offline — saved on this device'.tr,
        );
      case SyncStatus.error:
        return (LucideIcons.triangleAlert, CustomColors.error(), 'Sync failed'.tr);
      case SyncStatus.idle:
        return pending > 0
            ? (
                LucideIcons.upload,
                CustomColors.warning(),
                '@n pending'.trParams({'n': '$pending'}),
              )
            : (LucideIcons.cloudCheck, CustomColors.success(), 'Synced'.tr);
    }
  }
}
