import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/app/feature/purchases/purchases_logic/entitlement_store.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_logic/purchases_api_const.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_logic/purchases_catalog.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_models/entitlement_model.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_models/purchase_outcome.dart';

/// Pure logic only — no platform channels, no store, no network.
void main() {
  group('EntitlementState.parse', () {
    test('maps the spellings a backend is likely to send', () {
      expect(EntitlementState.parse('active'), EntitlementState.active);
      expect(EntitlementState.parse('IN_TRIAL'), EntitlementState.trial);
      expect(
        EntitlementState.parse('grace-period'),
        EntitlementState.gracePeriod,
      );
      expect(EntitlementState.parse('on hold'), EntitlementState.onHold);
      expect(EntitlementState.parse('cancelled'), EntitlementState.expired);
      expect(EntitlementState.parse('chargeback'), EntitlementState.refunded);
      expect(EntitlementState.parse('deferred'), EntitlementState.pending);
    });

    test('anything unknown is none, never active', () {
      expect(EntitlementState.parse(null), EntitlementState.none);
      expect(EntitlementState.parse(''), EntitlementState.none);
      expect(EntitlementState.parse('whatever'), EntitlementState.none);
    });
  });

  group('EntitlementModel.fromJson', () {
    test('reads snake_case and camelCase', () {
      final snake = EntitlementModel.fromJson(<String, dynamic>{
        'active': true,
        'state': 'active',
        'product_id': 'pro_yearly',
        'will_renew': true,
      });
      final camel = EntitlementModel.fromJson(<String, dynamic>{
        'isActive': true,
        'status': 'active',
        'productId': 'pro_yearly',
        'willRenew': true,
      });

      expect(snake.productId, 'pro_yearly');
      expect(camel.productId, 'pro_yearly');
      expect(snake.willRenew, isTrue);
      expect(camel.willRenew, isTrue);
    });

    test('parses ISO-8601, epoch seconds and epoch milliseconds', () {
      final iso = EntitlementModel.fromJson(<String, dynamic>{
        'expires_at': '2030-01-02T03:04:05Z',
      });
      expect(iso.expiresAt!.toUtc().year, 2030);

      final millis = DateTime.utc(2030, 1, 2, 3, 4, 5).millisecondsSinceEpoch;
      final ms = EntitlementModel.fromJson(<String, dynamic>{
        'expires_date_ms': millis,
      });
      final secs = EntitlementModel.fromJson(<String, dynamic>{
        'expires_at': '${millis ~/ 1000}',
      });

      expect(ms.expiresAt!.millisecondsSinceEpoch, millis);
      expect(secs.expiresAt!.millisecondsSinceEpoch, millis);
    });

    test('a missing active flag is inferred from the state', () {
      final active = EntitlementModel.fromJson(<String, dynamic>{
        'state': 'active',
      });
      final expired = EntitlementModel.fromJson(<String, dynamic>{
        'state': 'expired',
      });

      expect(active.active, isTrue);
      expect(expired.active, isFalse);
    });

    test('a non-map payload degrades to empty instead of throwing', () {
      expect(EntitlementModel.fromJson('nope').state, EntitlementState.none);
      expect(EntitlementModel.fromJson(null).active, isFalse);
    });

    test('json round-trips through the cache format', () {
      final original = EntitlementModel.fromJson(<String, dynamic>{
        'active': true,
        'state': 'trial',
        'product_id': 'pro_monthly',
        'tier': 'pro',
        'expires_at': '2030-01-02T03:04:05Z',
        'will_renew': true,
        'store': 'app_store',
      });

      final restored = EntitlementModel.fromJson(original.toJson());

      expect(restored.state, EntitlementState.trial);
      expect(restored.tier, 'pro');
      expect(restored.store, 'app_store');
      expect(restored.expiresAt, original.expiresAt);
      expect(restored.grantsAccess, isTrue);
    });
  });

  group('grantsAccess', () {
    EntitlementModel of(EntitlementState state, {bool active = true}) =>
        EntitlementModel(active: active, state: state);

    test('active, trial and grace period grant access', () {
      expect(of(EntitlementState.active).grantsAccess, isTrue);
      expect(of(EntitlementState.trial).grantsAccess, isTrue);
      expect(of(EntitlementState.gracePeriod).grantsAccess, isTrue);
    });

    test('expired, refunded, on hold and none never grant access', () {
      expect(of(EntitlementState.expired).grantsAccess, isFalse);
      expect(of(EntitlementState.refunded).grantsAccess, isFalse);
      expect(of(EntitlementState.onHold).grantsAccess, isFalse);
      expect(of(EntitlementState.none).grantsAccess, isFalse);
    });

    test('active:false always loses, whatever the state says', () {
      expect(of(EntitlementState.active, active: false).grantsAccess, isFalse);
    });

    test('grantsAccessAt honours the expiry it was given', () {
      final expires = DateTime.utc(2030);
      final model = EntitlementModel(
        active: true,
        state: EntitlementState.active,
        expiresAt: expires,
      );

      expect(model.grantsAccessAt(expires.subtract(const Duration(days: 1))),
          isTrue);
      expect(
          model.grantsAccessAt(expires.add(const Duration(days: 1))), isFalse);
    });

    test('no expiry means a lifetime purchase, not an expired one', () {
      final model = EntitlementModel(
        active: true,
        state: EntitlementState.active,
      );
      expect(model.grantsAccessAt(DateTime.utc(2999)), isTrue);
    });
  });

  group('EntitlementStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      EntitlementStore.maxCacheAge = const Duration(days: 7);
    });

    test('nothing cached reads as null and stale', () async {
      await EntitlementStore.init();
      expect(EntitlementStore.cached, isNull);
      expect(EntitlementStore.isStale, isTrue);
    });

    test('a saved entitlement survives a reload', () async {
      await EntitlementStore.init();
      await EntitlementStore.save(
        const EntitlementModel(active: true, state: EntitlementState.active),
      );

      await EntitlementStore.init();
      expect(EntitlementStore.cached?.grantsAccess, isTrue);
      expect(EntitlementStore.isStale, isFalse);
    });

    test('a cache older than maxCacheAge is withheld', () async {
      await EntitlementStore.init();
      await EntitlementStore.save(
        const EntitlementModel(active: true, state: EntitlementState.active),
      );

      EntitlementStore.maxCacheAge = Duration.zero;
      expect(EntitlementStore.isStale, isTrue);
      expect(EntitlementStore.cached, isNull);
      // Still readable for a "last checked" label.
      expect(EntitlementStore.cachedEvenIfStale, isNotNull);
    });

    test('clear wipes it', () async {
      await EntitlementStore.init();
      await EntitlementStore.save(
        const EntitlementModel(active: true, state: EntitlementState.active),
      );
      await EntitlementStore.clear();

      expect(EntitlementStore.cached, isNull);
      await EntitlementStore.init();
      expect(EntitlementStore.cached, isNull);
    });
  });

  group('PurchasesCatalog', () {
    tearDown(() => PurchasesCatalog.configure(PurchasesCatalog.defaults));

    test('defaults expose every id once', () {
      PurchasesCatalog.configure(PurchasesCatalog.defaults);
      expect(
        PurchasesCatalog.productIds.length,
        PurchasesCatalog.defaults.length,
      );
    });

    test('configure replaces the list', () {
      PurchasesCatalog.configure(const <PurchaseProductConfig>[
        PurchaseProductConfig(id: 'a', kind: PurchaseKind.consumable),
      ]);

      expect(PurchasesCatalog.productIds, <String>{'a'});
      expect(PurchasesCatalog.kindOf('a'), PurchaseKind.consumable);
    });

    test('configure ignores an empty list rather than emptying the paywall',
        () {
      PurchasesCatalog.configure(PurchasesCatalog.defaults);
      PurchasesCatalog.configure(const <PurchaseProductConfig>[]);
      expect(PurchasesCatalog.productIds, isNotEmpty);
    });

    test('an unknown id defaults to subscription and sorts last', () {
      PurchasesCatalog.configure(PurchasesCatalog.defaults);
      expect(PurchasesCatalog.kindOf('mystery'), PurchaseKind.subscription);
      expect(
        PurchasesCatalog.orderOf('mystery'),
        greaterThan(PurchasesCatalog.orderOf(PurchasesCatalog.defaults.last.id)),
      );
    });

    test('orderOf follows declaration order', () {
      PurchasesCatalog.configure(const <PurchaseProductConfig>[
        PurchaseProductConfig(id: 'second', kind: PurchaseKind.subscription),
        PurchaseProductConfig(id: 'first', kind: PurchaseKind.subscription),
      ]);

      expect(PurchasesCatalog.orderOf('second'), 0);
      expect(PurchasesCatalog.orderOf('first'), 1);
    });
  });

  group('PurchaseOutcome', () {
    test('only PurchaseGranted carries an entitlement', () {
      const PurchaseOutcome granted = PurchaseGranted(
        productId: 'pro_yearly',
        entitlement: EntitlementModel(
          active: true,
          state: EntitlementState.active,
        ),
      );

      expect(granted, isA<PurchaseGranted>());
      expect((granted as PurchaseGranted).entitlement.grantsAccess, isTrue);
      expect(granted.restored, isFalse);
    });

    test('an unreachable server is distinguishable from a refusal', () {
      const refused = PurchaseUnverified(reason: 'bad receipt');
      const offline =
          PurchaseUnverified(reason: 'timeout', serverReachable: false);

      expect(refused.serverReachable, isTrue);
      expect(offline.serverReachable, isFalse);
    });
  });

  group('PurchasesApiConst', () {
    test('every endpoint is a relative path on our own API', () {
      for (final String uri in <String>[
        PurchasesApiConst.verifyPurchaseUri,
        PurchasesApiConst.syncPurchasesUri,
        PurchasesApiConst.entitlementUri,
      ]) {
        expect(uri.startsWith('/'), isTrue, reason: uri);
        expect(uri.contains('apple.com'), isFalse);
        expect(uri.contains('googleapis.com'), isFalse);
      }
    });
  });
}
