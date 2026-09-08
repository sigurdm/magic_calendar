import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/models/models.dart';
import 'package:magic_calendar/src/ui/components/curved_text.dart';
import 'package:magic_calendar/src/ui/components/plant_quality_card.dart';
import 'package:magic_calendar/src/ui/theme/goethean_palette.dart';

CalendarInfo createInfo({
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
  group('PlantQualityCard Widget Tests', () {
    testWidgets('renders Root Day information cleanly', (tester) async {
      final info = createInfo(quality: PlantQuality.root);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: PlantQualityCard(info: info)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ROOT DAY'), findsOneWidget);
      expect(tester.widget<CurvedText>(find.byType(CurvedText)).text, 'EARTH');
      expect(
        find.textContaining('carrots, beets, potatoes, onions'),
        findsNothing,
      );
      expect(
        find.text(GoetheanPalette.getHarmoniousName(PlantQuality.root)),
        findsNothing,
      );
    });

    testWidgets('renders Leaf Day information cleanly', (tester) async {
      final info = createInfo(quality: PlantQuality.leaf);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: PlantQualityCard(info: info)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('LEAF DAY'), findsOneWidget);
      expect(tester.widget<CurvedText>(find.byType(CurvedText)).text, 'WATER');
      expect(
        find.textContaining('lettuce, spinach, herbs, cabbage'),
        findsNothing,
      );
    });

    testWidgets('renders Flower Day information cleanly', (tester) async {
      final info = createInfo(quality: PlantQuality.flower);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: PlantQualityCard(info: info)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('FLOWER DAY'), findsOneWidget);
      expect(tester.widget<CurvedText>(find.byType(CurvedText)).text, 'AIR');
    });

    testWidgets('renders Fruit Day information cleanly', (tester) async {
      final info = createInfo(quality: PlantQuality.fruit);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: PlantQualityCard(info: info)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('FRUIT DAY'), findsOneWidget);
      expect(tester.widget<CurvedText>(find.byType(CurvedText)).text, 'FIRE');
    });

    testWidgets('renders Special Alignment Day cleanly', (tester) async {
      final info = createInfo(
        quality: PlantQuality.leaf,
        isSpecial: true,
        message: 'Special Leaf Day: Planetary Trine',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: PlantQualityCard(info: info)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('SPECIAL LEAF DAY'), findsOneWidget);
      expect(
        tester.widget<CurvedText>(find.byType(CurvedText)).text,
        'SPECIAL ALIGNMENT',
      );
      expect(
        find.textContaining(
          'Exceptional moisture impulse for lush leafy greens',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders Gray Day blackout cleanly', (tester) async {
      final info = createInfo(
        quality: PlantQuality.none,
        isGrayDay: true,
        message: 'Lunar Node Eclipse - avoid sowing or harvesting.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: PlantQualityCard(info: info)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('GRAY DAY'), findsOneWidget);
      expect(tester.widget<CurvedText>(find.byType(CurvedText)).text, 'REST');
      expect(find.textContaining('Lunar Node Eclipse'), findsOneWidget);
    });

    testWidgets('renders without overflow on narrow 320px screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final info = createInfo(quality: PlantQuality.root);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: PlantQualityCard(info: info)),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('ROOT DAY'), findsOneWidget);
    });

    testWidgets('renders with selectedTime at noon, morning, and night', (
      tester,
    ) async {
      final info = createInfo(quality: PlantQuality.fruit);

      // Morning test
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PlantQualityCard(
                info: info,
                selectedTime: DateTime(2026, 9, 3, 7, 30),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('FRUIT DAY'), findsOneWidget);

      // Noon test
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PlantQualityCard(
                info: info,
                selectedTime: DateTime(2026, 9, 3, 12, 30),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('FRUIT DAY'), findsOneWidget);

      // Night test
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PlantQualityCard(
                info: info,
                selectedTime: DateTime(2026, 9, 3, 23, 0),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('FRUIT DAY'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DiurnalSolarLighting Tests', () {
    test('computes East-angled sunlight in the morning', () {
      final info = createInfo(quality: PlantQuality.flower);
      final morning = DateTime(2026, 9, 3, 7, 30);
      final lighting = DiurnalSolarLighting.compute(morning, info);

      expect(lighting.lx, lessThan(0.0)); // Light from left (East)
      expect(lighting.ly, lessThan(0.0)); // Light from above
      expect(lighting.daylightFactor, greaterThan(0.0));
      expect(lighting.sunAltitude, greaterThan(0.0));
    });

    test('computes overhead zenith sunlight at solar noon', () {
      final info = createInfo(quality: PlantQuality.flower);
      final noon = DateTime(2026, 9, 3, 12, 30);
      final lighting = DiurnalSolarLighting.compute(noon, info);

      expect(lighting.lx.abs(), lessThan(0.15)); // Centered horizontally
      expect(lighting.ly, lessThan(-0.75)); // Steep from overhead
      expect(lighting.daylightFactor, equals(1.0)); // Full daylight
      expect(lighting.sunAltitude, closeTo(1.0, 0.05));
    });

    test('computes West-angled sunlight in the evening', () {
      final info = createInfo(quality: PlantQuality.flower);
      final evening = DateTime(2026, 9, 3, 18, 0);
      final lighting = DiurnalSolarLighting.compute(evening, info);

      expect(lighting.lx, greaterThan(0.0)); // Light from right (West)
      expect(lighting.ly, lessThan(0.0));
      expect(lighting.daylightFactor, greaterThan(0.0));
    });

    test('computes nocturnal moonlight at night', () {
      final info = createInfo(quality: PlantQuality.flower);
      final night = DateTime(2026, 9, 3, 23, 30);
      final lighting = DiurnalSolarLighting.compute(night, info);

      expect(lighting.daylightFactor, equals(0.0));
      expect(lighting.sunAltitude, lessThan(0.0));
    });
  });
}
