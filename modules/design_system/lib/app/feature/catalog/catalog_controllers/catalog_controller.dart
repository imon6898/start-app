import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_starter/app/core/helpers/pagination_helper.dart';
import 'package:flutter_starter/app/localization/app_translations.dart';
import 'package:flutter_starter/app/themes/theme_controller.dart';
import 'package:get/get.dart';

import '../catalog_models/catalog_entry.dart';

/// State for the component catalog: which tab, which filter, and the three
/// global preview toggles (theme, text scale, locale).
class CatalogController extends GetxController {
  /// 0 = components, 1 = tokens.
  final RxInt tab = 0.obs;

  final RxString query = ''.obs;
  final RxnString group = RxnString();
  final RxDouble textScale = 1.0.obs;
  final RxString localeTag = ''.obs;

  final TextEditingController searchController = TextEditingController();

  // Demo state for the input widgets — a screen owns its controllers.
  final TextEditingController demoText = TextEditingController(
    text: 'Ada Lovelace',
  );
  final TextEditingController demoPassword = TextEditingController(
    text: 'correct horse',
  );
  final TextEditingController demoPhone = TextEditingController();
  final TextEditingController demoNotes = TextEditingController();
  final RxList<int> demoSelection = <int>[].obs;
  final RxList<int> demoMultiSelection = <int>[2].obs;
  final Rx<DateTime?> demoDate = Rx<DateTime?>(null);
  final Rx<File?> demoFile = Rx<File?>(null);
  final PaginationHelper<String> demoFeed = PaginationHelper<String>();

  /// Scales worth testing: default, large, accessibility-large, maximum.
  static const List<double> textScales = <double>[1.0, 1.3, 1.6, 2.0];

  ThemeMode? _restoreThemeMode;
  Locale? _restoreLocale;

  ThemeController get theme => Get.find<ThemeController>();

  @override
  void onInit() {
    super.onInit();
    _restoreThemeMode = theme.themeMode;
    _restoreLocale = Get.locale;
    localeTag.value = Get.locale == null
        ? ''
        : AppTranslations.tagOf(Get.locale!);

    // Fake feed so PaginationView has something to show without a backend.
    demoFeed.setup(
      (page, limit) async =>
          List<String>.generate(6, (i) => 'Feed item ${i + 1}'),
    );
    demoFeed.load();
  }

  @override
  void onClose() {
    searchController.dispose();
    demoText.dispose();
    demoPassword.dispose();
    demoPhone.dispose();
    demoNotes.dispose();

    // The toggles are global, so put the app back the way we found it.
    if (_restoreThemeMode != null && _restoreThemeMode != theme.themeMode) {
      theme.changeTheme(_restoreThemeMode!);
    }
    if (_restoreLocale != null && _restoreLocale != Get.locale) {
      Get.updateLocale(_restoreLocale!);
    }
    super.onClose();
  }

  List<CatalogEntry> filter(List<CatalogEntry> all) => all
      .where((e) => e.matches(query.value))
      .where((e) => group.value == null || e.group == group.value)
      .toList(growable: false);

  List<String> groupsOf(List<CatalogEntry> all) {
    final seen = <String>[];
    for (final e in all) {
      if (!seen.contains(e.group)) seen.add(e.group);
    }
    return seen;
  }

  void onQueryChanged(String value) => query.value = value;

  void clearQuery() {
    searchController.clear();
    query.value = '';
  }

  void selectGroup(String? value) =>
      group.value = group.value == value ? null : value;

  /// Flips the real app theme: CustomColors reads the ThemeController, not
  /// Theme.of(context), so a local override would not reach the widgets.
  void toggleTheme() => theme.toggleTheme();

  void cycleTextScale() {
    final next = (textScales.indexOf(textScale.value) + 1) % textScales.length;
    textScale.value = textScales[next];
  }

  /// `.tr` resolves against the global locale, so this switches it app-wide
  /// without persisting — onClose restores the user's choice.
  void cycleLocale() {
    final locales = AppTranslations.supported;
    if (locales.isEmpty) return;
    final current = locales.indexWhere(
      (l) => AppTranslations.tagOf(l) == localeTag.value,
    );
    final next = locales[(current + 1) % locales.length];
    localeTag.value = AppTranslations.tagOf(next);
    Get.updateLocale(next);
  }
}
