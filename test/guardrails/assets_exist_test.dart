import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'guardrail_utils.dart';

/// Fails when ImageUtils names an asset that is not on disk or not bundled.
void main() {
  final source = libFile(
    'app/utils/constants/app_assets.dart',
  ).readAsStringSync();

  // static const String name = 'assets/...';
  final declarations = RegExp(
    r"static\s+const\s+String\s+(\w+)\s*=\s*'([^']*)'",
  ).allMatches(source);

  final assetPaths = <String, String>{
    for (final m in declarations)
      if (m.group(2)!.startsWith('assets/')) m.group(1)!: m.group(2)!,
  };

  test('ImageUtils declares at least one asset', () {
    // Guards the regex above: a silent zero-match would make every test below pass.
    expect(assetPaths, isNotEmpty);
  });

  test('every ImageUtils path exists on disk', () {
    final missing = assetPaths.entries
        .where((e) => !File(e.value).existsSync())
        .map((e) => 'ImageUtils.${e.key} -> ${e.value}')
        .toList();

    expect(
      missing,
      isEmpty,
      reason: 'Asset files missing:\n${missing.join('\n')}',
    );
  });

  test('every ImageUtils path is bundled in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final bundled = RegExp(
      r'^\s*-\s*(assets/\S*)\s*$',
      multiLine: true,
    ).allMatches(pubspec).map((m) => m.group(1)!).toList();

    // A pubspec entry is either the exact file or the directory holding it.
    bool covered(String path) => bundled.any(
      (b) => b == path || (b.endsWith('/') && path.startsWith(b)),
    );

    final unbundled = assetPaths.entries
        .where((e) => !covered(e.value))
        .map((e) => 'ImageUtils.${e.key} -> ${e.value}')
        .toList();

    expect(
      unbundled,
      isEmpty,
      reason:
          'Not listed under `assets:` in pubspec.yaml:\n${unbundled.join('\n')}',
    );
  });
}
