// Pure resolution and parsing — no Rx, no plugins, so it is unit-testable.
// Precedence: local override -> cached/live remote value -> hardcoded fallback.

import 'dart:convert';

import 'feature_flag_keys.dart';

/// Which rung of the ladder produced the value currently in use.
enum FlagSource { override, remote, fallback }

class FlagResolver {
  FlagResolver._();

  static T resolve<T>(FlagKey<T> flag, {dynamic override, dynamic remote}) {
    final fromOverride = coerce(flag, override);
    if (fromOverride != null) return fromOverride;
    final fromRemote = coerce(flag, remote);
    if (fromRemote != null) return fromRemote;
    return flag.fallback;
  }

  static FlagSource sourceOf<T>(
    FlagKey<T> flag, {
    dynamic override,
    dynamic remote,
  }) {
    if (coerce(flag, override) != null) return FlagSource.override;
    if (coerce(flag, remote) != null) return FlagSource.remote;
    return FlagSource.fallback;
  }

  /// null means "unusable for this flag" — absent, or the wrong JSON type. A bad
  /// backend edit then falls through to the default instead of crashing.
  static T? coerce<T>(FlagKey<T> flag, dynamic raw) {
    if (raw == null) return null;
    switch (flag.type) {
      case FlagType.boolean:
        return _bool(raw) as T?;
      case FlagType.integer:
        return _int(raw) as T?;
      case FlagType.string:
        return raw is String ? raw as T : null;
      case FlagType.json:
        return _json(raw) as T?;
    }
  }

  static bool? _bool(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) {
      if (raw == 1) return true;
      if (raw == 0) return false;
      return null;
    }
    if (raw is String) {
      final v = raw.trim().toLowerCase();
      if (v == 'true') return true;
      if (v == 'false') return false;
    }
    return null;
  }

  static int? _int(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  static Map<String, dynamic>? _json(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
    if (raw is String && raw.trimLeft().startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

/// Remote experiment settings; every field is optional and falls back to the
/// compiled [Experiment].
class ExperimentConfig {
  final List<String> variants;
  final int? exposure;
  final String? forcedVariant;

  const ExperimentConfig({
    this.variants = const [],
    this.exposure,
    this.forcedVariant,
  });

  factory ExperimentConfig.fromJson(Map<dynamic, dynamic> json) {
    final rawVariants = json['variants'];
    final exposure = json['exposure'];
    final forced = json['forced_variant'] ?? json['forcedVariant'];
    return ExperimentConfig(
      variants: rawVariants is List
          ? rawVariants.map((v) => v.toString()).toList()
          : const [],
      exposure: exposure is num ? _percent(exposure) : null,
      forcedVariant: forced is String && forced.isNotEmpty ? forced : null,
    );
  }
}

/// The parsed flag document. See the README for the backend JSON contract.
class FlagDocument {
  final int version;
  final DateTime? updatedAt;

  /// Flag name -> raw JSON value, still untyped; [FlagResolver] coerces it.
  final Map<String, dynamic> values;

  /// Flag name -> rollout percentage, when the entry carries one.
  final Map<String, int> rollouts;
  final Map<String, ExperimentConfig> experiments;

  const FlagDocument({
    this.version = 0,
    this.updatedAt,
    this.values = const {},
    this.rollouts = const {},
    this.experiments = const {},
  });

  bool get isEmpty => values.isEmpty && experiments.isEmpty;

  /// Keys that describe the document rather than name a flag.
  static const Set<String> metaKeys = {
    'version',
    'updated_at',
    'updatedAt',
    'experiments',
    'flags',
  };

  /// Returns null instead of throwing: an unreadable document must leave the
  /// previous one in place.
  static FlagDocument? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return FlagDocument.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  factory FlagDocument.fromJson(Map<dynamic, dynamic> json) {
    // The "flags" envelope is optional; without it the document itself is the map.
    final rawFlags = json['flags'];
    final source = rawFlags is Map ? rawFlags : json;

    final values = <String, dynamic>{};
    final rollouts = <String, int>{};
    source.forEach((key, entry) {
      final name = key.toString();
      if (identical(source, json) && metaKeys.contains(name)) return;
      if (entry is Map) {
        // {"value": x, "rollout": n} is the rich form; a bare object is a
        // json-flag payload.
        if (entry.containsKey('value')) {
          values[name] = entry['value'];
          final rollout = entry['rollout'];
          if (rollout is num) rollouts[name] = _percent(rollout);
        } else {
          values[name] = entry;
        }
      } else {
        values[name] = entry;
      }
    });

    final experiments = <String, ExperimentConfig>{};
    final rawExperiments = json['experiments'];
    if (rawExperiments is Map) {
      rawExperiments.forEach((key, entry) {
        if (entry is Map) {
          experiments[key.toString()] = ExperimentConfig.fromJson(entry);
        }
      });
    }

    final rawVersion = json['version'];
    final rawUpdated = json['updated_at'] ?? json['updatedAt'];

    return FlagDocument(
      version: rawVersion is num ? rawVersion.toInt() : 0,
      updatedAt: rawUpdated is String ? DateTime.tryParse(rawUpdated) : null,
      values: values,
      rollouts: rollouts,
      experiments: experiments,
    );
  }
}

int _percent(num value) {
  final i = value.toInt();
  if (i < 0) return 0;
  return i > 100 ? 100 : i;
}
