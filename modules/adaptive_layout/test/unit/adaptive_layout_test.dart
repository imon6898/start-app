import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_starter/app/widgets/layout/adaptive_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every rule in this module is a pure function on purpose, so the decisions can
/// be tested without pumping a widget or faking a device.
void main() {
  group('AdaptiveBreakpoints.widthClass', () {
    test('phone widths are compact', () {
      expect(AdaptiveBreakpoints.widthClass(320), WindowSizeClass.compact);
      expect(AdaptiveBreakpoints.widthClass(599.9), WindowSizeClass.compact);
    });

    test('600 is the first medium width', () {
      expect(AdaptiveBreakpoints.widthClass(600), WindowSizeClass.medium);
      expect(AdaptiveBreakpoints.widthClass(839.9), WindowSizeClass.medium);
    });

    test('840 is the first expanded width', () {
      expect(AdaptiveBreakpoints.widthClass(840), WindowSizeClass.expanded);
      expect(AdaptiveBreakpoints.widthClass(1920), WindowSizeClass.expanded);
    });
  });

  group('AdaptiveBreakpoints.heightClass', () {
    test('a landscape phone is height-compact', () {
      expect(AdaptiveBreakpoints.heightClass(390), WindowSizeClass.compact);
    });

    test('480 and 900 are the height boundaries', () {
      expect(AdaptiveBreakpoints.heightClass(480), WindowSizeClass.medium);
      expect(AdaptiveBreakpoints.heightClass(899), WindowSizeClass.medium);
      expect(AdaptiveBreakpoints.heightClass(900), WindowSizeClass.expanded);
    });
  });

  group('WindowSizeClass', () {
    test('atLeast is inclusive and ordered', () {
      expect(WindowSizeClass.expanded.atLeast(WindowSizeClass.medium), isTrue);
      expect(WindowSizeClass.medium.atLeast(WindowSizeClass.medium), isTrue);
      expect(WindowSizeClass.compact.atLeast(WindowSizeClass.medium), isFalse);
    });

    test('pick falls back down the chain', () {
      expect(WindowSizeClass.medium.pick(compact: 1), 1);
      expect(WindowSizeClass.expanded.pick(compact: 1, medium: 2), 2);
      expect(
        WindowSizeClass.expanded.pick(compact: 1, medium: 2, expanded: 3),
        3,
      );
    });
  });

  group('AdaptiveScaffold.resolveStyle', () {
    test('portrait phone gets the bottom bar', () {
      expect(
        AdaptiveScaffold.resolveStyle(
          widthClass: WindowSizeClass.compact,
          heightClass: WindowSizeClass.expanded,
        ),
        AdaptiveNavigationStyle.bottomBar,
      );
    });

    test('short landscape phone gets the rail, not the bottom bar', () {
      expect(
        AdaptiveScaffold.resolveStyle(
          widthClass: WindowSizeClass.compact,
          heightClass: WindowSizeClass.compact,
        ),
        AdaptiveNavigationStyle.rail,
      );
    });

    test('medium width gets the rail', () {
      expect(
        AdaptiveScaffold.resolveStyle(
          widthClass: WindowSizeClass.medium,
          heightClass: WindowSizeClass.expanded,
        ),
        AdaptiveNavigationStyle.rail,
      );
    });

    test('expanded width pins the drawer open, or keeps the rail if asked', () {
      expect(
        AdaptiveScaffold.resolveStyle(
          widthClass: WindowSizeClass.expanded,
          heightClass: WindowSizeClass.expanded,
        ),
        AdaptiveNavigationStyle.drawer,
      );
      expect(
        AdaptiveScaffold.resolveStyle(
          widthClass: WindowSizeClass.expanded,
          heightClass: WindowSizeClass.expanded,
          useDrawerOnExpanded: false,
        ),
        AdaptiveNavigationStyle.rail,
      );
    });
  });

  group('MasterDetailView.shouldSplit', () {
    test('a phone never splits', () {
      expect(
        MasterDetailView.shouldSplit(
          availableWidth: 390,
          widthClass: WindowSizeClass.compact,
        ),
        isFalse,
      );
    });

    test('medium width stacks — two 320 panes do not fit', () {
      expect(
        MasterDetailView.shouldSplit(
          availableWidth: 800,
          widthClass: WindowSizeClass.medium,
        ),
        isFalse,
      );
    });

    test('expanded width splits', () {
      expect(
        MasterDetailView.shouldSplit(
          availableWidth: 900,
          widthClass: WindowSizeClass.expanded,
        ),
        isTrue,
      );
    });

    test('200% text scaling forces a small tablet back to stacked', () {
      expect(
        MasterDetailView.shouldSplit(
          availableWidth: 900,
          widthClass: WindowSizeClass.expanded,
          textScale: 2.0,
        ),
        isFalse,
      );
      // The same 2x text on a desktop window still has room for both panes.
      expect(
        MasterDetailView.shouldSplit(
          availableWidth: 1440,
          widthClass: WindowSizeClass.expanded,
          textScale: 2.0,
        ),
        isTrue,
      );
    });

    test('a separating hinge wins over the width maths', () {
      expect(
        MasterDetailView.shouldSplit(
          availableWidth: 700,
          widthClass: WindowSizeClass.medium,
          hasSeparatingHinge: true,
        ),
        isTrue,
      );
    });

    test('a hinge on a compact window still stacks', () {
      expect(
        MasterDetailView.shouldSplit(
          availableWidth: 400,
          widthClass: WindowSizeClass.compact,
          hasSeparatingHinge: true,
        ),
        isFalse,
      );
    });
  });

  group('HingeInfo.fromFeatures', () {
    const Size dualScreen = Size(1114, 705);

    test('a vertical hinge splits side by side', () {
      final HingeInfo? hinge = HingeInfo.fromFeatures(const <ui.DisplayFeature>[
        ui.DisplayFeature(
          bounds: Rect.fromLTRB(540, 0, 574, 705),
          type: ui.DisplayFeatureType.hinge,
          state: ui.DisplayFeatureState.postureFlat,
        ),
      ], dualScreen);

      expect(hinge, isNotNull);
      expect(hinge!.axis, Axis.vertical);
      expect(hinge.splitsSideBySide, isTrue);
      expect(hinge.thickness, 34);
      expect(hinge.isObstructing, isTrue);
    });

    test('a zero-width fold is detected but not obstructing', () {
      final HingeInfo? hinge = HingeInfo.fromFeatures(const <ui.DisplayFeature>[
        ui.DisplayFeature(
          bounds: Rect.fromLTRB(442, 0, 442, 705),
          type: ui.DisplayFeatureType.fold,
          state: ui.DisplayFeatureState.postureHalfOpened,
        ),
      ], dualScreen);

      expect(hinge!.thickness, 0);
      expect(hinge.isObstructing, isFalse);
      expect(hinge.isHalfOpened, isTrue);
    });

    test('a horizontal fold splits top and bottom', () {
      final HingeInfo? hinge = HingeInfo.fromFeatures(const <ui.DisplayFeature>[
        ui.DisplayFeature(
          bounds: Rect.fromLTRB(0, 350, 1114, 355),
          type: ui.DisplayFeatureType.fold,
          state: ui.DisplayFeatureState.postureFlat,
        ),
      ], dualScreen);

      expect(hinge!.axis, Axis.horizontal);
      expect(hinge.splitsSideBySide, isFalse);
      expect(hinge.thickness, 5);
    });

    test('a camera cutout is not a hinge', () {
      expect(
        HingeInfo.fromFeatures(const <ui.DisplayFeature>[
          ui.DisplayFeature(
            bounds: Rect.fromLTRB(500, 0, 614, 40),
            type: ui.DisplayFeatureType.cutout,
            state: ui.DisplayFeatureState.unknown,
          ),
        ], dualScreen),
        isNull,
      );
    });

    test('a feature that does not span the window is ignored', () {
      expect(
        HingeInfo.fromFeatures(const <ui.DisplayFeature>[
          ui.DisplayFeature(
            bounds: Rect.fromLTRB(540, 100, 574, 200),
            type: ui.DisplayFeatureType.hinge,
            state: ui.DisplayFeatureState.postureFlat,
          ),
        ], dualScreen),
        isNull,
      );
    });

    test('no features at all means no hinge', () {
      expect(
        HingeInfo.fromFeatures(const <ui.DisplayFeature>[], dualScreen),
        isNull,
      );
    });
  });

  group('AdaptiveGrid.columnsFor', () {
    test('rounds to the column count closest to the target width', () {
      expect(AdaptiveGrid.columnsFor(width: 380, targetTileWidth: 180), 2);
      expect(AdaptiveGrid.columnsFor(width: 1200, targetTileWidth: 180), 7);
    });

    test('spacing is taken out of the available width', () {
      expect(
        AdaptiveGrid.columnsFor(width: 360, targetTileWidth: 180, spacing: 12),
        2,
      );
    });

    test('never returns fewer than minColumns', () {
      expect(AdaptiveGrid.columnsFor(width: 100, targetTileWidth: 400), 1);
      expect(
        AdaptiveGrid.columnsFor(
          width: 100,
          targetTileWidth: 400,
          minColumns: 2,
        ),
        2,
      );
    });

    test('maxColumns caps a very wide window', () {
      expect(
        AdaptiveGrid.columnsFor(
          width: 3000,
          targetTileWidth: 180,
          maxColumns: 6,
        ),
        6,
      );
    });

    test('a zero width falls back instead of dividing by nothing', () {
      expect(AdaptiveGrid.columnsFor(width: 0, targetTileWidth: 180), 1);
    });
  });
}
