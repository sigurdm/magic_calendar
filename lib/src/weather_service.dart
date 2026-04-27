import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherDataPoint {
  final DateTime time;
  final double temperature; // Celsius
  final double windSpeed; // m/s
  final double windDirection; // degrees
  final double cloudCover; // percentage 0-100
  final double precipitation; // mm

  WeatherDataPoint({
    required this.time,
    required this.temperature,
    required this.windSpeed,
    required this.windDirection,
    required this.cloudCover,
    required this.precipitation,
  });

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

abstract class WeatherService {
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon);
}

class YrNoWeatherService implements WeatherService {
  final String userAgent;
  final Map<String, List<WeatherDataPoint>> _cache = {};

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
}
