/// Endpoints this module adds, in [ApiConstant]'s style but kept separate so
/// installing the module needs no edit to the core api_const.dart.
///
/// Both paths point at YOUR backend, never at api.stripe.com — the secret key
/// lives server-side and must never reach the app.
class PaymentApiConst {
  /// Path segment the payment service is mounted under.
  static const String pay = '/pay';

  // ── Payment endpoints ──
  /// POST — backend creates the PaymentIntent and returns only client_secret.
  static const String createPaymentIntentUri = '$pay/stripe/payment-intent';

  /// GET — backend reports the status it learned from the Stripe webhook.
  static const String paymentStatusUri = '$pay/stripe/payment-status';
}
