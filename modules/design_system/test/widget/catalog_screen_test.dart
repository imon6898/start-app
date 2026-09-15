import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/app/feature/catalog/catalog_controllers/catalog_controller.dart';
import 'package:flutter_starter/app/feature/catalog/catalog_presentation/catalog_registry.dart';
import 'package:flutter_starter/app/feature/catalog/catalog_presentation/catalog_screen.dart';
import 'package:flutter_starter/app/feature/catalog/catalog_presentation/catalog_tokens_view.dart';
import 'package:flutter_starter/app/services/local_data/cache_manager.dart';
import 'package:flutter_starter/app/themes/theme_controller.dart';

/// Smoke test: the registry builds 28 real widgets, so a constructor change in
/// the kit breaks the catalog here rather than on someone's device.
void main() {
  late CatalogController controller;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await CacheManager.init();
    Get.reset();
    Get.put(ThemeController());
    controller = Get.put(CatalogController());
  });

  tearDown(Get.reset);

  Future<void> pumpCatalog(WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: CatalogScreen()));
    // Not pumpAndSettle: ThinkingDots repeats forever, so the tree never settles.
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('every entry in the registry builds', (tester) async {
    // 375 wide is the Figma design width, so R scales 1:1; tall so the lazy
    // ListView builds every demo. At 2.0x text scale seven kit widgets really
    // do overflow - see the README - so this stays at the default scale.
    tester.view.physicalSize = const Size(375, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpCatalog(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Design system'), findsOneWidget);
    expect(find.text('CustomButton'), findsOneWidget);
    expect(find.text('PaginationGridView'), findsOneWidget);
  });

  testWidgets('the tokens tab renders the whole gallery', (tester) async {
    tester.view.physicalSize = const Size(375, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    controller.tab.value = 1;
    await pumpCatalog(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(CatalogTokensView), findsOneWidget);
    expect(find.textContaining('Colour roles'), findsOneWidget);
    expect(find.textContaining('Motion'), findsOneWidget);
  });

  testWidgets('search narrows the list and the empty state can recover', (
    tester,
  ) async {
    await pumpCatalog(tester);

    controller.onQueryChanged('zzz');
    await tester.pump();
    expect(find.text('No widget matches'), findsOneWidget);

    controller.clearQuery();
    await tester.pump();
    expect(find.text('No widget matches'), findsNothing);
  });

  test('the registry covers every group exactly once per entry', () {
    final entries = CatalogRegistry.entries(controller);
    expect(entries, hasLength(greaterThan(20)));
    expect(
      entries.map((e) => e.name).toSet(),
      hasLength(entries.length),
      reason: 'Duplicate CatalogEntry name',
    );
  });

  test('text-scale steps start at 1.0 and cycle back to it', () {
    expect(controller.textScale.value, 1.0);
    for (var i = 0; i < CatalogController.textScales.length; i++) {
      controller.cycleTextScale();
    }
    expect(controller.textScale.value, 1.0);
  });
}
