import 'package:get/get.dart';

import 'package:flutter_starter/app/services/connectivity_service.dart';
import 'package:flutter_starter/app/widgets/feedback/custom_snack_bar.dart';

/// Fail-fast gate a controller calls before any network action.
class ConnectivityGuard {
  const ConnectivityGuard._();

  /// Snackbar copy. Override once at startup to reword it app-wide.
  static String title = 'No internet connection';
  static String message = 'Check your connection and try again.';

  /// Resolves the service, registering it if the app never did.
  static ConnectivityService get service =>
      Get.isRegistered<ConnectivityService>()
      ? ConnectivityService.to
      : Get.put(ConnectivityService(), permanent: true);

  /// True when online; otherwise warns the user and returns false.
  static Future<bool> ensureOnline({
    bool notify = true,
    bool recheck = true,
  }) async {
    final online = recheck
        ? await service.refreshStatus()
        : service.isOnline.value;
    if (!online && notify) notifyOffline();
    return online;
  }

  /// Runs [action] only when online; returns null (and warns) when offline.
  static Future<T?> run<T>(
    Future<T> Function() action, {
    bool notify = true,
    bool recheck = true,
  }) async {
    if (!await ensureOnline(notify: notify, recheck: recheck)) return null;
    return action();
  }

  /// Cheap synchronous read — no probe, no snackbar.
  static bool get isOnline => service.isOnline.value;

  /// Shows the offline warning snackbar. No-op without a live context.
  static void notifyOffline() {
    final context = Get.context;
    if (context == null) return;
    showCustomSnackBar(
      context: context,
      type: SnackBarType.Warning,
      title: title.tr,
      description: message.tr,
    );
  }
}
