import 'package:flutter_test/flutter_test.dart';

import 'guardrail_utils.dart';

/// This template was fused from three donor apps. Any donor name left in lib/
/// means product copy, an endpoint or a flag was carried over instead of
/// genericised — exactly the leak that produced the fusion in the first place.
const List<String> donorTerms = [
  'Yaad',
  'YaadGlobal',
  'AdventCircle',
  'logistics',
  'calldone',
];

void main() {
  test('no donor branding anywhere under lib/', () {
    final hits = <String>[];

    for (final file in libDartFiles()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final lower = lines[i].toLowerCase();
        for (final term in donorTerms) {
          if (lower.contains(term.toLowerCase())) {
            hits.add('${rel(file)}:${i + 1}: $term -> ${lines[i].trim()}');
          }
        }
      }
    }

    expect(
      hits,
      isEmpty,
      reason:
          'Donor branding found in lib/ — rename it generically:\n'
          '${hits.join('\n')}',
    );
  });
}
