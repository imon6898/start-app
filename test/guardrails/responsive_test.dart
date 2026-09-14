import 'package:flutter_test/flutter_test.dart';

import 'guardrail_utils.dart';

/// R.pad() and R.margin() take raw Figma pixels and scale internally, so
/// R.pad(horizontal: R.w(16)) scales twice and renders wide on every device
/// that is not the design width.
void main() {
  final call = RegExp(r'R\.(?:pad|margin)\([^)]*R\.[whr]\(');

  test('R.pad / R.margin arguments are never pre-scaled', () {
    final hits = <String>[];

    for (final file in libDartFiles()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (call.hasMatch(lines[i])) {
          hits.add('${rel(file)}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      hits,
      isEmpty,
      reason:
          'Double scaling — drop the inner R.w()/R.h():\n${hits.join('\n')}',
    );
  });
}
