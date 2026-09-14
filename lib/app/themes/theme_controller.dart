import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/local_data/cache_manager.dart';

class ThemeController extends GetxController {
  // Reactive theme mode
  final Rx<ThemeMode> _themeMode = ThemeMode.system.obs;

  // Expose the Rx directly so Obx can listen to changes
  Rx<ThemeMode> get themeModeRx => _themeMode;
  ThemeMode get themeMode => _themeMode.value;

  // Check if current theme is dark
  bool get isDarkMode {
    if (_themeMode.value == ThemeMode.system) {
      return Get.isPlatformDarkMode;
    }
    return _themeMode.value == ThemeMode.dark;
  }

  @override
  void onInit() {
    super.onInit();
    _loadThemeFromCache();
  }

  /// Load saved theme preference from cache
  void _loadThemeFromCache() {
    final savedTheme = CacheManager.getThemeId;
    if (savedTheme != null && savedTheme.isNotEmpty) {
      switch (savedTheme) {
        case 'light':
          _themeMode.value = ThemeMode.light;
          break;
        case 'dark':
          _themeMode.value = ThemeMode.dark;
          break;
        default:
          _themeMode.value = ThemeMode.system;
      }
    }
  }

  /// Change theme and persist to cache
  Future<void> changeTheme(ThemeMode mode) async {
    _themeMode.value = mode;

    // Save to cache
    String themeId;
    switch (mode) {
      case ThemeMode.light:
        themeId = 'light';
        break;
      case ThemeMode.dark:
        themeId = 'dark';
        break;
      default:
        themeId = 'system';
    }
    await CacheManager.setThemeId(themeId);

    // Update GetMaterialApp theme
    Get.changeThemeMode(mode);

    // Force rebuild all GetBuilder widgets
    update();

    // Force UI refresh by triggering a frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.forceAppUpdate();
    });
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    if (isDarkMode) {
      await changeTheme(ThemeMode.light);
    } else {
      await changeTheme(ThemeMode.dark);
    }
  }

  /// Set system theme
  Future<void> setSystemTheme() async {
    await changeTheme(ThemeMode.system);
  }
}
