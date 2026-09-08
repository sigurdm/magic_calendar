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

  /// Whether to render a framed border and container background around the icon.
  ///
  /// Defaults to `true`. When `false`, the icon artwork is rendered directly
  /// without a rectangular container border.
  final bool showBorder;

  /// Creates a [PlantingQualityIcon].
  const PlantingQualityIcon({
    super.key,
    required this.quality,
    this.size = 24,
    this.color,
    this.isGrayDay = false,
    this.isSpecial = false,
    this.showBorder = true,
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

    Color glowColor;
    if (isGrayDay) {
      glowColor = const Color(0xFF64748B);
    } else {
      switch (quality) {
        case PlantQuality.flower:
          glowColor = const Color(0xFFFBBF24);
          break;
        case PlantQuality.fruit:
          glowColor = const Color(0xFFF87171);
          break;
        case PlantQuality.leaf:
          glowColor = const Color(0xFF34D399);
          break;
        case PlantQuality.root:
          glowColor = const Color(0xFFF59E0B);
          break;
        case PlantQuality.none:
          glowColor = const Color(0xFF94A3B8);
          break;
      }
    }

    if (!showBorder) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Image.asset(
                assetPath,
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
            ),
            if (isSpecial)
              Positioned(
                top: -size * 0.08,
                right: -size * 0.08,
                child: Icon(
                  Icons.stars_rounded,
                  color: const Color(0xFFFFD700),
                  size: size * 0.35,
                ),
              ),
          ],
        ),
      );
    }

    final borderColor = isSpecial
        ? const Color(0xFFFFD700)
        : (size > 48
              ? glowColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.7));
    final borderWidth = isSpecial ? 2.5 : (size > 48 ? 2.0 : 1.5);
    final borderRadius = BorderRadius.circular(size > 48 ? 24 : 4);

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
              borderRadius: borderRadius,
              boxShadow: [
                if (isSpecial)
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                else if (size > 48)
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size > 48 ? 22 : 3),
              child: Image.asset(assetPath, fit: BoxFit.contain),
            ),
          ),
          if (isSpecial)
            Positioned(
              top: -size * 0.12,
              right: -size * 0.12,
              child: Icon(
                Icons.stars_rounded,
                color: const Color(0xFFFFD700),
                size: size * 0.4,
              ),
            ),
        ],
      ),
    );
  }
}
