// What YOUR backend says the user is allowed to use. Never derived from the
// store client — see purchases_service.dart for why.

/// Subscription lifecycle as the server reports it.
enum EntitlementState {
  /// No purchase on record.
  none,

  /// Paid and current.
  active,

  /// Inside an introductory / free trial period.
  trial,

  /// Renewal failed; the store is retrying and access should continue.
  gracePeriod,

  /// Billing failed past the grace period — access must stop.
  onHold,

  /// User paused the subscription (Google Play only).
  paused,

  /// Term ended without renewal.
  expired,

  /// Money was returned; revoke immediately.
  refunded,

  /// Store has not settled the payment yet (Ask to Buy, cash, slow card).
  pending;

  static EntitlementState parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'[-\s]'), '_')) {
      case 'active':
      case 'subscribed':
        return EntitlementState.active;
      case 'trial':
      case 'in_trial':
      case 'trialing':
        return EntitlementState.trial;
      case 'grace_period':
      case 'in_grace_period':
      case 'grace':
        return EntitlementState.gracePeriod;
      case 'on_hold':
      case 'hold':
        return EntitlementState.onHold;
      case 'paused':
        return EntitlementState.paused;
      case 'expired':
      case 'canceled':
      case 'cancelled':
        return EntitlementState.expired;
      case 'refunded':
      case 'revoked':
      case 'chargeback':
        return EntitlementState.refunded;
      case 'pending':
      case 'deferred':
        return EntitlementState.pending;
      default:
        return EntitlementState.none;
    }
  }
}

class EntitlementModel {
  final bool active;
  final EntitlementState state;
  final String? productId;

  /// Your own plan name (`pro`, `team`), not a store id.
  final String? tier;
  final DateTime? expiresAt;

  /// Store reports auto-renew is on. False means the term is the last one.
  final bool willRenew;

  /// `app_store` or `google_play`, echoed back by the server.
  final String? store;

  /// When the server last confirmed this. Set locally on every apply.
  final DateTime? verifiedAt;

  /// Server-supplied reason, shown when a verification is refused.
  final String? message;

  const EntitlementModel({
    required this.active,
    required this.state,
    this.productId,
    this.tier,
    this.expiresAt,
    this.willRenew = false,
    this.store,
    this.verifiedAt,
    this.message,
  });

  /// Default before the first server answer, and after sign-out.
  static const EntitlementModel empty = EntitlementModel(
    active: false,
    state: EntitlementState.none,
  );

  factory EntitlementModel.fromJson(dynamic json) {
    if (json is! Map) return empty;
    final map = json.cast<String, dynamic>();

    final state = EntitlementState.parse(
      (map['state'] ?? map['status'] ?? map['entitlement_state'])?.toString(),
    );

    return EntitlementModel(
      active: _bool(map['active'] ?? map['is_active'] ?? map['isActive']) ??
          _statePresumesAccess(state),
      state: state,
      productId: _string(map['product_id'] ?? map['productId']),
      tier: _string(map['tier'] ?? map['plan'] ?? map['entitlement']),
      expiresAt: _date(
        map['expires_at'] ??
            map['expiresAt'] ??
            map['expiry_date'] ??
            map['expires_date_ms'],
      ),
      willRenew:
          _bool(map['will_renew'] ?? map['willRenew'] ?? map['auto_renewing']) ??
              false,
      store: _string(map['store'] ?? map['source'] ?? map['platform']),
      verifiedAt: _date(map['verified_at'] ?? map['verifiedAt']),
      message: _string(map['message'] ?? map['reason']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'active': active,
        'state': state.name,
        'product_id': productId,
        'tier': tier,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'will_renew': willRenew,
        'store': store,
        'verified_at': verifiedAt?.toUtc().toIso8601String(),
        'message': message,
      };

  EntitlementModel copyWith({
    bool? active,
    EntitlementState? state,
    String? productId,
    String? tier,
    DateTime? expiresAt,
    bool? willRenew,
    String? store,
    DateTime? verifiedAt,
    String? message,
  }) {
    return EntitlementModel(
      active: active ?? this.active,
      state: state ?? this.state,
      productId: productId ?? this.productId,
      tier: tier ?? this.tier,
      expiresAt: expiresAt ?? this.expiresAt,
      willRenew: willRenew ?? this.willRenew,
      store: store ?? this.store,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      message: message ?? this.message,
    );
  }

  /// The server's verdict, with the states that must revoke access removed.
  bool get grantsAccess =>
      active &&
      state != EntitlementState.expired &&
      state != EntitlementState.refunded &&
      state != EntitlementState.onHold &&
      state != EntitlementState.none;

  /// Offline fallback. The device clock is user-controlled, so an expiry check
  /// here is a courtesy to honest users, never proof of anything.
  bool grantsAccessAt(DateTime now) =>
      grantsAccess && (expiresAt == null || now.isBefore(expiresAt!));

  bool get isInTrial => state == EntitlementState.trial;

  bool get needsAttention =>
      state == EntitlementState.gracePeriod ||
      state == EntitlementState.onHold ||
      state == EntitlementState.paused;

  static bool _statePresumesAccess(EntitlementState state) =>
      state == EntitlementState.active ||
      state == EntitlementState.trial ||
      state == EntitlementState.gracePeriod;

  static String? _string(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static bool? _bool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return null;
  }

  // Accepts ISO-8601 and epoch milliseconds — Apple sends `expires_date_ms`.
  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is num) return _fromEpoch(v.toInt());
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final epoch = int.tryParse(s);
    if (epoch != null) return _fromEpoch(epoch);
    return DateTime.tryParse(s);
  }

  // A 10-digit value is seconds, 13 digits is milliseconds.
  static DateTime _fromEpoch(int value) => value.abs() < 100000000000
      ? DateTime.fromMillisecondsSinceEpoch(value * 1000)
      : DateTime.fromMillisecondsSinceEpoch(value);
}
