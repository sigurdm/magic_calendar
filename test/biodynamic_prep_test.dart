import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/biodynamic_prep.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:sweph/sweph.dart';

final class MockPrepEphemerisService implements EphemerisService {
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
      expect(
        eval.positiveFactors.any((f) => f.contains('10–28°C')),
        isTrue,
      );
      expect(
        eval.positiveFactors.any((f) => f.contains('<= 6 m/s')),
        isTrue,
      );
      expect(
        eval.positiveFactors.any((f) => f.contains('Leaf Day')),
        isTrue,
      );
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
      expect(
        eval.negativeFactors.any((f) => f.contains('< 5°C')),
        isTrue,
      );
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
      expect(
        eval.negativeFactors.any((f) => f.contains('> 30°C')),
        isTrue,
      );
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
      expect(
        eval.negativeFactors.any((f) => f.contains('> 8 m/s')),
        isTrue,
      );
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
      expect(eveningEval.positiveFactors.any((f) => f.contains('15:00–20:00')), isTrue);
      expect(eveningEval.positiveFactors.any((f) => f.contains('Descending Moon')), isTrue);
    });

    test('BD 501 prefers early morning sunrise and Ascending Moon on Flower/Fruit day', () {
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
      expect(morningEval.positiveFactors.any((f) => f.contains('05:00–09:00')), isTrue);
      expect(morningEval.positiveFactors.any((f) => f.contains('Ascending Moon')), isTrue);
      expect(morningEval.positiveFactors.any((f) => f.contains('Flower')), isTrue);
    });
  });

  group('BiodynamicPrepEvaluator - findOptimalWindow', () {
    test('findOptimalWindow terminates cleanly and discovers favorable window', () {
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
    });

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
