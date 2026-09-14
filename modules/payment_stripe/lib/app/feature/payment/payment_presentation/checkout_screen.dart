import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_starter/app/feature/payment/payment_controllers/payment_controller.dart';
import 'package:flutter_starter/app/feature/payment/payment_models/payment_result.dart';
import 'package:flutter_starter/app/feature/payment/payment_presentation/payment_result_screen.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:flutter_starter/app/widgets/layout/layout_components.dart';

/// One illustrative summary line. Replace with your own order model.
class CheckoutLineItem {
  final String label;

  /// Unit price in minor units (cents).
  final int amountMinor;
  final int quantity;

  const CheckoutLineItem({
    required this.label,
    required this.amountMinor,
    this.quantity = 1,
  });

  int get totalMinor => amountMinor * quantity;
}

/// Template checkout. The summary is illustrative — the charged amount is
/// whatever YOUR backend derives, never the figure passed from here.
class CheckoutScreen extends StatelessWidget {
  /// Swap these for the real cart. Defaults exist only so the screen runs.
  final List<CheckoutLineItem> items;

  /// ISO currency code as Stripe expects it, lowercase.
  final String currency;

  /// Extra charge shown under the subtotal, in minor units.
  final int feeMinor;
  final String feeLabel;

  /// Sent to the backend as an order hint only.
  final String? description;

  /// Name shown on the Stripe sheet.
  final String? merchantDisplayName;

  /// Handle the outcome yourself; omit to push [PaymentResultScreen].
  final void Function(PaymentResult result)? onResult;

  const CheckoutScreen({
    super.key,
    this.items = const [
      CheckoutLineItem(label: 'Starter plan', amountMinor: 1900),
      CheckoutLineItem(label: 'Extra seat', amountMinor: 500, quantity: 2),
    ],
    this.currency = 'usd',
    this.feeMinor = 0,
    this.feeLabel = 'Service fee',
    this.description,
    this.merchantDisplayName,
    this.onResult,
  });

  int get subtotalMinor => items.fold(0, (sum, item) => sum + item.totalMinor);

  int get totalMinor => subtotalMinor + feeMinor;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PaymentController>(
      builder: (c) {
        return Scaffold(
          backgroundColor: CustomColors.artboardColor(),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
            child: AppBarWidget(
              title: 'Checkout'.tr,
              backgroundColor: CustomColors.transparent(),
              elevation: 0,
            ),
          ),
          body: _body(context, c),
          bottomSheet: buildPayBar(context, c),
        );
      },
    );
  }

  Widget _body(BuildContext context, PaymentController controller) {
    return SingleChildScrollView(
      padding: R.pad(horizontal: 16, top: 16, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!controller.isReady) ...[
            buildNotConfiguredNotice(context, controller),
            SizedBox(height: R.h(16)),
          ],
          buildOrderSummary(context, controller),
          SizedBox(height: R.h(16)),
          buildSecurityNote(context, controller),
        ],
      ),
    );
  }

  /// Shown when STRIPE_PUBLISHABLE_KEY is missing or is not a pk_ key.
  Widget buildNotConfiguredNotice(
    BuildContext context,
    PaymentController controller,
  ) {
    return Container(
      padding: R.pad(all: 12),
      decoration: BoxDecoration(
        color: CustomColors.warningBg(),
        borderRadius: BorderRadius.circular(R.r(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.triangleAlert,
            size: R.w(18),
            color: CustomColors.warningOrange(),
          ),
          SizedBox(width: R.w(10)),
          Expanded(
            child: Text(
              'Payments are not configured. Add your Stripe publishable key to .env.'
                  .tr,
              style: CustomTextStyles.regular12.copyWith(
                color: CustomColors.warningOrange(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildOrderSummary(BuildContext context, PaymentController controller) {
    return CardContainer(
      padding: R.pad(all: 16),
      backgroundColor: CustomColors.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.receiptText,
                size: R.w(18),
                color: CustomColors.primary(),
              ),
              SizedBox(width: R.w(8)),
              Text(
                'Order summary'.tr,
                style: CustomTextStyles.semiBold16.copyWith(
                  color: CustomColors.black(),
                ),
              ),
            ],
          ),
          SizedBox(height: R.h(12)),
          ...items.map((item) => buildLineItem(context, item)),
          CustomDivider(
            margin: R.margin(vertical: 8),
            color: CustomColors.stroke(),
          ),
          buildAmountRow(context, 'Subtotal'.tr, formatMinor(subtotalMinor)),
          if (feeMinor != 0) ...[
            SizedBox(height: R.h(6)),
            buildAmountRow(context, feeLabel.tr, formatMinor(feeMinor)),
          ],
          CustomDivider(
            margin: R.margin(vertical: 8),
            color: CustomColors.stroke(),
          ),
          buildAmountRow(
            context,
            'Total'.tr,
            formatMinor(totalMinor),
            emphasised: true,
          ),
        ],
      ),
    );
  }

  Widget buildLineItem(BuildContext context, CheckoutLineItem item) {
    return Padding(
      padding: R.pad(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              item.quantity > 1
                  ? '${item.label.tr}  x${item.quantity}'
                  : item.label.tr,
              style: CustomTextStyles.regular14.copyWith(
                color: CustomColors.paragraph(),
              ),
            ),
          ),
          SizedBox(width: R.w(12)),
          Text(
            formatMinor(item.totalMinor),
            style: CustomTextStyles.medium14.copyWith(
              color: CustomColors.black(),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAmountRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasised = false,
  }) {
    final TextStyle labelStyle = emphasised
        ? CustomTextStyles.semiBold16.copyWith(color: CustomColors.black())
        : CustomTextStyles.regular14.copyWith(color: CustomColors.textGray());
    final TextStyle valueStyle = emphasised
        ? CustomTextStyles.bold16.copyWith(color: CustomColors.primary())
        : CustomTextStyles.medium14.copyWith(color: CustomColors.black());

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
  }

  Widget buildSecurityNote(BuildContext context, PaymentController controller) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          LucideIcons.shieldCheck,
          size: R.w(16),
          color: CustomColors.success(),
        ),
        SizedBox(width: R.w(8)),
        Expanded(
          child: Text(
            'Card details are collected by Stripe and never touch this app or its servers.'
                .tr,
            style: CustomTextStyles.regular12.copyWith(
              color: CustomColors.textGray(),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildPayBar(BuildContext context, PaymentController controller) {
    return Container(
      color: CustomColors.artboardColor(),
      padding: R.pad(horizontal: 16, top: 12, bottom: 16),
      child: SafeArea(
        top: false,
        child: Obx(() {
          final bool isLoading = controller.isLoadingPayment.value;
          return SizedBox(
            width: double.infinity,
            height: R.h(48),
            child: CustomButton(
              loading: isLoading,
              text: '${'Pay'.tr} ${formatMinor(totalMinor)}',
              borderRadius: R.r(8),
              textStyle: CustomTextStyles.medium16.copyWith(
                color: CustomColors.white(),
              ),
              icon: Icon(
                LucideIcons.creditCard,
                size: R.w(18),
                color: CustomColors.white(),
              ),
              onPressed: isLoading ? null : () => _onPay(context, controller),
            ),
          );
        }),
      ),
    );
  }

  /// Amount sent here is a display hint — the backend re-derives what to charge.
  Future<void> _onPay(
    BuildContext context,
    PaymentController controller,
  ) async {
    FocusScope.of(context).unfocus();
    if (merchantDisplayName != null && merchantDisplayName!.isNotEmpty) {
      controller.merchantDisplayName = merchantDisplayName!;
    }

    final PaymentResult result = await controller.pay(
      amountMinor: totalMinor,
      currency: currency,
      description: description,
    );

    if (onResult != null) {
      onResult!(result);
      return;
    }
    Get.to(() => PaymentResultScreen(result: result));
  }

  /// Minor units to display text. Zero-decimal currencies (JPY, KRW) need a
  /// divisor of 1 instead of 100 — adjust here if you support them.
  String formatMinor(int minor) {
    return '${currency.toUpperCase()} ${(minor / 100).toStringAsFixed(2)}';
  }
}
