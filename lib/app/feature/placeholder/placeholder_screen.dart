import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../utils/constants/app_colors.dart';
import '../../utils/constants/app_fonts.dart';
import '../../utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';

/// Stands in for a screen the template does not ship (dashboard, onboarding,
/// legal pages). Registered in [AppPages] so auth navigation never dead-ends —
/// replace each route with your own page.
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.BGColor(),
      appBar: AppBarWidget(title: title),
      body: Center(
        child: Padding(
          padding: R.pad(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.layoutTemplate,
                size: R.sp(48),
                color: CustomColors.textGray(),
              ),
              SizedBox(height: R.h(16)),
              Text(
                title,
                textAlign: TextAlign.center,
                style: CustomTextStyles.semiBold16,
              ),
              SizedBox(height: R.h(8)),
              Text(
                'This screen is not part of the starter. Point '
                '${Get.currentRoute} at your own page in AppPages.',
                textAlign: TextAlign.center,
                style: CustomTextStyles.regular14.gray,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
