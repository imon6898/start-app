import 'package:flutter_test/flutter_test.dart';

import 'guardrail_utils.dart';

/// Fails when a feature controller is never registered — GetBuilder would throw
/// "XController not found" only once the screen is opened at runtime.
void main() {
  final bindingSource = libFile(
    'app/bindings/view_model_binding.dart',
  ).readAsStringSync();

  final controllers = <String, String>{};
  for (final file in libDartFiles()) {
    if (!rel(file).startsWith('lib/app/feature/')) continue;
    for (final m in RegExp(
      r'^class\s+(\w+Controller)\b',
      multiLine: true,
    ).allMatches(file.readAsStringSync())) {
      controllers[m.group(1)!] = rel(file);
    }
  }

  test('at least one feature controller was found', () {
    expect(controllers, isNotEmpty);
  });

  test('every feature controller is registered in ViewModelBinding', () {
    final missing = controllers.entries
        .where((e) => !RegExp('\\b${e.key}\\b').hasMatch(bindingSource))
        .map((e) => '${e.key} (${e.value})')
        .toList();

    expect(
      missing,
      isEmpty,
      reason: 'Not registered in ViewModelBinding:\n${missing.join('\n')}',
    );
  });

  test('ViewModelBinding references no controller that no longer exists', () {
    final registered = RegExp(
      r'_lazy<(\w+Controller)>',
    ).allMatches(bindingSource).map((m) => m.group(1)!).toSet();

    // ThemeController lives outside feature/, so only check the feature ones.
    final stale = registered
        .where((c) => c.endsWith('Controller') && c != 'ThemeController')
        .where((c) => !controllers.containsKey(c))
        .toList();

    expect(
      stale,
      isEmpty,
      reason: 'Registered but undefined: ${stale.join(', ')}',
    );
  });
}
