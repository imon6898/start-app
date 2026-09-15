// Module-local persistence for the app lock. Own keys, own SharedPreferences
// handle — installing this module needs no edit to CacheManager.

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/app/services/domain/dev_tools.dart';

class AppLockStore {
  AppLockStore._();

  static const String enabledKey = 'app_lock_enabled';
  static const String timeoutKey = 'app_lock_timeout_seconds';

  /// Opt-in: off until the user turns it on.
  static const bool defaultEnabled = false;

  /// Seconds in the background before the lock screen comes back.
  static const int defaultTimeoutSeconds = 30;

  /// Choices the settings screen offers. 0 means lock immediately.
  static const List<int> timeoutOptions = <int>[0, 15, 30, 60, 300];

  static SharedPreferences? _pref;
  static bool _enabled = defaultEnabled;
  static int _timeoutSeconds = defaultTimeoutSeconds;

  /// True once [init] has read the disk.
  static bool get isReady => _pref != null;

  static bool get isEnabled => _enabled;

  static int get timeoutSeconds => _timeoutSeconds;

  /// Call from bootstrap before runApp so the first frame already knows.
  static Future<void> init() async {
    try {
      _pref = await SharedPreferences.getInstance();
      _enabled = _pref?.getBool(enabledKey) ?? defaultEnabled;
      _timeoutSeconds = _pref?.getInt(timeoutKey) ?? defaultTimeoutSeconds;
    } catch (e) {
      // Unreadable prefs fail open — a broken store must not trap the user.
      devPrint('$e', tag: 'AppLock');
      _enabled = defaultEnabled;
      _timeoutSeconds = defaultTimeoutSeconds;
    }
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _pref?.setBool(enabledKey, value);
  }

  static Future<void> setTimeoutSeconds(int value) async {
    _timeoutSeconds = value < 0 ? 0 : value;
    await _pref?.setInt(timeoutKey, _timeoutSeconds);
  }

  /// Wipes both keys — call next to CacheManager.removeAll() on logout.
  static Future<void> clear() async {
    _enabled = defaultEnabled;
    _timeoutSeconds = defaultTimeoutSeconds;
    await _pref?.remove(enabledKey);
    await _pref?.remove(timeoutKey);
  }
}
