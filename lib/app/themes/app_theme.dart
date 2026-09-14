import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.white,
  );

  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.black,
  );

  // Method to check if dark mode is enabled
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // Get background color dynamically
  static Color backgroundColor(BuildContext context) {
    return isDarkMode(context) ? Colors.black : Colors.white;
  }

  // Get divider color dynamically
  static Color dividerColor(BuildContext context) {
    return isDarkMode(context)
        ? const Color(0xff3f3f3f)
        : const Color(0xffDDDDDD);
  }

  // Get transparent background for dark mode
  static Color transparentBackground(BuildContext context) {
    return isDarkMode(context) ? Colors.transparent : Colors.white;
  }
}
