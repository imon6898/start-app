// WebView-hosted Cloudflare Turnstile challenge.
// Returns the token, or null when the user cancels, it errors, or it times out.
// The token proves nothing until the BACKEND verifies it with siteverify.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:flutter_starter/app/widgets/feedback/thinking_dots.dart';
import 'package:flutter_starter/app/widgets/layout/custom_bottom_sheet.dart';

// Name of the JS -> Dart bridge injected into the challenge page.
const String _bridgeName = 'CaptchaBridge';

/// Opens the challenge sheet and completes with the Turnstile token or null.
Future<String?> showCaptchaChallenge({
  required String siteKey,
  required String action,
  String? challengeUrl,
  String hostOrigin = 'https://localhost',
  Duration timeout = const Duration(seconds: 45),
}) {
  return showCustomBottomSheet<String>(
    sheetTitle: 'Security check'.tr,
    height: R.h(360),
    content: CaptchaChallengeView(
      siteKey: siteKey,
      action: action,
      challengeUrl: challengeUrl,
      hostOrigin: hostOrigin,
      timeout: timeout,
    ),
  );
}

/// Stateful because it owns a WebViewController lifecycle.
class CaptchaChallengeView extends StatefulWidget {
  const CaptchaChallengeView({
    super.key,
    required this.siteKey,
    required this.action,
    this.challengeUrl,
    this.hostOrigin = 'https://localhost',
    this.timeout = const Duration(seconds: 45),
  });

  final String siteKey;
  final String action;

  /// Page you host yourself; when null the HTML below is loaded inline.
  final String? challengeUrl;

  /// Origin the inline HTML claims — must be allow-listed on the Turnstile widget.
  final String hostOrigin;
  final Duration timeout;

  @override
  State<CaptchaChallengeView> createState() => _CaptchaChallengeViewState();
}

class _CaptchaChallengeViewState extends State<CaptchaChallengeView> {
  late final WebViewController _webView;
  Timer? _timeout;
  bool _finished = false;
  bool _interactive = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(widget.timeout, () => _finish(null, 'timeout'));
    _webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(CustomColors.transparent())
      ..addJavaScriptChannel(_bridgeName, onMessageReceived: _onMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) =>
              _showError(error.description),
        ),
      );
    _load();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _load() {
    final String? url = widget.challengeUrl;
    if (url != null && url.isNotEmpty) {
      _webView.loadRequest(Uri.parse(url));
    } else {
      _webView.loadHtmlString(_html(), baseUrl: widget.hostOrigin);
    }
  }

  void _onMessage(JavaScriptMessage message) {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (e) {
      devPrint('bad bridge payload: ${message.message} ($e)', tag: 'Captcha');
      return;
    }

    final String type = payload['type']?.toString() ?? '';
    final String data = payload['data']?.toString() ?? '';

    if (type == 'token' && data.isNotEmpty) {
      _finish(data, 'solved');
    } else if (type == 'interactive') {
      if (mounted) setState(() => _interactive = true);
    } else if (type == 'error' || type == 'expired') {
      _showError(data.isEmpty ? type : data);
    }
  }

  void _showError(String reason) {
    devPrint('challenge failed: $reason', tag: 'Captcha');
    if (!mounted) return;
    setState(() => _error = reason);
  }

  void _retry() {
    setState(() {
      _error = null;
      _interactive = false;
    });
    _load();
  }

  // Pops the sheet once; later callbacks are ignored.
  void _finish(String? token, String reason) {
    if (_finished || !mounted) return;
    _finished = true;
    _timeout?.cancel();
    devPrint('challenge $reason', tag: 'Captcha');
    Get.back<String>(result: token);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: R.pad(horizontal: 20, bottom: 20),
      child: Column(
        children: [
          _buildHeader(context),
          SizedBox(height: R.h(12)),
          Expanded(
            child: _error != null
                ? _buildError(context)
                : _buildChallenge(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          LucideIcons.shieldCheck,
          size: R.h(18),
          color: CustomColors.primary(),
        ),
        SizedBox(width: R.w(8)),
        Expanded(
          child: Text(
            'Confirming you are not a bot'.tr,
            style: CustomTextStyles.medium14.copyWith(
              color: CustomColors.textGray(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChallenge(BuildContext context) {
    // Turnstile must stay laid out and painted, so hide it with opacity only.
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: _interactive ? 1 : 0,
          child: WebViewWidget(controller: _webView),
        ),
        if (!_interactive) ThinkingDots(title: 'Checking your device'.tr),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          LucideIcons.shieldAlert,
          size: R.h(32),
          color: CustomColors.error(),
        ),
        SizedBox(height: R.h(12)),
        Text(
          'Verification could not be completed'.tr,
          textAlign: TextAlign.center,
          style: CustomTextStyles.medium16.copyWith(
            color: CustomColors.black(),
          ),
        ),
        SizedBox(height: R.h(16)),
        CustomButton(
          text: 'Try again'.tr,
          onPressed: _retry,
          icon: Icon(
            LucideIcons.refreshCw,
            size: R.h(16),
            color: CustomColors.onAccent(),
          ),
        ),
      ],
    );
  }

  // Written against Cloudflare's documented explicit-render Turnstile API.
  String _html() {
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<style>
  html, body { margin: 0; padding: 0; height: 100%; background: transparent; }
  #wrap { display: flex; align-items: center; justify-content: center; height: 100%; }
</style>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onTurnstileLoad&render=explicit" async defer></script>
</head>
<body>
<div id="wrap"><div id="cf"></div></div>
<script>
  function post(type, data) {
    $_bridgeName.postMessage(JSON.stringify({ type: type, data: data || '' }));
  }
  function onTurnstileLoad() {
    turnstile.render('#cf', {
      sitekey: '${widget.siteKey}',
      action: '${widget.action}',
      appearance: 'interaction-only',
      callback: function (token) { post('token', token); },
      'before-interactive-callback': function () { post('interactive'); },
      'error-callback': function (code) { post('error', String(code)); },
      'expired-callback': function () { post('expired'); }
    });
  }
  window.onerror = function (message) { post('error', String(message)); };
</script>
</body>
</html>
''';
  }
}
