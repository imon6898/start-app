/// Endpoints this module adds, in [ApiConstant]'s style but kept separate so
/// installing the module needs no edit to the core api_const.dart.
///
/// Both paths point at YOUR backend. The app never talks to Google's or
/// Apple's token endpoints directly — the backend does the verification.
class SocialAuthApiConst {
  /// Path segment the auth service is mounted under — mirrors ApiConstant.acc.
  static const String acc = '/acc';

  // ── Social sign-in endpoints ──
  /// POST — backend verifies the Google id_token, then issues a session.
  static const String googleSignInUri = '$acc/auth/google';

  /// POST — backend verifies the Apple authorization_code, then issues a session.
  static const String appleSignInUri = '$acc/auth/apple';
}
