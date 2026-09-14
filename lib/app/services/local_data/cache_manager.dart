// /// How to use for set
// ///         await CacheManager.setId(data['id'] ?? "");
// ///         await CacheManager.setToken(data['token'] ?? "");
// ///         await CacheManager.setEmail(data['email'] ?? "");
// ///         await CacheManager.setFirstName(data['firstName'] ?? "");
// ///         await CacheManager.setSignUpAs(data['signUpAs'] ?? "");
// ///         await CacheManager.setDriverId(data['driverId'] ?? "");
// ///         await CacheManager.setPictureBase64(data['pictureBase64'] ?? "");

// /// How to use for get
// ///         String? email = CacheManager.email;

import 'dart:convert';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

class CacheManager {
  static SharedPreferences? _pref;

  static Future<void> init() async {
    _pref = await SharedPreferences.getInstance();
  }

  // Setters
  static Future<bool> setThemeId(String themeId) async {log("Setting Theme ID: $themeId");return await _saveToCache(CacheKeys.themeId.name, themeId);}



  // Getters
  static String? get getThemeId {var value = _getFromCache<String>(CacheKeys.themeId.name);log("Theme ID: $value");return value;}


  // Removers
  static Future<bool> removeThemeId() async {log("Removing Theme ID");return await _remove(CacheKeys.themeId.name);}


  // Removers All
  static Future<bool> removeAll() async {log("Removing all data from cache");return await _removeAll();}
  static Future<bool> _removeAll() async {if (_pref == null) {log("SharedPreferences instance is null. Cannot remove all data");return false;}final removed = await _pref!.clear();log("Removed all data from cache: $removed");return removed;}



  // Helper function to remove a value from cache
  static Future<bool> _remove(String key) async {
    if (_pref == null) {
      log("SharedPreferences instance is null. Cannot remove key: $key");
      return false;
    }
    if (!_pref!.containsKey(key)) {
      log("Key '$key' does not exist in cache. Nothing to remove.");
      return false;
    }
    final removed = await _pref!.remove(key);
    log("Removed key '$key' from cache: $removed");
    return removed;
  }

  // Helper function to get data from cache
  static dynamic _getFromCache<T>(String key) {
    log("Getting $key as type: ${T.toString()}");
    if (_pref == null) return '';
    if (T == int) {
      return _pref!.getInt(key) ?? 0;
    } else if (T == bool) {
      return _pref!.getBool(key) ?? false;
    }
    return _pref!.getString(key) ?? '';
  }

  // Helper function to save data to cache
  static Future<bool> _saveToCache(String key, dynamic value) async {
    log("Saving $key with value: $value of type: ${value.runtimeType}");
    if (_pref == null || value == null) return false;
    log("save To Cache");
    if (value is bool) {
      return await _pref!.setBool(key, value);
    } else if (value is int) {
      return await _pref!.setInt(key, value);
    }
    return await _pref!.setString(key, value);
  }
}

enum CacheKeys {
  themeId,
}
