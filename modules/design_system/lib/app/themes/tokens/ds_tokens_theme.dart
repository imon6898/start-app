import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// The token set reachable through `Theme.of(context)` / `context.ds`.
///
/// Values are resolved for one [brightness] at build time; the static classes
/// (DsSpace, DsPalette, …) remain the source of truth.
@immutable
class DsTokens extends ThemeExtension<DsTokens> {
  final Brightness brightness;
  final Map<String, double> spacing;
  final Map<String, double> radius;
  final Map<String, Color> colors;
  final Map<String, Duration> durations;

  const DsTokens({
    required this.brightness,
    required this.spacing,
    required this.radius,
    required this.colors,
    required this.durations,
  });

  /// Snapshot of every token for one theme.
  factory DsTokens.of(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return DsTokens(
      brightness: brightness,
      spacing: DsSpace.all,
      radius: DsRadius.all,
      colors: {
        for (final e in DsPalette.all.entries) e.key: e.value.resolve(isDark),
      },
      durations: DsDuration.all,
    );
  }

  /// Raw Figma px — still needs R.h()/R.w().
  double space(String name) => spacing[name] ?? DsSpace.md;

  double corner(String name) => radius[name] ?? DsRadius.md;

  Color color(String name) => colors[name] ?? const Color(0x00000000);

  Duration duration(String name) => durations[name] ?? DsDuration.normal;

  @override
  DsTokens copyWith({
    Brightness? brightness,
    Map<String, double>? spacing,
    Map<String, double>? radius,
    Map<String, Color>? colors,
    Map<String, Duration>? durations,
  }) => DsTokens(
    brightness: brightness ?? this.brightness,
    spacing: spacing ?? this.spacing,
    radius: radius ?? this.radius,
    colors: colors ?? this.colors,
    durations: durations ?? this.durations,
  );

  @override
  DsTokens lerp(DsTokens? other, double t) {
    if (other == null) return this;
    // Colours interpolate; scales and durations are discrete, so they snap.
    return DsTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      spacing: t < 0.5 ? spacing : other.spacing,
      radius: t < 0.5 ? radius : other.radius,
      colors: {
        for (final e in colors.entries)
          e.key: Color.lerp(e.value, other.colors[e.key], t) ?? e.value,
      },
      durations: t < 0.5 ? durations : other.durations,
    );
  }
}

extension DsTokensContext on BuildContext {
  /// Tokens for this subtree; falls back to the static set when the
  /// ThemeExtension was never installed, so a missed wiring step is not a crash.
  DsTokens get ds =>
      Theme.of(this).extension<DsTokens>() ??
      DsTokens.of(Theme.of(this).brightness);
}
