/// One navigation API, three renderings: bottom bar, rail, persistent drawer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:get/get.dart';

import 'adaptive_breakpoints.dart';

/// How the destinations are being shown right now.
enum AdaptiveNavigationStyle { bottomBar, rail, drawer }

/// One navigation target. [label] is a translation key — every renderer runs
/// `.tr` on it, so pass the key, not the translated string.
@immutable
class AdaptiveDestination {
  const AdaptiveDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.tooltip,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final String? tooltip;
}

/// Exposes how much horizontal chrome sits to the left of the body, so a
/// descendant can map view coordinates (a hinge rect) into its own.
class AdaptiveScaffoldScope extends InheritedWidget {
  const AdaptiveScaffoldScope({
    super.key,
    required this.navigationInset,
    required this.style,
    required super.child,
  });

  final double navigationInset;
  final AdaptiveNavigationStyle style;

  static AdaptiveScaffoldScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdaptiveScaffoldScope>();

  static double navigationInsetOf(BuildContext context) =>
      maybeOf(context)?.navigationInset ?? 0;

  @override
  bool updateShouldNotify(AdaptiveScaffoldScope oldWidget) =>
      navigationInset != oldWidget.navigationInset || style != oldWidget.style;
}

/// A [Scaffold] that moves its navigation as the window grows.
///
/// compact -> `NavigationBar` at the bottom · medium -> `NavigationRail` ·
/// expanded -> a `NavigationDrawer` pinned open beside the body.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.leading,
    this.trailing,
    this.drawer,
    this.endDrawer,
    this.bottomSheet,
    this.useDrawerOnExpanded = true,
    this.labelBehavior,
    this.railWidth,
    this.drawerWidth,
    this.scaffoldKey,
    this.resizeToAvoidBottomInset = true,
  }) : assert(destinations.length >= 2, 'A nav bar needs 2+ destinations');

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;

  /// Above the destinations in the rail and the drawer (logo, a FAB, a search
  /// field). Not shown on compact, where there is nowhere sensible to put it.
  final Widget? leading;
  final Widget? trailing;

  /// Passed straight through, for a modal drawer of secondary items.
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomSheet;

  /// False keeps the rail on expanded instead of pinning a drawer open.
  final bool useDrawerOnExpanded;

  /// Defaults to hiding bottom-bar labels once text scaling makes them clip.
  final NavigationDestinationLabelBehavior? labelBehavior;

  /// Logical pixels, not Figma pixels — these are Material component metrics.
  final double? railWidth;
  final double? drawerWidth;

  final GlobalKey<ScaffoldState>? scaffoldKey;
  final bool resizeToAvoidBottomInset;

  /// Pure decision function, so the rules are testable without a widget tree.
  static AdaptiveNavigationStyle resolveStyle({
    required WindowSizeClass widthClass,
    required WindowSizeClass heightClass,
    bool useDrawerOnExpanded = true,
  }) {
    if (widthClass.isExpanded) {
      return useDrawerOnExpanded
          ? AdaptiveNavigationStyle.drawer
          : AdaptiveNavigationStyle.rail;
    }
    if (widthClass.isMedium) return AdaptiveNavigationStyle.rail;
    // Landscape phone: a bottom bar eats the little height that is left.
    return heightClass.isCompact
        ? AdaptiveNavigationStyle.rail
        : AdaptiveNavigationStyle.bottomBar;
  }

  int get _safeIndex => selectedIndex.clamp(0, destinations.length - 1);

  @override
  Widget build(BuildContext context) {
    final WindowInfo info = WindowInfo.of(context);
    final AdaptiveNavigationStyle style = resolveStyle(
      widthClass: info.widthClass,
      heightClass: info.heightClass,
      useDrawerOnExpanded: useDrawerOnExpanded,
    );

    switch (style) {
      case AdaptiveNavigationStyle.bottomBar:
        return _scaffold(
          style: style,
          inset: 0,
          body: body,
          bottomNavigationBar: _bottomBar(info),
        );

      case AdaptiveNavigationStyle.rail:
        final double width = railWidth ?? R.w(72).clamp(72.0, 112.0);
        final double divider = R.w(1);
        return _scaffold(
          style: style,
          inset: width + divider,
          body: Row(
            children: <Widget>[
              _rail(info, width),
              VerticalDivider(
                width: divider,
                thickness: divider,
                color: CustomColors.stroke(),
              ),
              Expanded(child: body),
            ],
          ),
        );

      case AdaptiveNavigationStyle.drawer:
        final double width = drawerWidth ?? R.w(280).clamp(280.0, 360.0);
        final double divider = R.w(1);
        return _scaffold(
          style: style,
          inset: width + divider,
          body: Row(
            children: <Widget>[
              _drawer(width),
              VerticalDivider(
                width: divider,
                thickness: divider,
                color: CustomColors.stroke(),
              ),
              Expanded(child: body),
            ],
          ),
        );
    }
  }

  Widget _scaffold({
    required AdaptiveNavigationStyle style,
    required double inset,
    required Widget body,
    Widget? bottomNavigationBar,
  }) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: backgroundColor ?? CustomColors.artboardColor(),
      appBar: appBar,
      drawer: drawer,
      endDrawer: endDrawer,
      bottomSheet: bottomSheet,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      bottomNavigationBar: bottomNavigationBar,
      body: AdaptiveScaffoldScope(
        navigationInset: inset,
        style: style,
        child: body,
      ),
    );
  }

  Widget _bottomBar(WindowInfo info) {
    // Hiding labels is what keeps a 200% text scale from clipping the bar.
    final NavigationDestinationLabelBehavior behavior =
        labelBehavior ??
        (info.isLargeText
            ? NavigationDestinationLabelBehavior.alwaysHide
            : NavigationDestinationLabelBehavior.alwaysShow);

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          return CustomTextStyles.medium12.copyWith(
            color: selected ? CustomColors.primary() : CustomColors.textGray(),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: R.sp(22),
            color: selected ? CustomColors.primary() : CustomColors.textGray(),
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: _safeIndex,
        onDestinationSelected: onDestinationSelected,
        backgroundColor: CustomColors.navbar(),
        indicatorColor: CustomColors.navbarSelected(),
        labelBehavior: behavior,
        destinations: destinations
            .map(
              (AdaptiveDestination d) => NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon ?? d.icon),
                label: d.label.tr,
                tooltip: (d.tooltip ?? d.label).tr,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _rail(WindowInfo info, double width) {
    // Extended only when the caller declined the drawer on expanded.
    final bool extended = info.widthClass.isExpanded;
    return NavigationRail(
      extended: extended,
      minWidth: width,
      minExtendedWidth: R.w(256).clamp(256.0, 320.0),
      // Long labels and big text overflow a fixed rail; let it scroll.
      scrollable: true,
      backgroundColor: CustomColors.navbar(),
      indicatorColor: CustomColors.navbarSelected(),
      selectedIndex: _safeIndex,
      onDestinationSelected: onDestinationSelected,
      leading: leading,
      trailing: trailing,
      labelType: extended
          ? null
          : (info.isLargeText
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all),
      selectedIconTheme: IconThemeData(
        size: R.sp(22),
        color: CustomColors.primary(),
      ),
      unselectedIconTheme: IconThemeData(
        size: R.sp(22),
        color: CustomColors.textGray(),
      ),
      selectedLabelTextStyle: CustomTextStyles.medium12.copyWith(
        color: CustomColors.primary(),
      ),
      unselectedLabelTextStyle: CustomTextStyles.medium12.copyWith(
        color: CustomColors.textGray(),
      ),
      destinations: destinations
          .map(
            (AdaptiveDestination d) => NavigationRailDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon ?? d.icon),
              label: Text(d.label.tr),
            ),
          )
          .toList(),
    );
  }

  Widget _drawer(double width) {
    // Drawer sizes itself from DrawerTheme, so a SizedBox around it is ignored.
    return DrawerTheme(
      data: DrawerThemeData(
        width: width,
        backgroundColor: CustomColors.navbar(),
        elevation: 0,
        shape: const RoundedRectangleBorder(),
      ),
      child: NavigationDrawerTheme(
        data: NavigationDrawerThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((
            Set<WidgetState> states,
          ) {
            final bool selected = states.contains(WidgetState.selected);
            return CustomTextStyles.medium14.copyWith(
              color: selected
                  ? CustomColors.primary()
                  : CustomColors.textPrimary(),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
            final bool selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: R.sp(22),
              color: selected
                  ? CustomColors.primary()
                  : CustomColors.textGray(),
            );
          }),
        ),
        child: NavigationDrawer(
          selectedIndex: _safeIndex,
          onDestinationSelected: onDestinationSelected,
          indicatorColor: CustomColors.navbarSelected(),
          children: <Widget>[
            if (leading != null)
              Padding(
                padding: R.pad(horizontal: 16, vertical: 12),
                child: leading,
              ),
            ...destinations.map(
              (AdaptiveDestination d) => NavigationDrawerDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon ?? d.icon),
                label: Text(d.label.tr),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: R.pad(horizontal: 16, vertical: 12),
                child: trailing,
              ),
          ],
        ),
      ),
    );
  }
}
