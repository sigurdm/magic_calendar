import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:magic_calendar/src/services/ephemeris_service.dart";
import "package:magic_calendar/src/ui/painters/infinite_timeline_painter.dart";

final class _StubEphemerisService with EphemerisService {
  @override
  SunriseSunsetInfo getSunriseSunset(DateTime date, double lat, double lon) =>
      SunriseSunsetInfo(
        sunrise: DateTime(date.year, date.month, date.day, 6),
        sunset: DateTime(date.year, date.month, date.day, 18),
        noon: DateTime(date.year, date.month, date.day, 12),
      );

  @override
  double getMoonLongitude(DateTime time) => 0.0;
  @override
  double getMoonDeclination(DateTime time) => 0.0;
  @override
  bool isNearNode(DateTime time) => false;
  @override
  bool isNearPerigee(DateTime time) => false;
  @override
  bool isNearApogee(DateTime time) => false;
  @override
  bool isMoonSaturnOpposition(DateTime time) => false;
  @override
  bool isMoonSquareNode(DateTime time) => false;
  @override
  MoonPhaseInfo getMoonPhase(DateTime time) => const MoonPhaseInfo(
    illuminatedFraction: 0.5,
    isWaxing: false,
    phaseAngle: 90.0,
  );
  @override
  List<PlanetInfo> getPlanets(DateTime time) => [];
  @override
  List<CalendarInterval> getIntervals(DateTime start, DateTime end) => [];
}

void main() {
  group("InfiniteTimelinePainter Transition Envelopes & Gray Day Feathering", () {
    test(
      "paints soft gradient transitions between qualities and feathered Gray Day without error",
      () {
        final base = DateTime(2026, 6, 21);
        final intervals = [
          CalendarInterval(
            start: base,
            end: base.add(const Duration(hours: 6)),
            quality: PlantQuality.fruit,
            isGrayDay: false,
            message: "Fruit",
          ),
          CalendarInterval(
            start: base.add(const Duration(hours: 6)),
            end: base.add(const Duration(hours: 12)),
            quality: PlantQuality.root,
            isGrayDay: false,
            message: "Root",
          ),
          CalendarInterval(
            start: base.add(const Duration(hours: 12)),
            end: base.add(const Duration(hours: 18)),
            quality: PlantQuality.none,
            isGrayDay: true,
            message: "Gray Day",
          ),
          CalendarInterval(
            start: base.add(const Duration(hours: 18)),
            end: base.add(const Duration(hours: 24)),
            quality: PlantQuality.flower,
            isGrayDay: false,
            message: "Flower",
          ),
        ];

        final painter = InfiniteTimelinePainter(
          centerTime: base.add(const Duration(hours: 12)),
          hourWidth: 20.0,
          intervals: intervals,
          weatherData: [],
          ephemeris: _StubEphemerisService(),
          latitude: 47.4814,
          longitude: 7.6178,
          showBiodynamicOverlay: true,
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(800, 200);

        expect(() => painter.paint(canvas, size), returnsNormally);
        final picture = recorder.endRecording();
        expect(picture, isNotNull);
      },
    );

    test("paints isolated Gray Day with feathered entry and exit", () {
      final base = DateTime(2026, 6, 21);
      final intervals = [
        CalendarInterval(
          start: base.add(const Duration(hours: 4)),
          end: base.add(const Duration(hours: 10)),
          quality: PlantQuality.none,
          isGrayDay: true,
          message: "Isolated Gray Day",
        ),
      ];

      final painter = InfiniteTimelinePainter(
        centerTime: base.add(const Duration(hours: 7)),
        hourWidth: 15.0,
        intervals: intervals,
        weatherData: [],
        ephemeris: _StubEphemerisService(),
        latitude: 47.4814,
        longitude: 7.6178,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(600, 200);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test(
      "paints zoom-adaptive sunlight strip across zoom scales without error",
      () {
        final base = DateTime(2026, 6, 21);
        final zoomLevels = [0.5, 1.0, 2.5, 5.0, 10.0, 25.0, 50.0];

        for (final hw in zoomLevels) {
          final painter = InfiniteTimelinePainter(
            centerTime: base,
            hourWidth: hw,
            intervals: [],
            weatherData: [],
            ephemeris: _StubEphemerisService(),
            latitude: 54.9037,
            longitude: 10.6074,
          );

          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          const size = Size(1000, 250);

          expect(
            () => painter.paint(canvas, size),
            returnsNormally,
            reason: 'Failed at hourWidth: $hw',
          );
          final picture = recorder.endRecording();
          expect(picture, isNotNull);
        }
      },
    );

    test("inspects rendered pixel colors of sunlight strip", () async {
      final base = DateTime(2026, 9, 4, 12, 0); // Noon
      final painter = InfiniteTimelinePainter(
        centerTime: base,
        hourWidth: 10.0,
        intervals: [],
        weatherData: [],
        ephemeris: _StubEphemerisService(),
        latitude: 54.9037,
        longitude: 10.6074,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(1000, 200);

      painter.paint(canvas, size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1000, 200);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      expect(byteData, isNotNull);

      // Center pixel is at x=500, y=37
      final index = (37 * 1000 + 500) * 4;
      final r = byteData!.getUint8(index);
      final g = byteData.getUint8(index + 1);
      final b = byteData.getUint8(index + 2);
      final a = byteData.getUint8(index + 3);
      debugPrint('Rendered center pixel at (500, 37): rgba($r, $g, $b, $a)');
    });
  });
}
