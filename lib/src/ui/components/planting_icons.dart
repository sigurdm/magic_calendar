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

  /// Creates a [PlantingQualityIcon].
  const PlantingQualityIcon({
    super.key,
    required this.quality,
    this.size = 24,
    this.color,
    this.isGrayDay = false,
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

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Image.asset(assetPath, fit: BoxFit.contain),
      ),
    );
  }
}
