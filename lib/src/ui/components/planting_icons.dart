import 'package:flutter/material.dart';
import '../../services/ephemeris_service.dart';

/// Widget rendering plant quality icon badges.
final class PlantingQualityIcon extends StatelessWidget {
  /// Plant quality.
  final PlantQuality quality;

  /// Size of icon.
  final double size;

  /// Optional color tint.
  final Color? color;

  /// Flag indicating if day is a Gray Day.
  final bool isGrayDay;

  /// Flag indicating if day is a Special Day (planetary trine).
  final bool isSpecial;

  /// Creates a [PlantingQualityIcon].
  const PlantingQualityIcon({
    super.key,
    required this.quality,
    this.size = 24,
    this.color,
    this.isGrayDay = false,
    this.isSpecial = false,
  });

  @override
  Widget build(BuildContext context) {
    String assetPath;
    if (isGrayDay) {
      assetPath = 'assets/icons/gray_day.png';
    } else {
      switch (quality) {
        case PlantQuality.root:
          assetPath = 'assets/icons/root.png';
          break;
        case PlantQuality.leaf:
          assetPath = 'assets/icons/leaf.png';
          break;
        case PlantQuality.flower:
          assetPath = 'assets/icons/flower.png';
          break;
        case PlantQuality.fruit:
          assetPath = 'assets/icons/fruit.png';
          break;
        case PlantQuality.none:
          assetPath = 'assets/icons/none.png';
          break;
      }
    }

    final borderColor = isSpecial
        ? const Color(0xFFFFD700)
        : Colors.white.withValues(alpha: 0.7);
    final borderWidth = isSpecial ? 2.5 : 1.5;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: borderWidth),
              borderRadius: BorderRadius.circular(4),
              boxShadow: isSpecial
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Image.asset(assetPath, fit: BoxFit.contain),
          ),
          if (isSpecial)
            Positioned(
              top: -size * 0.15,
              right: -size * 0.15,
              child: Icon(
                Icons.stars_rounded,
                color: const Color(0xFFFFD700),
                size: size * 0.45,
              ),
            ),
        ],
      ),
    );
  }
}
