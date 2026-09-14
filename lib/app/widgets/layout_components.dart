import 'package:flutter/material.dart';
import 'package:calldone/app/utils/constants/app_colors.dart';
import 'package:calldone/app/utils/constants/app_fonts.dart';
import 'package:calldone/app/utils/responsive_utils.dart';

/// Reusable Card Container Component
class CardContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? borderRadius;
  final List<BoxShadow>? boxShadow;

  const CardContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? EdgeInsets.all(R.w(16)),
      decoration: BoxDecoration(
        color: backgroundColor ?? CustomColors.white(),
        borderRadius: BorderRadius.circular(borderRadius ?? R.r(8)),
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}

/// Reusable Section Header Component
class SectionHeader extends StatelessWidget {
  final String title;
  final TextStyle? titleStyle;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.titleStyle,
    this.subtitle,
    this.subtitleStyle,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.symmetric(horizontal: R.w(16), vertical: R.h(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: titleStyle ?? CustomTextStyles.semiBold14.copyWith(color: CustomColors.black()),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: R.h(4)),
                  Text(
                    subtitle!,
                    style: subtitleStyle ?? CustomTextStyles.regular12.copyWith(color: CustomColors.textGray()),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Reusable Divider Component
class CustomDivider extends StatelessWidget {
  final double? height;
  final double? thickness;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const CustomDivider({
    super.key,
    this.height,
    this.thickness,
    this.color,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: margin,
      child: Divider(
        height: height ?? 1,
        thickness: thickness ?? 1,
        color: color ?? Colors.grey[300],
      ),
    );
  }
}

/// Reusable Loading Widget Component
class LoadingWidget extends StatelessWidget {
  final String? message;
  final double? size;

  const LoadingWidget({
    super.key,
    this.message,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size ?? R.h(30),
            height: size ?? R.h(30),
            child: CircularProgressIndicator(
              color: CustomColors.primary(),
            ),
          ),
          if (message != null) ...[
            SizedBox(height: R.w(16)),
            Text(
              message!,
              style: CustomTextStyles.semiBold14.copyWith(color: CustomColors.textGray()),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reusable Empty State Component
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(R.w(32)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: R.w(64),
              color: CustomColors.textGray(),
            ),
            SizedBox(height: R.w(16)),
            Text(
              title,
              style: CustomTextStyles.semiBold18.copyWith(color: CustomColors.black()),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: R.w(8)),
              Text(
                subtitle!,
                style: CustomTextStyles.semiBold14.copyWith(color: CustomColors.textGray()),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: R.h(24)),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
