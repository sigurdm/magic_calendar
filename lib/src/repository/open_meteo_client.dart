import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models/weather_data_point.dart';

/// Client repository module for fetching historical weather data from Open-Meteo.
final class OpenMeteoClient {
  final http.Client _client;

  /// Creates an instance of [OpenMeteoClient].
  ///
  /// Optionally accepts a custom [client] for testing.
  OpenMeteoClient({http.Client? client}) : _client = client ?? http.Client();

  /// Closes the underlying HTTP client.
  void close() {
    _client.close();
  }

  /// Fetches historical weather data between [start] and [end] for coordinates [lat], [lon].
  ///
  /// Preconditions:
  /// - [lat] must be a valid latitude between -90.0 and 90.0.
  /// - [lon] must be a valid longitude between -180.0 and 180.0.
  /// - [start] must be before or equal to [end].
  ///
  /// Throws [TimeoutException] if the request times out after 10 seconds.
  /// Throws [Exception] if the network request fails with a non-200 status code.
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) async {
    final startStr = start.toUtc().toIso8601String().substring(0, 10);
    final endStr = end.toUtc().toIso8601String().substring(0, 10);

    final url = Uri.parse(
      'https://archive-api.open-meteo.com/v1/archive?latitude=$lat&longitude=$lon&start_date=$startStr&end_date=$endStr&hourly=temperature_2m,wind_speed_10m,wind_direction_10m,cloudcover,precipitation&windspeed_unit=ms&timezone=UTC',
    );

    final response = await _client
        .get(url)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final hourly = (data['hourly'] as Map<String, dynamic>?) ?? {};
      final times = (hourly['time'] as List?) ?? [];
      final temps = (hourly['temperature_2m'] as List?) ?? [];
      final winds = (hourly['wind_speed_10m'] as List?) ?? [];
      final windDirs = (hourly['wind_direction_10m'] as List?) ?? [];
      final clouds = (hourly['cloudcover'] as List?) ?? [];
      final precip = (hourly['precipitation'] as List?) ?? [];

      final List<WeatherDataPoint> results = [];
      for (int i = 0; i < times.length; i++) {
        final timeStr = times[i] as String?;
        if (timeStr == null) {
          continue;
        }
        final temp = i < temps.length ? (temps[i] as num?)?.toDouble() : null;
        final wind = i < winds.length
            ? (winds[i] as num?)?.toDouble() ?? 0.0
            : 0.0;
        final windDir = i < windDirs.length
            ? (windDirs[i] as num?)?.toDouble() ?? 0.0
            : 0.0;
        final cloud = i < clouds.length
            ? (clouds[i] as num?)?.toDouble() ?? 0.0
            : 0.0;
        final rain = i < precip.length
            ? (precip[i] as num?)?.toDouble() ?? 0.0
            : 0.0;

        final parsedTime = timeStr.endsWith('Z')
            ? DateTime.parse(timeStr)
            : DateTime.parse('${timeStr}Z');

        results.add(
          WeatherDataPoint(
            time: parsedTime,
            temperature: temp,
            windSpeed: wind,
            windDirection: windDir,
            cloudCover: cloud,
            precipitation: rain,
          ),
        );
      }
      return results;
    } else {
      throw Exception(
        'Failed to load historical weather data: ${response.statusCode}',
      );
    }
  }
}
