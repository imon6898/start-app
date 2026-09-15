/// Endpoints this module adds, kept out of core `api_const.dart` so installing
/// needs no edit there.
///
/// Every path is on YOUR backend. There is no store URL here on purpose: Apple
/// and Google only accept receipt verification from a server holding a shared
/// secret / service account, and a client that "verifies" its own purchase
/// verifies nothing.
class PurchasesApiConst {
  /// Path segment the billing service is mounted under. Override in bootstrap
  /// if your API namespaces differently.
  static const String billing = '/billing';

  /// POST — one store receipt in, the resulting entitlement out.
  static const String verifyPurchaseUri = '$billing/purchases/verify';

  /// POST — batch of receipts from "restore purchases".
  static const String syncPurchasesUri = '$billing/purchases/sync';

  /// GET — the current entitlement. The source of truth for access.
  static const String entitlementUri = '$billing/entitlement';
}
