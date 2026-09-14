import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_starter/app/core/enums/enums.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/custom_image.dart';

Future<void> customSuccessDialog(
  BuildContext context, {
  String? imagePath,
  bool? isSvg = false,
  IconData? icon,
  Color? iconColor,
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
                  // Pass imagePath for artwork, or icon to override the glyph.
                  if (imagePath != null && imagePath.isNotEmpty)
                    CustomImage(
                      image: imagePath,
                      width: R.w(80),
                      height: R.w(80),
                      imageType: ImageType.asset,
                      isSvg: isSvg ?? false,
                    )
                  else
                    Icon(
                      icon ?? LucideIcons.circleCheck,
                      size: R.w(64),
                      color: iconColor ?? CustomColors.success(),
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
