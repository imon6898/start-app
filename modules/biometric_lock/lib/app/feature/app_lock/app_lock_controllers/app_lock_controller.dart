// Owns the lock state: cold-start lock, background timeout, opt-in toggle and
// the recovery path that stops a dead sensor from bricking the app.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'package:flutter_starter/app/feature/app_lock/app_lock_logic/app_lock_store.dart';
import 'package:flutter_starter/app/routes/app_routes.dart';
import 'package:flutter_starter/app/services/biometric_service.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:flutter_starter/app/services/local_data/cache_manager.dart';
import 'package:flutter_starter/app/widgets/feedback/custom_snack_bar.dart';

class AppLockController extends GetxController with WidgetsBindingObserver {
  static AppLockController get to => Get.find();

  /// Override to send a signed-out user somewhere other than the sign-in screen.
  static Future<void> Function()? onSignOut;

  final RxBool isEnabled = false.obs;
  final RxBool isLocked = false.obs;
  final RxBool isAuthenticating = false.obs;
  final RxBool isConfirmingSignOut = false.obs;
  final RxInt timeoutSeconds = AppLockStore.defaultTimeoutSeconds.obs;
  final RxString errorMessage = ''.obs;
  final Rx<BiometricStatus> capability = BiometricStatus.unknown.obs;

  /// Set false to show the lock screen without firing the OS prompt itself.
  bool autoPromptOnLock = true;

  DateTime? _leftAt;
  bool _promptScheduled = false;

  /// Self-registering so the module works with only the binding entry wired up.
  BiometricService get biometrics => Get.isRegistered<BiometricService>()
      ? Get.find<BiometricService>()
      : Get.put(BiometricService(), permanent: true);

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    if (AppLockStore.isReady) {
      _applyStored();
    } else {
      // Bootstrap did not init the store; load it and lock one frame later.
      unawaited(AppLockStore.init().then((_) => _applyStored()));
    }
    unawaited(refreshCapability());
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    isEnabled.close();
    isLocked.close();
    isAuthenticating.close();
    isConfirmingSignOut.close();
    timeoutSeconds.close();
    errorMessage.close();
    capability.close();
    super.onClose();
  }

  @override
  Future<bool> didPopRoute() async {
    // Swallow Android back while locked; the stack must not move underneath.
    if (isLocked.value) return true;
    return super.didPopRoute();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // The OS prompt backgrounds the app itself — ignoring it avoids a re-lock loop.
    if (isAuthenticating.value || !isEnabled.value) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _leftAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final DateTime? leftAt = _leftAt;
        _leftAt = null;
        if (leftAt == null) return;
        if (DateTime.now().difference(leftAt).inSeconds >=
            timeoutSeconds.value) {
          lockNow();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Re-reads what the device can do; drives the settings screen copy.
  Future<void> refreshCapability() async {
    capability.value = await biometrics.refreshCapability();
  }

  /// Shows the lock screen without asking — used on resume and from settings.
  void lockNow() {
    if (isLocked.value) return;
    errorMessage.value = '';
    isConfirmingSignOut.value = false;
    isLocked.value = true;
    if (autoPromptOnLock) _promptSoon();
  }

  /// The one path out of the lock screen. Biometrics first, device passcode as
  /// the OS-level fallback, forced recovery if the device can do neither.
  Future<void> unlock() async {
    if (isAuthenticating.value) return;
    isAuthenticating.value = true;
    errorMessage.value = '';
    try {
      final BiometricAuthResult result = await biometrics.authenticate(
        reason: 'Unlock to continue'.tr,
      );
      if (result.success) {
        isLocked.value = false;
        isConfirmingSignOut.value = false;
        _leftAt = null;
        return;
      }
      errorMessage.value = result.message;
      capability.value = result.status;
      if (result.deviceCannotAuthenticate) {
        await _recoverUnusableDevice(result.message);
      }
    } finally {
      isAuthenticating.value = false;
    }
  }

  /// Escape hatch offered on the lock screen only when the device really cannot
  /// authenticate. Re-checked here so a healthy device can never bypass.
  Future<void> disableBecauseUnavailable() async {
    if (await biometrics.canAuthenticate()) {
      errorMessage.value = BiometricService.messageFor(BiometricStatus.failed);
      return;
    }
    await _recoverUnusableDevice(
      BiometricService.messageFor(BiometricStatus.noHardware),
    );
  }

  /// Turning the lock on or off both need a passing check, so nobody else can
  /// flip it on a phone left unattended.
  Future<bool> setEnabled(bool value) async {
    if (isAuthenticating.value || value == isEnabled.value) {
      return isEnabled.value;
    }

    isAuthenticating.value = true;
    errorMessage.value = '';
    try {
      if (value && !await biometrics.canAuthenticate()) {
        await refreshCapability();
        errorMessage.value = BiometricService.messageFor(capability.value);
        return isEnabled.value;
      }

      final BiometricAuthResult result = await biometrics.authenticate(
        reason: value
            ? 'Confirm to turn on app lock'.tr
            : 'Confirm to turn off app lock'.tr,
      );
      if (result.success) {
        await _persistEnabled(value);
        return isEnabled.value;
      }

      errorMessage.value = result.message;
      // A device that cannot authenticate must never block turning the lock OFF.
      if (!value && result.deviceCannotAuthenticate) {
        await _persistEnabled(false);
      }
      return isEnabled.value;
    } finally {
      isAuthenticating.value = false;
      unawaited(refreshCapability());
    }
  }

  Future<void> setTimeoutSeconds(int seconds) async {
    await AppLockStore.setTimeoutSeconds(seconds);
    timeoutSeconds.value = AppLockStore.timeoutSeconds;
  }

  /// Always available from the lock screen: end the session instead of
  /// unlocking. The user loses the session, never the app.
  Future<void> signOut() async {
    final Future<void> Function()? hook = onSignOut;
    await AppLockStore.clear();
    isEnabled.value = false;
    isLocked.value = false;
    isConfirmingSignOut.value = false;
    if (hook != null) {
      await hook();
      return;
    }
    await CacheManager.removeAll();
    Get.offAllNamed(AppRoutes.SigninScreen);
  }

  /// "30 seconds" / "5 minutes" / "Immediately" for the timeout chooser.
  static String timeoutLabel(int seconds) {
    if (seconds <= 0) return 'Immediately'.tr;
    if (seconds < 60) return '$seconds ${'seconds'.tr}';
    final int minutes = seconds ~/ 60;
    return minutes == 1 ? '1 ${'minute'.tr}' : '$minutes ${'minutes'.tr}';
  }

  /// Cold start: if the user opted in, the app comes up locked.
  void _applyStored() {
    isEnabled.value = AppLockStore.isEnabled;
    timeoutSeconds.value = AppLockStore.timeoutSeconds;
    if (!isEnabled.value) return;
    isLocked.value = true;
    if (autoPromptOnLock) _promptSoon();
  }

  /// Waits for the lock screen to be painted before the OS sheet appears.
  void _promptSoon() {
    if (_promptScheduled) return;
    _promptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        _promptScheduled = false;
        if (isLocked.value && !isAuthenticating.value) unawaited(unlock());
      });
    });
  }

  Future<void> _persistEnabled(bool value) async {
    await AppLockStore.setEnabled(value);
    isEnabled.value = value;
    if (!value) isLocked.value = false;
    _leftAt = null;
  }

  /// The failure mode that matters: the device can no longer verify anyone, so
  /// keeping the lock on would brick the app. Turn it off and let the user in.
  Future<void> _recoverUnusableDevice(String reason) async {
    devPrint('Device cannot authenticate — app lock disabled', tag: 'AppLock');
    await AppLockStore.setEnabled(false);
    isEnabled.value = false;
    isLocked.value = false;
    isConfirmingSignOut.value = false;
    errorMessage.value = '';
    _leftAt = null;

    final BuildContext? context = Get.context;
    if (context == null || !context.mounted) return;
    showCustomSnackBar(
      context: context,
      type: SnackBarType.Warning,
      title: 'App lock turned off'.tr,
      description: reason,
    );
  }
}
