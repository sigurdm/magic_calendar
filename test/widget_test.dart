// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_calendar/main.dart';
import 'package:magic_calendar/src/ephemeris_service.dart';

class MockEphemerisService implements EphemerisService {
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

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(ephemeris: MockEphemerisService(0.0)));

    // Verify that it shows Magic Calendar.
    expect(find.text('Magic Calendar'), findsOneWidget);
  });
}
