// Module-owned SharedPreferences keys, so installing feature_flags needs no
// edit to the core CacheManager. Same box, namespaced keys.

import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class FeatureFlagStore {
  FeatureFlagStore._();

  static const String documentKey = 'feature_flags.document';
  static const String fetchedAtKey = 'feature_flags.fetchedAt';
  static const String overridesKey = 'feature_flags.overrides';
  static const String variantOverridesKey = 'feature_flags.variantOverrides';
  static const String anonymousIdKey = 'feature_flags.anonymousId';

  static SharedPreferences? _pref;

  /// Safe to call twice; the service calls it in init().
  static Future<void> init() async {
    _pref ??= await SharedPreferences.getInstance();
  }

  /// The last successful response, stored verbatim so a parser change also
  /// applies to already-cached data.
  static String? get rawDocument => _pref?.getString(documentKey);

  static Future<void> setRawDocument(String json) async {
    await _pref?.setString(documentKey, json);
  }

  static DateTime? get fetchedAt {
    final raw = _pref?.getString(fetchedAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static Future<void> setFetchedAt(DateTime value) async {
    await _pref?.setString(fetchedAtKey, value.toIso8601String());
  }

  static Map<String, dynamic> get overrides => _decode(overridesKey);

  static Future<void> setOverrides(Map<String, dynamic> value) async {
    await _pref?.setString(overridesKey, jsonEncode(value));
  }

  static Map<String, String> get variantOverrides => _decode(
    variantOverridesKey,
  ).map((key, value) => MapEntry(key, value.toString()));

  static Future<void> setVariantOverrides(Map<String, String> value) async {
    await _pref?.setString(variantOverridesKey, jsonEncode(value));
  }

  /// Stable per-install id, so a signed-out user keeps one bucket instead of
  /// re-rolling every launch. Wiping app data re-buckets that install.
  static String get anonymousId {
    final existing = _pref?.getString(anonymousIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id =
        'anon-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '-${Random().nextInt(1 << 32).toRadixString(36)}';
    _pref?.setString(anonymousIdKey, id);
    return id;
  }

  static Future<void> clearOverrides() async {
    await _pref?.remove(overridesKey);
    await _pref?.remove(variantOverridesKey);
  }

  /// Drops the cached document — use only when flags are user-specific and the
  /// user just signed out. The anonymous id survives.
  static Future<void> clearDocument() async {
    await _pref?.remove(documentKey);
    await _pref?.remove(fetchedAtKey);
  }

  static Map<String, dynamic> _decode(String key) {
    final raw = _pref?.getString(key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }
}
