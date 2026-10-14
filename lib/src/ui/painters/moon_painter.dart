import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/ephemeris_service.dart';

/// CustomPainter for rendering real-time moon phase graphics.
///
/// Supports both the classic flat geometric mode and an organic Goethean
/// watercolor mode featuring warm earthshine on the shadowed limb, a feathered
/// terminator, translucent lunar maria washes, and an atmospheric corona glow.
final class MoonPainter extends CustomPainter {
  /// Moon phase data used to render illumination.
  final MoonPhaseInfo info;

  /// Whether to render with hand-painted watercolor washes, earthshine, and corona.
  final bool organicWatercolor;

  /// Creates a [MoonPainter].
  const MoonPainter({required this.info, this.organicWatercolor = true});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    if (!organicWatercolor) {
      _paintClassic(canvas, center, radius);
      return;
    }

    _paintOrganicWatercolor(canvas, center, radius);
  }

  void _paintClassic(Canvas canvas, Offset center, double radius) {
    final bgPaint = Paint()..color = const Color(0xFF1E1E2E);
    final lightPaint = Paint()..color = const Color(0xFFFFF9C4);

    canvas.drawCircle(center, radius, bgPaint);

    final k = info.illuminatedFraction;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      info.isWaxing ? -math.pi / 2 : math.pi / 2,
      math.pi,
      true,
      lightPaint,
    );

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

  void _paintOrganicWatercolor(Canvas canvas, Offset center, double radius) {
    final discRect = Rect.fromCircle(center: center, radius: radius);

    // 1. Soft atmospheric lunar corona (warm golden-pearl halo)
    canvas.drawCircle(
      center,
      radius * 1.16,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius * 1.32,
          [
            const Color(0xFFF6E3A8).withValues(alpha: 0.36),
            const Color(0xFFD9B26F).withValues(alpha: 0.14),
            Colors.transparent,
          ],
          const [0.0, 0.65, 1.0],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.22),
    );

    // 2. Shadowed limb with warm copper-violet Earthshine
    final earthshineCenter = Offset(
      center.dx + (info.isWaxing ? -radius * 0.35 : radius * 0.35),
      center.dy - radius * 0.18,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          earthshineCenter,
          radius * 1.4,
          [
            const Color(0xFF3A313D), // Warm twilight earthshine
            const Color(0xFF241E26), // Deep humus umber-indigo
            const Color(0xFF171319),
          ],
          const [0.0, 0.65, 1.0],
        ),
    );

    // Subtle maria blotches visible even in earthshine
    canvas.save();
    canvas.clipPath(Path()..addOval(discRect));
    _paintLunarMaria(
      canvas,
      center,
      radius,
      const Color(0xFF120E14).withValues(alpha: 0.32),
    );

    // 3. Illuminated limb path (analytic crescent/gibbous manifold)
    final k = info.illuminatedFraction.clamp(0.0, 1.0);
    final isCrescent = k < 0.5;
    final ellipseWidth = (isCrescent ? 1.0 - 2.0 * k : 2.0 * k - 1.0) * radius;

    final semiCirclePath = Path()
      ..addArc(discRect, info.isWaxing ? -math.pi / 2 : math.pi / 2, math.pi)
      ..close();
    final terminatorOval = Path()
      ..addOval(
        Rect.fromLTRB(
          center.dx - ellipseWidth,
          center.dy - radius,
          center.dx + ellipseWidth,
          center.dy + radius,
        ),
      );

    final litPath = isCrescent
        ? Path.combine(PathOperation.difference, semiCirclePath, terminatorOval)
        : Path.combine(PathOperation.union, semiCirclePath, terminatorOval);

    // Soft feathered watercolor bleed across the terminator into the dark limb
    canvas.drawPath(
      litPath,
      Paint()
        ..color = const Color(0xFFE5B96B).withValues(alpha: 0.48)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.14),
    );

    // Main multi-stop watercolor pigment wash on the illuminated limb
    final sunFocal = Offset(
      center.dx + (info.isWaxing ? radius * 0.38 : -radius * 0.38),
      center.dy - radius * 0.22,
    );
    canvas.save();
    canvas.clipPath(litPath);
    canvas.drawRect(
      discRect,
      Paint()
        ..shader = ui.Gradient.radial(
          sunFocal,
          radius * 1.45,
          [
            const Color(0xFFFFFDF5), // Luminous paper reserve highlight
            const Color(0xFFF9E8B2), // Warm beeswax yellow lazure
            const Color(0xFFE6C278), // Golden ochre middle wash
            const Color(0xFFC4944A), // Granulating sienna limb darkening
          ],
          const [0.0, 0.38, 0.76, 1.0],
        ),
    );

    // Hand-painted watercolor lunar maria (Mare Imbrium, Serenitatis, Tranquillitatis)
    _paintLunarMaria(
      canvas,
      center,
      radius,
      const Color(0xFF9C7B4C).withValues(alpha: 0.24),
    );
    _paintLunarMaria(
      canvas,
      Offset(center.dx + radius * 0.06, center.dy - radius * 0.04),
      radius * 0.88,
      const Color(0xFF7A6348).withValues(alpha: 0.16),
    );
    canvas.restore();
    canvas.restore();

    // 4. Hand-brushed golden rim highlight on the sunlit edge & subtle earthshine rim
    final rimAlign = info.isWaxing
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final oppAlign = info.isWaxing
        ? Alignment.centerLeft
        : Alignment.centerRight;
    canvas.drawCircle(
      center,
      radius - 0.6,
      Paint()
        ..shader = LinearGradient(
          begin: rimAlign,
          end: oppAlign,
          colors: [
            const Color(0xFFFFF8DC).withValues(alpha: 0.75),
            const Color(0xFFD4AF37).withValues(alpha: 0.28),
            const Color(0xFF8C7A6B).withValues(alpha: 0.18),
          ],
        ).createShader(discRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  void _paintLunarMaria(
    Canvas canvas,
    Offset center,
    double radius,
    Color washColor,
  ) {
    final paint = Paint()
      ..color = washColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.09);

    // Mare Imbrium & Oceanus Procellarum (upper-left quadrant)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - radius * 0.26, center.dy - radius * 0.24),
        width: radius * 0.54,
        height: radius * 0.44,
      ),
      paint,
    );
    // Mare Serenitatis & Tranquillitatis (center-right)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + radius * 0.20, center.dy - radius * 0.08),
        width: radius * 0.46,
        height: radius * 0.38,
      ),
      paint,
    );
    // Mare Fecunditatis & Crisium (right limb)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + radius * 0.38, center.dy + radius * 0.18),
        width: radius * 0.32,
        height: radius * 0.42,
      ),
      paint,
    );
    // Southern highlands stipple wash
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - radius * 0.12, center.dy + radius * 0.34),
        width: radius * 0.58,
        height: radius * 0.28,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant MoonPainter oldDelegate) =>
      oldDelegate.info != info ||
      oldDelegate.organicWatercolor != organicWatercolor;
}
