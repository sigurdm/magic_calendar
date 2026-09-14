import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/seasonal_calendar.dart';

void main() {
  group('gregorianEaster', () {
    // Reference dates for Easter Sunday in the Gregorian calendar.
    const knownEasters = <int, (int, int)>{
      2020: (4, 12),
      2021: (4, 4),
      2022: (4, 17),
      2023: (4, 9),
      2024: (3, 31),
      2025: (4, 20),
      2026: (4, 5),
      2027: (3, 28),
      2028: (4, 16),
      2029: (4, 1),
      2030: (4, 21),
      2038: (4, 25), // latest possible date
      2035: (3, 25),
    };

    for (final entry in knownEasters.entries) {
      test('is correct for ${entry.key}', () {
        final (month, day) = entry.value;
        expect(gregorianEaster(entry.key), DateTime(entry.key, month, day));
      });
    }

    test('always falls between 22 March and 25 April', () {
      for (var year = 1900; year <= 2200; year++) {
        final easter = gregorianEaster(year);
        expect(
          easter.isAfter(DateTime(year, 3, 21)),
          isTrue,
          reason: 'Easter $year ($easter) must be on or after 22 March',
        );
        expect(
          easter.isBefore(DateTime(year, 4, 26)),
          isTrue,
          reason: 'Easter $year ($easter) must be on or before 25 April',
        );
      }
    });

    test('always falls on a Sunday', () {
      for (var year = 1900; year <= 2200; year++) {
        expect(
          gregorianEaster(year).weekday,
          DateTime.sunday,
          reason: 'Easter $year must be a Sunday',
        );
      }
    });
  });

  group('southernHemisphereMonth', () {
    test('maps each month to its opposite season', () {
      expect(southernHemisphereMonth(1), 7);
      expect(southernHemisphereMonth(6), 12);
      expect(southernHemisphereMonth(7), 1);
      expect(southernHemisphereMonth(12), 6);
    });

    test('is its own inverse', () {
      for (var month = 1; month <= 12; month++) {
        expect(southernHemisphereMonth(southernHemisphereMonth(month)), month);
      }
    });

    test('always returns a valid 1-based month', () {
      for (var month = 1; month <= 12; month++) {
        expect(southernHemisphereMonth(month), inInclusiveRange(1, 12));
      }
    });
  });

  group('toNorthernSeasonEquivalent', () {
    test('returns the date unchanged in the northern hemisphere', () {
      final date = DateTime(2026, 12, 31, 14, 30);
      expect(toNorthernSeasonEquivalent(date, isNorthern: true), date);
    });

    test('shifts a southern date forward by six months', () {
      expect(
        toNorthernSeasonEquivalent(DateTime(2026, 1, 15), isNorthern: false),
        DateTime(2026, 7, 15),
      );
    });

    test('advances December into the following year', () {
      final shifted = toNorthernSeasonEquivalent(
        DateTime(2026, 12, 15),
        isNorthern: false,
      );
      expect(shifted.year, 2027);
      expect(shifted.month, 6);
      expect(shifted.day, 15);
    });

    test('preserves the time of day', () {
      final shifted = toNorthernSeasonEquivalent(
        DateTime(2026, 3, 10, 14, 35, 20),
        isNorthern: false,
      );
      expect(shifted.hour, 14);
      expect(shifted.minute, 35);
      expect(shifted.second, 20);
    });

    test('moves strictly forward in time for every month', () {
      for (var month = 1; month <= 12; month++) {
        final date = DateTime(2026, month, 15);
        final shifted = toNorthernSeasonEquivalent(date, isNorthern: false);
        expect(
          shifted.isAfter(date),
          isTrue,
          reason: 'month $month should map forward, got $shifted',
        );
      }
    });
  });
}
