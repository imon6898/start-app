import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_starter/app/feature/payment/payment_controllers/payment_controller.dart';
import 'package:flutter_starter/app/feature/payment/payment_models/payment_result.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:flutter_starter/app/widgets/feedback/status_badge.dart';
import 'package:flutter_starter/app/widgets/feedback/success_dialog.dart';
import 'package:flutter_starter/app/widgets/layout/layout_components.dart';

/// Icon, colours and copy for one outcome.
class _ResultStyle {
  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String message;

  const _ResultStyle({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.message,
  });
}

/// Exhaustive because [PaymentResult] is sealed.
_ResultStyle _styleFor(PaymentResult result) => switch (result) {
  PaymentSuccess() => _ResultStyle(
    icon: LucideIcons.circleCheck,
    color: CustomColors.success(),
    background: CustomColors.successBg(),
    title: 'Payment successful'.tr,
    // Settlement is confirmed by the Stripe webhook, not by this screen.
    message:
        'Your payment was submitted. We will confirm your order as soon as Stripe notifies our server.'
            .tr,
  ),
  PaymentCancelled() => _ResultStyle(
    icon: LucideIcons.ban,
    color: CustomColors.warningOrange(),
    background: CustomColors.warningBg(),
    title: 'Payment cancelled'.tr,
    message: 'You closed the payment sheet. Nothing was charged.'.tr,
  ),
  PaymentFailed(:final message) => _ResultStyle(
    icon: LucideIcons.circleX,
    color: CustomColors.error(),
    background: CustomColors.errorBg(),
    title: 'Payment failed'.tr,
    message: message.isEmpty
        ? 'We could not complete your payment. Please try again.'.tr
        : message,
  ),
};

/// Outcome screen for one checkout attempt.
class PaymentResultScreen extends StatelessWidget {
  final PaymentResult result;

  /// Where to go when the customer is done; defaults to popping this screen.
  final VoidCallback? onDone;

  /// Retry action for a failed or cancelled attempt; defaults to going back.
  final VoidCallback? onRetry;

  const PaymentResultScreen({
    super.key,
    required this.result,
    this.onDone,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PaymentController>(
      builder: (c) {
        return Scaffold(
          backgroundColor: CustomColors.artboardColor(),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
            child: AppBarWidget(
              title: 'Payment'.tr,
              backgroundColor: CustomColors.transparent(),
              elevation: 0,
              isBackEnable: false,
            ),
          ),
          body: _body(context, c),
        );
      },
    );
  }

  Widget _body(BuildContext context, PaymentController controller) {
    final _ResultStyle style = _styleFor(result);

    return SingleChildScrollView(
      padding: R.pad(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: R.h(20)),
          _buildStatusIcon(context, style),
          SizedBox(height: R.h(20)),
          Text(
            style.title,
            textAlign: TextAlign.center,
            style: CustomTextStyles.semiBold20.copyWith(
              color: CustomColors.black(),
            ),
          ),
          SizedBox(height: R.h(8)),
          Text(
            style.message,
            textAlign: TextAlign.center,
            style: CustomTextStyles.regular14.copyWith(
              color: CustomColors.paragraph(),
            ),
          ),
          SizedBox(height: R.h(24)),
          buildDetails(context, controller),
          SizedBox(height: R.h(32)),
          buildActions(context, controller),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context, _ResultStyle style) {
    return Container(
      width: R.w(88),
      height: R.w(88),
      decoration: BoxDecoration(
        color: style.background,
        shape: BoxShape.circle,
      ),
      child: Icon(style.icon, size: R.w(44), color: style.color),
    );
  }

  /// Reference details, shown only when the backend gave us something to show.
  Widget buildDetails(BuildContext context, PaymentController controller) {
    return switch (result) {
      PaymentSuccess(:final paymentIntentId, :final status) => _successDetails(
        context,
        paymentIntentId,
        status,
      ),
      PaymentFailed(:final declineCode) => _declineDetails(
        context,
        declineCode,
      ),
      PaymentCancelled() => const SizedBox.shrink(),
    };
  }

  Widget _successDetails(
    BuildContext context,
    String? reference,
    String? status,
  ) {
    final String intentId = reference ?? '';
    final String intentStatus = status ?? '';
    if (intentId.isEmpty && intentStatus.isEmpty) {
      return const SizedBox.shrink();
    }

    return CardContainer(
      padding: R.pad(all: 16),
      backgroundColor: CustomColors.card(),
      child: Column(
        children: [
          if (intentId.isNotEmpty)
            buildDetailRow(context, 'Reference'.tr, valueText: intentId),
          if (intentId.isNotEmpty && intentStatus.isNotEmpty)
            CustomDivider(
              margin: R.margin(vertical: 8),
              color: CustomColors.stroke(),
            ),
          if (intentStatus.isNotEmpty)
            buildDetailRow(
              context,
              'Status'.tr,
              valueWidget: StatusBadge.fromStatus(intentStatus),
            ),
        ],
      ),
    );
  }

  Widget _declineDetails(BuildContext context, String? declineCode) {
    final String code = declineCode ?? '';
    if (code.isEmpty) return const SizedBox.shrink();
    return CardContainer(
      padding: R.pad(all: 16),
      backgroundColor: CustomColors.card(),
      child: buildDetailRow(context, 'Decline code'.tr, valueText: code),
    );
  }

  Widget buildDetailRow(
    BuildContext context,
    String label, {
    String? valueText,
    Widget? valueWidget,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: CustomTextStyles.regular14.copyWith(
            color: CustomColors.textGray(),
          ),
        ),
        SizedBox(width: R.w(12)),
        Flexible(
          child:
              valueWidget ??
              Text(
                valueText ?? '',
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: CustomTextStyles.medium14.copyWith(
                  color: CustomColors.black(),
                ),
              ),
        ),
      ],
    );
  }

  Widget buildActions(BuildContext context, PaymentController controller) {
    final bool canRetry = result is! PaymentSuccess;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: R.h(48),
          child: CustomButton(
            text: canRetry ? 'Try again'.tr : 'Done'.tr,
            borderRadius: R.r(8),
            textStyle: CustomTextStyles.medium16.copyWith(
              color: CustomColors.white(),
            ),
            onPressed: () {
              if (canRetry) {
                controller.reset();
                if (onRetry != null) {
                  onRetry!();
                  return;
                }
              } else if (onDone != null) {
                onDone!();
                return;
              }
              Get.back();
            },
          ),
        ),
        if (canRetry) ...[
          SizedBox(height: R.h(12)),
          SizedBox(
            width: double.infinity,
            height: R.h(48),
            // CustomOutlinedButton scales the radius itself, CustomButton does not.
            child: CustomOutlinedButton(
              text: 'Back'.tr,
              borderRadius: 8,
              textStyle: CustomTextStyles.medium16,
              onPressed: () {
                if (onDone != null) {
                  onDone!();
                  return;
                }
                Get.back();
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Same outcome as a dialog, for flows that stay on the checkout screen.
Future<void> showPaymentResultDialog(
  BuildContext context,
  PaymentResult result, {
  VoidCallback? onClose,
}) {
  final _ResultStyle style = _styleFor(result);
  return showSuccessDialog(
    context,
    icon: style.icon,
    iconColor: style.color,
    title: style.title,
    message: style.message,
    closeDialog: onClose,
  );
}
