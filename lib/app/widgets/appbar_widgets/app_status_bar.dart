import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Per-screen status-bar / navigation-bar styling.
///
/// Wraps [AnnotatedRegion] so the **currently visible route wins and the style
/// auto-reverts on pop** — unlike `SystemChrome.setSystemUIOverlayStyle`, which
/// is global + persistent and must NOT be used inside `build()` or controllers
/// (it leaks the previous screen's style onto the next and never restores).
///
/// Pick the factory by the icon colour your background needs:
///  • light background → [AppStatusBar.darkIcons]
///  • dark background  → [AppStatusBar.lightIcons]
///
/// The factories handle the Android (`statusBarIconBrightness`) vs iOS
/// (`statusBarBrightness`) inversion for you — getting that wrong is the most
/// common "status bar icons are invisible" bug.
class AppStatusBar extends StatelessWidget {
  final Widget child;
  final SystemUiOverlayStyle style;

  const AppStatusBar({super.key, required this.child, required this.style});

  /// Dark status-bar icons — use on LIGHT backgrounds.
  factory AppStatusBar.darkIcons({
    Key? key,
    required Widget child,
    Color statusBarColor = Colors.transparent,
    Color? navBarColor,
  }) => AppStatusBar(
    key: key,
    style: SystemUiOverlayStyle(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: Brightness.dark, // Android
      statusBarBrightness: Brightness.light, // iOS
      systemNavigationBarColor: navBarColor,
      systemNavigationBarIconBrightness: navBarColor == null
          ? null
          : Brightness.dark,
    ),
    child: child,
  );

  /// Light status-bar icons — use on DARK backgrounds.
  factory AppStatusBar.lightIcons({
    Key? key,
    required Widget child,
    Color statusBarColor = Colors.transparent,
    Color? navBarColor,
  }) => AppStatusBar(
    key: key,
    style: SystemUiOverlayStyle(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: Brightness.light, // Android
      statusBarBrightness: Brightness.dark, // iOS
      systemNavigationBarColor: navBarColor,
      systemNavigationBarIconBrightness: navBarColor == null
          ? null
          : Brightness.light,
    ),
    child: child,
  );

  /// Theme-level defaults for `appBarTheme.systemOverlayStyle` so every screen
  /// with an AppBar gets the correct status bar automatically.
  static const SystemUiOverlayStyle darkIconsStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );
  static const SystemUiOverlayStyle lightIconsStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) =>
      AnnotatedRegion<SystemUiOverlayStyle>(value: style, child: child);
}
