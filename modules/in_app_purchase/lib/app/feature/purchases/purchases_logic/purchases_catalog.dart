import 'package:flutter_starter/app/core/config/env.dart';

/// How a product must be bought. The store has no runtime flag for this, so it
/// has to be declared here.
enum PurchaseKind {
  /// Auto-renewing subscription (Play: subs, App Store: auto-renewable).
  subscription,

  /// Bought once, owned forever. Restorable.
  nonConsumable,

  /// Bought repeatedly (coins, credits). NOT returned by restore.
  consumable,
}

class PurchaseProductConfig {
  /// Store product id — must match App Store Connect and Play Console exactly.
  final String id;
  final PurchaseKind kind;

  /// Tile ribbon, e.g. `Best value`. Localised through `.tr` in the UI.
  final String? badge;

  /// Pre-selected and visually emphasised on the paywall.
  final bool highlighted;

  const PurchaseProductConfig({
    required this.id,
    required this.kind,
    this.badge,
    this.highlighted = false,
  });
}

/// The product list the paywall queries. Replace [defaults] or call
/// [configure] from bootstrap — editing this file is not required.
class PurchasesCatalog {
  PurchasesCatalog._();

  /// Placeholder ids. They will come back in `notFoundIDs` until you create
  /// the real ones in both consoles.
  static const List<PurchaseProductConfig> defaults = <PurchaseProductConfig>[
    PurchaseProductConfig(id: 'pro_monthly', kind: PurchaseKind.subscription),
    PurchaseProductConfig(
      id: 'pro_yearly',
      kind: PurchaseKind.subscription,
      badge: 'Best value',
      highlighted: true,
    ),
    PurchaseProductConfig(
      id: 'pro_lifetime',
      kind: PurchaseKind.nonConsumable,
    ),
  ];

  static List<PurchaseProductConfig> _products = _fromEnv() ?? defaults;

  static List<PurchaseProductConfig> get products => _products;

  /// Call before the paywall opens to supply real ids from your own config.
  static void configure(List<PurchaseProductConfig> products) {
    if (products.isEmpty) return;
    _products = List<PurchaseProductConfig>.unmodifiable(products);
  }

  static Set<String> get productIds =>
      _products.map((p) => p.id).toSet();

  static PurchaseProductConfig? configFor(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  static PurchaseKind kindOf(String id) =>
      configFor(id)?.kind ?? PurchaseKind.subscription;

  /// Catalog order, used to sort whatever the store returns.
  static int orderOf(String id) {
    final index = _products.indexWhere((p) => p.id == id);
    return index < 0 ? _products.length : index;
  }

  static PurchaseProductConfig? get highlighted {
    for (final p in _products) {
      if (p.highlighted) return p;
    }
    return null;
  }

  /// Optional `.env` override so store ids can change without a code edit.
  /// Read through `Env.optional`, so `Env.requiredKeys` stays untouched.
  static List<PurchaseProductConfig>? _fromEnv() {
    List<String> read(String key) {
      // dotenv throws NotInitializedError before Env.load(); a widget test that
      // skips bootstrap must still be able to read the catalog.
      try {
        return _split(Env.optional(key));
      } catch (_) {
        return const <String>[];
      }
    }

    final subs = read('IAP_SUBSCRIPTION_IDS');
    final owned = read('IAP_NON_CONSUMABLE_IDS');
    final consumables = read('IAP_CONSUMABLE_IDS');
    if (subs.isEmpty && owned.isEmpty && consumables.isEmpty) return null;

    return <PurchaseProductConfig>[
      for (final id in subs)
        PurchaseProductConfig(id: id, kind: PurchaseKind.subscription),
      for (final id in owned)
        PurchaseProductConfig(id: id, kind: PurchaseKind.nonConsumable),
      for (final id in consumables)
        PurchaseProductConfig(id: id, kind: PurchaseKind.consumable),
    ];
  }

  static List<String> _split(String raw) => raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}
