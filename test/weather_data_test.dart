import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/ui/views/time_scroll_view.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:magic_calendar/src/services/weather_service.dart';
import 'package:magic_calendar/src/ui/painters/infinite_timeline_painter.dart';

final class MockEphemerisService implements EphemerisService {
  @override
  List<CalendarInterval> getIntervals(DateTime start, DateTime end) => [];
  @override
  double getMoonLongitude(DateTime time) => 0.0;
  @override
  bool isNearNode(DateTime time) => false;
  @override
  bool isNearPerigee(DateTime time) => false;
  @override
  bool isMoonSquareNode(DateTime time) => false;
  @override
  double getMoonDeclination(DateTime time) => 0.0;
  @override
  MoonPhaseInfo getMoonPhase(DateTime time) =>
      MoonPhaseInfo(illuminatedFraction: 0.5, isWaxing: true, phaseAngle: 0.0);
  @override
  List<PlanetInfo> getPlanets(DateTime time) => [];
  @override
  SunriseSunsetInfo getSunriseSunset(DateTime date, double lat, double lon) {
    return SunriseSunsetInfo(noon: DateTime.now());
  }
}

final class MockWeatherService implements WeatherService {
  final List<WeatherDataPoint> forecastData;
  final List<WeatherDataPoint> historicalData;

  MockWeatherService({
    this.forecastData = const [],
    this.historicalData = const [],
  });

  @override
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon) async =>
      forecastData;

  @override
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) async => historicalData;
}

void main() {
  testWidgets('Weather data overlap is filtered', (WidgetTester tester) async {
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
      temperature: 25.0, // Different value to detect if it's used
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

    final mockWeather = MockWeatherService(
      forecastData: [forecastPoint],
      historicalData: [historicalPointValid, historicalPointOverlapping],
    );

    final mockEphemeris = MockEphemerisService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeScrollView(
            ephemeris: mockEphemeris,
            weatherService: mockWeather,
            onTimeSelected: (_, {immediate = false}) {},
          ),
        ),
      ),
    );

    // Wait for update to complete (Timer and async calls)
    await tester.pump(); // Trigger initial update
    await tester.pump(const Duration(seconds: 1)); // Wait for async work

    // Find CustomPaint and inspect painter
    final customPaintFinder = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is InfiniteTimelinePainter,
    );
    expect(customPaintFinder, findsOneWidget);

    final customPaint = tester.widget<CustomPaint>(customPaintFinder);
    final painter = customPaint.painter as InfiniteTimelinePainter;

    final weatherData = painter.weatherData;

    // Verify that the overlapping historical point is filtered out
    expect(weatherData.length, 2);
    expect(weatherData.contains(historicalPointOverlapping), isFalse);
    expect(weatherData.contains(forecastPoint), isTrue);
    expect(weatherData.contains(historicalPointValid), isTrue);
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
      final yrNoMock = MockWeatherService(forecastData: expectedForecast);
      final dmiMock = MockWeatherService();
      final combined = CombinedWeatherService(
        yrNoService: yrNoMock,
        dmiService: dmiMock,
      );

      final result = await combined.getForecast(55.0, 10.0);
      expect(result, expectedForecast);
    });

    test('calls DMI for historical data in Denmark', () async {
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
      final yrNoMock = MockWeatherService();
      final dmiMock = MockWeatherService(historicalData: expectedHistorical);
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
      expect(result, expectedHistorical);
    });

    test(
      'falls back to Yr.no if DMI historical data fails in Denmark',
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
        final yrNoMock = MockWeatherService(historicalData: expectedHistorical);
        final throwingDmiMock = _ThrowingMockWeatherService();
        final combined = CombinedWeatherService(
          yrNoService: yrNoMock,
          dmiService: throwingDmiMock,
        );

        final result = await combined.getHistoricalData(
          55.0,
          10.0,
          DateTime.now(),
          DateTime.now(),
        );
        expect(result, expectedHistorical);
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
      final yrNoMock = MockWeatherService(historicalData: expectedHistorical);
      final dmiMock = MockWeatherService();
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
      expect(result, expectedHistorical);
    });
  });
}

/// A mock weather service that throws an exception when historical data is fetched.
final class _ThrowingMockWeatherService implements WeatherService {
  @override
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon) async {
    throw UnimplementedError();
  }

  @override
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) async {
    throw Exception('DMI service error');
  }
}
