// Value types for one attestation attempt. The token is opaque to the app —
// only your backend can verify it with Google Play Integrity / Apple App Attest.

/// Which native API produced the token. The backend needs this to pick a verifier.
enum AttestationKind {
  /// Android, Play Integrity standard request. Verify server-side with Google.
  playIntegrity,

  /// iOS, App Attest assertion. Verify against the key registered by [attestKey].
  appAttestAssertion,

  /// iOS fallback when App Attest is unavailable. Verify with Apple's DeviceCheck API.
  deviceCheck,
}

/// Why no token was produced. Sent as a header so the backend can log the reason.
enum AttestationSkipReason {
  /// Not Android or iOS, or the OS is too old.
  unsupportedPlatform,

  /// Native side is not wired up or the plugin is missing.
  notConfigured,

  /// Last call failed; the service is in backoff and refuses to hammer the API.
  backoff,

  /// The platform API returned an error (Play Services missing, quota, offline).
  platformError,
}

/// A token plus everything the backend needs to verify it.
class AttestationToken {
  final AttestationKind kind;
  final String token;

  /// iOS App Attest key id. Null on Android and for DeviceCheck.
  final String? keyId;

  /// Base64 SHA-256 the token is bound to. The backend must recompute it.
  final String requestHash;

  final DateTime issuedAt;

  const AttestationToken({
    required this.kind,
    required this.token,
    required this.requestHash,
    required this.issuedAt,
    this.keyId,
  });

  bool isFresh(Duration ttl) => DateTime.now().difference(issuedAt) < ttl;

  /// Headers the interceptor attaches. Match these names on the server.
  Map<String, String> toHeaders() => {
    headerKind: kind.name,
    headerToken: token,
    headerRequestHash: requestHash,
    headerKeyId: ?keyId,
  };

  static const String headerKind = 'X-Attestation-Kind';
  static const String headerToken = 'X-Attestation-Token';
  static const String headerKeyId = 'X-Attestation-Key-Id';
  static const String headerRequestHash = 'X-Attestation-Request-Hash';

  /// Sent instead of a token so the server can distinguish "no token" from "old client".
  static const String headerSkipped = 'X-Attestation-Skipped';
}

/// One-time App Attest registration payload. POST it to your backend once.
class AttestationKeyRegistration {
  final String keyId;

  /// Base64 CBOR attestation object. Apple verifies it, not you.
  final String attestationObject;

  /// Base64 SHA-256 of the challenge your server issued.
  final String challengeHash;

  const AttestationKeyRegistration({
    required this.keyId,
    required this.attestationObject,
    required this.challengeHash,
  });

  Map<String, dynamic> toJson() => {
    'key_id': keyId,
    'attestation_object': attestationObject,
    'challenge_hash': challengeHash,
  };
}
