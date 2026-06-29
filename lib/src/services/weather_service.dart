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
  WeatherDataPoint({
    required this.time,
    required this.temperature,
    required this.windSpeed,
    required this.windDirection,
    required this.cloudCover,
    required this.precipitation,
  });

  /// Constructs a [WeatherDataPoint] from JSON representation.
  factory WeatherDataPoint.fromJson(Map<String, dynamic> json) {
    final instantDetails = json['data']['instant']['details'];
    final next1Hours = json['data']['next_1_hours'];
    final prec = next1Hours != null
        ? next1Hours['details']['precipitation_amount']?.toDouble() ?? 0.0
        : 0.0;

    return WeatherDataPoint(
      time: DateTime.parse(json['time']),
      temperature: instantDetails['air_temperature']?.toDouble() ?? 0.0,
      windSpeed: instantDetails['wind_speed']?.toDouble() ?? 0.0,
      windDirection: instantDetails['wind_from_direction']?.toDouble() ?? 0.0,
      cloudCover: instantDetails['cloud_area_fraction']?.toDouble() ?? 0.0,
      precipitation: prec,
    );
  }
}

/// Abstract contract for fetching weather forecasts and historical data.
abstract class WeatherService {
  /// Fetches weather forecast for given [lat] and [lon].
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon);

  /// Fetches historical weather data between [start] and [end] for [lat] and [lon].
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
  final Map<String, List<WeatherDataPoint>> _cache = {};
  final OpenMeteoClient _openMeteoClient = OpenMeteoClient();

  /// Creates a [YrNoWeatherService] with the required [userAgent].
  YrNoWeatherService({required this.userAgent});

  @override
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon) async {
    final cacheKey = '$lat,$lon';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final url = Uri.parse(
      'https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=$lat&lon=$lon',
    );

    final response = await http.get(url, headers: {'User-Agent': userAgent});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final timeseries = data['properties']['timeseries'] as List;
      final forecast = timeseries
          .map((item) => WeatherDataPoint.fromJson(item))
          .toList();
      _cache[cacheKey] = forecast;
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
