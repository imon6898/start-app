import '../platform_utils.dart';

/// Bundled asset paths. Every entry must also be listed under `assets:` in pubspec.yaml.
class ImageUtils {
  const ImageUtils._();

  /// Shown on the splash screen — swap in your own mark.
  static const String appLogo = 'assets/images/app_logo.svg';

  /// Source image for launcher icons (e.g. flutter_launcher_icons).
  static const String appIcon = 'assets/icon/app_icon.png';

  static const String backIos = 'assets/icons/back_ios.svg';
  static const String backAndroid = 'assets/icons/back_android.svg';

  /// Back affordance matching the host platform's convention.
  static String get platformBackIcon =>
      PlatformUtils.isIOS ? backIos : backAndroid;
}
