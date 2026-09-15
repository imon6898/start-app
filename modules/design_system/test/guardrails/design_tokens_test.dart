import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The generator is the spec: the test regenerates and compares, so a
// hand-edited design_tokens.dart fails here instead of drifting silently.
import '../../tool/gen_tokens.dart';

void main() {
  final jsonFile = File(kDefaultInput);
  final dartFile = File(kDefaultOutput);
  final colorsFile = File(kDefaultColors);

  final Map<String, dynamic> tokens =
      jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;

  Map<String, dynamic> group(String key) =>
      (tokens[key] as Map<String, dynamic>?) ?? const {};

  test('tokens.json and design_tokens.dart both exist', () {
    expect(jsonFile.existsSync(), isTrue, reason: kDefaultInput);
    expect(dartFile.existsSync(), isTrue, reason: kDefaultOutput);
  });

  test('design_tokens.dart is in sync with tokens.json', () {
    final expected = generateTokens(
      tokens,
      source: kDefaultInput,
      customColors: customColorMethods(colorsFile),
    );

    expect(
      dartFile.readAsStringSync(),
      expected,
      reason: 'Stale or hand-edited. Run: dart run tool/gen_tokens.dart',
    );
  });

  test('every colorAlias target is a real CustomColors method', () {
    final methods = customColorMethods(colorsFile);
    expect(methods, isNotEmpty, reason: 'Guards the regex above.');

    final missing = group('colorAlias').entries
        .where((e) => !methods.contains(e.value.toString()))
        .map((e) => '${e.key} -> CustomColors.${e.value}()')
        .toList();

    expect(
      missing,
      isEmpty,
      reason:
          'No such method in ${colorsFile.path}:\n${missing.join('\n')}\n'
          'Add it there, or move the role to "colorRole" as a light/dark pair.',
    );
  });

  test('every curve name resolves to a const Curves entry', () {
    final bad = group('curve').entries
        .where((e) => !kCurves.containsKey(e.value.toString()))
        .map((e) => '${e.key} -> ${e.value}')
        .toList();

    expect(
      bad,
      isEmpty,
      reason: 'Allowed: ${kCurves.keys.join(', ')}\n${bad.join('\n')}',
    );
  });

  test('every motion token points at a declared duration and curve', () {
    final durations = group('duration').keys.toSet();
    final curves = group('curve').keys.toSet();
    final bad = <String>[];

    group('motion').forEach((name, raw) {
      final m = raw as Map<String, dynamic>;
      if (!durations.contains(m['duration'])) {
        bad.add('motion.$name duration "${m['duration']}"');
      }
      if (!curves.contains(m['curve'])) {
        bad.add('motion.$name curve "${m['curve']}"');
      }
    });

    expect(bad, isEmpty, reason: 'Dangling reference:\n${bad.join('\n')}');
  });

  test('every token name is a Dart lowerCamelCase identifier', () {
    final id = RegExp(r'^[a-z][A-Za-z0-9]*$');
    final bad = <String>[];

    for (final entry in tokens.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      for (final name in value.keys) {
        if (!id.hasMatch(name.toString())) bad.add('${entry.key}.$name');
      }
    }

    expect(
      bad,
      isEmpty,
      reason:
          'A Figma export can emit "space/2x" or "Space MD" — rename in '
          'tokens.json:\n${bad.join('\n')}',
    );
  });

  test('spacing and radius scales ascend in declaration order', () {
    for (final key in ['spacing', 'radius']) {
      final values = group(key).values.map((v) => (v as num).toDouble()).toList();
      final sorted = [...values]..sort();
      expect(
        values,
        sorted,
        reason: '$key is out of order — a reader trusts sm < md < lg.',
      );
    }
  });

  test('colorRole pairs are full 6- or 8-digit hex', () {
    final hex = RegExp(r'^#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$');
    final bad = <String>[];

    group('colorRole').forEach((name, raw) {
      final m = raw as Map<String, dynamic>;
      for (final tone in ['light', 'dark']) {
        final value = m[tone]?.toString() ?? '';
        if (!hex.hasMatch(value)) bad.add('colorRole.$name.$tone = "$value"');
      }
    });

    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
