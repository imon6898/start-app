import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_starter/app/feature/purchases/purchases_logic/purchases_catalog.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';

/// One selectable plan. Title, description and price all come from the store so
/// they are localised and in the user's currency.
class PurchaseProductTile extends StatelessWidget {
  final ProductDetails product;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const PurchaseProductTile({
    super.key,
    required this.product,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final PurchaseProductConfig? config = PurchasesCatalog.configFor(product.id);
    final Color border =
        selected ? CustomColors.primary() : CustomColors.stroke();

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: InkWell(
        borderRadius: BorderRadius.circular(R.r(10)),
        onTap: enabled ? onTap : null,
        child: Container(
          margin: R.margin(bottom: 12),
          padding: R.pad(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: CustomColors.card(),
            borderRadius: BorderRadius.circular(R.r(10)),
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _radio(),
              SizedBox(width: R.w(12)),
              Expanded(child: _details(config)),
              SizedBox(width: R.w(10)),
              _price(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radio() {
    return Icon(
      selected ? LucideIcons.circleCheck : LucideIcons.circle,
      size: R.w(20),
      color: selected ? CustomColors.primary() : CustomColors.textGray(),
    );
  }

  Widget _details(PurchaseProductConfig? config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                product.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CustomTextStyles.semiBold16.copyWith(
                  color: CustomColors.black(),
                ),
              ),
            ),
            if (config?.badge != null) ...[
              SizedBox(width: R.w(8)),
              _badge(config!.badge!),
            ],
          ],
        ),
        if (product.description.isNotEmpty) ...[
          SizedBox(height: R.h(4)),
          Text(
            product.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: CustomTextStyles.regular12.copyWith(
              color: CustomColors.paragraph(),
            ),
          ),
        ],
        if (config?.kind == PurchaseKind.nonConsumable) ...[
          SizedBox(height: R.h(4)),
          Text(
            'One-time purchase'.tr,
            style: CustomTextStyles.medium10.copyWith(
              color: CustomColors.textGray(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _badge(String label) {
    return Container(
      padding: R.pad(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CustomColors.badgeBlueBg(),
        borderRadius: BorderRadius.circular(R.r(20)),
      ),
      child: Text(
        label.tr,
        style: CustomTextStyles.medium10.copyWith(
          color: CustomColors.badgeBlue(),
        ),
      ),
    );
  }

  Widget _price() {
    return Text(
      product.price,
      style: CustomTextStyles.bold16.copyWith(color: CustomColors.primary()),
    );
  }
}
