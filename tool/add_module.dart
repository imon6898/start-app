// ignore_for_file: avoid_print
// Installs a stripped feature module from modules/<name>/ back into lib/.
// Usage: dart run tool/add_module.dart [<module>] [--dry-run] [--force]
// Dependency-free: dart:io + a tiny YAML-subset parser.

import 'dart:io';

void main(List<String> args) {
  final flags = args.where((a) => a.startsWith('-')).toSet();
  final names = args.where((a) => !a.startsWith('-')).toList();

  if (flags.contains('-h') || flags.contains('--help')) {
    _printUsage();
    return;
  }

  final unknown = flags.difference(
      {'--dry-run', '--force', '--list', '-l', '-h', '--help'});
  if (unknown.isNotEmpty) {
    _fail('Unknown option(s): ${unknown.join(', ')}\nRun with --help.');
  }

  final root = _findProjectRoot();
  final modulesDir = Directory(_join(root, 'modules'));
  if (!modulesDir.existsSync()) _fail('No modules/ directory at $root');

  final modules = _loadModules(modulesDir);
  if (modules.isEmpty) _fail('No modules found in ${modulesDir.path}');

  if (names.isEmpty || flags.contains('--list') || flags.contains('-l')) {
    _list(modules);
    return;
  }
  if (names.length > 1) _fail('Install one module at a time. Got: ${names.join(', ')}');

  final mod = modules.firstWhere(
    (m) => m.name == names.first,
    orElse: () {
      // A file name was probably given instead of a module name.
      final owners = modules
          .where((m) => m.files.any((f) =>
              f.source.split('/').last.replaceAll('.dart', '') == names.first))
          .map((m) => m.name);
      _fail('Unknown module "${names.first}".'
          '${owners.isEmpty ? '' : '\nThat file ships inside: ${owners.join(', ')}'}'
          '\nAvailable: ${modules.map((m) => m.name).join(', ')}');
    },
  );

  _install(
    mod,
    root,
    dryRun: flags.contains('--dry-run'),
    force: flags.contains('--force'),
  );
}

void _printUsage() {
  print('''
add_module - re-add a stripped feature module to lib/

  dart run tool/add_module.dart                 list available modules
  dart run tool/add_module.dart <module>        install it
  dart run tool/add_module.dart <module> --dry-run   show the plan, write nothing
  dart run tool/add_module.dart <module> --force     overwrite existing files

Modules live in modules/<name>/ and are documented in modules/README.md.''');
}

// ---------- listing ----------

void _list(List<_Module> modules) {
  print('Available modules (${modules.length}) - modules/README.md has the details\n');
  final width = modules.map((m) => m.name.length).reduce((a, b) => a > b ? a : b);
  for (final m in modules) {
    final tag = m.isReference ? ' [reference]' : '';
    print('  ${m.name.padRight(width)}  ${_oneLine(m.description)}$tag');
    final deps = m.dependencies.keys.toList();
    print('  ${' '.padRight(width)}  deps: ${deps.isEmpty ? 'none' : deps.join(', ')}'
        '${m.hasPlatformConfig ? ' | platform setup required' : ''}');
    print('');
  }
  print('Install:  dart run tool/add_module.dart <name>');
  print('Preview:  dart run tool/add_module.dart <name> --dry-run');
}

String _oneLine(String s) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length <= 100 ? t : '${t.substring(0, 97)}...';
}

// ---------- install ----------

void _install(_Module m, String root, {bool dryRun = false, bool force = false}) {
  final tag = dryRun ? '[dry-run] ' : '';
  print('${tag}Installing module: ${m.name}');
  print(_indent(_wrap(m.description, 74), '  '));
  print('');

  if (m.isReference) {
    print('  NOTE: this is a REFERENCE module - it carries domain-specific business');
    print('        logic. Copy the structure, then replace the fields. See its README.');
    print('');
  }

  // Resolve source -> target for every file.
  final plan = <List<String>>[];
  final missing = <String>[];
  for (final f in m.files) {
    final src = _join(m.dir, f.source);
    if (!File(src).existsSync()) missing.add(f.source);
    plan.add([src, _join(root, f.target), f.target]);
  }
  if (missing.isNotEmpty) {
    _fail('Module "${m.name}" is missing source file(s):\n  ${missing.join('\n  ')}');
  }

  // Refuse to clobber unless --force.
  final clashes = plan.where((p) => File(p[1]).existsSync()).toList();
  if (clashes.isNotEmpty && !force) {
    stderr.writeln('These files already exist in the project:');
    for (final c in clashes) {
      stderr.writeln('  ${c[2]}');
    }
    stderr.writeln('\nRe-run with --force to overwrite them, or delete them first.');
    exit(1);
  }

  print('  Files:');
  for (final p in plan) {
    final exists = File(p[1]).existsSync();
    print('    ${exists ? 'overwrite' : 'create   '}  ${p[2]}');
    if (!dryRun) {
      Directory(_dirname(p[1])).createSync(recursive: true);
      File(p[0]).copySync(p[1]);
    }
  }
  print('');

  _applyDependencies(m, root, dryRun: dryRun);
  _printManualSteps(m);

  print(dryRun
      ? '[dry-run] Nothing was written. Drop --dry-run to install.'
      : 'Done. Now run:  flutter pub get');
}

void _applyDependencies(_Module m, String root, {required bool dryRun}) {
  if (m.dependencies.isEmpty) {
    print('  Dependencies: none - this module adds nothing to pubspec.yaml.');
    print('');
    _printOptionalDeps(m);
    return;
  }

  final pubspecFile = File(_join(root, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) _fail('pubspec.yaml not found at $root');
  final lines = pubspecFile.readAsLinesSync();

  final block = _dependencyBlock(lines);
  if (block == null) _fail('Could not find a top-level "dependencies:" block in pubspec.yaml');

  final existing = <String>{};
  for (var i = block[0]; i < block[1]; i++) {
    final match = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(lines[i]);
    if (match != null) existing.add(match.group(1)!);
  }

  final toAdd = <String, String>{};
  print('  Dependencies:');
  for (final entry in m.dependencies.entries) {
    if (existing.contains(entry.key)) {
      print('    already present  ${entry.key}');
    } else {
      print('    add              ${entry.key}: ${entry.value}');
      toAdd[entry.key] = entry.value;
    }
  }

  if (toAdd.isNotEmpty && !dryRun) {
    // Insert after the last entry of the dependencies block.
    var insertAt = block[1];
    while (insertAt > block[0] && lines[insertAt - 1].trim().isEmpty) {
      insertAt--;
    }
    final added = [
      '  # ${m.name} module',
      ...toAdd.entries.map((e) => '  ${e.key}: ${e.value}'),
    ];
    lines.insertAll(insertAt, added);
    pubspecFile.writeAsStringSync('${lines.join('\n')}\n');
    print('    -> pubspec.yaml updated (${toAdd.length} added)');
  } else if (toAdd.isEmpty) {
    print('    -> pubspec.yaml already has everything this module needs');
  }
  print('');
  _printOptionalDeps(m);
}

void _printOptionalDeps(_Module m) {
  if (m.optionalDependencies.isEmpty) return;
  print('  Optional dependencies (add only if you need the noted feature):');
  m.optionalDependencies
      .forEach((k, v) => print('    $k: $v'));
  print('');
}

// Returns [firstLineAfterHeader, endExclusive] of the top-level dependencies block.
List<int>? _dependencyBlock(List<String> lines) {
  var start = -1;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trimRight() == 'dependencies:') {
      start = i + 1;
      break;
    }
  }
  if (start == -1) return null;
  var end = lines.length;
  for (var i = start; i < lines.length; i++) {
    final l = lines[i];
    if (l.trim().isEmpty) continue;
    if (!l.startsWith(' ') && !l.startsWith('\t')) {
      end = i;
      break;
    }
  }
  return [start, end];
}

void _printManualSteps(_Module m) {
  void section(String title, dynamic value) {
    if (value == null) return;
    final body = _render(value).trimRight();
    if (body.isEmpty) return;
    print('  $title:');
    print(_indent(body, '    '));
    print('');
  }

  print('  MANUAL STEPS - do these by hand:');
  print('');
  section('Platform config', m.raw['platform_config'] ?? 'None required.');
  section('Environment (.env)', m.raw['env']);
  section('Setup / registration', m.raw['setup']);
  section('Routes to register (AppRoutes / AppPages)', m.raw['routes']);
  section('Bindings to register', m.raw['bindings']);
  section('Core files that must exist',
      m.raw['requires'] ?? m.raw['requires_core'] ?? m.raw['core_dependencies']);
  section('Other modules needed', m.raw['requires_modules']);
  section('Optional integration', m.raw['optional_integration']);
  section('Notes', m.raw['notes']);
  print('  Full docs: modules/${m.name}/README.md');
  print('');
}

// ---------- module loading ----------

class _ModuleFile {
  final String source;
  final String target;
  _ModuleFile(this.source, this.target);
}

class _Module {
  final String name;
  final String dir;
  final Map<String, dynamic> raw;
  _Module(this.name, this.dir, this.raw);

  String get description => _str(raw['description']) ?? '(no description)';
  bool get isReference => _str(raw['kind']) == 'reference';

  Map<String, String> get dependencies => _depMap(raw['dependencies']);
  Map<String, String> get optionalDependencies => _depMap(raw['optional_dependencies']);

  bool get hasPlatformConfig {
    final p = raw['platform_config'];
    if (p == null) return false;
    if (p is String) return !p.trim().toLowerCase().startsWith('none');
    return true;
  }

  // files: entries are either "path" (mirrors the project path) or {source, target}.
  List<_ModuleFile> get files {
    final raws = raw['files'];
    if (raws is! List) return const [];
    final installDir = _str(raw['install_dir']);
    final out = <_ModuleFile>[];
    for (final e in raws) {
      if (e is String) {
        final target = installDir == null
            ? e
            : '$installDir/${e.split('/').last}';
        out.add(_ModuleFile(e, target));
      } else if (e is Map) {
        final s = _str(e['source']);
        final t = _str(e['target']);
        if (s != null && t != null) out.add(_ModuleFile(s, t));
      }
    }
    return out;
  }
}

Map<String, String> _depMap(dynamic v) {
  if (v is! Map) return {};
  final out = <String, String>{};
  v.forEach((k, val) {
    final s = _str(val);
    if (s != null && s.isNotEmpty) out[k.toString()] = s;
  });
  return out;
}

List<_Module> _loadModules(Directory modulesDir) {
  final out = <_Module>[];
  final dirs = modulesDir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final d in dirs) {
    final yaml = File(_join(d.path, 'module.yaml'));
    if (!yaml.existsSync()) continue;
    try {
      final parsed = parseYaml(yaml.readAsStringSync());
      if (parsed is! Map<String, dynamic>) continue;
      final name = _str(parsed['name']) ?? d.path.split(Platform.pathSeparator).last;
      out.add(_Module(name, d.path, parsed));
    } catch (e) {
      stderr.writeln('Skipping ${yaml.path}: $e');
    }
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}

// ---------- tiny YAML subset parser ----------
// Handles nested maps, "- " lists, inline {}/[], and |/> block scalars. Enough
// for module.yaml; not a general YAML implementation.

dynamic parseYaml(String src) => _YamlParser(src).parse();

class _YamlParser {
  final List<String> lines;
  int i = 0;
  _YamlParser(String src) : lines = src.replaceAll('\r\n', '\n').split('\n');

  dynamic parse() => _node(0);

  bool get _atEnd => i >= lines.length;

  void _skipBlanks() {
    while (i < lines.length) {
      final t = lines[i].trim();
      if (t.isEmpty || t.startsWith('#') || t == '---') {
        i++;
      } else {
        break;
      }
    }
  }

  int _indentOf(String l) => l.length - l.trimLeft().length;

  dynamic _node(int minIndent) {
    _skipBlanks();
    if (_atEnd) return null;
    final ind = _indentOf(lines[i]);
    if (ind < minIndent) return null;
    final t = lines[i].trimLeft();
    return (t == '-' || t.startsWith('- ')) ? _list(ind) : _map(ind);
  }

  List<dynamic> _list(int indent) {
    final out = <dynamic>[];
    while (true) {
      _skipBlanks();
      if (_atEnd) break;
      if (_indentOf(lines[i]) != indent) break;
      final t = lines[i].trimLeft();
      if (t != '-' && !t.startsWith('- ')) break;
      final rest = t.length > 1 ? t.substring(2) : '';
      if (rest.trim().isEmpty) {
        i++;
        out.add(_node(indent + 1));
      } else if (rest.trim().startsWith('|') || rest.trim().startsWith('>')) {
        i++;
        out.add(_blockScalar(indent, fold: rest.trim().startsWith('>')));
      } else if (_keyIndex(rest.trim()) >= 0 && !rest.trim().startsWith('"')) {
        // Item is a map: blank out the dash so the keys align, then parse a map.
        lines[i] = '${' ' * (indent + 2)}${rest.trimLeft()}';
        out.add(_map(indent + 2));
      } else {
        i++;
        out.add(_scalar(_stripComment(rest.trim())));
      }
    }
    return out;
  }

  Map<String, dynamic> _map(int indent) {
    final out = <String, dynamic>{};
    while (true) {
      _skipBlanks();
      if (_atEnd) break;
      if (_indentOf(lines[i]) != indent) break;
      final t = lines[i].trimLeft();
      if (t.startsWith('- ')) break;
      final ci = _keyIndex(t);
      if (ci < 0) break;
      final key = t.substring(0, ci).trim();
      final rawVal = t.substring(ci + 1).trim();
      i++;
      if (rawVal.startsWith('|') || rawVal.startsWith('>')) {
        out[key] = _blockScalar(indent, fold: rawVal.startsWith('>'));
      } else if (rawVal.isEmpty) {
        out[key] = _node(indent + 1);
      } else {
        out[key] = _scalar(_stripComment(rawVal));
      }
    }
    return out;
  }

  // Collects the indented body after a "key: |" / "key: >" header.
  String _blockScalar(int parentIndent, {required bool fold}) {
    final body = <String>[];
    var bodyIndent = -1;
    while (i < lines.length) {
      final l = lines[i];
      if (l.trim().isEmpty) {
        body.add('');
        i++;
        continue;
      }
      final ind = _indentOf(l);
      if (ind <= parentIndent) break;
      if (bodyIndent == -1) bodyIndent = ind;
      body.add(l.length >= bodyIndent ? l.substring(bodyIndent) : l.trimLeft());
      i++;
    }
    while (body.isNotEmpty && body.last.trim().isEmpty) {
      body.removeLast();
    }
    if (!fold) return body.join('\n');
    // Folded: blank line = paragraph break, indented line keeps its own line.
    final buf = StringBuffer();
    for (final l in body) {
      if (l.trim().isEmpty) {
        buf.write('\n\n');
      } else if (l.startsWith(' ')) {
        buf.write('\n$l');
      } else {
        if (buf.isNotEmpty && !buf.toString().endsWith('\n')) buf.write(' ');
        buf.write(l.trim());
      }
    }
    return buf.toString().trim();
  }

  // Index of the ":" that separates key from value, ignoring quoted keys.
  int _keyIndex(String t) {
    if (t.endsWith(':')) return t.length - 1;
    final idx = t.indexOf(': ');
    if (idx <= 0) return -1;
    if (t.substring(0, idx).contains(' ') && !t.startsWith('"')) {
      // Key with spaces is unusual but legal in these files (plist keys).
      return idx;
    }
    return idx;
  }

  String _stripComment(String v) {
    if (v.startsWith('"') || v.startsWith("'")) return v;
    final idx = v.indexOf(' #');
    return idx >= 0 ? v.substring(0, idx).trim() : v;
  }

  dynamic _scalar(String v) {
    if (v == '{}') return <String, dynamic>{};
    if (v == '[]') return <dynamic>[];
    if (v == 'null' || v == '~') return null;
    if (v == 'true') return true;
    if (v == 'false') return false;
    if ((v.startsWith('"') && v.endsWith('"') && v.length > 1) ||
        (v.startsWith("'") && v.endsWith("'") && v.length > 1)) {
      return v.substring(1, v.length - 1);
    }
    return v;
  }
}

// ---------- helpers ----------

String? _str(dynamic v) => v?.toString().trim();

// Pretty-prints a parsed YAML value as readable text.
String _render(dynamic v, [int depth = 0]) {
  if (v == null) return '';
  // Wrap prose; leave literal blocks (code/XML snippets) untouched.
  if (v is String) {
    final t = v.trim();
    return t.contains('\n') ? t : _wrap(t, 76 - depth * 2);
  }
  if (v is bool || v is num) return v.toString();
  if (v is List) {
    return v.map((e) {
      final body = _render(e, depth + 1);
      return body.contains('\n')
          ? '- ${_indent(body, '  ').trimLeft()}'
          : '- $body';
    }).join('\n');
  }
  if (v is Map) {
    final buf = StringBuffer();
    v.forEach((k, val) {
      final body = _render(val, depth + 1);
      if (body.contains('\n')) {
        buf.writeln('$k:');
        buf.writeln(_indent(body, '  '));
      } else {
        buf.writeln('$k: $body');
      }
    });
    return buf.toString().trimRight();
  }
  return v.toString();
}

// Word-wraps a paragraph to the given width.
String _wrap(String s, int width) {
  final words = s.replaceAll(RegExp(r'\s+'), ' ').trim().split(' ');
  final out = <String>[];
  var line = '';
  for (final w in words) {
    if (line.isEmpty) {
      line = w;
    } else if (line.length + 1 + w.length <= width) {
      line = '$line $w';
    } else {
      out.add(line);
      line = w;
    }
  }
  if (line.isNotEmpty) out.add(line);
  return out.join('\n');
}

String _indent(String s, String pad) =>
    s.split('\n').map((l) => l.trim().isEmpty ? '' : '$pad$l').join('\n');

String _join(String a, String b) =>
    '$a${Platform.pathSeparator}${b.replaceAll('/', Platform.pathSeparator)}';

String _dirname(String p) {
  final idx = p.lastIndexOf(Platform.pathSeparator);
  return idx <= 0 ? p : p.substring(0, idx);
}

// Walks up from the CWD looking for the project root (pubspec.yaml + modules/).
String _findProjectRoot() {
  var dir = Directory.current.absolute;
  for (var n = 0; n < 8; n++) {
    if (File(_join(dir.path, 'pubspec.yaml')).existsSync() &&
        Directory(_join(dir.path, 'modules')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  _fail('Run this from the Flutter project root (needs pubspec.yaml and modules/).');
}

Never _fail(String msg) {
  stderr.writeln('ERROR: $msg');
  exit(1);
}
