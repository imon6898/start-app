/// Module-owned endpoints — installing offline_first must not require an edit
/// to the core `ApiConstant`. Move them there once you keep the feature.
class NotesApiConst {
  static const String _sync = '/sync/notes';

  /// GET — changes with `updated_at > since`, tombstones included.
  static const String pullUri = '$_sync/pull';

  /// POST — replays one outbox op. Must be idempotent on `op_id`.
  static const String pushUri = '$_sync/push';
}
