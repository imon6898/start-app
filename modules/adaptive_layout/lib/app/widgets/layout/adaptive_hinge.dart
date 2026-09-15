/// Foldable support: read the hinge out of MediaQuery and split around it.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';

/// A fold or hinge that cuts the window in two. [bounds] is in view
/// coordinates, the same space MediaQuery reports it in.
@immutable
class HingeInfo {
  const HingeInfo({
    required this.bounds,
    required this.axis,
    required this.type,
    required this.state,
  });

  final Rect bounds;

  /// The direction the hinge runs. [Axis.vertical] means two panes side by side.
  final Axis axis;
  final ui.DisplayFeatureType type;
  final ui.DisplayFeatureState state;

  double get thickness => axis == Axis.vertical ? bounds.width : bounds.height;

  /// A hinge has a physical gap; a fold is a crease with zero thickness.
  bool get isObstructing => thickness > 0;

  bool get splitsSideBySide => axis == Axis.vertical;

  /// Laptop / book posture — the two halves are at an angle to each other.
  bool get isHalfOpened => state == ui.DisplayFeatureState.postureHalfOpened;

  /// First fold or hinge that spans the whole window. Cutouts are ignored:
  /// they punch a hole, they do not divide the layout.
  static HingeInfo? fromFeatures(
    List<ui.DisplayFeature> features,
    Size windowSize,
  ) {
    for (final ui.DisplayFeature feature in features) {
      if (feature.type != ui.DisplayFeatureType.hinge &&
          feature.type != ui.DisplayFeatureType.fold) {
        continue;
      }
      final Rect b = feature.bounds;
      final Axis axis = b.width < b.height ? Axis.vertical : Axis.horizontal;
      // A feature that stops short of both edges is a notch, not a divider.
      final bool spans = axis == Axis.vertical
          ? b.height >= windowSize.height - 1
          : b.width >= windowSize.width - 1;
      if (!spans) continue;
      return HingeInfo(
        bounds: b,
        axis: axis,
        type: feature.type,
        state: feature.state,
      );
    }
    return null;
  }

  static HingeInfo? of(BuildContext context) => fromFeatures(
    MediaQuery.displayFeaturesOf(context),
    MediaQuery.sizeOf(context),
  );
}

/// Smallest share of the box a hinge-aligned pane may get before the hinge is
/// ignored. Guards the case where chrome pushes the seam near an edge.
const double _minHingePaneFraction = 0.2;

/// Two panes side by side, aligned to the hinge when the device has one.
///
/// On a foldable the seam lands exactly on the hinge, so no content is laid
/// across it. Everywhere else it falls back to [startFraction].
class HingeAwareSplit extends StatelessWidget {
  const HingeAwareSplit({
    super.key,
    required this.start,
    required this.end,
    this.startFraction = 0.5,
    this.startMin,
    this.startMax,
    this.gap = 0,
    this.separator,
    this.viewOffset = 0,
  });

  final Widget start;
  final Widget end;

  /// Share of the width given to [start] when there is no hinge.
  final double startFraction;

  /// Logical-pixel clamps on the fallback width. A hinge overrides both — you
  /// cannot negotiate with hardware.
  final double? startMin;
  final double? startMax;

  /// Raw Figma pixels; scaled with `R.w` internally.
  final double gap;

  /// Drawn in the gap only when the gap is ours, never over a hinge.
  final Widget? separator;

  /// Distance from the left edge of the view to this widget, so the hinge rect
  /// can be mapped into local coordinates. A rail or drawer to the left of the
  /// body is exactly this offset.
  final double viewOffset;

  @override
  Widget build(BuildContext context) {
    final HingeInfo? hinge = HingeInfo.of(context);
    final double fallbackGap = gap == 0 ? 0 : R.w(gap);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedWidth) {
          return _flexRow(fallbackGap);
        }
        final double total = constraints.maxWidth;

        double startWidth = 0;
        double gapWidth = 0;
        bool fromHinge = false;

        if (hinge != null && hinge.splitsSideBySide) {
          final double left = hinge.bounds.left - viewOffset;
          final double right = hinge.bounds.right - viewOffset;
          // Honour the hinge only when it falls inside this box and leaves both
          // panes usable — a 60px sliver is worse than ignoring the hardware.
          final double minPane = total * _minHingePaneFraction;
          if (left >= minPane && right <= total - minPane) {
            startWidth = left;
            gapWidth = right - left;
            fromHinge = true;
          }
        }

        if (!fromHinge) {
          gapWidth = fallbackGap > total ? total : fallbackGap;
          startWidth = (total - gapWidth) * startFraction;
          if (startMin != null) {
            startWidth = startWidth < startMin! ? startMin! : startWidth;
          }
          if (startMax != null) {
            startWidth = startWidth > startMax! ? startMax! : startWidth;
          }
          startWidth = startWidth.clamp(0.0, total - gapWidth);
        }

        // A zero-thickness fold still deserves a visible seam; a real hinge gap
        // never gets one, because that strip of screen is physically hidden.
        Widget? gapChild;
        if (separator != null && (!fromHinge || gapWidth <= 0)) {
          gapChild = separator;
          if (gapWidth <= 0) gapWidth = R.w(1);
        }

        return Row(
          children: <Widget>[
            SizedBox(width: startWidth, child: start),
            SizedBox(width: gapWidth, child: gapChild),
            Expanded(child: end),
          ],
        );
      },
    );
  }

  // Unbounded width (inside a Row or a scroll view): fall back to flex.
  Widget _flexRow(double gapWidth) {
    final int startFlex = (startFraction * 100).round().clamp(1, 99);
    return Row(
      children: <Widget>[
        Expanded(flex: startFlex, child: start),
        SizedBox(width: gapWidth, child: separator),
        Expanded(flex: 100 - startFlex, child: end),
      ],
    );
  }
}
