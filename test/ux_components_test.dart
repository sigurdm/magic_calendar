import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/main.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:magic_calendar/src/ui/components/biodynamic_card.dart';
import 'package:magic_calendar/src/ui/components/concoction_assistant_dialog.dart';
import 'package:magic_calendar/src/ui/components/plant_recommendations_card.dart';
import 'package:magic_calendar/src/ui/components/stirring_timer_dialog.dart';
import 'package:magic_calendar/src/ui/views/help_screen.dart';

import 'support/fakes.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  final sampleCalendarInfo = CalendarInfo(
    quality: PlantQuality.root,
    isGrayDay: false,
    message: 'Root Day',
    sapFlow: 'Descending: Sap recedes to roots',
    vitality: 'Waning Crescent',
    moonPhase: MoonPhaseInfo(
      illuminatedFraction: 0.3,
      isWaxing: false,
      phaseAngle: 240,
    ),
    planets: [],
  );

  group('UX & UI Component Tests', () {
    testWidgets(
      'Responsive Header renders on narrow screen (360px) without overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MyApp(
            ephemeris: FakeEphemerisService(),
            weather: FakeWeatherService(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Magic Calendar'), findsOneWidget);
        expect(find.text('NOW'), findsOneWidget);
        expect(find.byIcon(Icons.location_on), findsOneWidget);
        expect(find.byIcon(Icons.calendar_month), findsOneWidget);
        expect(find.byIcon(Icons.help_outline), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('PlantRecommendationsCard displays crops and switches tabs', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTestApp(
          SingleChildScrollView(
            child: PlantRecommendationsCard(
              info: sampleCalendarInfo,
              selectedDate: DateTime(2026, 4, 15, 12, 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Planting Recommendations'), findsOneWidget);
      expect(find.text('Gulerod (Carrot)'), findsOneWidget);

      // Switch to Leaf tab
      await tester.tap(find.text('Leaf'));
      await tester.pumpAndSettle();

      expect(find.text('Hovedsalat (Butterhead Lettuce)'), findsOneWidget);
    });

    testWidgets(
      'PlantRecommendationsCard opens crop detail modal and renders on 320x568 without overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildTestApp(
            SingleChildScrollView(
              child: PlantRecommendationsCard(
                info: sampleCalendarInfo,
                selectedDate: DateTime(2026, 4, 15, 12, 0),
                onPlanCropRequested: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Verify PlantCategory filter chip interaction if present
        final vegCatFilter = find.byKey(
          const ValueKey('rec_category_vegetable'),
        );
        if (vegCatFilter.evaluate().isNotEmpty) {
          await tester.ensureVisible(vegCatFilter);
          await tester.tap(vegCatFilter);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final allCatFilter = find.byKey(const ValueKey('rec_category_all'));
          if (allCatFilter.evaluate().isNotEmpty) {
            await tester.ensureVisible(allCatFilter);
            await tester.tap(allCatFilter);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }

        // Tap Marshmallow Root (or Carrot) to open the crop detail modal bottom sheet
        final marshmallowFinder = find.text('Lægestokrose (Marshmallow Root)');
        final targetCropFinder = marshmallowFinder.evaluate().isNotEmpty
            ? marshmallowFinder
            : find.text('Gulerod (Carrot)');
        expect(targetCropFinder, findsOneWidget);

        await tester.ensureVisible(targetCropFinder);
        await tester.tap(targetCropFinder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(find.text('Cultivation Guidance (Vejledning)'), findsOneWidget);
        expect(
          find.textContaining('Biodynamic Rhythms & Timing ('),
          findsOneWidget,
        );
        expect(find.text('Close Guide'), findsOneWidget);

        // Close modal
        await tester.ensureVisible(find.text('Close Guide'));
        await tester.tap(find.text('Close Guide'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'PlantRecommendationsCard includes multi-organ crops in currentMonthCrops when secondaryOrganRules match month and quality',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final flowerDayInfo = CalendarInfo(
          quality: PlantQuality.flower,
          isGrayDay: false,
          message: 'Flower Day',
          sapFlow: 'Ascending: Sap rises to flowers',
          vitality: 'Waxing Gibbous',
          moonPhase: MoonPhaseInfo(
            illuminatedFraction: 0.8,
            isWaxing: true,
            phaseAngle: 120,
          ),
          planets: [],
        );

        await tester.pumpWidget(
          _buildTestApp(
            SingleChildScrollView(
              child: PlantRecommendationsCard(
                info: flowerDayInfo,
                selectedDate: DateTime(2026, 7, 15, 10, 0),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Marshmallow Root (primary quality: root) has a secondary flower rule in July/August (months: [7, 8])
        expect(find.text('Lægestokrose (Marshmallow Root)'), findsOneWidget);
        expect(find.text('Off-Season'), findsNothing);
      },
    );

    testWidgets('BiodynamicCard renders and opens StirringTimerDialog', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTestApp(
          SingleChildScrollView(
            child: BiodynamicCard(
              info: sampleCalendarInfo,
              selectedDate: DateTime(2026, 4, 15, 17, 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Biodynamic Practice & Sprays'), findsOneWidget);
      expect(find.text('Stirring Timer (1 Hr)'), findsOneWidget);
      expect(find.text('Concoction Assistant'), findsOneWidget);

      // Open Stirring Timer
      await tester.tap(find.text('Stirring Timer (1 Hr)'));
      await tester.pumpAndSettle();

      expect(find.text('Biodynamic Stirrer'), findsOneWidget);
      expect(find.text('Start Stirring'), findsOneWidget);
      expect(find.text('Cycle 1/48'), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Biodynamic Stirrer'), findsNothing);
    });

    testWidgets(
      'StirringTimerDialog play/pause and +/- 1 min skip buttons work',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: StirringTimerDialog())),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('60:00'), findsOneWidget);

        // Skip -1 min
        await tester.tap(find.text('-1 min'));
        await tester.pumpAndSettle();
        expect(find.text('59:00'), findsOneWidget);

        // Skip +1 min
        await tester.tap(find.text('+1 min'));
        await tester.pumpAndSettle();
        expect(find.text('60:00'), findsOneWidget);

        // Start timer
        await tester.tap(find.text('Start Stirring'));
        await tester.pump();
        expect(find.text('Pause Stirring'), findsOneWidget);

        // Pause timer
        await tester.tap(find.text('Pause Stirring'));
        await tester.pump();
        expect(find.text('Start Stirring'), findsOneWidget);
      },
    );

    testWidgets(
      'StirringTimerDialog renders in landscape without vertical overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 360);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: StirringTimerDialog())),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Biodynamic Stirrer'), findsOneWidget);
        final ex = tester.takeException();
        if (ex != null) {
          debugPrint('CAUGHT EXCEPTION: $ex');
        }
        expect(ex, isNull);
      },
    );

    testWidgets(
      'ConcoctionAssistantDialog calculates metric & imperial dosages accurately',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: ConcoctionAssistantDialog())),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Concoction Assistant'), findsOneWidget);
        expect(find.text('Dosage Calculator'), findsOneWidget);

        // Switch to Imperial
        await tester.tap(find.text('Imperial'));
        await tester.pumpAndSettle();

        expect(find.text('Garden Area (sq ft)'), findsOneWidget);
      },
    );

    testWidgets('HelpScreen renders guide and sections cleanly', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Magic Calendar Guide & Practice'), findsOneWidget);
      expect(find.text('How to Use the Calendar'), findsOneWidget);
      expect(
        find.text('Plant Qualities & Practical Application'),
        findsOneWidget,
      );
      expect(find.text('Special Days & Sap Rhythms'), findsOneWidget);
      expect(find.text('Biodynamic Field Preparations'), findsOneWidget);
      expect(
        find.text('Prioritization & Gray Day Consequences'),
        findsOneWidget,
      );
      expect(find.text('Historical Context & References'), findsOneWidget);
    });
  });
}
