import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/climate/climate_profile.dart';
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

  /// Fetches daily mean and minimum air temperature and precipitation for
  /// every day from 1 January [firstYear] to 31 December [lastYear] at
  /// [latitude], [longitude], from Open-Meteo's ERA5-based archive.
  ///
  /// Days are local calendar days of the location. The [firstYear] must not
  /// be after [lastYear].
  ///
  /// A 30-year request returns about 300 KiB and counts as roughly 235 calls
  /// against Open-Meteo's free-tier limit of 10,000 a day, so callers should
  /// cache the result. The data is licensed CC BY 4.0 and must be attributed
  /// to Open-Meteo.
  ///
  /// Throws a [TimeoutException] if there is no response within 30 seconds,
  /// an [http.ClientException] if the server answers with an error status,
  /// and a [FormatException] if the response cannot be parsed.
  Future<DailyClimateSeries> getDailyClimateSeries(
    double latitude,
    double longitude, {
    int firstYear = 1991,
    int lastYear = 2020,
  }) async {
    if (firstYear > lastYear) {
      throw ArgumentError.value(
        firstYear,
        'firstYear',
        'Must not be after lastYear ($lastYear)',
      );
    }
    final uri = Uri.https('archive-api.open-meteo.com', '/v1/archive', {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'start_date': '$firstYear-01-01',
      'end_date': '$lastYear-12-31',
      'daily': 'temperature_2m_mean,temperature_2m_min,precipitation_sum',
      'timezone': 'auto',
    });
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      final body = response.body;
      throw http.ClientException(
        'Open-Meteo climate request failed with status '
        '${response.statusCode}: '
        '${body.length > 200 ? '${body.substring(0, 200)}…' : body}',
        uri,
      );
    }
    return parseDailyClimateSeries(response.body);
  }

  /// Parses an Open-Meteo archive response holding the daily variables
  /// `temperature_2m_mean`, `temperature_2m_min` and `precipitation_sum`.
  ///
  /// Missing values stay null; [ClimateProfile.fromDailySeries] rejects them.
  ///
  /// Throws a [FormatException] if [body] is not such a response.
  static DailyClimateSeries parseDailyClimateSeries(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object');
    }
    final daily = decoded['daily'];
    if (daily is! Map<String, Object?>) {
      throw const FormatException('Response has no "daily" object');
    }

    List<Object?> column(String key) {
      final values = daily[key];
      if (values is! List<Object?>) {
        throw FormatException('Response has no daily "$key" values');
      }
      return values;
    }

    List<double?> numbers(String key) => [
      for (final value in column(key))
        switch (value) {
          null => null,
          num() => value.toDouble(),
          _ => throw FormatException('Non-numeric daily "$key" value', value),
        },
    ];

    final dates = <DateTime>[];
    for (final value in column('time')) {
      final date = value is String
          ? DateTime.tryParse('${value}T00:00:00Z')
          : null;
      if (date == null) throw FormatException('Invalid daily date', value);
      dates.add(date);
    }
    final meanTemperature = numbers('temperature_2m_mean');
    final minimumTemperature = numbers('temperature_2m_min');
    final precipitation = numbers('precipitation_sum');
    if (meanTemperature.length != dates.length ||
        minimumTemperature.length != dates.length ||
        precipitation.length != dates.length) {
      throw const FormatException('Daily columns have different lengths');
    }
    final elevation = decoded['elevation'];
    return DailyClimateSeries(
      dates: dates,
      meanTemperature: meanTemperature,
      minimumTemperature: minimumTemperature,
      precipitation: precipitation,
      elevation: elevation is num ? elevation.toDouble() : null,
    );
  }
}
