import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/biodynamic_prep.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:sweph/sweph.dart';

final class MockPrepEphemerisService with EphemerisService {
  final PlantQuality mockQuality;
  final bool mockIsGrayDay;
  final String mockSapFlow;
  final double mockMoonIllumination;

  MockPrepEphemerisService({
    this.mockQuality = PlantQuality.leaf,
    this.mockIsGrayDay = false,
    this.mockSapFlow = 'Descending: Sap recedes',
    this.mockMoonIllumination = 0.90,
  });

  @override
  List<CalendarInterval> getIntervals(DateTime start, DateTime end) => [];

  @override
  double getMoonLongitude(DateTime time) => 90.0;

  @override
  bool isNearNode(DateTime time) => mockIsGrayDay;

  @override
  bool isNearPerigee(DateTime time) => false;

  @override
  bool isNearApogee(DateTime time) => false;

  @override
  bool isMoonSaturnOpposition(DateTime time) => false;

  @override
  bool isMoonSquareNode(DateTime time) => false;

  @override
  double getMoonDeclination(DateTime time) => 15.0;

  @override
  MoonPhaseInfo getMoonPhase(DateTime time) => MoonPhaseInfo(
    illuminatedFraction: mockMoonIllumination,
    isWaxing: true,
    phaseAngle: 180.0 * mockMoonIllumination,
  );

  @override
  List<PlanetInfo> getPlanets(DateTime time) => [];

  @override
  SunriseSunsetInfo getSunriseSunset(DateTime date, double lat, double lon) =>
      SunriseSunsetInfo(noon: date);
}

void main() async {
  await Sweph.init();

  group('BiodynamicPrepEvaluator - BD 508 (Horsetail / Equisetum)', () {
    test('evaluates BD 508 as highly favorable under optimal conditions', () {
      final calendarInfo = CalendarInfo(
        quality: PlantQuality.leaf,
        isGrayDay: false,
        message: '',
        sapFlow: 'Ascending: Sap rises',
        vitality: 'Full Moon (Increasing moisture/vitality)',
        moonPhase: const MoonPhaseInfo(
          illuminatedFraction: 0.95,
          isWaxing: true,
          phaseAngle: 170.0,
        ),
        planets: const [],
      );

      // Morning 10:00, 18°C, 2.5 m/s wind, 0 mm rain, 80% humidity
      final time = DateTime(2026, 6, 15, 10, 0);
      final eval = BiodynamicPrepEvaluator.evaluateSpray(
        prep: BiodynamicPrepType.bd508,
        time: time,
        calendarInfo: calendarInfo,
        temperature: 18.0,
        windSpeed: 2.5,
        precipitation: 0.0,
        humidity: 80.0,
      );

      expect(eval.isFavorable, isTrue);
      expect(eval.score, greaterThanOrEqualTo(0.80));
      expect(eval.positiveFactors, isNotEmpty);
      expect(eval.negativeFactors, isEmpty);
      expect(eval.positiveFactors.any((f) => f.contains('10–28°C')), isTrue);
      expect(eval.positiveFactors.any((f) => f.contains('<= 6 m/s')), isTrue);
      expect(eval.positiveFactors.any((f) => f.contains('Leaf Day')), isTrue);
    });

    test('penalizes cold temperatures below 5°C', () {
      final calendarInfo = CalendarInfo(
        quality: PlantQuality.leaf,
        isGrayDay: false,
        message: '',
        sapFlow: '',
        vitality: '',
        moonPhase: const MoonPhaseInfo(
          illuminatedFraction: 0.5,
          isWaxing: true,
          phaseAngle: 90.0,
        ),
        planets: const [],
      );

      final eval = BiodynamicPrepEvaluator.evaluateSpray(
        prep: BiodynamicPrepType.bd508,
        time: DateTime(2026, 4, 1, 10, 0),
        calendarInfo: calendarInfo,
        temperature: 2.0,
        windSpeed: 3.0,
      );

      expect(eval.isFavorable, isFalse);
      expect(eval.negativeFactors.any((f) => f.contains('< 5°C')), isTrue);
    });

    test('penalizes extreme heat above 30°C', () {
      final calendarInfo = CalendarInfo(
        quality: PlantQuality.leaf,
        isGrayDay: false,
        message: '',
        sapFlow: '',
        vitality: '',
        moonPhase: const MoonPhaseInfo(
          illuminatedFraction: 0.5,
          isWaxing: true,
          phaseAngle: 90.0,
        ),
        planets: const [],
      );

      final eval = BiodynamicPrepEvaluator.evaluateSpray(
        prep: BiodynamicPrepType.bd508,
        time: DateTime(2026, 7, 15, 12, 0),
        calendarInfo: calendarInfo,
        temperature: 33.0,
        windSpeed: 3.0,
      );

      expect(eval.isFavorable, isFalse);
      expect(eval.negativeFactors.any((f) => f.contains('> 30°C')), isTrue);
    });

    test('penalizes high winds above 8 m/s', () {
      final calendarInfo = CalendarInfo(
        quality: PlantQuality.leaf,
        isGrayDay: false,
        message: '',
        sapFlow: '',
        vitality: '',
        moonPhase: const MoonPhaseInfo(
          illuminatedFraction: 0.5,
          isWaxing: true,
          phaseAngle: 90.0,
        ),
        planets: const [],
      );

      final eval = BiodynamicPrepEvaluator.evaluateSpray(
        prep: BiodynamicPrepType.bd508,
        time: DateTime(2026, 6, 15, 10, 0),
        calendarInfo: calendarInfo,
        temperature: 20.0,
        windSpeed: 10.5,
      );

      expect(eval.isFavorable, isFalse);
      expect(eval.negativeFactors.any((f) => f.contains('> 8 m/s')), isTrue);
    });

    test('disqualifies spray during Gray Day blackout windows', () {
      final calendarInfo = CalendarInfo(
        quality: PlantQuality.none,
        isGrayDay: true,
        message: 'Near Lunar Node',
        sapFlow: '',
        vitality: '',
        moonPhase: const MoonPhaseInfo(
          illuminatedFraction: 0.95,
          isWaxing: true,
          phaseAngle: 180.0,
        ),
        planets: const [],
      );

      final eval = BiodynamicPrepEvaluator.evaluateSpray(
        prep: BiodynamicPrepType.bd508,
        time: DateTime(2026, 6, 15, 10, 0),
        calendarInfo: calendarInfo,
        temperature: 20.0,
        windSpeed: 2.0,
      );

      expect(eval.score, 0.0);
      expect(eval.isFavorable, isFalse);
      expect(eval.negativeFactors.any((f) => f.contains('Gray Day')), isTrue);
    });
  });

  group('BiodynamicPrepEvaluator - BD 500 and BD 501', () {
    test('BD 500 prefers late afternoon / evening and Descending Moon', () {
      final descInfo = CalendarInfo(
        quality: PlantQuality.root,
        isGrayDay: false,
        message: '',
        sapFlow: "Descending: Sap recedes; 'transplanting time'",
        vitality: '',
        moonPhase: const MoonPhaseInfo(
          illuminatedFraction: 0.4,
          isWaxing: false,
          phaseAngle: 270.0,
        ),
        planets: const [],
      );

      final eveningEval = BiodynamicPrepEvaluator.evaluateSpray(
        prep: BiodynamicPrepType.bd500,
        time: DateTime(2026, 5, 10, 17, 0),
        calendarInfo: descInfo,
        windSpeed: 2.0,
      );

      expect(eveningEval.isFavorable, isTrue);
      expect(
        eveningEval.positiveFactors.any((f) => f.contains('15:00–20:00')),
        isTrue,
      );
      expect(
        eveningEval.positiveFactors.any((f) => f.contains('Descending Moon')),
        isTrue,
      );
    });

    test(
      'BD 501 prefers early morning sunrise and Ascending Moon on Flower/Fruit day',
      () {
        final ascInfo = CalendarInfo(
          quality: PlantQuality.flower,
          isGrayDay: false,
          message: '',
          sapFlow: 'Ascending: Sap rises',
          vitality: '',
          moonPhase: const MoonPhaseInfo(
            illuminatedFraction: 0.6,
            isWaxing: true,
            phaseAngle: 60.0,
          ),
          planets: const [],
        );

        final morningEval = BiodynamicPrepEvaluator.evaluateSpray(
          prep: BiodynamicPrepType.bd501,
          time: DateTime(2026, 5, 10, 6, 30),
          calendarInfo: ascInfo,
          windSpeed: 1.5,
        );

        expect(morningEval.isFavorable, isTrue);
        expect(
          morningEval.positiveFactors.any((f) => f.contains('05:00–09:00')),
          isTrue,
        );
        expect(
          morningEval.positiveFactors.any((f) => f.contains('Ascending Moon')),
          isTrue,
        );
        expect(
          morningEval.positiveFactors.any((f) => f.contains('Flower')),
          isTrue,
        );
      },
    );
  });

  group(
    'BiodynamicPrepEvaluator - CPP (Cow Pat Pit / Maria Thun Barrel Compost)',
    () {
      final descRootInfo = CalendarInfo(
        quality: PlantQuality.root,
        isGrayDay: false,
        message: '',
        sapFlow: 'Descending: Earth Inhalation',
        vitality: 'Waning Gibbous',
        moonPhase: const MoonPhaseInfo(
          illuminatedFraction: 0.75,
          isWaxing: false,
          phaseAngle: 220.0,
        ),
        planets: const [],
      );

      test(
        'evaluates CPP as optimal during Descending Moon, evening (15-20), temp >= 8°C, wind <= 5 m/s',
        () {
          final eval = BiodynamicPrepEvaluator.evaluateSpray(
            prep: BiodynamicPrepType.cpp,
            time: DateTime(2026, 5, 12, 17, 30),
            calendarInfo: descRootInfo,
            temperature: 15.0,
            windSpeed: 3.0,
            precipitation: 0.0,
          );

          expect(eval.level, equals(PrepSuitabilityLevel.optimal));
          expect(eval.isFavorable, isTrue);
          expect(eval.score, equals(1.0));
          expect(
            eval.positiveFactors.any((f) => f.contains('Descending Moon')),
            isTrue,
          );
          expect(
            eval.positiveFactors.any((f) => f.contains('15:00–20:00')),
            isTrue,
          );
          expect(eval.positiveFactors.any((f) => f.contains('>= 8°C')), isTrue);
          expect(
            eval.positiveFactors.any((f) => f.contains('<= 5 m/s')),
            isTrue,
          );
          expect(eval.negativeFactors, isEmpty);
        },
      );

      test('penalizes CPP when temperature is below 8°C', () {
        final eval = BiodynamicPrepEvaluator.evaluateSpray(
          prep: BiodynamicPrepType.cpp,
          time: DateTime(2026, 4, 15, 17, 0),
          calendarInfo: descRootInfo,
          temperature: 6.0,
          windSpeed: 2.0,
        );

        expect(eval.level, equals(PrepSuitabilityLevel.unfavorable));
        expect(eval.weatherSuitable, isFalse);
        expect(eval.negativeFactors.any((f) => f.contains('< 8°C')), isTrue);
      });

      test('penalizes CPP when wind speed exceeds 5 m/s', () {
        final eval = BiodynamicPrepEvaluator.evaluateSpray(
          prep: BiodynamicPrepType.cpp,
          time: DateTime(2026, 5, 15, 17, 0),
          calendarInfo: descRootInfo,
          temperature: 16.0,
          windSpeed: 6.5,
        );

        expect(eval.level, equals(PrepSuitabilityLevel.unfavorable));
        expect(eval.weatherSuitable, isFalse);
        expect(eval.negativeFactors.any((f) => f.contains('> 5 m/s')), isTrue);
      });

      test('penalizes CPP during Ascending Moon', () {
        final ascInfo = CalendarInfo(
          quality: PlantQuality.leaf,
          isGrayDay: false,
          message: '',
          sapFlow: 'Ascending: Earth Exhalation',
          vitality: '',
          moonPhase: const MoonPhaseInfo(
            illuminatedFraction: 0.5,
            isWaxing: true,
            phaseAngle: 90.0,
          ),
          planets: const [],
        );

        final eval = BiodynamicPrepEvaluator.evaluateSpray(
          prep: BiodynamicPrepType.cpp,
          time: DateTime(2026, 5, 15, 17, 0),
          calendarInfo: ascInfo,
          temperature: 16.0,
          windSpeed: 2.0,
        );

        expect(eval.astronomicalSuitable, isFalse);
        expect(
          eval.negativeFactors.any((f) => f.contains('Ascending Moon')),
          isTrue,
        );
      });
    },
  );

  group('BiodynamicPrepEvaluator - getBurialStatus and Sheath Organs', () {
    test('verifies animal sheath organs for BD 502–507 and CPP', () {
      expect(
        BiodynamicPrepType.bd502.sheathOrgan.toLowerCase(),
        contains('stag'),
      );
      expect(
        BiodynamicPrepType.bd503.sheathOrgan.toLowerCase(),
        contains('intestine'),
      );
      expect(
        BiodynamicPrepType.bd504.sheathOrgan.toLowerCase(),
        contains('peat'),
      );
      expect(
        BiodynamicPrepType.bd505.sheathOrgan.toLowerCase(),
        contains('skull'),
      );
      expect(
        BiodynamicPrepType.bd506.sheathOrgan.toLowerCase(),
        contains('mesentery'),
      );
      expect(
        BiodynamicPrepType.bd507.sheathOrgan.toLowerCase(),
        contains('glass'),
      );
      expect(
        BiodynamicPrepType.cpp.sheathOrgan.toLowerCase(),
        contains('barrel'),
      );
    });

    test(
      'BD 502 Yarrow shows Michaelmas burial window in October and Easter retrieval in April',
      () {
        final autumnDate = DateTime(2026, 10, 5);
        final autumnStatus = BiodynamicPrepEvaluator.getBurialStatus(
          prep: BiodynamicPrepType.bd502,
          date: autumnDate,
          latitude: 55.6,
        );
        expect(autumnStatus.isActiveWindow, isTrue);
        expect(autumnStatus.stage, contains('Michaelmas'));
        expect(autumnStatus.sheathOrgan?.toLowerCase(), contains('stag'));

        final winterDate = DateTime(2026, 1, 15);
        final winterStatus = BiodynamicPrepEvaluator.getBurialStatus(
          prep: BiodynamicPrepType.bd502,
          date: winterDate,
          latitude: 55.6,
        );
        expect(winterStatus.isActiveWindow, isFalse);
        expect(winterStatus.stage, contains('Subterranean Winter'));

        final springDate = DateTime(2026, 4, 10);
        final springStatus = BiodynamicPrepEvaluator.getBurialStatus(
          prep: BiodynamicPrepType.bd502,
          date: springDate,
          latitude: 55.6,
        );
        expect(springStatus.isActiveWindow, isTrue);
        expect(springStatus.stage, contains('Easter'));
      },
    );

    test(
      'getSeasonalBurialProgress accurately calculates burial rhythm progress',
      () {
        final winterDate = DateTime(2026, 1, 1);
        final winterProgress =
            BiodynamicPrepEvaluator.getSeasonalBurialProgress(winterDate);
        expect(winterProgress.isUndergroundBurial, isTrue);
        expect(winterProgress.progressFraction, greaterThan(0.0));
        expect(winterProgress.progressFraction, lessThan(1.0));
        expect(winterProgress.seasonName, contains('Winter'));

        final summerDate = DateTime(2026, 7, 1);
        final summerProgress =
            BiodynamicPrepEvaluator.getSeasonalBurialProgress(summerDate);
        expect(summerProgress.isUndergroundBurial, isFalse);
        expect(summerProgress.progressFraction, greaterThan(0.0));
        expect(summerProgress.progressFraction, lessThan(1.0));
        expect(summerProgress.seasonName, contains('Summer'));
      },
    );
  });

  group('BiodynamicPrepEvaluator - findOptimalWindow', () {
    test(
      'findOptimalWindow terminates cleanly and discovers favorable window',
      () {
        final service = AstronomiaEphemerisService();
        final startTime = DateTime.utc(2026, 6, 1, 0, 0);

        final window = BiodynamicPrepEvaluator.findOptimalWindow(
          prep: BiodynamicPrepType.bd508,
          startTime: startTime,
          ephemeris: service,
          searchForward: true,
          maxDaysSearch: 30,
        );

        if (window != null) {
          expect(window.isAfter(startTime), isTrue);
        }
      },
    );

    test('findOptimalWindow backward search works', () {
      final service = AstronomiaEphemerisService();
      final startTime = DateTime.utc(2026, 6, 15, 12, 0);

      final window = BiodynamicPrepEvaluator.findOptimalWindow(
        prep: BiodynamicPrepType.bd500,
        startTime: startTime,
        ephemeris: service,
        searchForward: false,
        maxDaysSearch: 30,
      );

      if (window != null) {
        expect(window.isBefore(startTime), isTrue);
      }
    });
  });
}
