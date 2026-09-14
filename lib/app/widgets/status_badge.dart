import 'package:flutter/material.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';

enum StatusTone { info, success, courier, warning, danger, neutral }

class StatusPalette {
  final Color fg;
  final Color bg;
  const StatusPalette(this.fg, this.bg);
}

StatusPalette statusPaletteFor(StatusTone tone) {
  switch (tone) {
    case StatusTone.success:
      return StatusPalette(CustomColors.success(), CustomColors.successBg());
    case StatusTone.courier:
      return StatusPalette(
          CustomColors.courierGreen(), CustomColors.courierGreenBg());
    case StatusTone.warning:
      return StatusPalette(
          CustomColors.warningOrange(), CustomColors.warningBg());
    case StatusTone.danger:
      return StatusPalette(CustomColors.error(), CustomColors.errorBg());
    case StatusTone.neutral:
      return StatusPalette(const Color(0xFF222222), CustomColors.gray());
    case StatusTone.info:
      return StatusPalette(CustomColors.badgeBlue(), CustomColors.badgeBlueBg());
  }
}

StatusTone statusToneFor(String status) {
  final s = status.trim().toLowerCase().replaceAll(' ', '_');
  switch (s) {
    case 'delivered':
    case 'completed':
    case 'dispatched':
    case 'prepaid':
    case 'paid':
    case 'success':
      return StatusTone.success;
    case 'in_transit':
    case 'in_transit_to_destination':
    case 'picked_up':
    case 'out_for_delivery':
    case 'courier':
    case 'delivery_attempted':
      return StatusTone.courier;
    case 'pending':
    case 'pending_pickup':
    case 'pickup_scheduled':
    case 'cod':
      return StatusTone.warning;
    case 'cancelled':
    case 'canceled':
    case 'failed':
    case 'failed_pickup':
    case 'failed_delivery':
    case 'returned':
    case 'returned_to_origin':
    case 'returned_to_customer':
    case 'return_to_origin_hub':
    case 'rider_declined':
    case 'declined':
      return StatusTone.danger;
    case 'ready_for_delivery':
    case 'draft':
    case 'closed':
      return StatusTone.neutral;
    // Support ticket lifecycle
    case 'open':
    case 'reopened':
      return StatusTone.warning;
    case 'in_progress':
      return StatusTone.courier;
    case 'resolved':
      return StatusTone.success;
    case 'created':
    case 'order_placed':
    case 'accepted':
    case 'assigned_rider':
    case 'assigned_rider_pickup':
    case 'arrived_at_hub':
    case 'at_origin_hub':
    case 'at_destination_hub':
    case 'standard':
    case 'ecommerce':
    case 'direct_hub_drop':
      return StatusTone.info;
    default:
      return StatusTone.info;
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusTone? tone;
  final double height;

  const StatusBadge({
    super.key,
    required this.label,
    this.tone,
    this.height = 26,
  });

  factory StatusBadge.fromStatus(String status, {String? labelOverride, double height = 26}) {
    final tone = statusToneFor(status);
    final display = (labelOverride ?? status).replaceAll('_', ' ').toUpperCase();
    return StatusBadge(label: display, tone: tone, height: height);
  }

  @override
  Widget build(BuildContext context) {
    final palette = statusPaletteFor(tone ?? StatusTone.info);
    return IntrinsicWidth(
      child: Container(
        height: R.h(height),
        padding: EdgeInsets.symmetric(horizontal: R.w(10)),
        decoration: BoxDecoration(
          color: palette.bg,
          borderRadius: BorderRadius.circular(R.r(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: R.w(5),
              height: R.h(5),
              decoration: BoxDecoration(
                color: palette.fg,
                borderRadius: BorderRadius.circular(R.r(6)),
              ),
            ),
            SizedBox(width: R.w(5)),
            Text(
              label,
              style: CustomTextStyles.medium12.copyWith(
                fontSize: R.sp(13),
                color: palette.fg,
                height: 1.0,
                letterSpacing: R.sp(13) * 0.0077,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
