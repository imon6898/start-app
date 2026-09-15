import 'package:flutter/material.dart';
import 'package:flutter_starter/app/feature/app_update/app_update_controllers/app_update_controller.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Body of the dismissible soft-update sheet. The title bar, handle and close
/// button come from showCustomBottomSheet.
class SoftUpdateSheet extends StatelessWidget {
  const SoftUpdateSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppUpdateController>(
      builder: (controller) {
        return SingleChildScrollView(
          padding: R.pad(horizontal: 20, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCopy(context, controller),
              SizedBox(height: R.h(20)),
              _buildActions(context, controller),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCopy(BuildContext context, AppUpdateController controller) {
    final info = controller.info;
    final message = info?.message.isNotEmpty == true
        ? info!.message
        : 'A newer version is available with fixes and improvements.'.tr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.rocket,
              size: R.h(20),
              color: CustomColors.primary(),
            ),
            SizedBox(width: R.w(8)),
            Expanded(
              child: Text(
                '${'Version'.tr} ${info?.latestVersion ?? ''}',
                style: CustomTextStyles.semiBold16.copyWith(
                  color: CustomColors.textPrimary(),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: R.h(10)),
        Text(
          message,
          style: CustomTextStyles.regular14.copyWith(
            color: CustomColors.paragraph(),
          ),
        ),
        if (info != null && info.releaseNotes.isNotEmpty) ...[
          SizedBox(height: R.h(14)),
          ...info.releaseNotes.map(
            (note) => Padding(
              padding: R.pad(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.sparkles,
                    size: R.h(14),
                    color: CustomColors.primary(),
                  ),
                  SizedBox(width: R.w(8)),
                  Expanded(
                    child: Text(
                      note,
                      style: CustomTextStyles.regular12.copyWith(
                        color: CustomColors.paragraph(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        SizedBox(height: R.h(14)),
        Text(
          '${'Installed'.tr}: ${controller.currentVersion}',
          style: CustomTextStyles.regular12.copyWith(
            color: CustomColors.textGray(),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, AppUpdateController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(
          () => CustomButton(
            text: 'Update now'.tr,
            height: 46,
            borderRadius: R.r(10),
            loading: controller.isLaunchingStore.value,
            icon: Icon(
              LucideIcons.download,
              size: R.h(18),
              color: CustomColors.white(),
            ),
            onPressed: () async {
              await controller.openStore();
              // Closing here makes the snooze in showSoftUpdateSheet fire.
              if (Get.isBottomSheetOpen ?? false) Get.back();
            },
          ),
        ),
        SizedBox(height: R.h(10)),
        TextButton(
          onPressed: () => Get.back(),
          child: Text(
            'Remind me later'.tr,
            style: CustomTextStyles.medium14.copyWith(
              color: CustomColors.textGray(),
            ),
          ),
        ),
      ],
    );
  }
}
