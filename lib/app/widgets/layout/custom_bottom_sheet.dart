import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Future<T?> showCustomBottomSheet<T>({
  required String sheetTitle,
  required Widget content,
  double? height,
  double? width,
  bool centerTitle = true,
}) {
  final context = Get.context!;
  final defaultHeight = MediaQuery.of(context).size.height * R.h(0.5);
  final defaultWidth = MediaQuery.of(context).size.width;

  return Get.bottomSheet<T>(
    Container(
      width: width ?? defaultWidth,
      height: height ?? defaultHeight,
      decoration: BoxDecoration(
        color: CustomColors.white(),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(R.r(12)),
          topRight: Radius.circular(R.r(12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: EdgeInsets.only(top: R.h(10)),
              width: R.w(33),
              height: 4,
              decoration: BoxDecoration(
                color: CustomColors.handleBar(),
                borderRadius: BorderRadius.circular(R.r(2)),
              ),
            ),
          ),
          // Header
          Container(
            decoration: BoxDecoration(
              color: CustomColors.white(),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(R.r(12)),
                topRight: Radius.circular(R.r(12)),
              ),
              border: Border(
                bottom: BorderSide(color: CustomColors.whiteStroke(), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: centerTitle
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                Expanded(flex: 1, child: SizedBox(width: 2)),
                if (!centerTitle)
                  Text(
                    sheetTitle,
                    style: CustomTextStyles.semiBold18.copyWith(
                      color: CustomColors.black(),
                    ),
                  ),
                if (centerTitle)
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: Text(
                        sheetTitle,
                        style: CustomTextStyles.semiBold18.copyWith(
                          color: CustomColors.black(),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Builder(
                      builder: (innerContext) => IconButton(
                        icon: Icon(
                          LucideIcons.x,
                          color: CustomColors.error(),
                          size: R.h(18),
                        ),
                        onPressed: () {
                          Navigator.of(innerContext).pop();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: R.h(10)),

          // Content
          Expanded(child: content),
        ],
      ),
    ),
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(R.r(16))),
    ),
  );
}
