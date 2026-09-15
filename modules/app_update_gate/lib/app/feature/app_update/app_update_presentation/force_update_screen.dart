import 'package:flutter/material.dart';
import 'package:flutter_starter/app/feature/app_update/app_update_controllers/app_update_controller.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Blocking gate. No app bar, no back button, no way past it but the store.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppUpdateController>(
      builder: (controller) {
        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: CustomColors.artboardColor(),
            body: SafeArea(
              child: Padding(
                padding: R.pad(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBadge(context),
                    SizedBox(height: R.h(28)),
                    _buildCopy(context, controller),
                    SizedBox(height: R.h(32)),
                    _buildAction(context, controller),
                    SizedBox(height: R.h(16)),
                    _buildVersionLine(context, controller),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(BuildContext context) {
    return Container(
      width: R.w(96),
      height: R.w(96),
      decoration: BoxDecoration(
        color: CustomColors.primary().withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        LucideIcons.circleArrowUp,
        size: R.h(44),
        color: CustomColors.primary(),
      ),
    );
  }

  Widget _buildCopy(BuildContext context, AppUpdateController controller) {
    final info = controller.info;
    final title = info?.title.isNotEmpty == true
        ? info!.title
        : 'Update required'.tr;
    final message = info?.message.isNotEmpty == true
        ? info!.message
        : 'This version of the app is no longer supported. Please update to continue.'
              .tr;

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: CustomTextStyles.semiBold22.copyWith(
            color: CustomColors.textPrimary(),
          ),
        ),
        SizedBox(height: R.h(10)),
        Text(
          message,
          textAlign: TextAlign.center,
          style: CustomTextStyles.regular14.copyWith(
            color: CustomColors.paragraph(),
          ),
        ),
        if (info != null && info.releaseNotes.isNotEmpty) ...[
          SizedBox(height: R.h(18)),
          _buildReleaseNotes(info.releaseNotes),
        ],
      ],
    );
  }

  Widget _buildReleaseNotes(List<String> notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: notes
          .map(
            (note) => Padding(
              padding: R.pad(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.sparkles,
                    size: R.h(14),
                    color: CustomColors.primary(),
                  ),
                  SizedBox(width: R.w(8)),
                  Expanded(
                    child: Text(
                      note,
                      style: CustomTextStyles.regular12.copyWith(
                        color: CustomColors.paragraph(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAction(BuildContext context, AppUpdateController controller) {
    return SizedBox(
      width: double.infinity,
      child: Obx(
        () => CustomButton(
          text: 'Update now'.tr,
          height: 48,
          borderRadius: R.r(10),
          loading: controller.isLaunchingStore.value,
          icon: Icon(
            LucideIcons.download,
            size: R.h(18),
            color: CustomColors.white(),
          ),
          onPressed: controller.openStore,
        ),
      ),
    );
  }

  Widget _buildVersionLine(BuildContext context, AppUpdateController ctrl) {
    final latest = ctrl.info?.latestVersion ?? '';
    final line = latest.isEmpty
        ? '${'Installed'.tr}: ${ctrl.currentVersion}'
        : '${'Installed'.tr}: ${ctrl.currentVersion}   •   ${'Latest'.tr}: $latest';

    return Text(
      line,
      textAlign: TextAlign.center,
      style: CustomTextStyles.regular12.copyWith(
        color: CustomColors.textGray(),
      ),
    );
  }
}
