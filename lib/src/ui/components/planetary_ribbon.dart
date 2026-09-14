import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'dart:ui' as ui;

import '../../services/ephemeris_service.dart';
import '../../core/dornach_boundaries.dart';

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
    this.height = 60,
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

          return Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: RibbonPainter(
                  planets: planets,
                  centerLongitude: moon.longitude,
                ),
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

  /// Creates a [RibbonPainter].
  const RibbonPainter({required this.planets, required this.centerLongitude});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) {
      return;
    }

    const double visibleRange = 360.0;
    final double degreeWidth = size.width / visibleRange;
    final double startLon = (centerLongitude - 180.0);

    double getX(double lon) {
      double relativeLon = (lon - startLon) % 360.0;
      if (relativeLon < 0) {
        relativeLon += 360.0;
      }
      return relativeLon * degreeWidth;
    }

    for (var boundary in dornachBoundaries) {
      final paint = Paint()
        ..color = _getColorForElement(boundary.element).withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;

      double x1 = getX(boundary.startDegree);
      double x2 = getX(boundary.endDegree);

      if (x2 < x1) {
        canvas.drawRect(
          Rect.fromLTWH(x1, 0, size.width - x1, size.height),
          paint,
        );
        canvas.drawRect(Rect.fromLTWH(0, 0, x2, size.height), paint);
      } else {
        canvas.drawRect(Rect.fromLTWH(x1, 0, x2 - x1, size.height), paint);
      }

      double blockWidth = (boundary.endDegree - boundary.startDegree) % 360.0;
      if (blockWidth < 0) {
        blockWidth += 360.0;
      }

      if (blockWidth * degreeWidth > 15) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: boundary.name.substring(0, 3).toUpperCase(),
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 9,
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

      final paint = Paint()
        ..color = _getPlanetColor(planet.name)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 4, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: _getPlanetSymbol(planet.name),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamilyFallback: ['DejaVu Sans', 'Symbola', 'Noto Sans Symbols'],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - 22));
    }

    final refPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      refPaint,
    );
  }

  Color _getColorForElement(String element) {
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
        return Colors.yellow;
      case 'Moon':
        return Colors.white;
      case 'Mercury':
        return Colors.grey;
      case 'Venus':
        return Colors.green;
      case 'Mars':
        return Colors.red;
      case 'Jupiter':
        return Colors.orange;
      case 'Saturn':
        return Colors.brown;
      default:
        return Colors.white;
    }
  }

  String _getPlanetSymbol(String name) {
    switch (name) {
      case 'Sun':
        return '☀️';
      case 'Moon':
        return '🌙';
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
        return '?';
    }
  }

  @override
  bool shouldRepaint(covariant RibbonPainter oldDelegate) =>
      oldDelegate.centerLongitude != centerLongitude ||
      oldDelegate.planets != planets;
}
