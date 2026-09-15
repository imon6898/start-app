// Face ID / Touch ID / fingerprint wrapper over local_auth. Every platform
// error code is normalised to one BiometricStatus with a user-facing message.

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:flutter_starter/app/utils/platform_utils.dart';

/// Normalised outcome of one local_auth call.
enum BiometricStatus {
  success,
  cancelled,
  failed,
  noHardware,
  notEnrolled,
  passcodeNotSet,
  lockedOut,
  permanentlyLockedOut,
  misconfigured,
  unsupportedPlatform,
  unknown,
}

/// What [BiometricService.authenticate] returns: a flag, a reason the UI can
/// switch on, and a message that is already fit to show.
class BiometricAuthResult {
  final bool success;
  final BiometricStatus status;
  final String message;

  const BiometricAuthResult({
    required this.success,
    required this.status,
    required this.message,
  });

  /// The device itself can no longer verify anyone — no biometrics, no screen
  /// lock, wrong host activity. Never keep a user locked out on one of these.
  bool get deviceCannotAuthenticate =>
      status == BiometricStatus.noHardware ||
      status == BiometricStatus.passcodeNotSet ||
      status == BiometricStatus.misconfigured ||
      status == BiometricStatus.unsupportedPlatform;

  /// Showing the prompt again can still succeed.
  bool get canRetry =>
      status == BiometricStatus.failed ||
      status == BiometricStatus.cancelled ||
      status == BiometricStatus.lockedOut ||
      status == BiometricStatus.permanentlyLockedOut ||
      status == BiometricStatus.notEnrolled ||
      status == BiometricStatus.unknown;
}

class BiometricService extends GetxService {
  static BiometricService get to => Get.find();

  final LocalAuthentication _auth = LocalAuthentication();

  List<BiometricType> _enrolled = const <BiometricType>[];

  /// Types seen by the last [availableBiometrics] call.
  List<BiometricType> get enrolledTypes => _enrolled;

  /// local_auth only ships Android, iOS, macOS and Windows implementations.
  bool get isPlatformSupported =>
      PlatformUtils.isMobile ||
      PlatformUtils.isMacOS ||
      PlatformUtils.isWindows;

  /// True when the device has biometric hardware the OS can drive.
  Future<bool> canCheckBiometrics() async {
    if (!isPlatformSupported) return false;
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      devPrint('$e', tag: 'Biometric');
      return false;
    }
  }

  /// True when biometrics **or** the device passcode can verify the user.
  Future<bool> canAuthenticate() async {
    if (!isPlatformSupported) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      devPrint('$e', tag: 'Biometric');
      return false;
    }
  }

  /// Enrolled biometric types; also refreshes the cache [biometricLabel] reads.
  Future<List<BiometricType>> availableBiometrics() async {
    if (!isPlatformSupported) return const <BiometricType>[];
    try {
      _enrolled = await _auth.getAvailableBiometrics();
    } catch (e) {
      devPrint('$e', tag: 'Biometric');
      _enrolled = const <BiometricType>[];
    }
    return _enrolled;
  }

  /// One call for "can this device lock the app, and how".
  Future<BiometricStatus> refreshCapability() async {
    if (!isPlatformSupported) return BiometricStatus.unsupportedPlatform;
    final bool deviceAuth = await canAuthenticate();
    final List<BiometricType> types = await availableBiometrics();
    if (types.isNotEmpty) return BiometricStatus.success;
    // No biometrics enrolled, but the passcode prompt still works.
    if (deviceAuth) return BiometricStatus.notEnrolled;
    return BiometricStatus.noHardware;
  }

  /// Name of what the OS will actually show the user.
  String get biometricLabel {
    if (_enrolled.contains(BiometricType.face)) {
      return PlatformUtils.isIOS ? 'Face ID'.tr : 'Face unlock'.tr;
    }
    if (_enrolled.contains(BiometricType.fingerprint)) {
      return PlatformUtils.isIOS ? 'Touch ID'.tr : 'Fingerprint'.tr;
    }
    if (_enrolled.contains(BiometricType.iris)) return 'Iris scan'.tr;
    if (_enrolled.isNotEmpty) return 'Biometrics'.tr;
    return 'Device passcode'.tr;
  }

  /// Prompts the user. Leave [biometricOnly] false so the OS offers the device
  /// passcode — that fallback is what keeps a broken sensor from locking
  /// someone out of their own app.
  Future<BiometricAuthResult> authenticate({
    required String reason,
    bool biometricOnly = false,
    bool stickyAuth = true,
  }) async {
    if (!isPlatformSupported) {
      return _result(BiometricStatus.unsupportedPlatform);
    }
    try {
      final bool ok = await _auth.authenticate(
        // local_auth asserts on an empty reason.
        localizedReason: reason.isEmpty ? 'Verify it is you'.tr : reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: stickyAuth,
          sensitiveTransaction: true,
        ),
      );
      if (ok) await availableBiometrics();
      return _result(ok ? BiometricStatus.success : BiometricStatus.failed);
    } on MissingPluginException catch (e) {
      devPrint('$e', tag: 'Biometric');
      return _result(BiometricStatus.unsupportedPlatform);
    } on PlatformException catch (e) {
      devPrint('${e.code}: ${e.message}', tag: 'Biometric');
      return _result(statusFromCode(e.code));
    } catch (e) {
      devPrint('$e', tag: 'Biometric');
      return _result(BiometricStatus.unknown);
    }
  }

  /// Dismisses a prompt that is still on screen. Not supported everywhere.
  Future<void> cancel() async {
    try {
      await _auth.stopAuthentication();
    } catch (e) {
      devPrint('$e', tag: 'Biometric');
    }
  }

  /// Codes verified against local_auth 2.3.0, local_auth_android 1.0.56 and
  /// local_auth_darwin 1.6.1.
  static BiometricStatus statusFromCode(String code) {
    switch (code) {
      case auth_error.notAvailable:
      case 'BiometricNotAvailable':
        return BiometricStatus.noHardware;
      case auth_error.notEnrolled:
        return BiometricStatus.notEnrolled;
      case auth_error.passcodeNotSet:
        return BiometricStatus.passcodeNotSet;
      case auth_error.lockedOut:
        return BiometricStatus.lockedOut;
      case auth_error.permanentlyLockedOut:
        return BiometricStatus.permanentlyLockedOut;
      case auth_error.otherOperatingSystem:
      case auth_error.biometricOnlyNotSupported:
        return BiometricStatus.unsupportedPlatform;
      case 'UserCancelled':
      case 'UserFallback':
        return BiometricStatus.cancelled;
      // Android host-app mistakes — see the README's Android section.
      case 'no_fragment_activity':
      case 'no_activity':
        return BiometricStatus.misconfigured;
      case 'auth_in_progress':
        return BiometricStatus.failed;
      default:
        return BiometricStatus.unknown;
    }
  }

  /// One clear sentence per status, shown to the user as-is.
  static String messageFor(BiometricStatus status) {
    switch (status) {
      case BiometricStatus.success:
        return 'Unlocked'.tr;
      case BiometricStatus.cancelled:
        return 'Authentication was cancelled'.tr;
      case BiometricStatus.failed:
        return 'We could not verify it is you. Try again'.tr;
      case BiometricStatus.noHardware:
        return 'This device cannot verify you — it has no biometrics and no screen lock'
            .tr;
      case BiometricStatus.notEnrolled:
        return 'No fingerprint or face is set up. Add one in device settings, or use your device passcode'
            .tr;
      case BiometricStatus.passcodeNotSet:
        return 'Set a screen lock on this device before turning on app lock'.tr;
      case BiometricStatus.lockedOut:
        return 'Too many attempts. Wait about 30 seconds, then try again'.tr;
      case BiometricStatus.permanentlyLockedOut:
        return 'Biometrics are locked. Use your device passcode to unlock them again'
            .tr;
      case BiometricStatus.misconfigured:
        return 'App lock is not set up correctly in this build'.tr;
      case BiometricStatus.unsupportedPlatform:
        return 'App lock is not available on this platform'.tr;
      case BiometricStatus.unknown:
        return 'Something went wrong while verifying you'.tr;
    }
  }

  BiometricAuthResult _result(BiometricStatus status) => BiometricAuthResult(
    success: status == BiometricStatus.success,
    status: status,
    message: messageFor(status),
  );
}
