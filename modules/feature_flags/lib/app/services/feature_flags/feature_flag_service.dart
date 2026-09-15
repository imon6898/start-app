// Resolution order, always: override -> cached/live remote -> hardcoded default.
// The cache is what makes a kill switch survive a failed fetch; without it an
// offline launch would silently re-enable the feature you just killed.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:get/get.dart';

import 'feature_flag_bucketing.dart';
import 'feature_flag_keys.dart';
import 'feature_flag_resolver.dart';
import 'feature_flag_store.dart';
import 'feature_flags_api_service.dart';

class FeatureFlagService extends GetxService {
  static FeatureFlagService get to => Get.find<FeatureFlagService>();

  /// Null when nobody registered the service — see [Flags] for reads that must
  /// survive that (widget tests, code running before bootstrap).
  static FeatureFlagService? get maybe => Get.isRegistered<FeatureFlagService>()
      ? Get.find<FeatureFlagService>()
      : null;

  /// Overrides are a QA tool; release builds ignore them so a forgotten toggle
  /// cannot ship. Set this before init() if you need them in a release build.
  static bool allowOverrides = !kReleaseMode;

  /// Extra query params sent with every fetch (app version, locale, cohort).
  static Map<String, dynamic> requestParams = <String, dynamic>{};

  final FeatureFlagsRepo _repo = FeatureFlagsRepo();

  final RxMap<String, dynamic> _remote = <String, dynamic>{}.obs;
  final RxMap<String, int> _rollouts = <String, int>{}.obs;
  final RxMap<String, ExperimentConfig> _experiments =
      <String, ExperimentConfig>{}.obs;
  final RxMap<String, dynamic> _overrides = <String, dynamic>{}.obs;
  final RxMap<String, String> _variantOverrides = <String, String>{}.obs;

  final RxBool isFetching = false.obs;
  final RxInt documentVersion = 0.obs;
  final Rx<DateTime?> lastFetchedAt = Rx<DateTime?>(null);
  final RxnString lastError = RxnString();

  /// The id experiments bucket on. Null means "use the per-install anonymous id".
  final RxnString userId = RxnString();

  /// Loads the cache first so the very first frame already has real values, then
  /// refreshes after that frame — fetching before runApp can hit `Get.context!`
  /// inside ApiService's offline snackbar.
  Future<FeatureFlagService> init({bool fetchAfterFirstFrame = true}) async {
    await FeatureFlagStore.init();
    _hydrateFromCache();
    if (fetchAfterFirstFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
    }
    return this;
  }

  /// Fetches, applies and persists. Never throws; returns false on failure and
  /// leaves the previous document in place.
  Future<bool> refresh() async {
    if (isFetching.value) return false;
    isFetching.value = true;
    try {
      final raw = await _repo.fetchDocument(
        userId: userId.value,
        extraParams: requestParams,
      );
      if (raw == null) {
        lastError.value = 'fetch failed';
        return false;
      }
      final doc = FlagDocument.tryParse(raw);
      if (doc == null) {
        lastError.value = 'document was not valid JSON';
        return false;
      }
      _apply(doc);
      final now = DateTime.now();
      lastFetchedAt.value = now;
      lastError.value = null;
      await FeatureFlagStore.setRawDocument(raw);
      await FeatureFlagStore.setFetchedAt(now);
      return true;
    } catch (e) {
      // Catches Error too: ApiService reaches for Get.context! when offline.
      devPrint('Flags refresh failed: $e');
      lastError.value = e.toString();
      return false;
    } finally {
      isFetching.value = false;
    }
  }

  // ── Typed reads ──

  T valueOf<T>(FlagKey<T> flag) => FlagResolver.resolve(
    flag,
    override: _overrideOf(flag.name),
    remote: _remote[flag.name],
  );

  /// Bool flags also honour a `rollout` percentage from the document: the value
  /// must be true AND this user must fall inside the percentage.
  bool isEnabled(BoolFlag flag) {
    if (!valueOf<bool>(flag)) return false;
    if (_overrideOf(flag.name) != null) return true;
    final percent = _rollouts[flag.name];
    if (percent == null) return true;
    return FlagBucketing.inRollout(bucketingId, flag.name, percent);
  }

  /// True when the backend has switched the feature off.
  bool isKilled(KillSwitch flag) => !isEnabled(flag);

  int intOf(IntFlag flag) => valueOf<int>(flag);

  String stringOf(StringFlag flag) => valueOf<String>(flag);

  Map<String, dynamic> jsonOf(JsonFlag flag) =>
      valueOf<Map<String, dynamic>>(flag);

  FlagSource sourceOf<T>(FlagKey<T> flag) => FlagResolver.sourceOf(
    flag,
    override: _overrideOf(flag.name),
    remote: _remote[flag.name],
  );

  int? rolloutOf(FlagKey<Object> flag) => _rollouts[flag.name];

  // ── Experiments ──

  /// Stable id: the server's user id when signed in, otherwise a per-install id.
  String get bucketingId {
    final id = userId.value?.trim();
    return (id == null || id.isEmpty) ? FeatureFlagStore.anonymousId : id;
  }

  /// The variant this user is in, or null when they are not enrolled. Same
  /// answer on every launch and every device for the same user id.
  String? variantOf(Experiment experiment) {
    final config = _experiments[experiment.key];
    final variants = (config != null && config.variants.isNotEmpty)
        ? config.variants
        : experiment.variants;

    final forced =
        (allowOverrides ? _variantOverrides[experiment.key] : null) ??
        config?.forcedVariant;
    if (forced != null && variants.contains(forced)) return forced;

    final exposure = config?.exposure ?? experiment.exposure;
    if (!FlagBucketing.inRollout(bucketingId, experiment.key, exposure)) {
      return null;
    }
    return FlagBucketing.variantOf(bucketingId, experiment.key, variants);
  }

  String variantOrControl(Experiment experiment) =>
      variantOf(experiment) ?? experiment.control;

  bool isInVariant(Experiment experiment, String variant) =>
      variantOf(experiment) == variant;

  bool isEnrolled(Experiment experiment) => variantOf(experiment) != null;

  /// Exposed for the debug screen and for logging alongside your analytics event.
  int bucketOf(Experiment experiment) =>
      FlagBucketing.bucketOf(bucketingId, experiment.key);

  // ── Identity ──

  /// Call after sign-in, and with null after sign-out. Changing the id
  /// re-buckets every experiment, which is why it must be the server's user id
  /// and not a per-device value.
  void setUserId(String? id) {
    if (userId.value == id) return;
    userId.value = id;
  }

  // ── Local overrides (the debug screen) ──

  bool get overridesEnabled => allowOverrides;

  bool get hasOverrides =>
      _overrides.isNotEmpty || _variantOverrides.isNotEmpty;

  bool isOverridden(FlagKey<Object> flag) =>
      allowOverrides && _overrides.containsKey(flag.name);

  String? variantOverrideOf(Experiment experiment) =>
      allowOverrides ? _variantOverrides[experiment.key] : null;

  Future<void> setOverride<T>(FlagKey<T> flag, T? value) async {
    if (!allowOverrides) return;
    if (value == null) {
      _overrides.remove(flag.name);
    } else {
      _overrides[flag.name] = value;
    }
    await FeatureFlagStore.setOverrides(Map<String, dynamic>.from(_overrides));
  }

  Future<void> toggleOverride(BoolFlag flag) =>
      setOverride<bool>(flag, !isEnabled(flag));

  Future<void> setVariantOverride(
    Experiment experiment,
    String? variant,
  ) async {
    if (!allowOverrides) return;
    if (variant == null) {
      _variantOverrides.remove(experiment.key);
    } else {
      _variantOverrides[experiment.key] = variant;
    }
    await FeatureFlagStore.setVariantOverrides(
      Map<String, String>.from(_variantOverrides),
    );
  }

  Future<void> clearOverrides() async {
    _overrides.clear();
    _variantOverrides.clear();
    await FeatureFlagStore.clearOverrides();
  }

  /// Sign-out helper for user-specific documents. Leaves overrides alone.
  Future<void> clearCachedDocument() async {
    _remote.clear();
    _rollouts.clear();
    _experiments.clear();
    documentVersion.value = 0;
    lastFetchedAt.value = null;
    await FeatureFlagStore.clearDocument();
  }

  // ── Internals ──

  dynamic _overrideOf(String name) =>
      allowOverrides ? _overrides[name] : null;

  void _hydrateFromCache() {
    _overrides.assignAll(FeatureFlagStore.overrides);
    _variantOverrides.assignAll(FeatureFlagStore.variantOverrides);
    lastFetchedAt.value = FeatureFlagStore.fetchedAt;

    final raw = FeatureFlagStore.rawDocument;
    if (raw == null || raw.isEmpty) return;
    final doc = FlagDocument.tryParse(raw);
    if (doc == null) {
      devPrint('Flags: cached document unreadable, using hardcoded defaults');
      return;
    }
    _apply(doc);
  }

  void _apply(FlagDocument doc) {
    _remote.assignAll(doc.values);
    _rollouts.assignAll(doc.rollouts);
    _experiments.assignAll(doc.experiments);
    documentVersion.value = doc.version;
  }
}

/// Static passthrough that degrades to the hardcoded default when the service
/// is not registered. Reads through here are NOT reactive — inside an `Obx`,
/// use `FeatureFlagService.to` so the widget rebuilds when a flag flips.
class Flags {
  Flags._();

  static bool isEnabled(BoolFlag flag) =>
      FeatureFlagService.maybe?.isEnabled(flag) ?? flag.fallback;

  static bool isKilled(KillSwitch flag) => !isEnabled(flag);

  static int intOf(IntFlag flag) =>
      FeatureFlagService.maybe?.intOf(flag) ?? flag.fallback;

  static String stringOf(StringFlag flag) =>
      FeatureFlagService.maybe?.stringOf(flag) ?? flag.fallback;

  static Map<String, dynamic> jsonOf(JsonFlag flag) =>
      FeatureFlagService.maybe?.jsonOf(flag) ?? flag.fallback;

  static String? variantOf(Experiment experiment) =>
      FeatureFlagService.maybe?.variantOf(experiment);

  static String variantOrControl(Experiment experiment) =>
      variantOf(experiment) ?? experiment.control;
}
