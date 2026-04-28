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
    // 1. Find a station near the location
    final bbox = '${lon - 0.5},${lat - 0.5},${lon + 0.5},${lat + 0.5}';
    final stationsUrl = Uri.parse(
      'https://opendataapi.dmi.dk/v2/metObs/collections/station/items?bbox=$bbox&status=Active&type=Synop',
    );

    final stationsResponse = await http.get(stationsUrl);

    String stationId = '';
    if (stationsResponse.statusCode == 200) {
      final data = jsonDecode(stationsResponse.body);
      final features = data['features'] as List;
      if (features.isNotEmpty) {
        // Pick the first station
        stationId = features.first['properties']['stationId'];
      }
    }

    if (stationId.isEmpty) {
      throw Exception(
        'No active DMI weather station found near this location.',
      );
    }

    // 2. Fetch observations for that station
    final startStr = start.toUtc().toIso8601String();
    final endStr = end.toUtc().toIso8601String();
    final obsUrl = Uri.parse(
      'https://opendataapi.dmi.dk/v2/metObs/collections/observation/items?stationId=$stationId&datetime=$startStr/$endStr&limit=20000',
    );

    final obsResponse = await http.get(obsUrl);

    if (obsResponse.statusCode == 200) {
      final data = jsonDecode(obsResponse.body);
      final features = data['features'] as List;

      // Map observations to WeatherDataPoint
      // Since observations are separate features for each parameter,
      // we need to group them by time.

      final Map<DateTime, Map<String, double>> groupedData = {};

      for (var feature in features) {
        final props = feature['properties'];
        final time = DateTime.parse(props['observed']);
        // Round to nearest 10 minutes
        final roundedTime = DateTime.utc(
          time.year,
          time.month,
          time.day,
          time.hour,
          (time.minute / 10).round() * 10,
        );
        final paramId = props['parameterId'];
        final value = props['value']?.toDouble() ?? 0.0;

        if (!groupedData.containsKey(roundedTime)) {
          groupedData[roundedTime] = {};
        }
        groupedData[roundedTime]![paramId] = value;
      }

      final List<WeatherDataPoint> results = [];

      groupedData.forEach((time, params) {
        results.add(
          WeatherDataPoint(
            time: time,
            temperature: params['temp_dry'] ?? 0.0,
            windSpeed: params['wind_speed'] ?? 0.0,
            windDirection: params['wind_dir'] ?? 0.0,
            cloudCover: params['cloud_cover'] ?? 0.0,
            precipitation: params['precip_past1h'] ?? 0.0,
          ),
        );
      });

      return results;
    } else {
      throw Exception(
        'Failed to load historical weather data from DMI: ${obsResponse.statusCode}',
      );
    }
  }
}
