
import 'package:flutter/material.dart';

import '../themes/app_theme.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_fonts.dart';

class CustomTextRow extends StatelessWidget {
  final String label;
  final String value;

  const CustomTextRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    bool isEmptyValue = value.toLowerCase() == "null";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: "$label : ",
              style: CustomTextStyles.medium16.copyWith(color: AppTheme.isDarkMode(context) ? CustomColors.white() : CustomColors.black()),


            ),
            TextSpan(
              text: isEmptyValue ? "No value provided" : value,
              style: CustomTextStyles.regular16.copyWith(
                color: isEmptyValue ? CustomColors.primary() : AppTheme.isDarkMode(context) ? CustomColors.white() : CustomColors.black(),

                fontWeight: isEmptyValue ? FontWeight.normal : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}