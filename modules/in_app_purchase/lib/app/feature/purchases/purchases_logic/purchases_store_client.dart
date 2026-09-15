import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:flutter_starter/app/services/domain/dev_tools.dart';

/// The only file that talks to the `in_app_purchase` plugin. Every method is
/// overridable so tests can subclass it without touching a platform channel.
class PurchasesStoreClient {
  // Lazy on purpose: InAppPurchase.instance registers the platform (and opens a
  // BillingClient), so a fake subclass must never trigger it.
  InAppPurchase get _iap => InAppPurchase.instance;

  /// Broadcast, never closes, and replays an interrupted purchase on launch.
  /// Subscribe before anything else.
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (e) {
      devPrint('isAvailable failed: $e', tag: 'IAP');
      return false;
    }
  }

  Future<ProductDetailsResponse> queryProducts(Set<String> ids) =>
      _iap.queryProductDetails(ids);

  /// Returns whether the request reached the store, NOT whether it succeeded —
  /// the outcome arrives on [purchaseStream].
  ///
  /// [applicationUserName] should be an opaque hash of your user id. Apple and
  /// Google both forbid putting an email or anything identifying in it.
  Future<bool> buy(
    ProductDetails product, {
    required bool consumable,
    String? applicationUserName,
  }) {
    // A plain PurchaseParam is enough for Play subscriptions: the Android
    // implementation reads the offer token off GooglePlayProductDetails itself.
    final PurchaseParam param = PurchaseParam(
      productDetails: product,
      applicationUserName: applicationUserName,
    );
    return consumable
        ? _iap.buyConsumable(purchaseParam: param)
        : _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Results arrive on [purchaseStream] with `PurchaseStatus.restored`. Throws
  /// `InAppPurchaseException` on Android when the billing query fails.
  Future<void> restore({String? applicationUserName}) =>
      _iap.restorePurchases(applicationUserName: applicationUserName);

  /// Finishes the transaction. Until this runs, iOS re-delivers it on every
  /// launch and Google auto-refunds the purchase after three days.
  Future<void> complete(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  Future<String?> countryCode() async {
    try {
      return await _iap.countryCode();
    } catch (e) {
      devPrint('countryCode failed: $e', tag: 'IAP');
      return null;
    }
  }
}
