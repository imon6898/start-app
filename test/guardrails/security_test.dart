import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Locks in the fixes from the security review so they cannot silently return.
void main() {
  final libFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('no credential is ever persisted to plaintext storage', () {
    // A storage write on the same line as "password" — not API calls like
    // resetPassword, which legitimately send one to the server.
    final write = RegExp(
      r'(_saveToCache|setString|CacheManager\s*\.\s*set)[^;]*[Pp]assword',
    );
    final offenders = <String>[];
    for (final file in libFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (write.hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    // The cache key itself must not exist either.
    final cacheKeys =
        File('lib/app/services/local_data/cache_manager.dart').readAsStringSync();
    if (RegExp(r'^\s*\w*[Pp]assword,', multiLine: true).hasMatch(cacheKeys)) {
      offenders.add('cache_manager.dart: CacheKeys declares a password key');
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A password must never be written to SharedPreferences: it is plaintext '
          'and a password cannot be revoked. Persist the email and rely on the '
          'refresh token.\n${offenders.join('\n')}',
    );
  });

  test('TLS validation is never bypassed', () {
    final offenders = <String>[];
    for (final file in libFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (line.contains('badCertificateCallback') ||
            line.contains('HttpOverrides')) {
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Accepting untrusted certificates — even under kDebugMode — invites a '
          'MITM and leaks into release when someone flips a flag. Add the proxy '
          'CA to the device trust store instead.\n${offenders.join('\n')}',
    );
  });

  test('no http:// endpoint in source', () {
    final offenders = <String>[];
    for (final file in libFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'''["']http://''').hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'Use https://.\n${offenders.join('\n')}');
  });

  test('android backup of app data is disabled', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      manifest,
      contains('android:allowBackup="false"'),
      reason:
          'With allowBackup=true, `adb backup` extracts SharedPreferences — '
          'including the session token — from an unrooted device.',
    );
  });

  test('no secret-shaped literal is committed in source', () {
    final patterns = <RegExp>[
      RegExp(r'AIza[0-9A-Za-z_\-]{30,}'),
      RegExp(r'sk_(live|test)_[0-9A-Za-z]{10,}'),
      RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'),
    ];
    final offenders = <String>[];
    for (final file in libFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (patterns.any((p) => p.hasMatch(lines[i]))) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Secrets belong in .env, read through Env.\n${offenders.join('\n')}',
    );
  });
}
