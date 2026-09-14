import "package:flutter/material.dart";
import "package:get/get.dart";

import "../services/domain/dev_tools.dart";


/// 🚀 Universal Responsive Helper Class
/// Works on ALL devices: Smart Watch, Phone, Tablet, Laptop, TV
/// Usage: R.h(10), R.w(100), R.sp(16), R.r(8)
///
/// Self-contained: scale is derived from the live MediaQuery, so there is no
/// `ScreenUtilInit` to install and no initialisation order to get wrong. Before
/// the first frame (no `Get.context` yet) it falls back to the Figma size, so a
/// call from a controller or a test never throws.
class R {
  // ==================== FIGMA DESIGN CONFIG ====================
  /// Your Figma design dimensions (Mobile-first design)
  static const double _figmaWidth = 375.0;
  static const double _figmaHeight = 812.0;

  // ==================== SCREEN UTILITIES ====================

  /// Get current screen size
  static Size get size {
    final context = Get.context;
    if (context == null) {
      return const Size(_figmaWidth, _figmaHeight);
    }
    return MediaQuery.of(context).size;
  }

  /// Get screen width
  static double get width => size.width;

  /// Get screen height
  static double get height => size.height;

  /// Check if device is in landscape mode
  static bool get isLandscape => width > height;

  /// Get device pixel ratio
  static double get pixelRatio {
    final context = Get.context;
    return context != null ? MediaQuery.of(context).devicePixelRatio : 1.0;
  }

  // ==================== DEVICE DETECTION ====================

  /// Check if device is a smart watch
  static bool get isWatch => width <= 450 && height <= 450;

  /// Check if device is a phone
  static bool get isPhone => !isWatch && width < 600;

  /// Check if device is a small phone
  static bool get isSmallPhone => isPhone && width <= 400;

  /// Check if device is a large phone
  static bool get isLargePhone => isPhone && width > 400;

  /// Check if device is a tablet
  static bool get isTablet => !isWatch && width >= 600 && width < 1024;

  /// Check if device is a desktop/laptop
  static bool get isDesktop => !isWatch && width >= 1024 && width < 1920;

  /// Check if device is a TV or very large screen
  static bool get isTV => !isWatch && width >= 1920;

  /// Check if device is foldable (approximate detection)
  static bool get isFoldable =>
      (width >= 700 && height >= 700) || (isLandscape && width > height * 1.5);

  // ==================== SMART SCALING SYSTEM ====================

  /// Get smart scale factor based on device type
  static double _getScale() {
    final double rawScale = width / _figmaWidth;

    // Apply device-specific scaling limits
    if (isWatch) {
      return rawScale.clamp(0.7, 1.3);
    } else if (isPhone) {
      return rawScale.clamp(0.8, 1.4);
    } else if (isTablet) {
      if (isFoldable) {
        return rawScale.clamp(0.9, 1.5);
      }
      return rawScale.clamp(0.9, 1.6);
    } else if (isDesktop) {
      return rawScale.clamp(1.0, 1.8);
    } else {
      // TV
      return rawScale.clamp(1.2, 2.0);
    }
  }

  // ==================== PUBLIC RESPONSIVE API ====================

  /// Convert Figma pixels to responsive height units
  /// ✅ Works on ALL devices: Smart Watch, Phone, Tablet, Desktop, TV
  static double h(double figmaPixels) {
    double scale = _getScale();

    // Adjust for very small values (icons, small spacing)
    if (figmaPixels < 20) {
      if (isWatch) scale *= 0.9;
      if (isTV) scale *= 1.1;
    }

    // Adjust for large values
    if (figmaPixels > 100) {
      if (isWatch) scale *= 1.1;
      if (isTV) scale *= 0.95;
    }

    return (figmaPixels * scale).roundToDouble();
  }

  /// Convert Figma pixels to responsive width units
  static double w(double figmaPixels) {
    // For width, we can be slightly more aggressive
    double scale = _getScale();

    if (isWatch) {
      scale = scale.clamp(0.8, 1.4);
    }

    return (figmaPixels * scale).roundToDouble();
  }

  /// Convert Figma pixels to responsive font size
  static double sp(double figmaPixels) {
    double size = h(figmaPixels);

    // Ensure readable font sizes per device type
    if (isWatch) {
      return size.clamp(10.0, 26.0);
    } else if (isPhone) {
      return size.clamp(12.0, 36.0);
    } else if (isTablet) {
      return size.clamp(14.0, 42.0);
    } else if (isDesktop) {
      return size.clamp(16.0, 48.0);
    } else {
      // TV
      return size.clamp(20.0, 56.0);
    }
  }

  /// Convert Figma pixels to responsive border radius
  static double r(double figmaPixels) {
    return h(figmaPixels);
  }

  // ==================== LAYOUT HELPERS ====================

  /// Get responsive padding
  static EdgeInsets pad({
    double all = 0,
    double horizontal = 0,
    double vertical = 0,
    double left = 0,
    double right = 0,
    double top = 0,
    double bottom = 0,
  }) {
    if (all != 0) {
      return EdgeInsets.all(h(all));
    }

    return EdgeInsets.only(
      left: left != 0 ? w(left) : (horizontal != 0 ? w(horizontal) : 0),
      right: right != 0 ? w(right) : (horizontal != 0 ? w(horizontal) : 0),
      top: top != 0 ? h(top) : (vertical != 0 ? h(vertical) : 0),
      bottom: bottom != 0 ? h(bottom) : (vertical != 0 ? h(vertical) : 0),
    );
  }

  /// Get responsive margin
  static EdgeInsets margin({
    double all = 0,
    double horizontal = 0,
    double vertical = 0,
    double left = 0,
    double right = 0,
    double top = 0,
    double bottom = 0,
  }) {
    return pad(
      all: all,
      horizontal: horizontal,
      vertical: vertical,
      left: left,
      right: right,
      top: top,
      bottom: bottom,
    );
  }

  /// Get responsive spacing (for SizedBox)
  static SizedBox space({double? width, double? height}) {
    return SizedBox(
      width: width != null ? w(width) : null,
      height: height != null ? h(height) : null,
    );
  }

  /// Get responsive sized box with constraints
  static SizedBox box({required double width, required double height}) {
    return SizedBox(width: w(width), height: h(height));
  }

  // ==================== DEVICE-SPECIFIC HELPERS ====================

  /// Get minimum touch target size for current device
  static double get minTouchSize {
    if (isWatch) return h(44);
    if (isPhone) return h(48);
    return h(44);
  }

  /// Get safe area padding for current device
  static EdgeInsets get safeArea {
    final context = Get.context;
    if (context == null) return EdgeInsets.zero;

    final padding = MediaQuery.of(context).padding;
    return EdgeInsets.only(
      top: padding.top,
      bottom: padding.bottom,
      left: padding.left,
      right: padding.right,
    );
  }

  /// Check if element size is touch-friendly
  static bool isTouchFriendly(double size) {
    return size >= minTouchSize;
  }

  // ==================== DEBUG & TEST UTILITIES ====================

  /// Print current device information
  static void printDeviceInfo() {
    final deviceType = isWatch
        ? "Watch"
        : isPhone
            ? "Phone"
            : isTablet
                ? "Tablet"
                : isDesktop
                    ? "Desktop"
                    : "TV";

    devPrint('''
    📱 DEVICE INFORMATION:
    ├─ Type: $deviceType ${isFoldable ? '(Foldable)' : ''}
    ├─ Size: ${width.toInt()} × ${height.toInt()}
    ├─ Orientation: ${isLandscape ? 'Landscape' : 'Portrait'}
    ├─ Pixel Ratio: ${pixelRatio.toStringAsFixed(2)}x
    ├─ Scale Factor: ${_getScale().toStringAsFixed(2)}x
    └─ R.h(10) = ${h(10)}px
    ''');
  }

  /// Test responsive values
  static void testResponsiveValues() {
    devPrint('''
    🧪 RESPONSIVE TEST:
    ├─ R.h(10)  = ${h(10)}px
    ├─ R.h(20)  = ${h(20)}px
    ├─ R.h(50)  = ${h(50)}px
    ├─ R.sp(16) = ${sp(16)}px
    ├─ R.r(8)   = ${r(8)}px
    └─ Touch Friendly: ${isTouchFriendly(h(44)) ? '✅' : '❌'}
    ''');
  }
}

// ==================== EXTENSION FOR EASIER USAGE ====================

/// Extension methods for easier responsive usage
extension ResponsiveExtension on num {
  /// Convert number to responsive height
  double get h => R.h(toDouble());

  /// Convert number to responsive width
  double get w => R.w(toDouble());

  /// Convert number to responsive font size
  double get sp => R.sp(toDouble());

  /// Convert number to responsive border radius
  double get r => R.r(toDouble());
}

// Extension for SizedBox spacing
extension SpaceExtension on double {
  SizedBox get spaceHeight => SizedBox(height: this);
  SizedBox get spaceWidth => SizedBox(width: this);
}
