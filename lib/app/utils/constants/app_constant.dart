import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Location related constants
class LocationConstants {
  static double? latitude;
  static double? longitude;
  static String? locationName;

  static String get formattedCoordinates {
    if (latitude == null || longitude == null) return 'Location not available';
    return '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}';
  }

  static bool get hasLocation => latitude != null && longitude != null;
}

double screenHeight(BuildContext context) {
  return MediaQuery.of(context).size.height;
}

double screenWidth(BuildContext context) {
  return MediaQuery.of(context).size.width;
}

/// Basic scale factor based on screen width only
/// Use scaleWithOrientation() for orientation-aware scaling
double scale() {
  final screenWidth = MediaQuery.of(Get.context!).size.width;
  return screenWidth < 360
      ? 0.85
      : screenWidth < 480
          ? 1.0
          : screenWidth < 720
              ? 1.1
              : 1.2;
}

/// Advanced scale factor that considers both device type and orientation
///
/// Scale factors:
/// - Phone Portrait: 0.85 - 1.0
/// - Phone Landscape: 0.9 - 1.05
/// - Tablet Portrait: 1.1 - 1.2
/// - Tablet Landscape: 1.15 - 1.3
double scaleWithOrientation() {
  final mediaQuery = MediaQuery.of(Get.context!);
  final screenWidth = mediaQuery.size.width;
  final shortestSide = mediaQuery.size.shortestSide;
  final isLandscape = mediaQuery.orientation == Orientation.landscape;
  final isTablet = shortestSide >= 600;

  if (isTablet) {
    // Tablet scaling
    if (isLandscape) {
      // Tablet Landscape - wider screen, need larger scale
      return screenWidth < 1024 ? 1.15 : 1.3;
    } else {
      // Tablet Portrait
      return screenWidth < 768 ? 1.1 : 1.2;
    }
  } else {
    // Phone scaling
    if (isLandscape) {
      // Phone Landscape - more horizontal space
      return screenWidth < 600 ? 0.9 : 1.05;
    } else {
      // Phone Portrait
      return screenWidth < 360
          ? 0.85
          : screenWidth < 480
              ? 1.0
              : 1.05;
    }
  }
}

/// Get scale factor for specific use cases
class ScaleFactors {
  /// Scale for text/fonts
  static double get text {
    final mediaQuery = MediaQuery.of(Get.context!);
    final shortestSide = mediaQuery.size.shortestSide;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isTablet = shortestSide >= 600;

    if (isTablet) {
      return isLandscape ? 1.1 : 1.05;
    }
    return isLandscape ? 0.95 : 1.0;
  }

  /// Scale for icons
  static double get icon {
    final mediaQuery = MediaQuery.of(Get.context!);
    final shortestSide = mediaQuery.size.shortestSide;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isTablet = shortestSide >= 600;

    if (isTablet) {
      return isLandscape ? 1.3 : 1.2;
    }
    return isLandscape ? 1.1 : 1.0;
  }

  /// Scale for spacing/padding
  static double get spacing {
    final mediaQuery = MediaQuery.of(Get.context!);
    final shortestSide = mediaQuery.size.shortestSide;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isTablet = shortestSide >= 600;

    if (isTablet) {
      return isLandscape ? 1.5 : 1.3;
    }
    return isLandscape ? 1.2 : 1.0;
  }

  /// Scale for images/thumbnails
  static double get image {
    final mediaQuery = MediaQuery.of(Get.context!);
    final shortestSide = mediaQuery.size.shortestSide;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isTablet = shortestSide >= 600;

    if (isTablet) {
      return isLandscape ? 1.4 : 1.25;
    }
    return isLandscape ? 1.15 : 1.0;
  }
}

/// Breakpoints for responsive design
class Breakpoints {
  static const double mobileSmall = 320;
  static const double mobile = 360;
  static const double mobileLarge = 480;
  static const double tablet = 600;
  static const double tabletLarge = 900;
  static const double desktop = 1200;

  /// Check if current width matches breakpoint
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide < tablet;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= tablet &&
      MediaQuery.of(context).size.shortestSide < desktop;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= desktop;
}
