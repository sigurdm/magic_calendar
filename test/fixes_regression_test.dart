import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/algorithm.dart' as algo;
import 'package:magic_calendar/src/repository/open_meteo_client.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:magic_calendar/src/ui/components/location_picker_dialog.dart';
import 'package:magic_calendar/src/ui/painters/infinite_timeline_painter.dart';
import 'package:magic_calendar/src/ui/painters/moon_painter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sweph/sweph.dart';

void main() {
  setUpAll(() async {
    await Sweph.init();
  });

  group('Regression Tests for Verified Bug Fixes', () {
    test(
      'InfiniteTimelinePainter clamps solar dot product to prevent NaN blackout at zenith',
      () {
        final ephemeris = AstronomiaEphemerisService();
        // Paint at equinox noon at latitude 0 (sun at zenith)
        final painter = InfiniteTimelinePainter(
          centerTime: DateTime.utc(2026, 3, 20, 12, 0),
          hourWidth: 10.0,
          intervals: [],
          weatherData: [],
          latitude: 0.0,
          longitude: 0.0,
          ephemeris: ephemeris,
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => painter.paint(canvas, const Size(400, 200)),
          returnsNormally,
        );
      },
    );

    test(
      'InfiniteTimelinePainter paints across DST spring forward transition without error',
      () {
        final ephemeris = AstronomiaEphemerisService();
        // 2026-03-29 is European DST change date (clocks jump forward 1 hour at 02:00)
        final painter = InfiniteTimelinePainter(
          centerTime: DateTime(2026, 3, 29, 12, 0),
          hourWidth: 10.0,
          intervals: [],
          weatherData: [],
          latitude: 55.0,
          longitude: 10.0,
          ephemeris: ephemeris,
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => painter.paint(canvas, const Size(800, 200)),
          returnsNormally,
        );
      },
    );

    test(
      'InfiniteTimelinePainter does not throw division by zero on hourWidth <= 0',
      () {
        final ephemeris = AstronomiaEphemerisService();
        final painter = InfiniteTimelinePainter(
          centerTime: DateTime.utc(2026, 6, 21, 12),
          hourWidth: 0.0, // Zero hour width
          intervals: [],
          weatherData: [],
          latitude: 55.0,
          longitude: 10.0,
          ephemeris: ephemeris,
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => painter.paint(canvas, const Size(400, 200)),
          returnsNormally,
        );
      },
    );

    test(
      'getCalendarInfo computes dynamic sapFlow even with includePlanets: false',
      () {
        final ephemeris = AstronomiaEphemerisService();

        // Test across two dates with opposite lunar declination velocities
        // 2026-03-01 vs 2026-03-15
        final info1 = algo.getCalendarInfo(
          DateTime.utc(2026, 3, 1, 12),
          ephemeris,
          includePlanets: false, // Default is false!
        );
        final info2 = algo.getCalendarInfo(
          DateTime.utc(2026, 3, 15, 12),
          ephemeris,
          includePlanets: false,
        );

        expect(info1.sapFlow, isNotEmpty);
        expect(info2.sapFlow, isNotEmpty);
        // One should be Ascending and the other Descending
        final isDifferent =
            (info1.sapFlow.contains('Ascending') &&
                info2.sapFlow.contains('Descending')) ||
            (info1.sapFlow.contains('Descending') &&
                info2.sapFlow.contains('Ascending'));
        expect(
          isDifferent,
          isTrue,
          reason:
              'sapFlow must vary based on Moon declination even when includePlanets is false',
        );
      },
    );

    test(
      'MoonPainter handles non-square aspect ratio without error and checks equality in shouldRepaint',
      () {
        const info = MoonPhaseInfo(
          illuminatedFraction: 0.5,
          isWaxing: true,
          phaseAngle: 90.0,
        );
        final painter = MoonPainter(info: info);

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        // Non-square size: 200x50
        expect(
          () => painter.paint(canvas, const Size(200, 50)),
          returnsNormally,
        );

        const sameInfo = MoonPhaseInfo(
          illuminatedFraction: 0.5,
          isWaxing: true,
          phaseAngle: 90.0,
        );
        const differentInfo = MoonPhaseInfo(
          illuminatedFraction: 0.6,
          isWaxing: true,
          phaseAngle: 90.0,
        );

        expect(painter.shouldRepaint(MoonPainter(info: sameInfo)), isFalse);
        expect(painter.shouldRepaint(MoonPainter(info: differentInfo)), isTrue);
      },
    );

    test(
      'OpenMeteoClient queries with timezone=UTC and parses UTC timestamps',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.queryParameters['timezone'], equals('UTC'));
          return http.Response('''
{
  "hourly": {
    "time": ["2026-06-21T00:00", "2026-06-21T01:00"],
    "temperature_2m": [15.5, 16.0],
    "wind_speed_10m": [4.2, 5.0],
    "wind_direction_10m": [180, 190],
    "cloudcover": [20, 30],
    "precipitation": [0.0, 0.5]
  }
}
''', 200);
        });

        final client = OpenMeteoClient(client: mockClient);
        final data = await client.getHistoricalData(
          55.0,
          10.0,
          DateTime.utc(2026, 6, 21),
          DateTime.utc(2026, 6, 21),
        );

        expect(data.length, equals(2));
        expect(data.first.time.isUtc, isTrue);
        expect(data.first.time.hour, equals(0));
      },
    );

    testWidgets(
      'LocationPickerDialog instantiates and disposes controllers cleanly',
      (tester) async {
        double savedLat = 0;
        double savedLon = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationPickerDialog(
                initialLatitude: 55.0,
                initialLongitude: 10.0,
                onLocationSaved: (lat, lon) {
                  savedLat = lat;
                  savedLon = lon;
                },
              ),
            ),
          ),
        );

        expect(find.text('Set Location'), findsOneWidget);
        expect(find.text('55.0'), findsOneWidget);
        expect(find.text('10.0'), findsOneWidget);

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(savedLat, equals(55.0));
        expect(savedLon, equals(10.0));
      },
    );
  });
}
