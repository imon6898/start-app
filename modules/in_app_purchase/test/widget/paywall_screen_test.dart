import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/app/feature/purchases/purchases_controllers/paywall_controller.dart';
import 'package:flutter_starter/app/feature/purchases/purchases_presentation/paywall_screen.dart';
import 'package:flutter_starter/app/services/purchases_service.dart';

/// There is no store in a test environment, so `isAvailable` is false and the
/// product query never answers. That is exactly the degraded path worth
/// covering: the screen must still show restore and the legal links.
void main() {
  const timeout = Duration(milliseconds: 50);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PurchasesService.productQueryTimeout = timeout;
    Get.lazyPut<PaywallController>(() => PaywallController(), fenix: true);
  });

  tearDown(Get.reset);

  /// Pumps past the product-query timeout so no timer outlives the test.
  Future<void> pumpPaywall(WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: PaywallScreen()));
    await tester.pump(timeout * 4);
  }

  testWidgets('shows the restore button App Store review requires',
      (tester) async {
    await pumpPaywall(tester);
    expect(find.text('Restore purchases'), findsOneWidget);
  });

  testWidgets('links to Terms of Service and Privacy Policy', (tester) async {
    await pumpPaywall(tester);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('discloses the auto-renewal terms on the purchase screen',
      (tester) async {
    await pumpPaywall(tester);
    expect(find.textContaining('renew automatically'), findsOneWidget);
  });

  testWidgets('says so when billing is unavailable instead of failing silently',
      (tester) async {
    await pumpPaywall(tester);
    expect(find.textContaining('not available on this device'), findsOneWidget);
  });

  testWidgets('a store query that never answers falls back to the empty state',
      (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: PaywallScreen()));
    expect(find.text('Loading plans'), findsOneWidget);

    await tester.pump(timeout * 4);
    expect(find.text('Loading plans'), findsNothing);
    expect(find.text('No plans available'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the buy button is disabled with nothing selectable',
      (tester) async {
    await pumpPaywall(tester);
    final ElevatedButton button = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(button.onPressed, isNull);
  });
}
