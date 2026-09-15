import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_starter/app/services/connectivity_service.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';

/// What the bar is currently saying.
enum OfflineBannerMode { hidden, offline, restored }

/// Overlays an animated offline bar on top of [child].
class OfflineBanner extends StatefulWidget {
  final Widget child;

  /// Show the green "back online" bar after connectivity returns.
  final bool showRestored;

  /// How long the "back online" bar stays up.
  final Duration restoredDuration;

  /// Slide/fade duration.
  final Duration animationDuration;

  /// Tapping the offline bar re-checks connectivity.
  final bool tapToRetry;

  final String? offlineMessage;
  final String? restoredMessage;

  /// Defaults to `R.margin(horizontal: 12, top: 8)`.
  final EdgeInsets? margin;

  const OfflineBanner({
    super.key,
    required this.child,
    this.showRestored = true,
    this.restoredDuration = const Duration(seconds: 2),
    this.animationDuration = const Duration(milliseconds: 260),
    this.tapToRetry = true,
    this.offlineMessage,
    this.restoredMessage,
    this.margin,
  });

  /// Drop-in for `GetMaterialApp(builder: OfflineBanner.builder())`.
  static TransitionBuilder builder({
    bool showRestored = true,
    Duration restoredDuration = const Duration(seconds: 2),
    bool tapToRetry = true,
    String? offlineMessage,
    String? restoredMessage,
    EdgeInsets? margin,
  }) {
    return (context, child) => OfflineBanner(
      showRestored: showRestored,
      restoredDuration: restoredDuration,
      tapToRetry: tapToRetry,
      offlineMessage: offlineMessage,
      restoredMessage: restoredMessage,
      margin: margin,
      child: child ?? const SizedBox.shrink(),
    );
  }

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late final ConnectivityService _service;
  Worker? _worker;
  Timer? _restoredTimer;
  OfflineBannerMode _mode = OfflineBannerMode.hidden;

  @override
  void initState() {
    super.initState();
    // Register on demand so the banner still works without bootstrap wiring.
    _service = Get.isRegistered<ConnectivityService>()
        ? ConnectivityService.to
        : Get.put(ConnectivityService(), permanent: true);
    _mode = _service.isOnline.value
        ? OfflineBannerMode.hidden
        : OfflineBannerMode.offline;
    _worker = ever<bool>(_service.isOnline, _onStatusChanged);
  }

  @override
  void dispose() {
    _restoredTimer?.cancel();
    _worker?.dispose();
    super.dispose();
  }

  void _onStatusChanged(bool online) {
    _restoredTimer?.cancel();
    if (!online) {
      _setMode(OfflineBannerMode.offline);
      return;
    }
    // Only confirm a recovery we actually announced.
    if (!widget.showRestored || _mode != OfflineBannerMode.offline) {
      _setMode(OfflineBannerMode.hidden);
      return;
    }
    _setMode(OfflineBannerMode.restored);
    _restoredTimer = Timer(
      widget.restoredDuration,
      () => _setMode(OfflineBannerMode.hidden),
    );
  }

  void _setMode(OfflineBannerMode mode) {
    if (!mounted || _mode == mode) return;
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(bottom: false, child: _buildAnimatedBar(context)),
        ),
      ],
    );
  }

  Widget _buildAnimatedBar(BuildContext context) {
    final visible = _mode != OfflineBannerMode.hidden;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -1.6),
        duration: widget.animationDuration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: widget.animationDuration,
          child: _buildBar(context),
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    final restored = _mode == OfflineBannerMode.restored;
    final label = restored
        ? (widget.restoredMessage ?? 'Back online').tr
        : (widget.offlineMessage ?? 'No internet connection').tr;

    return Material(
      color: CustomColors.transparent(),
      child: GestureDetector(
        onTap: widget.tapToRetry && !restored
            ? () => unawaited(_service.refreshStatus())
            : null,
        child: Container(
          width: double.infinity,
          margin: widget.margin ?? R.margin(horizontal: 12, top: 8),
          padding: R.pad(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: restored ? CustomColors.success() : CustomColors.error(),
            borderRadius: BorderRadius.circular(R.r(12)),
            boxShadow: [
              BoxShadow(
                color: CustomColors.appBarShadow().withValues(alpha: 0.25),
                blurRadius: R.r(12),
                offset: Offset(0, R.h(4)),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                restored ? LucideIcons.wifi : LucideIcons.wifiOff,
                size: R.sp(18),
                color: CustomColors.textInverse(),
              ),
              SizedBox(width: R.w(10)),
              Flexible(
                child: Text(
                  label,
                  style: CustomTextStyles.medium14.copyWith(
                    color: CustomColors.textInverse(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
