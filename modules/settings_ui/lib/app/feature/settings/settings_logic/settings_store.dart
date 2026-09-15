// Module-owned preference keys, so installing settings_ui needs no edit to the
// core CacheManager. Same SharedPreferences box, a namespaced key.

import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  SettingsStore._();

  /// Namespaced so it never collides with a CacheKeys entry.
  static const String notificationsKey = 'settings_ui.notificationsEnabled';

  static SharedPreferences? _pref;

  /// Safe to call more than once; SettingsController calls it in onInit.
  static Future<void> init() async {
    _pref ??= await SharedPreferences.getInstance();
  }

  /// Defaults to on — a fresh install should still receive announcements.
  static bool get notificationsEnabled =>
      _pref?.getBool(notificationsKey) ?? true;

  static Future<bool> setNotificationsEnabled(bool value) async {
    await init();
    return _pref!.setBool(notificationsKey, value);
  }

  static Future<bool> removeNotificationsEnabled() async {
    await init();
    return _pref!.remove(notificationsKey);
  }
}
