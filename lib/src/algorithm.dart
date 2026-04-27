import 'ephemeris_service.dart';
import 'dornach_boundaries.dart';

CalendarInfo getCalendarInfo(
  DateTime time,
  EphemerisService ephemeris, {
  bool includePlanets = false,
  List<ConstellationBoundary> boundaries = dornachBoundaries,
}) {
  // 1. Coordinate Calculation
  double moonLongitude;
  try {
    moonLongitude = ephemeris.getMoonLongitude(time);
  } catch (e) {
    return CalendarInfo(
      quality: PlantQuality.none,
      isGrayDay: false,
      message: 'Error calculating planetary positions: $e',
      sapFlow: '',
      vitality: '',
      moonPhase: MoonPhaseInfo(
        illuminatedFraction: 0,
        isWaxing: false,
        phaseAngle: 0,
      ),
      planets: [],
    );
  }

  // 2. Dashed Line Check (Gray Day)
  // TODO: Implement checks for nodes, perigee, squares.
  bool isNearNode = ephemeris.isNearNode(time);
  bool isNearPerigee = ephemeris.isNearPerigee(time);
  bool isGrayDay = isNearNode || isNearPerigee;
  String message = '';

  if (isNearNode) {
    message = 'Gray Day: Near Lunar Node.';
  } else if (isNearPerigee) {
    message = 'Gray Day: Near Lunar Perigee.';
  }

  if (isGrayDay) {
    final moonPhase = ephemeris.getMoonPhase(time);
    return CalendarInfo(
      quality: PlantQuality.none,
      isGrayDay: true,
      message: message,
      sapFlow: '',
      vitality: '',
      moonPhase: moonPhase,
      planets: includePlanets ? ephemeris.getPlanets(time) : [],
    );
  }

  // 3. Trine Search
  // TODO: Implement trine checks.
  PlantQuality trineQuality = PlantQuality.none;

  // 4. Baseline Sidereal Assignment
  PlantQuality quality = PlantQuality.none;
  if (trineQuality == PlantQuality.none) {
    quality = getQualityFromLongitude(moonLongitude, boundaries);
  } else {
    quality = trineQuality;
  }

  // 5. Distance Modification
  // TODO: Check for apogee and override to Flower if needed.

  // 6. Sap Flow Vector
  String sapFlow = 'Ascending: Sap rises; good for harvesting fruit/cuttings.';
  if (includePlanets) {
    double dec1 = ephemeris.getMoonDeclination(time);
    double dec2 = ephemeris.getMoonDeclination(
      time.add(const Duration(hours: 1)),
    );
    sapFlow = dec2 > dec1
        ? 'Ascending: Sap rises; good for harvesting fruit/cuttings.'
        : "Descending: Sap recedes; 'transplanting time' for root development.";
  }

  // 7. Vitality Index
  final moonPhase = ephemeris.getMoonPhase(time);
  String vitality = moonPhase.name;
  if (moonPhase.isWaxing) {
    vitality += ' (Increasing moisture/vitality)';
  } else {
    vitality += ' (Decreasing moisture; good for storage)';
  }

  // 8. Planets
  final planets = includePlanets ? ephemeris.getPlanets(time) : <PlanetInfo>[];

  return CalendarInfo(
    quality: quality,
    isGrayDay: false,
    message: message,
    sapFlow: sapFlow,
    vitality: vitality,
    moonPhase: moonPhase,
    planets: planets,
  );
}
