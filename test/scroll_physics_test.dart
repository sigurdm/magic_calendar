import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/ui/views/time_scroll_view.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('Fling right scrolls to past', (WidgetTester tester) async {
    DateTime? selectedTime;
    final mockEphemeris = FakeEphemerisService();
    final mockWeather = FakeWeatherService();
    final controller = TimeScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeScrollView(
            ephemeris: mockEphemeris,
            weatherService: mockWeather,
            controller: controller,
            onTimeSelected: (time, {immediate = false}) {
              selectedTime = time;
            },
          ),
        ),
      ),
    );

    await tester.pump();

    // Call scrollToNow to set initial time and trigger onTimeSelected
    controller.scrollToNow();
    await tester.pump();

    final startTime = selectedTime;
    expect(startTime, isNotNull);

    // Perform a fling gesture to the right (drag from left to right)
    // This should have positive velocity.
    await tester.fling(find.byType(TimeScrollView), const Offset(200, 0), 1000);

    // Pump to trigger animation frames
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 100)); // Advance animation

    final timeAfterFling = selectedTime;
    expect(timeAfterFling, isNotNull);

    // Flinging right should pull content from left (past) into view.
    // So the center time should move to the past (decrease).
    expect(
      timeAfterFling!.isBefore(startTime!),
      isTrue,
      reason:
          'Flinging right should move time to the past. '
          'Start: $startTime, After: $timeAfterFling',
    );
  });

  testWidgets('Fling left scrolls to future', (WidgetTester tester) async {
    DateTime? selectedTime;
    final mockEphemeris = FakeEphemerisService();
    final mockWeather = FakeWeatherService();
    final controller = TimeScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeScrollView(
            ephemeris: mockEphemeris,
            weatherService: mockWeather,
            controller: controller,
            onTimeSelected: (time, {immediate = false}) {
              selectedTime = time;
            },
          ),
        ),
      ),
    );

    await tester.pump();
    controller.scrollToNow();
    await tester.pump();

    final startTime = selectedTime;
    expect(startTime, isNotNull);

    // Perform a fling gesture to the left (drag from right to left)
    await tester.fling(
      find.byType(TimeScrollView),
      const Offset(-200, 0),
      1000,
    );

    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 100)); // Advance animation

    final timeAfterFling = selectedTime;
    expect(timeAfterFling, isNotNull);

    // Flinging left should pull content from right (future) into view.
    // So the center time should move to the future (increase).
    expect(
      timeAfterFling!.isAfter(startTime!),
      isTrue,
      reason:
          'Flinging left should move time to the future. '
          'Start: $startTime, After: $timeAfterFling',
    );
  });
}
