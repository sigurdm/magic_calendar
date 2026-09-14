import 'dart:async';

import 'calendar_info.dart';
import 'celestial_aspect.dart';
import 'moon_phase_info.dart';
import 'planet_info.dart';

/// Abstract contract for ephemeris services computing astronomical data.
abstract mixin class EphemerisService {
  /// Obtains moon ecliptic longitude at [time].
  double getMoonLongitude(DateTime time);

  /// True if Moon is near ascending or descending node at [time].
  bool isNearNode(DateTime time);

  /// True if Moon is near perigee at [time].
  bool isNearPerigee(DateTime time);

  /// True if Moon is near apogee at [time].
  bool isNearApogee(DateTime time);

  /// True if Moon is in opposition with Saturn.
  bool isMoonSaturnOpposition(DateTime time);

  /// True if Moon is at 90 deg square to lunar nodes.
  bool isMoonSquareNode(DateTime time) => false;

  /// Returns illuminated fraction and phase info at [time].
  MoonPhaseInfo getMoonPhase(DateTime time);

  /// Returns topocentric declination of the Moon at [time].
  double getMoonDeclination(DateTime time);

  /// Returns planetary ecliptic positions at [time].
  List<PlanetInfo> getPlanets(DateTime time) => const [];

  /// Returns time intervals of plant quality across [start] and [end].
  FutureOr<List<CalendarInterval>> getIntervals(DateTime start, DateTime end);

  /// Calculates sunrise, sunset and solar noon times for date and coordinates.
  SunriseSunsetInfo getSunriseSunset(DateTime date, double lat, double lon);

  /// Updates topocentric observer geographical coordinates.
  void setObserverLocation(
    double latitude,
    double longitude, [
    double altitude = 0.0,
  ]) {}

  /// Returns active planetary aspects at [time].
  List<PlanetaryAspect> getAspects(DateTime time) => const [];

  /// True if Moon or Sun is within an eclipse blackout window (±12 hours).
  bool isNearEclipse(DateTime time) => false;

  /// Disposes any resources held by this ephemeris service.
  void dispose() {}
}
