///How to use
library;

/*
import 'package:your_project/utils/custom_colors.dart';

Container(
  color: CustomColors.mainColor,
  child: Text(
    'Hello World',
    style: TextStyle(color: CustomColors.white),
  ),
);

*/

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../themes/theme_controller.dart';

class CustomColors {
  // Helper method to check if dark mode is active
  static bool get _isDarkMode {
    try {
      final themeController = Get.find<ThemeController>();
      return themeController.isDarkMode;
    } catch (_) {
      // Fallback if ThemeController not initialized yet
      return Theme.of(Get.context!).brightness == Brightness.dark;
    }
  }

  // === PRIMARY & SECONDARY ===
  static Color primary() {
    return _isDarkMode
        ? const Color(0xFF6BBF56)
        : const Color(0xFF58A645);
  }

  static Color secondary() {
    return _isDarkMode
        ? const Color(0xFFD8A648)
        : const Color(0xFFC4973F);
  }

  // === STATUS COLORS ===
  static Color success() {
    return const Color(0xFF3AA961);
  }

  static Color error() {
    return const Color(0xFFD82424);
  }

  // === TEXT COLORS ===
  static Color textPrimary() {
    return _isDarkMode
        ? CustomColors.white()
        : const Color(0xFF006466);
  }

  static Color paragraph() {
    return _isDarkMode
        ? const Color(0xFF44444F)
        : const Color(0xFF44444F);
  }

  static Color artboardColor() {
    return _isDarkMode
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFF8F8F8);
  }

  static Color textGray() {
    return _isDarkMode
        ? const Color(0xFF5A5A5A)
        : const Color(0xFFB1B1B1);
  }

  static Color lightGrey() {
    return _isDarkMode
        ? const Color(0xFF434343)
        : const Color(0xFFD3D3D3);
  }

  // === BACKGROUND COLORS ===
  static Color BGColor() {
    return _isDarkMode
        ? const Color(0xFF000000)
        : const Color(0xFFF8F8F8);
  }

  static Color gray() {
    return _isDarkMode
        ? const Color(0xFF2C2C2C)
        : const Color(0xFFF4F4F4);
  }

  static Color redeemColor() {
    return _isDarkMode
        ? const Color(0xFFC55309)
        : const Color(0xFFC55309);
  }

  static Color gray2() {
    return _isDarkMode
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFA8A8A8);
  }

  // === STROKE COLORS ===
  static Color whiteStroke() {
    return _isDarkMode
        ? const Color(0xFF3F3F3F)
        : const Color(0xFFE1E3E4);
  }

  static Color tableStroke() {
    return _isDarkMode
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFF0F1F1);
  }

  static Color stroke() {
    return _isDarkMode
        ? const Color(0xFF3F3F3F)
        : const Color(0xFFDDDDDD);
  }

  // === UI ELEMENTS ===
  static Color card() {
    return _isDarkMode
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF9F8F6);
  }

  static Color navbar() {
    return _isDarkMode
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF9F8F6);
  }

  static Color navbarSelected() {
    return _isDarkMode
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFF7E0E6);
  }

  static Color yellow() {
    return const Color(0xFFFFA903); // Same for both themes
  }

  static Color starColor() {
    return const Color(0xFFE5780B); // Same for both themes
  }

  static Color green() {
    return const Color(0xFF218C09); // Same for both themes
  }

  static Color successGreen() {
    return const Color(0xFF3AA961); // Same for both themes
  }

  static Color transparent() {
    return const Color(0x00000000);
  }

  // === BLACK & WHITE ===
  static Color black() {
    return _isDarkMode
        ? const Color(0xFFFAFAFA)
        : const Color(0xFF222222);
  }

  static Color white() {
    return _isDarkMode
        ? const Color(0xFF121212)
        : const Color(0xFFFFFFFF);
  }

  static Color blue() {
    return _isDarkMode
        ? const Color(0xFF1E3A8A)
        : const Color(0xFF2563EB);
  }

  static Color pointAssentBorder() {
    return _isDarkMode
        ? const Color(0xFF5C4F3F)
        : const Color(0xFFFFE0C2);
  }
  static Color pointAssent() {
    return _isDarkMode
        ? const Color(0xFF4C4946)
        : const Color(0xFFFFFAF5);
  }

  static Color translateBlue() {
    return _isDarkMode
        ? const Color(0xFF4B8BF5)
        : const Color(0xFF4B8BF5);
  }

  static Color pink() {
    return _isDarkMode
        ? const Color(0xFF7E22CE)
        : const Color(0xFF9435EA);
  }

  // === SNACKBAR BACKGROUNDS ===
  static Color successSnackBar() {
    return _isDarkMode
        ? const Color(0xFF1B3D33)
        : const Color(0xFFD8FFF2);
  }

  static Color appBarShadow() {
    return _isDarkMode
        ? const Color(0xFF1B3D33)
        : const Color(0xFF878787);
  }

  static Color warningSnackBar() {
    return _isDarkMode
        ? const Color(0xFF423D2B)
        : const Color(0xFFFEF1D4);
  }

  static Color failureSnackBar() {
    return _isDarkMode
        ? const Color(0xFF5F2C2C)
        : const Color(0xFFFFC3C3);
  }

  static Color lightSnackBar() {
    return _isDarkMode
        ? const Color(0xFF2A2A2A)
        : const Color(0xEFEFEFF7); // Double check this alpha if needed
  }

  static Color offWhiteBGColor() {
    return _isDarkMode
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF9FAFB); // Double check this alpha if needed
  }

  static Color warmOffWhiteBG() {
    return _isDarkMode
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFFCEFE2);
  }

  static Color accentOrange() {
    return _isDarkMode
        ? const Color(0xFFFFA14A)
        : const Color(0xFFFF8D28);
  }

  // === BADGE COLORS ===
  static Color badgeBlue() {
    return const Color(0xFF3F84C4);
  }

  static Color badgeBlueBg() {
    return _isDarkMode
        ? const Color(0xFF1A2A3A)
        : const Color(0xFFECF3F9);
  }

  // === TEXT GRAY (Figma "Text Gray" #7C7F85) ===
  static Color textGrayDark() {
    return _isDarkMode
        ? const Color(0xFF9A9DA3)
        : const Color(0xFF7C7F85);
  }

  // === STATUS BADGE BACKGROUNDS ===
  static Color successBg() {
    return _isDarkMode
        ? const Color(0xFF1A3D2A)
        : const Color(0xFFEBF6EF);
  }

  static Color errorBg() {
    return _isDarkMode
        ? const Color(0xFF3D1A1A)
        : const Color(0xFFFBE9E9);
  }

  static Color warningOrange() {
    return const Color(0xFFE79829);
  }

  static Color warningBg() {
    return _isDarkMode
        ? const Color(0xFF3D3520)
        : const Color(0xFFFDF5EA);
  }

  // Courier (in-transit / picked-up / out-for-delivery)
  static Color courierGreen() {
    return const Color(0xFF9CC43F);
  }

  static Color courierGreenBg() {
    return _isDarkMode
        ? const Color(0xFF253318)
        : const Color(0xFFF5F9EC);
  }

  // === HANDLE BAR ===
  static Color handleBar() {
    return const Color(0xFFC4C4C4);
  }

}
