import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_starter/app/feature/purchases/purchases_controllers/paywall_controller.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_presentation/purchases_widgets/entitlement_banner.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_presentation/purchases_widgets/purchase_product_tile.dart';
import 'package:flutter_starter/app/routes/app_routes.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:flutter_starter/app/widgets/layout/layout_components.dart';

/// Paywall. Restore, Terms and Privacy are not decoration — App Store review
/// rejects a subscription screen without all three.
class PaywallScreen extends StatelessWidget {
  /// Selling points above the plans. Replace with your own.
  final List<String> benefits;

  final String headline;
  final String subhead;

  /// Defaults to `AppRoutes.TermsOfServiceScreen`. Pass your own to open a
  /// hosted page instead (needs `url_launcher` or the `webview` module).
  final VoidCallback? onTermsTap;

  /// Defaults to `AppRoutes.PrivacyPolicyScreen`.
  final VoidCallback? onPrivacyTap;

  /// Shown when the user already has access; see the README for the store URLs.
  final VoidCallback? onManageSubscription;

  const PaywallScreen({
    super.key,
    this.headline = 'Go Pro',
    this.subhead = 'Unlock everything, cancel any time',
    this.benefits = const <String>[
      'Unlimited projects',
      'Priority support',
      'No ads',
    ],
    this.onTermsTap,
    this.onPrivacyTap,
    this.onManageSubscription,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PaywallController>(
      builder: (PaywallController c) {
        return Scaffold(
          backgroundColor: CustomColors.artboardColor(),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
            child: AppBarWidget(
              title: 'Subscription'.tr,
              backgroundColor: CustomColors.transparent(),
              elevation: 0,
            ),
          ),
          body: _body(context, c),
          bottomSheet: _buildActionBar(context, c),
        );
      },
    );
  }

  Widget _body(BuildContext context, PaywallController controller) {
    return SingleChildScrollView(
      padding: R.pad(horizontal: 16, top: 8, bottom: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, controller),
          SizedBox(height: R.h(20)),
          Obx(
            () => EntitlementBanner(
              entitlement: controller.purchases.entitlement.value,
              cacheAgeInDays: controller.cacheAgeInDays,
            ),
          ),
          Obx(() => _buildNotices(context, controller)),
          _buildBenefits(context, controller),
          SizedBox(height: R.h(20)),
          Obx(() => _buildPlans(context, controller)),
          SizedBox(height: R.h(12)),
          _buildRenewalDisclosure(context, controller),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PaywallController controller) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: R.pad(all: 10),
          decoration: BoxDecoration(
            color: CustomColors.primary().withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(R.r(10)),
          ),
          child: Icon(
            LucideIcons.crown,
            size: R.w(22),
            color: CustomColors.primary(),
          ),
        ),
        SizedBox(width: R.w(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline.tr,
                style: CustomTextStyles.bold22.copyWith(
                  color: CustomColors.black(),
                ),
              ),
              SizedBox(height: R.h(4)),
              Text(
                subhead.tr,
                style: CustomTextStyles.regular14.copyWith(
                  color: CustomColors.paragraph(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefits(BuildContext context, PaywallController controller) {
    if (benefits.isEmpty) return const SizedBox.shrink();
    return CardContainer(
      padding: R.pad(all: 16),
      backgroundColor: CustomColors.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final String benefit in benefits)
            Padding(
              padding: R.pad(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.check,
                    size: R.w(16),
                    color: CustomColors.success(),
                  ),
                  SizedBox(width: R.w(8)),
                  Expanded(
                    child: Text(
                      benefit.tr,
                      style: CustomTextStyles.regular14.copyWith(
                        color: CustomColors.black(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlans(BuildContext context, PaywallController controller) {
    if (controller.purchases.isLoadingProducts.value &&
        controller.products.isEmpty) {
      return Padding(
        padding: R.pad(vertical: 24),
        child: LoadingWidget(message: 'Loading plans'.tr),
      );
    }

    if (controller.products.isEmpty) {
      return EmptyStateWidget(
        icon: LucideIcons.receiptText,
        title: 'No plans available'.tr,
        subtitle:
            'The store returned no products. Check the product ids and that the build is signed with the right bundle id.'
                .tr,
        action: CustomOutlinedButton(
          text: 'Try again'.tr,
          onPressed: controller.reload,
          icon: Icon(
            LucideIcons.refreshCw,
            size: R.w(16),
            color: CustomColors.primary(),
          ),
        ),
      );
    }

    final String? selectedId = controller.selectedProductId.value;
    final bool busy =
        controller.isBuying.value || controller.purchases.isRestoring.value;

    return Column(
      children: [
        for (final product in controller.products)
          PurchaseProductTile(
            product: product,
            selected: product.id == selectedId,
            enabled: !busy,
            onTap: () => controller.select(product.id),
          ),
      ],
    );
  }

  Widget _buildNotices(BuildContext context, PaywallController controller) {
    final List<Widget> notices = <Widget>[];

    if (!controller.purchases.storeAvailable.value) {
      notices.add(
        _notice(
          icon: LucideIcons.triangleAlert,
          text: 'In-app purchases are not available on this device'.tr,
          foreground: CustomColors.error(),
          background: CustomColors.errorBg(),
        ),
      );
    }

    if (controller.purchases.awaitingApproval.isNotEmpty) {
      notices.add(
        _notice(
          icon: LucideIcons.hourglass,
          text:
              'A payment is waiting for approval. Access unlocks automatically once the store settles it.'
                  .tr,
          foreground: CustomColors.warningOrange(),
          background: CustomColors.warningBg(),
        ),
      );
    }

    final List<String> unknown = controller.purchases.unknownProductIds;
    if (unknown.isNotEmpty) {
      notices.add(
        _notice(
          icon: LucideIcons.info,
          text: '${'Unknown product ids'.tr}: ${unknown.join(', ')}',
          foreground: CustomColors.warningOrange(),
          background: CustomColors.warningBg(),
        ),
      );
    }

    if (notices.isEmpty) return const SizedBox.shrink();
    return Column(children: notices);
  }

  Widget _notice({
    required IconData icon,
    required String text,
    required Color foreground,
    required Color background,
  }) {
    return Container(
      padding: R.pad(all: 12),
      margin: R.margin(bottom: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(R.r(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: R.w(16), color: foreground),
          SizedBox(width: R.w(10)),
          Expanded(
            child: Text(
              text,
              style: CustomTextStyles.regular12.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }

  /// Both stores require the auto-renew terms on the purchase screen itself.
  Widget _buildRenewalDisclosure(
    BuildContext context,
    PaywallController controller,
  ) {
    return Text(
      'Payment is charged to your store account at confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the period ends. Manage or cancel in your store account settings.'
          .tr,
      style: CustomTextStyles.regular10.copyWith(
        color: CustomColors.textGray(),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, PaywallController controller) {
    return Container(
      color: CustomColors.artboardColor(),
      padding: R.pad(horizontal: 16, top: 12, bottom: 12),
      child: SafeArea(
        top: false,
        child: Obx(() {
          final bool busy = controller.isBuying.value ||
              controller.purchases.isVerifying.value;
          final bool restoring = controller.purchases.isRestoring.value;
          final bool canBuy = controller.selected != null &&
              controller.purchases.storeAvailable.value;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: R.h(48),
                child: CustomButton(
                  loading: busy,
                  text: controller.hasAccess
                      ? 'Change plan'.tr
                      : _ctaLabel(controller),
                  borderRadius: R.r(8),
                  icon: Icon(
                    LucideIcons.sparkles,
                    size: R.w(18),
                    color: CustomColors.white(),
                  ),
                  onPressed: (busy || restoring || !canBuy)
                      ? null
                      : () => _onBuy(context, controller),
                ),
              ),
              SizedBox(height: R.h(8)),
              _buildRestoreRow(context, controller, restoring: restoring),
              _buildLegalRow(context, controller),
            ],
          );
        }),
      ),
    );
  }

  String _ctaLabel(PaywallController controller) {
    final product = controller.selected;
    if (product == null) return 'Continue'.tr;
    return '${'Continue'.tr} — ${product.price}';
  }

  Widget _buildRestoreRow(
    BuildContext context,
    PaywallController controller, {
    required bool restoring,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: restoring ? null : controller.restore,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.rotateCcw,
                size: R.w(14),
                color: CustomColors.primary(),
              ),
              SizedBox(width: R.w(6)),
              Text(
                restoring ? 'Restoring…'.tr : 'Restore purchases'.tr,
                style: CustomTextStyles.medium12.copyWith(
                  color: CustomColors.primary(),
                ),
              ),
            ],
          ),
        ),
        if (controller.hasAccess && onManageSubscription != null)
          TextButton(
            onPressed: onManageSubscription,
            child: Text(
              'Manage'.tr,
              style: CustomTextStyles.medium12.copyWith(
                color: CustomColors.primary(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLegalRow(BuildContext context, PaywallController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legalLink(
          'Terms of Service'.tr,
          onTermsTap ?? () => Get.toNamed(AppRoutes.TermsOfServiceScreen),
        ),
        Text(
          '  ·  ',
          style: CustomTextStyles.regular10.copyWith(
            color: CustomColors.textGray(),
          ),
        ),
        _legalLink(
          'Privacy Policy'.tr,
          onPrivacyTap ?? () => Get.toNamed(AppRoutes.PrivacyPolicyScreen),
        ),
      ],
    );
  }

  Widget _legalLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: CustomTextStyles.regular10.copyWith(
          color: CustomColors.textGray(),
          decoration: TextDecoration.underline,
          decorationColor: CustomColors.textGray(),
        ),
      ),
    );
  }

  Future<void> _onBuy(
    BuildContext context,
    PaywallController controller,
  ) async {
    FocusScope.of(context).unfocus();
    await controller.buySelected();
  }
}
