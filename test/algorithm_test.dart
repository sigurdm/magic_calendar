import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/algorithm.dart';
import 'package:magic_calendar/src/core/dornach_boundaries.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:sweph/sweph.dart';

import 'support/fakes.dart';
import 'support/sweph_test_loader.dart';

void main() async {
  await ensureSwephLoaded();
  await Sweph.init();

  test('getCalendarInfo returns a valid CalendarInfo', () {
    final info = getCalendarInfo(DateTime.now(), FakeEphemerisService());
    expect(info.quality, isA<PlantQuality>());
  });

  test('getCalendarInfo catches exceptions and returns error CalendarInfo gracefully', () {
    final throwingService = FakeEphemerisService(
      error: Exception('Simulated Ephemeris Error'),
    );
    final info = getCalendarInfo(DateTime.now(), throwingService);
    expect(info.quality, PlantQuality.none);
    expect(info.isGrayDay, isFalse);
    expect(info.message, contains('Error calculating planetary positions:'));
  });

  test('getCalendarInfo returns gray day when near node', () {
    final info = getCalendarInfo(
      DateTime.now(),
      FakeEphemerisService(nearNode: true),
    );
    expect(info.isGrayDay, isTrue);
    expect(info.quality, PlantQuality.none);
    expect(info.message, contains('Near Lunar Node'));
  });

  test('getCalendarInfo returns gray day when near perigee', () {
    final info = getCalendarInfo(
      DateTime.now(),
      FakeEphemerisService(nearPerigee: true),
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

  test('getQualityFromLongitude handles degree normalization correctly at 360 boundaries', () {
    expect(getQualityFromLongitude(0.0), isA<PlantQuality>());
    expect(getQualityFromLongitude(360.0), getQualityFromLongitude(0.0));
    expect(getQualityFromLongitude(-10.0), getQualityFromLongitude(350.0));
    expect(getQualityFromLongitude(720.0), getQualityFromLongitude(0.0));
  });

  test('calculateTrineQuality detects Special Flower Day from Air constellation planetary trine', () {
    final planets = [
      const PlanetInfo(
        name: 'Moon',
        longitude: 108.0,
      ), // Gemini (Air -> Flower)
      const PlanetInfo(
        name: 'Jupiter',
        longitude: 228.0,
      ), // Libra (Air -> Flower), exact 120 degrees apart
    ];

    final result = calculateTrineQuality(planets, dornachBoundaries);

    expect(result.quality, PlantQuality.flower);
    expect(result.message, contains('Special Flower Day'));
  });

  test(
    'validates Ag-Flower and Especially Favorable reference scan periods',
    () {
      final service = AstronomiaEphemerisService();
      final checkPoints = [
        (
          'Jan 12 Ag-Flower',
          DateTime.utc(2026, 1, 12, 22, 0),
          PlantQuality.flower,
        ),
        (
          'Feb 9 Ag-Flower',
          DateTime.utc(2026, 2, 9, 4, 0),
          PlantQuality.flower,
        ),
        (
          'Mar 8 Fav Flower',
          DateTime.utc(2026, 3, 8, 16, 0),
          PlantQuality.flower,
        ),
        (
          'Feb 7 Moon-Saturn Opp',
          DateTime.utc(2026, 2, 7, 10, 0),
          PlantQuality.root,
        ),
      ];

      for (final (label, time, expectedQuality) in checkPoints) {
        final info = getCalendarInfo(
          time,
          service,
          boundaries: customCalendarBoundaries,
        );
        expect(info.isSpecial, isTrue, reason: 'Failed isSpecial for $label');
        expect(
          info.quality,
          expectedQuality,
          reason: 'Failed quality for $label',
        );
      }
    },
  );

  test('getSunriseSunset accurately calculates sunrise and sunset with Equation of Time', () {
    final service = AstronomiaEphemerisService();
    // Copenhagen: 55.6761 N, 12.5683 E on summer solstice 2026-06-21
    final solsticeDate = DateTime.utc(2026, 6, 21);
    final sunInfo = service.getSunriseSunset(solsticeDate, 55.6761, 12.5683);

    expect(sunInfo.sunrise, isNotNull);
    expect(sunInfo.sunset, isNotNull);
    expect(sunInfo.sunrise!.isBefore(sunInfo.noon), isTrue);
    expect(sunInfo.noon.isBefore(sunInfo.sunset!), isTrue);

    // Daylight duration on solstice in Copenhagen is ~17.5 hours
    final daylightHours =
        sunInfo.sunset!.difference(sunInfo.sunrise!).inMinutes / 60.0;
    expect(daylightHours, greaterThan(17.0));
    expect(daylightHours, lessThan(18.0));
  });

  test(
    'isMoonSquareNode correctly identifies high ecliptic latitude windows',
    () {
      final service = AstronomiaEphemerisService();
      // Test across a lunar month to find square node points (approx 2 occurrences per month)
      var testTime = DateTime.utc(2026, 1, 1);
      final endTime = DateTime.utc(2026, 2, 1);
      int squareNodeCount = 0;

      while (testTime.isBefore(endTime)) {
        if (service.isMoonSquareNode(testTime)) {
          squareNodeCount++;
        }
        testTime = testTime.add(const Duration(hours: 1));
      }

      // There should be a reasonable number of square node hours detected (~12-30 hours per month)
      expect(squareNodeCount, greaterThan(10));
      expect(squareNodeCount, lessThan(50));
    },
  );
}
