import "../platform_utils.dart";

class ImageUtils {
  const ImageUtils._();

  // ── App identity ──────────────────────────────────────────────────────

  static const String appIcon = "assets/icon/app_icon.png";

  /// Neutral placeholder for a product/hero image that failed to load or was
  /// never supplied. Aliases [appIcon] — one bundled mark serves both roles
  /// rather than shipping a second near-identical PNG.
  static const String imagePlaceholder = appIcon;

  // ── Typography ────────────────────────────────────────────────────────
  /// The bundled font family. Declared here so `CustomTextStyles` and any
  /// ad-hoc `TextStyle` name it from one place.
  static const String interFontFamily = "Inter";

  // ── Platform-specific ─────────────────────────────────────────────────
  /// Kept for parity with the merchant app's platform-aware asset lookups. The
  /// shopper app draws its back affordance from the Phosphor icon font rather
  /// than an SVG pair, so this reports the platform rather than a file — use it
  /// to pick the right *glyph*.
  static bool get usesIosBackChevron => PlatformUtils.isIOS;
}
