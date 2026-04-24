import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'ephemeris_service.dart';

class PlantingQualityIcon extends StatelessWidget {
  final PlantQuality quality;
  final double size;
  final Color? color;
  final bool isGrayDay;

  const PlantingQualityIcon({
    super.key,
    required this.quality,
    this.size = 24,
    this.color,
    this.isGrayDay = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isGrayDay) {
      return Image.asset(
        'assets/icons/none.png',
        width: size,
        height: size,
        color: color,
      );
    }

    String assetName;
    switch (quality) {
      case PlantQuality.root:
        assetName = 'root.png';
        break;
      case PlantQuality.leaf:
        assetName = 'leaf.png';
        break;
      case PlantQuality.flower:
        assetName = 'flower.png';
        break;
      case PlantQuality.fruit:
        assetName = 'fruit.png';
        break;
      case PlantQuality.none:
        assetName = 'none.png';
        break;
    }

    return Image.asset(
      'assets/icons/$assetName',
      width: size,
      height: size,
      color: color,
    );
  }
}

class PlantingPainter extends CustomPainter {
  final PlantQuality quality;
  final bool isGrayDay;
  final Color? color;

  PlantingPainter({required this.quality, required this.isGrayDay, this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (isGrayDay) {
      _drawGrayDay(canvas, size, color ?? const Color(0xFFD32F2F));
      return;
    }

    switch (quality) {
      case PlantQuality.root:
        _drawRoot(canvas, size, color ?? const Color(0xFF8D6E63));
        break;
      case PlantQuality.leaf:
        _drawLeaf(canvas, size, color ?? const Color(0xFF66BB6A));
        break;
      case PlantQuality.flower:
        _drawFlower(canvas, size, color ?? const Color(0xFFAB47BC));
        break;
      case PlantQuality.fruit:
        _drawFruit(canvas, size, color ?? const Color(0xFFFFA726));
        break;
      case PlantQuality.none:
        // Draw nothing or a simple placeholder
        break;
    }
  }

  void _drawRoot(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.2);
    path.quadraticBezierTo(
      size.width * 0.5,
      0,
      size.width * 0.8,
      size.height * 0.2,
    );
    path.lineTo(size.width * 0.5, size.height);
    path.close();
    canvas.drawPath(path, paint);

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.8),
      Offset(size.width * 0.3, size.height * 0.9),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.6),
      Offset(size.width * 0.7, size.height * 0.7),
      linePaint,
    );
  }

  void _drawLeaf(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.5, size.height);
    path.quadraticBezierTo(0, size.height * 0.5, size.width * 0.4, 0);
    path.quadraticBezierTo(
      size.width * 0.6,
      size.height * 0.4,
      size.width * 0.5,
      size.height,
    );
    canvas.drawPath(path, paint);

    final path2 = Path();
    path2.moveTo(size.width * 0.5, size.height * 0.8);
    path2.quadraticBezierTo(
      size.width,
      size.height * 0.3,
      size.width * 0.7,
      size.height * 0.1,
    );
    path2.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.4,
      size.width * 0.5,
      size.height * 0.8,
    );
    paint.color = color.withValues(alpha: 0.8);
    canvas.drawPath(path2, paint);
  }

  void _drawFlower(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final petalRadius = size.width * 0.25;

    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - math.pi / 2;
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * petalRadius,
          center.dy + math.sin(angle) * petalRadius,
        ),
        petalRadius,
        paint,
      );
    }

    canvas.drawCircle(
      center,
      size.width * 0.15,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  void _drawFruit(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.6),
      size.width * 0.4,
      paint,
    );

    final stemPaint = Paint()
      ..color = Colors.brown
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.25),
      Offset(size.width * 0.55, size.height * 0.1),
      stemPaint,
    );

    final leafPaint = Paint()..color = Colors.green;
    final leafPath = Path();
    leafPath.moveTo(size.width * 0.5, size.height * 0.2);
    leafPath.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.05,
      size.width * 0.8,
      size.height * 0.2,
    );
    leafPath.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.35,
      size.width * 0.5,
      size.height * 0.2,
    );
    canvas.drawPath(leafPath, leafPaint);
  }

  void _drawGrayDay(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    canvas.drawCircle(center, radius, paint);

    canvas.drawLine(
      Offset(center.dx - radius * 0.7, center.dy - radius * 0.7),
      Offset(center.dx + radius * 0.7, center.dy + radius * 0.7),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
