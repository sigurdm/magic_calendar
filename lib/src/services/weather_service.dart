import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models/weather_data_point.dart';
import '../repository/open_meteo_client.dart';

export '../core/models/weather_data_point.dart';
export 'combined_weather_service.dart';
export 'dmi_weather_service.dart';

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

  /// Closes any underlying network clients and resources.
  void close() {}
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

  YrNoWeatherService._({
    required this.userAgent,
    required this._client,
    required this._openMeteoClient,
    required this.cacheTtl,
  });

  /// Creates a [YrNoWeatherService] with the required [userAgent].
  ///
  /// Optionally accepts [client], [openMeteoClient], and [cacheTtl]
  /// (defaults to 1 hour). If [client] is omitted, a single shared [http.Client]
  /// is created for both MET Norway and Open-Meteo requests.
  factory YrNoWeatherService({
    required String userAgent,
    http.Client? client,
    OpenMeteoClient? openMeteoClient,
    Duration cacheTtl = const Duration(hours: 1),
  }) {
    final effectiveClient = client ?? http.Client();
    return YrNoWeatherService._(
      userAgent: userAgent,
      client: effectiveClient,
      openMeteoClient:
          openMeteoClient ?? OpenMeteoClient(client: effectiveClient),
      cacheTtl: cacheTtl,
    );
  }

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

  @override
  void close() {
    _client.close();
    _openMeteoClient.close();
  }
}
