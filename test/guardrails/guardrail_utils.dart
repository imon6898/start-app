import 'dart:io';

/// Shared source-tree readers for the convention tests. These run off disk, so
/// no test in guardrails/ needs the app to boot.

final Directory libDir = Directory('lib');

/// Every .dart file under lib/, sorted so failures are reproducible.
List<File> libDartFiles() =>
    libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// Path relative to the package root, with forward slashes.
String rel(File f) => f.path.replaceAll(r'\', '/');

File libFile(String relativePath) {
  final f = File('lib/$relativePath');
  if (!f.existsSync()) {
    throw StateError(
      'Expected $relativePath to exist — it is a pinned house-convention file. '
      'If it moved, update the guardrail test too.',
    );
  }
  return f;
}
