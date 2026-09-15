/// Endpoints this module adds, in [ApiConstant]'s style but kept separate so
/// installing the module needs no edit to the core api_const.dart.
///
/// Both paths are relative to `ApiService`'s base URL — they hit YOUR backend,
/// which is where the FCM server key lives.
class PushApiConst {
  /// Path segment the notification service is mounted under.
  static const String notify = '/notify';

  // ── Device token endpoints ──
  /// POST — stores the FCM token against the signed-in user.
  static const String registerDeviceUri = '$notify/devices/register';

  /// POST — drops the token on logout so this device stops receiving pushes.
  static const String unregisterDeviceUri = '$notify/devices/unregister';
}
