/// Grid sized by how wide a tile should be, not by a hardcoded column count.
library;

import 'package:flutter/material.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';

import 'adaptive_breakpoints.dart';

class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.targetTileWidth = 180,
    this.spacing = 12,
    this.runSpacing,
    this.tileHeight,
    this.aspectRatio,
    this.minColumns = 1,
    this.maxColumns,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.controller,
    this.scaleWithText = true,
  }) : assert(minColumns >= 1, 'minColumns must be at least 1');

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Raw Figma pixels. Column count is whatever gets tiles closest to this.
  final double targetTileWidth;

  /// Raw Figma pixels between columns; [runSpacing] defaults to it for rows.
  final double spacing;
  final double? runSpacing;

  /// Raw Figma pixels. Prefer this over [aspectRatio] — a fixed ratio plus a
  /// large text scale is the classic grid overflow.
  final double? tileHeight;
  final double? aspectRatio;

  final int minColumns;
  final int? maxColumns;

  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  /// Widens the target tile (so, fewer columns) as the user's font scale grows.
  final bool scaleWithText;

  /// Pure, so the column maths is testable. Rounds rather than floors: with a
  /// 180px target, a 380px window gives 2 columns of 184, not 1 of 380.
  static int columnsFor({
    required double width,
    required double targetTileWidth,
    double spacing = 0,
    int minColumns = 1,
    int? maxColumns,
  }) {
    if (width <= 0 || targetTileWidth <= 0) return minColumns;
    final int raw = ((width + spacing) / (targetTileWidth + spacing)).round();
    final int upper = maxColumns ?? 1 << 20;
    return raw.clamp(minColumns < 1 ? 1 : minColumns, upper);
  }

  @override
  Widget build(BuildContext context) {
    final WindowInfo info = WindowInfo.of(context);
    final double textBump = scaleWithText
        ? info.textScale.clamp(1.0, 1.6)
        : 1.0;
    final double crossSpacing = R.w(spacing);
    final double mainSpacing = R.h(runSpacing ?? spacing);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : info.size.width;
        final EdgeInsets resolved = (padding ?? EdgeInsets.zero).resolve(
          Directionality.of(context),
        );
        final double usable = width - resolved.horizontal;

        final int columns = columnsFor(
          width: usable,
          targetTileWidth: R.w(targetTileWidth) * textBump,
          spacing: crossSpacing,
          minColumns: minColumns,
          maxColumns: maxColumns,
        );

        return GridView.builder(
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics,
          controller: controller,
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: crossSpacing,
            mainAxisSpacing: mainSpacing,
            childAspectRatio: aspectRatio ?? 1.0,
            mainAxisExtent: tileHeight == null
                ? null
                : R.h(tileHeight!) * textBump,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
