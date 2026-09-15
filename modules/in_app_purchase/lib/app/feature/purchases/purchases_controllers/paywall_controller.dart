import 'dart:async';

import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:flutter_starter/app/feature/purchases/purchases_logic/entitlement_store.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_logic/purchases_catalog.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_models/entitlement_model.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_models/purchase_outcome.dart';
import 'package:flutter_starter/app/services/purchases_service.dart';
import 'package:flutter_starter/app/widgets/feedback/custom_snack_bar.dart';

/// Screen state for the paywall. All store and server work lives in
/// [PurchasesService]; this only chooses a tile and reports outcomes.
class PaywallController extends GetxController {
  final PurchasesService purchases = PurchasesService.ensure();

  final RxnString selectedProductId = RxnString();
  final RxBool isBuying = false.obs;

  StreamSubscription<PurchaseOutcome>? _outcomeSub;
  Worker? _productsWorker;

  List<ProductDetails> get products => purchases.products;

  EntitlementModel get entitlement => purchases.entitlement.value;

  bool get hasAccess => purchases.hasAccess;

  ProductDetails? get selected {
    final String? id = selectedProductId.value;
    if (id == null) return null;
    for (final ProductDetails p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Days since the last server confirmation, null when never or fresh today.
  int? get cacheAgeInDays {
    final DateTime? at = EntitlementStore.cachedAt;
    if (at == null || !purchases.entitlementFromCache.value) return null;
    return DateTime.now().difference(at).inDays;
  }

  @override
  void onInit() {
    super.onInit();
    _outcomeSub = purchases.outcomes.listen(_report);
    _productsWorker = ever(purchases.products, (_) => _preselect());
    _preselect();
    if (products.isEmpty) purchases.loadProducts();
    purchases.refreshEntitlement();
  }

  @override
  void onClose() {
    _outcomeSub?.cancel();
    _productsWorker?.dispose();
    selectedProductId.close();
    isBuying.close();
    super.onClose();
  }

  void select(String productId) => selectedProductId.value = productId;

  Future<void> buySelected() async {
    final ProductDetails? product = selected;
    if (product == null || isBuying.value) return;
    isBuying.value = true;
    try {
      await purchases.buy(product);
    } finally {
      isBuying.value = false;
    }
  }

  Future<void> restore() => purchases.restore();

  Future<void> reload() async {
    await purchases.loadProducts();
    await purchases.refreshEntitlement();
  }

  /// Highlighted tile first, else the cheapest thing the store returned.
  void _preselect() {
    if (products.isEmpty) return;
    if (selected != null) return;
    final String? preferred = PurchasesCatalog.highlighted?.id;
    final bool hasPreferred =
        preferred != null && products.any((p) => p.id == preferred);
    selectedProductId.value = hasPreferred ? preferred : products.first.id;
  }

  void _report(PurchaseOutcome outcome) {
    final context = Get.context;
    if (context == null) return;

    switch (outcome) {
      case PurchaseGranted(restored: final bool restored):
        showCustomSnackBar(
          context: context,
          type: SnackBarType.Success,
          title: restored ? 'Purchases restored'.tr : 'You are all set'.tr,
          description: 'Your subscription is active'.tr,
        );
      case PurchaseAwaitingApproval():
        showCustomSnackBar(
          context: context,
          type: SnackBarType.Warning,
          title: 'Waiting for approval'.tr,
          description:
              'The store has not completed this payment yet. Access unlocks as soon as it does.'
                  .tr,
        );
      case PurchaseCancelled():
        showCustomSnackBar(
          context: context,
          type: SnackBarType.Light,
          title: 'Purchase cancelled'.tr,
          description: 'Nothing was charged'.tr,
        );
      case PurchaseUnverified(serverReachable: final bool reachable):
        showCustomSnackBar(
          context: context,
          type: SnackBarType.Failure,
          title: 'Could not confirm the purchase'.tr,
          description: reachable
              ? 'The store charge was not accepted. Contact support with your receipt.'
                  .tr
              : 'You were charged but we could not reach the server. It will finish automatically.'
                  .tr,
        );
      case PurchaseFailed(message: final String message):
        showCustomSnackBar(
          context: context,
          type: SnackBarType.Failure,
          title: 'Purchase failed'.tr,
          description: message,
        );
      case PurchaseNothingToRestore():
        showCustomSnackBar(
          context: context,
          type: SnackBarType.Light,
          title: 'Nothing to restore'.tr,
          description: 'This store account has no previous purchase'.tr,
        );
      case PurchaseStoreUnavailable():
        showCustomSnackBar(
          context: context,
          type: SnackBarType.Failure,
          title: 'Store unavailable'.tr,
          description: 'In-app purchases are not available on this device'.tr,
        );
    }
  }
}
