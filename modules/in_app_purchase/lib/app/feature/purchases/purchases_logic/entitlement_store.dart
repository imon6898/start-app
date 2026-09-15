// Module-local persistence for the last server-granted entitlement. Own keys,
// own SharedPreferences handle — installing needs no edit to CacheManager.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/app/feature/purchases/purchases_models/entitlement_model.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';

class EntitlementStore {
  EntitlementStore._();

  static const String entitlementKey = 'iap_entitlement';
  static const String cachedAtKey = 'iap_entitlement_cached_at';

  /// How long an offline device keeps trusting the last server answer. Longer
  /// is friendlier to travellers; shorter limits how long a cancelled user
  /// keeps access by staying offline. Seven days is the usual compromise.
  static Duration maxCacheAge = const Duration(days: 7);

  static SharedPreferences? _pref;
  static EntitlementModel? _entitlement;
  static DateTime? _cachedAt;

  /// True once [init] has read the disk.
  static bool get isReady => _pref != null;

  static DateTime? get cachedAt => _cachedAt;

  static bool get isStale {
    final at = _cachedAt;
    if (at == null) return true;
    return DateTime.now().difference(at) > maxCacheAge;
  }

  /// The cached verdict, or null when absent or older than [maxCacheAge].
  static EntitlementModel? get cached => isStale ? null : _entitlement;

  /// Kept separately so the UI can say "last checked 3 days ago" even when the
  /// value is too old to trust.
  static EntitlementModel? get cachedEvenIfStale => _entitlement;

  static Future<void> init() async {
    try {
      _pref = await SharedPreferences.getInstance();
      final raw = _pref?.getString(entitlementKey);
      final at = _pref?.getInt(cachedAtKey);
      _cachedAt =
          at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
      _entitlement = raw == null
          ? null
          : EntitlementModel.fromJson(jsonDecode(raw));
    } catch (e) {
      // Unreadable prefs fail closed: no cache means "ask the server".
      devPrint('$e', tag: 'IAP');
      _entitlement = null;
      _cachedAt = null;
    }
  }

  static Future<void> save(EntitlementModel entitlement) async {
    _entitlement = entitlement;
    _cachedAt = DateTime.now();
    try {
      await _pref?.setString(entitlementKey, jsonEncode(entitlement.toJson()));
      await _pref?.setInt(cachedAtKey, _cachedAt!.millisecondsSinceEpoch);
    } catch (e) {
      devPrint('$e', tag: 'IAP');
    }
  }

  /// Wipes both keys — call next to CacheManager.removeAll() on logout, or the
  /// next account on this device inherits the previous user's access.
  static Future<void> clear() async {
    _entitlement = null;
    _cachedAt = null;
    await _pref?.remove(entitlementKey);
    await _pref?.remove(cachedAtKey);
  }
}
