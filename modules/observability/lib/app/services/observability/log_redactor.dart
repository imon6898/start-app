// Every log message and field passes through here before any sink sees it.
// Keep the rules additive: a false redaction is cheap, a leaked token is not.

/// Strips credentials and contact details out of log text and fields.
class LogRedactor {
  LogRedactor._();

  /// Replacement marker; visible in the log so you know a value was dropped.
  static const String redacted = '[redacted]';

  /// Field keys redacted when a name *token* matches exactly. Tokenised on
  /// `_`, `-`, `.` and camelCase, so `pin` hits `user_pin` but not `spinner`.
  static const List<String> exactKeys = [
    'auth',
    'jwt',
    'pwd',
    'pin',
    'otp',
    'ssn',
    'cvv',
    'cvc',
    'iban',
    'card',
    'mail',
    'session',
    'signature',
    'address',
    'lat',
    'lng',
    'latitude',
    'longitude',
  ];

  /// Field keys redacted when the name *contains* the needle anywhere.
  static const List<String> substringKeys = [
    'token',
    'authorization',
    'authorisation',
    'password',
    'passwd',
    'secret',
    'credential',
    'bearer',
    'apikey',
    'api_key',
    'cookie',
    'email',
    'phone',
    'mobile',
    'msisdn',
  ];

  static final RegExp _bearer = RegExp(
    r'bearer\s+[\w\-._~+/=]+',
    caseSensitive: false,
  );
  static final RegExp _jwt = RegExp(r'eyJ[\w-]{4,}\.[\w-]+\.[\w-]*');
  static final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  // International form with separators; the leading + keeps dates out.
  static final RegExp _intlPhone = RegExp(r'\+\d[\d\s().-]{6,}\d');
  // Nine or more consecutive digits: phone numbers, card numbers, long ids.
  static final RegExp _longDigits = RegExp(r'\d{9,}');
  static final RegExp _camel = RegExp(r'([a-z0-9])([A-Z])');
  static final RegExp _separators = RegExp(r'[^a-z0-9]+');

  /// Redacts bearer tokens, JWTs, emails, phone-shaped input and digit runs.
  static String? scrubText(String? text) {
    if (text == null || text.isEmpty) return text;
    return text
        .replaceAll(_bearer, 'Bearer $redacted')
        .replaceAll(_jwt, redacted)
        .replaceAll(_email, redacted)
        .replaceAll(_intlPhone, redacted)
        .replaceAll(_longDigits, redacted);
  }

  /// True when a field name names something that must never be logged.
  static bool isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    if (substringKeys.any(lower.contains)) return true;
    return _tokenize(key).any(exactKeys.contains);
  }

  /// Redacts by key, then scrubs every remaining string value. Nested maps and
  /// lists are walked; `maxDepth` stops a cyclic structure from looping.
  static Map<String, Object?> scrubFields(
    Map<String, Object?> fields, {
    int maxDepth = 4,
  }) {
    final out = <String, Object?>{};
    fields.forEach((key, value) {
      out[key] = isSensitiveKey(key) ? redacted : _scrubValue(value, maxDepth);
    });
    return out;
  }

  static Object? _scrubValue(Object? value, int depth) {
    if (value is String) return scrubText(value);
    if (depth <= 0) return value is num || value is bool ? value : redacted;
    if (value is Map) {
      final out = <String, Object?>{};
      value.forEach((k, v) {
        final key = k.toString();
        out[key] = isSensitiveKey(key) ? redacted : _scrubValue(v, depth - 1);
      });
      return out;
    }
    if (value is Iterable) {
      return value.map((v) => _scrubValue(v, depth - 1)).toList();
    }
    return value;
  }

  static List<String> _tokenize(String key) => key
      .replaceAllMapped(_camel, (m) => '${m[1]}_${m[2]}')
      .toLowerCase()
      .split(_separators)
      .where((t) => t.isNotEmpty)
      .toList();
}
