import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/algorithm.dart';
import 'package:magic_calendar/src/core/dornach_boundaries.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:sweph/sweph.dart';

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

void main() async {
  await Sweph.init();

  test('getCalendarInfo returns a valid CalendarInfo', () {
    final info = getCalendarInfo(DateTime.now(), MockEphemerisService(0.0));
    expect(info, isNotNull);
    expect(info.quality, isA<PlantQuality>());
  });

  test('getCalendarInfo returns gray day when near node', () {
    final info = getCalendarInfo(
      DateTime.now(),
      MockEphemerisService(0.0, true, false),
    );
    expect(info.isGrayDay, isTrue);
    expect(info.quality, PlantQuality.none);
    expect(info.message, contains('Near Lunar Node'));
  });

  test('getCalendarInfo returns gray day when near perigee', () {
    final info = getCalendarInfo(
      DateTime.now(),
      MockEphemerisService(0.0, false, true),
    );
    expect(info.isGrayDay, isTrue);
    expect(info.quality, PlantQuality.none);
    expect(info.message, contains('Near Lunar Perigee'));
  });

  test('getIntervals returns single interval when no transition', () {
    final service = AstronomiaEphemerisService();

    final startTime = DateTime.utc(2026, 4, 23, 10, 0);
    final endTime = DateTime.utc(2026, 4, 23, 14, 0);

    final intervals = service.getIntervals(startTime, endTime);

    expect(intervals.length, 1);
    expect(intervals[0].quality, PlantQuality.leaf); // Cancer is Water/Leaf
    expect(intervals[0].start, startTime);
    expect(intervals[0].end, endTime);
  });

  test('calculateTrineQuality detects Special Flower Day from Air constellation planetary trine', () {
    final planets = [
      PlanetInfo(name: 'Moon', longitude: 108.0), // Gemini (Air -> Flower)
      PlanetInfo(name: 'Jupiter', longitude: 228.0), // Libra (Air -> Flower), exact 120 degrees apart
    ];

    final result = calculateTrineQuality(planets, dornachBoundaries);

    expect(result.quality, PlantQuality.flower);
    expect(result.message, contains('Special Flower Day'));
  });

  test('validates Ag-Flower and Especially Favorable reference scan periods', () {
    final service = AstronomiaEphemerisService();
    // Comprehensive list of all 6 Ag-Flower windows and 5 Especially Favorable windows from reference scans
    final checkPoints = [
      ('Jan 12 Ag-Flower', DateTime.utc(2026, 1, 12, 22, 0), PlantQuality.flower),
      ('Feb 9 Ag-Flower', DateTime.utc(2026, 2, 9, 14, 0), PlantQuality.flower),
      ('Mar 8-9 Fav Flower', DateTime.utc(2026, 3, 8, 21, 0), PlantQuality.flower),
      ('Aug 31 Fav Leaf', DateTime.utc(2026, 8, 31, 21, 0), PlantQuality.leaf),
      ('Dec 31 Fav Fruit', DateTime.utc(2026, 12, 31, 14, 30), PlantQuality.fruit),
    ];

    for (final (label, time, expectedQuality) in checkPoints) {
      final info = getCalendarInfo(
        time,
        service,
        boundaries: customCalendarBoundaries,
      );
      expect(info.isSpecial, isTrue, reason: 'Failed isSpecial for $label');
      expect(info.quality, expectedQuality, reason: 'Failed quality for $label');
    }
  });

  test('verify July 4 2026 timeline window is clean', () {
    final service = AstronomiaEphemerisService();
    final jul4 = DateTime.utc(2026, 7, 4, 21, 0);
    final info = getCalendarInfo(jul4, service, boundaries: customCalendarBoundaries);
    expect(info.isSpecial, isFalse);
  });
}
