import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/models/agricultural_tasks.dart';
import 'package:magic_calendar/src/ui/theme/biodynamic_icons.dart';

void main() {
  testWidgets('BiodynamicIcon renders all icon types without error', (
    tester,
  ) async {
    for (final type in BiodynamicIconType.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BiodynamicIcon(type: type, size: 24, color: Colors.green),
            ),
          ),
        ),
      );
      expect(find.byType(BiodynamicIcon), findsOneWidget);
    }
  });

  testWidgets('BiodynamicIcon.fromTask renders each agricultural task', (
    tester,
  ) async {
    for (final task in AgriculturalTaskType.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BiodynamicIcon.fromTask(
                task,
                size: 20,
                color: Colors.amber,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(BiodynamicIcon), findsOneWidget);
    }
  });
}
