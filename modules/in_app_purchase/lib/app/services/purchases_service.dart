import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:flutter_starter/app/core/models/base_response.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_logic/entitlement_store.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_logic/purchases_api_service.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_logic/purchases_catalog.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_logic/purchases_store_client.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_models/entitlement_model.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_models/purchase_outcome.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';

/// Owns the store connection, the purchase stream and the entitlement state.
///
/// The store only tells you that money moved. Whether this user may use the
/// paid feature is decided by YOUR backend after it validates the receipt with
/// Apple / Google, and this service never overrides that verdict. A patched
/// binary can make any client-side `purchased == true` check return true; it
/// cannot forge a signed receipt your server accepts.
class PurchasesService extends GetxService {
  PurchasesService({PurchasesStoreClient? store, PurchasesRepo? repo})
      : _store = store ?? PurchasesStoreClient(),
        _repo = repo ?? PurchasesRepo();

  final PurchasesStoreClient _store;
  final PurchasesRepo _repo;

  /// How long [buy] waits for the stream before reporting "still processing".
  static Duration purchaseTimeout = const Duration(minutes: 3);

  /// iOS delivers nothing at all when a restore finds no purchases, so restore
  /// waits this long, then asks the server and reports the result.
  static Duration restoreGrace = const Duration(seconds: 8);

  /// A store query that never answers must not leave a spinner on screen
  /// forever; on timeout the paywall shows its empty state with a retry.
  static Duration productQueryTimeout = const Duration(seconds: 20);

  final RxBool storeAvailable = false.obs;
  final RxBool isLoadingProducts = false.obs;
  final RxBool isRestoring = false.obs;
  final RxBool isVerifying = false.obs;

  final RxList<ProductDetails> products = <ProductDetails>[].obs;

  /// Ids the store did not recognise — almost always a console/bundle-id
  /// mismatch, or a product that is not yet approved.
  final RxList<String> unknownProductIds = <String>[].obs;

  /// Purchases the store accepted but has not settled (Ask to Buy, cash).
  final RxList<PurchaseDetails> awaitingApproval = <PurchaseDetails>[].obs;

  final Rx<EntitlementModel> entitlement = EntitlementModel.empty.obs;

  /// True while the value came from disk and no server answer has landed yet.
  final RxBool entitlementFromCache = false.obs;

  final RxnString lastError = RxnString();

  /// Opaque account identifier passed to the store. Set it to a hash of your
  /// user id — never an email, both stores forbid that.
  String? applicationUserName;

  final StreamController<PurchaseOutcome> _outcomes =
      StreamController<PurchaseOutcome>.broadcast();
  final Map<String, Completer<PurchaseOutcome>> _waiting =
      <String, Completer<PurchaseOutcome>>{};

  StreamSubscription<List<PurchaseDetails>>? _sub;
  Future<void> _pump = Future<void>.value();
  int _restoredCount = 0;
  bool _initialised = false;

  /// One-shot purchase events, for snackbars and navigation.
  Stream<PurchaseOutcome> get outcomes => _outcomes.stream;

  /// The single question the rest of the app should ask.
  bool get hasAccess => entitlement.value.grantsAccessAt(DateTime.now());

  /// Registered in bootstrap; this is the fallback for when that was skipped.
  /// It works, but a purchase interrupted before launch is only picked up once
  /// something calls this — usually too late to feel instant.
  static PurchasesService ensure() {
    if (Get.isRegistered<PurchasesService>()) {
      return Get.find<PurchasesService>();
    }
    devPrint(
      'PurchasesService was not registered in bootstrap - registering late, '
      'launch-time interrupted purchases may be missed',
      tag: 'IAP',
    );
    final service = Get.put(PurchasesService(), permanent: true);
    service.init();
    return service;
  }

  /// Idempotent. Await it from `Get.putAsync` in bootstrap.
  Future<PurchasesService> init() async {
    if (_initialised) return this;
    _initialised = true;

    await EntitlementStore.init();
    final EntitlementModel? cached = EntitlementStore.cached;
    if (cached != null) {
      entitlement.value = cached;
      entitlementFromCache.value = true;
    }

    // Subscribe first. An unfinished transaction is delivered as soon as the
    // stream has a listener, and anything awaited before this can miss it.
    _sub = _store.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => devPrint('purchaseStream error: $e', tag: 'IAP'),
    );

    storeAvailable.value = await _store.isAvailable();
    if (storeAvailable.value) {
      unawaited(loadProducts());
    } else {
      devPrint('Store is unavailable on this device', tag: 'IAP');
    }
    unawaited(refreshEntitlement());
    return this;
  }

  @override
  void onClose() {
    _sub?.cancel();
    _outcomes.close();
    super.onClose();
  }

  /// Fetches localised titles and prices. Prices must always be shown from
  /// here — the store, not a hardcoded string, knows the user's currency.
  Future<void> loadProducts() async {
    if (isLoadingProducts.value) return;
    isLoadingProducts.value = true;
    try {
      final ProductDetailsResponse response = await _store
          .queryProducts(PurchasesCatalog.productIds)
          .timeout(productQueryTimeout);
      if (response.error != null) {
        lastError.value = response.error!.message;
        devPrint('queryProductDetails: ${response.error}', tag: 'IAP');
      }
      unknownProductIds.assignAll(response.notFoundIDs);

      final List<ProductDetails> found =
          List<ProductDetails>.of(response.productDetails)
            ..sort((a, b) => PurchasesCatalog.orderOf(a.id)
                .compareTo(PurchasesCatalog.orderOf(b.id)));
      products.assignAll(found);
    } catch (e) {
      lastError.value = e.toString();
      devPrint('loadProducts failed: $e', tag: 'IAP');
    } finally {
      isLoadingProducts.value = false;
    }
  }

  /// Starts a purchase and resolves once the stream settles it. The store UI is
  /// modal and native; nothing here can hurry it along.
  Future<PurchaseOutcome> buy(ProductDetails product) async {
    if (!storeAvailable.value) {
      return PurchaseStoreUnavailable(productId: product.id);
    }
    if (_waiting.containsKey(product.id)) {
      return PurchaseAwaitingApproval(productId: product.id);
    }

    final completer = Completer<PurchaseOutcome>();
    _waiting[product.id] = completer;

    bool sent;
    try {
      sent = await _store.buy(
        product,
        consumable:
            PurchasesCatalog.kindOf(product.id) == PurchaseKind.consumable,
        applicationUserName: applicationUserName,
      );
    } catch (e) {
      // iOS throws here when the same product already has a pending
      // transaction that was never finished.
      _waiting.remove(product.id);
      devPrint('buy failed: $e', tag: 'IAP');
      return PurchaseFailed(productId: product.id, message: e.toString());
    }

    if (!sent) {
      _waiting.remove(product.id);
      return PurchaseFailed(
        productId: product.id,
        message: 'The store did not accept the request',
      );
    }

    return completer.future.timeout(
      purchaseTimeout,
      onTimeout: () {
        _waiting.remove(product.id);
        return PurchaseAwaitingApproval(productId: product.id);
      },
    );
  }

  /// Required by App Store review. Also the only way a user who reinstalled or
  /// switched devices gets their non-consumable back.
  Future<void> restore() async {
    if (isRestoring.value) return;
    isRestoring.value = true;
    _restoredCount = 0;
    try {
      await _store.restore(applicationUserName: applicationUserName);
      // The stream is the real channel, but it stays silent when there is
      // nothing to restore — so give it a moment, then trust the server.
      await Future<void>.delayed(restoreGrace);
      await _pump;
      await refreshEntitlement();
      if (_restoredCount == 0 && !hasAccess) {
        _emit(const PurchaseNothingToRestore());
      }
    } on InAppPurchaseException catch (e) {
      lastError.value = e.message ?? e.code;
      _emit(PurchaseFailed(message: e.message ?? e.code, code: e.code));
    } catch (e) {
      lastError.value = e.toString();
      devPrint('restore failed: $e', tag: 'IAP');
      _emit(PurchaseFailed(message: e.toString()));
    } finally {
      isRestoring.value = false;
    }
  }

  /// Asks the server for the current entitlement. This is what picks up a
  /// renewal, a cancellation, a refund or an expiry that happened while the
  /// app was closed — the store webhook told your backend, not this device.
  Future<void> refreshEntitlement() async {
    try {
      final dynamic response = await _repo.fetchEntitlement();
      if (response == null) return; // Offline: keep the cached verdict.
      final parsed = BaseResponse<EntitlementModel>.fromJson(
        response,
        EntitlementModel.fromJson,
      );
      await _applyEntitlement(parsed.data ?? EntitlementModel.empty);
    } catch (e) {
      devPrint('refreshEntitlement failed: $e', tag: 'IAP');
    }
  }

  /// Call on sign-out. Without it the next account on this device inherits the
  /// previous user's cached access.
  Future<void> clear() async {
    entitlement.value = EntitlementModel.empty;
    entitlementFromCache.value = false;
    awaitingApproval.clear();
    lastError.value = null;
    await EntitlementStore.clear();
  }

  // Serialised so two stream events cannot verify at the same time.
  void _onPurchases(List<PurchaseDetails> updates) {
    _pump = _pump
        .then((_) => _process(updates))
        .catchError((Object e) => devPrint('purchase handling: $e', tag: 'IAP'));
  }

  Future<void> _process(List<PurchaseDetails> updates) async {
    for (final PurchaseDetails purchase in updates) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Never complete a pending purchase — the plugin throws. Wait for the
          // store to send a second event when the payment settles.
          _rememberAwaiting(purchase);
          _settle(PurchaseAwaitingApproval(productId: purchase.productID));

        case PurchaseStatus.canceled:
          _forgetAwaiting(purchase);
          _settle(PurchaseCancelled(productId: purchase.productID));

        case PurchaseStatus.error:
          _forgetAwaiting(purchase);
          final String message =
              purchase.error?.message ?? 'The purchase could not be completed';
          lastError.value = message;
          devPrint('purchase error: ${purchase.error}', tag: 'IAP');
          _settle(PurchaseFailed(
            productId: purchase.productID,
            message: message,
            code: purchase.error?.code,
          ));

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndGrant(purchase);
      }
    }
  }

  Future<void> _verifyAndGrant(PurchaseDetails purchase) async {
    final bool restored = purchase.status == PurchaseStatus.restored;
    isVerifying.value = true;
    try {
      final dynamic response = await _repo.verifyPurchase(<String, dynamic>{
        'platform': _platformName,
        // 'app_store' or 'google_play' — tells the backend which API to call.
        'source': purchase.verificationData.source,
        'product_id': purchase.productID,
        'purchase_id': purchase.purchaseID,
        'transaction_date': purchase.transactionDate,
        // iOS StoreKit 2: the JWS signed transaction. iOS StoreKit 1: the
        // base64 app receipt. Android: the purchase token.
        'receipt': purchase.verificationData.serverVerificationData,
        'is_restore': restored,
      });

      if (response == null) {
        // Server unreachable. Leave the transaction unfinished so the store
        // re-delivers it on the next launch instead of losing the receipt.
        _settle(PurchaseUnverified(
          productId: purchase.productID,
          reason: 'Could not reach the server to confirm the purchase',
          serverReachable: false,
        ));
        return;
      }

      final parsed = BaseResponse<EntitlementModel>.fromJson(
        response,
        EntitlementModel.fromJson,
      );
      final EntitlementModel granted = parsed.data ?? EntitlementModel.empty;

      if (!granted.grantsAccess) {
        // An explicit refusal: finish the transaction so the store stops
        // re-delivering a receipt the backend will never accept. On Android
        // this also avoids the automatic 3-day refund.
        lastError.value = parsed.message.isEmpty ? granted.message : parsed.message;
        await _complete(purchase);
        _settle(PurchaseUnverified(
          productId: purchase.productID,
          reason: lastError.value ?? 'The purchase was not accepted',
        ));
        return;
      }

      await _applyEntitlement(granted);
      // Only now: the grant is recorded, so losing the receipt is harmless.
      await _complete(purchase);
      _forgetAwaiting(purchase);
      if (restored) _restoredCount++;
      _settle(PurchaseGranted(
        productId: purchase.productID,
        entitlement: granted,
        restored: restored,
      ));
    } catch (e) {
      devPrint('verify failed: $e', tag: 'IAP');
      _settle(PurchaseUnverified(
        productId: purchase.productID,
        reason: e.toString(),
        serverReachable: false,
      ));
    } finally {
      isVerifying.value = false;
    }
  }

  Future<void> _applyEntitlement(EntitlementModel granted) async {
    final EntitlementModel stamped =
        granted.copyWith(verifiedAt: granted.verifiedAt ?? DateTime.now());
    entitlement.value = stamped;
    entitlementFromCache.value = false;
    await EntitlementStore.save(stamped);
  }

  /// Completing is what removes the transaction from the store queue. Pending
  /// purchases must be skipped: the plugin throws on those, and on iOS a
  /// cancelled purchase has no transaction id to finish.
  Future<void> _complete(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending) return;
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _store.complete(purchase);
    } catch (e) {
      devPrint('completePurchase failed: $e', tag: 'IAP');
    }
  }

  void _rememberAwaiting(PurchaseDetails purchase) {
    if (awaitingApproval.any((p) => p.productID == purchase.productID)) return;
    awaitingApproval.add(purchase);
  }

  void _forgetAwaiting(PurchaseDetails purchase) {
    awaitingApproval.removeWhere((p) => p.productID == purchase.productID);
  }

  // Resolves the pending buy() future, if any, and broadcasts to the UI.
  void _settle(PurchaseOutcome outcome) {
    final String? id = outcome.productId;
    if (id != null) {
      final Completer<PurchaseOutcome>? waiting = _waiting[id];
      // A pending purchase is not the end of the story; keep waiting for the
      // settled event so buy() can still resolve as granted.
      if (waiting != null && outcome is! PurchaseAwaitingApproval) {
        _waiting.remove(id);
        if (!waiting.isCompleted) waiting.complete(outcome);
      }
    }
    _emit(outcome);
  }

  void _emit(PurchaseOutcome outcome) {
    if (!_outcomes.isClosed) _outcomes.add(outcome);
  }

  String get _platformName {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.android:
        return 'android';
      default:
        return defaultTargetPlatform.name;
    }
  }
}
