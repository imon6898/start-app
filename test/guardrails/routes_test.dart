import 'package:flutter_test/flutter_test.dart';

import 'guardrail_utils.dart';

/// Fails when AppRoutes and AppPages drift apart — an unrouted constant is a
/// dead link, an unlisted page is unreachable.
void main() {
  final routesSource = libFile('app/routes/app_routes.dart').readAsStringSync();
  final pagesSource = libFile('app/routes/app_pages.dart').readAsStringSync();

  final declared = <String, String>{
    for (final m in RegExp(
      r"static\s+const\s+String\s+(\w+)\s*=\s*'([^']*)'",
    ).allMatches(routesSource))
      m.group(1)!: m.group(2)!,
  };

  final referenced = RegExp(
    r'AppRoutes\.(\w+)',
  ).allMatches(pagesSource).map((m) => m.group(1)!).toSet();

  test('AppRoutes declares at least one route', () {
    expect(declared, isNotEmpty);
  });

  test('every AppRoutes constant has a GetPage in AppPages', () {
    final unrouted = declared.keys
        .where((k) => !referenced.contains(k))
        .toList();
    expect(
      unrouted,
      isEmpty,
      reason: 'Declared in AppRoutes but never routed: ${unrouted.join(', ')}',
    );
  });

  test('every AppRoutes reference in AppPages is a declared constant', () {
    final unknown = referenced.where((k) => !declared.containsKey(k)).toList();
    expect(
      unknown,
      isEmpty,
      reason:
          'Used in AppPages but not declared in AppRoutes: ${unknown.join(', ')}',
    );
  });

  test('route paths are unique', () {
    final byPath = <String, List<String>>{};
    declared.forEach(
      (name, path) => byPath.putIfAbsent(path, () => []).add(name),
    );

    final clashes = byPath.entries.where((e) => e.value.length > 1).toList();
    expect(
      clashes,
      isEmpty,
      reason:
          'Duplicate route paths: '
          '${clashes.map((e) => '${e.key} <- ${e.value.join(', ')}').join(' | ')}',
    );
  });
}
