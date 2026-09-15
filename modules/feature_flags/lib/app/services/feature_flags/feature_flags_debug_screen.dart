// QA screen: every flag, its resolved value, where that value came from, and a
// local override. GetBuilder(init:) scopes the controller to the screen, so no
// ViewModelBinding edit is needed to install the module.

import 'package:flutter/material.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:flutter_starter/app/widgets/feedback/custom_snack_bar.dart';
import 'package:flutter_starter/app/widgets/inputs/custom_text_field.dart';
import 'package:flutter_starter/app/widgets/layout/custom_bottom_sheet.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'feature_flag_keys.dart';
import 'feature_flag_resolver.dart';
import 'feature_flags_debug_controller.dart';

class FeatureFlagsDebugScreen extends StatelessWidget {
  const FeatureFlagsDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FeatureFlagsDebugController>(
      init: FeatureFlagsDebugController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: CustomColors.artboardColor(),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
            child: AppBarWidget(
              title: 'Feature flags'.tr,
              toolbarActions: [
                IconButton(
                  onPressed: controller.isReady ? controller.reload : null,
                  icon: Icon(
                    LucideIcons.refreshCw,
                    size: R.sp(20),
                    color: CustomColors.textPrimary(),
                  ),
                ),
              ],
            ),
          ),
          body: controller.isReady
              ? _body(context, controller)
              : _notRegistered(),
        );
      },
    );
  }

  Widget _notRegistered() {
    return Center(
      child: Padding(
        padding: R.pad(horizontal: 24),
        child: Text(
          'FeatureFlagService is not registered.'.tr,
          textAlign: TextAlign.center,
          style: CustomTextStyles.medium14.copyWith(
            color: CustomColors.textGray(),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, FeatureFlagsDebugController controller) {
    return Column(
      children: [
        _status(controller),
        _search(controller),
        Expanded(
          child: Obx(() {
            final flags = controller.visibleFlags;
            final experiments = controller.visibleExperiments;
            return ListView(
              padding: R.pad(horizontal: 16, bottom: 24),
              children: [
                if (flags.isNotEmpty) _sectionTitle('Flags'.tr),
                ...flags.map((flag) => _flagTile(context, controller, flag)),
                if (experiments.isNotEmpty) _sectionTitle('Experiments'.tr),
                ...experiments.map(
                  (experiment) => _experimentTile(controller, experiment),
                ),
                if (flags.isEmpty && experiments.isEmpty)
                  Padding(
                    padding: R.pad(vertical: 32),
                    child: Text(
                      'No data found'.tr,
                      textAlign: TextAlign.center,
                      style: CustomTextStyles.regular14.copyWith(
                        color: CustomColors.textGray(),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _status(FeatureFlagsDebugController controller) {
    return Container(
      width: double.infinity,
      margin: R.margin(horizontal: 16, top: 12),
      padding: R.pad(all: 12),
      decoration: BoxDecoration(
        color: CustomColors.card(),
        borderRadius: BorderRadius.circular(R.r(8)),
        border: Border.all(color: CustomColors.stroke()),
      ),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusRow(
              'Version'.tr,
              controller.flags.documentVersion.value.toString(),
            ),
            _statusRow('Last fetch'.tr, controller.lastFetchLabel),
            _statusRow('Bucketing id'.tr, controller.flags.bucketingId),
            if (controller.flags.lastError.value != null)
              _statusRow('Error'.tr, controller.flags.lastError.value!),
            if (!controller.flags.overridesEnabled)
              Padding(
                padding: R.pad(top: 8),
                child: Text(
                  'Overrides are disabled in release builds.'.tr,
                  style: CustomTextStyles.regular12.copyWith(
                    color: CustomColors.warningOrange(),
                  ),
                ),
              ),
            if (controller.flags.hasOverrides)
              Padding(
                padding: R.pad(top: 10),
                child: CustomButton(
                  text: 'Reset all overrides'.tr,
                  backgroundColor: CustomColors.error(),
                  onPressed: controller.clearAll,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: R.pad(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: R.w(100),
            child: Text(
              label,
              style: CustomTextStyles.regular12.copyWith(
                color: CustomColors.textGray(),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: CustomTextStyles.medium12.copyWith(
                color: CustomColors.textPrimary(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _search(FeatureFlagsDebugController controller) {
    return Padding(
      padding: R.pad(horizontal: 16, top: 12),
      child: CustomTextField(
        controller: controller.searchController,
        hintText: 'Search...'.tr,
        onChanged: controller.onQueryChanged,
        inputAction: TextInputAction.search,
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: R.pad(top: 20, bottom: 8),
      child: Text(
        title,
        style: CustomTextStyles.semiBold14.copyWith(
          color: CustomColors.textGray(),
        ),
      ),
    );
  }

  Widget _flagTile(
    BuildContext context,
    FeatureFlagsDebugController controller,
    FlagKey<Object> flag,
  ) {
    final boolFlag = flag is BoolFlag ? flag : null;
    return Container(
      margin: R.margin(bottom: 10),
      padding: R.pad(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CustomColors.white(),
        borderRadius: BorderRadius.circular(R.r(8)),
        border: Border.all(color: CustomColors.stroke()),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (flag is KillSwitch)
                      Padding(
                        padding: R.pad(right: 6),
                        child: Icon(
                          LucideIcons.power,
                          size: R.sp(14),
                          color: CustomColors.error(),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        flag.name,
                        style: CustomTextStyles.medium14.copyWith(
                          color: CustomColors.textPrimary(),
                        ),
                      ),
                    ),
                    _sourceBadge(controller, flag),
                  ],
                ),
                if (flag.description.isNotEmpty)
                  Padding(
                    padding: R.pad(top: 2),
                    child: Text(
                      flag.description,
                      style: CustomTextStyles.regular12.copyWith(
                        color: CustomColors.textGray(),
                      ),
                    ),
                  ),
                Obx(() {
                  final rollout = controller.flags.rolloutOf(flag);
                  return Padding(
                    padding: R.pad(top: 4),
                    child: Text(
                      rollout == null
                          ? controller.displayValue(flag)
                          : '${controller.displayValue(flag)}  ·  $rollout%',
                      style: CustomTextStyles.regular12.copyWith(
                        color: CustomColors.paragraph(),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          if (boolFlag != null)
            Obx(
              () => Switch(
                value: controller.flags.isEnabled(boolFlag),
                activeThumbColor: CustomColors.white(),
                activeTrackColor: CustomColors.primary(),
                onChanged: controller.flags.overridesEnabled
                    ? (_) => controller.toggle(boolFlag)
                    : null,
              ),
            )
          else
            IconButton(
              onPressed: controller.flags.overridesEnabled
                  ? () => _openEditor(context, controller, flag)
                  : null,
              icon: Icon(
                LucideIcons.settings2,
                size: R.sp(18),
                color: CustomColors.textPrimary(),
              ),
            ),
          Obx(
            () => controller.flags.isOverridden(flag)
                ? IconButton(
                    onPressed: () => controller.clearOverride(flag),
                    icon: Icon(
                      LucideIcons.rotateCcw,
                      size: R.sp(16),
                      color: CustomColors.error(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _sourceBadge(
    FeatureFlagsDebugController controller,
    FlagKey<Object> flag,
  ) {
    return Obx(() {
      final source = controller.flags.sourceOf(flag);
      final color = switch (source) {
        FlagSource.override => CustomColors.warningOrange(),
        FlagSource.remote => CustomColors.green(),
        FlagSource.fallback => CustomColors.textGray(),
      };
      return Container(
        padding: R.pad(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(R.r(4)),
        ),
        child: Text(
          controller.sourceLabel(flag),
          style: CustomTextStyles.medium10.copyWith(color: color),
        ),
      );
    });
  }

  Widget _experimentTile(
    FeatureFlagsDebugController controller,
    Experiment experiment,
  ) {
    return Container(
      margin: R.margin(bottom: 10),
      padding: R.pad(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CustomColors.white(),
        borderRadius: BorderRadius.circular(R.r(8)),
        border: Border.all(color: CustomColors.stroke()),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.flaskConical,
            size: R.sp(16),
            color: CustomColors.primary(),
          ),
          SizedBox(width: R.w(8)),
          Expanded(
            child: Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    experiment.key,
                    style: CustomTextStyles.medium14.copyWith(
                      color: CustomColors.textPrimary(),
                    ),
                  ),
                  Padding(
                    padding: R.pad(top: 2),
                    child: Text(
                      '${controller.variantLabel(experiment)}  ·  '
                      '${'Bucket'.tr} ${controller.flags.bucketOf(experiment)}',
                      style: CustomTextStyles.regular12.copyWith(
                        color: CustomColors.paragraph(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: controller.flags.overridesEnabled
                ? () => controller.cycleVariant(experiment)
                : null,
            icon: Icon(
              LucideIcons.toggleRight,
              size: R.sp(18),
              color: CustomColors.textPrimary(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    FeatureFlagsDebugController controller,
    FlagKey<Object> flag,
  ) async {
    controller.valueController.text = controller.displayValue(flag);
    await showCustomBottomSheet<void>(
      sheetTitle: flag.name,
      height: R.h(300),
      content: SingleChildScrollView(
        padding: R.pad(horizontal: 16, top: 16, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              controller: controller.valueController,
              textHeading: 'Local value'.tr,
              hintText: flag.fallback.toString(),
              inputType: flag.type == FlagType.integer
                  ? TextInputType.number
                  : TextInputType.text,
              maxLines: flag.type == FlagType.json ? 4 : 1,
              inputAction: TextInputAction.done,
            ),
            SizedBox(height: R.h(16)),
            CustomButton(
              text: 'Save'.tr,
              height: 44,
              onPressed: () async {
                final ok = await controller.applyTextOverride(
                  flag,
                  controller.valueController.text,
                );
                if (!context.mounted) return;
                if (!ok) {
                  showCustomSnackBar(
                    context: context,
                    type: SnackBarType.Failure,
                    title: 'Invalid value'.tr,
                    description: 'It does not match the flag type.'.tr,
                  );
                  return;
                }
                Get.back();
              },
            ),
            SizedBox(height: R.h(10)),
            CustomButton(
              text: 'Clear override'.tr,
              height: 44,
              backgroundColor: CustomColors.gray(),
              onPressed: () async {
                await controller.clearOverride(flag);
                Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }
}
