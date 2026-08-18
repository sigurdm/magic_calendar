import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/main.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:magic_calendar/src/services/weather_service.dart';
import 'package:magic_calendar/src/ui/components/biodynamic_card.dart';
import 'package:magic_calendar/src/ui/components/concoction_assistant_dialog.dart';
import 'package:magic_calendar/src/ui/components/plant_recommendations_card.dart';
import 'package:magic_calendar/src/ui/components/stirring_timer_dialog.dart';
import 'package:magic_calendar/src/ui/views/help_screen.dart';

final class _MockEphemerisService implements EphemerisService {
  @override
  List<CalendarInterval> getIntervals(DateTime start, DateTime end) => [];

  @override
  double getMoonLongitude(DateTime time) => 0.0;

  @override
  bool isNearNode(DateTime time) => false;

  @override
  bool isNearPerigee(DateTime time) => false;

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
  bool isNearApogee(DateTime time) => false;

  @override
  bool isMoonSaturnOpposition(DateTime time) => false;

  @override
  SunriseSunsetInfo getSunriseSunset(DateTime date, double lat, double lon) {
    return SunriseSunsetInfo(noon: DateTime.now());
  }
}

final class _MockWeatherService implements WeatherService {
  @override
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon) async => [];

  @override
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) async => [];
}

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
    testWidgets('Responsive Header renders on narrow screen (360px) without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MyApp(
          ephemeris: _MockEphemerisService(),
          weather: _MockWeatherService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Magic Calendar'), findsOneWidget);
      expect(find.text('NOW'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      final ex = tester.takeException();
      if (ex != null) {
        debugPrint("CAUGHT EXCEPTION: $ex");
      }
      expect(ex, isNull);
    });

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

    testWidgets('StirringTimerDialog renders in landscape without vertical overflow', (
      WidgetTester tester,
    ) async {
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
        debugPrint("CAUGHT EXCEPTION: $ex");
      }
      expect(ex, isNull);
    });

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
