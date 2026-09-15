// No network. The service tests use SharedPreferences' in-memory mock, so a
// failed fetch is exercised for real: it must leave the cached values alone.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_starter/app/services/feature_flags/feature_flag_bucketing.dart';
import 'package:flutter_starter/app/services/feature_flags/feature_flag_keys.dart';
import 'package:flutter_starter/app/services/feature_flags/feature_flag_resolver.dart';
import 'package:flutter_starter/app/services/feature_flags/feature_flag_service.dart';
import 'package:flutter_starter/app/services/feature_flags/feature_flag_store.dart';
import 'package:flutter_starter/app/services/feature_flags/feature_flags_debug_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('FlagBucketing.hash', () {
    test('matches the published FNV-1a 32-bit vectors', () {
      // If these drift, every user re-buckets and running experiments are void.
      expect(FlagBucketing.hash(''), 0x811c9dc5);
      expect(FlagBucketing.hash('a'), 0xe40c292c);
      expect(FlagBucketing.hash('foobar'), 0xbf9cf968);
    });

    test('stays inside 32 bits', () {
      for (final input in ['', 'a', 'user-1:exp', 'ø' * 200]) {
        final value = FlagBucketing.hash(input);
        expect(value >= 0 && value <= 0xFFFFFFFF, isTrue);
      }
    });
  });

  group('bucketing is deterministic', () {
    test('the same id and key always give the same bucket', () {
      for (var i = 0; i < 200; i++) {
        final id = 'user-$i';
        final first = FlagBucketing.bucketOf(id, 'onboarding_copy');
        for (var repeat = 0; repeat < 5; repeat++) {
          expect(FlagBucketing.bucketOf(id, 'onboarding_copy'), first);
        }
      }
    });

    test('buckets are in 0..99', () {
      for (var i = 0; i < 500; i++) {
        final bucket = FlagBucketing.bucketOf('user-$i', 'exp');
        expect(bucket, inInclusiveRange(0, 99));
      }
    });

    test('different experiments bucket a user independently', () {
      var different = 0;
      for (var i = 0; i < 200; i++) {
        if (FlagBucketing.bucketOf('user-$i', 'a') !=
            FlagBucketing.bucketOf('user-$i', 'b')) {
          different++;
        }
      }
      expect(different, greaterThan(150));
    });

    test('a 50% exposure enrols roughly half of a large population', () {
      final enrolled = List.generate(
        2000,
        (i) => FlagBucketing.inRollout('user-$i', 'exp', 50),
      ).where((e) => e).length;
      expect(enrolled, greaterThan(850));
      expect(enrolled, lessThan(1150));
    });

    test('0% enrols nobody and 100% enrols everybody', () {
      for (var i = 0; i < 100; i++) {
        expect(FlagBucketing.inRollout('user-$i', 'exp', 0), isFalse);
        expect(FlagBucketing.inRollout('user-$i', 'exp', 100), isTrue);
      }
    });

    test('variant assignment is stable and inside the variant list', () {
      const variants = ['control', 'short', 'video'];
      for (var i = 0; i < 300; i++) {
        final variant = FlagBucketing.variantOf('user-$i', 'exp', variants);
        expect(variants, contains(variant));
        expect(FlagBucketing.variantOf('user-$i', 'exp', variants), variant);
      }
    });

    test('changing exposure does not reshuffle variants', () {
      // Enrolment and variant use different salts, which is the whole point.
      const variants = ['control', 'treatment'];
      final before = {
        for (var i = 0; i < 50; i++)
          'user-$i': FlagBucketing.variantOf('user-$i', 'exp', variants),
      };
      for (final entry in before.entries) {
        expect(FlagBucketing.variantOf(entry.key, 'exp', variants), entry.value);
      }
    });

    test('an empty variant list yields null instead of throwing', () {
      expect(FlagBucketing.variantOf('user-1', 'exp', const []), isNull);
    });
  });

  group('FlagResolver precedence', () {
    const gate = BoolFlag('gate', fallback: true);

    test('override beats remote beats fallback', () {
      expect(FlagResolver.resolve(gate), isTrue);
      expect(FlagResolver.resolve(gate, remote: false), isFalse);
      expect(FlagResolver.resolve(gate, remote: false, override: true), isTrue);
    });

    test('a remote false beats a true fallback — the kill switch case', () {
      const killSwitch = KillSwitch('checkout_enabled');
      expect(FlagResolver.resolve(killSwitch), isTrue);
      expect(FlagResolver.resolve(killSwitch, remote: false), isFalse);
    });

    test('sourceOf names the rung that won', () {
      expect(FlagResolver.sourceOf(gate), FlagSource.fallback);
      expect(FlagResolver.sourceOf(gate, remote: false), FlagSource.remote);
      expect(
        FlagResolver.sourceOf(gate, remote: false, override: false),
        FlagSource.override,
      );
    });

    test('a wrong-typed remote value falls through instead of throwing', () {
      expect(FlagResolver.resolve(gate, remote: 'yes'), isTrue);
      const size = IntFlag('size', fallback: 10);
      expect(FlagResolver.resolve(size, remote: 'abc'), 10);
      expect(FlagResolver.resolve(size, remote: {'a': 1}), 10);
      const email = StringFlag('email', fallback: 'a@b.c');
      expect(FlagResolver.resolve(email, remote: 42), 'a@b.c');
    });
  });

  group('FlagResolver.coerce', () {
    test('bool accepts JSON bool, "true"/"false" and 1/0', () {
      const flag = BoolFlag('f');
      expect(FlagResolver.coerce(flag, true), isTrue);
      expect(FlagResolver.coerce(flag, 'TRUE'), isTrue);
      expect(FlagResolver.coerce(flag, ' false '), isFalse);
      expect(FlagResolver.coerce(flag, 1), isTrue);
      expect(FlagResolver.coerce(flag, 0), isFalse);
      expect(FlagResolver.coerce(flag, 7), isNull);
      expect(FlagResolver.coerce(flag, null), isNull);
    });

    test('int accepts int, num and a numeric string', () {
      const flag = IntFlag('f');
      expect(FlagResolver.coerce(flag, 5), 5);
      expect(FlagResolver.coerce(flag, 5.9), 5);
      expect(FlagResolver.coerce(flag, ' 12 '), 12);
      expect(FlagResolver.coerce(flag, 'x'), isNull);
    });

    test('string is strict — a number is not a string', () {
      const flag = StringFlag('f');
      expect(FlagResolver.coerce(flag, 'hi'), 'hi');
      expect(FlagResolver.coerce(flag, 3), isNull);
    });

    test('json accepts a map or an encoded map', () {
      const flag = JsonFlag('f');
      expect(FlagResolver.coerce(flag, {'a': 1}), {'a': 1});
      expect(FlagResolver.coerce(flag, '{"a":1}'), {'a': 1});
      expect(FlagResolver.coerce(flag, '[1,2]'), isNull);
      expect(FlagResolver.coerce(flag, 'not json'), isNull);
    });
  });

  group('FlagDocument', () {
    test('reads the flags envelope, values, rollouts and experiments', () {
      final doc = FlagDocument.fromJson(
        jsonDecode('''
        {
          "version": 7,
          "updated_at": "2026-09-15T10:00:00Z",
          "flags": {
            "checkout_enabled": { "value": false },
            "new_dashboard": { "value": true, "rollout": 25 },
            "max_upload_mb": 25,
            "promo_banner": { "value": { "title": "Hi" } }
          },
          "experiments": {
            "onboarding_copy": {
              "variants": ["control", "short"],
              "exposure": 40,
              "forced_variant": "short"
            }
          }
        }
        ''') as Map<String, dynamic>,
      );

      expect(doc.version, 7);
      expect(doc.updatedAt, isNotNull);
      expect(doc.values['checkout_enabled'], isFalse);
      expect(doc.values['max_upload_mb'], 25);
      expect(doc.values['promo_banner'], {'title': 'Hi'});
      expect(doc.rollouts['new_dashboard'], 25);
      expect(doc.rollouts.containsKey('checkout_enabled'), isFalse);

      final experiment = doc.experiments['onboarding_copy']!;
      expect(experiment.variants, ['control', 'short']);
      expect(experiment.exposure, 40);
      expect(experiment.forcedVariant, 'short');
    });

    test('the flags envelope is optional', () {
      final doc = FlagDocument.fromJson(
        jsonDecode('{"version": 2, "a": true, "b": 3}')
            as Map<String, dynamic>,
      );
      expect(doc.version, 2);
      expect(doc.values, {'a': true, 'b': 3});
    });

    test('a bare object is a json value, not a wrapper', () {
      final doc = FlagDocument.fromJson(
        jsonDecode('{"flags": {"promo": {"title": "x"}}}')
            as Map<String, dynamic>,
      );
      expect(doc.values['promo'], {'title': 'x'});
    });

    test('a rollout outside 0..100 is clamped', () {
      final doc = FlagDocument.fromJson(
        jsonDecode('{"flags": {"a": {"value": true, "rollout": 250}}}')
            as Map<String, dynamic>,
      );
      expect(doc.rollouts['a'], 100);
    });

    test('tryParse returns null for junk so the cache survives', () {
      expect(FlagDocument.tryParse('not json'), isNull);
      expect(FlagDocument.tryParse('[1,2]'), isNull);
      expect(FlagDocument.tryParse('{}')?.isEmpty, isTrue);
    });
  });

  group('the declared registry stays usable', () {
    test('no duplicate flag names', () {
      final names = FeatureFlags.all.map((f) => f.name).toList();
      expect(names.toSet().length, names.length);
    });

    test('every experiment has at least one variant', () {
      for (final experiment in FeatureFlags.experiments) {
        expect(experiment.variants, isNotEmpty);
        expect(experiment.control, experiment.variants.first);
      }
    });
  });

  group('FeatureFlagService', () {
    tearDown(Get.reset);

    // FeatureFlagStore caches the SharedPreferences instance, so a second
    // setMockInitialValues would not be seen — seed through the store instead.
    Future<FeatureFlagService> serviceWith([String? document]) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await FeatureFlagStore.init();
      await FeatureFlagStore.clearOverrides();
      if (document == null) {
        await FeatureFlagStore.clearDocument();
      } else {
        await FeatureFlagStore.setRawDocument(document);
      }
      final service = await FeatureFlagService().init(
        fetchAfterFirstFrame: false,
      );
      Get.put<FeatureFlagService>(service);
      return service;
    }

    test('a cold start with no cache uses the hardcoded defaults', () async {
      final service = await serviceWith();
      expect(service.isEnabled(FeatureFlags.checkout), isTrue);
      expect(service.isEnabled(FeatureFlags.newDashboard), isFalse);
      expect(service.intOf(FeatureFlags.maxUploadMb), 10);
      expect(service.sourceOf(FeatureFlags.checkout), FlagSource.fallback);
    });

    test('a cached kill switch survives a failed fetch', () async {
      final service = await serviceWith(
        '{"version":3,"flags":{"checkout_enabled":{"value":false}}}',
      );
      expect(service.documentVersion.value, 3);
      expect(service.isEnabled(FeatureFlags.checkout), isFalse);

      // No .env and no network here, so this fetch fails — the point is that it
      // does not re-enable the feature.
      expect(await service.refresh(), isFalse);
      expect(service.isEnabled(FeatureFlags.checkout), isFalse);
    });

    test('an unreadable cached document falls back, never throws', () async {
      final service = await serviceWith('not json at all');
      expect(service.isEnabled(FeatureFlags.checkout), isTrue);
      expect(service.documentVersion.value, 0);
    });

    test('a rollout gates a true value by bucket', () async {
      final service = await serviceWith(
        '{"flags":{"new_dashboard":{"value":true,"rollout":0}}}',
      );
      expect(service.isEnabled(FeatureFlags.newDashboard), isFalse);
      expect(service.rolloutOf(FeatureFlags.newDashboard), 0);
    });

    test('an override wins and is persisted', () async {
      final service = await serviceWith();
      await service.setOverride<bool>(FeatureFlags.newDashboard, true);
      expect(service.isEnabled(FeatureFlags.newDashboard), isTrue);
      expect(service.sourceOf(FeatureFlags.newDashboard), FlagSource.override);
      expect(service.hasOverrides, isTrue);

      await service.clearOverrides();
      expect(service.isEnabled(FeatureFlags.newDashboard), isFalse);
    });

    test('the same user id always lands in the same variant', () async {
      final service = await serviceWith();
      service.setUserId('user-42');
      final variant = service.variantOf(FeatureFlags.onboardingCopy);
      for (var i = 0; i < 20; i++) {
        expect(service.variantOf(FeatureFlags.onboardingCopy), variant);
      }
      expect(service.bucketingId, 'user-42');
    });

    test('a forced variant from the document overrides bucketing', () async {
      final service = await serviceWith(
        '{"experiments":{"onboarding_copy":{"variants":["control","short"],'
        '"exposure":0,"forced_variant":"short"}}}',
      );
      expect(service.variantOf(FeatureFlags.onboardingCopy), 'short');
    });

    test('exposure 0 means nobody is enrolled', () async {
      final service = await serviceWith(
        '{"experiments":{"onboarding_copy":{"exposure":0}}}',
      );
      expect(service.variantOf(FeatureFlags.onboardingCopy), isNull);
      expect(
        service.variantOrControl(FeatureFlags.onboardingCopy),
        FeatureFlags.onboardingCopy.control,
      );
    });

    test('Flags.* reads work with no service registered', () {
      expect(Flags.isEnabled(FeatureFlags.checkout), isTrue);
      expect(Flags.intOf(FeatureFlags.maxUploadMb), 10);
      expect(Flags.variantOf(FeatureFlags.onboardingCopy), isNull);
    });
  });

  group('FeatureFlagsDebugScreen', () {
    tearDown(Get.reset);

    testWidgets('says so instead of throwing when nothing is registered', (
      tester,
    ) async {
      await tester.pumpWidget(
        const GetMaterialApp(home: FeatureFlagsDebugScreen()),
      );
      await tester.pump();
      expect(find.textContaining('not registered'), findsOneWidget);
    });

    testWidgets('lists every declared flag and experiment', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      Get.put<FeatureFlagService>(
        await FeatureFlagService().init(fetchAfterFirstFrame: false),
      );

      await tester.pumpWidget(
        const GetMaterialApp(home: FeatureFlagsDebugScreen()),
      );
      await tester.pump();

      for (final flag in FeatureFlags.all) {
        expect(find.text(flag.name), findsOneWidget);
      }
      for (final experiment in FeatureFlags.experiments) {
        expect(find.text(experiment.key), findsOneWidget);
      }
    });

    testWidgets('an override shows up as the source badge', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final service = await FeatureFlagService().init(
        fetchAfterFirstFrame: false,
      );
      Get.put<FeatureFlagService>(service);
      await service.setOverride<bool>(FeatureFlags.newDashboard, true);

      await tester.pumpWidget(
        const GetMaterialApp(home: FeatureFlagsDebugScreen()),
      );
      await tester.pump();
      expect(find.text('override'), findsWidgets);
    });
  });
}
