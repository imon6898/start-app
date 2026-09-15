import 'package:flutter/material.dart';
import 'package:flutter_starter/app/themes/ds_theme.dart';
import 'package:flutter_starter/app/themes/tokens/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the ThemeExtension path only. DsRole delegates to CustomColors, which
/// needs a registered ThemeController, so it is exercised by the catalog, not here.
void main() {
  // A bare Theme, not MaterialApp: MaterialApp wraps an AnimatedTheme, and a
  // read taken mid-transition returns the lerped (still-old) token set.
  Future<DsTokens> read(WidgetTester tester, ThemeData theme) async {
    late DsTokens tokens;
    await tester.pumpWidget(
      Theme(
        data: theme,
        child: Builder(
          builder: (context) {
            tokens = context.ds;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return tokens;
  }

  testWidgets('DsTheme installs DsTokens for the theme brightness', (
    tester,
  ) async {
    final light = await read(tester, DsTheme.light);
    expect(light.brightness, Brightness.light);
    expect(light.color('focusRing'), DsPalette.focusRing.light);

    final dark = await read(tester, DsTheme.dark);
    expect(dark.brightness, Brightness.dark);
    expect(dark.color('focusRing'), DsPalette.focusRing.dark);
  });

  testWidgets('context.ds falls back when the wiring step was skipped', (
    tester,
  ) async {
    final tokens = await read(tester, ThemeData(brightness: Brightness.dark));
    expect(tokens.brightness, Brightness.dark);
    expect(tokens.color('surfaceSunken'), DsPalette.surfaceSunken.dark);
  });

  testWidgets('scales come through unscaled, in raw Figma px', (tester) async {
    final tokens = await read(tester, DsTheme.light);
    expect(tokens.space('lg'), DsSpace.lg);
    expect(tokens.corner('pill'), DsRadius.pill);
    expect(tokens.duration('fast'), DsDuration.fast);
  });

  testWidgets('an unknown token name returns the documented default', (
    tester,
  ) async {
    final tokens = await read(tester, DsTheme.light);
    expect(tokens.space('nope'), DsSpace.md);
    expect(tokens.corner('nope'), DsRadius.md);
    expect(tokens.duration('nope'), DsDuration.normal);
    expect(tokens.color('nope').a, 0);
  });

  test('DsTheme keeps other ThemeExtensions and replaces only DsTokens', () {
    final base = ThemeData.light().copyWith(extensions: const [_Marker()]);

    final themed = DsTheme.withTokens(DsTheme.withTokens(base));

    expect(themed.extension<_Marker>(), isNotNull);
    expect(themed.extensions.values.whereType<DsTokens>().length, 1);
  });

  test('every generated token map is non-empty', () {
    expect(DsSpace.all, isNotEmpty);
    expect(DsRadius.all, isNotEmpty);
    expect(DsBorderWidth.all, isNotEmpty);
    expect(DsOpacity.all, isNotEmpty);
    expect(DsIconSize.all, isNotEmpty);
    expect(DsElevation.all, isNotEmpty);
    expect(DsDuration.all, isNotEmpty);
    expect(DsCurve.all, isNotEmpty);
    expect(DsMotion.all, isNotEmpty);
    expect(DsRole.all, isNotEmpty);
    expect(DsPalette.all, isNotEmpty);
  });

  test('the "none" elevation resolves to no shadow at all', () {
    expect(DsElevation.none.isNone, isTrue);
    expect(DsElevation.none.value, isEmpty);
    expect(DsElevation.low.value, hasLength(1));
  });
}

@immutable
class _Marker extends ThemeExtension<_Marker> {
  const _Marker();

  @override
  _Marker copyWith() => this;

  @override
  _Marker lerp(_Marker? other, double t) => this;
}
