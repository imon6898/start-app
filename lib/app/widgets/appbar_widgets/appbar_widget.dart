import 'package:calldone/app/utils/constants/app_colors.dart';
import 'package:calldone/app/utils/constants/app_fonts.dart';
import 'package:calldone/app/widgets/appbar_widgets/app_bar_leading.dart';
import 'package:flutter/material.dart';

import '../../utils/responsive_utils.dart';

class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final Function()? onLeadingTap;
  final Color? backgroundColor;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? toolbarActions;
  final double? elevation;
  final PreferredSizeWidget? bottom;
  final double? titleSpacing;
  final bool isBackEnable;
  final bool isBackForcefullyShow;
  final bool? centerTitle;
  final Color? titleColor;
  final Icon? leadingIcon;
  final Widget? leadingWidget;
  final bool? isAutoLeadingEnable;
  final double? horizontalPadding;
  final double? additionalHeight;
  final EdgeInsets? actionsPadding;

  const AppBarWidget({
    this.onLeadingTap,
    this.backgroundColor,
    this.title,
    this.titleWidget,
    this.toolbarActions,
    this.centerTitle = true,
    this.elevation = 0,
    this.bottom,
    this.titleSpacing,
    this.isBackEnable = true,
    this.isBackForcefullyShow = false,
    this.isAutoLeadingEnable = true,
    this.titleColor,
    this.leadingIcon,
    this.leadingWidget,
    this.horizontalPadding,
    this.additionalHeight,
    this.actionsPadding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var isShow =
        (isBackEnable && Navigator.canPop(context)) || isBackForcefullyShow;
    return Container(
        color: backgroundColor ?? CustomColors.white(),
        child: SafeArea(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding ?? R.w(12),
                vertical: R.h(0),
              ),
              decoration: BoxDecoration(
                color: backgroundColor ?? CustomColors.white(),
                boxShadow: [
                  BoxShadow(
                    color: backgroundColor ?? CustomColors.whiteStroke(),
                    spreadRadius: -R.r(10), // Negative spread radius to contain the shadow
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],

              ),
              // decoration: BoxDecoration(
              //   color: backgroundColor ?? Colors.transparent,
              //   boxShadow: (elevation != null && elevation! > 0)
              //       ? [
              //           BoxShadow(
              //             color: CustomColors.appBarShadow().withAlpha(
              //               (0.1 * 255).round(),
              //             ),
              //             spreadRadius: 0,
              //             blurRadius: elevation!,
              //             offset: Offset(0, elevation! / 3),
              //           ),
              //         ]
              //       : null,
              // ),
              child: AppBar(
                forceMaterialTransparency: true,
                centerTitle: centerTitle,
                elevation: elevation,
                title: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding ?? R.w(12)),
                  child:
                  titleWidget ??
                      Text(
                        title ?? "",
                        style: CustomTextStyles.medium16.copyWith(color: titleColor ?? CustomColors.black()),
                        maxLines: 1,
                      ),
                ),
                toolbarHeight: AppBar().preferredSize.height,
                leadingWidth: isShow || leadingWidget != null ? R.w(41) : R.w(16),
                //before it was height+5w
                leading:
                leadingWidget ??
                    (isShow
                        ?
                    // (isAutoLeadingEnable ?? true)
                    //         ? AutoLeadingButton(
                    //           color:
                    //               leadingIcon?.color ??
                    //               Theme.of(context).iconTheme.color,
                    //         )
                    //         :
                    AppBarLeading(
                      onLeadingTap: onLeadingTap,
                      isForcefullyShow: isShow,
                      icon: leadingIcon,
                    )
                        : const SizedBox()),
                iconTheme: IconThemeData(
                  color: Theme.of(context).primaryColor,
                  size: R.sp(20),
                ),
                // titleTextStyle: TextStyle(color:const Color(0xff181818),fontSize: 22.sp,fontWeight: FontWeight.w700),
                titleSpacing: titleSpacing ?? (isShow ? -R.w(10) : 0),
                // actionsPadding: actionsPadding ?? EdgeInsets.all(8.w),
                actionsPadding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                actions: toolbarActions,

              ),
            )));
  }

  @override
  Size get preferredSize {
    final double baseHeight = R.isTablet
        ? (R.isLandscape ? 64 : 72)
        : kToolbarHeight; // 56

    return Size.fromHeight(baseHeight + (additionalHeight ?? 0));
  }

}
