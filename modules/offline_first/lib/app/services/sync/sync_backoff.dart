import 'dart:math';

/// Full-jitter exponential backoff for failed outbox ops.
class SyncBackoff {
  const SyncBackoff({
    this.base = const Duration(seconds: 2),
    this.max = const Duration(minutes: 5),
    this.maxAttempts = 8,
  });

  /// First delay ceiling; doubles per attempt.
  final Duration base;

  /// Cap, so a long outage does not schedule a retry hours out.
  final Duration max;

  /// After this many failures an op is dead-lettered instead of retried.
  final int maxAttempts;

  /// delay = random(0, min(base * 2^attempt, max)) — `attempt` is 0-based.
  Duration delayFor(int attempt, {Random? random}) {
    if (attempt < 0) attempt = 0;
    // 2^attempt overflows nothing at 30, and the cap makes anything past it moot.
    final shift = attempt > 30 ? 30 : attempt;
    final ceilingMs = min(base.inMilliseconds * (1 << shift), max.inMilliseconds);
    final rng = random ?? Random();
    return Duration(milliseconds: rng.nextInt(ceilingMs <= 0 ? 1 : ceilingMs + 1));
  }

  /// Fixed backoff makes every client retry in lockstep — that is the herd.
  bool isExhausted(int attempts) => attempts >= maxAttempts;
}
