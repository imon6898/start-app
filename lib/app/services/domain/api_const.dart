import '../../core/config/app_flavor.dart';
import '../../core/config/env.dart';

/// Backend hosts and endpoint paths. Hosts come from [Env]; paths are declared
/// here so a URL is never typed twice.
class ApiConstant {
  // Hosts (see .env)
  static String get baseUrl => Env.baseUrl;
  static String get devBaseUrl => Env.devBaseUrl;
  static String get imageUrl => Env.imageUrl;
  static String get socketUrl => Env.socketUrl;
  static String get socketUrlDev => Env.socketUrlDev;

  /// Optional second backend, selected via `ApiService(secondaryBaseUrl: true)`.
  static String get secondaryBaseUrl => Env.optional('SECONDARY_BASE_URL');
  static String get devSecondaryBaseUrl =>
      Env.optional('DEV_SECONDARY_BASE_URL');

  /// Host for the current flavor — only prod talks to the production backend.
  static String get activeBaseUrl => AppFlavor.isProd ? baseUrl : devBaseUrl;
  static String get activeSocketUrl =>
      AppFlavor.isProd ? socketUrl : socketUrlDev;
  static String get activeSecondaryBaseUrl =>
      AppFlavor.isProd ? secondaryBaseUrl : devSecondaryBaseUrl;

  /// Google Maps / Places key, read by the opt-in `location_picker` module.
  static String get gapikey => Env.googleMapsApiKey;
  static const String googleBaseUrl = 'https://maps.googleapis.com';

  // ── Service prefixes ──
  /// Path segment the auth service is mounted under.
  static const String acc = '/acc';

  // ── Auth endpoints ──
  static const String loginUri = '$acc/auth/login';
  static const String signupUserUri = '$acc/auth/signup';
  static const String refreshTokenUri = '$acc/auth/refresh';
  static const String sentOtpUri = '$acc/auth/otp/send';
  static const String reSentOtpUri = '$acc/auth/otp/resend';
  static const String verifyOtpUri = '$acc/auth/otp/verify';
  static const String resetPasswordUri = '$acc/auth/password/reset';
  static const String googleSignInUri = '$acc/auth/google';
  static const String appleSignInUri = '$acc/auth/apple';
}
