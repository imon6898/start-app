// Client-side pacing: persisted cooldowns, debounce, throttle, single-flight.
// These stop YOUR app from generating abusive traffic. They are not security —
// a modified client skips them, so the server must enforce its own limits.

import 'dart:async';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences slice for guard state, prefixed so it never collides with
/// CacheManager keys. Same backing store, so CacheManager.removeAll() wipes it.
class GuardCache {
  static const String prefix = 'guard.';
  static SharedPreferences? _pref;

  /// Optional eager init; every write calls it anyway.
  static Future<void> init() async =>
      _pref ??= await SharedPreferences.getInstance();

  static int? readInt(String key) => _pref?.getInt('$prefix$key');

  static Future<void> writeInt(String key, int value) async {
    await init();
    await _pref!.setInt('$prefix$key', value);
  }

  static Future<void> remove(String key) async {
    await init();
    await _pref!.remove('$prefix$key');
  }

  /// Drops every guard key — call on logout if cooldowns should not survive it.
  static Future<void> clearAll() async {
    await init();
    for (final key in _pref!.getKeys().where((k) => k.startsWith(prefix))) {
      await _pref!.remove(key);
    }
  }

  /// FNV-1a over the identifier: stable across restarts (String.hashCode is not)
  /// and keeps raw emails/phones out of SharedPreferences. Not a security hash.
  static String keyFor(String identifier) {
    var hash = 0x811c9dc5;
    for (final unit in identifier.trim().toLowerCase().codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}

/// Named cooldown with a live countdown, persisted so a restart does not reset it.
/// Same shape as the OTP resend timer: [countdownTime] + [canRun].
class ActionCooldown {
  ActionCooldown({required this.name, required this.duration});

  final String name;
  final Duration duration;

  /// Seconds left — mirrors countdownTime in VerifyOtpController.
  final RxInt countdownTime = 0.obs;

  /// True when the action may run — mirrors canResend.
  final RxBool canRun = true.obs;

  Timer? _timer;

  String get cacheKey => 'cooldown.$name';

  /// mm:ss for the UI.
  String get formattedTime {
    final int seconds = countdownTime.value;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  /// Reloads the stored expiry and resumes ticking; call from onInit.
  Future<void> restore() async {
    await GuardCache.init();
    _apply(_remainingSeconds());
  }

  /// Starts (or restarts) the cooldown and persists its expiry.
  Future<void> start({Duration? override}) async {
    final Duration window = override ?? duration;
    await GuardCache.writeInt(
      cacheKey,
      DateTime.now().add(window).millisecondsSinceEpoch,
    );
    _apply(window.inSeconds);
  }

  /// Runs [action] only when clear, then starts the cooldown. False = blocked.
  Future<bool> run(Future<void> Function() action, {Duration? override}) async {
    await restore();
    if (!canRun.value) return false;
    await action();
    await start(override: override);
    return true;
  }

  /// Clears the cooldown.
  Future<void> reset() async {
    _timer?.cancel();
    await GuardCache.remove(cacheKey);
    countdownTime.value = 0;
    canRun.value = true;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  int _remainingSeconds() {
    final int? expiry = GuardCache.readInt(cacheKey);
    if (expiry == null) return 0;
    final int ms = expiry - DateTime.now().millisecondsSinceEpoch;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  // Recomputes from the clock on every tick so backgrounding cannot drift it.
  void _apply(int seconds) {
    _timer?.cancel();
    countdownTime.value = seconds;
    canRun.value = seconds <= 0;
    if (seconds <= 0) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final int left = _remainingSeconds();
      countdownTime.value = left;
      if (left <= 0) {
        timer.cancel();
        canRun.value = true;
      }
    });
  }
}

/// Waits until the caller stops firing — for search-as-you-type.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;
  Timer? _timer;

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() => _timer?.cancel();

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Runs the first call and swallows the rest until [interval] passes — rapid taps.
class Throttler {
  Throttler({this.interval = const Duration(milliseconds: 800)});

  final Duration interval;
  DateTime? _lastRun;

  /// Returns false when the call was swallowed.
  bool call(void Function() action) {
    final DateTime now = DateTime.now();
    if (_lastRun != null && now.difference(_lastRun!) < interval) return false;
    _lastRun = now;
    action();
    return true;
  }

  void dispose() {
    _lastRun = null;
  }
}

/// Ignores a second call while the first is still running — kills double-submit.
class SingleFlight {
  final RxBool inFlight = false.obs;

  /// Returns null when the call was dropped because one was already in flight.
  Future<T?> run<T>(Future<T> Function() action) async {
    if (inFlight.value) return null;
    inFlight.value = true;
    try {
      return await action();
    } finally {
      inFlight.value = false;
    }
  }
}
