import 'package:flutter/material.dart';
import 'package:magic_calendar/src/core/models/models.dart';
import 'package:magic_calendar/src/ui/components/plant_quality_card.dart';

/// Example showing how to render [PlantQualityCard] with Anthroposophic architecture.
Widget buildCardExample() {
  final sampleInfo = CalendarInfo(
    quality: PlantQuality.leaf,
    isGrayDay: false,
    message: 'Leaf Day',
    sapFlow: 'Ascending: Sap rising into leaves',
    vitality: 'Waxing Gibbous',
    moonPhase: MoonPhaseInfo(
      illuminatedFraction: 0.75,
      isWaxing: true,
      phaseAngle: 120,
    ),
    planets: [],
  );

  return PlantQualityCard(info: sampleInfo);
}
