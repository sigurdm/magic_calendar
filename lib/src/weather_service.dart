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
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  );
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

  @override
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) async {
    final clientId = '371091f7-14c3-4d25-9725-4da6eb9d5b25';
    final credentials = base64Encode(utf8.encode('$clientId:'));

    final sourcesUrl = Uri.parse(
      'https://frost.met.no/sources/v0.jsonld?geometry=point($lon $lat)',
    );
    final sourcesResponse = await http.get(
      sourcesUrl,
      headers: {'Authorization': 'Basic $credentials'},
    );

    String stationId = '';
    if (sourcesResponse.statusCode == 200) {
      final data = jsonDecode(sourcesResponse.body);
      final sources = data['data'] as List;
      if (sources.isNotEmpty) {
        stationId = sources.first['id'];
      }
    }

    if (stationId.isEmpty) {
      throw Exception('No weather station found near this location.');
    }

    final startStr = start.toUtc().toIso8601String();
    final endStr = end.toUtc().toIso8601String();
    final obsUrl = Uri.parse(
      'https://frost.met.no/observations/v0.jsonld?sources=$stationId&referencetime=$startStr/$endStr&elements=air_temperature,wind_speed,wind_from_direction,cloud_area_fraction',
    );

    final obsResponse = await http.get(
      obsUrl,
      headers: {'Authorization': 'Basic $credentials'},
    );

    if (obsResponse.statusCode == 200) {
      final data = jsonDecode(obsResponse.body);
      final obsData = data['data'] as List;

      final List<WeatherDataPoint> results = [];
      for (var point in obsData) {
        final time = DateTime.parse(point['referenceTime']);
        final observations = point['observations'] as List;

        double temp = 0.0;
        double windSpeed = 0.0;
        double windDir = 0.0;
        double clouds = 0.0;

        for (var obs in observations) {
          final element = obs['elementId'];
          final value = obs['value']?.toDouble() ?? 0.0;
          switch (element) {
            case 'air_temperature':
              temp = value;
              break;
            case 'wind_speed':
              windSpeed = value;
              break;
            case 'wind_from_direction':
              windDir = value;
              break;
            case 'cloud_area_fraction':
              clouds = value;
              break;
          }
        }

        results.add(
          WeatherDataPoint(
            time: time,
            temperature: temp,
            windSpeed: windSpeed,
            windDirection: windDir,
            cloudCover: clouds,
            precipitation: 0.0,
          ),
        );
      }
      return results;
    } else {
      throw Exception(
        'Failed to load historical weather data: ${obsResponse.statusCode}',
      );
    }
  }
}
