import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/main.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:magic_calendar/src/ui/components/curved_text.dart';
import 'package:magic_calendar/src/ui/components/plant_quality_card.dart';
import 'package:magic_calendar/src/ui/views/time_scroll_view.dart';

import 'support/fakes.dart';

CalendarInfo _createCalendarInfo({
  required PlantQuality quality,
  bool isSpecial = false,
  bool isGrayDay = false,
  String message = 'Standard Day',
}) {
  return CalendarInfo(
    quality: quality,
    isSpecial: isSpecial,
    isGrayDay: isGrayDay,
    message: message,
    sapFlow: 'Rising',
    vitality: 'Optimal',
    moonPhase: MoonPhaseInfo(
      phaseAngle: 0.5,
      illuminatedFraction: 0.5,
      isWaxing: true,
    ),
    planets: [],
  );
}

void main() {
  const mobileSizes = <String, Size>{
    'iPhone SE (320x568)': Size(320, 568),
    'Android Standard (360x800)': Size(360, 800),
    'iPhone 14 / Modern (390x844)': Size(390, 844),
    'Pixel 7 / Large (412x915)': Size(412, 915),
  };

  group('Mobile Viewport Tests - PlantQualityCard', () {
    for (final entry in mobileSizes.entries) {
      final name = entry.key;
      final size = entry.value;

      testWidgets('renders cleanly on $name for all elements', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (final quality in [
          PlantQuality.root,
          PlantQuality.leaf,
          PlantQuality.flower,
          PlantQuality.fruit,
        ]) {
          final info = _createCalendarInfo(quality: quality);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Center(child: PlantQualityCard(info: info)),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.byType(CurvedText), findsOneWidget);
        }
      });

      testWidgets('renders Special Alignment and Gray Day on $name', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Special alignment
        final specialInfo = _createCalendarInfo(
          quality: PlantQuality.flower,
          isSpecial: true,
          message: 'Special Flower Day: Planetary Trine',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Center(child: PlantQualityCard(info: specialInfo)),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<CurvedText>(find.byType(CurvedText)).text,
          'SPECIAL ALIGNMENT',
        );

        // Gray Day
        final grayInfo = _createCalendarInfo(
          quality: PlantQuality.none,
          isGrayDay: true,
          message: 'Lunar Node Eclipse - avoid planting.',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Center(child: PlantQualityCard(info: grayInfo)),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.widget<CurvedText>(find.byType(CurvedText)).text, 'REST');
      });
    }
  });

  group('Mobile Viewport Tests - Full CalendarHomePage', () {
    for (final entry in mobileSizes.entries) {
      final name = entry.key;
      final size = entry.value;

      testWidgets(
        'renders entire homepage and scrolls without overflow on $name',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final errors = <FlutterErrorDetails>[];
          final oldOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details);
            oldOnError?.call(details);
          };
          addTearDown(() => FlutterError.onError = oldOnError);

          await tester.pumpWidget(
            MyApp(
              ephemeris: FakeEphemerisService(),
              weather: FakeWeatherService(),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Magic Calendar'), findsOneWidget);

          // Scroll down to verify bottom cards render without overflow
          final scrollable = find.byType(CustomScrollView).first;
          await tester.drag(scrollable, const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.drag(scrollable, const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(errors, isEmpty);
        },
      );
    }

    testWidgets('Timeline sticks to top of screen when scrolling down', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MyApp(ephemeris: FakeEphemerisService(), weather: FakeWeatherService()),
      );
      await tester.pumpAndSettle();

      final timelineFinder = find.byType(TimeScrollView);
      expect(timelineFinder, findsOneWidget);

      // Initial position: below HomeHeader and PlantQualityCard
      final initialTop = tester.getTopLeft(timelineFinder).dy;
      expect(initialTop, greaterThan(100.0));

      // Drag down by 600 pixels to scroll past the top cards
      final scrollable = find.byType(CustomScrollView).first;
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pumpAndSettle();

      // Timeline must still be present and pinned to the top of viewport
      expect(timelineFinder, findsOneWidget);
      final pinnedTop = tester.getTopLeft(timelineFinder).dy;
      expect(pinnedTop, closeTo(0.0, 1.0));

      // Further drag down by another 400 pixels
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pumpAndSettle();

      // Still pinned at top
      expect(timelineFinder, findsOneWidget);
      final pinnedTopAfterFurtherScroll = tester.getTopLeft(timelineFinder).dy;
      expect(pinnedTopAfterFurtherScroll, closeTo(0.0, 1.0));

      // Scroll back up to top
      await tester.drag(scrollable, const Offset(0, 1000));
      await tester.pumpAndSettle();

      // Returns to initial unpinned position
      final restoredTop = tester.getTopLeft(timelineFinder).dy;
      expect(restoredTop, equals(initialTop));
    });
  });
}
