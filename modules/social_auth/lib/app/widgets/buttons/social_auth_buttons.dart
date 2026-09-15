import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Google sign-in button.
///
/// The glyph is `LucideIcons.globe`, NOT the Google "G". Google's branding
/// rules require their own mark on a real sign-in button — see the README.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool loading;
  final bool enabled;
  final String label;
  final double height;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.label = 'Continue with Google',
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return _SocialAuthButton(
      icon: LucideIcons.globe,
      label: label,
      loading: loading,
      enabled: enabled,
      height: height,
      background: CustomColors.white(),
      foreground: CustomColors.black(),
      borderColor: CustomColors.whiteStroke(),
      onPressed: onPressed,
    );
  }
}

/// Apple sign-in button, black-on-white per Apple's preferred style.
///
/// `LucideIcons.apple` is a lookalike, not Apple's mark. For production use
/// `SignInWithAppleButton` from the `sign_in_with_apple` package — see the README.
class AppleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool loading;
  final bool enabled;
  final String label;
  final double height;

  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.label = 'Continue with Apple',
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return _SocialAuthButton(
      icon: LucideIcons.apple,
      label: label,
      loading: loading,
      enabled: enabled,
      height: height,
      background: CustomColors.black(),
      foreground: CustomColors.white(),
      borderColor: CustomColors.black(),
      onPressed: onPressed,
    );
  }
}

/// Both buttons stacked, with Apple hidden where it cannot run.
///
/// Wrap in `Obx` at the call site — this widget takes plain bools.
class SocialAuthButtons extends StatelessWidget {
  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;
  final bool googleLoading;
  final bool appleLoading;
  final bool enabled;
  final double spacing;

  /// Defaults to Apple platforms only. Pass `true` on Android/web once the
  /// Services ID + redirect URI are configured.
  final bool? showApple;

  const SocialAuthButtons({
    super.key,
    required this.onGooglePressed,
    required this.onApplePressed,
    this.googleLoading = false,
    this.appleLoading = false,
    this.enabled = true,
    this.spacing = 12,
    this.showApple,
  });

  bool get _showApple =>
      showApple ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS));

  @override
  Widget build(BuildContext context) {
    final bool busy = googleLoading || appleLoading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GoogleSignInButton(
          onPressed: onGooglePressed,
          loading: googleLoading,
          enabled: enabled && !busy,
        ),
        if (_showApple) ...[
          SizedBox(height: R.h(spacing)),
          AppleSignInButton(
            onPressed: onApplePressed,
            loading: appleLoading,
            enabled: enabled && !busy,
          ),
        ],
      ],
    );
  }
}

/// Shared shell: core [CustomOutlinedButton] with a tinted spinner in the icon
/// slot (the built-in one is always white, invisible on a light button).
class _SocialAuthButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final bool enabled;
  final double height;
  final Color background;
  final Color foreground;
  final Color borderColor;
  final VoidCallback onPressed;

  const _SocialAuthButton({
    required this.icon,
    required this.label,
    required this.loading,
    required this.enabled,
    required this.height,
    required this.background,
    required this.foreground,
    required this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = !enabled || loading;

    return SizedBox(
      width: double.infinity,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: CustomOutlinedButton(
          text: label.tr,
          height: height,
          textStyle: CustomTextStyles.medium14,
          textColor: foreground,
          backgroundColor: background,
          borderColor: borderColor,
          onPressed: isDisabled
              ? () {}
              : () {
                  FocusScope.of(context).unfocus();
                  onPressed();
                },
          icon: loading
              ? SizedBox(
                  width: R.w(18),
                  height: R.w(18),
                  child: CupertinoActivityIndicator(
                    radius: 8,
                    color: foreground,
                  ),
                )
              : Icon(icon, size: R.h(20), color: foreground),
        ),
      ),
    );
  }
}
