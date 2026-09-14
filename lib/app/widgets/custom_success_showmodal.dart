import 'package:calldone/app/core/enums/enums.dart';
import 'package:calldone/app/utils/constants/app_assets.dart';
import 'package:calldone/app/utils/constants/app_colors.dart';
import 'package:calldone/app/utils/constants/app_fonts.dart';
import 'package:calldone/app/utils/responsive_utils.dart';
import 'package:calldone/app/widgets/custom_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<void> customSuccessDialog(
  BuildContext context, {
  String? imagePath,
      bool? isSvg = false,
  String? title,
  String? message,
  Widget? widget,
  String? buttonText,
  VoidCallback? onPressed,
  VoidCallback? closeDialog,
}) async {
  showDialog(
    context: context,
    barrierDismissible: false, // user must tap button/close icon
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: R.w(20)), // full width card
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.r(12)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: R.h(10)), // spacing below close icon
                  CustomImage(
                    image: imagePath ?? ImageUtils.SuccessIcon,
                    width: R.w(80),
                    height: R.w(80),
                    imageType: ImageType.asset,
                    isSvg: isSvg ?? false,
                  ),
                  SizedBox(height: R.h(20)),
                  Text(
                    title ?? "",
                    textAlign: TextAlign.center,
                    style: CustomTextStyles.medium16.copyWith(
                      color: CustomColors.black(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: R.h(10)),
                  Text(
                    message ?? "",
                    textAlign: TextAlign.center,
                    style: CustomTextStyles.medium14.copyWith(
                      color: CustomColors.paragraph(),
                    ),
                  ),

                  
                  if (widget != null) ...[SizedBox(height: R.h(10)), widget],
                  SizedBox(height: R.h(10)),
                  
                ],
              ),
            ),

            /// top-right close button
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.red),
                onPressed: closeDialog ?? () {
                  // Use Navigator.pop for reliable dialog dismissal
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
