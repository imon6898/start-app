import 'package:flutter/material.dart';
import 'package:flutter_starter/app/themes/theme_controller.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:get/get.dart';

import 'token_types.dart';

/// Resolves theme-dependent tokens through the same probe CustomColors uses, so
/// a token and a CustomColors call can never disagree about the active theme.
class DsBrightness {
  const DsBrightness._();

  static bool get isDark {
    try {
      return Get.find<ThemeController>().isDarkMode;
    } catch (_) {
      // Before the first frame there is no context either — assume light.
      final context = Get.context;
      return context != null && Theme.of(context).brightness == Brightness.dark;
    }
  }

  static Brightness get value => isDark ? Brightness.dark : Brightness.light;
}

extension DsColorTokenResolve on DsColorToken {
  /// Value for the active theme.
  Color get value => resolve(DsBrightness.isDark);
}

extension DsShadowTokenResolve on DsShadowToken {
  /// Scaled BoxShadow list. The colour is always pure black — CustomColors
  /// .black() inverts in dark mode, which would paint a white shadow.
  List<BoxShadow> get value {
    if (isNone) return const <BoxShadow>[];
    return [
      BoxShadow(
        color: const Color(
          0xFF000000,
        ).withValues(alpha: alpha(DsBrightness.isDark)),
        offset: Offset(0, R.h(y)),
        blurRadius: R.r(blur),
        spreadRadius: R.r(spread),
      ),
    ];
  }
}
