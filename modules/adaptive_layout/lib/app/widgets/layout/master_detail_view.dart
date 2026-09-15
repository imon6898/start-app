/// List + detail that stacks on a phone and sits side by side on a tablet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'adaptive_breakpoints.dart';
import 'adaptive_hinge.dart';
import 'adaptive_scaffold.dart';

/// Tells descendants whether the detail is its own page right now.
class MasterDetailScope extends InheritedWidget {
  const MasterDetailScope({
    super.key,
    required this.isDetailStacked,
    required this.closeDetail,
    required super.child,
  });

  /// True on compact, where the detail is pushed over the list.
  final bool isDetailStacked;

  /// Clears the selection; a no-op worth calling either way.
  final VoidCallback closeDetail;

  static MasterDetailScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MasterDetailScope>();

  @override
  bool updateShouldNotify(MasterDetailScope oldWidget) =>
      isDetailStacked != oldWidget.isDetailStacked;
}

/// Back button that disappears when the detail is already beside the list.
class AdaptiveDetailBackButton extends StatelessWidget {
  const AdaptiveDetailBackButton({super.key, this.icon, this.color});

  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final MasterDetailScope? scope = MasterDetailScope.maybeOf(context);
    if (scope == null || !scope.isDetailStacked) return const SizedBox.shrink();
    return IconButton(
      onPressed: scope.closeDetail,
      icon: Icon(
        icon ?? LucideIcons.arrowLeft,
        size: R.sp(22),
        color: color ?? CustomColors.textPrimary(),
      ),
    );
  }
}

/// Two-pane list/detail layout.
///
/// Compact stacks the detail on a nested [Navigator], so the system back
/// gesture and the Android back button pop it. Expanded (or any foldable with a
/// separating hinge) shows both panes, seamed on the hinge.
class MasterDetailView<T extends Object> extends StatefulWidget {
  const MasterDetailView({
    super.key,
    required this.masterBuilder,
    required this.detailBuilder,
    this.placeholderBuilder,
    this.initialSelection,
    this.onSelectionChanged,
    this.masterFraction = 0.38,
    this.masterMinWidth,
    this.masterMaxWidth,
    this.minPaneWidth = 320,
    this.gap = 0,
    this.showSeparator = true,
  });

  /// `onSelect` opens the item; `selected` is there so the list can highlight
  /// the row that the detail pane is showing.
  final Widget Function(
    BuildContext context,
    ValueChanged<T> onSelect,
    T? selected,
  )
  masterBuilder;

  /// `onClose` is null while the detail sits beside the list — there is nothing
  /// to go back to.
  final Widget Function(BuildContext context, T item, VoidCallback? onClose)
  detailBuilder;

  /// Shown in the detail pane when nothing is selected. Side by side only.
  final WidgetBuilder? placeholderBuilder;

  final T? initialSelection;
  final ValueChanged<T?>? onSelectionChanged;

  /// Share of the width given to the list when there is no hinge to follow.
  final double masterFraction;

  /// Logical-pixel clamps for the list pane.
  final double? masterMinWidth;
  final double? masterMaxWidth;

  /// Below two of these, splitting is worse than stacking. Grows with the
  /// user's text scale, which is what makes 200% font size survivable.
  final double minPaneWidth;

  /// Raw Figma pixels between the panes.
  final double gap;
  final bool showSeparator;

  /// Pure decision function — the whole rule, testable without a widget tree.
  static bool shouldSplit({
    required double availableWidth,
    required WindowSizeClass widthClass,
    bool hasSeparatingHinge = false,
    double textScale = 1.0,
    double minPaneWidth = 320,
  }) {
    // Two physical screens: side by side is the only sane answer.
    if (hasSeparatingHinge && !widthClass.isCompact) return true;
    if (!widthClass.isExpanded) return false;
    final double needed = minPaneWidth * 2 * textScale.clamp(1.0, 1.5);
    return availableWidth >= needed;
  }

  @override
  State<MasterDetailView<T>> createState() => _MasterDetailViewState<T>();
}

class _MasterDetailViewState<T extends Object>
    extends State<MasterDetailView<T>> {
  static const ValueKey<String> _masterPageKey = ValueKey<String>('master');

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  T? _selected;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
  }

  void _select(T item) {
    if (_selected == item) return;
    setState(() {
      _selected = item;
      _serial++;
    });
    widget.onSelectionChanged?.call(item);
  }

  void _clear() {
    if (_selected == null) return;
    setState(() => _selected = null);
    widget.onSelectionChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final WindowInfo info = WindowInfo.of(context);
    final HingeInfo? hinge = HingeInfo.of(context);
    final double inset = AdaptiveScaffoldScope.navigationInsetOf(context);

    final bool split = MasterDetailView.shouldSplit(
      availableWidth: info.size.width - inset,
      widthClass: info.widthClass,
      hasSeparatingHinge: hinge?.splitsSideBySide ?? false,
      textScale: info.textScale,
      minPaneWidth: widget.minPaneWidth,
    );

    return split ? _buildSplit(context, inset) : _buildStacked(context);
  }

  Widget _buildSplit(BuildContext context, double inset) {
    final T? selected = _selected;
    return MasterDetailScope(
      isDetailStacked: false,
      closeDetail: _clear,
      child: HingeAwareSplit(
        viewOffset: inset,
        startFraction: widget.masterFraction,
        startMin: widget.masterMinWidth,
        startMax: widget.masterMaxWidth,
        gap: widget.gap,
        separator: widget.showSeparator
            ? ColoredBox(color: CustomColors.stroke())
            : null,
        start: widget.masterBuilder(context, _select, selected),
        end: selected == null
            ? (widget.placeholderBuilder?.call(context) ??
                  const SizedBox.shrink())
            : widget.detailBuilder(context, selected, null),
      ),
    );
  }

  Widget _buildStacked(BuildContext context) {
    final T? selected = _selected;
    return MasterDetailScope(
      isDetailStacked: selected != null,
      closeDetail: _clear,
      // Routes the system back gesture into the nested Navigator instead of
      // letting the root one pop the whole screen.
      child: NavigatorPopHandler<Object?>(
        onPopWithResult: (Object? _) => _navigatorKey.currentState?.maybePop(),
        child: Navigator(
          key: _navigatorKey,
          pages: <Page<Object?>>[
            MaterialPage<Object?>(
              key: _masterPageKey,
              child: widget.masterBuilder(context, _select, selected),
            ),
            if (selected != null)
              MaterialPage<Object?>(
                key: ValueKey<String>('detail-$_serial'),
                child: widget.detailBuilder(context, selected, _clear),
              ),
          ],
          onDidRemovePage: (Page<Object?> page) {
            if (page.key != _masterPageKey) _clear();
          },
        ),
      ),
    );
  }
}
