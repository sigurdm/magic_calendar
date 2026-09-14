import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/algorithm.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';

final class _StubEphemerisService with EphemerisService {
  final double moonLongitude;
  final double Function(DateTime time)? declinationFn;
  final SunriseSunsetInfo sunTimes;

  _StubEphemerisService({
    this.moonLongitude = 60.0,
    this.declinationFn,
    required this.sunTimes,
  });

  @override
  SunriseSunsetInfo getSunriseSunset(DateTime date, double lat, double lon) =>
      sunTimes;

  @override
  double getMoonLongitude(DateTime time) => moonLongitude;

  @override
  double getMoonDeclination(DateTime time) {
    if (declinationFn != null) return declinationFn!(time);
    return 0.0;
  }

  @override
  bool isNearNode(DateTime time) => false;
  @override
  bool isNearPerigee(DateTime time) => false;
  @override
  bool isNearApogee(DateTime time) => false;
  @override
  bool isMoonSaturnOpposition(DateTime time) => false;
  @override
  bool isMoonSquareNode(DateTime time) => false;
  @override
  MoonPhaseInfo getMoonPhase(DateTime time) => const MoonPhaseInfo(
    illuminatedFraction: 0.5,
    isWaxing: false,
    phaseAngle: 90.0,
  );
  @override
  List<PlanetInfo> getPlanets(DateTime time) => [];
  @override
  List<CalendarInterval> getIntervals(DateTime start, DateTime end) => [];
}

void main() {
  group("Diurnal Earth Rhythms (Earth's Daily Breath)", () {
    final sunrise = DateTime(2026, 6, 21, 5, 30);
    final solarNoon = DateTime(2026, 6, 21, 12, 0);
    final sunset = DateTime(2026, 6, 21, 20, 30);

    test('Correctly classifies Night Rest before sunrise', () {
      final t = DateTime(2026, 6, 21, 4, 15);
      final info = DiurnalRhythmInfo.fromSunTimes(
        time: t,
        sunrise: sunrise,
        sunset: sunset,
        solarNoon: solarNoon,
      );

      expect(info.phase, DiurnalPhase.nightRest);
      expect(info.title, contains('Night Rest'));
      expect(info.optimalTasks, contains(contains('Compost')));
    });

    test('Correctly classifies Morning Exhalation after sunrise until noon stillness', () {
      final t = DateTime(2026, 6, 21, 8, 45);
      final info = DiurnalRhythmInfo.fromSunTimes(
        time: t,
        sunrise: sunrise,
        sunset: sunset,
        solarNoon: solarNoon,
      );

      expect(info.phase, DiurnalPhase.morningExhalation);
      expect(info.title, contains('Morning Exhalation'));
      expect(info.optimalTasks.any((task) => task.contains('BD 501')), isTrue);
      expect(info.cautionedTasks.any((task) => task.contains('Root')), isTrue);
    });

    test(
      'Correctly classifies Solar Noon Stillness in zenith window (±45 min)',
      () {
        final tBefore = DateTime(2026, 6, 21, 11, 30);
        final infoBefore = DiurnalRhythmInfo.fromSunTimes(
          time: tBefore,
          sunrise: sunrise,
          sunset: sunset,
          solarNoon: solarNoon,
        );
        expect(infoBefore.phase, DiurnalPhase.solarNoonStillness);
        expect(infoBefore.title, contains('Solar Noon Stillness'));
        expect(
          infoBefore.cautionedTasks.any((t) => t.contains('cultivation')),
          isTrue,
        );

        final infoNoon = DiurnalRhythmInfo.fromSunTimes(
          time: solarNoon,
          sunrise: sunrise,
          sunset: sunset,
          solarNoon: solarNoon,
        );
        expect(infoNoon.phase, DiurnalPhase.solarNoonStillness);

        final tAfter = DateTime(2026, 6, 21, 12, 40);
        final infoAfter = DiurnalRhythmInfo.fromSunTimes(
          time: tAfter,
          sunrise: sunrise,
          sunset: sunset,
          solarNoon: solarNoon,
        );
        expect(infoAfter.phase, DiurnalPhase.solarNoonStillness);
      },
    );

    test('Correctly classifies Evening Inhalation after noon stillness until sunset', () {
      final t = DateTime(2026, 6, 21, 16, 30);
      final info = DiurnalRhythmInfo.fromSunTimes(
        time: t,
        sunrise: sunrise,
        sunset: sunset,
        solarNoon: solarNoon,
      );

      expect(info.phase, DiurnalPhase.eveningInhalation);
      expect(info.title, contains('Evening Inhalation'));
      expect(info.optimalTasks.any((t) => t.contains('BD 500')), isTrue);
      expect(info.optimalTasks.any((t) => t.contains('Seed sowing')), isTrue);
    });

    test('Correctly classifies Night Rest after sunset', () {
      final t = DateTime(2026, 6, 21, 22, 10);
      final info = DiurnalRhythmInfo.fromSunTimes(
        time: t,
        sunrise: sunrise,
        sunset: sunset,
        solarNoon: solarNoon,
      );

      expect(info.phase, DiurnalPhase.nightRest);
      expect(info.title, contains('Night Rest'));
    });

    test('Sensible fallbacks work when sunrise or sunset is null (e.g. polar regions)', () {
      final info = DiurnalRhythmInfo.fromSunTimes(
        time: DateTime(2026, 6, 21, 14, 0),
        sunrise: null,
        sunset: null,
        solarNoon: solarNoon,
      );

      expect(info.phase, DiurnalPhase.eveningInhalation);
      expect(info.title, contains('Evening Inhalation'));
    });

    test('getCalendarInfo populates diurnalRhythm and synthesizes sapFlow', () {
      final eveningTime = DateTime.utc(2026, 6, 21, 16, 0);
      final sunTimes = SunriseSunsetInfo(
        sunrise: DateTime.utc(2026, 6, 21, 5, 0),
        sunset: DateTime.utc(2026, 6, 21, 20, 0),
        noon: DateTime.utc(2026, 6, 21, 12, 0),
      );

      final service = _StubEphemerisService(
        moonLongitude: 60.0,
        declinationFn: (t) =>
            t.hour == 16 ? 15.0 : 14.0, // Descending (15.0 -> 14.0)
        sunTimes: sunTimes,
      );

      final info = getCalendarInfo(eveningTime, service);

      expect(info.diurnalRhythm, isNotNull);
      expect(info.diurnalRhythm!.phase, DiurnalPhase.eveningInhalation);
      expect(info.sapFlow, contains('Descending: Sap recedes.'));
      expect(
        info.sapFlow,
        contains(
          'Evening Inhalation: Earth breathes in, optimal for seed sowing & soil spray.',
        ),
      );
    });

    test(
      'getCalendarInfo synthesizes ascending sapFlow with morning exhalation',
      () {
        final morningTime = DateTime.utc(2026, 6, 21, 8, 0);
        final sunTimes = SunriseSunsetInfo(
          sunrise: DateTime.utc(2026, 6, 21, 5, 0),
          sunset: DateTime.utc(2026, 6, 21, 20, 0),
          noon: DateTime.utc(2026, 6, 21, 12, 0),
        );

        final service = _StubEphemerisService(
          moonLongitude: 60.0,
          declinationFn: (t) =>
              t.hour == 8 ? 14.0 : 15.0, // Ascending (14.0 -> 15.0)
          sunTimes: sunTimes,
        );

        final info = getCalendarInfo(morningTime, service);

        expect(info.diurnalRhythm, isNotNull);
        expect(info.diurnalRhythm!.phase, DiurnalPhase.morningExhalation);
        expect(info.sapFlow, contains('Ascending: Sap rises.'));
        expect(
          info.sapFlow,
          contains('Morning Exhalation: Earth breathes out'),
        );
      },
    );
  });
}
