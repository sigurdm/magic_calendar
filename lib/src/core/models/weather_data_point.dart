/// Represents a single weather data observation or forecast point.
final class WeatherDataPoint {
  /// Timestamp of the observation.
  final DateTime time;

  /// Air temperature in degrees Celsius (null if unavailable).
  final double? temperature;

  /// Wind speed in meters per second.
  final double windSpeed;

  /// Wind direction in degrees (0-360).
  final double windDirection;

  /// Cloud cover percentage (0-100).
  final double cloudCover;

  /// Precipitation amount in millimeters.
  final double precipitation;

  /// Creates a [WeatherDataPoint].
  const WeatherDataPoint({
    required this.time,
    this.temperature,
    required this.windSpeed,
    required this.windDirection,
    required this.cloudCover,
    required this.precipitation,
  });

  /// Constructs a [WeatherDataPoint] from JSON representation.
  ///
  /// Extracts instantaneous metrics (temperature, wind, cloud cover) and
  /// precipitation. Precipitation is parsed from `next_1_hours` if available,
  /// falling back to `next_6_hours` (divided by 6) or defaulting to 0.0.
  ///
  /// It is an error if [json] does not contain a valid parseable `time` field.
  factory WeatherDataPoint.fromJson(Map<String, dynamic> json) {
    final timeRaw = json['time'];
    if (timeRaw == null) {
      throw ArgumentError.notNull("json['time']");
    }

    final data = json['data'] as Map<String, dynamic>?;
    final instant = data?['instant'] as Map<String, dynamic>?;
    final instantDetails = instant?['details'] as Map<String, dynamic>?;

    final next1Hours = data?['next_1_hours'] as Map<String, dynamic>?;
    final next6Hours = data?['next_6_hours'] as Map<String, dynamic>?;

    double prec = 0.0;
    if (next1Hours != null) {
      final details = next1Hours['details'] as Map<String, dynamic>?;
      prec = (details?['precipitation_amount'] as num?)?.toDouble() ?? 0.0;
    } else if (next6Hours != null) {
      final details = next6Hours['details'] as Map<String, dynamic>?;
      final amount = (details?['precipitation_amount'] as num?)?.toDouble();
      prec = amount != null ? amount / 6.0 : 0.0;
    }

    return WeatherDataPoint(
      time: DateTime.parse(timeRaw as String),
      temperature: (instantDetails?['air_temperature'] as num?)?.toDouble(),
      windSpeed: (instantDetails?['wind_speed'] as num?)?.toDouble() ?? 0.0,
      windDirection:
          (instantDetails?['wind_from_direction'] as num?)?.toDouble() ?? 0.0,
      cloudCover:
          (instantDetails?['cloud_area_fraction'] as num?)?.toDouble() ?? 0.0,
      precipitation: prec,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherDataPoint &&
          runtimeType == other.runtimeType &&
          time == other.time &&
          temperature == other.temperature &&
          windSpeed == other.windSpeed &&
          windDirection == other.windDirection &&
          cloudCover == other.cloudCover &&
          precipitation == other.precipitation;

  @override
  int get hashCode => Object.hash(
    time,
    temperature,
    windSpeed,
    windDirection,
    cloudCover,
    precipitation,
  );

  @override
  String toString() =>
      'WeatherDataPoint(time: $time, temp: ${temperature != null ? "${temperature!.toStringAsFixed(1)}°C" : "null"}, '
      'wind: ${windSpeed.toStringAsFixed(1)}m/s @ ${windDirection.toStringAsFixed(0)}°, '
      'cloud: ${cloudCover.toStringAsFixed(0)}%, precip: ${precipitation.toStringAsFixed(2)}mm)';
}
