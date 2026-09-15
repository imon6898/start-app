// Provider-agnostic CAPTCHA hook.
// The client only FETCHES a token. It means nothing until your backend posts it
// to the provider's siteverify endpoint; a client-side "pass" proves nothing.

import 'package:get/get.dart';

import 'package:flutter_starter/app/core/config/env.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:flutter_starter/app/widgets/feedback/captcha_challenge_sheet.dart';

/// Token to attach to a signup/login request for the backend to verify.
class CaptchaToken {
  const CaptchaToken({
    required this.value,
    required this.provider,
    required this.action,
  });

  final String value;
  final String provider;
  final String action;

  /// Merge into a request body.
  Map<String, dynamic> toParams() => {
    'captcha_token': value,
    'captcha_provider': provider,
    'captcha_action': action,
  };

  /// Or send as headers, if that is what your backend reads.
  Map<String, String> toHeaders() => {
    'X-Captcha-Token': value,
    'X-Captcha-Provider': provider,
  };
}

/// Swap the registered implementation to change provider; callers see only this.
abstract class CaptchaService extends GetxService {
  static CaptchaService get to => Get.find<CaptchaService>();

  String get provider;

  /// False when the site key is missing — decide whether to block or proceed.
  bool get isConfigured;

  /// Null means no token was obtained (cancelled, errored, timed out, disabled).
  Future<CaptchaToken?> getToken({required String action});
}

/// No-op implementation for dev builds or backends that do not require a token.
class NoCaptchaService extends CaptchaService {
  @override
  String get provider => 'none';

  @override
  bool get isConfigured => false;

  @override
  Future<CaptchaToken?> getToken({required String action}) async => null;
}

/// Cloudflare Turnstile via a WebView challenge (no first-party Flutter plugin).
class TurnstileCaptchaService extends CaptchaService {
  TurnstileCaptchaService({
    String? siteKey,
    String? challengeUrl,
    String? hostOrigin,
    this.timeout = const Duration(seconds: 45),
  }) : siteKey = siteKey ?? Env.optional('TURNSTILE_SITE_KEY'),
       challengeUrl = challengeUrl ?? Env.optional('TURNSTILE_CHALLENGE_URL'),
       hostOrigin =
           hostOrigin ??
           Env.optional('TURNSTILE_HOST', fallback: 'https://localhost');

  final String siteKey;

  /// Page you host yourself; empty means the inline HTML is used instead.
  final String challengeUrl;

  /// Origin the inline HTML claims — allow-list it on the Turnstile widget.
  final String hostOrigin;
  final Duration timeout;

  @override
  String get provider => 'turnstile';

  @override
  bool get isConfigured => siteKey.isNotEmpty;

  @override
  Future<CaptchaToken?> getToken({required String action}) async {
    if (!isConfigured) {
      devPrint('TURNSTILE_SITE_KEY is not set — no token', tag: 'Captcha');
      return null;
    }

    final String? token = await showCaptchaChallenge(
      siteKey: siteKey,
      action: action,
      challengeUrl: challengeUrl.isEmpty ? null : challengeUrl,
      hostOrigin: hostOrigin,
      timeout: timeout,
    );
    if (token == null || token.isEmpty) return null;

    return CaptchaToken(value: token, provider: provider, action: action);
  }
}
