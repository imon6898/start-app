import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_starter/app/feature/purchases/purchases_models/entitlement_model.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';

/// Shows what the server last said about this account's access.
class EntitlementBanner extends StatelessWidget {
  final EntitlementModel entitlement;

  /// Days since the last server confirmation; null when the value is fresh.
  final int? cacheAgeInDays;

  const EntitlementBanner({
    super.key,
    required this.entitlement,
    this.cacheAgeInDays,
  });

  @override
  Widget build(BuildContext context) {
    if (entitlement.state == EntitlementState.none) {
      return const SizedBox.shrink();
    }

    final _BannerStyle style = _styleFor(entitlement.state);

    return Container(
      padding: R.pad(all: 12),
      margin: R.margin(bottom: 16),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(R.r(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, size: R.w(18), color: style.foreground),
          SizedBox(width: R.w(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style.title,
                  style: CustomTextStyles.semiBold14.copyWith(
                    color: style.foreground,
                  ),
                ),
                if (_subtitle != null) ...[
                  SizedBox(height: R.h(2)),
                  Text(
                    _subtitle!,
                    style: CustomTextStyles.regular12.copyWith(
                      color: style.foreground,
                    ),
                  ),
                ],
                if (cacheAgeInDays != null) ...[
                  SizedBox(height: R.h(4)),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.cloudOff,
                        size: R.w(12),
                        color: style.foreground,
                      ),
                      SizedBox(width: R.w(4)),
                      Text(
                        cacheAgeInDays == 0
                            ? 'Offline — using the last confirmed status'.tr
                            : '${'Offline — last confirmed'.tr} '
                                '$cacheAgeInDays ${'days ago'.tr}',
                        style: CustomTextStyles.regular10.copyWith(
                          color: style.foreground,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? get _subtitle {
    final DateTime? expires = entitlement.expiresAt;
    if (expires == null) return null;
    final String date = DateFormat.yMMMd().format(expires.toLocal());
    return entitlement.willRenew
        ? '${'Renews on'.tr} $date'
        : '${'Access ends on'.tr} $date';
  }

  _BannerStyle _styleFor(EntitlementState state) {
    switch (state) {
      case EntitlementState.active:
        return _BannerStyle(
          icon: LucideIcons.badgeCheck,
          title: 'Subscription active'.tr,
          foreground: CustomColors.success(),
          background: CustomColors.successBg(),
        );
      case EntitlementState.trial:
        return _BannerStyle(
          icon: LucideIcons.sparkles,
          title: 'Free trial active'.tr,
          foreground: CustomColors.success(),
          background: CustomColors.successBg(),
        );
      case EntitlementState.gracePeriod:
        return _BannerStyle(
          icon: LucideIcons.triangleAlert,
          title: 'Payment problem'.tr,
          foreground: CustomColors.warningOrange(),
          background: CustomColors.warningBg(),
        );
      case EntitlementState.onHold:
        return _BannerStyle(
          icon: LucideIcons.ban,
          title: 'Subscription on hold'.tr,
          foreground: CustomColors.error(),
          background: CustomColors.errorBg(),
        );
      case EntitlementState.paused:
        return _BannerStyle(
          icon: LucideIcons.pause,
          title: 'Subscription paused'.tr,
          foreground: CustomColors.warningOrange(),
          background: CustomColors.warningBg(),
        );
      case EntitlementState.pending:
        return _BannerStyle(
          icon: LucideIcons.hourglass,
          title: 'Waiting for approval'.tr,
          foreground: CustomColors.warningOrange(),
          background: CustomColors.warningBg(),
        );
      case EntitlementState.refunded:
        return _BannerStyle(
          icon: LucideIcons.ban,
          title: 'Purchase refunded'.tr,
          foreground: CustomColors.error(),
          background: CustomColors.errorBg(),
        );
      case EntitlementState.expired:
      case EntitlementState.none:
        return _BannerStyle(
          icon: LucideIcons.clock,
          title: 'Subscription expired'.tr,
          foreground: CustomColors.textGrayDark(),
          background: CustomColors.lightGrey(),
        );
    }
  }
}

class _BannerStyle {
  final IconData icon;
  final String title;
  final Color foreground;
  final Color background;

  const _BannerStyle({
    required this.icon,
    required this.title,
    required this.foreground,
    required this.background,
  });
}
