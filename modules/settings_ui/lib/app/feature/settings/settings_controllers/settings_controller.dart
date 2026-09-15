import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_starter/app/core/di/user_di.dart';
import 'package:flutter_starter/app/feature/settings/settings_logic/settings_store.dart';
import 'package:flutter_starter/app/localization/app_translations.dart';
import 'package:flutter_starter/app/routes/app_routes.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:flutter_starter/app/services/local_data/cache_manager.dart';
import 'package:flutter_starter/app/themes/theme_controller.dart';
import 'package:flutter_starter/app/widgets/feedback/custom_snack_bar.dart';

/// Drives the settings screen. Everything here is local — no API, no repo.
class SettingsController extends GetxController {
  /// Where logout lands. Reassign once at startup if your app differs.
  String logoutRoute = AppRoutes.SigninScreen;

  /// Keeps theme + language across a logout; removeAll() wipes those keys too.
  bool keepPreferencesOnLogout = true;

  /// Hook for a push SDK — subscribe/unsubscribe when the toggle flips.
  Future<void> Function(bool enabled)? onNotificationsChanged;

  /// Hook for a disk cache (flutter_cache_manager, Hive, Drift, …).
  Future<void> Function()? onClearCache;

  final RxBool notificationsEnabled = true.obs;
  final RxString appVersion = ''.obs;
  final RxBool isClearingCache = false.obs;
  final RxBool isLoggingOut = false.obs;

  // A language lists itself in its own tongue, so these are never translated.
  static const Map<String, String> _languageNames = {
    'en': 'English',
    'bn': 'বাংলা',
  };

  ThemeController get _themeController => Get.find<ThemeController>();

  ThemeMode get themeMode => _themeController.themeMode;

  Locale get locale => Get.locale ?? AppTranslations.fallbackLocale;

  List<Locale> get supportedLocales => AppTranslations.supported;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  @override
  void onClose() {
    notificationsEnabled.close();
    appVersion.close();
    isClearingCache.close();
    isLoggingOut.close();
    super.onClose();
  }

  Future<void> _load() async {
    await SettingsStore.init();
    notificationsEnabled.value = SettingsStore.notificationsEnabled;
    await _loadVersion();
  }

  /// Version row. A plugin failure must not blank the whole screen.
  Future<void> _loadVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      appVersion.value = '${info.version} (${info.buildNumber})';
    } catch (e) {
      devPrint('Could not read package info: $e');
      appVersion.value = '';
    }
  }

  // ── Theme ──

  /// English key for a mode; the screen appends `.tr`.
  String themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  Future<void> changeTheme(ThemeMode mode) async {
    if (mode == themeMode) return;
    await _themeController.changeTheme(mode);
    update();
  }

  // ── Language ──

  String languageLabel(Locale value) =>
      _languageNames[value.languageCode] ?? value.languageCode.toUpperCase();

  /// Persists through AppTranslations.setLocale, so it survives a restart.
  Future<void> changeLocale(Locale value) async {
    if (value.languageCode == locale.languageCode) return;
    await AppTranslations.setLocale(value);
    update();
  }

  // ── Notifications ──

  Future<void> setNotifications(bool value) async {
    notificationsEnabled.value = value;
    await SettingsStore.setNotificationsEnabled(value);
    try {
      await onNotificationsChanged?.call(value);
    } catch (e) {
      devPrint('onNotificationsChanged failed: $e');
    }
  }

  // ── Links ──

  /// Opens [url] externally, or falls back to an in-app route when unset.
  Future<void> openLink(
    BuildContext context,
    String url, {
    String? fallbackRoute,
  }) async {
    final String target = url.trim();
    if (target.isEmpty) {
      if (fallbackRoute != null) Get.toNamed(fallbackRoute);
      return;
    }

    final Uri? uri = Uri.tryParse(target);
    if (uri == null || !uri.hasScheme) {
      _notify(context, SnackBarType.Failure, 'Could not open link'.tr, target);
      return;
    }

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        _notify(
          context,
          SnackBarType.Failure,
          'Could not open link'.tr,
          target,
        );
      }
    } catch (e) {
      devPrint('launchUrl failed: $e');
      if (context.mounted) {
        _notify(
          context,
          SnackBarType.Failure,
          'Could not open link'.tr,
          target,
        );
      }
    }
  }

  // ── Cache ──

  /// Drops Flutter's in-memory image cache; session data is untouched.
  Future<void> clearCache(BuildContext context) async {
    if (isClearingCache.value) return;
    isClearingCache.value = true;
    try {
      final ImageCache cache = PaintingBinding.instance.imageCache;
      cache.clear();
      cache.clearLiveImages();
      await onClearCache?.call();
      if (context.mounted) {
        _notify(
          context,
          SnackBarType.Success,
          'Cache cleared'.tr,
          'Temporary files have been removed'.tr,
        );
      }
    } catch (e) {
      devPrint('clearCache failed: $e');
      if (context.mounted) {
        _notify(
          context,
          SnackBarType.Failure,
          'Could not clear cache'.tr,
          'Please try again'.tr,
        );
      }
    } finally {
      isClearingCache.value = false;
    }
  }

  // ── Logout ──

  /// Wipes the session, then restarts at [logoutRoute].
  Future<void> logout() async {
    if (isLoggingOut.value) return;
    isLoggingOut.value = true;

    final String? themeId = CacheManager.getThemeId;
    final String? savedLocale = CacheManager.getLocale;

    try {
      if (Get.isRegistered<UserDi>()) {
        await Get.find<UserDi>().clearUserData();
      }
      await CacheManager.removeAll();
      if (keepPreferencesOnLogout) {
        if (themeId != null) await CacheManager.setThemeId(themeId);
        if (savedLocale != null) await CacheManager.setLocale(savedLocale);
      }
    } catch (e) {
      devPrint('logout failed: $e');
    } finally {
      isLoggingOut.value = false;
    }

    notificationsEnabled.value = SettingsStore.notificationsEnabled;
    Get.offAllNamed(logoutRoute);
  }

  void _notify(
    BuildContext context,
    SnackBarType type,
    String title,
    String description,
  ) {
    showCustomSnackBar(
      context: context,
      type: type,
      title: title,
      description: description,
    );
  }
}
