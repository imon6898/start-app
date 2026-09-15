import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_starter/app/core/config/env.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Which provider produced a [SocialAuthResult].
enum SocialAuthProvider { google, apple }

/// Outcome of one provider round-trip. `cancelled` is a normal user action.
enum SocialAuthStatus { success, cancelled, failed }

/// What the provider handed back on the device.
///
/// These are CLAIMS, not a session. Nothing here proves who the user is until
/// your backend has verified the token with Google / Apple.
class SocialAuthResult {
  final SocialAuthProvider provider;
  final SocialAuthStatus status;

  /// Google `id_token`, or the Apple `identityToken` JWT.
  final String? idToken;

  /// Google only — OAuth access token for Google APIs.
  final String? accessToken;

  /// Google only — one-time code the backend can exchange for a refresh token.
  final String? serverAuthCode;

  /// Apple only — code the backend redeems with Apple within 5 minutes.
  final String? authorizationCode;

  /// Apple only — the value embedded in the identity token, for replay defence.
  final String? nonce;

  /// Apple only — stable per-app user id. Apple platforms only, never Android.
  final String? userIdentifier;

  /// Apple sends the profile on the FIRST authorization only; store it server-side.
  final String? email;
  final String? name;
  final String? photoUrl;

  /// Failure reason, for logs and the snackbar.
  final String? message;

  const SocialAuthResult({
    required this.provider,
    required this.status,
    this.idToken,
    this.accessToken,
    this.serverAuthCode,
    this.authorizationCode,
    this.nonce,
    this.userIdentifier,
    this.email,
    this.name,
    this.photoUrl,
    this.message,
  });

  factory SocialAuthResult.cancelled(SocialAuthProvider provider) =>
      SocialAuthResult(provider: provider, status: SocialAuthStatus.cancelled);

  factory SocialAuthResult.failed(
    SocialAuthProvider provider,
    String message,
  ) => SocialAuthResult(
    provider: provider,
    status: SocialAuthStatus.failed,
    message: message,
  );

  bool get isSuccess => status == SocialAuthStatus.success;
  bool get isCancelled => status == SocialAuthStatus.cancelled;

  /// Request body for the backend endpoint. Empty values are dropped so the
  /// server sees only what the provider actually returned.
  Map<String, dynamic> toParams() {
    final params = <String, dynamic>{
      if (provider == SocialAuthProvider.google) ...<String, dynamic>{
        'id_token': idToken,
        'access_token': accessToken,
        'server_auth_code': serverAuthCode,
      } else ...<String, dynamic>{
        'identity_token': idToken,
        'authorization_code': authorizationCode,
        'nonce': nonce,
        'user_identifier': userIdentifier,
      },
      'email': email,
      'name': name,
    };
    params.removeWhere((_, value) => value == null || value == '');
    return params;
  }

  @override
  String toString() =>
      'SocialAuthResult($provider, $status, idToken set: ${idToken != null})';
}

/// Thin wrapper over `google_sign_in` and `sign_in_with_apple`.
///
/// It only collects a token. It never decides that the user is logged in —
/// hand [SocialAuthResult.toParams] to your backend and let it verify.
class SocialAuthService extends GetxService {
  static SocialAuthService get to => Get.find();

  /// Scopes requested from Google. Widen only if the backend needs more.
  static const List<String> googleScopes = <String>['email', 'profile'];

  GoogleSignIn? _google;

  bool get _isApplePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Built on first use, so an Apple-only app never reads the Google config.
  GoogleSignIn get google => _google ??= GoogleSignIn(
    scopes: googleScopes,
    // Android ignores this: it identifies the app by package + signing SHA-1.
    clientId: _isApplePlatform ? _env('GOOGLE_IOS_CLIENT_ID') : null,
    // Audience of the id_token the backend verifies. Required on Android.
    serverClientId: _env('GOOGLE_SERVER_CLIENT_ID'),
  );

  /// True when the native Apple sheet can run (iOS 13+, macOS 10.15+, Android, web).
  Future<bool> isAppleAvailable() async {
    try {
      return await SignInWithApple.isAvailable();
    } catch (e) {
      devPrint('Apple availability check failed: $e', tag: 'SocialAuth');
      return false;
    }
  }

  /// Opens the Google account picker and returns the token bundle.
  Future<SocialAuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await google.signIn();
      if (account == null) {
        return SocialAuthResult.cancelled(SocialAuthProvider.google);
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        return SocialAuthResult.failed(
          SocialAuthProvider.google,
          'Google returned no id_token — set GOOGLE_SERVER_CLIENT_ID in .env.',
        );
      }

      return SocialAuthResult(
        provider: SocialAuthProvider.google,
        status: SocialAuthStatus.success,
        idToken: idToken,
        accessToken: auth.accessToken,
        serverAuthCode: account.serverAuthCode,
        email: account.email,
        name: account.displayName,
        photoUrl: account.photoUrl,
      );
    } on PlatformException catch (e) {
      if (e.code == GoogleSignIn.kSignInCanceledError) {
        return SocialAuthResult.cancelled(SocialAuthProvider.google);
      }
      devPrint(
        'Google sign-in failed: ${e.code} ${e.message}',
        tag: 'SocialAuth',
      );
      return SocialAuthResult.failed(
        SocialAuthProvider.google,
        e.message ?? e.code,
      );
    } catch (e) {
      devPrint('Google sign-in failed: $e', tag: 'SocialAuth');
      return SocialAuthResult.failed(SocialAuthProvider.google, e.toString());
    }
  }

  /// Opens the Apple sheet. The nonce is echoed inside the identity token —
  /// the backend must compare the two before trusting it.
  Future<SocialAuthResult> signInWithApple({String? nonce}) async {
    final String requestNonce = nonce ?? generateNonce();
    final WebAuthenticationOptions? webOptions = _appleWebOptions;

    if (!_isApplePlatform && webOptions == null) {
      return SocialAuthResult.failed(
        SocialAuthProvider.apple,
        'Apple sign-in off Apple platforms needs APPLE_SERVICE_ID and '
        'APPLE_REDIRECT_URI in .env.',
      );
    }

    try {
      final AuthorizationCredentialAppleID credential =
          await SignInWithApple.getAppleIDCredential(
            scopes: const <AppleIDAuthorizationScopes>[
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
            nonce: requestNonce,
            webAuthenticationOptions: webOptions,
          );

      final String fullName = <String?>[
        credential.givenName,
        credential.familyName,
      ].whereType<String>().where((part) => part.isNotEmpty).join(' ');

      return SocialAuthResult(
        provider: SocialAuthProvider.apple,
        status: SocialAuthStatus.success,
        idToken: credential.identityToken,
        authorizationCode: credential.authorizationCode,
        nonce: requestNonce,
        userIdentifier: credential.userIdentifier,
        email: credential.email,
        name: fullName.isEmpty ? null : fullName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return SocialAuthResult.cancelled(SocialAuthProvider.apple);
      }
      devPrint(
        'Apple sign-in failed: ${e.code} ${e.message}',
        tag: 'SocialAuth',
      );
      return SocialAuthResult.failed(SocialAuthProvider.apple, e.message);
    } on SignInWithAppleException catch (e) {
      devPrint('Apple sign-in failed: $e', tag: 'SocialAuth');
      return SocialAuthResult.failed(SocialAuthProvider.apple, e.toString());
    } catch (e) {
      devPrint('Apple sign-in failed: $e', tag: 'SocialAuth');
      return SocialAuthResult.failed(SocialAuthProvider.apple, e.toString());
    }
  }

  /// Clears the cached Google account. Apple has no client-side sign-out — drop
  /// the session your backend issued instead.
  Future<void> signOut() async {
    try {
      await google.signOut();
    } catch (e) {
      devPrint('Google sign-out failed: $e', tag: 'SocialAuth');
    }
  }

  /// Revokes the Google grant, so the next sign-in re-asks for consent.
  Future<void> disconnectGoogle() async {
    try {
      await google.disconnect();
    } catch (e) {
      devPrint('Google disconnect failed: $e', tag: 'SocialAuth');
    }
  }

  /// Required on Android and web, ignored on Apple platforms.
  WebAuthenticationOptions? get _appleWebOptions {
    final String? clientId = _env('APPLE_SERVICE_ID');
    final String? redirectUri = _env('APPLE_REDIRECT_URI');
    if (clientId == null || redirectUri == null) return null;
    return WebAuthenticationOptions(
      clientId: clientId,
      redirectUri: Uri.parse(redirectUri),
    );
  }

  String? _env(String key) {
    final String value = Env.optional(key);
    return value.isEmpty ? null : value;
  }
}
