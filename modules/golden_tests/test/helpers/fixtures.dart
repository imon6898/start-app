// Loads canned API payloads from test/fixtures/. `flutter test` runs with the
// package root as its cwd, so these paths need no resolution.

import 'dart:convert';
import 'dart:io';

String fixtureString(String name) {
  final file = File('test/fixtures/$name');
  if (!file.existsSync()) {
    throw StateError('Missing fixture test/fixtures/$name');
  }
  return file.readAsStringSync();
}

Map<String, dynamic> fixtureJson(String name) =>
    jsonDecode(fixtureString(name)) as Map<String, dynamic>;

List<dynamic> fixtureJsonList(String name) =>
    jsonDecode(fixtureString(name)) as List<dynamic>;
