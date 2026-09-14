// Encrypted token storage: Android KeyStore-backed AES-GCM, iOS/macOS Keychain.
// Drop-in replacement for the CacheManager token methods, but ASYNC.
// Call SecureStore.init() in bootstrap() right after CacheManager.init().
//   await SecureStore.setToken(token);
//   final token = await SecureStore.token;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStore {
  SecureStore._();

  // Keys inside the encrypted store. Owned by this module.
  static const String _kToken = 'token';
  static const String _kRefreshToken = 'refreshToken';

  // Plaintext SharedPreferences keys the migration drains (CacheKeys.*.name).
  static const String _kLegacyToken = 'token';
  static const String _kLegacyRefreshToken = 'refreshToken';

  // Not a secret — a plain flag so the migration runs exactly once.
  static const String _kMigrationDone = 'secure_store_migrated_v1';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    // AES-GCM data key wrapped by an RSA-OAEP KeyStore key. resetOnError wipes
    // the store instead of crashing when a value is undecryptable.
    aOptions: AndroidOptions(
      resetOnError: true,
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    // Readable after the first unlock since boot, and never leaves this device.
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static String? _tokenMem;
  static String? _refreshTokenMem;
  static bool _ready = false;

  /// Runs the one-time migration and warms the in-memory copy. Await before runApp.
  static Future<void> init() async {
    await migrateFromPlaintext();
    _tokenMem = await _read(_kToken);
    _refreshTokenMem = await _read(_kRefreshToken);
    _ready = true;
  }

  /// True once [init] has completed.
  static bool get isReady => _ready;

  // ── Auth tokens ──

  static Future<String?> get token async =>
      _ready ? _tokenMem : (_tokenMem = await _read(_kToken));

  static Future<bool> setToken(String value) async {
    _tokenMem = value;
    return _write(_kToken, value);
  }

  static Future<bool> removeToken() async {
    _tokenMem = null;
    return _delete(_kToken);
  }

  static Future<String?> get refreshToken async => _ready
      ? _refreshTokenMem
      : (_refreshTokenMem = await _read(_kRefreshToken));

  static Future<bool> setRefreshToken(String value) async {
    _refreshTokenMem = value;
    return _write(_kRefreshToken, value);
  }

  static Future<bool> removeRefreshToken() async {
    _refreshTokenMem = null;
    return _delete(_kRefreshToken);
  }

  /// Deletes every key this module owns. Leaves other plugins' secure keys alone.
  static Future<bool> clearAll() async {
    _tokenMem = null;
    _refreshTokenMem = null;
    final results = await Future.wait([
      _delete(_kToken),
      _delete(_kRefreshToken),
    ]);
    return results.every((ok) => ok);
  }

  // ── Synchronous mirrors ──
  // Only for call sites that cannot await (e.g. the Dio BaseOptions constructor).
  // Valid after init(); every setter keeps them in step.

  static String? get tokenSync => _tokenMem;

  static String? get refreshTokenSync => _refreshTokenMem;

  // ── One-time migration ──

  /// Moves plaintext tokens from SharedPreferences into secure storage, once.
  static Future<void> migrateFromPlaintext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kMigrationDone) == true) return;

      final moved = await Future.wait([
        _movePlaintextKey(prefs, _kLegacyToken, _kToken),
        _movePlaintextKey(prefs, _kLegacyRefreshToken, _kRefreshToken),
      ]);

      // Only latch the flag if nothing failed, so a flaky run retries next launch.
      if (moved.every((ok) => ok)) {
        await prefs.setBool(_kMigrationDone, true);
        devPrint('plaintext tokens migrated', tag: 'SecureStore');
      }
    } catch (e) {
      devPrint('migration failed: $e', tag: 'SecureStore');
    }
  }

  /// Copies one plaintext key into secure storage and deletes the original.
  static Future<bool> _movePlaintextKey(
    SharedPreferences prefs,
    String legacyKey,
    String secureKey,
  ) async {
    String? legacy;
    try {
      legacy = prefs.getString(legacyKey);
    } catch (_) {
      // Key exists with a non-String type — nothing worth migrating.
      legacy = null;
    }
    if (legacy == null || legacy.isEmpty) {
      await prefs.remove(legacyKey);
      return true;
    }

    // A value already in secure storage wins; the plaintext copy is stale.
    final alreadySecure = await _read(secureKey);
    if (alreadySecure == null || alreadySecure.isEmpty) {
      if (!await _write(secureKey, legacy)) return false;
    }

    await prefs.remove(legacyKey);
    return true;
  }

  // ── Plumbing ──

  static Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      devPrint('read "$key" failed: $e', tag: 'SecureStore');
      return null;
    }
  }

  static Future<bool> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return true;
    } catch (e) {
      devPrint('write "$key" failed: $e', tag: 'SecureStore');
      return false;
    }
  }

  static Future<bool> _delete(String key) async {
    try {
      await _storage.delete(key: key);
      return true;
    } catch (e) {
      devPrint('delete "$key" failed: $e', tag: 'SecureStore');
      return false;
    }
  }
}
