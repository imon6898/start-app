import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/observability_service.dart';
import '../../utils/constants/app_colors.dart';
import '../../utils/constants/app_fonts.dart';
import '../../utils/responsive_utils.dart';

/// Developer HUD over the app: frame health, startup timings, request and log
/// counters. Tap the pill to expand. Debug-only by default.
///
/// Strings here are deliberately not `.tr` — this is a developer tool, and
/// translating it would add keys to every locale for text no user ever sees.
class ObservabilityOverlay extends StatefulWidget {
  const ObservabilityOverlay({
    super.key,
    required this.child,
    this.enabled = defaultEnabled,
    this.alignment = Alignment.topRight,
  });

  /// On in debug and profile, off in release. Profile is where the numbers are
  /// real, so it stays on there.
  static const bool defaultEnabled = !kReleaseMode;

  final Widget child;
  final bool enabled;
  final Alignment alignment;

  /// Drop-in for `GetMaterialApp(builder: ObservabilityOverlay.builder())`.
  static TransitionBuilder builder({
    bool enabled = defaultEnabled,
    Alignment alignment = Alignment.topRight,
  }) {
    return (context, child) => ObservabilityOverlay(
      enabled: enabled,
      alignment: alignment,
      child: child ?? const SizedBox.shrink(),
    );
  }

  @override
  State<ObservabilityOverlay> createState() => _ObservabilityOverlayState();
}

class _ObservabilityOverlayState extends State<ObservabilityOverlay> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !Get.isRegistered<ObservabilityService>()) {
      return widget.child;
    }
    final service = Get.find<ObservabilityService>();

    return Stack(
      children: [
        widget.child,
        SafeArea(
          child: Align(
            alignment: widget.alignment,
            child: Padding(
              padding: R.pad(horizontal: 8, vertical: 8),
              child: Material(
                type: MaterialType.transparency,
                child: GestureDetector(
                  onTap: () {
                    service.publishNow();
                    setState(() => _expanded = !_expanded);
                  },
                  child: _expanded ? _panel(service) : _pill(service),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill(ObservabilityService service) {
    return Obx(
      () => Container(
        padding: R.pad(horizontal: 10, vertical: 6),
        decoration: _box(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.activity, size: R.w(12), color: _health(service)),
            SizedBox(width: R.w(6)),
            Text(
              'p95 ${service.p95FrameMs.value}ms  '
              'jank ${service.jankFrames.value}  '
              'err ${service.errorCount.value}',
              style: _text(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel(ObservabilityService service) {
    return Container(
      width: R.w(210),
      padding: R.pad(horizontal: 12, vertical: 10),
      decoration: _box(),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(LucideIcons.gauge, size: R.w(12), color: _health(service)),
                SizedBox(width: R.w(6)),
                Expanded(
                  child: Text('observability', style: _text(bold: true)),
                ),
                Icon(LucideIcons.x, size: R.w(12), color: CustomColors.white()),
              ],
            ),
            SizedBox(height: R.h(6)),
            _row('frames', '${service.framesObserved.value}'),
            _row(
              'jank',
              '${service.jankFrames.value} '
                  '(${service.jankPercent.toStringAsFixed(1)}%)',
            ),
            _row(
              'p50 / p95',
              '${service.p50FrameMs.value} / '
                  '${service.p95FrameMs.value} ms',
            ),
            _row('worst frame', '${service.worstFrameMs.value} ms'),
            _row('first frame', '${service.firstFrameMs.value} ms'),
            _row('interactive', '${service.timeToInteractiveMs.value} ms'),
            _row(
              'requests',
              '${service.requestCount.value} '
                  '(${service.failedRequestCount.value} fail, '
                  '${service.slowRequestCount.value} slow)',
            ),
            _row('last call', '${service.lastRequestMs.value} ms'),
            _row('trace', _shortTrace(service.lastTraceId.value)),
            _row(
              'logs',
              '${service.logCount.value} '
                  '(${service.warnCount.value} warn, '
                  '${service.errorCount.value} err)',
            ),
            if (service.droppedLogCount.value > 0)
              _row('dropped', '${service.droppedLogCount.value}'),
            if (service.spanMs.isNotEmpty)
              ...service.spanMs.entries.map(
                (e) => _row(e.key, '${e.value} ms'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: R.pad(vertical: 1),
      child: Row(
        children: [
          Expanded(child: Text(label, style: _text())),
          Text(value, style: _text(bold: true)),
        ],
      ),
    );
  }

  BoxDecoration _box() => BoxDecoration(
    color: CustomColors.black().withValues(alpha: 0.78),
    borderRadius: BorderRadius.circular(R.r(8)),
  );

  TextStyle _text({bool bold = false}) =>
      (bold ? CustomTextStyles.semiBold10 : CustomTextStyles.regular10)
          .copyWith(color: CustomColors.white());

  /// Green under a 2% jank rate, amber under 10%, red above.
  Color _health(ObservabilityService service) {
    final jank = service.jankPercent;
    if (service.errorCount.value > 0 || jank > 10) return CustomColors.error();
    if (jank > 2) return CustomColors.warning();
    return CustomColors.success();
  }

  String _shortTrace(String traceId) =>
      traceId.isEmpty ? '-' : traceId.substring(0, 8);
}
