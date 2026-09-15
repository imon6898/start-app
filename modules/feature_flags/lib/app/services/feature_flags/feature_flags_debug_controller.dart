// Drives the QA debug screen. Lives next to the service on purpose: it is dev
// tooling, so installing the module needs no ViewModelBinding entry.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_starter/app/widgets/feedback/custom_snack_bar.dart';
import 'package:get/get.dart';

import 'feature_flag_keys.dart';
import 'feature_flag_resolver.dart';
import 'feature_flag_service.dart';

class FeatureFlagsDebugController extends GetxController {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController valueController = TextEditingController();
  final RxString query = ''.obs;

  /// False when nobody registered the service — show a hint instead of throwing.
  bool get isReady => Get.isRegistered<FeatureFlagService>();

  FeatureFlagService get flags => FeatureFlagService.to;

  List<FlagKey<Object>> get visibleFlags =>
      FeatureFlags.all.where(_matchesFlag).toList();

  List<Experiment> get visibleExperiments =>
      FeatureFlags.experiments.where(_matchesExperiment).toList();

  void onQueryChanged(String value) => query.value = value;

  Future<void> reload() async {
    final ok = await flags.refresh();
    final context = Get.context;
    if (context == null || !context.mounted) return;
    showCustomSnackBar(
      context: context,
      type: ok ? SnackBarType.Success : SnackBarType.Failure,
      title: ok ? 'Flags updated'.tr : 'Flag fetch failed'.tr,
      description: ok
          ? 'The document was refreshed from the backend.'.tr
          : 'Cached values are still in use.'.tr,
    );
  }

  Future<void> toggle(BoolFlag flag) => flags.toggleOverride(flag);

  Future<void> clearOverride(FlagKey<Object> flag) =>
      flags.setOverride<Object>(flag, null);

  Future<void> clearAll() => flags.clearOverrides();

  /// Parses [text] against the flag's declared type. false means "did not fit" —
  /// the caller keeps the sheet open and says so.
  Future<bool> applyTextOverride(FlagKey<Object> flag, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      await clearOverride(flag);
      return true;
    }
    final parsed = FlagResolver.coerce<Object>(flag, trimmed);
    if (parsed == null) return false;
    await flags.setOverride<Object>(flag, parsed);
    return true;
  }

  /// Cycles none -> variant 1 -> variant 2 -> none, so QA can see every arm.
  Future<void> cycleVariant(Experiment experiment) async {
    final options = <String?>[null, ...experiment.variants];
    final current = flags.variantOverrideOf(experiment);
    final next = options[(options.indexOf(current) + 1) % options.length];
    await flags.setVariantOverride(experiment, next);
  }

  String displayValue(FlagKey<Object> flag) {
    final value = flags.valueOf<Object>(flag);
    return value is Map ? jsonEncode(value) : value.toString();
  }

  String sourceLabel(FlagKey<Object> flag) => switch (flags.sourceOf(flag)) {
    FlagSource.override => 'override'.tr,
    FlagSource.remote => 'remote'.tr,
    FlagSource.fallback => 'default'.tr,
  };

  String variantLabel(Experiment experiment) =>
      flags.variantOf(experiment) ?? 'Not enrolled'.tr;

  String get lastFetchLabel {
    final at = flags.lastFetchedAt.value;
    if (at == null) return 'never'.tr;
    return '${_two(at.hour)}:${_two(at.minute)}:${_two(at.second)}';
  }

  bool _matchesFlag(FlagKey<Object> flag) =>
      _matches(flag.name) || _matches(flag.description);

  bool _matchesExperiment(Experiment experiment) =>
      _matches(experiment.key) || _matches(experiment.description);

  bool _matches(String value) {
    final q = query.value.trim().toLowerCase();
    return q.isEmpty || value.toLowerCase().contains(q);
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  @override
  void onClose() {
    searchController.dispose();
    valueController.dispose();
    super.onClose();
  }
}
