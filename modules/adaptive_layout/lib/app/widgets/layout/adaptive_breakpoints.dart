/// Material window size classes, read from the live MediaQuery.
///
/// `R` answers "how big should this box be"; this answers "which layout".
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';

/// Material's three layout buckets. Compare against raw logical pixels.
enum WindowSizeClass {
  compact,
  medium,
  expanded;

  bool get isCompact => this == WindowSizeClass.compact;
  bool get isMedium => this == WindowSizeClass.medium;
  bool get isExpanded => this == WindowSizeClass.expanded;

  /// True for this class and every wider one.
  bool atLeast(WindowSizeClass other) => index >= other.index;

  /// Picks a value per class; medium falls back to compact, expanded to medium.
  T pick<T>({required T compact, T? medium, T? expanded}) => switch (this) {
    WindowSizeClass.compact => compact,
    WindowSizeClass.medium => medium ?? compact,
    WindowSizeClass.expanded => expanded ?? medium ?? compact,
  };
}

/// The breakpoint table. Deliberately NOT run through `R` — a breakpoint has to
/// compare against the real window, not against design units.
class AdaptiveBreakpoints {
  const AdaptiveBreakpoints._();

  /// Width at which compact becomes medium (phone -> small tablet / split view).
  static const double mediumWidth = 600;

  /// Width at which medium becomes expanded (tablet / desktop / unfolded).
  static const double expandedWidth = 840;

  /// Informational only: Material calls >= this "large". Not its own class here.
  static const double largeWidth = 1200;

  /// Height at which compact becomes medium (landscape phone -> everything else).
  static const double mediumHeight = 480;

  /// Height at which medium becomes expanded.
  static const double expandedHeight = 900;

  static WindowSizeClass widthClass(double width) => width >= expandedWidth
      ? WindowSizeClass.expanded
      : width >= mediumWidth
      ? WindowSizeClass.medium
      : WindowSizeClass.compact;

  static WindowSizeClass heightClass(double height) => height >= expandedHeight
      ? WindowSizeClass.expanded
      : height >= mediumHeight
      ? WindowSizeClass.medium
      : WindowSizeClass.compact;

  /// Width class without a BuildContext, for controllers. Falls back to the
  /// Figma width before the first frame, exactly like the rest of `R`.
  static WindowSizeClass get current => widthClass(R.width);
}

/// One snapshot of everything a layout decision needs.
@immutable
class WindowInfo {
  const WindowInfo({
    required this.size,
    required this.widthClass,
    required this.heightClass,
    required this.orientation,
    required this.textScaler,
    required this.displayFeatures,
  });

  /// Subscribes to size, orientation, text scale and display features only, so
  /// a keyboard opening (viewInsets) does not rebuild the whole layout.
  factory WindowInfo.of(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    return WindowInfo(
      size: size,
      widthClass: AdaptiveBreakpoints.widthClass(size.width),
      heightClass: AdaptiveBreakpoints.heightClass(size.height),
      orientation: MediaQuery.orientationOf(context),
      textScaler: MediaQuery.textScalerOf(context),
      displayFeatures: MediaQuery.displayFeaturesOf(context),
    );
  }

  final Size size;
  final WindowSizeClass widthClass;
  final WindowSizeClass heightClass;
  final Orientation orientation;
  final TextScaler textScaler;
  final List<ui.DisplayFeature> displayFeatures;

  bool get isCompact => widthClass.isCompact;
  bool get isExpanded => widthClass.isExpanded;
  bool get isLandscape => orientation == Orientation.landscape;

  /// Material's "large" bucket, folded into [WindowSizeClass.expanded] here.
  bool get isLargeScreen => size.width >= AdaptiveBreakpoints.largeWidth;

  /// How much a 16px label actually grows. 2.0 is the platform 200% setting.
  double get textScale => textScaler.scale(16) / 16;

  /// Past this, labels stop fitting next to icons and layouts must give ground.
  bool get isLargeText => textScale >= 1.3;
}

extension AdaptiveContext on BuildContext {
  WindowInfo get windowInfo => WindowInfo.of(this);
  WindowSizeClass get widthClass =>
      AdaptiveBreakpoints.widthClass(MediaQuery.sizeOf(this).width);
}
