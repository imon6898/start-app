// flutter_tools runs the nearest flutter_test_config.dart above each test file,
// so this applies to test/golden/ only and leaves the other suites untouched.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Fonts once per test file, before any pump — otherwise text is Ahem boxes.
  await loadAppFonts();

  final tolerance =
      double.tryParse(Platform.environment['GOLDEN_TOLERANCE'] ?? '') ?? 0;
  final current = goldenFileComparator;
  if (tolerance > 0 && current is LocalFileComparator) {
    goldenFileComparator =
        TolerantGoldenComparator(current.basedir, tolerance: tolerance);
  }

  await testMain();
}
