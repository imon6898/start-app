import 'package:flutter/material.dart';

/// Value types the generated design_tokens.dart instantiates. Hand-written, so
/// the generator only has to emit const constructor calls.

/// A colour with one value per theme. Resolve it, never read the fields.
@immutable
class DsColorToken {
  final Color light;
  final Color dark;

  const DsColorToken({required this.light, required this.dark});

  Color resolve(bool isDark) => isDark ? dark : light;
}

/// Shadow geometry in raw Figma px plus a per-theme alpha.
@immutable
class DsShadowToken {
  final double y;
  final double blur;
  final double spread;
  final double alphaLight;
  final double alphaDark;

  const DsShadowToken({
    required this.y,
    required this.blur,
    required this.spread,
    required this.alphaLight,
    required this.alphaDark,
  });

  double alpha(bool isDark) => isDark ? alphaDark : alphaLight;

  bool get isNone => blur == 0 && y == 0 && spread == 0;
}

/// One animation: how long and in what shape.
@immutable
class DsMotionToken {
  final Duration duration;
  final Curve curve;

  const DsMotionToken({required this.duration, required this.curve});
}
