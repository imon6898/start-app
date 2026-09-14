import 'dart:io';

/// Global platform utility class for platform-specific checks
class PlatformUtils {
  /// Check if the current platform is Android
  static bool get isAndroid => Platform.isAndroid;

  /// Check if the current platform is iOS
  static bool get isIOS => Platform.isIOS;

  /// Check if the current platform is Web
  static bool get isWeb => false; // Platform.isWeb is not available in dart:io

  /// Check if the current platform is Windows
  static bool get isWindows => Platform.isWindows;

  /// Check if the current platform is macOS
  static bool get isMacOS => Platform.isMacOS;

  /// Check if the current platform is Linux
  static bool get isLinux => Platform.isLinux;

  /// Check if the current platform is mobile (Android or iOS)
  static bool get isMobile => isAndroid || isIOS;

  /// Check if the current platform is desktop (Windows, macOS, or Linux)
  static bool get isDesktop => isWindows || isMacOS || isLinux;
}
