import 'package:flutter/material.dart';
import 'package:flutter_starter/app/themes/tokens/tokens.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/inputs/custom_text_field.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../catalog_controllers/catalog_controller.dart';

/// Tab switch, the three preview toggles, search and group filter.
class CatalogToolbar extends StatelessWidget {
  final CatalogController controller;
  final List<String> groups;

  const CatalogToolbar({
    super.key,
    required this.controller,
    required this.groups,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: R.pad(horizontal: 16, top: 12, bottom: 10),
      color: DsRole.surface(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tabs(),
          SizedBox(height: R.h(DsSpace.md)),
          _toggles(),
          SizedBox(height: R.h(DsSpace.md)),
          Obx(() => controller.tab.value == 0
              ? _componentFilters()
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Obx(
      () => Row(
        children: [
          _tab('Components', LucideIcons.blocks, 0),
          SizedBox(width: R.w(DsSpace.sm)),
          _tab('Tokens', LucideIcons.palette, 1),
        ],
      ),
    );
  }

  Widget _tab(String label, IconData icon, int index) {
    final selected = controller.tab.value == index;
    return _pill(
      label: label,
      icon: icon,
      selected: selected,
      onTap: () => controller.tab.value = index,
    );
  }

  Widget _toggles() {
    return Obx(
      () => Wrap(
        spacing: R.w(DsSpace.sm),
        runSpacing: R.h(DsSpace.sm),
        children: [
          _pill(
            label: controller.theme.isDarkMode ? 'Dark' : 'Light',
            icon: controller.theme.isDarkMode
                ? LucideIcons.moon
                : LucideIcons.sun,
            selected: controller.theme.isDarkMode,
            onTap: controller.toggleTheme,
          ),
          _pill(
            label: '${controller.textScale.value}x',
            icon: LucideIcons.type,
            selected: controller.textScale.value != 1.0,
            onTap: controller.cycleTextScale,
          ),
          _pill(
            label: controller.localeTag.value.isEmpty
                ? 'locale'
                : controller.localeTag.value,
            icon: LucideIcons.languages,
            selected: false,
            onTap: controller.cycleLocale,
          ),
        ],
      ),
    );
  }

  Widget _componentFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          hintText: 'Search widgets',
          controller: controller.searchController,
          onChanged: controller.onQueryChanged,
          borderRadius: R.r(DsRadius.md),
          inputAction: TextInputAction.search,
        ),
        SizedBox(height: R.h(DsSpace.sm)),
        Obx(
          () => Wrap(
            spacing: R.w(DsSpace.sm),
            runSpacing: R.h(DsSpace.sm),
            children: groups
                .map(
                  (g) => _pill(
                    label: g,
                    selected: controller.group.value == g,
                    onTap: () => controller.selectGroup(g),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.r(DsRadius.pill)),
      child: Container(
        padding: R.pad(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? DsRole.accent() : DsPalette.surfaceSunken.value,
          borderRadius: BorderRadius.circular(R.r(DsRadius.pill)),
          border: Border.all(
            color: selected ? DsRole.accent() : DsRole.border(),
            width: DsBorderWidth.thin,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: R.w(DsIconSize.sm),
                color: selected ? DsRole.onAccent() : DsRole.onSurfaceMuted(),
              ),
              SizedBox(width: R.w(DsSpace.xs)),
            ],
            Text(
              label,
              style: CustomTextStyles.medium12.copyWith(
                color: selected ? DsRole.onAccent() : DsRole.onSurface(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
