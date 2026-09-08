import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/ui/components/curved_text.dart';

void main() {
  group('CurvedText', () {
    test('throws ArgumentError when text is empty', () {
      final path = Path()..lineTo(100, 0);
      expect(
        () => CurvedText(
          text: '',
          path: path,
          style: const TextStyle(fontSize: 12),
        ),
        throwsArgumentError,
      );
    });

    testWidgets('paints along horizontal path without throwing', (
      tester,
    ) async {
      final path = Path()..lineTo(200, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 50,
                child: CurvedText(
                  text: 'TEST CURVE',
                  path: path,
                  style: const TextStyle(fontSize: 14, color: Colors.green),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CurvedText), findsOneWidget);
    });

    testWidgets('paints along bezier curve path without throwing', (
      tester,
    ) async {
      final path = Path()
        ..moveTo(10, 40)
        ..quadraticBezierTo(100, 10, 190, 40);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 60,
                child: CurvedText(
                  text: 'WATER ELEMENT',
                  path: path,
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CurvedText), findsOneWidget);
    });

    testWidgets(
      'paints text containing emojis and special unicode symbols without throwing',
      (tester) async {
        final path = Path()
          ..moveTo(10, 40)
          ..quadraticBezierTo(100, 10, 190, 40);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  height: 60,
                  child: CurvedText(
                    text: '🌿 WATER ELEMENT • SAP RISING 🌿',
                    path: path,
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CurvedText), findsOneWidget);
      },
    );
  });
}
