import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/ephemeris_service.dart';

final class _CachedMoonStaticLayer {
  final Offset center;
  final double radius;
  final bool isWaxing;
  final Rect discRect;
  final Path discClipPath;
  final Paint coronaPaint;
  final Paint earthshinePaint;
  final Paint terminatorBleedPaint;
  final Paint sunWashPaint;
  final Paint rimPaint;
  final Paint mariaDarkPaint;
  final Paint mariaLitPrimaryPaint;
  final Paint mariaLitSecondaryPaint;
  final List<Rect> primaryMariaOvals;
  final List<Rect> secondaryMariaOvals;

  _CachedMoonStaticLayer({
    required this.center,
    required this.radius,
    required this.isWaxing,
  }) : discRect = Rect.fromCircle(center: center, radius: radius),
       discClipPath = Path()
         ..addOval(Rect.fromCircle(center: center, radius: radius)),
       coronaPaint = Paint()
         ..shader = ui.Gradient.radial(
           center,
           radius * 1.32,
           const [Color(0x5CF6E3A8), Color(0x24D9B26F), Colors.transparent],
           const [0.0, 0.65, 1.0],
         )
         ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.22),
       earthshinePaint = Paint()
         ..shader = ui.Gradient.radial(
           Offset(
             center.dx + (isWaxing ? -radius * 0.35 : radius * 0.35),
             center.dy - radius * 0.18,
           ),
           radius * 1.4,
           const [
             Color(0xFF3A313D), // Warm twilight earthshine
             Color(0xFF241E26), // Deep humus umber-indigo
             Color(0xFF171319),
           ],
           const [0.0, 0.65, 1.0],
         ),
       terminatorBleedPaint = Paint()
         ..color = const Color(0x7AE5B96B)
         ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.14),
       sunWashPaint = Paint()
         ..shader = ui.Gradient.radial(
           Offset(
             center.dx + (isWaxing ? radius * 0.38 : -radius * 0.38),
             center.dy - radius * 0.22,
           ),
           radius * 1.45,
           const [
             Color(0xFFFFFDF5), // Luminous paper reserve highlight
             Color(0xFFF9E8B2), // Warm beeswax yellow lazure
             Color(0xFFE6C278), // Golden ochre middle wash
             Color(0xFFC4944A), // Granulating sienna limb darkening
           ],
           const [0.0, 0.38, 0.76, 1.0],
         ),
       rimPaint = Paint()
         ..shader = LinearGradient(
           begin: isWaxing ? Alignment.centerRight : Alignment.centerLeft,
           end: isWaxing ? Alignment.centerLeft : Alignment.centerRight,
           colors: const [
             Color(0xBFFFF8DC),
             Color(0x47D4AF37),
             Color(0x2E8C7A6B),
           ],
         ).createShader(Rect.fromCircle(center: center, radius: radius))
         ..style = PaintingStyle.stroke
         ..strokeWidth = 1.4,
       mariaDarkPaint = Paint()
         ..color = const Color(0x52120E14)
         ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.09),
       mariaLitPrimaryPaint = Paint()
         ..color = const Color(0x3D9C7B4C)
         ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.09),
       mariaLitSecondaryPaint = Paint()
         ..color = const Color(0x297A6348)
         ..maskFilter = MaskFilter.blur(
           BlurStyle.normal,
           (radius * 0.88) * 0.09,
         ),
       primaryMariaOvals = _buildMariaOvals(center, radius),
       secondaryMariaOvals = _buildMariaOvals(
         Offset(center.dx + radius * 0.06, center.dy - radius * 0.04),
         radius * 0.88,
       );

  static List<Rect> _buildMariaOvals(Offset c, double r) {
    return <Rect>[
      Rect.fromCenter(
        center: Offset(c.dx - r * 0.26, c.dy - r * 0.24),
        width: r * 0.54,
        height: r * 0.44,
      ),
      Rect.fromCenter(
        center: Offset(c.dx + r * 0.20, c.dy - r * 0.08),
        width: r * 0.46,
        height: r * 0.38,
      ),
      Rect.fromCenter(
        center: Offset(c.dx + r * 0.38, c.dy + r * 0.18),
        width: r * 0.32,
        height: r * 0.42,
      ),
      Rect.fromCenter(
        center: Offset(c.dx - r * 0.12, c.dy + r * 0.34),
        width: r * 0.58,
        height: r * 0.28,
      ),
    ];
  }
}

/// CustomPainter for rendering real-time moon phase graphics.
///
/// Supports both the classic flat geometric mode and an organic Goethean
/// watercolor mode featuring warm earthshine on the shadowed limb, a feathered
/// terminator, translucent lunar maria washes, and an atmospheric corona glow.
final class MoonPainter extends CustomPainter {
  /// Minimum change in [MoonPhaseInfo.illuminatedFraction] required to trigger
  /// a repaint (~0.2% illumination, sub-pixel at standard widget sizes).
  static const double phaseRepaintThreshold = 0.002;

  static final Paint _classicBgPaint = Paint()..color = const Color(0xFF1E1E2E);
  static final Paint _classicLightPaint = Paint()
    ..color = const Color(0xFFFFF9C4);
  static final Paint _classicBorderPaint = Paint()
    ..color = const Color(0x1AFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  static final LinkedHashMap<(Offset, double, bool), _CachedMoonStaticLayer>
  _staticLayerCache = LinkedHashMap();

  static final LinkedHashMap<(Offset, double, bool, int), Path> _litPathCache =
      LinkedHashMap();

  /// Moon phase data used to render illumination.
  final MoonPhaseInfo info;

  /// Whether to render with hand-painted watercolor washes, earthshine, and corona.
  final bool organicWatercolor;

  /// Creates a [MoonPainter].
  const MoonPainter({required this.info, this.organicWatercolor = true});

  static _CachedMoonStaticLayer _resolveStaticLayer(
    Offset center,
    double radius,
    bool isWaxing,
  ) {
    final key = (center, radius, isWaxing);
    final existing = _staticLayerCache.remove(key);
    if (existing != null) {
      _staticLayerCache[key] = existing;
      return existing;
    }
    final created = _CachedMoonStaticLayer(
      center: center,
      radius: radius,
      isWaxing: isWaxing,
    );
    if (_staticLayerCache.length >= 16) {
      _staticLayerCache.remove(_staticLayerCache.keys.first);
    }
    _staticLayerCache[key] = created;
    return created;
  }

  static Path _resolveLitPath(
    Offset center,
    double radius,
    Rect discRect,
    bool isWaxing,
    double k,
  ) {
    final quantizedK = (k * 500.0).round();
    final key = (center, radius, isWaxing, quantizedK);
    final existing = _litPathCache.remove(key);
    if (existing != null) {
      _litPathCache[key] = existing;
      return existing;
    }

    final effectiveK = quantizedK / 500.0;
    final isCrescent = effectiveK < 0.5;
    final ellipseWidth =
        (isCrescent ? 1.0 - 2.0 * effectiveK : 2.0 * effectiveK - 1.0) * radius;

    final semiCirclePath = Path()
      ..addArc(discRect, isWaxing ? -math.pi / 2 : math.pi / 2, math.pi)
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

    if (_litPathCache.length >= 32) {
      _litPathCache.remove(_litPathCache.keys.first);
    }
    _litPathCache[key] = litPath;
    return litPath;
  }

  static double _safeFraction(double value) =>
      value.isFinite ? value.clamp(0.0, 1.0) : 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    if (radius <= 0 || !radius.isFinite) return;

    if (!organicWatercolor) {
      _paintClassic(canvas, center, radius);
      return;
    }

    _paintOrganicWatercolor(canvas, center, radius);
  }

  void _paintClassic(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, _classicBgPaint);

    final k = _safeFraction(info.illuminatedFraction);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      info.isWaxing ? -math.pi / 2 : math.pi / 2,
      math.pi,
      true,
      _classicLightPaint,
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
      isCrescent ? _classicBgPaint : _classicLightPaint,
    );

    canvas.drawCircle(center, radius, _classicBorderPaint);
  }

  void _paintOrganicWatercolor(Canvas canvas, Offset center, double radius) {
    final layer = _resolveStaticLayer(center, radius, info.isWaxing);
    final discRect = layer.discRect;

    // 1. Soft atmospheric lunar corona (warm golden-pearl halo)
    canvas.drawCircle(center, radius * 1.16, layer.coronaPaint);

    // 2. Shadowed limb with warm copper-violet Earthshine
    canvas.drawCircle(center, radius, layer.earthshinePaint);

    // Subtle maria blotches visible even in earthshine
    canvas.save();
    canvas.clipPath(layer.discClipPath);
    _paintMariaOvals(canvas, layer.primaryMariaOvals, layer.mariaDarkPaint);

    // 3. Illuminated limb path (analytic crescent/gibbous manifold)
    final k = _safeFraction(info.illuminatedFraction);
    final litPath = _resolveLitPath(center, radius, discRect, info.isWaxing, k);

    // Soft feathered watercolor bleed across the terminator into the dark limb
    canvas.drawPath(litPath, layer.terminatorBleedPaint);

    // Main multi-stop watercolor pigment wash on the illuminated limb
    canvas.save();
    canvas.clipPath(litPath);
    canvas.drawRect(discRect, layer.sunWashPaint);

    // Hand-painted watercolor lunar maria (Mare Imbrium, Serenitatis, Tranquillitatis)
    _paintMariaOvals(
      canvas,
      layer.primaryMariaOvals,
      layer.mariaLitPrimaryPaint,
    );
    _paintMariaOvals(
      canvas,
      layer.secondaryMariaOvals,
      layer.mariaLitSecondaryPaint,
    );
    canvas.restore();
    canvas.restore();

    // 4. Hand-brushed golden rim highlight on the sunlit edge & subtle earthshine rim
    if (radius > 0.6) {
      canvas.drawCircle(center, radius - 0.6, layer.rimPaint);
    }
  }

  void _paintMariaOvals(Canvas canvas, List<Rect> ovals, Paint paint) {
    for (int i = 0; i < ovals.length; i++) {
      canvas.drawOval(ovals[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant MoonPainter oldDelegate) {
    if (oldDelegate.organicWatercolor != organicWatercolor ||
        oldDelegate.info.isWaxing != info.isWaxing) {
      return true;
    }
    final oldK = _safeFraction(oldDelegate.info.illuminatedFraction);
    final newK = _safeFraction(info.illuminatedFraction);
    return (oldK - newK).abs() >= phaseRepaintThreshold;
  }
}
