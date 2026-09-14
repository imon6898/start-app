/// A PaymentIntent as returned by YOUR backend — never created on the client.
/// The backend holds the Stripe secret key and decides [amount]; the app only
/// ever receives [clientSecret] and hands it to the Stripe SDK.
class PaymentIntentModel {
  /// The only value the app needs to confirm a payment.
  final String? clientSecret;
  final String? paymentIntentId;

  /// Minor units (cents). Display only — the server figure is authoritative.
  final int? amount;
  final String? currency;
  final String? status;

  /// Set these two only if the backend created a Customer + ephemeral key.
  final String? customerId;
  final String? ephemeralKey;

  PaymentIntentModel({
    this.clientSecret,
    this.paymentIntentId,
    this.amount,
    this.currency,
    this.status,
    this.customerId,
    this.ephemeralKey,
  });

  PaymentIntentModel copyWith({
    String? clientSecret,
    String? paymentIntentId,
    int? amount,
    String? currency,
    String? status,
    String? customerId,
    String? ephemeralKey,
  }) {
    return PaymentIntentModel(
      clientSecret: clientSecret ?? this.clientSecret,
      paymentIntentId: paymentIntentId ?? this.paymentIntentId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      customerId: customerId ?? this.customerId,
      ephemeralKey: ephemeralKey ?? this.ephemeralKey,
    );
  }

  /// Accepts snake_case or camelCase so most backends parse without a mapper.
  factory PaymentIntentModel.fromJson(Map<String, dynamic> json) {
    return PaymentIntentModel(
      clientSecret: json['client_secret'] ?? json['clientSecret'],
      paymentIntentId:
          json['payment_intent_id'] ?? json['paymentIntentId'] ?? json['id'],
      amount: _toInt(json['amount']),
      currency: json['currency'],
      status: json['status'],
      customerId: json['customer_id'] ?? json['customerId'] ?? json['customer'],
      ephemeralKey:
          json['ephemeral_key'] ??
          json['ephemeralKey'] ??
          json['ephemeral_key_secret'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_secret': clientSecret,
      'payment_intent_id': paymentIntentId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'customer_id': customerId,
      'ephemeral_key': ephemeralKey,
    };
  }

  /// Some backends serialise amounts as strings.
  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
