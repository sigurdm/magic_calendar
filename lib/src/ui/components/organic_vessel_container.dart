import 'dart:collection';
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
/// $O(1)$ time per paint pass, memoizing geometry and gradient shaders across frames.
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

  static const DiurnalSolarLighting _defaultLighting = DiurnalSolarLighting(
    lx: -0.45,
    ly: -0.72,
    lz: 0.52,
    sunAltitude: 0.68,
    daylightFactor: 0.92,
  );

  @override
  Widget build(BuildContext context) {
    final effectiveLighting = lighting ?? _defaultLighting;

    final painted = CustomPaint(
      isComplex: !isInsetNiche,
      painter: _OrganicVesselPainter(
        accentColor: accentColor,
        lighting: effectiveLighting,
        seed: seed,
        isInsetNiche: isInsetNiche,
      ),
      child: Padding(padding: padding, child: child),
    );
    return isInsetNiche ? painted : RepaintBoundary(child: painted);
  }
}

final class _CachedVesselPaints {
  final Paint rimPaint;
  final Paint wellPaint;
  final Paint crestPaint;

  const _CachedVesselPaints({
    required this.rimPaint,
    required this.wellPaint,
    required this.crestPaint,
  });
}

final class _OrganicVesselPainter extends CustomPainter {
  static final Paint _dropShadowPaint = Paint()
    ..color = const Color(0x6B000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);

  static final Paint _cavityShadowRaisedPaint = Paint()
    ..color = const Color(0x8C000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5.0
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

  static final Paint _cavityShadowInsetPaint = Paint()
    ..color = const Color(0x73000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

  static final LinkedHashMap<(Size, int, bool), (Path, Path)> _pathCache =
      LinkedHashMap();

  static final LinkedHashMap<
    (Size, int, int, int, int, bool),
    _CachedVesselPaints
  >
  _shaderPaintCache = LinkedHashMap();

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

  static (Path, Path) _resolvePaths(Size size, double seed, bool isInsetNiche) {
    final safeSeed = seed.isFinite ? seed : 0.0;
    final key = (size, (safeSeed * 1000).round(), isInsetNiche);
    final existing = _pathCache.remove(key);
    if (existing != null) {
      _pathCache[key] = existing;
      return existing;
    }
    final outerPath = _buildVesselPathStatic(size, 0.0, safeSeed, isInsetNiche);
    final bevelWidth = isInsetNiche ? 2.5 : 5.5;
    final innerPath = _buildVesselPathStatic(
      size,
      bevelWidth,
      safeSeed,
      isInsetNiche,
    );
    final pair = (outerPath, innerPath);
    if (_pathCache.length >= 48) {
      _pathCache.remove(_pathCache.keys.first);
    }
    _pathCache[key] = pair;
    return pair;
  }

  static _CachedVesselPaints _resolveShaderPaints(
    Size size,
    Color accentColor,
    DiurnalSolarLighting lighting,
    bool isInsetNiche,
  ) {
    final safeLx = lighting.lx.isFinite ? lighting.lx.clamp(-1.0, 1.0) : -0.45;
    final safeLy = lighting.ly.isFinite ? lighting.ly.clamp(-1.0, 1.0) : -0.72;
    final safeDay = lighting.daylightFactor.isFinite
        ? lighting.daylightFactor.clamp(0.0, 1.0)
        : 0.92;
    final qLx = (safeLx * 100).round();
    final qLy = (safeLy * 100).round();
    final qDay = (safeDay * 100).round();
    final key = (size, accentColor.toARGB32(), qLx, qLy, qDay, isInsetNiche);
    final existing = _shaderPaintCache.remove(key);
    if (existing != null) {
      _shaderPaintCache[key] = existing;
      return existing;
    }

    final sunSideAlign = Alignment(
      safeLx.clamp(-0.9, 0.9),
      safeLy.clamp(-0.9, 0.9),
    );
    final shadowSideAlign = Alignment(
      (-safeLx).clamp(-0.9, 0.9),
      (-safeLy).clamp(-0.9, 0.9),
    );

    final warmTint = Color.lerp(
      accentColor,
      const Color(0xFFF3E5C8),
      0.48 * safeDay + 0.15,
    )!;
    final midBody = Color.lerp(
      const Color(0xFF2B2622),
      accentColor,
      isInsetNiche ? 0.20 : 0.32,
    )!;
    final deepShadow = Color.lerp(const Color(0xFF14110F), accentColor, 0.10)!;

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

    const wellBaseDark = Color(0xFF1E1B18);
    const wellTopsoil = Color(0xFF27231E);
    final wellLazure = Color.lerp(
      wellTopsoil,
      accentColor,
      isInsetNiche ? 0.14 : 0.11,
    )!;

    final wellPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(safeLx * 0.5, safeLy * 0.5),
        radius: 1.15,
        colors: [
          wellLazure.withValues(alpha: isInsetNiche ? 0.88 : 0.94),
          wellBaseDark.withValues(alpha: isInsetNiche ? 0.92 : 0.96),
        ],
      ).createShader(rimRect);

    final crestPaint = Paint()
      ..shader = LinearGradient(
        begin: rimStartAlign,
        end: rimEndAlign,
        colors: [
          warmTint.withValues(alpha: isInsetNiche ? 0.35 : 0.55),
          accentColor.withValues(alpha: 0.18),
          const Color(0x59000000),
        ],
      ).createShader(rimRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final created = _CachedVesselPaints(
      rimPaint: rimPaint,
      wellPaint: wellPaint,
      crestPaint: crestPaint,
    );
    if (_shaderPaintCache.length >= 64) {
      _shaderPaintCache.remove(_shaderPaintCache.keys.first);
    }
    _shaderPaintCache[key] = created;
    return created;
  }

  /// Builds an asymmetric, C1-continuous non-Cartesian contour inspired by
  /// Steiner's carved wooden frames and concrete portals at Dornach.
  static Path _buildVesselPathStatic(
    Size size,
    double inset,
    double seed,
    bool isInsetNiche,
  ) {
    final w = size.width;
    final h = size.height;
    final maxInset = math.max(0.0, math.min(w, h) * 0.25);
    final effectiveInset = math.min(inset, maxInset);
    final l = effectiveInset;
    final t = effectiveInset;
    final r = w - effectiveInset;
    final b = h - effectiveInset;
    final availW = math.max(0.0, r - l);
    final availH = math.max(0.0, b - t);

    // Subtle organic asymmetry varied by seed so cards don't look stamped from a cookie cutter
    final archShift = (math.sin(seed * 1.7) * 0.08 + 0.06) * w;
    final topLift = math.min(isInsetNiche ? 2.2 : 4.5, availH * 0.2);
    final bottomWave = math.min(isInsetNiche ? 1.8 : 3.6, availH * 0.2);
    final sideSwell = math.min(isInsetNiche ? 1.5 : 3.0, availW * 0.2);
    final cornerX = math.min(isInsetNiche ? 14.0 : 24.0, availW * 0.35);
    final cornerY = math.min(isInsetNiche ? 14.0 : 22.0, availH * 0.35);

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
    if (size.width <= 0 ||
        size.height <= 0 ||
        !size.width.isFinite ||
        !size.height.isFinite) {
      return;
    }

    final (outerPath, innerPath) = _resolvePaths(size, seed, isInsetNiche);
    final paints = _resolveShaderPaints(
      size,
      accentColor,
      lighting,
      isInsetNiche,
    );

    final safeLx = lighting.lx.isFinite ? lighting.lx.clamp(-1.0, 1.0) : -0.45;
    final safeLy = lighting.ly.isFinite ? lighting.ly.clamp(-1.0, 1.0) : -0.72;

    // 1. Directional drop shadow cast away from the diurnal sun vector
    if (!isInsetNiche) {
      final shadowDx = -safeLx * 6.0;
      final shadowDy = (-safeLy * 5.0).clamp(2.0, 8.0);
      canvas.save();
      canvas.translate(shadowDx, shadowDy);
      canvas.drawPath(outerPath, _dropShadowPaint);
      canvas.restore();
    }

    // 2. Sculpted outer bevel frame (chiseled mineral crest catching diurnal sunlight)
    canvas.drawPath(outerPath, paints.rimPaint);

    // 3. Inner recessed card well with warm compost/humus watercolor lazure glaze
    canvas.drawPath(innerPath, paints.wellPaint);

    // 4. Subtle inner reveal shadow & sunlit sill highlight along the chiseled ridge
    canvas.save();
    canvas.clipPath(innerPath);
    // Sunken cavity shadow cast by the frame overhang
    canvas.translate(-safeLx * 2.5, -safeLy * 2.5);
    canvas.drawPath(
      innerPath,
      isInsetNiche ? _cavityShadowInsetPaint : _cavityShadowRaisedPaint,
    );
    canvas.restore();

    // Crisp chiseled crest line where outer bevel meets inner slope
    canvas.drawPath(innerPath, paints.crestPaint);
  }

  @override
  bool shouldRepaint(covariant _OrganicVesselPainter oldDelegate) {
    if (oldDelegate.accentColor != accentColor ||
        oldDelegate.seed != seed ||
        oldDelegate.isInsetNiche != isInsetNiche) {
      return true;
    }
    final oldL = oldDelegate.lighting;
    if (identical(oldL, lighting)) return false;
    return (oldL.lx - lighting.lx).abs() >= 0.01 ||
        (oldL.ly - lighting.ly).abs() >= 0.01 ||
        (oldL.daylightFactor - lighting.daylightFactor).abs() >= 0.01;
  }
}
