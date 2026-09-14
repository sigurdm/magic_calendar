import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/ephemeris_service.dart';

/// CustomPainter for rendering real-time moon phase graphics.
final class MoonPainter extends CustomPainter {
  /// Moon phase data used to render illumination.
  final MoonPhaseInfo info;

  /// Creates a [MoonPainter].
  const MoonPainter({required this.info});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final bgPaint = Paint()..color = const Color(0xFF1E1E2E);
    final lightPaint = Paint()..color = const Color(0xFFFFF9C4);

    canvas.drawCircle(center, radius, bgPaint);

    final k = info.illuminatedFraction;

    // Light the half that faces the sun: the right-hand half while waxing,
    // the left-hand half while waning.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      info.isWaxing ? -math.pi / 2 : math.pi / 2,
      math.pi,
      true,
      lightPaint,
    );

    // The terminator is an ellipse whose half-width collapses to zero at
    // quarter phase. Below half illumination it carves shadow out of the lit
    // half; above it, it adds light to the dark half.
    final isCrescent = k < 0.5;
    final ellipseWidth = (isCrescent ? 1 - 2 * k : 2 * k - 1) * radius;
    canvas.drawOval(
      Rect.fromLTRB(
        center.dx - ellipseWidth,
        center.dy - radius,
        center.dx + ellipseWidth,
        center.dy + radius,
      ),
      isCrescent ? bgPaint : lightPaint,
    );

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant MoonPainter oldDelegate) =>
      oldDelegate.info != info;
}
