import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// How a background run ended. Android turns [retry] into a re-run with its
/// backoff policy; iOS ignores the return value and just scores the task.
/// [stopped] means the OS killed the worker mid-run — Android only.
enum BackgroundOutcome { success, retry, failure, stopped }

/// What the last background run left behind. Written in the background isolate,
/// read in the UI isolate — SharedPreferences is the only state both can see.
class BackgroundRunInfo {
  const BackgroundRunInfo({
    this.task,
    this.outcome,
    this.at,
    this.message = '',
    this.runCount = 0,
    this.failureCount = 0,
  });

  final String? task;
  final BackgroundOutcome? outcome;
  final DateTime? at;
  final String message;

  /// Lifetime counters — the only honest way to see whether the OS ever runs
  /// you on a real device.
  final int runCount;
  final int failureCount;

  bool get hasRun => at != null;

  BackgroundRunInfo copyWith({
    String? task,
    BackgroundOutcome? outcome,
    DateTime? at,
    String? message,
    int? runCount,
    int? failureCount,
  }) => BackgroundRunInfo(
    task: task ?? this.task,
    outcome: outcome ?? this.outcome,
    at: at ?? this.at,
    message: message ?? this.message,
    runCount: runCount ?? this.runCount,
    failureCount: failureCount ?? this.failureCount,
  );

  Map<String, dynamic> toMap() => {
    'task': task,
    'outcome': outcome?.name,
    'at': at?.toIso8601String(),
    'message': message,
    'runCount': runCount,
    'failureCount': failureCount,
  };

  factory BackgroundRunInfo.fromMap(Map<String, dynamic> map) {
    final rawAt = map['at'] as String?;
    return BackgroundRunInfo(
      task: map['task'] as String?,
      outcome: _outcomeNamed(map['outcome'] as String?),
      at: rawAt == null ? null : DateTime.tryParse(rawAt),
      message: (map['message'] as String?) ?? '',
      runCount: (map['runCount'] as num?)?.toInt() ?? 0,
      failureCount: (map['failureCount'] as num?)?.toInt() ?? 0,
    );
  }

  static BackgroundOutcome? _outcomeNamed(String? name) {
    for (final outcome in BackgroundOutcome.values) {
      if (outcome.name == name) return outcome;
    }
    return null;
  }
}

/// The cross-isolate mailbox. Everything here re-opens SharedPreferences,
/// because a handler in the background isolate shares nothing with the UI one.
class BackgroundRunLog {
  const BackgroundRunLog._();

  static const String _runKey = 'backgroundLastRun';

  /// Reloads first: the UI isolate's in-memory copy predates the background
  /// write, so without this the tile shows yesterday's result forever.
  /// Process-wide — it refreshes CacheManager's view too, which is harmless.
  static Future<BackgroundRunInfo> read() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return _decode(prefs.getString(_runKey));
  }

  static Future<BackgroundRunInfo> record({
    required String task,
    required BackgroundOutcome outcome,
    String message = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final previous = _decode(prefs.getString(_runKey));
    final next = BackgroundRunInfo(
      task: task,
      outcome: outcome,
      at: DateTime.now(),
      message: message,
      runCount: previous.runCount + 1,
      failureCount:
          previous.failureCount + (outcome == BackgroundOutcome.success ? 0 : 1),
    );
    await prefs.setString(_runKey, jsonEncode(next.toMap()));
    return next;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_runKey);
  }

  static BackgroundRunInfo _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const BackgroundRunInfo();
    try {
      return BackgroundRunInfo.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A log written by an older shape is not worth crashing a handler over.
      return const BackgroundRunInfo();
    }
  }
}
