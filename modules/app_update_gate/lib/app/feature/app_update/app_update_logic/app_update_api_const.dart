/// Endpoint this module adds, in [ApiConstant]'s style but kept separate so
/// installing the module needs no edit to the core api_const.dart.
class AppUpdateApiConst {
  /// Path segment the app-meta service is mounted under.
  static const String app = '/app';

  // ── App update endpoints ──
  /// GET — returns the version gate for the calling platform.
  static const String versionGateUri = '$app/version';
}
