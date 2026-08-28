/// Info class for sunrise, sunset, and solar noon times.
final class SunriseSunsetInfo {
  /// Sunrise time, if applicable.
  final DateTime? sunrise;

  /// Sunset time, if applicable.
  final DateTime? sunset;

  /// Solar noon time.
  final DateTime noon;

  /// Creates [SunriseSunsetInfo].
  SunriseSunsetInfo({this.sunrise, this.sunset, required this.noon});
}

/// Represents position information for a planet.
final class PlanetInfo {
  /// Name of planet.
  final String name;

  /// Ecliptic longitude (0-360 degrees).
  final double longitude;

  /// Creates [PlanetInfo].
  const PlanetInfo({required this.name, required this.longitude});
}
