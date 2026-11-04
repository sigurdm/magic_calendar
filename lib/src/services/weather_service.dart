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

  static const int _maxCacheEntries = 32;

  final http.Client _client;
  final OpenMeteoClient _openMeteoClient;
  final Map<String, _CachedForecast> _cache = {};
  final Map<String, Future<List<WeatherDataPoint>>> _inFlight = {};

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

  static void _validateCoordinates(double lat, double lon) {
    if (!lat.isFinite || lat < -90.0 || lat > 90.0) {
      throw ArgumentError.value(
        lat,
        'lat',
        'Must be a finite latitude between -90.0 and 90.0',
      );
    }
    if (!lon.isFinite || lon < -180.0 || lon > 180.0) {
      throw ArgumentError.value(
        lon,
        'lon',
        'Must be a finite longitude between -180.0 and 180.0',
      );
    }
  }

  @override
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon) {
    _validateCoordinates(lat, lon);
    final formattedLat = lat.toStringAsFixed(4);
    final formattedLon = lon.toStringAsFixed(4);
    final cacheKey = '$formattedLat,$formattedLon';

    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < cacheTtl) {
      return Future<List<WeatherDataPoint>>.value(cached.forecast);
    }

    if (_inFlight[cacheKey] case final active?) {
      return active;
    }

    final future = _fetchForecast(formattedLat, formattedLon, cacheKey)
        .whenComplete(() {
          _inFlight.remove(cacheKey);
        });
    _inFlight[cacheKey] = future;
    return future;
  }

  Future<List<WeatherDataPoint>> _fetchForecast(
    String formattedLat,
    String formattedLon,
    String cacheKey,
  ) async {
    final url = Uri.parse(
      'https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=$formattedLat&lon=$formattedLon',
    );

    const isWeb = bool.fromEnvironment('dart.library.js_interop');
    final response = await _client
        .get(url, headers: isWeb ? null : {'User-Agent': userAgent})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Expected a JSON object from MET Norway');
      }
      final properties = decoded['properties'];
      if (properties is! Map) {
        throw const FormatException(
          'Expected a "properties" object in MET Norway response',
        );
      }
      final timeseries = properties['timeseries'];
      if (timeseries is! List) {
        throw const FormatException(
          'Expected a "timeseries" list in MET Norway response',
        );
      }
      final forecast = List<WeatherDataPoint>.unmodifiable([
        for (final item in timeseries)
          if (item is Map<String, dynamic>)
            WeatherDataPoint.fromJson(item)
          else if (item is Map)
            WeatherDataPoint.fromJson(Map<String, dynamic>.from(item))
          else
            throw FormatException('Invalid timeseries entry', item),
      ]);
      if (_cache.length >= _maxCacheEntries && !_cache.containsKey(cacheKey)) {
        _cache.remove(_cache.keys.first);
      }
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
    _validateCoordinates(lat, lon);
    if (start.isAfter(end)) {
      throw ArgumentError.value(start, 'start', 'Must not be after end ($end)');
    }
    return _openMeteoClient.getHistoricalData(lat, lon, start, end);
  }

  @override
  void close() {
    _cache.clear();
    _inFlight.clear();
    _client.close();
    _openMeteoClient.close();
  }
}
