import 'package:flutter/material.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:flutter_starter/app/widgets/layout/layout_components.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../catalog_controllers/catalog_controller.dart';
import '../catalog_models/catalog_entry.dart';
import 'catalog_registry.dart';
import 'catalog_tokens_view.dart';
import 'catalog_widgets/catalog_case.dart';
import 'catalog_widgets/catalog_toolbar.dart';

/// Debug-only storybook: every widget in the kit, plus the token gallery.
/// Chrome here is intentionally not `.tr` — it is developer copy, not product
/// copy, and the localisation guardrail expects only shipped strings.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CatalogController>(
      builder: (controller) {
        final entries = CatalogRegistry.entries(controller);
        return Scaffold(
          backgroundColor: CustomColors.artboardColor(),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
            child: const AppBarWidget(
              title: 'Design system',
              isBackForcefullyShow: true,
            ),
          ),
          body: Obx(
            () => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(controller.textScale.value),
              ),
              child: _body(controller, entries),
            ),
          ),
        );
      },
    );
  }

  Widget _body(CatalogController controller, List<CatalogEntry> entries) {
    return Column(
      children: [
        CatalogToolbar(
          controller: controller,
          groups: controller.groupsOf(entries),
        ),
        Expanded(
          child: Obx(
            () => controller.tab.value == 0
                ? _components(controller, entries)
                : const CatalogTokensView(),
          ),
        ),
      ],
    );
  }

  Widget _components(CatalogController controller, List<CatalogEntry> entries) {
    final visible = controller.filter(entries);
    if (visible.isEmpty) {
      // Scrollable so it cannot overflow a short window or a 2.0x text scale.
      return SingleChildScrollView(
        child: EmptyStateWidget(
          icon: LucideIcons.search,
          title: 'No widget matches',
          subtitle: 'Clear the search box or tap the active group chip again.',
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomButton(text: 'Clear', onPressed: controller.clearQuery),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: R.pad(top: 12, bottom: 32),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final entry = visible[index];
        final startsGroup =
            index == 0 || visible[index - 1].group != entry.group;
        return Column(
          children: [
            if (startsGroup) SectionHeader(title: entry.group),
            CatalogCase(entry: entry),
          ],
        );
      },
    );
  }
}
