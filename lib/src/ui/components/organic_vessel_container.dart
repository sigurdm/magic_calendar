import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/goethean_palette.dart';
import 'plant_quality_card.dart';

/// Sculpted Anthroposophic container replacing flat `BorderRadius.circular` cards
/// with non-Cartesian Goetheanum contours, chiseled bevel ridges, and diurnal solar lighting.
///
/// Preconditions:
/// * [child] must not be null. It is an error if [child] is null.
///
/// Performance considerations:
/// Evaluates smooth cubic Bézier boundary contours and faceted rim gradients in
/// $O(1)$ time per paint pass.
final class OrganicVesselContainer extends StatelessWidget {
  /// Inner widget content.
  final Widget child;

  /// Inner padding inside the sculpted frame.
  final EdgeInsetsGeometry padding;

  /// Mineral pigment accent color tinting the lazure glaze and sunlit bevel crest.
  final Color accentColor;

  /// Optional diurnal solar lighting state. If omitted, uses a warm morning/noon default.
  final DiurnalSolarLighting? lighting;

  /// Seed value varying the organic asymmetry between sibling cards (`0.0` to `10.0`).
  final double seed;

  /// Whether this is a recessed inner niche (e.g. weather sub-tile or status banner)
  /// rather than a raised primary vessel.
  final bool isInsetNiche;

  /// Creates a primary raised [OrganicVesselContainer].
  const OrganicVesselContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.accentColor = GoetheanPalette.leafWater,
    this.lighting,
    this.seed = 0.0,
    this.isInsetNiche = false,
  });

  /// Creates a recessed inner niche [OrganicVesselContainer] for sub-panels and banners.
  const OrganicVesselContainer.inset({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.accentColor = GoetheanPalette.leafWater,
    this.lighting,
    this.seed = 1.0,
  }) : isInsetNiche = true;

  @override
  Widget build(BuildContext context) {
    final effectiveLighting =
        lighting ??
        const DiurnalSolarLighting(
          lx: -0.45,
          ly: -0.72,
          lz: 0.52,
          sunAltitude: 0.68,
          daylightFactor: 0.92,
        );

    return CustomPaint(
      painter: _OrganicVesselPainter(
        accentColor: accentColor,
        lighting: effectiveLighting,
        seed: seed,
        isInsetNiche: isInsetNiche,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

final class _OrganicVesselPainter extends CustomPainter {
  final Color accentColor;
  final DiurnalSolarLighting lighting;
  final double seed;
  final bool isInsetNiche;

  const _OrganicVesselPainter({
    required this.accentColor,
    required this.lighting,
    required this.seed,
    required this.isInsetNiche,
  });

  /// Builds an asymmetric, C1-continuous non-Cartesian contour inspired by
  /// Steiner's carved wooden frames and concrete portals at Dornach.
  Path _buildVesselPath(Size size, double inset) {
    final w = size.width;
    final h = size.height;
    final l = inset;
    final t = inset;
    final r = w - inset;
    final b = h - inset;

    // Subtle organic asymmetry varied by seed so cards don't look stamped from a cookie cutter
    final archShift = (math.sin(seed * 1.7) * 0.08 + 0.06) * w;
    final topLift = isInsetNiche ? 2.2 : 4.5;
    final bottomWave = isInsetNiche ? 1.8 : 3.6;
    final sideSwell = isInsetNiche ? 1.5 : 3.0;
    final cornerX = isInsetNiche ? 14.0 : 24.0;
    final cornerY = isInsetNiche ? 14.0 : 22.0;

    final path = Path();
    // Start on upper-left shoulder after the sculpted arch corner
    path.moveTo(l + cornerX, t + 1.5);

    // Upper lintel: asymmetric arch rising toward center-right (or center-left via seed)
    path.cubicTo(
      w * 0.32 + archShift,
      t - topLift,
      w * 0.68 + archShift * 0.5,
      t - topLift * 0.85,
      r - cornerX,
      t + 1.0,
    );

    // Upper-right faceted shoulder corner
    path.cubicTo(
      r - cornerX * 0.32,
      t + 1.5,
      r - 1.0,
      t + cornerY * 0.38,
      r - 0.5,
      t + cornerY,
    );

    // Right flank: living S-curve swelling gently outward in the lower half
    path.cubicTo(
      r + sideSwell * 0.6,
      h * 0.38,
      r + sideSwell,
      h * 0.68,
      r - 1.0,
      b - cornerY,
    );

    // Lower-right grounded foot corner
    path.cubicTo(
      r - 1.5,
      b - cornerY * 0.35,
      r - cornerX * 0.35,
      b - 0.5,
      r - cornerX,
      b - 1.0,
    );

    // Bottom sill rail: undulating wave rising slightly in the middle and grounding at the left foot
    path.cubicTo(
      w * 0.66 - archShift * 0.4,
      b - bottomWave,
      w * 0.30 - archShift * 0.5,
      b + bottomWave * 0.65,
      l + cornerX,
      b - 0.5,
    );

    // Lower-left architectural foot corner
    path.cubicTo(
      l + cornerX * 0.32,
      b + 0.5,
      l + 1.0,
      b - cornerY * 0.32,
      l + 0.5,
      b - cornerY,
    );

    // Left flank: gentle inward bow rising back to the upper-left shoulder
    path.cubicTo(
      l - sideSwell * 0.5,
      h * 0.65,
      l + sideSwell * 0.6,
      h * 0.32,
      l + 1.0,
      t + cornerY,
    );

    // Upper-left shoulder corner closing the manifold
    path.cubicTo(
      l + 1.2,
      t + cornerY * 0.35,
      l + cornerX * 0.35,
      t + 2.0,
      l + cornerX,
      t + 1.5,
    );

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final outerPath = _buildVesselPath(size, 0.0);
    final bevelWidth = isInsetNiche ? 2.5 : 5.5;
    final innerPath = _buildVesselPath(size, bevelWidth);

    // 1. Directional drop shadow cast away from the diurnal sun vector
    if (!isInsetNiche) {
      final shadowDx = -lighting.lx * 6.0;
      final shadowDy = (-lighting.ly * 5.0).clamp(2.0, 8.0);
      canvas.save();
      canvas.translate(shadowDx, shadowDy);
      canvas.drawPath(
        outerPath,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.42)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0),
      );
      canvas.restore();
    }

    // 2. Sculpted outer bevel frame (chiseled mineral crest catching diurnal sunlight)
    final sunSideAlign = Alignment(
      lighting.lx.clamp(-0.9, 0.9),
      lighting.ly.clamp(-0.9, 0.9),
    );
    final shadowSideAlign = Alignment(
      (-lighting.lx).clamp(-0.9, 0.9),
      (-lighting.ly).clamp(-0.9, 0.9),
    );

    final warmTint = Color.lerp(
      accentColor,
      const Color(0xFFF3E5C8),
      0.48 * lighting.daylightFactor + 0.15,
    )!;
    final midBody = Color.lerp(
      const Color(0xFF2B2622),
      accentColor,
      isInsetNiche ? 0.20 : 0.32,
    )!;
    final deepShadow = Color.lerp(const Color(0xFF14110F), accentColor, 0.10)!;

    // For inset niches, invert light/shadow alignment so the top/sunward lip looks sunken
    final rimStartAlign = isInsetNiche ? shadowSideAlign : sunSideAlign;
    final rimEndAlign = isInsetNiche ? sunSideAlign : shadowSideAlign;

    final rimRect = Offset.zero & size;
    final rimPaint = Paint()
      ..shader = LinearGradient(
        begin: rimStartAlign,
        end: rimEndAlign,
        colors: [
          warmTint.withValues(alpha: isInsetNiche ? 0.45 : 0.68),
          midBody.withValues(alpha: isInsetNiche ? 0.55 : 0.82),
          deepShadow.withValues(alpha: isInsetNiche ? 0.72 : 0.92),
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(rimRect);

    canvas.drawPath(outerPath, rimPaint);

    // 3. Inner recessed card well with warm compost/humus watercolor lazure glaze
    final wellBaseDark = const Color(0xFF1E1B18);
    final wellTopsoil = const Color(0xFF27231E);
    final wellLazure = Color.lerp(
      wellTopsoil,
      accentColor,
      isInsetNiche ? 0.14 : 0.11,
    )!;

    final wellPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(lighting.lx * 0.5, lighting.ly * 0.5),
        radius: 1.15,
        colors: [
          wellLazure.withValues(alpha: isInsetNiche ? 0.88 : 0.94),
          wellBaseDark.withValues(alpha: isInsetNiche ? 0.92 : 0.96),
        ],
      ).createShader(rimRect);

    canvas.drawPath(innerPath, wellPaint);

    // 4. Subtle inner reveal shadow & sunlit sill highlight along the chiseled ridge
    canvas.save();
    canvas.clipPath(innerPath);
    // Sunken cavity shadow cast by the frame overhang
    canvas.translate(-lighting.lx * 2.5, -lighting.ly * 2.5);
    canvas.drawPath(
      innerPath,
      Paint()
        ..color = Colors.black.withValues(alpha: isInsetNiche ? 0.45 : 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isInsetNiche ? 3.0 : 5.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );
    canvas.restore();

    // Crisp chiseled crest line where outer bevel meets inner slope
    final crestPaint = Paint()
      ..shader = LinearGradient(
        begin: rimStartAlign,
        end: rimEndAlign,
        colors: [
          warmTint.withValues(alpha: isInsetNiche ? 0.35 : 0.55),
          accentColor.withValues(alpha: 0.18),
          Colors.black.withValues(alpha: 0.35),
        ],
      ).createShader(rimRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawPath(innerPath, crestPaint);
  }

  @override
  bool shouldRepaint(covariant _OrganicVesselPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor ||
      oldDelegate.lighting != lighting ||
      oldDelegate.seed != seed ||
      oldDelegate.isInsetNiche != isInsetNiche;
}
