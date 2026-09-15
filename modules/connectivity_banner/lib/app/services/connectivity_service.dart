import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

import 'package:flutter_starter/app/services/domain/dev_tools.dart';

/// Single source of truth for "is the device online right now".
class ConnectivityService extends GetxService {
  static ConnectivityService get to => Get.find();

  /// Reactive online flag. Optimistic until the first check lands.
  final RxBool isOnline = true.obs;

  /// Last radio types the platform reported (wifi, mobile, ethernet, none...).
  final RxList<ConnectivityResult> results = <ConnectivityResult>[].obs;

  /// Set false to trust the radio state and skip the DNS probe.
  bool verifyReachability = true;

  /// Host used by the reachability probe. Change it for restricted networks.
  String probeHost = 'google.com';

  /// How long the probe may take before it counts as offline.
  Duration probeTimeout = const Duration(seconds: 4);

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  int _seq = 0;

  /// True while there is no usable network.
  bool get isOffline => !isOnline.value;

  /// Emits on every change of [isOnline].
  Stream<bool> get onStatusChange => isOnline.stream;

  @override
  void onInit() {
    super.onInit();
    _sub = _connectivity.onConnectivityChanged.listen(_apply);
    unawaited(refreshStatus());
  }

  @override
  void onClose() {
    _sub?.cancel();
    _sub = null;
    super.onClose();
  }

  /// Re-reads the platform state now and returns the resulting flag.
  Future<bool> refreshStatus() async {
    try {
      await _apply(await _connectivity.checkConnectivity());
    } catch (e) {
      devPrint('checkConnectivity failed: $e', tag: 'ConnectivityService');
    }
    return isOnline.value;
  }

  /// Completes once online, or on [timeout] — returns the final flag.
  Future<bool> waitUntilOnline({Duration? timeout}) async {
    if (isOnline.value) return true;
    final completer = Completer<bool>();
    late final Worker worker;
    Timer? timer;

    void finish(bool value) {
      if (completer.isCompleted) return;
      timer?.cancel();
      worker.dispose();
      completer.complete(value);
    }

    worker = ever<bool>(isOnline, (online) {
      if (online) finish(true);
    });
    if (timeout != null) timer = Timer(timeout, () => finish(isOnline.value));
    return completer.future;
  }

  /// connectivity_plus v7 returns a List — never compare it to a bare enum.
  Future<void> _apply(List<ConnectivityResult> next) async {
    final token = ++_seq;
    results.assignAll(next);

    final hasRadio =
        next.isNotEmpty && next.any((r) => r != ConnectivityResult.none);
    final online =
        hasRadio && (!verifyReachability || await _canReachInternet());

    // A newer event landed while the probe was in flight — let it win.
    if (token != _seq) return;

    if (isOnline.value != online) {
      devPrint(
        'online = $online (${next.map((r) => r.name).join(', ')})',
        tag: 'ConnectivityService',
      );
    }
    isOnline.value = online;
  }

  /// The radio being up does not prove egress; a DNS lookup does.
  Future<bool> _canReachInternet() async {
    try {
      final lookup = await InternetAddress.lookup(
        probeHost,
      ).timeout(probeTimeout);
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
