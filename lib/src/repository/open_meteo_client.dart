import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/weather_service.dart';

/// Client repository module for fetching historical weather data from Open-Meteo.
final class OpenMeteoClient {
  final http.Client _client;

  /// Creates an instance of [OpenMeteoClient].
  OpenMeteoClient({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches historical weather data between [start] and [end] for [lat], [lon].
  ///
  /// Throws an [Exception] if the network request fails with a non-200 status code.
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) async {
    final startStr = start.toUtc().toIso8601String().substring(0, 10);
    final endStr = end.toUtc().toIso8601String().substring(0, 10);

    final url = Uri.parse(
      'https://archive-api.open-meteo.com/v1/archive?latitude=$lat&longitude=$lon&start_date=$startStr&end_date=$endStr&hourly=temperature_2m,wind_speed_10m,wind_direction_10m,cloudcover,precipitation',
    );

    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final hourly = data['hourly'];
      final times = hourly['time'] as List;
      final temps = hourly['temperature_2m'] as List;
      final winds = hourly['wind_speed_10m'] as List;
      final windDirs = hourly['wind_direction_10m'] as List;
      final clouds = hourly['cloudcover'] as List;
      final precip = hourly['precipitation'] as List;

      final List<WeatherDataPoint> results = [];
      for (int i = 0; i < times.length; i++) {
        if (temps[i] == null) {
          continue;
        }
        results.add(
          WeatherDataPoint(
            time: DateTime.parse(times[i]),
            temperature: temps[i].toDouble(),
            windSpeed: winds[i].toDouble(),
            windDirection: windDirs[i].toDouble(),
            cloudCover: clouds[i].toDouble(),
            precipitation: precip[i].toDouble(),
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
