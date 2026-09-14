/// Outcome of one payment attempt. Sealed so `switch` on it is exhaustive.
///
/// [PaymentSuccess] means the sheet completed — not that money settled. Only
/// the Stripe webhook hitting your backend proves that.
sealed class PaymentResult {
  const PaymentResult();
}

/// The customer completed the payment sheet.
final class PaymentSuccess extends PaymentResult {
  final String? paymentIntentId;

  /// Status read back from your backend, when it was checked.
  final String? status;

  const PaymentSuccess({this.paymentIntentId, this.status});
}

/// The customer dismissed the sheet.
final class PaymentCancelled extends PaymentResult {
  const PaymentCancelled();
}

/// The payment was declined or the flow errored.
final class PaymentFailed extends PaymentResult {
  final String message;

  /// Stripe decline code, when the failure came from Stripe.
  final String? declineCode;

  const PaymentFailed(this.message, {this.declineCode});
}
