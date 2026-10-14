import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/agricultural_task_evaluator.dart';
import 'package:magic_calendar/src/core/biodynamic_prep.dart';
import 'package:magic_calendar/src/core/ecological_synthesis.dart';
import 'package:magic_calendar/src/core/models/models.dart';
import 'package:magic_calendar/src/core/task_window_planner.dart';
import 'package:magic_calendar/src/core/vegetable_database.dart';
import 'package:magic_calendar/src/ui/components/celestial_details_card.dart';
import 'package:magic_calendar/src/ui/components/plant_recommendations_card.dart';

import 'support/fakes.dart';

FakeEphemerisService _buildOrbitingFakeEphemeris(DateTime epoch) {
  return FakeEphemerisService(
    longitudeAt: (time) {
      final hours = time.difference(epoch).inMinutes / 60.0;
      return (hours * (360.0 / (27.32 * 24.0))) % 360.0;
    },
    declinationAt: (time) {
      final hours = time.difference(epoch).inMinutes / 60.0;
      return 23.4 * math.cos(2 * math.pi * hours / (27.21 * 24.0));
    },
  );
}

void main() {
  final rootDescendingInfo = CalendarInfo(
    quality: PlantQuality.root,
    isGrayDay: false,
    message: 'Root Day',
    sapFlow: 'Descending: Sap recedes to roots',
    vitality: 'Waning Crescent',
    moonPhase: const MoonPhaseInfo(
      illuminatedFraction: 0.3,
      isWaxing: false,
      phaseAngle: 240,
    ),
    planets: const [],
  );

  final fruitDescendingInfo = CalendarInfo(
    quality: PlantQuality.fruit,
    isGrayDay: false,
    message: 'Fruit Day',
    sapFlow: 'Descending: Sap recedes to roots',
    vitality: 'Waning Gibbous',
    moonPhase: const MoonPhaseInfo(
      illuminatedFraction: 0.6,
      isWaxing: false,
      phaseAngle: 210,
    ),
    planets: const [],
  );

  group('MultiHorizonWeatherAnalysis - 72h Antecedent Soil Moisture & API', () {
    test('flags waterlogged soil at 16:00 when 20 mm rain fell that morning even though 16:00 is dry', () {
      final targetTime = DateTime.utc(2026, 5, 10, 16, 0);
      final series = <WeatherDataPoint>[
        // Morning deluge between 06:00 and 10:00 (5 hours * 4.0 mm = 20.0 mm)
        for (int h = 6; h <= 10; h++)
          WeatherDataPoint(
            time: DateTime.utc(2026, 5, 10, h, 0),
            temperature: 11.0,
            windSpeed: 2.5,
            windDirection: 180,
            cloudCover: 95,
            precipitation: 4.0,
          ),
        // Dry afternoon from 11:00 to 16:00
        for (int h = 11; h <= 16; h++)
          WeatherDataPoint(
            time: DateTime.utc(2026, 5, 10, h, 0),
            temperature: 15.0,
            windSpeed: 2.0,
            windDirection: 200,
            cloudCover: 30,
            precipitation: 0.0,
          ),
      ];

      final horizon = MultiHorizonWeatherAnalysis.analyze(
        referenceTime: targetTime,
        weatherSeries: series,
      );

      expect(horizon.currentPoint, isNotNull);
      expect(horizon.currentPoint!.precipitation, 0.0);
      expect(horizon.precipitationLast24h, closeTo(20.0, 1e-6));
      expect(horizon.precipitationLast48h, closeTo(20.0, 1e-6));
      expect(horizon.antecedentPrecipitationIndex, greaterThan(15.0));
      expect(horizon.soilMoisture, SoilMoistureStatus.saturated);
      expect(horizon.isSoilSaturated, isTrue);
      expect(horizon.isAntecedentWaterlogging, isTrue);

      // EcologicalSynthesis flags waterlogging and prevents tillage
      final eco = EcologicalSynthesis.synthesize(
        calendarInfo: rootDescendingInfo,
        time: targetTime,
        weatherSeries: series,
      );
      expect(eco.hasWaterlogging, isTrue);
      expect(eco.hasConflicts, isTrue);
      expect(eco.alerts.any((a) => a.preventsTillage), isTrue);

      // AgriculturalTaskEvaluator restricts afternoon soil cultivation
      final cultAdvice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.soilCultivation,
        calendarInfo: rootDescendingInfo,
        time: targetTime,
        weatherSeries: series,
      );
      expect(cultAdvice.hasWeatherConflict, isTrue);
      expect(cultAdvice.suitability, TaskSuitability.restricted);
      expect(cultAdvice.terrestrialReasoning, contains('48–72h antecedent'));
    });

    test('classifies moderate rain 30h ago as moist & workable and favorable for BD 500 soil spray', () {
      final targetTime = DateTime.utc(2026, 5, 12, 17, 0);
      final series = <WeatherDataPoint>[
        // 6.0 mm gentle rain 30 hours before targetTime
        WeatherDataPoint(
          time: targetTime.subtract(const Duration(hours: 30)),
          temperature: 14.0,
          windSpeed: 3.0,
          windDirection: 180,
          cloudCover: 80,
          precipitation: 6.0,
        ),
        // Dry at targetTime
        WeatherDataPoint(
          time: targetTime,
          temperature: 16.0,
          windSpeed: 2.0,
          windDirection: 180,
          cloudCover: 25,
          precipitation: 0.0,
        ),
      ];

      final horizon = MultiHorizonWeatherAnalysis.analyze(
        referenceTime: targetTime,
        weatherSeries: series,
      );

      expect(horizon.soilMoisture, SoilMoistureStatus.moist);
      expect(horizon.soilMoisture.favorsSoilSpray, isTrue);
      expect(horizon.soilMoisture.preventsTillage, isFalse);

      final bd500Eval = BiodynamicPrepEvaluator.evaluateSpray(
        prep: BiodynamicPrepType.bd500,
        time: targetTime,
        calendarInfo: rootDescendingInfo,
        windSpeed: 2.0,
        precipitation: 0.0,
        horizon: horizon,
      );
      expect(bd500Eval.isFavorable, isTrue);
      expect(
        bd500Eval.positiveFactors.any((f) => f.contains('Moist topsoil')),
        isTrue,
      );
    });
  });

  group('MultiHorizonWeatherAnalysis - 24–48h Post-Task Lookahead', () {
    test('detects spray wash-off risk when rain is forecast within 6 hours after a dry spray hour', () {
      final sprayTime = DateTime.utc(2026, 5, 18, 7, 0);
      final ascFlowerInfo = CalendarInfo(
        quality: PlantQuality.flower,
        isGrayDay: false,
        message: 'Flower Day',
        sapFlow: 'Ascending: Sap rises',
        vitality: 'Waxing',
        moonPhase: const MoonPhaseInfo(
          illuminatedFraction: 0.5,
          isWaxing: true,
          phaseAngle: 90,
        ),
        planets: const [],
      );

      final series = <WeatherDataPoint>[
        // Calm and dry at 07:00
        WeatherDataPoint(
          time: sprayTime,
          temperature: 14.0,
          windSpeed: 1.5,
          windDirection: 180,
          cloudCover: 20,
          precipitation: 0.0,
        ),
        // 3.2 mm rain arrives 3 hours later at 10:00
        WeatherDataPoint(
          time: sprayTime.add(const Duration(hours: 3)),
          temperature: 13.0,
          windSpeed: 4.0,
          windDirection: 220,
          cloudCover: 90,
          precipitation: 3.2,
        ),
      ];

      final horizon = MultiHorizonWeatherAnalysis.analyze(
        referenceTime: sprayTime,
        weatherSeries: series,
      );

      expect(horizon.hasSprayWashoffRisk, isTrue);
      expect(horizon.hasFoliarSprayWashoffRisk, isTrue);
      expect(horizon.precipitationNext6h, closeTo(3.2, 1e-6));

      final eco = EcologicalSynthesis.synthesize(
        calendarInfo: ascFlowerInfo,
        time: sprayTime,
        weatherSeries: series,
      );
      expect(eco.hasSprayWashoffRisk, isTrue);
      expect(eco.hasConflicts, isTrue);
      expect(eco.alerts.any((a) => a.preventsSpray), isTrue);

      final bd501Eval = BiodynamicPrepEvaluator.evaluateSpray(
        prep: BiodynamicPrepType.bd501,
        time: sprayTime,
        calendarInfo: ascFlowerInfo,
        windSpeed: 1.5,
        cloudCover: 20.0,
        precipitation: 0.0,
        horizon: horizon,
      );
      expect(bd501Eval.weatherSuitable, isFalse);
      expect(bd501Eval.isFavorable, isFalse);
      expect(
        bd501Eval.negativeFactors.any((f) => f.contains('within 6h')),
        isTrue,
      );
    });

    test('detects 48h night frost lookahead during a warm afternoon and warns against transplanting and pruning', () {
      final afternoonTime = DateTime.utc(2026, 4, 20, 15, 0);
      final series = <WeatherDataPoint>[
        // Mild 13°C afternoon
        WeatherDataPoint(
          time: afternoonTime,
          temperature: 13.0,
          windSpeed: 2.0,
          windDirection: 180,
          cloudCover: 15,
          precipitation: 0.0,
        ),
        // Clear sky radiation freeze (-1.8°C) 36 hours later
        WeatherDataPoint(
          time: afternoonTime.add(const Duration(hours: 36)),
          temperature: -1.8,
          windSpeed: 1.0,
          windDirection: 45,
          cloudCover: 5,
          precipitation: 0.0,
        ),
      ];

      final eco = EcologicalSynthesis.synthesize(
        calendarInfo: fruitDescendingInfo,
        time: afternoonTime,
        weatherSeries: series,
        latitude: 55.6761,
      );
      expect(eco.hasFrostRisk, isTrue);
      final frostAlert = eco.alerts.firstWhere(
        (a) => a.type == EcologicalAlertType.springFrostRisk,
      );
      expect(frostAlert.valerianSprayAdvised, isTrue);
      expect(frostAlert.title, contains('within 48h'));

      final pruneAdvice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.pruning,
        calendarInfo: fruitDescendingInfo,
        time: afternoonTime,
        weatherSeries: series,
      );
      expect(pruneAdvice.hasWeatherConflict, isTrue);
      expect(pruneAdvice.suitability, TaskSuitability.restricted);
      expect(pruneAdvice.terrestrialReasoning, contains('within 48h'));
    });
  });

  group('Soil Temperature Thresholds vs Crop Germination Minimums', () {
    test('VegetableEntry.minimumGerminationSoilTempC distinguishes hardy, moderate, and warm-season crops', () {
      final pea = VegetableDatabase.findById('shelling_pea')!;
      final carrot = VegetableDatabase.findById('carrot')!;
      final celeriac = VegetableDatabase.findById('celeriac')!;
      final frenchBean = VegetableDatabase.findById('bush_bean')!;
      final tomato = VegetableDatabase.findById('tomato')!;

      expect(pea.minimumGerminationSoilTempC, 5.0);
      expect(carrot.minimumGerminationSoilTempC, 7.0);
      expect(celeriac.minimumGerminationSoilTempC, 10.0);
      expect(frenchBean.minimumGerminationSoilTempC, 12.0);
      expect(tomato.minimumGerminationSoilTempC, 15.0);
    });

    test('TaskWindowPlanner compares 72h lagged soil temperature against crop germination minimum', () {
      final start = DateTime.utc(2026, 4, 25, 8, 0);
      final ephemeris = _buildOrbitingFakeEphemeris(start);
      final pea = VegetableDatabase.findById(
        'shelling_pea',
      )!; // Fruit day, min 5°C
      final frenchBean = VegetableDatabase.findById(
        'bush_bean',
      )!; // Fruit day, min 12°C

      // Build a 10-day weather series where nights are 4°C and afternoons are 13°C,
      // yielding an estimated topsoil temperature around ~8.0°C (warm enough for Pea >= 5°C,
      // but too cold for French Bean < 12°C).
      final forecast = <WeatherDataPoint>[
        for (int h = -48; h <= 240; h += 3)
          WeatherDataPoint(
            time: start.add(Duration(hours: h)),
            temperature:
                (start.add(Duration(hours: h)).hour >= 11 &&
                    start.add(Duration(hours: h)).hour <= 17)
                ? 13.0
                : 4.5,
            windSpeed: 2.5,
            windDirection: 180,
            cloudCover: 40,
            precipitation: 0.0,
          ),
      ];

      final peaWindows = TaskWindowPlanner.findUpcomingWindows(
        action: TaskActionType.sowOutdoor,
        targetQuality: pea.quality,
        crop: pea,
        startTime: start,
        ephemeris: ephemeris,
        weatherForecast: forecast,
        searchDays: 10,
      );
      expect(peaWindows.windows, isNotEmpty);
      final firstPeaWindow = peaWindows.windows.first;
      expect(firstPeaWindow.hasWeatherConflict, isFalse);
      expect(firstPeaWindow.weatherNote, contains('favorable'));

      final beanWindows = TaskWindowPlanner.findUpcomingWindows(
        action: TaskActionType.sowOutdoor,
        targetQuality: frenchBean.quality,
        crop: frenchBean,
        startTime: start,
        ephemeris: ephemeris,
        weatherForecast: forecast,
        searchDays: 10,
      );
      expect(beanWindows.windows, isNotEmpty);
      final firstBeanWindow = beanWindows.windows.first;
      expect(firstBeanWindow.hasWeatherConflict, isTrue);
      expect(firstBeanWindow.weatherNote, contains('Soil Temp Alert'));
      expect(firstBeanWindow.weatherNote, contains('12°C minimum'));
    });
  });

  group('Multi-Horizon Weather UI Surfacing', () {
    testWidgets(
      'PlantRecommendationsCard and CelestialDetailsCard render multi-horizon soil tilth, soil temp, and lookahead pills',
      (tester) async {
        final now = DateTime.utc(2026, 5, 10, 15, 0);
        final series = <WeatherDataPoint>[
          WeatherDataPoint(
            time: now.subtract(const Duration(hours: 12)),
            temperature: 10.0,
            windSpeed: 2.0,
            windDirection: 180,
            cloudCover: 70,
            precipitation: 5.5,
          ),
          WeatherDataPoint(
            time: now,
            temperature: 14.0,
            windSpeed: 3.0,
            windDirection: 180,
            cloudCover: 30,
            precipitation: 0.0,
          ),
          WeatherDataPoint(
            time: now.add(const Duration(hours: 12)),
            temperature: 7.5,
            windSpeed: 2.5,
            windDirection: 180,
            cloudCover: 20,
            precipitation: 0.4,
          ),
        ];
        final weatherNotifier = ValueNotifier<List<WeatherDataPoint>?>(series);
        final dateNotifier = ValueNotifier<DateTime>(now);
        final ephemeris = _buildOrbitingFakeEphemeris(now);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    CelestialDetailsCard(
                      selectedDateNotifier: dateNotifier,
                      weatherNotifier: weatherNotifier,
                      ephemeris: ephemeris,
                    ),
                    PlantRecommendationsCard(
                      info: rootDescendingInfo,
                      selectedDate: now,
                      weatherNotifier: weatherNotifier,
                      ephemeris: ephemeris,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        expect(
          find.byKey(const ValueKey('multi_horizon_synthesis_pills')),
          findsOneWidget,
        );
        expect(find.textContaining('Soil: Moist'), findsOneWidget);
        expect(find.textContaining('Est. Soil: ~'), findsWidgets);
        expect(find.text('Soil Tilth (72h)'), findsOneWidget);
      },
    );
  });
}
