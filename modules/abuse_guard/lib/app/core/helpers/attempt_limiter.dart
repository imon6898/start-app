// Failed-attempt lockout with escalating, persisted cooldowns.
// A UX affordance and a courtesy to your server — NOT security. The server must
// enforce its own per-account and per-IP limits; this client can be bypassed.

import 'dart:async';

import 'package:get/get.dart';

import 'package:flutter_starter/app/core/helpers/action_throttle.dart';

/// Result of asking the limiter whether an attempt may proceed.
class AttemptGate {
  const AttemptGate({
    required this.allowed,
    required this.attemptsLeft,
    required this.remaining,
  });

  final bool allowed;
  final int attemptsLeft;
  final Duration remaining;

  /// mm:ss left on the lock.
  String get formattedTime {
    final int seconds = remaining.inSeconds;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// Counts failures per identifier (email/phone) and locks for an escalating
/// window once [maxAttempts] is reached. State survives an app restart.
class AttemptLimiter {
  AttemptLimiter({
    required this.name,
    this.maxAttempts = 5,
    this.steps = const [
      Duration(minutes: 1),
      Duration(minutes: 5),
      Duration(minutes: 15),
    ],
    this.decayAfter = const Duration(hours: 24),
  });

  final String name;
  final int maxAttempts;

  /// Lock lengths, used in order: first lock -> steps[0], next -> steps[1], ...
  final List<Duration> steps;

  /// A counter older than this is forgotten, so one bad day is not permanent.
  final Duration decayAfter;

  /// Seconds left on the identifier passed to the last check/record call.
  final RxInt lockRemaining = 0.obs;
  final RxBool isLocked = false.obs;

  Timer? _timer;
  String _watched = '';

  /// mm:ss for the UI.
  String get formattedTime {
    final int seconds = lockRemaining.value;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  /// Current gate for [identifier]; also binds the Rx countdown to it.
  Future<AttemptGate> check(String identifier) async {
    await GuardCache.init();
    _watched = GuardCache.keyFor(identifier);
    return _gate();
  }

  /// Records one failure and returns the resulting gate.
  Future<AttemptGate> recordFailure(String identifier) async {
    await GuardCache.init();
    _watched = GuardCache.keyFor(identifier);

    final int now = DateTime.now().millisecondsSinceEpoch;
    final int last = GuardCache.readInt(_seenKey) ?? 0;
    final int previous = now - last > decayAfter.inMilliseconds
        ? 0
        : (GuardCache.readInt(_countKey) ?? 0);

    final int failures = previous + 1;
    await GuardCache.writeInt(_countKey, failures);
    await GuardCache.writeInt(_seenKey, now);

    if (failures >= maxAttempts) {
      final Duration step =
          steps[(failures - maxAttempts).clamp(0, steps.length - 1)];
      await GuardCache.writeInt(
        _lockKey,
        DateTime.now().add(step).millisecondsSinceEpoch,
      );
    }
    return _gate();
  }

  /// Clears the counter and any lock after a successful attempt.
  Future<void> recordSuccess(String identifier) => clear(identifier);

  Future<void> clear(String identifier) async {
    await GuardCache.init();
    final String key = GuardCache.keyFor(identifier);
    await GuardCache.remove('attempts.$name.$key');
    await GuardCache.remove('seen.$name.$key');
    await GuardCache.remove('lock.$name.$key');
    if (key == _watched) _apply(0);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  String get _countKey => 'attempts.$name.$_watched';
  String get _seenKey => 'seen.$name.$_watched';
  String get _lockKey => 'lock.$name.$_watched';

  AttemptGate _gate() {
    final int failures = GuardCache.readInt(_countKey) ?? 0;
    final int expiry = GuardCache.readInt(_lockKey) ?? 0;
    final int ms = expiry - DateTime.now().millisecondsSinceEpoch;
    final int seconds = ms <= 0 ? 0 : (ms / 1000).ceil();

    _apply(seconds);
    return AttemptGate(
      allowed: seconds <= 0,
      attemptsLeft: (maxAttempts - failures).clamp(0, maxAttempts),
      remaining: Duration(seconds: seconds),
    );
  }

  // Recomputes from the clock on every tick so backgrounding cannot drift it.
  void _apply(int seconds) {
    _timer?.cancel();
    lockRemaining.value = seconds;
    isLocked.value = seconds > 0;
    if (seconds <= 0) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final int expiry = GuardCache.readInt(_lockKey) ?? 0;
      final int ms = expiry - DateTime.now().millisecondsSinceEpoch;
      final int left = ms <= 0 ? 0 : (ms / 1000).ceil();
      lockRemaining.value = left;
      if (left <= 0) {
        timer.cancel();
        isLocked.value = false;
      }
    });
  }
}
