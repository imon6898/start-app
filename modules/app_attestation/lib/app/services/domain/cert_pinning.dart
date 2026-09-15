// SSL public-key (SPKI) pinning for the Dio HttpClientAdapter.
//
// DANGER: a pin that stops matching BRICKS every installed client — the app
// cannot reach the server at all, and you cannot ship a fix through an API it
// can no longer call. Read the rotation rules in the module README before you
// enable this. Always configure at least one backup pin and a kill switch.
//
// This replaces the `badCertificateCallback => kDebugMode` pattern in
// api_service.dart, which disables certificate validation outright.
//   CertPinning.configure(hosts: {...}, pins: {...});
//   _dio.httpClientAdapter = CertPinning.adapter();

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/io.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_tools.dart';

class CertPinning {
  CertPinning._();

  /// Survives restarts so a disabled pin set stays disabled.
  static const String killSwitchPrefKey = 'cert_pinning_disabled';

  static Set<String> _pins = const {};
  static Set<String> _hosts = const {};
  static String? _trustAnchorsPem;
  static bool _enabled = false;

  /// True when pinning is armed. False means every connection uses normal
  /// system trust only — still safe, just unpinned.
  static bool get isEnabled => _enabled && _pins.isNotEmpty;

  /// Hosts currently in scope. Anything else is never pinned.
  static Set<String> get pinnedHosts => _hosts;

  /// [pins] are base64 SHA-256 SPKI hashes (see the README openssl command).
  /// [hosts] limits pinning to your own API hosts — never pin a third party.
  /// [trustAnchorsPem] optionally replaces the system trust store with your own
  /// intermediate/root CA, which is how you pin a CA rather than a leaf key.
  static void configure({
    required Iterable<String> pins,
    required Iterable<String> hosts,
    bool enabled = true,
    String? trustAnchorsPem,
  }) {
    _pins = pins.where((p) => p.trim().isNotEmpty).toSet();
    _hosts = hosts.where((h) => h.trim().isNotEmpty).toSet();
    _trustAnchorsPem = trustAnchorsPem;
    _enabled = enabled;
    if (_enabled && _pins.length < 2) {
      devPrint(
        'only ${_pins.length} pin configured — add a backup key',
        tag: 'CertPinning',
      );
    }
  }

  /// Reads the persisted kill switch. Await in bootstrap right after [configure].
  static Future<void> restoreKillSwitch() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(killSwitchPrefKey) == true) {
      _enabled = false;
      devPrint('disabled by persisted kill switch', tag: 'CertPinning');
    }
  }

  /// The escape hatch. Fetch the flag from a host you do NOT pin, or a bad pin
  /// also blocks the request that would have turned pinning off.
  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(killSwitchPrefKey, !value);
  }

  /// Adapter for `_dio.httpClientAdapter`. No badCertificateCallback: an
  /// untrusted chain must fail the connection, in debug builds too.
  static IOHttpClientAdapter adapter() => IOHttpClientAdapter(
    createHttpClient: _createHttpClient,
    validateCertificate: validateCertificate,
  );

  static HttpClient _createHttpClient() {
    final pem = _trustAnchorsPem;
    if (pem == null || pem.trim().isEmpty) return HttpClient();
    final context = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificatesBytes(utf8.encode(pem));
    return HttpClient(context: context);
  }

  /// Dio calls this with the LEAF certificate only, after normal chain
  /// validation has already passed. Dart never exposes the full peer chain, so
  /// pin the leaf key here and pin the CA via [trustAnchorsPem] instead.
  static bool validateCertificate(
    X509Certificate? certificate,
    String host,
    int port,
  ) {
    if (!isEnabled) return true;
    if (_hosts.isNotEmpty && !_hosts.contains(host)) return true;

    if (certificate == null) {
      devPrint('no leaf certificate for $host', tag: 'CertPinning');
      return false;
    }

    final pin = spkiSha256(certificate.der);
    if (pin == null) {
      devPrint('could not read SPKI for $host', tag: 'CertPinning');
      return false;
    }
    if (_pins.contains(pin)) return true;

    devPrint('PIN MISMATCH $host got $pin', tag: 'CertPinning');
    return false;
  }

  /// Base64 SHA-256 of the certificate's SubjectPublicKeyInfo — the same value
  /// the openssl pipeline in the README prints. Null if the DER will not parse.
  static String? spkiSha256(Uint8List der) {
    try {
      final certificate = _readTlv(der, 0);
      final tbs = _readTlv(der, certificate.contentStart);
      var p = tbs.contentStart;

      // Optional [0] EXPLICIT version.
      if (p < der.length && der[p] == 0xA0) p = _readTlv(der, p).end;

      // serialNumber, signature, issuer, validity, subject — then SPKI.
      for (var i = 0; i < 5; i++) {
        p = _readTlv(der, p).end;
      }
      final spki = _readTlv(der, p);
      final bytes = Uint8List.sublistView(der, p, spki.end);
      return base64.encode(sha256.convert(bytes).bytes);
    } catch (e) {
      devPrint('SPKI parse failed: $e', tag: 'CertPinning');
      return null;
    }
  }

  // Minimal DER reader: X.509 uses definite lengths and low tag numbers only.
  static _Tlv _readTlv(Uint8List d, int start) {
    var i = start;
    if (i + 1 >= d.length) throw const FormatException('truncated TLV');
    i++; // tag
    var len = d[i++];
    if (len & 0x80 != 0) {
      final count = len & 0x7f;
      if (count == 0 || count > 4) throw const FormatException('bad length');
      len = 0;
      for (var k = 0; k < count; k++) {
        if (i >= d.length) throw const FormatException('truncated length');
        len = (len << 8) | d[i++];
      }
    }
    final end = i + len;
    if (end > d.length) throw const FormatException('length overruns buffer');
    return _Tlv(i, end);
  }
}

class _Tlv {
  final int contentStart;
  final int end;
  const _Tlv(this.contentStart, this.end);
}
