import 'package:shared_preferences/shared_preferences.dart';

/// Module-local snooze store. Keeps its keys out of core CacheManager so the
/// module installs without editing anything in lib/.
class AppUpdateStore {
  static const String _versionKey = 'app_update_snoozed_version';
  static const String _atKey = 'app_update_snoozed_at';

  /// Version the user last tapped "Remind me later" on.
  static Future<String?> snoozedVersion() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(_versionKey);
  }

  /// When that snooze was taken.
  static Future<DateTime?> snoozedAt() async {
    final pref = await SharedPreferences.getInstance();
    final raw = pref.getInt(_atKey);
    return raw == null ? null : DateTime.fromMillisecondsSinceEpoch(raw);
  }

  /// Silences the soft sheet for [version] until the snooze window expires.
  static Future<void> snooze(String version) async {
    if (version.isEmpty) return;
    final pref = await SharedPreferences.getInstance();
    await pref.setString(_versionKey, version);
    await pref.setInt(_atKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Re-arms the sheet on the next check.
  static Future<void> clear() async {
    final pref = await SharedPreferences.getInstance();
    await pref.remove(_versionKey);
    await pref.remove(_atKey);
  }
}
