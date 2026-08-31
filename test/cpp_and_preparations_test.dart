import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/biodynamic_prep.dart';
import 'package:magic_calendar/src/core/models/models.dart';
import 'package:magic_calendar/src/ui/components/biodynamic_card.dart';
import 'package:magic_calendar/src/ui/components/concoction_assistant_dialog.dart';
import 'package:magic_calendar/src/ui/components/stirring_timer_dialog.dart';

void main() {
  group('Module 3 - Cow Pat Pit (CPP) Model & Evaluation', () {
    test('BiodynamicPrepType.cpp configuration matches Maria Thun specifications', () {
      const cpp = BiodynamicPrepType.cpp;
      expect(cpp.code, equals('CPP'));
      expect(cpp.commonName, contains('Cow Pat Pit'));
      expect(cpp.commonName, contains('Maria Thun Barrel Compost'));
      expect(cpp.category, equals(PrepCategory.fieldSpray));
      expect(cpp.stirringMinutes, equals(20));
      expect(cpp.sheathOrgan, contains('barrel'));
    });

    test('CPP spray evaluation succeeds in optimal conditions', () {
      final descRootInfo = CalendarInfo(
        quality: PlantQuality.root,
        isGrayDay: false,
        message: 'Root Day',
        sapFlow: 'Descending: Sap recedes to roots',
        vitality: 'Waning Gibbous',
        moonPhase: const MoonPhaseInfo(
          illuminatedFraction: 0.6,
          isWaxing: false,
          phaseAngle: 210.0,
        ),
        planets: const [],
      );

      final eval = BiodynamicPrepEvaluator.evaluateSpray(
        prep: BiodynamicPrepType.cpp,
        time: DateTime(2026, 5, 20, 17, 0),
        calendarInfo: descRootInfo,
        temperature: 16.0,
        windSpeed: 2.5,
        precipitation: 0.0,
      );

      expect(eval.level, equals(PrepSuitabilityLevel.optimal));
      expect(eval.isFavorable, isTrue);
      expect(eval.weatherSuitable, isTrue);
      expect(eval.astronomicalSuitable, isTrue);
      expect(eval.negativeFactors, isEmpty);
      expect(eval.positiveFactors.any((f) => f.contains('Descending Moon')), isTrue);
      expect(eval.positiveFactors.any((f) => f.contains('15:00–20:00')), isTrue);
      expect(eval.positiveFactors.any((f) => f.contains('>= 8°C')), isTrue);
      expect(eval.positiveFactors.any((f) => f.contains('<= 5 m/s')), isTrue);
    });

    test('CPP spray evaluation enforces weather thresholds (wind <= 5 m/s, temp >= 8°C)', () {
      final descInfo = CalendarInfo(
        quality: PlantQuality.leaf,
        isGrayDay: false,
        message: '',
        sapFlow: 'Descending',
        vitality: '',
        moonPhase: const MoonPhaseInfo(
          illuminatedFraction: 0.5,
          isWaxing: false,
          phaseAngle: 200.0,
        ),
        planets: const [],
      );

      // Low temp
      final coldEval = BiodynamicPrepEvaluator.evaluateSpray(
        prep: BiodynamicPrepType.cpp,
        time: DateTime(2026, 5, 20, 17, 0),
        calendarInfo: descInfo,
        temperature: 5.0,
        windSpeed: 2.0,
      );
      expect(coldEval.weatherSuitable, isFalse);
      expect(coldEval.negativeFactors.any((f) => f.contains('< 8°C')), isTrue);

      // High wind
      final windyEval = BiodynamicPrepEvaluator.evaluateSpray(
        prep: BiodynamicPrepType.cpp,
        time: DateTime(2026, 5, 20, 17, 0),
        calendarInfo: descInfo,
        temperature: 15.0,
        windSpeed: 6.0,
      );
      expect(windyEval.weatherSuitable, isFalse);
      expect(windyEval.negativeFactors.any((f) => f.contains('> 5 m/s')), isTrue);
    });
  });

  group('Module 3 - Compost Preparations BD 502–507 & Seasonal Burial Rhythms', () {
    test('Every preparation has traditional animal sheath organs defined', () {
      expect(BiodynamicPrepType.bd500.sheathOrgan, contains('horn'));
      expect(BiodynamicPrepType.bd501.sheathOrgan, contains('horn'));
      expect(BiodynamicPrepType.bd502.sheathOrgan, contains("Stag's bladder"));
      expect(BiodynamicPrepType.bd503.sheathOrgan, contains('small intestine'));
      expect(BiodynamicPrepType.bd504.sheathOrgan, contains('peat'));
      expect(BiodynamicPrepType.bd505.sheathOrgan, contains('skull'));
      expect(BiodynamicPrepType.bd506.sheathOrgan, contains('mesentery'));
      expect(BiodynamicPrepType.bd507.sheathOrgan, contains('glass'));
      expect(BiodynamicPrepType.cpp.sheathOrgan, contains('barrel'));
    });

    test('Tracks Michaelmas (Sept 29) to Easter burial rhythm', () {
      // Michaelmas burial window (October)
      final oct = DateTime(2026, 10, 1);
      final octStatus = BiodynamicPrepEvaluator.getBurialStatus(
        prep: BiodynamicPrepType.bd503,
        date: oct,
        latitude: 50.0,
      );
      expect(octStatus.isActiveWindow, isTrue);
      expect(octStatus.stage, contains('Michaelmas'));
      expect(octStatus.sheathOrgan, contains('intestine'));

      // Easter retrieval window (April)
      final apr = DateTime(2026, 4, 10);
      final aprStatus = BiodynamicPrepEvaluator.getBurialStatus(
        prep: BiodynamicPrepType.bd503,
        date: apr,
        latitude: 50.0,
      );
      expect(aprStatus.isActiveWindow, isTrue);
      expect(aprStatus.stage, contains('Easter'));

      // Winter underground ripening (January)
      final jan = DateTime(2026, 1, 15);
      final janStatus = BiodynamicPrepEvaluator.getBurialStatus(
        prep: BiodynamicPrepType.bd503,
        date: jan,
        latitude: 50.0,
      );
      expect(janStatus.isActiveWindow, isFalse);
      expect(janStatus.stage, contains('Subterranean Winter'));
    });

    test('getSeasonalBurialProgress reports accurate progress and season names', () {
      final winterProgress = BiodynamicPrepEvaluator.getSeasonalBurialProgress(
        DateTime(2026, 1, 1),
      );
      expect(winterProgress.isUndergroundBurial, isTrue);
      expect(winterProgress.seasonName, contains('Winter'));
      expect(winterProgress.progressFraction, inInclusiveRange(0.0, 1.0));

      final summerProgress = BiodynamicPrepEvaluator.getSeasonalBurialProgress(
        DateTime(2026, 6, 21),
      );
      expect(summerProgress.isUndergroundBurial, isFalse);
      expect(summerProgress.seasonName, contains('Summer'));
      expect(summerProgress.progressFraction, inInclusiveRange(0.0, 1.0));
    });
  });

  group('Module 3 - Concoction Catalog & Assistant Dialog', () {
    test('ConcoctionCatalog contains cpp_barrel_compost recipe with Maria Thun rates', () {
      final cppRecipe = ConcoctionCatalog.recipes.firstWhere(
        (r) => r.id == 'cpp_barrel_compost',
      );
      expect(cppRecipe.titleEn, contains('Cow Pat Pit'));
      expect(cppRecipe.herbGramsPer100Sqm, equals(35.0));
      expect(cppRecipe.waterLitersPer100Sqm, equals(5.0));
      expect(cppRecipe.dilutionRatio, equals(1));
      expect(cppRecipe.steps.any((s) => s.contains('20 minutes')), isTrue);
    });

    testWidgets('ConcoctionAssistantDialog displays CPP recipe and calculates dosages', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConcoctionAssistantDialog(initialRecipeId: 'cpp_barrel_compost'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cow Pat Pit (Maria Thun Barrel Compost)'), findsWidgets);
      expect(find.text('35.0 g'), findsOneWidget); // 35g for 100 m²
      expect(find.text('5.0 L'), findsWidgets); // 5L water & spray for 100 m²
    });
  });

  group('Module 3 - StirringTimerDialog & Goethean Guidance UI', () {
    testWidgets('StirringTimerDialog configures 20-minute timer for CPP (16 cycles of 75s)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StirringTimerDialog(initialPrep: StirringPrepType.cpp),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('Cycle 1/16'), findsOneWidget);
      expect(find.text('Start Stirring'), findsOneWidget);
      expect(find.text('CPP (Barrel Compost)'), findsOneWidget);

      // Verify Goethean Dynamization Guidance is visible
      expect(find.text('Goethean Dynamization Guidance'), findsOneWidget);
      expect(find.text('Water Source & Warmth'), findsOneWidget);
      expect(find.text('Vessel Materiality'), findsOneWidget);
      expect(find.text('Vortex & Dynamic Chaos'), findsOneWidget);
      expect(find.text('Droplet Atomization & Spraying'), findsOneWidget);
      expect(find.textContaining('Coarse Soil Droplets'), findsOneWidget);

      // Switch to BD 501
      await tester.tap(find.text('BD 501 (Silica)'));
      await tester.pumpAndSettle();

      expect(find.text('60:00'), findsOneWidget);
      expect(find.text('Cycle 1/48'), findsOneWidget);
      expect(find.textContaining('Ultra-Fine Floating Mist'), findsOneWidget);
    });
  });

  group('Module 3 - BiodynamicCard Integration', () {
    testWidgets('BiodynamicCard displays optimal CPP window and compost burial cycle', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final descRootInfo = CalendarInfo(
        quality: PlantQuality.root,
        isGrayDay: false,
        message: 'Root Day',
        sapFlow: 'Descending: Earth Inhalation',
        vitality: 'Waning Crescent',
        moonPhase: const MoonPhaseInfo(
          illuminatedFraction: 0.3,
          isWaxing: false,
          phaseAngle: 240,
        ),
        planets: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: BiodynamicCard(
                info: descRootInfo,
                selectedDate: DateTime(2026, 5, 10, 17, 0),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Biodynamic Practice & Sprays'), findsOneWidget);
      expect(find.text('Stirring Timer (1 Hr)'), findsOneWidget);
      expect(find.text('CPP Stirrer (20 Min)'), findsOneWidget);
      expect(find.text('Concoction Assistant'), findsOneWidget);
      expect(find.textContaining('BD 500 Horn Manure & CPP Cow Pat Pit'), findsOneWidget);
      expect(find.text('Compost Preparations (BD 502–507)'), findsOneWidget);
      expect(find.textContaining('BD 502 Yarrow: Stag bladder'), findsOneWidget);
      expect(find.textContaining('BD 503 Chamomile: Cow intestine'), findsOneWidget);
      expect(find.textContaining('BD 505 Oak Bark: Animal skull'), findsOneWidget);
    });
  });
}
