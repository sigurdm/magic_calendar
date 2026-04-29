import 'dart:convert';
import 'package:http/http.dart' as http;

import 'weather_service.dart';

/// A weather service that fetches historical data from the DMI Open Data API.
final class DmiWeatherService implements WeatherService {
  @override
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon) async {
    // DMI Open Data also has forecast APIs (EDR and STAC), but to keep it simple,
    // we might still rely on Yr.no for forecasts or implement it later.
    // For now, return empty list or throw not implemented.
    // Let's throw to be explicit.
    throw UnimplementedError(
      'getForecast not implemented in DmiWeatherService. Use YrNoWeatherService for forecasts.',
    );
  }

  @override
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) async {
    // Use Open-Meteo Archive API for reliable and compact historical data.
    // Open-Meteo uses DMI HARMONIE models for Denmark, so this is still DMI data,
    // but pre-aggregated to hourly intervals, avoiding the 300,000+ item limit 
    // and 50MB+ JSON payloads of the raw DMI API.
    final startStr = start.toUtc().toIso8601String().substring(0, 10);
    final endStr = end.toUtc().toIso8601String().substring(0, 10);

    final url = Uri.parse(
      'https://archive-api.open-meteo.com/v1/archive?latitude=$lat&longitude=$lon&start_date=$startStr&end_date=$endStr&hourly=temperature_2m,wind_speed_10m,wind_direction_10m,cloudcover,precipitation',
    );

    final response = await http.get(url);

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
        if (temps[i] == null) continue; // Skip missing data
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
