import 'package:flutter_test/flutter_test.dart';

import 'guardrail_utils.dart';

/// Mixed-case file names break on case-sensitive CI after working locally on
/// macOS. The `file_names` lint covers new code; this covers the whole tree.
void main() {
  test('every .dart file under lib/ is lower_snake_case', () {
    final bad = libDartFiles()
        .map(rel)
        .where((p) => p.split('/').last.contains(RegExp('[A-Z]')))
        .toList();

    expect(bad, isEmpty, reason: 'Uppercase in file name:\n${bad.join('\n')}');
  });

  test('no directory under lib/ has an uppercase letter', () {
    final bad = libDartFiles()
        .map(rel)
        .where(
          (p) => p
              .split('/')
              .sublist(0, p.split('/').length - 1)
              .any((seg) => seg.contains(RegExp('[A-Z]'))),
        )
        .toSet()
        .toList();

    expect(
      bad,
      isEmpty,
      reason: 'Uppercase in folder name:\n${bad.join('\n')}',
    );
  });
}
