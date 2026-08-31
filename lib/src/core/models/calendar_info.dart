import '../dornach_boundaries.dart';
import 'celestial_aspect.dart';
import 'diurnal_rhythm.dart';
import 'moon_phase_info.dart';
import 'planet_info.dart';
import 'plant_quality.dart';
import 'transition_envelope.dart';

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

  /// True if solar or lunar eclipse is active.
  final bool isEclipse;

  /// Active planetary aspects at this timestamp.
  final List<PlanetaryAspect> activeAspects;

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

  /// Diurnal Earth rhythm info (Earth's daily breathing phase).
  final DiurnalRhythmInfo? diurnalRhythm;

  /// Transition envelope info (cusp blending with adjacent constellation).
  final TransitionEnvelope? transitionEnvelope;

  /// Creates [CalendarInfo].
  CalendarInfo({
    required this.quality,
    required this.isGrayDay,
    this.isSpecial = false,
    this.isApogee = false,
    this.isMoonSaturnOpposition = false,
    this.isEclipse = false,
    this.activeAspects = const [],
    required this.message,
    required this.sapFlow,
    required this.vitality,
    required this.moonPhase,
    required this.planets,
    this.diurnalRhythm,
    this.transitionEnvelope,
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

  /// Transition envelope info (cusp blending with adjacent constellation).
  final TransitionEnvelope? transitionEnvelope;

  /// Creates [CalendarInterval].
  CalendarInterval({
    required this.start,
    required this.end,
    required this.quality,
    required this.isGrayDay,
    this.isSpecial = false,
    required this.message,
    this.transitionEnvelope,
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
