/*
CustomButton(
                    text: "SignIN",
                    onPressed: () {
                      print("Learn More Pressed!");
                    },
                    backgroundColor: CustomColors.mainColor,
                    padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
                    textStyle: CustomTextStyles.bold22.copyWith(color: CustomColors.white()),
                  ),
*/

import 'package:calldone/app/utils/constants/app_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/constants/app_colors.dart';
import '../utils/responsive_utils.dart';

class CustomButton extends StatelessWidget {
  final String? text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final double borderRadius;
  final EdgeInsets padding;
  final TextStyle? textStyle;
  final double height;
  final bool loading;
  final Widget? icon;

  const  CustomButton({
    super.key,
    this.text,
    required this.onPressed,
    this.backgroundColor,
    this.borderRadius = 6.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 0.0),
    this.textStyle,
    this.height = 34.0,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = loading || onPressed == null;

    return SizedBox(
      height: R.h(height),
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: padding,
          backgroundColor: backgroundColor ?? CustomColors.primary(),
          disabledBackgroundColor: CustomColors.primary().withOpacity(
            0.8,
          ), // optional
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text ?? '',
                style:
                    textStyle ??
                    CustomTextStyles.medium16.copyWith(
                      color: CustomColors.white(),
                    ),
              ),
              if (icon != null) ...[SizedBox(width: R.w(8)), icon!],
              if (loading) ...[
                SizedBox(width: R.w(8)),
                SizedBox(
                  width: R.w(18),
                  height: R.w(18),
                  child: CupertinoActivityIndicator(
                    radius: 12,
                    color: CustomColors.white(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CustomOutlinedButton extends StatelessWidget {
  final String? text;
  final VoidCallback onPressed;
  final Color? borderColor;
  final Color? textColor;
  final double borderRadius;
  final EdgeInsets padding;
  final TextStyle? textStyle;
  final double height;
  final Widget? icon; // NEW
  final bool? iconRight; // NEW
  final Color? backgroundColor; // NEW
  final double? width; // NEW
  final bool loading;

  const CustomOutlinedButton({
    super.key,
    this.text,
    required this.onPressed,
    this.borderColor,
    this.textColor,
    this.borderRadius = 6.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 0.0),
    this.textStyle,
    this.height = 34.0,
    this.loading = false,
    this.icon,
    this.iconRight = false,
    this.backgroundColor,
    this.width = double.infinity, // NEW
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = loading || onPressed == null;

    final defaultTextStyle = CustomTextStyles.medium16.copyWith(
      color: textColor ?? CustomColors.black(),
    );

    return SizedBox(
      height: R.h(height),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? CustomColors.white(),
          borderRadius: BorderRadius.circular(R.r(borderRadius)),
          boxShadow: [
            BoxShadow(
              color: CustomColors.black().withOpacity(0.1),
              offset: const Offset(0, 2),
              blurRadius: 5,
              spreadRadius: 0,
            ),
          ],
        ),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: padding,
            backgroundColor: backgroundColor ?? CustomColors.transparent(), // NEW
            side: BorderSide(
              color: borderColor ?? CustomColors.whiteStroke(),
              width: 1.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(R.r(borderRadius)),
            ),
            shadowColor: Colors.black.withOpacity(0.1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon on left (if iconRight is false)
              if (icon != null && iconRight != true) ...[icon!, SizedBox(width: R.w(8))],
              text != null
                  ? Text(
                      text!,
                      style:
                          textStyle?.copyWith(color: textColor) ??
                          defaultTextStyle,
                    )
                  : SizedBox(),
              // Icon on right (if iconRight is true)
              if (icon != null && iconRight == true) ...[SizedBox(width: R.w(8)), icon!],
              if (loading) ...[
                SizedBox(width: R.w(8)),
                SizedBox(
                  width: R.w(18),
                  height: R.w(18),
                  child: CupertinoActivityIndicator(
                    radius: 12,
                    color: CustomColors.white(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
