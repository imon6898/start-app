import 'dart:async';

import 'package:get/get.dart';

import 'domain/circuit_breaker.dart';
import 'domain/dev_tools.dart';

/// Rx mirror of what the interceptor is doing, so a screen can say
/// "too many requests — try again in 00:42" instead of hanging.
///
/// Optional: every static reporter no-ops when the service is not registered.
class ApiResilienceService extends GetxService {
  final RxBool isRateLimited = false.obs;
  final RxInt countdownTime = 0.obs;
  final RxString limitedHost = ''.obs;

  /// Per-host breaker state; closed hosts are removed.
  final RxMap<String, CircuitState> circuits = <String, CircuitState>{}.obs;
  final RxInt circuitCooldown = 0.obs;

  Timer? _limitTimer;
  Timer? _circuitTimer;

  /// Half-open hosts are already probing, so they are not reported as down.
  bool get isCircuitOpen =>
      circuits.values.any((state) => state == CircuitState.open);

  /// True when the server sent 429 without a usable Retry-After.
  bool get isWaitUnknown => isRateLimited.value && countdownTime.value <= 0;

  /// mm:ss for the rate-limit countdown, same idiom as VerifyOtpController.
  String get formattedTime => _format(countdownTime.value);

  String get circuitCooldownText => _format(circuitCooldown.value);

  static ApiResilienceService? get _instance =>
      Get.isRegistered<ApiResilienceService>()
      ? Get.find<ApiResilienceService>()
      : null;

  static void reportRateLimit(String host, Duration? retryAfter) =>
      _instance?._onRateLimit(host, retryAfter);

  static void reportCircuit(
    String host,
    CircuitState state,
    Duration cooldown,
  ) => _instance?._onCircuit(host, state, cooldown);

  static void clear() => _instance?.clearAll();

  void _onRateLimit(String host, Duration? retryAfter) {
    devPrint('Resilience: rate limited by $host for ${retryAfter?.inSeconds}s');
    limitedHost.value = host;
    isRateLimited.value = true;
    _startCountdown(countdownTime, retryAfter?.inSeconds ?? 0, () {
      isRateLimited.value = false;
      limitedHost.value = '';
    });
  }

  void _onCircuit(String host, CircuitState state, Duration cooldown) {
    if (state == CircuitState.closed) {
      circuits.remove(host);
    } else {
      circuits[host] = state;
    }
    _startCountdown(circuitCooldown, cooldown.inSeconds, null);
  }

  void clearRateLimit() {
    _limitTimer?.cancel();
    countdownTime.value = 0;
    isRateLimited.value = false;
    limitedHost.value = '';
  }

  void clearAll() {
    clearRateLimit();
    _circuitTimer?.cancel();
    circuitCooldown.value = 0;
    circuits.clear();
  }

  void _startCountdown(RxInt target, int seconds, void Function()? onDone) {
    final timer = identical(target, countdownTime)
        ? _limitTimer
        : _circuitTimer;
    timer?.cancel();
    target.value = seconds;
    if (seconds <= 0) {
      onDone?.call();
      return;
    }
    final ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (target.value > 0) {
        target.value--;
      } else {
        t.cancel();
        onDone?.call();
      }
    });
    if (identical(target, countdownTime)) {
      _limitTimer = ticker;
    } else {
      _circuitTimer = ticker;
    }
  }

  String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void onClose() {
    _limitTimer?.cancel();
    _circuitTimer?.cancel();
    super.onClose();
  }
}
