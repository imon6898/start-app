import 'dart:io';

import 'package:calldone/app/core/enums/enums.dart';
import 'package:calldone/app/utils/constants/app_assets.dart';
import 'package:calldone/app/utils/constants/app_colors.dart';
import 'package:calldone/app/widgets/custom_image.dart';
import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class AppBarLeading extends StatelessWidget {
  final Function()? onLeadingTap;
  final bool isForcefullyShow;
  final Icon? icon;

  const AppBarLeading({
    super.key,
    this.onLeadingTap,
    required this.isForcefullyShow,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      onTap:
          onLeadingTap ??
          () {
            if (MediaQuery.of(context).viewInsets.bottom > 0) {
              // FocusManager.instance.primaryFocus?.unfocus();
              FocusScope.of(context).unfocus();
              return;
            }
            // Use Navigator.pop instead of Get.back() to avoid snackbar issues
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
      child:
          isForcefullyShow || Navigator.canPop(context)
              ? Container(
                //color: Colors.red,
                width: R.w(42),
                height: R.w(50),
                padding: EdgeInsets.only(right: R.w(5)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(R.r(10)),
                  //color: CustomColors.black(),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon ??
                        CustomImage(
                          image: ImageUtils.platformBackIcon,
                          height: R.h(22),
                          width: R.w(22),
                          color: CustomColors.black(),
                          fit: BoxFit.contain,
                          imageType: ImageType.asset,
                          isSvg: true,
                        ),
                  ],
                ),
              )
              : SizedBox(width: R.w(0)),
    );
  }
}
