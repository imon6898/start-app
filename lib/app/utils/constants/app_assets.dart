import "../platform_utils.dart";

/// Bundled asset paths. Every entry here must also be listed under `assets:`
/// in pubspec.yaml.
class ImageUtils {
  const ImageUtils._();

  /// Shown on the splash screen — swap in your own mark.
  static const String appLogo = "assets/images/app_logo.svg";

  static const String backIos = "assets/icons/back_ios.svg";
  static const String backAndroid = "assets/icons/back_android.svg";

  /// Back affordance matching the host platform's convention.
  static String get platformBackIcon =>
      PlatformUtils.isIOS ? backIos : backAndroid;

  /// The bundled font family, named here so styles resolve it from one place.
  static const String interFontFamily = "Inter";
}
