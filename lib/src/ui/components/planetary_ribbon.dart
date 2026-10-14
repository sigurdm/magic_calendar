import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/dornach_boundaries.dart';
import '../../services/ephemeris_service.dart';
import '../theme/goethean_palette.dart';
import 'organic_vessel_container.dart';

/// Widget displaying planetary positions across the zodiac ribbon.
final class PlanetaryRibbon extends StatelessWidget {
  /// Notifier for currently selected date/time.
  final ValueListenable<DateTime> timeNotifier;

  /// Ephemeris service.
  final EphemerisService ephemeris;

  /// Height of ribbon widget.
  final double height;

  /// Creates a [PlanetaryRibbon].
  const PlanetaryRibbon({
    super.key,
    required this.timeNotifier,
    required this.ephemeris,
    this.height = 64,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<DateTime>(
        valueListenable: timeNotifier,
        builder: (context, time, _) {
          final planets = ephemeris.getPlanets(time);
          final moon = planets.firstWhere(
            (p) => p.name == 'Moon',
            orElse: () => PlanetInfo(name: 'Moon', longitude: 0),
          );

          final painterWidget = CustomPaint(
            size: Size(double.infinity, height),
            painter: RibbonPainter(
              planets: planets,
              centerLongitude: moon.longitude,
            ),
          );

          return SizedBox(
            height: height + 8,
            width: double.infinity,
            child: OrganicVesselContainer.inset(
              padding: const EdgeInsets.all(4),
              accentColor: GoetheanPalette.aspectGold,
              seed: 4.2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: painterWidget,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Painter for drawing constellation boundaries and planet markers.
final class RibbonPainter extends CustomPainter {
  /// List of planets to draw.
  final List<PlanetInfo> planets;

  /// Center longitude reference.
  final double centerLongitude;

  /// Whether to render feathered watercolor washes, ecliptic sine wave, and planet halos.
  final bool organicFlow;

  /// Whether to use the Goethean nature palette for zodiac elements.
  final bool warmPalette;

  /// Creates a [RibbonPainter].
  const RibbonPainter({
    required this.planets,
    required this.centerLongitude,
    this.organicFlow = true,
    this.warmPalette = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) {
      return;
    }

    const double visibleRange = 360.0;
    final double degreeWidth = size.width / visibleRange;
    final double startLon = centerLongitude - 180.0;

    double getX(double lon) {
      double relativeLon = (lon - startLon) % 360.0;
      if (relativeLon < 0) {
        relativeLon += 360.0;
      }
      return relativeLon * degreeWidth;
    }

    final count = dornachBoundaries.length;
    for (int i = 0; i < count; i++) {
      final boundary = dornachBoundaries[i];
      final nextBoundary = dornachBoundaries[(i + 1) % count];
      final baseColor = _getColorForElement(boundary.element);
      final nextColor = _getColorForElement(nextBoundary.element);
      final alpha = organicFlow ? 0.20 : 0.10;

      final double x1 = getX(boundary.startDegree);
      final double x2 = getX(boundary.endDegree);

      Paint buildBandPaint(double left, double width) {
        if (!organicFlow || width <= 4) {
          return Paint()
            ..color = baseColor.withValues(alpha: alpha)
            ..style = PaintingStyle.fill;
        }
        final rect = Rect.fromLTWH(left, 0, width, size.height);
        return Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              baseColor.withValues(alpha: alpha * 0.95),
              baseColor.withValues(alpha: alpha * 1.15),
              Color.lerp(baseColor, nextColor, 0.5)!.withValues(alpha: alpha),
            ],
            stops: const [0.0, 0.72, 1.0],
          ).createShader(rect);
      }

      if (x2 < x1) {
        final w1 = size.width - x1;
        canvas.drawRect(
          Rect.fromLTWH(x1, 0, w1, size.height),
          buildBandPaint(x1, w1),
        );
        canvas.drawRect(
          Rect.fromLTWH(0, 0, x2, size.height),
          buildBandPaint(0, x2),
        );
      } else {
        final w = x2 - x1;
        canvas.drawRect(
          Rect.fromLTWH(x1, 0, w, size.height),
          buildBandPaint(x1, w),
        );
      }

      double blockWidth = (boundary.endDegree - boundary.startDegree) % 360.0;
      if (blockWidth < 0) {
        blockWidth += 360.0;
      }

      if (blockWidth * degreeWidth > 15) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: boundary.name.substring(0, 3).toUpperCase(),
            style: TextStyle(
              fontFamily: 'Outfit',
              color: organicFlow || warmPalette
                  ? const Color(0xFFE8DCC8).withValues(alpha: 0.45)
                  : Colors.white24,
              fontSize: 9,
              letterSpacing: organicFlow ? 0.8 : 0.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout();

        double labelX = x1 + (blockWidth * degreeWidth - textPainter.width) / 2;
        labelX = labelX % size.width;
        if (labelX < 0) {
          labelX += size.width;
        }

        textPainter.paint(canvas, Offset(labelX, size.height - 15));
      }
    }

    // Draw flowing golden ecliptic sine wave when organicFlow is enabled
    if (organicFlow) {
      final eclipticPath = Path();
      for (double x = 0; x <= size.width; x += 4.0) {
        final lonRad = ((startLon + x / degreeWidth) * math.pi) / 180.0;
        final y = (size.height * 0.46) - math.sin(lonRad) * 9.5;
        if (x == 0) {
          eclipticPath.moveTo(x, y);
        } else {
          eclipticPath.lineTo(x, y);
        }
      }
      canvas.drawPath(
        eclipticPath,
        Paint()
          ..color = GoetheanPalette.aspectGold.withValues(alpha: 0.26)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    final offsets = {
      'Sun': 0.0,
      'Moon': -15.0,
      'Mercury': 15.0,
      'Venus': -10.0,
      'Mars': 10.0,
      'Jupiter': -5.0,
      'Saturn': 5.0,
    };

    for (var planet in planets) {
      final x = getX(planet.longitude);

      if (x < -20 || x > size.width + 20) {
        continue;
      }

      final yOffset = offsets[planet.name] ?? 0.0;
      final y = size.height / 2 + yOffset;
      final pColor = _getPlanetColor(planet.name);

      if (organicFlow) {
        // Soft watercolor halo around each planet orb
        canvas.drawCircle(
          Offset(x, y),
          8.5,
          Paint()
            ..color = pColor.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
        );
      }

      final paint = Paint()
        ..color = pColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), organicFlow ? 4.5 : 4.0, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: _getPlanetSymbol(planet.name),
          style: TextStyle(
            color: organicFlow || warmPalette
                ? const Color(0xFFF6ECD8)
                : Colors.white,
            fontSize: 16,
            fontFamilyFallback: const [
              'DejaVu Sans',
              'Symbola',
              'Noto Sans Symbols',
            ],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - 22));
    }

    final refPaint = Paint()
      ..color = organicFlow
          ? GoetheanPalette.aspectGold.withValues(alpha: 0.35)
          : Colors.white12
      ..strokeWidth = organicFlow ? 1.4 : 1.0;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      refPaint,
    );
  }

  Color _getColorForElement(String element) {
    if (warmPalette || organicFlow) {
      switch (element) {
        case 'Earth':
          return GoetheanPalette.rootEarth;
        case 'Water':
          return GoetheanPalette.leafWater;
        case 'Air':
          return GoetheanPalette.flowerAir;
        case 'Fire':
          return GoetheanPalette.fruitWarmth;
        default:
          return GoetheanPalette.neutralRest;
      }
    }
    switch (element) {
      case 'Earth':
        return const Color(0xFF8D6E63);
      case 'Water':
        return const Color(0xFF66BB6A);
      case 'Air':
        return const Color(0xFFAB47BC);
      case 'Fire':
        return const Color(0xFFFFA726);
      default:
        return Colors.grey;
    }
  }

  Color _getPlanetColor(String name) {
    switch (name) {
      case 'Sun':
        return const Color(0xFFFBC02D);
      case 'Moon':
        return const Color(0xFFFFF9C4);
      case 'Mercury':
        return const Color(0xFFB0BEC5);
      case 'Venus':
        return const Color(0xFF81C784);
      case 'Mars':
        return const Color(0xFFE57373);
      case 'Jupiter':
        return const Color(0xFFFFB74D);
      case 'Saturn':
        return const Color(0xFFA1887F);
      default:
        return Colors.white;
    }
  }

  String _getPlanetSymbol(String name) {
    switch (name) {
      case 'Sun':
        return '☉';
      case 'Moon':
        return '☽';
      case 'Mercury':
        return '☿';
      case 'Venus':
        return '♀';
      case 'Mars':
        return '♂';
      case 'Jupiter':
        return '♃';
      case 'Saturn':
        return '♄';
      default:
        return '•';
    }
  }

  @override
  bool shouldRepaint(covariant RibbonPainter oldDelegate) {
    return oldDelegate.centerLongitude != centerLongitude ||
        oldDelegate.planets != planets ||
        oldDelegate.organicFlow != organicFlow ||
        oldDelegate.warmPalette != warmPalette;
  }
}
