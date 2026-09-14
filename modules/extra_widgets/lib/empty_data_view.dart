import 'package:flutter_starter/app/core/enums/enums.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/custom_image.dart';
import 'package:flutter/material.dart';

/// Centered empty state: image (or fallback icon), title and subtitle.
class EmptyDataView extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? imagePath;
  final double? width;
  final double? height;
  final bool isSvg;
  final bool? circlar;

  const EmptyDataView({
    Key? key,
    this.title,
    this.subtitle,
    this.imagePath,
    this.width,
    this.height,
    this.isSvg = false,
    this.circlar = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imagePath != null && imagePath!.isNotEmpty)
            CustomImage(
              image: imagePath!,
              height: width ?? R.w(140),
              width: height ?? R.w(140),
              imageType: ImageType.asset,
              isSvg: isSvg,
              circular: circlar!,
            )
          else
            Container(
              width: R.w(100),
              height: R.w(100),
              decoration: BoxDecoration(
                color: CustomColors.gray(),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: R.sp(48),
                color: CustomColors.textGray(),
              ),
            ),

          SizedBox(height: R.h(16)),

          Text(
            title ?? "",
            style: CustomTextStyles.medium16.copyWith(
              color: CustomColors.black(),
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: R.h(6)),

          Text(
            subtitle ?? "",
            style: CustomTextStyles.regular14.copyWith(
              color: CustomColors.textGray(),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
