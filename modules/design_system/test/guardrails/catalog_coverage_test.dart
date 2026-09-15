import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A storybook is only worth opening when it is complete, so an uncatalogued
/// widget fails the build. Add a CatalogEntry — or delete this test if you
/// deliberately want a partial catalog.
void main() {
  final registry = File(
    'lib/app/feature/catalog/catalog_presentation/catalog_registry.dart',
  );

  final widgetFiles = Directory('lib/app/widgets')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      // Barrels re-export; they declare nothing.
      .where((f) => !f.path.endsWith('widgets.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  // class Foo extends StatelessWidget / class Foo<T> extends StatefulWidget
  final widgetClass = RegExp(
    r'^class\s+([A-Z]\w*)(?:<[^>]*>)?\s+extends\s+State(?:less|ful)Widget',
    multiLine: true,
  );

  // void showX(...) / Future<T?> showX<T>(...)
  final showFunction = RegExp(
    r'^(?:void|Future<[^>]*>)\s+(show[A-Z]\w*)(?:<[^>]*>)?\s*\(',
    multiLine: true,
  );

  final public = <String, String>{};
  for (final file in widgetFiles) {
    final source = file.readAsStringSync();
    for (final m in widgetClass.allMatches(source)) {
      public[m.group(1)!] = file.path;
    }
    for (final m in showFunction.allMatches(source)) {
      public[m.group(1)!] = file.path;
    }
  }

  test('the widget kit was found', () {
    expect(registry.existsSync(), isTrue, reason: registry.path);
    expect(public.length, greaterThan(10), reason: 'Guards the regexes above.');
  });

  test('every public widget under lib/app/widgets/ is catalogued', () {
    final source = registry.readAsStringSync();
    final missing = public.entries
        .where((e) => !RegExp("name: '${e.key}'").hasMatch(source))
        .map((e) => '${e.key} (${e.value})')
        .toList();

    expect(
      missing,
      isEmpty,
      reason:
          'Add a CatalogEntry for each:\n${missing.join('\n')}\n'
          'See modules/design_system/README.md > Adding a component.',
    );
  });

  test('every catalogued source path exists on disk', () {
    final paths = RegExp(r"source: '([^']+)'")
        .allMatches(registry.readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();

    expect(paths, isNotEmpty);
    final dead = paths.where((p) => !File(p).existsSync()).toList();
    expect(dead, isEmpty, reason: 'Renamed or removed:\n${dead.join('\n')}');
  });
}
