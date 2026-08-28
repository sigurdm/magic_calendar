import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/models.dart';
import 'planting_icons.dart';

/// Card presenting the predominant agricultural plant quality for the selected date.
final class PlantQualityCard extends StatelessWidget {
  /// Calculated calendar info.
  final CalendarInfo info;

  /// Creates a [PlantQualityCard].
  const PlantQualityCard({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    String title = 'Unknown';
    String desc = 'Select a date to see quality.';

    if (info.isGrayDay) {
      title = 'Gray Day';
      desc = info.message;
    } else if (info.message.startsWith('Special')) {
      title = info.message.split(':').first;
      switch (info.quality) {
        case PlantQuality.flower:
          desc =
              'Exceptional cosmic energy for flowering plants, medicinal herbs & essential oils.';
          break;
        case PlantQuality.fruit:
          desc =
              'Exceptional warmth energy for seed formation, fruit ripening & long storage.';
          break;
        case PlantQuality.leaf:
          desc =
              'Exceptional moisture impulse for lush leafy greens, spinach & herbs.';
          break;
        case PlantQuality.root:
          desc =
              'Exceptional gravitational earth focus for carrots, beets & root vegetables.';
          break;
        default:
          desc =
              'Special planetary alignment boosting elemental plant development.';
          break;
      }
    } else {
      switch (info.quality) {
        case PlantQuality.root:
          title = 'Root Day';
          desc = 'Good for planting carrots, beets, potatoes, onions.';
          break;
        case PlantQuality.leaf:
          title = 'Leaf Day';
          desc = 'Good for planting lettuce, spinach, herbs, cabbage.';
          break;
        case PlantQuality.flower:
          title = 'Flower Day';
          desc = 'Good for planting broccoli, cauliflower, cut flowers.';
          break;
        case PlantQuality.fruit:
          title = 'Fruit Day';
          desc = 'Good for planting tomatoes, beans, grains, fruit trees.';
          break;
        case PlantQuality.none:
          title = 'No Specific Quality';
          desc = 'Neutral day for planting.';
          break;
      }
    }

    String elementName = 'NEUTRAL';
    IconData elementIcon = Icons.spa_outlined;
    Color accentColor = const Color(0xFF94A3B8);

    if (info.isGrayDay) {
      elementName = 'REST PERIOD';
      elementIcon = Icons.block;
      accentColor = const Color(0xFF94A3B8);
    } else {
      switch (info.quality) {
        case PlantQuality.root:
          elementName = 'EARTH ELEMENT';
          elementIcon = Icons.terrain;
          accentColor = const Color(0xFFF59E0B);
          break;
        case PlantQuality.leaf:
          elementName = 'WATER ELEMENT';
          elementIcon = Icons.water_drop_outlined;
          accentColor = const Color(0xFF34D399);
          break;
        case PlantQuality.flower:
          elementName = 'LIGHT & AIR ELEMENT';
          elementIcon = Icons.air;
          accentColor = const Color(0xFFFBBF24);
          break;
        case PlantQuality.fruit:
          elementName = 'FIRE & WARMTH ELEMENT';
          elementIcon = Icons.local_fire_department_outlined;
          accentColor = const Color(0xFFF87171);
          break;
        case PlantQuality.none:
          elementName = 'NEUTRAL ELEMENT';
          elementIcon = Icons.spa_outlined;
          accentColor = const Color(0xFF94A3B8);
          break;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(elementIcon, size: 14, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      elementName,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PlantingQualityIcon(
                quality: info.quality,
                isGrayDay: info.isGrayDay,
                isSpecial: info.isSpecial,
                size: 180,
                color: Colors.white,
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Text(
                  desc,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
