import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/custom_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showDeleteConfirmationDialog({
  required VoidCallback onConfirm,
  String title = 'Sure about Deleting!',
  String message = "Once you Delete this you can't restore",
  String confirmText = 'Delete',
  String cancelText = 'Cancel',
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
                Icon(Icons.warning_amber_rounded, color: CustomColors.error()),
                SizedBox(width: R.w(8)),
                Text(
                  title,
                  style: CustomTextStyles.medium18.copyWith(
                    color: CustomColors.error(),
                  ),
                ),
              ],
            ),
            SizedBox(height: R.h(12)),
            Text(
              message,
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
                    text: cancelText,
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
                    text: confirmText,
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