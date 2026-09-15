import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void showDeleteConfirmationDialog({
  required VoidCallback onConfirm,
  // Nullable, not defaulted — a default value must be const, and `.tr` isn't.
  String? title,
  String? message,
  String? confirmText,
  String? cancelText,
}) {
  Get.dialog(
    Dialog(
      backgroundColor: CustomColors.white(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.triangleAlert, color: CustomColors.error()),
                SizedBox(width: R.w(8)),
                Text(
                  title ?? 'Delete this item?'.tr,
                  style: CustomTextStyles.medium18.copyWith(
                    color: CustomColors.error(),
                  ),
                ),
              ],
            ),
            SizedBox(height: R.h(12)),
            Text(
              message ?? 'Once you delete this you can’t restore it.'.tr,
              textAlign: TextAlign.center,
              style: CustomTextStyles.regular14.copyWith(
                color: CustomColors.paragraph(),
              ),
            ),
            SizedBox(height: R.h(16)),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    backgroundColor: CustomColors.gray(),
                    borderRadius: 8,
                    height: R.h(22),
                    onPressed: () => Navigator.of(Get.overlayContext!).pop(),
                    text: cancelText ?? 'Cancel'.tr,
                    textStyle: CustomTextStyles.medium16.copyWith(
                      color: CustomColors.black(),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    backgroundColor: CustomColors.error(),
                    borderRadius: 8,
                    height: R.h(22),
                    onPressed: () {
                      Navigator.of(Get.overlayContext!).pop();
                      onConfirm();
                    },
                    text: confirmText ?? 'Delete'.tr,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: true,
  );
}
