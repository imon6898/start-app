import 'package:flutter/material.dart';
import 'package:flutter_starter/app/themes/app_theme.dart';

import 'tokens/tokens.dart';

/// AppTheme plus the token ThemeExtension. Additive on purpose: it does not
/// rewrite colorScheme or textTheme, because CustomColors and CustomTextStyles
/// stay the source of truth for every widget in the kit.
class DsTheme {
  const DsTheme._();

  static ThemeData get light => withTokens(AppTheme.lightTheme);

  static ThemeData get dark => withTokens(AppTheme.darkTheme);

  /// Attaches DsTokens for the theme's own brightness, keeping other extensions.
  static ThemeData withTokens(ThemeData base) {
    // Type argument omitted deliberately: `ThemeExtension<dynamic>` is
    // F-bounded and the CFE rejects it as a literal element type.
    final kept = base.extensions.values.where((e) => e is! DsTokens);
    return base.copyWith(
      extensions: [...kept, DsTokens.of(base.brightness)],
    );
  }
}
