import 'package:flutter/material.dart';

class CustomStatusBar extends StatelessWidget {
  final double width;
  final double height;
  final double percent;

  const CustomStatusBar({
    super.key,
    required this.width,
    required this.height,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            // Background (gray part)
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),

            // Progress (striped part)
            FractionallySizedBox(
              widthFactor: percent / 100,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(height / 2),
                child: CustomPaint(
                  size: Size(width, height),
                  painter: StripedProgressPainter(
                    stripColor: const Color(0xFF00695C), // Dark teal
                    backgroundColor: const Color(0xFF00897B), // Light teal
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
    // Draw the background color first
    final backgroundPaint = Paint()..color = backgroundColor;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    // Draw the stripes
    final stripPaint = Paint()..color = stripColor;
    const double stripeWidth = 4.0; // Width of each stripe
    const double stripeSpacing = 4.0; // Spacing between stripes

    // Calculate the diagonal length to ensure full coverage
    final diagonal = size.height * 2;

    for (
      double i = -diagonal;
      i < size.width + diagonal;
      i += (stripeWidth + stripeSpacing)
    ) {
      canvas.save();
      canvas.translate(i, 0);
      canvas.rotate(-0.785398); // Rotate by -45 degrees (approx. -pi/4)

      canvas.drawRect(Rect.fromLTWH(0, 0, stripeWidth, diagonal), stripPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
