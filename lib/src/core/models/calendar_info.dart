import '../dornach_boundaries.dart';
import 'moon_phase_info.dart';
import 'planet_info.dart';
import 'plant_quality.dart';

/// Aggregated calendar information for a given timestamp.
final class CalendarInfo {
  /// Plant quality.
  final PlantQuality quality;

  /// True if Gray Day.
  final bool isGrayDay;

  /// True if Special Day (e.g. planetary trine aspect).
  final bool isSpecial;

  /// True if Moon is near Apogee (Ag).
  final bool isApogee;

  /// True if Moon is in opposition (180 deg) with Saturn.
  final bool isMoonSaturnOpposition;

  /// Message describing Gray Day condition or Special Day.
  final String message;

  /// Sap flow vector text.
  final String sapFlow;

  /// Vitality description text.
  final String vitality;

  /// Moon phase info.
  final MoonPhaseInfo moonPhase;

  /// List of planetary positions.
  final List<PlanetInfo> planets;

  /// Creates [CalendarInfo].
  CalendarInfo({
    required this.quality,
    required this.isGrayDay,
    this.isSpecial = false,
    this.isApogee = false,
    this.isMoonSaturnOpposition = false,
    required this.message,
    required this.sapFlow,
    required this.vitality,
    required this.moonPhase,
    required this.planets,
  });
}

/// Time interval quality entry.
final class CalendarInterval {
  /// Start time of interval.
  final DateTime start;

  /// End time of interval.
  final DateTime end;

  /// Plant quality.
  final PlantQuality quality;

  /// True if Gray Day.
  final bool isGrayDay;

  /// True if Special Day.
  final bool isSpecial;

  /// Message explaining quality or Gray Day.
  final String message;

  /// Creates [CalendarInterval].
  CalendarInterval({
    required this.start,
    required this.end,
    required this.quality,
    required this.isGrayDay,
    this.isSpecial = false,
    required this.message,
  });
}

/// Maps ecliptic [longitude] to [PlantQuality] based on constellation boundaries.
PlantQuality getQualityFromLongitude(
  double longitude, [
  List<ConstellationBoundary> boundaries = dornachBoundaries,
]) {
  double normLon = longitude % 360.0;
  if (normLon < 0) {
    normLon += 360.0;
  }
  for (var boundary in boundaries) {
    if (boundary.startDegree <= boundary.endDegree) {
      if (normLon >= boundary.startDegree && normLon < boundary.endDegree) {
        switch (boundary.element) {
          case 'Earth':
            return PlantQuality.root;
          case 'Water':
            return PlantQuality.leaf;
          case 'Air':
            return PlantQuality.flower;
          case 'Fire':
            return PlantQuality.fruit;
        }
      }
    } else {
      if (normLon >= boundary.startDegree || normLon < boundary.endDegree) {
        switch (boundary.element) {
          case 'Earth':
            return PlantQuality.root;
          case 'Water':
            return PlantQuality.leaf;
          case 'Air':
            return PlantQuality.flower;
          case 'Fire':
            return PlantQuality.fruit;
        }
      }
    }
  }
  return PlantQuality.none;
}
