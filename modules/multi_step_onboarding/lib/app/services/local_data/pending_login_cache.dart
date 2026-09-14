import 'package:shared_preferences/shared_preferences.dart';

/// Holds the credentials entered during signup so the app can auto-login after OTP.
/// Clear it as soon as the login succeeds — this is not a secure store.
class PendingLoginCache {
  static const _emailKey = 'pending_login_email';
  static const _passwordKey = 'pending_login_password';

  static Future<void> setEmail(String email) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString(_emailKey, email);
  }

  static Future<void> setPassword(String password) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString(_passwordKey, password);
  }

  static Future<String?> getEmail() async =>
      (await SharedPreferences.getInstance()).getString(_emailKey);

  static Future<String?> getPassword() async =>
      (await SharedPreferences.getInstance()).getString(_passwordKey);

  static Future<void> clear() async {
    final pref = await SharedPreferences.getInstance();
    await pref.remove(_emailKey);
    await pref.remove(_passwordKey);
  }
}
