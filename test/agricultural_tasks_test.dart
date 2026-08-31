import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/agricultural_task_evaluator.dart';
import 'package:magic_calendar/src/core/models/models.dart';
import 'package:magic_calendar/src/ui/theme/goethean_palette.dart';

void main() {
  CalendarInfo createTestCalendarInfo({
    PlantQuality quality = PlantQuality.fruit,
    bool isDescending = true,
    bool isWaxing = false,
    bool isGrayDay = false,
  }) {
    return CalendarInfo(
      quality: quality,
      isGrayDay: isGrayDay,
      message: 'Test Info',
      sapFlow: isDescending
          ? 'Descending: Sap recedes to roots'
          : 'Ascending: Sap rises to leaves and fruit',
      vitality: isWaxing ? 'Waxing Gibbous' : 'Waning Crescent',
      moonPhase: MoonPhaseInfo(
        illuminatedFraction: 0.4,
        isWaxing: isWaxing,
        phaseAngle: isWaxing ? 60.0 : 240.0,
      ),
      planets: [],
    );
  }

  group('AgriculturalTaskEvaluator - Pruning Logic', () {
    test('Descending Moon + Fruit Day is optimal for fruit tree and vine pruning', () {
      final info = createTestCalendarInfo(
        quality: PlantQuality.fruit,
        isDescending: true,
        isWaxing: false,
        isGrayDay: false,
      );

      final advice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.pruning,
        calendarInfo: info,
        time: DateTime.utc(2026, 3, 15, 14, 0),
      );

      expect(advice.suitability, TaskSuitability.optimal);
      expect(advice.cosmicReasoning, contains('OPTIMAL'));
      expect(advice.cosmicReasoning, contains('Fruit/Warmth'));
      expect(advice.practicalAction, contains('Prune fruit trees'));
      expect(advice.hasWeatherConflict, isFalse);
    });

    test('Ascending Moon strictly prohibits pruning due to sap bleeding', () {
      final info = createTestCalendarInfo(
        quality: PlantQuality.fruit,
        isDescending: false, // Ascending!
        isWaxing: true,
        isGrayDay: false,
      );

      final advice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.pruning,
        calendarInfo: info,
        time: DateTime.utc(2026, 3, 15, 14, 0),
      );

      expect(advice.suitability, TaskSuitability.restricted);
      expect(advice.cosmicReasoning, contains('PROHIBITED'));
      expect(advice.cosmicReasoning, contains('Ascending Moon'));
      expect(advice.cosmicReasoning, contains('bleeding'));
    });

    test('Leaf/Water Day strictly prohibits pruning due to fungal rot risk', () {
      final info = createTestCalendarInfo(
        quality: PlantQuality.leaf, // Leaf day!
        isDescending: true,
        isWaxing: false,
        isGrayDay: false,
      );

      final advice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.pruning,
        calendarInfo: info,
        time: DateTime.utc(2026, 3, 15, 14, 0),
      );

      expect(advice.suitability, TaskSuitability.restricted);
      expect(advice.cosmicReasoning, contains('PROHIBITED'));
      expect(advice.cosmicReasoning, contains('Leaf/Water Day'));
      expect(advice.terrestrialReasoning, contains('canker'));
    });

    test('Pruning on Gray Day is restricted', () {
      final info = createTestCalendarInfo(
        quality: PlantQuality.fruit,
        isDescending: true,
        isWaxing: false,
        isGrayDay: true,
      );

      final advice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.pruning,
        calendarInfo: info,
        time: DateTime.utc(2026, 3, 15, 14, 0),
      );

      expect(advice.suitability, TaskSuitability.restricted);
      expect(advice.cosmicReasoning, contains('Cosmic Rest Window'));
    });

    test('Freezing weather creates weather conflict on pruning', () {
      final info = createTestCalendarInfo(
        quality: PlantQuality.fruit,
        isDescending: true,
        isWaxing: false,
      );
      final freezingWeather = WeatherDataPoint(
        time: DateTime.utc(2026, 2, 10, 10, 0),
        temperature: -3.0,
        windSpeed: 2.0,
        windDirection: 180,
        cloudCover: 20,
        precipitation: 0.0,
      );

      final advice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.pruning,
        calendarInfo: info,
        time: DateTime.utc(2026, 2, 10, 10, 0),
        weather: freezingWeather,
      );

      expect(advice.hasWeatherConflict, isTrue);
      expect(advice.suitability, TaskSuitability.restricted);
      expect(advice.terrestrialReasoning, contains('Freezing weather'));
    });
  });

  group('AgriculturalTaskEvaluator - Soil Cultivation Logic', () {
    test('Morning shallow hoeing scalp weeds during Earth exhalation', () {
      final info = createTestCalendarInfo(
        quality: PlantQuality.root,
        isDescending: true,
        isWaxing: false,
      );

      final advice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.soilCultivation,
        calendarInfo: info,
        time: DateTime.utc(2026, 5, 10, 8, 30), // Morning: 08:30
      );

      expect(advice.title, contains('Morning Shallow Hoeing'));
      expect(advice.suitability, TaskSuitability.optimal);
      expect(advice.cosmicReasoning, contains('Morning Exhalation'));
      expect(advice.practicalAction, contains('Shallow surface hoeing'));
      expect(advice.hasWeatherConflict, isFalse);
    });

    test('Afternoon deep cultivation aerates roots during Earth inhalation', () {
      final info = createTestCalendarInfo(
        quality: PlantQuality.root,
        isDescending: true,
        isWaxing: false,
      );

      final advice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.soilCultivation,
        calendarInfo: info,
        time: DateTime.utc(2026, 5, 10, 15, 0), // Afternoon: 15:00
      );

      expect(advice.title, contains('Afternoon Deep Cultivation'));
      expect(advice.suitability, TaskSuitability.optimal);
      expect(advice.cosmicReasoning, contains('Inhalation'));
      expect(advice.practicalAction, contains('Deep root aeration'));
      expect(advice.hasWeatherConflict, isFalse);
    });

    test('Waterlogging (> 2.0 mm rain) restricts tillage to protect soil structure', () {
      final info = createTestCalendarInfo(
        quality: PlantQuality.root,
        isDescending: true,
      );
      final wetWeather = WeatherDataPoint(
        time: DateTime.utc(2026, 5, 10, 15, 0),
        temperature: 15.0,
        windSpeed: 2.0,
        windDirection: 90,
        cloudCover: 100,
        precipitation: 4.5, // > 2.0 mm!
      );

      final advice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.soilCultivation,
        calendarInfo: info,
        time: DateTime.utc(2026, 5, 10, 15, 0),
        weather: wetWeather,
      );

      expect(advice.hasWeatherConflict, isTrue);
      expect(advice.suitability, TaskSuitability.restricted);
      expect(advice.terrestrialReasoning, contains('waterlogged'));
      expect(advice.practicalAction, contains('Cease all tillage'));
    });
  });

  group('AgriculturalTaskEvaluator - Storage vs Fresh Harvest', () {
    test('Waning Moon + Root Day is optimal for cellar storage harvest', () {
      final info = createTestCalendarInfo(
        quality: PlantQuality.root,
        isDescending: true,
        isWaxing: false, // Waning!
      );

      final advice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.harvestStorage,
        calendarInfo: info,
        time: DateTime.utc(2026, 9, 20, 11, 0),
      );

      expect(advice.suitability, TaskSuitability.optimal);
      expect(advice.cosmicReasoning, contains('OPTIMAL'));
      expect(advice.cosmicReasoning, contains('Waning Moon'));
      expect(advice.practicalAction, contains('cellar'));
    });

    test('Waxing Moon or Leaf Day is unfavorable for cellar storage', () {
      final infoWaxing = createTestCalendarInfo(
        quality: PlantQuality.root,
        isWaxing: true, // Waxing!
      );

      final adviceWaxing = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.harvestStorage,
        calendarInfo: infoWaxing,
        time: DateTime.utc(2026, 9, 20, 11, 0),
      );

      expect(adviceWaxing.suitability, TaskSuitability.unfavorable);
      expect(adviceWaxing.cosmicReasoning, contains('Waxing Moon'));

      final infoLeaf = createTestCalendarInfo(
        quality: PlantQuality.leaf, // Leaf day!
        isWaxing: false,
      );

      final adviceLeaf = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.harvestStorage,
        calendarInfo: infoLeaf,
        time: DateTime.utc(2026, 9, 20, 11, 0),
      );

      expect(adviceLeaf.suitability, TaskSuitability.unfavorable);
      expect(adviceLeaf.cosmicReasoning, contains('Leaf/Water Day'));
    });

    test('Waxing Moon during morning exhalation is optimal for fresh harvest', () {
      final info = createTestCalendarInfo(
        quality: PlantQuality.leaf,
        isWaxing: true, // Waxing!
      );

      final advice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.harvestFresh,
        calendarInfo: info,
        time: DateTime.utc(2026, 6, 12, 9, 0), // 09:00 Morning!
      );

      expect(advice.suitability, TaskSuitability.optimal);
      expect(advice.cosmicReasoning, contains('Waxing Moon'));
      expect(advice.cosmicReasoning, contains('Morning Exhalation'));
      expect(advice.terrestrialReasoning, contains('turgor'));
    });
  });

  group('AgriculturalTaskEvaluator - Timber Felling & Peppering', () {
    test('Waning Moon in Capricorn is optimal for Mondholz timber felling', () {
      final info = createTestCalendarInfo(
        quality: PlantQuality.root,
        isWaxing: false, // Waning!
      );

      final advice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.timberFelling,
        calendarInfo: info,
        time: DateTime.utc(2026, 1, 15, 10, 0),
        constellation: 'Capricorn',
      );

      expect(advice.suitability, TaskSuitability.optimal);
      expect(advice.cosmicReasoning, contains('Mondholz'));
      expect(advice.cosmicReasoning, contains('Capricorn'));
      expect(advice.terrestrialReasoning, contains('beetles'));
    });

    test('Waxing Moon is unfavorable for timber felling', () {
      final info = createTestCalendarInfo(
        quality: PlantQuality.root,
        isWaxing: true,
      );

      final advice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.timberFelling,
        calendarInfo: info,
        time: DateTime.utc(2026, 1, 15, 10, 0),
        constellation: 'Capricorn',
      );

      expect(advice.suitability, TaskSuitability.unfavorable);
      expect(advice.cosmicReasoning, contains('Waxing Moon'));
    });

    test('Weed peppering is optimal when Moon is in Leo', () {
      final info = createTestCalendarInfo(
        quality: PlantQuality.fruit,
      );

      final advice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.peppering,
        calendarInfo: info,
        time: DateTime.utc(2026, 7, 20, 14, 0),
        constellation: 'Leo',
      );

      expect(advice.suitability, TaskSuitability.optimal);
      expect(advice.title, contains('Weed Peppering'));
      expect(advice.cosmicReasoning, contains('Leo'));
      expect(advice.cosmicReasoning, contains('seed reproductive vitality'));
    });

    test('Pest peppering is optimal when Moon is in Scorpio', () {
      final info = createTestCalendarInfo(
        quality: PlantQuality.leaf,
      );

      final advice = AgriculturalTaskEvaluator.evaluateTask(
        task: AgriculturalTaskType.peppering,
        calendarInfo: info,
        time: DateTime.utc(2026, 7, 25, 14, 0),
        constellation: 'Scorpio',
      );

      expect(advice.suitability, TaskSuitability.optimal);
      expect(advice.title, contains('Pest Peppering'));
      expect(advice.cosmicReasoning, contains('Scorpio'));
      expect(advice.cosmicReasoning, contains('invertebrate'));
    });

    test('evaluateAllTasks returns all 6 agricultural tasks', () {
      final info = createTestCalendarInfo();

      final allAdvice = AgriculturalTaskEvaluator.evaluateAllTasks(
        calendarInfo: info,
        time: DateTime.utc(2026, 5, 1, 10, 0),
      );

      expect(allAdvice.length, 6);
      expect(
        allAdvice.map((a) => a.task).toSet(),
        AgriculturalTaskType.values.toSet(),
      );
    });
  });

  group('Goethean Nature Palette Specification', () {
    test('validates Goethean nature color values', () {
      expect(GoetheanPalette.rootEarth, const Color(0xFFC86D51));
      expect(GoetheanPalette.leafWater, const Color(0xFF5B8A4E));
      expect(GoetheanPalette.flowerAir, const Color(0xFFA594C4));
      expect(GoetheanPalette.fruitWarmth, const Color(0xFFE5A93C));
      expect(GoetheanPalette.compostDark, const Color(0xFF191715));
      expect(GoetheanPalette.topsoilWarm, const Color(0xFF221F1B));

      expect(GoetheanPalette.getColor(PlantQuality.root), GoetheanPalette.rootEarth);
      expect(GoetheanPalette.getColor(PlantQuality.leaf), GoetheanPalette.leafWater);
      expect(GoetheanPalette.getColor(PlantQuality.flower), GoetheanPalette.flowerAir);
      expect(GoetheanPalette.getColor(PlantQuality.fruit), GoetheanPalette.fruitWarmth);
    });
  });
}
