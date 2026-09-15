import 'package:flutter/material.dart';
import 'package:flutter_starter/app/themes/tokens/tokens.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/layout/layout_components.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../catalog_models/catalog_entry.dart';

/// One card per catalogued widget: name, source path, optional gotcha, and the
/// live demo on a sunken surface so padding and shadows are visible.
class CatalogCase extends StatelessWidget {
  final CatalogEntry entry;

  const CatalogCase({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      margin: R.margin(horizontal: 16, bottom: 12),
      padding: EdgeInsets.zero,
      backgroundColor: DsRole.surface(),
      borderRadius: R.r(DsRadius.lg),
      boxShadow: DsElevation.low.value,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_header(), _preview(context)],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: R.pad(horizontal: 14, top: 12, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.name,
            style: CustomTextStyles.semiBold14.copyWith(
              color: DsRole.onSurface(),
            ),
          ),
          SizedBox(height: R.h(DsSpace.xxs)),
          Text(
            entry.source,
            style: CustomTextStyles.regular10.copyWith(
              color: DsRole.onSurfaceMuted(),
            ),
          ),
          if (entry.note != null) ...[
            SizedBox(height: R.h(DsSpace.sm)),
            _note(entry.note!),
          ],
        ],
      ),
    );
  }

  Widget _note(String note) {
    return Container(
      padding: R.pad(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: DsPalette.infoBg.value,
        borderRadius: BorderRadius.circular(R.r(DsRadius.sm)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.info,
            size: R.w(DsIconSize.sm),
            color: DsPalette.infoFg.value,
          ),
          SizedBox(width: R.w(DsSpace.sm)),
          Expanded(
            child: Text(
              note,
              style: CustomTextStyles.regular12.copyWith(
                color: DsPalette.infoFg.value,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: R.pad(all: 14),
      decoration: BoxDecoration(
        color: DsPalette.surfaceSunken.value,
        border: Border(
          top: BorderSide(
            color: DsRole.borderSubtle(),
            width: DsBorderWidth.thin,
          ),
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(R.r(DsRadius.lg)),
        ),
      ),
      child: entry.demo(context),
    );
  }
}
