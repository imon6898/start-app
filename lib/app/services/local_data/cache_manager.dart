// Typed wrapper over SharedPreferences. Add a key to [CacheKeys], then a
// set/get/remove trio below. Call CacheManager.init() before runApp.
//   await CacheManager.setToken(token);
//   final token = CacheManager.token;

import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

class CacheManager {
  static SharedPreferences? _pref;

  static Future<void> init() async {
    _pref = await SharedPreferences.getInstance();
  }

  // ── Auth tokens ──
  static String? get token => _getFromCache<String>(CacheKeys.token.name);
  static Future<bool> setToken(String value) => _saveToCache(CacheKeys.token.name, value);
  static Future<bool> removeToken() => _remove(CacheKeys.token.name);

  static String? get refreshToken => _getFromCache<String>(CacheKeys.refreshToken.name);
  static Future<bool> setRefreshToken(String value) => _saveToCache(CacheKeys.refreshToken.name, value);
  static Future<bool> removeRefreshToken() => _remove(CacheKeys.refreshToken.name);

  // ── Session user ──
  /// The signed-in user serialised as JSON.
  static String? get userData => _getFromCache<String>(CacheKeys.userData.name);
  static Future<bool> setUserData(String value) => _saveToCache(CacheKeys.userData.name, value);
  static Future<bool> removeUserData() => _remove(CacheKeys.userData.name);

  static String? get userType => _getFromCache<String>(CacheKeys.userType.name);
  static Future<bool> setUserType(String value) => _saveToCache(CacheKeys.userType.name, value);
  static Future<bool> removeUserType() => _remove(CacheKeys.userType.name);

  /// Roles are stored as a JSON array string; [rolesList] decodes it.
  static Future<bool> setRoles(String jsonList) => _saveToCache(CacheKeys.roles.name, jsonList);
  static Future<bool> removeRoles() => _remove(CacheKeys.roles.name);
  static List<String> get rolesList {
    final raw = _getFromCache<String>(CacheKeys.roles.name);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (e) {
      log("Could not decode cached roles: $e");
      return const [];
    }
  }

  // ── Flags ──
  static bool get isGuest => _getFromCache<bool>(CacheKeys.isGuest.name) ?? false;
  static Future<bool> setIsGuest(bool value) => _saveToCache(CacheKeys.isGuest.name, value);
  static Future<bool> removeIsGuest() => _remove(CacheKeys.isGuest.name);

  static bool get hasSeenOnboarding => _getFromCache<bool>(CacheKeys.hasSeenOnboarding.name) ?? false;
  static Future<bool> setHasSeenOnboarding(bool value) => _saveToCache(CacheKeys.hasSeenOnboarding.name, value);
  static Future<bool> removeHasSeenOnboarding() => _remove(CacheKeys.hasSeenOnboarding.name);

  // ── "Remember me" credentials ──
  static String? get getLoginEmail => _getFromCache<String>(CacheKeys.loginEmail.name);
  static Future<bool> setLoginEmail(String value) => _saveToCache(CacheKeys.loginEmail.name, value);
  static Future<bool> removeLoginEmail() => _remove(CacheKeys.loginEmail.name);

  static String? get getLoginPassword => _getFromCache<String>(CacheKeys.loginPassword.name);
  static Future<bool> setLoginPassword(String value) => _saveToCache(CacheKeys.loginPassword.name, value);
  static Future<bool> removeLoginPassword() => _remove(CacheKeys.loginPassword.name);

  // ── Theme ──
  static String? get getThemeId => _getFromCache<String>(CacheKeys.themeId.name);
  static Future<bool> setThemeId(String themeId) => _saveToCache(CacheKeys.themeId.name, themeId);
  static Future<bool> removeThemeId() => _remove(CacheKeys.themeId.name);

  /// Wipes every key — use on logout.
  static Future<bool> removeAll() async {
    if (_pref == null) return false;
    return await _pref!.clear();
  }

  static Future<bool> _remove(String key) async {
    if (_pref == null || !_pref!.containsKey(key)) return false;
    return await _pref!.remove(key);
  }

  static dynamic _getFromCache<T>(String key) {
    if (_pref == null) return null;
    if (T == int) return _pref!.getInt(key);
    if (T == bool) return _pref!.getBool(key);
    return _pref!.getString(key);
  }

  static Future<bool> _saveToCache(String key, dynamic value) async {
    if (_pref == null || value == null) return false;
    if (value is bool) return await _pref!.setBool(key, value);
    if (value is int) return await _pref!.setInt(key, value);
    return await _pref!.setString(key, value);
  }
}

enum CacheKeys {
  token,
  refreshToken,
  userData,
  userType,
  roles,
  isGuest,
  hasSeenOnboarding,
  loginEmail,
  loginPassword,
  themeId,
}
