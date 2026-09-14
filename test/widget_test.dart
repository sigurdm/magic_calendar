import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/main.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(ephemeris: FakeEphemerisService(), weather: FakeWeatherService()),
    );

    expect(find.text('Magic Calendar'), findsOneWidget);
  });
}
