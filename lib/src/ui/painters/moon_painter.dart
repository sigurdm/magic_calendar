import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../../services/ephemeris_service.dart';

/// CustomPainter for rendering real-time moon phase graphics.
final class MoonPainter extends CustomPainter {
  /// Moon phase data used to render illumination.
  final MoonPhaseInfo info;

  /// Creates a [MoonPainter].
  MoonPainter({required this.info});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final bgPaint = Paint()..color = const Color(0xFF1E1E2E);
    final lightPaint = Paint()..color = const Color(0xFFFFF9C4);

    canvas.drawCircle(center, radius, bgPaint);

    double k = info.illuminatedFraction;

    if (info.isWaxing) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi,
        true,
        lightPaint,
      );
      if (k < 0.5) {
        double ellipseWidth = (1 - 2 * k) * radius;
        canvas.drawOval(
          Rect.fromLTRB(
            center.dx - ellipseWidth,
            center.dy - radius,
            center.dx + ellipseWidth,
            center.dy + radius,
          ),
          bgPaint,
        );
      } else {
        double ellipseWidth = (2 * k - 1) * radius;
        canvas.drawOval(
          Rect.fromLTRB(
            center.dx - ellipseWidth,
            center.dy - radius,
            center.dx + ellipseWidth,
            center.dy + radius,
          ),
          lightPaint,
        );
      }
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi / 2,
        math.pi,
        true,
        lightPaint,
      );
      if (k < 0.5) {
        double ellipseWidth = (1 - 2 * k) * radius;
        canvas.drawOval(
          Rect.fromLTRB(
            center.dx - ellipseWidth,
            center.dy - radius,
            center.dx + ellipseWidth,
            center.dy + radius,
          ),
          bgPaint,
        );
      } else {
        double ellipseWidth = (2 * k - 1) * radius;
        canvas.drawOval(
          Rect.fromLTRB(
            center.dx - ellipseWidth,
            center.dy - radius,
            center.dx + ellipseWidth,
            center.dy + radius,
          ),
          lightPaint,
        );
      }
    }

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
