import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvException implements Exception {
  final String message;
  const EnvException(this.message);

  @override
  String toString() => 'EnvException: $message';
}

/// Typed reader over `.env`. Required keys throw at startup instead of leaking
/// an empty string into a base URL and failing as a confusing 404 later.
class Env {
  /// Keys [load] refuses to boot without. Add yours here, not in the getters.
  static const List<String> requiredKeys = ['BASE_URL', 'DEV_BASE_URL'];

  /// Reads `.env` (the dotenv default) and aborts on a missing required key.
  static Future<void> load() async {
    try {
      await dotenv.load();
    } catch (_) {
      throw const EnvException(
        'Missing .env at the project root. Copy .env.example to .env, then '
        'confirm `assets: - .env` is listed in pubspec.yaml.',
      );
    }

    final missing = requiredKeys.where((k) => _raw(k).isEmpty).toList();
    if (missing.isNotEmpty) {
      throw EnvException('.env is missing: ${missing.join(', ')}');
    }
  }

  // Hosts
  static String get baseUrl => _required('BASE_URL');
  static String get devBaseUrl => _required('DEV_BASE_URL');
  static String get socketUrl => optional('SOCKET_URL');
  static String get socketUrlDev => optional('SOCKET_URL_DEV');
  static String get imageUrl => optional('IMAGE_URL');

  // Third-party keys
  static String get googleMapsApiKey =>
      optional('GOOGLE_MAPS_API_KEY_ALL_IN_ONE');
  static String get stripePublishableKey => optional('STRIPE_PUBLISHABLE_KEY');

  /// Escape hatch for keys an opt-in module adds to `.env`.
  static String optional(String key, {String fallback = ''}) {
    final value = _raw(key);
    return value.isEmpty ? fallback : value;
  }

  static String _required(String key) {
    final value = _raw(key);
    if (value.isEmpty) {
      throw EnvException('$key is not set in .env');
    }
    return value;
  }

  static String _raw(String key) => (dotenv.env[key] ?? '').trim();
}
