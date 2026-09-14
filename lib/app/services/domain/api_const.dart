import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Backend hosts and endpoint paths. Hosts come from `.env`; paths are declared
/// here so a URL is never typed twice.
class ApiConstant {
  // ── Hosts (see .env) ──
  static String get baseUrl => dotenv.get('BASE_URL', fallback: '');
  static String get devBaseUrl => dotenv.get('DEV_BASE_URL', fallback: '');
  static String get imageUrl => dotenv.get('IMAGE_URL', fallback: '');
  static String get socketUrl => dotenv.get('SOCKET_URL', fallback: '');
  static String get socketUrlDev => dotenv.get('SOCKET_URL_DEV', fallback: '');

  /// Optional second backend, selected via `ApiService(logisticsBaseUrl: true)`.
  static String get logisticsBaseUrl => dotenv.get('LOGISTICS_BASE_URL', fallback: '');
  static String get devLogisticsBaseUrl => dotenv.get('DEV_LOGISTICS_BASE_URL', fallback: '');

  /// Google Maps / Places key, read by the opt-in `location_picker` module.
  static String get gapikey => dotenv.get('GOOGLE_MAPS_API_KEY_ALL_IN_ONE', fallback: '');
  static const String googleBaseUrl = "https://maps.googleapis.com";

  // ── Service prefixes ──
  /// Path segment the auth service is mounted under.
  static const String acc = "/acc";

  // ── Auth endpoints ──
  static const String loginUri = "$acc/auth/login";
  static const String signupUserUri = "$acc/auth/signup";
  static const String refreshTokenUri = "$acc/auth/refresh";
  static const String sentOtpUri = "$acc/auth/otp/send";
  static const String reSentOtpUri = "$acc/auth/otp/resend";
  static const String verifyOtpUri = "$acc/auth/otp/verify";
  static const String resetPasswordUri = "$acc/auth/password/reset";
  static const String googleSignInUri = "$acc/auth/google";
  static const String appleSignInUri = "$acc/auth/apple";
}
