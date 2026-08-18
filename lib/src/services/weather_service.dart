import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../repository/open_meteo_client.dart';

export 'dmi_weather_service.dart';
export 'combined_weather_service.dart';

/// Represents a single weather data observation or forecast point.
final class WeatherDataPoint {
  /// Timestamp of the observation.
  final DateTime time;

  /// Air temperature in degrees Celsius.
  final double temperature;

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
    required this.temperature,
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
      temperature:
          (instantDetails?['air_temperature'] as num?)?.toDouble() ?? 0.0,
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
      'WeatherDataPoint(time: $time, temp: ${temperature.toStringAsFixed(1)}°C, '
      'wind: ${windSpeed.toStringAsFixed(1)}m/s @ ${windDirection.toStringAsFixed(0)}°, '
      'cloud: ${cloudCover.toStringAsFixed(0)}%, precip: ${precipitation.toStringAsFixed(2)}mm)';
}

/// Cached forecast item with associated retrieval timestamp.
final class _CachedForecast {
  final DateTime timestamp;
  final List<WeatherDataPoint> forecast;

  _CachedForecast({required this.timestamp, required this.forecast});
}

/// Abstract contract for fetching weather forecasts and historical data.
abstract class WeatherService {
  /// Fetches weather forecast for given coordinates [lat] and [lon].
  ///
  /// Preconditions:
  /// - [lat] must be a valid latitude between -90.0 and 90.0.
  /// - [lon] must be a valid longitude between -180.0 and 180.0.
  ///
  /// Throws [TimeoutException] if the request times out.
  /// Throws [Exception] if the upstream weather request fails.
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon);

  /// Fetches historical weather data between [start] and [end] for coordinates [lat] and [lon].
  ///
  /// Preconditions:
  /// - [lat] must be a valid latitude between -90.0 and 90.0.
  /// - [lon] must be a valid longitude between -180.0 and 180.0.
  /// - [start] must be before or equal to [end].
  ///
  /// Throws [TimeoutException] if the request times out.
  /// Throws [Exception] if the upstream weather request fails.
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  );
}

/// Weather service implementation connecting to Yr.no (MET Norway).
final class YrNoWeatherService implements WeatherService {
  /// User agent header identifying the application to MET Norway APIs.
  final String userAgent;

  /// Duration for which cached forecast data remains valid.
  final Duration cacheTtl;

  final http.Client _client;
  final OpenMeteoClient _openMeteoClient;
  final Map<String, _CachedForecast> _cache = {};

  /// Creates a [YrNoWeatherService] with the required [userAgent].
  ///
  /// Optionally accepts [client], [openMeteoClient], and [cacheTtl]
  /// (defaults to 1 hour).
  YrNoWeatherService({
    required this.userAgent,
    http.Client? client,
    OpenMeteoClient? openMeteoClient,
    this.cacheTtl = const Duration(hours: 1),
  }) : _client = client ?? http.Client(),
       _openMeteoClient = openMeteoClient ?? OpenMeteoClient(client: client);

  @override
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon) async {
    final formattedLat = lat.toStringAsFixed(4);
    final formattedLon = lon.toStringAsFixed(4);
    final cacheKey = '$formattedLat,$formattedLon';

    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < cacheTtl) {
      return cached.forecast;
    }

    final url = Uri.parse(
      'https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=$formattedLat&lon=$formattedLon',
    );

    final response = await _client
        .get(url, headers: {'User-Agent': userAgent})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final properties = data['properties'] as Map<String, dynamic>? ?? {};
      final timeseries = (properties['timeseries'] as List?) ?? [];
      final forecast = timeseries
          .map(
            (item) => WeatherDataPoint.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      _cache[cacheKey] = _CachedForecast(
        timestamp: DateTime.now(),
        forecast: forecast,
      );
      return forecast;
    } else {
      throw Exception('Failed to load weather data: ${response.statusCode}');
    }
  }

  @override
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) {
    return _openMeteoClient.getHistoricalData(lat, lon, start, end);
  }
}
