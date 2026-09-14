import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:magic_calendar/src/repository/open_meteo_client.dart';
import 'package:magic_calendar/src/services/weather_service.dart';
import 'package:magic_calendar/src/ui/painters/infinite_timeline_painter.dart';
import 'package:magic_calendar/src/ui/views/time_scroll_view.dart';

import 'support/fakes.dart';

void main() {
  group('WeatherDataPoint Model', () {
    test('equality and hashCode work as expected', () {
      final t = DateTime.utc(2026, 6, 1, 12, 0);
      final point1 = WeatherDataPoint(
        time: t,
        temperature: 18.5,
        windSpeed: 4.2,
        windDirection: 120.0,
        cloudCover: 30.0,
        precipitation: 1.5,
      );
      final point2 = WeatherDataPoint(
        time: t,
        temperature: 18.5,
        windSpeed: 4.2,
        windDirection: 120.0,
        cloudCover: 30.0,
        precipitation: 1.5,
      );
      final point3 = WeatherDataPoint(
        time: t,
        temperature: 19.0, // Different
        windSpeed: 4.2,
        windDirection: 120.0,
        cloudCover: 30.0,
        precipitation: 1.5,
      );

      expect(point1, equals(point2));
      expect(point1.hashCode, equals(point2.hashCode));
      expect(point1, isNot(equals(point3)));
    });

    test('toString formatting contains all primary fields', () {
      final point = WeatherDataPoint(
        time: DateTime.utc(2026, 6, 1, 12, 0),
        temperature: 18.5,
        windSpeed: 4.2,
        windDirection: 120.0,
        cloudCover: 30.0,
        precipitation: 1.5,
      );

      final str = point.toString();
      expect(str, contains('18.5°C'));
      expect(str, contains('4.2m/s'));
      expect(str, contains('120°'));
      expect(str, contains('30%'));
      expect(str, contains('1.50mm'));
    });

    test('toString formatting handles null temperature gracefully', () {
      final point = WeatherDataPoint(
        time: DateTime.utc(2026, 6, 1, 12, 0),
        temperature: null,
        windSpeed: 4.2,
        windDirection: 120.0,
        cloudCover: 30.0,
        precipitation: 1.5,
      );

      final str = point.toString();
      expect(str, contains('temp: null'));
    });

    test('fromJson parses next_1_hours precipitation when available', () {
      final json = {
        'time': '2026-06-01T12:00:00Z',
        'data': {
          'instant': {
            'details': {
              'air_temperature': 15.2,
              'wind_speed': 3.1,
              'wind_from_direction': 240.0,
              'cloud_area_fraction': 75.0,
            },
          },
          'next_1_hours': {
            'details': {'precipitation_amount': 2.4},
          },
          'next_6_hours': {
            'details': {'precipitation_amount': 6.0},
          },
        },
      };

      final point = WeatherDataPoint.fromJson(json);
      expect(point.time, equals(DateTime.parse('2026-06-01T12:00:00Z')));
      expect(point.temperature, equals(15.2));
      expect(point.windSpeed, equals(3.1));
      expect(point.windDirection, equals(240.0));
      expect(point.cloudCover, equals(75.0));
      expect(point.precipitation, equals(2.4));
    });

    test('fromJson falls back to next_6_hours (divided by 6) when next_1_hours is absent', () {
      final json = {
        'time': '2026-06-05T12:00:00Z',
        'data': {
          'instant': {
            'details': {
              'air_temperature': 21.0,
              'wind_speed': 5.0,
              'wind_from_direction': 90.0,
              'cloud_area_fraction': 10.0,
            },
          },
          'next_6_hours': {
            'details': {'precipitation_amount': 9.0},
          },
        },
      };

      final point = WeatherDataPoint.fromJson(json);
      expect(point.precipitation, closeTo(1.5, 0.001)); // 9.0 / 6 = 1.5
    });

    test(
      'fromJson defaults to 0.0 when next_1_hours and next_6_hours are absent',
      () {
        final json = {
          'time': '2026-06-05T12:00:00Z',
          'data': {
            'instant': {
              'details': {
                'air_temperature': 21.0,
                'wind_speed': 5.0,
                'wind_from_direction': 90.0,
                'cloud_area_fraction': 10.0,
              },
            },
          },
        };

        final point = WeatherDataPoint.fromJson(json);
        expect(point.precipitation, equals(0.0));
      },
    );

    test('fromJson safely handles missing instant details', () {
      final json = {
        'time': '2026-06-05T12:00:00Z',
        'data': <String, dynamic>{},
      };

      final point = WeatherDataPoint.fromJson(json);
      expect(point.temperature, isNull);
      expect(point.windSpeed, equals(0.0));
      expect(point.windDirection, equals(0.0));
      expect(point.cloudCover, equals(0.0));
      expect(point.precipitation, equals(0.0));
    });

    test('fromJson throws ArgumentError if time is null', () {
      expect(
        () => WeatherDataPoint.fromJson({'data': <String, Object?>{}}),
        throwsArgumentError,
      );
    });
  });

  group('OpenMeteoClient', () {
    test(
      'safely parses historical data with partial null sensor values',
      () async {
        final mockResponse = {
          'hourly': {
            'time': [
              '2026-05-01T00:00',
              '2026-05-01T01:00',
              '2026-05-01T02:00',
            ],
            'temperature_2m': [12.5, null, 14],
            'wind_speed_10m': [null, 3.2, 5],
            'wind_direction_10m': [180, null, 210.5],
            'cloudcover': [null, null, 80],
            'precipitation': [0.5, null, 2],
          },
        };

        final client = MockClient((request) async {
          expect(request.url.host, equals('archive-api.open-meteo.com'));
          return http.Response(jsonEncode(mockResponse), 200);
        });

        final openMeteo = OpenMeteoClient(client: client);
        final results = await openMeteo.getHistoricalData(
          55.0,
          10.0,
          DateTime.utc(2026, 5, 1),
          DateTime.utc(2026, 5, 1),
        );

        expect(results.length, equals(3));

        // Row 0: temperature=12.5, wind_speed=0.0 (null), wind_dir=180.0, clouds=0.0 (null), precip=0.5
        expect(results[0].temperature, equals(12.5));
        expect(results[0].windSpeed, equals(0.0));
        expect(results[0].windDirection, equals(180.0));
        expect(results[0].cloudCover, equals(0.0));
        expect(results[0].precipitation, equals(0.5));

        // Row 1: temperature=null, wind_speed=3.2, wind_dir=0.0 (null), clouds=0.0 (null), precip=0.0 (null)
        expect(results[1].temperature, isNull);
        expect(results[1].windSpeed, equals(3.2));
        expect(results[1].windDirection, equals(0.0));
        expect(results[1].cloudCover, equals(0.0));
        expect(results[1].precipitation, equals(0.0));

        // Row 2: temperature=14.0 (int), wind_speed=5.0 (int), wind_dir=210.5, clouds=80.0 (int), precip=2.0 (int)
        expect(results[2].temperature, equals(14.0));
        expect(results[2].windSpeed, equals(5.0));
        expect(results[2].windDirection, equals(210.5));
        expect(results[2].cloudCover, equals(80.0));
        expect(results[2].precipitation, equals(2.0));
      },
    );

    test('throws Exception on non-200 HTTP response', () async {
      final client = MockClient((request) async {
        return http.Response('Server error', 500);
      });

      final openMeteo = OpenMeteoClient(client: client);
      expect(
        () => openMeteo.getHistoricalData(
          55.0,
          10.0,
          DateTime.utc(2026, 5, 1),
          DateTime.utc(2026, 5, 1),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('YrNoWeatherService', () {
    test(
      'formats coordinates to 4 decimal places and caches responses',
      () async {
        int requestCount = 0;
        final mockResponse = {
          'properties': {
            'timeseries': [
              {
                'time': '2026-06-01T12:00:00Z',
                'data': {
                  'instant': {
                    'details': {
                      'air_temperature': 19.5,
                      'wind_speed': 4.0,
                      'wind_from_direction': 180.0,
                      'cloud_area_fraction': 40.0,
                    },
                  },
                  'next_1_hours': {
                    'details': {'precipitation_amount': 0.0},
                  },
                },
              },
            ],
          },
        };

        final client = MockClient((request) async {
          requestCount++;
          expect(request.url.queryParameters['lat'], equals('55.1235'));
          expect(request.url.queryParameters['lon'], equals('14.9877'));
          return http.Response(jsonEncode(mockResponse), 200);
        });

        final yrNo = YrNoWeatherService(
          userAgent: 'MagicCalendarTest/1.0',
          client: client,
          cacheTtl: const Duration(minutes: 30),
        );

        final forecastFirst = await yrNo.getForecast(55.123456, 14.987654);
        expect(requestCount, equals(1));
        expect(forecastFirst.length, equals(1));
        expect(forecastFirst.first.temperature, equals(19.5));

        // Second call with same rounded coordinates should hit cache
        final forecastSecond = await yrNo.getForecast(55.123499, 14.987699);
        expect(requestCount, equals(1));
        expect(forecastSecond, equals(forecastFirst));
      },
    );
  });

  group('CombinedWeatherService', () {
    test('calls Yr.no for forecast', () async {
      final expectedForecast = [
        WeatherDataPoint(
          time: DateTime.now(),
          temperature: 20.0,
          windSpeed: 5.0,
          windDirection: 180.0,
          cloudCover: 50.0,
          precipitation: 0.0,
        ),
      ];
      final yrNoMock = FakeWeatherService(forecast: expectedForecast);
      final dmiMock = FakeWeatherService();
      final combined = CombinedWeatherService(
        yrNoService: yrNoMock,
        dmiService: dmiMock,
      );

      final result = await combined.getForecast(55.0, 10.0);
      expect(result, equals(expectedForecast));
    });

    test('calls DMI for historical data in Denmark mainland', () async {
      final expectedHistorical = [
        WeatherDataPoint(
          time: DateTime.now(),
          temperature: 15.0,
          windSpeed: 5.0,
          windDirection: 180.0,
          cloudCover: 50.0,
          precipitation: 0.0,
        ),
      ];
      final yrNoMock = FakeWeatherService();
      final dmiMock = FakeWeatherService(historical: expectedHistorical);
      final combined = CombinedWeatherService(
        yrNoService: yrNoMock,
        dmiService: dmiMock,
      );

      final result = await combined.getHistoricalData(
        55.0,
        10.0,
        DateTime.now(),
        DateTime.now(),
      );
      expect(result, equals(expectedHistorical));
    });

    test(
      'calls DMI for historical data in Bornholm (lon ~ 14.9°E - 15.2°E)',
      () async {
        final expectedHistorical = [
          WeatherDataPoint(
            time: DateTime.now(),
            temperature: 16.5,
            windSpeed: 6.0,
            windDirection: 90.0,
            cloudCover: 20.0,
            precipitation: 0.0,
          ),
        ];
        final yrNoMock = FakeWeatherService();
        final dmiMock = FakeWeatherService(historical: expectedHistorical);
        final combined = CombinedWeatherService(
          yrNoService: yrNoMock,
          dmiService: dmiMock,
        );

        // Rønne / Nexø on Bornholm coordinates: ~55.1°N, 14.9°E to 15.15°E
        final result = await combined.getHistoricalData(
          55.10,
          14.90,
          DateTime.now(),
          DateTime.now(),
        );
        expect(result, equals(expectedHistorical));

        final resultEastBornholm = await combined.getHistoricalData(
          55.05,
          15.15,
          DateTime.now(),
          DateTime.now(),
        );
        expect(resultEastBornholm, equals(expectedHistorical));
      },
    );

    test(
      'falls back to Yr.no if DMI historical data fails in Denmark / Bornholm',
      () async {
        final expectedHistorical = [
          WeatherDataPoint(
            time: DateTime.now(),
            temperature: 15.0,
            windSpeed: 5.0,
            windDirection: 180.0,
            cloudCover: 50.0,
            precipitation: 0.0,
          ),
        ];
        final yrNoMock = FakeWeatherService(historical: expectedHistorical);
        final throwingDmiMock = FakeWeatherService(
          forecastError: UnimplementedError(),
          historicalError: Exception('DMI service error'),
        );
        final combined = CombinedWeatherService(
          yrNoService: yrNoMock,
          dmiService: throwingDmiMock,
        );

        final result = await combined.getHistoricalData(
          55.10,
          14.90,
          DateTime.now(),
          DateTime.now(),
        );
        expect(result, equals(expectedHistorical));
      },
    );

    test('calls Yr.no for historical data outside Denmark', () async {
      final expectedHistorical = [
        WeatherDataPoint(
          time: DateTime.now(),
          temperature: 15.0,
          windSpeed: 5.0,
          windDirection: 180.0,
          cloudCover: 50.0,
          precipitation: 0.0,
        ),
      ];
      final yrNoMock = FakeWeatherService(historical: expectedHistorical);
      final dmiMock = FakeWeatherService();
      final combined = CombinedWeatherService(
        yrNoService: yrNoMock,
        dmiService: dmiMock,
      );

      final result = await combined.getHistoricalData(
        40.0,
        -3.0,
        DateTime.now(),
        DateTime.now(),
      );
      expect(result, equals(expectedHistorical));
    });
  });

  group('TimeScrollView Weather Integration', () {
    testWidgets(
      'Weather data overlap is filtered and onWeatherDataChanged is invoked',
      (WidgetTester tester) async {
        final now = DateTime.now();
        final forecastPoint = WeatherDataPoint(
          time: now.add(const Duration(hours: 1)),
          temperature: 20.0,
          windSpeed: 5.0,
          windDirection: 180.0,
          cloudCover: 50.0,
          precipitation: 0.0,
        );

        // Historical data that overlaps into the future
        final historicalPointOverlapping = WeatherDataPoint(
          time: now.add(const Duration(hours: 1)),
          temperature: 25.0,
          windSpeed: 5.0,
          windDirection: 180.0,
          cloudCover: 50.0,
          precipitation: 0.0,
        );

        final historicalPointValid = WeatherDataPoint(
          time: now.subtract(const Duration(hours: 1)),
          temperature: 15.0,
          windSpeed: 5.0,
          windDirection: 180.0,
          cloudCover: 50.0,
          precipitation: 0.0,
        );

        final mockWeather = FakeWeatherService(
          forecast: [forecastPoint],
          historical: [historicalPointValid, historicalPointOverlapping],
        );

        final mockEphemeris = FakeEphemerisService();
        List<WeatherDataPoint>? reportedWeather;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimeScrollView(
                ephemeris: mockEphemeris,
                weatherService: mockWeather,
                onTimeSelected: (_) {},
                onWeatherDataChanged: (weather) {
                  reportedWeather = weather;
                },
              ),
            ),
          ),
        );

        // Wait for update to complete (Timer and async calls)
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Find CustomPaint and inspect painter
        final customPaintFinder = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter is InfiniteTimelinePainter,
        );
        expect(customPaintFinder, findsOneWidget);

        final customPaint = tester.widget<CustomPaint>(customPaintFinder);
        final painter = customPaint.painter as InfiniteTimelinePainter;

        final weatherData = painter.weatherData;

        // Verify that the overlapping historical point is filtered out
        expect(weatherData.length, equals(2));
        expect(weatherData.contains(historicalPointOverlapping), isFalse);
        expect(weatherData.contains(forecastPoint), isTrue);
        expect(weatherData.contains(historicalPointValid), isTrue);

        // Verify onWeatherDataChanged was notified
        expect(reportedWeather, isNotNull);
        expect(reportedWeather!.length, equals(2));
        expect(reportedWeather!.contains(historicalPointOverlapping), isFalse);
        expect(reportedWeather!.contains(forecastPoint), isTrue);
        expect(reportedWeather!.contains(historicalPointValid), isTrue);
      },
    );
  });
}
