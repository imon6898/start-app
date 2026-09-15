import 'package:flutter_starter/app/localization/app_translations.dart';
import 'package:flutter_starter/app/localization/locales/en_us.dart';
import 'package:flutter_test/flutter_test.dart';

import 'guardrail_utils.dart';

/// Keys are English source strings, so the map and the code have to agree
/// exactly — a typo in either one silently ships the raw key to the user.
void main() {
  const source = 'en_US';

  /// Every `'...'.tr` / `.trParams` literal in lib/, excluding the maps.
  final literals = RegExp(
    '''(?:'((?:[^'\\\\\\n]|\\\\.)*)'|"((?:[^"\\\\\\n]|\\\\.)*)")\\s*\\.tr(?:Params|Args)?\\b''',
  );

  final Set<String> used = libDartFiles()
      .where((f) => !rel(f).contains('/localization/'))
      .expand(
        (f) => literals
            .allMatches(f.readAsStringSync())
            .map((m) => m.group(1) ?? m.group(2)!),
      )
      .toSet();

  test('$source values equal their keys', () {
    final bad = enUs.entries
        .where((e) => e.key != e.value)
        .map((e) => '${e.key} -> ${e.value}')
        .toList();

    expect(
      bad,
      isEmpty,
      reason:
          'The fallback renders the key itself, so $source must be a mirror. '
          'Change the copy in code, not the value:\n${bad.join('\n')}',
    );
  });

  test('no key has leading or trailing whitespace', () {
    final bad = enUs.keys.where((k) => k.trim() != k).toList();

    expect(
      bad,
      isEmpty,
      reason:
          'Pad in the widget, not the key — trailing spaces do not survive '
          'translation:\n${bad.map((k) => '"$k"').join('\n')}',
    );
  });

  test('every locale carries exactly the $source keys', () {
    final expected = enUs.keys.toSet();

    for (final entry in AppTranslations().keys.entries) {
      if (entry.key == source) continue;
      final keys = entry.value.keys.toSet();

      expect(
        expected.difference(keys),
        isEmpty,
        reason: '${entry.key} is missing keys',
      );
      expect(
        keys.difference(expected),
        isEmpty,
        reason: '${entry.key} has keys $source does not',
      );
    }
  });

  test('every translated string in lib/ has a $source entry', () {
    final missing = used.difference(enUs.keys.toSet()).toList()..sort();

    expect(
      missing,
      isEmpty,
      reason:
          'Add these to lib/app/localization/locales/:\n${missing.join('\n')}',
    );
  });

  test('no $source key is unused', () {
    final orphans = enUs.keys.toSet().difference(used).toList()..sort();

    expect(
      orphans,
      isEmpty,
      reason:
          'Nothing calls `.tr` on these — drop them from every locale:\n'
          '${orphans.join('\n')}',
    );
  });
}
