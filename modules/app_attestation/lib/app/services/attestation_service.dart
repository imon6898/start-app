// Device attestation: Play Integrity (Android) + App Attest/DeviceCheck (iOS).
// Produces a token your BACKEND verifies with Google/Apple. Checking it on the
// client is worthless — an attacker owns the client.
//   await AttestationService.to.init();                  // once, in bootstrap
//   final t = await AttestationService.to.tokenFor(hash); // per sensitive call
//
// Requires the native side from modules/app_attestation/platform/. There is no
// first-party Flutter package for either API; this talks to a MethodChannel.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/env.dart';
import 'attestation/attestation_token.dart';
import 'domain/dev_tools.dart';

class AttestationService extends GetxService {
  /// `.env` key holding the Google Cloud project number linked in Play Console.
  static const String cloudProjectNumberKey =
      'PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER';

  /// Must match the channel name in the Kotlin/Swift stubs.
  static const MethodChannel channel = MethodChannel(
    'flutter_starter/attestation',
  );

  /// Self-registering so bootstrap can use it before ViewModelBinding runs.
  static AttestationService get to => Get.isRegistered<AttestationService>()
      ? Get.find<AttestationService>()
      : Get.put(AttestationService(), permanent: true);

  /// SharedPreferences key holding the iOS App Attest key id.
  static const String keyIdPrefKey = 'attestation_key_id';

  /// How long a token stays reusable. Keep it short; the backend also expires it.
  Duration tokenTtl = const Duration(minutes: 5);

  /// Floor between two native calls. Attestation is quota-limited and slow.
  Duration minInterval = const Duration(seconds: 10);

  /// Backoff after a failure, doubled per consecutive failure up to [maxBackoff].
  Duration baseBackoff = const Duration(seconds: 30);
  Duration maxBackoff = const Duration(minutes: 15);

  bool _warm = false;
  String? _keyId;
  AttestationToken? _cached;
  Completer<AttestationToken?>? _inFlight;
  DateTime? _lastCallAt;
  DateTime? _blockedUntil;
  int _failures = 0;
  AttestationSkipReason? _lastSkip;

  /// Only Android and iOS have an attestation API worth calling.
  bool get isSupportedPlatform => Platform.isAndroid || Platform.isIOS;

  /// True once [init] found a working native implementation.
  bool get isReady => _warm;

  /// Why the last call produced nothing. Null after a success.
  AttestationSkipReason? get lastSkipReason => _lastSkip;

  /// App Attest key id, once registered. Null on Android.
  String? get keyId => _keyId;

  /// Call once from bootstrap. Never throws; a failure just leaves attestation off.
  Future<AttestationService> init() async {
    if (_warm) return this;
    if (!isSupportedPlatform) {
      _lastSkip = AttestationSkipReason.unsupportedPlatform;
      devPrint('off — unsupported platform', tag: 'Attestation');
      return this;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _keyId = prefs.getString(keyIdPrefKey);

      // Android warms the standard Play Integrity token provider here; iOS
      // checks DCAppAttestService.isSupported. Both are cheap and idempotent.
      final ok =
          await channel.invokeMethod<bool>('warmUp', {
            'cloudProjectNumber': Env.optional(cloudProjectNumberKey),
          }) ??
          false;
      _warm = ok;
      if (!ok) _lastSkip = AttestationSkipReason.notConfigured;
      devPrint(ok ? 'warm' : 'off — native warmUp said no', tag: 'Attestation');
    } on MissingPluginException {
      _lastSkip = AttestationSkipReason.notConfigured;
      devPrint('off — native side not installed', tag: 'Attestation');
    } catch (e) {
      _lastSkip = AttestationSkipReason.notConfigured;
      devPrint('warmUp failed: $e', tag: 'Attestation');
    }
    return this;
  }

  /// URL-safe base64 SHA-256 over method, path and body. The server must hash
  /// identically. Streamed and multipart bodies are hashed as method+path only.
  static String hashFor(String method, String path, [Object? body]) {
    final payload = StringBuffer()
      ..write(method.toUpperCase())
      ..write('\n')
      ..write(path);
    final encoded = _encodeBody(body);
    if (encoded != null) payload.write('\n$encoded');
    // URL-safe: Play Integrity's requestHash and HTTP headers both dislike '+/'.
    return base64Url.encode(
      sha256.convert(utf8.encode(payload.toString())).bytes,
    );
  }

  static String? _encodeBody(Object? body) {
    if (body == null) return null;
    if (body is String) return body;
    if (body is Map || body is List) {
      try {
        return jsonEncode(body);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Returns a token bound to [requestHash], or null when one cannot be had.
  /// Deduplicates concurrent calls and refuses to exceed [minInterval].
  Future<AttestationToken?> tokenFor(String requestHash) async {
    if (!_warm) return null;

    final cached = _cached;
    if (cached != null &&
        cached.requestHash == requestHash &&
        cached.isFresh(tokenTtl)) {
      return cached;
    }

    final blockedUntil = _blockedUntil;
    if (blockedUntil != null && DateTime.now().isBefore(blockedUntil)) {
      _lastSkip = AttestationSkipReason.backoff;
      return null;
    }

    final pending = _inFlight;
    if (pending != null) return pending.future;

    final last = _lastCallAt;
    if (last != null && DateTime.now().difference(last) < minInterval) {
      // Too soon for a fresh native call — reuse a still-valid token or skip.
      if (cached != null && cached.isFresh(tokenTtl)) return cached;
      _lastSkip = AttestationSkipReason.backoff;
      return null;
    }

    final completer = Completer<AttestationToken?>();
    _inFlight = completer;
    AttestationToken? token;
    try {
      token = await _request(requestHash);
    } finally {
      _inFlight = null;
      if (!completer.isCompleted) completer.complete(token);
    }
    return token;
  }

  Future<AttestationToken?> _request(String requestHash) async {
    _lastCallAt = DateTime.now();
    try {
      final raw = await channel.invokeMapMethod<String, dynamic>('getToken', {
        'requestHash': requestHash,
        'keyId': _keyId,
      });
      final token = raw?['token'] as String?;
      if (token == null || token.isEmpty) {
        return _fail(AttestationSkipReason.platformError, 'empty token');
      }

      final result = AttestationToken(
        kind: _kindFrom(raw?['kind'] as String?),
        token: token,
        keyId: raw?['keyId'] as String? ?? _keyId,
        requestHash: requestHash,
        issuedAt: DateTime.now(),
      );
      _cached = result;
      _failures = 0;
      _blockedUntil = null;
      _lastSkip = null;
      return result;
    } on MissingPluginException {
      _warm = false;
      return _fail(AttestationSkipReason.notConfigured, 'plugin missing');
    } on PlatformException catch (e) {
      return _fail(
        AttestationSkipReason.platformError,
        '${e.code}: ${e.message}',
      );
    } catch (e) {
      return _fail(AttestationSkipReason.platformError, '$e');
    }
  }

  AttestationToken? _fail(AttestationSkipReason reason, String detail) {
    _failures++;
    _lastSkip = reason;
    final backoffMs = baseBackoff.inMilliseconds * (1 << (_failures - 1));
    final capped = backoffMs > maxBackoff.inMilliseconds
        ? maxBackoff
        : Duration(milliseconds: backoffMs);
    _blockedUntil = DateTime.now().add(capped);
    devPrint(
      'no token ($detail) — backing off ${capped.inSeconds}s',
      tag: 'Attestation',
    );
    return null;
  }

  AttestationKind _kindFrom(String? raw) {
    return AttestationKind.values.firstWhere(
      (k) => k.name == raw,
      orElse: () => Platform.isAndroid
          ? AttestationKind.playIntegrity
          : AttestationKind.appAttestAssertion,
    );
  }

  /// iOS only, once per install: generates an App Attest key and attests it.
  /// POST the result to your backend, which verifies it with Apple and stores
  /// the public key against [keyId]. Assertions are worthless without this step.
  ///
  /// [challenge] must come from your server, single-use.
  Future<AttestationKeyRegistration?> registerKey(String challenge) async {
    if (!Platform.isIOS || !_warm) return null;
    try {
      final challengeHash = base64Url.encode(
        sha256.convert(utf8.encode(challenge)).bytes,
      );
      // Native hashes the raw challenge; the server recomputes SHA-256 the same way.
      final raw = await channel.invokeMapMethod<String, dynamic>('attestKey', {
        'challenge': challenge,
      });
      final id = raw?['keyId'] as String?;
      final object = raw?['attestationObject'] as String?;
      if (id == null || object == null) return null;

      _keyId = id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyIdPrefKey, id);

      return AttestationKeyRegistration(
        keyId: id,
        attestationObject: object,
        challengeHash: challengeHash,
      );
    } catch (e) {
      devPrint('registerKey failed: $e', tag: 'Attestation');
      return null;
    }
  }

  /// Drops the cached token. Call after sign-out or when the server rejects one.
  void invalidate() {
    _cached = null;
    _blockedUntil = null;
    _failures = 0;
  }

  /// Forgets the App Attest key id so the next [registerKey] starts clean.
  Future<void> resetKey() async {
    _keyId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyIdPrefKey);
  }
}
