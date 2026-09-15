import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_starter/app/widgets/layout/adaptive_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Resizes the test view instead of mocking MediaQuery, so `R`, `CustomColors`
/// and the widgets all see the same window.
void main() {
  const List<AdaptiveDestination> destinations = <AdaptiveDestination>[
    AdaptiveDestination(icon: LucideIcons.house, label: 'Home'),
    AdaptiveDestination(icon: LucideIcons.search, label: 'Search'),
    AdaptiveDestination(icon: LucideIcons.user, label: 'Profile'),
  ];

  void sizeView(
    WidgetTester tester,
    Size logical, {
    List<ui.DisplayFeature> features = const <ui.DisplayFeature>[],
  }) {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = logical
      ..displayFeatures = features;
    addTearDown(tester.view.reset);
  }

  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(GetMaterialApp(home: child));

  Widget scaffold() => AdaptiveScaffold(
    destinations: destinations,
    selectedIndex: 0,
    onDestinationSelected: (_) {},
    body: const Text('body'),
  );

  group('AdaptiveScaffold picks one of three renderings', () {
    testWidgets('compact shows the bottom bar only', (tester) async {
      sizeView(tester, const Size(390, 844));
      await pump(tester, scaffold());

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationDrawer), findsNothing);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('medium shows the rail only', (tester) async {
      sizeView(tester, const Size(700, 1000));
      await pump(tester, scaffold());

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationDrawer), findsNothing);
    });

    testWidgets('expanded pins the drawer open', (tester) async {
      sizeView(tester, const Size(1200, 900));
      await pump(tester, scaffold());

      expect(find.byType(NavigationDrawer), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('a short compact window gets the rail', (tester) async {
      sizeView(tester, const Size(560, 360));
      await pump(tester, scaffold());

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('MasterDetailView', () {
    Widget masterDetail() => Scaffold(
      body: MasterDetailView<String>(
        // Each pane is its own Scaffold: on compact it becomes a real page.
        masterBuilder:
            (BuildContext context, ValueChanged<String> onSelect, _) {
              return Scaffold(
                body: ListView(
                  children: <Widget>[
                    for (final String item in <String>['one', 'two'])
                      ListTile(
                        title: Text('item $item'),
                        onTap: () => onSelect(item),
                      ),
                  ],
                ),
              );
            },
        detailBuilder: (BuildContext context, String item, _) => Scaffold(
          appBar: AppBar(
            leading: const AdaptiveDetailBackButton(),
            title: Text('detail $item'),
          ),
          body: const SizedBox.shrink(),
        ),
        placeholderBuilder: (_) => const Text('nothing selected'),
      ),
    );

    testWidgets('compact stacks the detail and comes back', (tester) async {
      sizeView(tester, const Size(390, 844));
      await pump(tester, masterDetail());

      expect(find.text('item one'), findsOneWidget);
      expect(find.text('nothing selected'), findsNothing);

      await tester.tap(find.text('item one'));
      await tester.pumpAndSettle();

      expect(find.text('detail one'), findsOneWidget);
      expect(find.text('item one'), findsNothing);

      await tester.tap(find.byType(AdaptiveDetailBackButton));
      await tester.pumpAndSettle();

      expect(find.text('item one'), findsOneWidget);
      expect(find.text('detail one'), findsNothing);
    });

    testWidgets('the system back gesture pops the detail, not the screen', (
      tester,
    ) async {
      sizeView(tester, const Size(390, 844));
      await pump(tester, masterDetail());
      await tester.tap(find.text('item one'));
      await tester.pumpAndSettle();

      final bool handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.text('item one'), findsOneWidget);
      expect(find.text('detail one'), findsNothing);
    });

    testWidgets('expanded shows both panes at once', (tester) async {
      sizeView(tester, const Size(1200, 900));
      await pump(tester, masterDetail());

      expect(find.text('nothing selected'), findsOneWidget);

      await tester.tap(find.text('item two'));
      await tester.pumpAndSettle();

      expect(find.text('item two'), findsOneWidget);
      expect(find.text('detail two'), findsOneWidget);
      // Nothing to go back to, so the back button renders as empty space.
      expect(find.byIcon(LucideIcons.arrowLeft), findsNothing);
    });

    testWidgets('a hinge moves the seam onto the hinge', (tester) async {
      sizeView(
        tester,
        const Size(1114, 705),
        features: const <ui.DisplayFeature>[
          ui.DisplayFeature(
            bounds: Rect.fromLTRB(540, 0, 574, 705),
            type: ui.DisplayFeatureType.hinge,
            state: ui.DisplayFeatureState.postureFlat,
          ),
        ],
      );
      await pump(
        tester,
        Scaffold(
          body: MasterDetailView<String>(
            masterFraction: 0.2, // Ignored: the hardware wins.
            masterBuilder: (_, _, _) => const Text('master'),
            detailBuilder: (_, _, _) => const SizedBox.shrink(),
            placeholderBuilder: (_) => const Text('detail'),
          ),
        ),
      );

      expect(tester.getSize(find.text('master')).width, lessThanOrEqualTo(540));
      expect(
        tester.getTopLeft(find.text('detail')).dx,
        greaterThanOrEqualTo(574),
      );
    });
  });

  group('AdaptiveGrid', () {
    const int tiles = 12;

    Future<void> pumpGrid(WidgetTester tester, Size size) async {
      sizeView(tester, size);
      await pump(
        tester,
        Scaffold(
          body: AdaptiveGrid(
            itemCount: tiles,
            targetTileWidth: 180,
            spacing: 0,
            tileHeight: 120,
            itemBuilder: (_, int i) => ColoredBox(
              key: ValueKey<int>(i),
              color: const Color(0xFF000000),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    int firstRowCount(WidgetTester tester) {
      final double top = tester
          .getTopLeft(find.byKey(const ValueKey<int>(0)))
          .dy;
      var count = 0;
      for (var i = 0; i < tiles; i++) {
        final Finder tile = find.byKey(ValueKey<int>(i));
        if (tile.evaluate().isEmpty) continue;
        if ((tester.getTopLeft(tile).dy - top).abs() < 0.5) count++;
      }
      return count;
    }

    testWidgets('more columns on a wider window, same target tile', (
      tester,
    ) async {
      await pumpGrid(tester, const Size(390, 844));
      final int narrow = firstRowCount(tester);

      await pumpGrid(tester, const Size(1200, 900));
      final int wide = firstRowCount(tester);

      expect(narrow, greaterThanOrEqualTo(2));
      expect(wide, greaterThan(narrow));
    });
  });
}
