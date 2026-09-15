import 'sync_record.dart';

/// Two versions of the same row that both changed since the last sync.
class SyncConflict {
  const SyncConflict({required this.local, required this.remote, this.base});

  final SyncRecord local;
  final SyncRecord remote;

  /// The version both sides started from, when the store still has it.
  final Map<String, dynamic>? base;

  String get collection => remote.collection;
  String get id => remote.id;
}

/// What the engine should do with a conflict.
sealed class SyncResolution {
  const SyncResolution();
}

/// Take the server's row and drop the local edit.
class KeepRemote extends SyncResolution {
  const KeepRemote();
}

/// Re-push the local row, overwriting the server's.
class KeepLocal extends SyncResolution {
  const KeepLocal();
}

/// Push a third value built from both sides.
class MergedResolution extends SyncResolution {
  const MergedResolution(this.data);
  final Map<String, dynamic> data;
}

/// Park it. The engine stores it in `pendingConflicts` and waits for a human.
class ManualResolution extends SyncResolution {
  const ManualResolution();
}

abstract class SyncConflictResolver {
  SyncResolution resolve(SyncConflict conflict);
}

/// Default. Newest `updated_at` wins; a tie goes to the server.
///
/// This SILENTLY LOSES DATA: if two devices edit different fields of the same
/// row, the older edit disappears entirely — not merged, not flagged. Accept it
/// only for rows a single user edits from one device at a time.
class LastWriteWinsResolver implements SyncConflictResolver {
  const LastWriteWinsResolver();

  @override
  SyncResolution resolve(SyncConflict conflict) {
    // A remote tombstone wins over a local edit: undeleting by accident is worse.
    if (conflict.remote.deleted) return const KeepRemote();
    return conflict.local.updatedAt.isAfter(conflict.remote.updatedAt)
        ? const KeepLocal()
        : const KeepRemote();
  }
}

/// The local device always wins. Honest about what it is: a data-loss policy
/// pointed the other way.
class PreferLocalResolver implements SyncConflictResolver {
  const PreferLocalResolver();

  @override
  SyncResolution resolve(SyncConflict conflict) => const KeepLocal();
}

/// Field-level merge. [pick] is called per key present on either side; return
/// the value to keep. Only safe when fields are genuinely independent.
class FieldMergeResolver implements SyncConflictResolver {
  const FieldMergeResolver(this.pick);

  final Object? Function(String key, Object? local, Object? remote) pick;

  @override
  SyncResolution resolve(SyncConflict conflict) {
    final keys = {...conflict.local.data.keys, ...conflict.remote.data.keys};
    final merged = <String, dynamic>{};
    for (final key in keys) {
      merged[key] = pick(key, conflict.local.data[key], conflict.remote.data[key]);
    }
    return MergedResolution(merged);
  }
}

/// Never guesses. Every conflict lands in `SyncService.pendingConflicts` for the
/// UI to present, and the local row stays dirty until resolved.
class ManualConflictResolver implements SyncConflictResolver {
  const ManualConflictResolver();

  @override
  SyncResolution resolve(SyncConflict conflict) => const ManualResolution();
}
