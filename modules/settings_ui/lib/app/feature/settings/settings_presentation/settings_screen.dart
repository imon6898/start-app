import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_starter/app/feature/settings/settings_controllers/settings_controller.dart';
import 'package:flutter_starter/app/feature/settings/settings_logic/settings_links.dart';
import 'package:flutter_starter/app/routes/app_routes.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/feedback/delete_confirmation_dialog.dart';
import 'package:flutter_starter/app/widgets/layout/custom_bottom_sheet.dart';
import 'package:flutter_starter/app/widgets/layout/layout_components.dart';

/// Settings screen — theme, language, notifications, about, cache and logout.
/// Built from the shared widget kit: SectionHeader, CardContainer,
/// CustomDivider, showCustomBottomSheet, showDeleteConfirmationDialog.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SettingsController>(
      builder: (c) {
        return Scaffold(
          backgroundColor: CustomColors.artboardColor(),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
            child: AppBarWidget(
              title: 'Settings'.tr,
              backgroundColor: CustomColors.transparent(),
              elevation: 0,
            ),
          ),
          body: _body(context, c),
        );
      },
    );
  }

  Widget _body(BuildContext context, SettingsController controller) {
    return SingleChildScrollView(
      padding: R.pad(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildAppearanceSection(context, controller),
          buildNotificationSection(context, controller),
          buildAboutSection(context, controller),
          buildDataSection(context, controller),
          buildAccountSection(context, controller),
        ],
      ),
    );
  }

  // ── Sections ──

  Widget buildAppearanceSection(
    BuildContext context,
    SettingsController controller,
  ) {
    return _section(
      title: 'Appearance'.tr,
      children: [
        _row(
          icon: LucideIcons.palette,
          title: 'Theme'.tr,
          value: controller.themeLabel(controller.themeMode).tr,
          onTap: () => _pickTheme(controller),
        ),
        const CustomDivider(),
        _row(
          icon: LucideIcons.languages,
          title: 'Language'.tr,
          value: controller.languageLabel(controller.locale),
          onTap: () => _pickLanguage(controller),
        ),
      ],
    );
  }

  Widget buildNotificationSection(
    BuildContext context,
    SettingsController controller,
  ) {
    return _section(
      title: 'Notifications'.tr,
      children: [
        _row(
          icon: LucideIcons.bell,
          title: 'Push notifications'.tr,
          trailing: Obx(
            () => Switch.adaptive(
              value: controller.notificationsEnabled.value,
              activeThumbColor: CustomColors.primary(),
              onChanged: controller.setNotifications,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildAboutSection(
    BuildContext context,
    SettingsController controller,
  ) {
    return _section(
      title: 'About'.tr,
      children: [
        _row(
          icon: LucideIcons.info,
          title: 'App version'.tr,
          trailing: Obx(
            () => Text(
              controller.appVersion.value.isEmpty
                  ? '—'
                  : controller.appVersion.value,
              style: CustomTextStyles.regular14.copyWith(
                color: CustomColors.textGrayDark(),
              ),
            ),
          ),
        ),
        const CustomDivider(),
        _row(
          icon: LucideIcons.shieldCheck,
          title: 'Privacy Policy'.tr,
          onTap: () => controller.openLink(
            context,
            SettingsLinks.privacyPolicy,
            fallbackRoute: AppRoutes.PrivacyPolicyScreen,
          ),
        ),
        const CustomDivider(),
        _row(
          icon: LucideIcons.fileText,
          title: 'Terms of Service'.tr,
          onTap: () => controller.openLink(
            context,
            SettingsLinks.termsOfService,
            fallbackRoute: AppRoutes.TermsOfServiceScreen,
          ),
        ),
      ],
    );
  }

  Widget buildDataSection(BuildContext context, SettingsController controller) {
    return _section(
      title: 'Storage'.tr,
      children: [
        _row(
          icon: LucideIcons.database,
          title: 'Clear cache'.tr,
          trailing: Obx(
            () => controller.isClearingCache.value
                ? SizedBox(
                    width: R.w(16),
                    height: R.w(16),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CustomColors.primary(),
                    ),
                  )
                : Icon(
                    LucideIcons.chevronRight,
                    size: R.h(18),
                    color: CustomColors.textGrayDark(),
                  ),
          ),
          onTap: () => showDeleteConfirmationDialog(
            title: 'Clear cache?'.tr,
            message: 'Cached images and temporary files will be removed.'.tr,
            confirmText: 'Clear'.tr,
            cancelText: 'Cancel'.tr,
            onConfirm: () => controller.clearCache(context),
          ),
        ),
      ],
    );
  }

  Widget buildAccountSection(
    BuildContext context,
    SettingsController controller,
  ) {
    return _section(
      title: 'Account'.tr,
      children: [
        _row(
          icon: LucideIcons.logOut,
          title: 'Log out'.tr,
          tint: CustomColors.error(),
          trailing: Obx(
            () => controller.isLoggingOut.value
                ? SizedBox(
                    width: R.w(16),
                    height: R.w(16),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CustomColors.error(),
                    ),
                  )
                : Icon(
                    LucideIcons.chevronRight,
                    size: R.h(18),
                    color: CustomColors.error(),
                  ),
          ),
          onTap: () {
            FocusScope.of(context).unfocus();
            showDeleteConfirmationDialog(
              title: 'Log out?'.tr,
              message: 'You will need to sign in again to continue.'.tr,
              confirmText: 'Log out'.tr,
              cancelText: 'Cancel'.tr,
              onConfirm: controller.logout,
            );
          },
        ),
      ],
    );
  }

  // ── Pickers ──

  Future<void> _pickTheme(SettingsController controller) async {
    await showCustomBottomSheet<void>(
      sheetTitle: 'Theme'.tr,
      height: R.h(260),
      content: ListView(
        padding: R.pad(horizontal: 16, vertical: 4),
        children: ThemeMode.values.map((mode) {
          return _option(
            icon: _themeIcon(mode),
            label: controller.themeLabel(mode).tr,
            selected: controller.themeMode == mode,
            onTap: () async {
              Get.back<void>();
              await controller.changeTheme(mode);
            },
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickLanguage(SettingsController controller) async {
    await showCustomBottomSheet<void>(
      sheetTitle: 'Language'.tr,
      height: R.h(260),
      content: ListView(
        padding: R.pad(horizontal: 16, vertical: 4),
        children: controller.supportedLocales.map((value) {
          return _option(
            icon: LucideIcons.globe,
            label: controller.languageLabel(value),
            selected: value.languageCode == controller.locale.languageCode,
            onTap: () async {
              Get.back<void>();
              await controller.changeLocale(value);
            },
          );
        }).toList(),
      ),
    );
  }

  IconData _themeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return LucideIcons.sun;
      case ThemeMode.dark:
        return LucideIcons.moon;
      case ThemeMode.system:
        return LucideIcons.smartphone;
    }
  }

  // ── Building blocks ──

  /// SectionHeader + a CardContainer holding the rows.
  Widget _section({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title, padding: R.pad(horizontal: 20, top: 16)),
        CardContainer(
          margin: R.margin(horizontal: 16, top: 4),
          padding: R.pad(horizontal: 12, vertical: 4),
          borderRadius: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    String? value,
    Widget? trailing,
    VoidCallback? onTap,
    Color? tint,
  }) {
    final Color labelColor = tint ?? CustomColors.black();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: R.pad(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: R.h(20), color: tint ?? CustomColors.primary()),
            SizedBox(width: R.w(12)),
            Expanded(
              child: Text(
                title,
                style: CustomTextStyles.medium14.copyWith(color: labelColor),
              ),
            ),
            if (value != null) ...[
              Text(
                value,
                style: CustomTextStyles.regular14.copyWith(
                  color: CustomColors.textGrayDark(),
                ),
              ),
              SizedBox(width: R.w(6)),
            ],
            if (trailing != null)
              trailing
            else if (onTap != null)
              Icon(
                LucideIcons.chevronRight,
                size: R.h(18),
                color: CustomColors.textGrayDark(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _option({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: R.pad(vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: R.h(20),
              color: selected
                  ? CustomColors.primary()
                  : CustomColors.textGrayDark(),
            ),
            SizedBox(width: R.w(12)),
            Expanded(
              child: Text(
                label,
                style: CustomTextStyles.medium14.copyWith(
                  color: CustomColors.black(),
                ),
              ),
            ),
            if (selected)
              Icon(
                LucideIcons.check,
                size: R.h(18),
                color: CustomColors.primary(),
              ),
          ],
        ),
      ),
    );
  }
}
