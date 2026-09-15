// Ids shared by BOTH isolates. Keep this file plugin-free and import-free.

/// Task names and unique ids. A task name travels to the background isolate as
/// a plain string, so renaming one orphans anything an older build queued.
class BackgroundTasks {
  const BackgroundTasks._();

  // Task names — what the dispatcher looks up to find a handler.
  static const String syncOutbox = 'syncOutbox';
  static const String refreshContent = 'refreshContent';
  static const String cleanupCache = 'cleanupCache';

  // Unique names — one scheduling slot each, and the BGTaskScheduler
  // identifiers that go in Info.plist. Keep them bundle-id-ish.
  static const String periodicSyncId = 'com.easital.starter.periodicSync';
  static const String oneOffSyncId = 'com.easital.starter.oneOffSync';
  static const String processingId = 'com.easital.starter.processing';

  /// iOS delivers a periodic or processing task under its BGTaskScheduler
  /// identifier — the uniqueName — not the task name. Android always sends the
  /// task name. This maps the iOS spelling back onto a handler.
  static const Map<String, String> uniqueNameAliases = {
    periodicSyncId: syncOutbox,
    oneOffSyncId: syncOutbox,
    processingId: cleanupCache,
  };

  /// Handler for a legacy iOS background-fetch wakeup, which arrives under
  /// workmanager's own `iOSPerformFetch` name.
  static const String iosFallback = syncOutbox;

  /// Android-only tag. Cancelling by tag is a documented no-op on iOS.
  static const String tag = 'flutter_starter.background';

  // inputData keys. inputData crosses a platform channel: primitives only.
  static const String keyReason = 'reason';
  static const String keyAttempt = 'attempt';
}
