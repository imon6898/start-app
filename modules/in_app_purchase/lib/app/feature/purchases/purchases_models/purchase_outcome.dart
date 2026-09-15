import 'package:flutter_starter/app/feature/purchases/purchases_models/entitlement_model.dart';

/// Result of one buy or restore attempt, after the server has had its say.
sealed class PurchaseOutcome {
  const PurchaseOutcome({this.productId});

  final String? productId;
}

/// Server verified the receipt and granted access. The only success case.
class PurchaseGranted extends PurchaseOutcome {
  const PurchaseGranted({
    super.productId,
    required this.entitlement,
    this.restored = false,
  });

  final EntitlementModel entitlement;
  final bool restored;
}

/// Store took the order but has not settled it: Ask to Buy, cash payment, a
/// card needing 3DS. Do not unlock anything yet.
class PurchaseAwaitingApproval extends PurchaseOutcome {
  const PurchaseAwaitingApproval({super.productId});
}

class PurchaseCancelled extends PurchaseOutcome {
  const PurchaseCancelled({super.productId});
}

/// Store says bought, your backend did not grant. Either it refused the
/// receipt, or it could not be reached.
class PurchaseUnverified extends PurchaseOutcome {
  const PurchaseUnverified({
    super.productId,
    required this.reason,
    this.serverReachable = true,
  });

  final String reason;
  final bool serverReachable;
}

class PurchaseFailed extends PurchaseOutcome {
  const PurchaseFailed({super.productId, required this.message, this.code});

  final String message;
  final String? code;
}

/// Restore finished and the store had nothing for this account.
class PurchaseNothingToRestore extends PurchaseOutcome {
  const PurchaseNothingToRestore();
}

/// Billing is unavailable: emulator without Play Services, parental block,
/// or a signed-out store account.
class PurchaseStoreUnavailable extends PurchaseOutcome {
  const PurchaseStoreUnavailable({super.productId});
}
