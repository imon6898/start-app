import 'package:flutter/material.dart';

import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/feedback/status_badge.dart';
import 'package:flutter_starter/app/widgets/feedback/striped_progress_bar.dart';
import 'package:flutter_starter/app/widgets/feedback/thinking_dots.dart';

import 'golden_harness.dart';

void main() {
  // One image covering every tone catches a palette regression in one diff.
  goldenMatrixTest(
    'status_badge_tones',
    () => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tone in StatusTone.values)
          Padding(
            padding: R.pad(bottom: 8),
            child: StatusBadge(label: tone.name.toUpperCase(), tone: tone),
          ),
      ],
    ),
  );

  goldenMatrixTest(
    'status_badge_from_status',
    () => Wrap(
      spacing: R.w(8),
      runSpacing: R.h(8),
      alignment: WrapAlignment.center,
      children: [
        StatusBadge.fromStatus('delivered'),
        StatusBadge.fromStatus('in_transit'),
        StatusBadge.fromStatus('pending'),
        StatusBadge.fromStatus('cancelled'),
      ],
    ),
    matrix: kPhoneOnlyMatrix,
  );

  // percent is 0-100, not a 0-1 fraction.
  goldenMatrixTest(
    'striped_progress_bar',
    () => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final percent in const [0.0, 35.0, 100.0])
          Padding(
            padding: R.pad(bottom: 12),
            child: StripedProgressBar(
              width: R.w(240),
              height: R.h(14),
              percent: percent,
            ),
          ),
      ],
    ),
    matrix: kPhoneOnlyMatrix,
  );

  // ThinkingDots animates with repeat(), so pumpAndSettle would never return.
  goldenMatrixTest(
    'thinking_dots',
    () => const ThinkingDots(title: 'Loading'),
    matrix: kPhoneOnlyMatrix,
    settle: false,
  );
}
