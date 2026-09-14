import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:magic_calendar/src/ui/views/time_scroll_view.dart';
import 'package:sweph/sweph.dart';

import 'support/fakes.dart';
import 'support/sweph_test_loader.dart';

void main() async {
  await ensureSwephLoaded();
  await Sweph.init();

  group('Interval Merging Logic', () {
    test('merges contiguous 2-hour segments into a single interval', () {
      final service = AstronomiaEphemerisService();
      // April 23, 2026 10:00 to 18:00 (8 hours in Cancer -> Water/Leaf)
      final start = DateTime.utc(2026, 4, 23, 10, 0);
      final end = DateTime.utc(2026, 4, 23, 18, 0);

      final intervals = service.getIntervals(start, end);

      expect(intervals.length, 1);
      expect(intervals[0].start, start);
      expect(intervals[0].end, end);
      expect(intervals[0].quality, PlantQuality.leaf);
    });

    test('splits intervals cleanly across quality transitions', () {
      final service = AstronomiaEphemerisService();
      final start = DateTime.utc(2026, 4, 24, 0, 0);
      final end = DateTime.utc(2026, 4, 26, 0, 0);

      final intervals = service.getIntervals(start, end);

      expect(intervals.length, greaterThanOrEqualTo(2));
      expect(intervals.first.quality, isNot(equals(intervals.last.quality)));
    });
  });

  group('Precaching and Scroll Threshold Discovery', () {
    testWidgets('loads initial 120-day cache window on mount', (
      WidgetTester tester,
    ) async {
      final trackingEphemeris = FakeEphemerisService(
        intervalsAt: singleSpanningInterval,
      );
      final dummyWeather = FakeWeatherService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeScrollView(
              ephemeris: trackingEphemeris,
              weatherService: dummyWeather,
              onTimeSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(trackingEphemeris.getIntervalsCalls.length, 1);
      final call = trackingEphemeris.getIntervalsCalls.first;
      final duration = call.end.difference(call.start);
      expect(duration.inDays, 120);
    });

    testWidgets('does not trigger recalculation when scrolling within buffer', (
      WidgetTester tester,
    ) async {
      final trackingEphemeris = FakeEphemerisService(
        intervalsAt: singleSpanningInterval,
      );
      final dummyWeather = FakeWeatherService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeScrollView(
              ephemeris: trackingEphemeris,
              weatherService: dummyWeather,
              onTimeSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(trackingEphemeris.getIntervalsCalls.length, 1);

      // Perform a small drag (approx 2 days of hours)
      await tester.drag(find.byType(TimeScrollView), const Offset(-100, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Should still be 1 call (no recalculation triggered because center is far from 15-day edge)
      expect(trackingEphemeris.getIntervalsCalls.length, 1);
    });

    testWidgets(
      'triggers recalculation when scrolling past threshold boundary',
      (WidgetTester tester) async {
        final trackingEphemeris = FakeEphemerisService(
          intervalsAt: singleSpanningInterval,
        );
        final dummyWeather = FakeWeatherService();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimeScrollView(
                ephemeris: trackingEphemeris,
                weatherService: dummyWeather,
                onTimeSelected: (_) {},
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(trackingEphemeris.getIntervalsCalls.length, 1);

        // Perform large drags to scroll past 45 days threshold
        for (int i = 0; i < 15; i++) {
          await tester.drag(
            find.byType(TimeScrollView),
            const Offset(-3000, 0),
          );
          await tester.pump(const Duration(milliseconds: 120));
        }

        expect(trackingEphemeris.getIntervalsCalls.length, greaterThan(1));
      },
    );
  });
}
