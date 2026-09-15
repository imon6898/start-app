// Scaffolds a feature folder in the house convention.
//   dart run tool/new_feature.dart orders
//   dart run tool/new_feature.dart orders --dry-run
//
// Writes the four folders and their starter files, then prints the three
// wiring edits it deliberately does not make for you (route, page, binding) —
// touching those files automatically would fight your editor's imports.

import 'dart:io';

const _pkg = 'flutter_starter';

void main(List<String> args) {
  final flags = args.where((a) => a.startsWith('--')).toSet();
  final names = args.where((a) => !a.startsWith('--')).toList();

  if (names.isEmpty) {
    _usage();
    exit(64);
  }

  final name = names.first;
  final dryRun = flags.contains('--dry-run');
  final force = flags.contains('--force');

  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
    _fail(
      "'$name' is not a valid feature name.\n"
      'Use lowercase_with_underscores, starting with a letter — e.g. orders, order_history.',
    );
  }

  final pascal = _toPascal(name);
  final root = Directory('lib/app/feature/$name');

  if (root.existsSync() && !force) {
    _fail(
      'lib/app/feature/$name/ already exists.\n'
      'Delete it, pick another name, or pass --force to overwrite.',
    );
  }

  final files = <String, String>{
    '${root.path}/${name}_models/${name}_model.dart': _model(pascal),
    '${root.path}/${name}_logic/${name}_api_service.dart': _apiService(pascal, name),
    '${root.path}/${name}_controllers/${name}_controller.dart': _controller(pascal, name),
    '${root.path}/${name}_presentation/${name}_screen.dart': _screen(pascal, name),
  };

  stdout.writeln(dryRun ? '[dry-run] Feature: $name' : 'Feature: $name');
  stdout.writeln();

  for (final entry in files.entries) {
    final exists = File(entry.key).existsSync();
    stdout.writeln('  ${exists ? 'overwrite' : 'create   '}  ${entry.key}');
    if (dryRun) continue;
    File(entry.key)
      ..createSync(recursive: true)
      ..writeAsStringSync(entry.value);
  }

  // Appended automatically so the generated Repo compiles on the first run.
  final endpointAdded = _addEndpoint(name, dryRun: dryRun);
  stdout.writeln(
    '  ${endpointAdded ? 'append   ' : 'skip     '}  '
    'lib/app/services/domain/api_const.dart  (${_camel(name)}Uri)',
  );

  stdout.writeln();
  _printWiring(pascal, name);

  if (dryRun) {
    stdout.writeln('\n[dry-run] Nothing was written.');
    return;
  }
  stdout.writeln(
    '\nThen run:  flutter analyze && flutter test'
    '\nThe guardrails will tell you if a wiring step is missing.',
  );
}

/// Appends `<name>Uri` before the closing brace of `class ApiConstant`.
/// Returns false if the file is missing or already has the key.
bool _addEndpoint(String name, {required bool dryRun}) {
  final file = File('lib/app/services/domain/api_const.dart');
  if (!file.existsSync()) return false;

  final key = '${_camel(name)}Uri';
  final src = file.readAsStringSync();
  if (src.contains(key)) return false;

  final close = src.lastIndexOf('}');
  if (close == -1) return false;

  final block = '\n  // ── ${_title(_toPascal(name))} ──\n'
      "  static const String $key = '/${name.replaceAll('_', '-')}';\n";

  if (!dryRun) {
    file.writeAsStringSync(src.replaceRange(close, close, block));
  }
  return true;
}

void _printWiring(String pascal, String name) {
  stdout.writeln('WIRE IT UP — the endpoint is already added; these are yours:');
  stdout.writeln();
  stdout.writeln('1. lib/app/routes/app_routes.dart');
  stdout.writeln('     /// ${_title(pascal)}');
  stdout.writeln("     static const String ${pascal}Screen = '/${_camel(name)}Screen';");
  stdout.writeln();
  stdout.writeln('2. lib/app/routes/app_pages.dart');
  stdout.writeln("     import '../feature/$name/${name}_presentation/${name}_screen.dart';");
  stdout.writeln('     // inside AppPages.pages:');
  stdout.writeln('     _page(AppRoutes.${pascal}Screen, () => const ${pascal}Screen()),');
  stdout.writeln();
  stdout.writeln('3. lib/app/bindings/view_model_binding.dart');
  stdout.writeln("     import '../feature/$name/${name}_controllers/${name}_controller.dart';");
  stdout.writeln('     // inside dependencies():');
  stdout.writeln('     // ${_title(pascal)}');
  stdout.writeln('     _lazy<${pascal}Controller>(() => ${pascal}Controller());');
  stdout.writeln();
  stdout.writeln('4. Strings — add every .tr key to BOTH files:');
  stdout.writeln('     lib/app/localization/locales/en_us.dart');
  stdout.writeln('     lib/app/localization/locales/bn_bd.dart');
}

String _model(String pascal) => '''
class ${pascal}Model {
  final String? id;
  final String? name;

  ${pascal}Model({this.id, this.name});

  ${pascal}Model copyWith({String? id, String? name}) =>
      ${pascal}Model(id: id ?? this.id, name: name ?? this.name);

  factory ${pascal}Model.fromJson(Map<String, dynamic> json) => ${pascal}Model(
        id: json['id'],
        name: json['name'],
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
''';

String _apiService(String pascal, String name) => '''
import 'package:$_pkg/app/services/domain/api_const.dart';
import 'package:$_pkg/app/services/domain/api_service.dart';

/// What the $name feature can ask the network to do.
abstract class ${pascal}ApiService {
  Future fetch${pascal}s(String url, {Map<String, dynamic>? params});
}

/// The only place ApiService is constructed for this feature.
class ${pascal}Impl extends ${pascal}ApiService {
  @override
  Future fetch${pascal}s(String url, {Map<String, dynamic>? params}) async {
    final dynamic response = await ApiService().get(url, params: params);
    return response;
  }
}

/// Picks the endpoint and unwraps the envelope. Controllers talk to this.
class ${pascal}Repo {
  final ${pascal}ApiService ${_camel(name)}ApiService = ${pascal}Impl();

  Future<dynamic>? fetch${pascal}s() async {
    // TODO: add ${_camel(name)}Uri to ApiConstant.
    dynamic responseData = await ${_camel(name)}ApiService.fetch${pascal}s(
      ApiConstant.${_camel(name)}Uri,
    );
    return responseData = responseData.data;
  }
}
''';

String _controller(String pascal, String name) => '''
import 'package:get/get.dart';
import 'package:$_pkg/app/core/models/base_response.dart';
import 'package:$_pkg/app/services/domain/dev_tools.dart';
import '../${name}_logic/${name}_api_service.dart';
import '../${name}_models/${name}_model.dart';

class ${pascal}Controller extends GetxController {
  final ${pascal}Repo _${_camel(name)}Repo = ${pascal}Repo();

  final RxList<${pascal}Model> items = <${pascal}Model>[].obs;
  final RxBool isLoading${pascal}s = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load${pascal}s();
  }

  Future<void> load${pascal}s() async {
    isLoading${pascal}s.value = true;
    errorMessage.value = '';
    try {
      final response = await _${_camel(name)}Repo.fetch${pascal}s();
      // The Repo returns null when offline or on a swallowed Dio error.
      if (response == null) {
        errorMessage.value = 'Something went wrong. Please try again.'.tr;
        return;
      }
      final parsed = BaseResponse<List<${pascal}Model>>.fromJson(
        response,
        (data) => (data as List).map((e) => ${pascal}Model.fromJson(e)).toList(),
      );
      items.assignAll(parsed.data ?? []);
    } catch (e) {
      devPrint('\$e', tag: '${pascal}Controller');
      errorMessage.value = 'Something went wrong. Please try again.'.tr;
    } finally {
      isLoading${pascal}s.value = false;
    }
  }
}
''';

String _screen(String pascal, String name) => '''
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:$_pkg/app/utils/constants/app_colors.dart';
import 'package:$_pkg/app/utils/constants/app_fonts.dart';
import 'package:$_pkg/app/utils/responsive_utils.dart';
import 'package:$_pkg/app/widgets/widgets.dart';
import '../${name}_controllers/${name}_controller.dart';
import '../${name}_models/${name}_model.dart';

class ${pascal}Screen extends StatelessWidget {
  const ${pascal}Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<${pascal}Controller>(
      builder: (controller) => Scaffold(
        backgroundColor: CustomColors.artboardColor(),
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
          child: AppBarWidget(title: '${_title(pascal)}'.tr),
        ),
        body: _body(context, controller),
      ),
    );
  }

  Widget _body(BuildContext context, ${pascal}Controller controller) {
    return Obx(() {
      if (controller.isLoading${pascal}s.value) {
        return const LoadingWidget();
      }
      if (controller.errorMessage.value.isNotEmpty) {
        return EmptyStateWidget(
          icon: LucideIcons.inbox,
          title: controller.errorMessage.value,
        );
      }
      return ListView.separated(
        padding: R.pad(horizontal: 16, vertical: 12),
        itemCount: controller.items.length,
        separatorBuilder: (_, _) => SizedBox(height: R.h(12)),
        itemBuilder: (_, i) => _tile(controller.items[i]),
      );
    });
  }

  Widget _tile(${pascal}Model item) {
    return CardContainer(
      child: Text(item.name ?? '', style: CustomTextStyles.medium16),
    );
  }
}
''';

String _toPascal(String snake) => snake
    .split('_')
    .where((p) => p.isNotEmpty)
    .map((p) => p[0].toUpperCase() + p.substring(1))
    .join();

String _camel(String snake) {
  final p = _toPascal(snake);
  return p[0].toLowerCase() + p.substring(1);
}

/// "OrderHistory" -> "Order History", for headings and route comments.
String _title(String pascal) =>
    pascal.replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => ' ${m[1]}');

void _usage() {
  stdout.writeln('''
Scaffold a feature in the house convention.

  dart run tool/new_feature.dart <name> [--dry-run] [--force]

  <name>      lowercase_with_underscores, e.g. orders, order_history
  --dry-run   print what would be written, write nothing
  --force     overwrite an existing feature folder

Creates:
  lib/app/feature/<name>/<name>_models/<name>_model.dart
  lib/app/feature/<name>/<name>_logic/<name>_api_service.dart
  lib/app/feature/<name>/<name>_controllers/<name>_controller.dart
  lib/app/feature/<name>/<name>_presentation/<name>_screen.dart

Then prints the route, page, binding and endpoint lines to paste.''');
}

Never _fail(String message) {
  stderr.writeln('error: $message');
  exit(1);
}
