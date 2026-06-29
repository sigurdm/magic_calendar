import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/main.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:magic_calendar/src/services/weather_service.dart';

final class MockEphemerisService implements EphemerisService {
  final double _mockLongitude;
  final bool _mockIsNearNode;
  final bool _mockIsNearPerigee;

  MockEphemerisService(
    this._mockLongitude, [
    this._mockIsNearNode = false,
    this._mockIsNearPerigee = false,
  ]);

  @override
  List<CalendarInterval> getIntervals(DateTime start, DateTime end) => [];

  @override
  double getMoonLongitude(DateTime time) => _mockLongitude;

  @override
  bool isNearNode(DateTime time) => _mockIsNearNode;

  @override
  bool isNearPerigee(DateTime time) => _mockIsNearPerigee;

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
  @override
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon) async {
    return [];
  }

  @override
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) async {
    return [];
  }
}

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        ephemeris: MockEphemerisService(0.0),
        weather: MockWeatherService(),
      ),
    );

    expect(find.text('Magic Calendar'), findsOneWidget);
  });
}
