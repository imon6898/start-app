import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';

/// Determinate progress bar with diagonal stripes. [percent] is 0-100.
class StripedProgressBar extends StatelessWidget {
  final double width;
  final double height;
  final double percent;
  final Color? stripeColor;
  final Color? fillColor;
  final Color? trackColor;

  const StripedProgressBar({
    super.key,
    required this.width,
    required this.height,
    required this.percent,
    this.stripeColor,
    this.fillColor,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: trackColor ?? CustomColors.lightGrey(),
                borderRadius: radius,
              ),
            ),
            FractionallySizedBox(
              widthFactor: (percent / 100).clamp(0.0, 1.0),
              child: ClipRRect(
                borderRadius: radius,
                child: CustomPaint(
                  size: Size(width, height),
                  painter: StripedProgressPainter(
                    stripColor: stripeColor ?? CustomColors.secondary(),
                    backgroundColor: fillColor ?? CustomColors.primary(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StripedProgressPainter extends CustomPainter {
  final Color stripColor;
  final Color backgroundColor;

  StripedProgressPainter({
    required this.stripColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = backgroundColor,
    );

    final stripPaint = Paint()..color = stripColor;
    const double stripeWidth = 4.0;
    const double stripeSpacing = 4.0;
    // Overshoot both ends so the -45° rotation still covers the corners.
    final diagonal = size.height * 2;

    for (
      double i = -diagonal;
      i < size.width + diagonal;
      i += (stripeWidth + stripeSpacing)
    ) {
      canvas.save();
      canvas.translate(i, 0);
      canvas.rotate(-math.pi / 4);
      canvas.drawRect(Rect.fromLTWH(0, 0, stripeWidth, diagonal), stripPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant StripedProgressPainter oldDelegate) =>
      oldDelegate.stripColor != stripColor ||
      oldDelegate.backgroundColor != backgroundColor;
}
