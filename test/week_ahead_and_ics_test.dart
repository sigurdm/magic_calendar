import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/biodynamic_prep.dart';
import 'package:magic_calendar/src/core/ics_calendar_exporter.dart';
import 'package:magic_calendar/src/core/models/models.dart';
import 'package:magic_calendar/src/core/task_window_planner.dart';
import 'package:magic_calendar/src/core/vegetable_database.dart';
import 'package:magic_calendar/src/core/week_ahead_planner.dart';
import 'package:magic_calendar/src/services/ics_file_saver.dart';
import 'package:magic_calendar/src/ui/components/biodynamic_card.dart';
import 'package:magic_calendar/src/ui/components/task_planner_card.dart';
import 'package:magic_calendar/src/ui/components/week_ahead_card.dart';

import 'support/fakes.dart';

FakeEphemerisService _buildOrbitingFakeEphemeris(DateTime epoch) {
  return FakeEphemerisService(
    longitudeAt: (time) {
      final hours = time.difference(epoch).inMinutes / 60.0;
      return (hours * (360.0 / (27.32 * 24.0))) % 360.0;
    },
    declinationAt: (time) {
      final hours = time.difference(epoch).inMinutes / 60.0;
      return 23.4 * math.cos(2 * math.pi * hours / (27.21 * 24.0));
    },
  );
}

void main() {
  group('IcsCalendarExporter — RFC 5545 .ics Generation', () {
    test('fromBiodynamicSpray includes 1-hour stirring VEVENT and VALARM before BD 500/501 spray window', () {
      final sprayStart = DateTime(2026, 4, 18, 16, 0);
      final sprayEnd = DateTime(2026, 4, 18, 19, 0);
      final info = CalendarInfo(
        quality: PlantQuality.root,
        isGrayDay: false,
        message: 'Root Day',
        sapFlow: 'Descending: Sap recedes to roots',
        vitality: 'Waning',
        moonPhase: MoonPhaseInfo(
          illuminatedFraction: 0.4,
          isWaxing: false,
          phaseAngle: 210,
        ),
        planets: const [],
      );

      final event = IcsCalendarExporter.fromBiodynamicSpray(
        preparation: BiodynamicPrepType.bd500,
        sprayStart: sprayStart,
        sprayEnd: sprayEnd,
        calendarInfo: info,
        weatherSummary: 'Dry & calm (15.0°C, 0.0 mm, 2.1 m/s wind)',
        latitude: 55.68,
        longitude: 12.57,
      );

      expect(event.hasStirringWindow, isTrue);
      expect(event.stirringStart, DateTime(2026, 4, 18, 15, 0));
      expect(event.stirringEnd, DateTime(2026, 4, 18, 16, 0));
      expect(event.stirringDuration, const Duration(minutes: 60));

      final ics = IcsCalendarExporter.formatEvent(
        event,
        timestamp: DateTime.utc(2026, 4, 18, 12, 0),
      );

      // Verify CRLF line endings and 75-octet RFC 5545 folding limit
      expect(ics.contains('\r\n'), isTrue);
      final rawLines = ics.split('\r\n');
      for (final line in rawLines) {
        expect(
          utf8.encode(line).length,
          lessThanOrEqualTo(75),
          reason: 'Line exceeded 75 UTF-8 octets: $line',
        );
      }

      // Unfold lines to verify semantic properties
      final unfolded = ics.replaceAll('\r\n ', '');
      expect(unfolded, contains('BEGIN:VCALENDAR'));
      expect(unfolded, contains('VERSION:2.0'));
      expect(
        unfolded,
        contains('SUMMARY:Stir BD 500 Horn Manure (60m Dynamization)'),
      );
      expect(unfolded, contains('DTSTART:20260418T150000'));
      expect(unfolded, contains('DTEND:20260418T160000'));
      expect(
        unfolded,
        contains('SUMMARY:Spray BD 500 Horn Manure (Earth Inhalation)'),
      );
      expect(unfolded, contains('DTSTART:20260418T160000'));
      expect(unfolded, contains('DTEND:20260418T190000'));
      expect(unfolded, contains('TRIGGER:-PT60M'));
      expect(unfolded, contains('END:VCALENDAR'));
    });

    test('fromTaskWindow creates focused 2-hour block around peakTime and escapes special characters', () {
      final carrot = VegetableDatabase.findById('carrot');
      final window = TaskWindow(
        start: DateTime(2026, 4, 20, 8, 0),
        end: DateTime(2026, 4, 21, 20, 0),
        peakTime: DateTime(2026, 4, 20, 16, 0),
        suitability: TaskSuitability.optimal,
        quality: PlantQuality.root,
        isDescending: true,
        isWaxing: false,
        isSpecialTrine: true,
        isInSeason: true,
        headline: 'Root Day • Descending Moon (Pflanzzeit) • Planetary Trine',
        cosmicExplanation:
            'Optimal Root impulse; sow, hoe, and cultivate in afternoon.',
        weatherNote: 'Forecast: 14.5°C, 0.0 mm precip',
      );

      final event = IcsCalendarExporter.fromTaskWindow(
        window: window,
        action: TaskActionType.sowOutdoor,
        crop: carrot,
        latitude: 55.68,
        longitude: 12.57,
      );

      expect(event.start, DateTime(2026, 4, 20, 16, 0));
      expect(event.end, DateTime(2026, 4, 20, 18, 0));
      expect(event.hasStirringWindow, isFalse);
      expect(event.suggestedFileName, endsWith('-2026-04-20.ics'));

      final unfolded = IcsCalendarExporter.formatEvent(event)
          .replaceAll('\r\n ', '');
      expect(unfolded, contains('DTSTART:20260420T160000'));
      expect(unfolded, contains('DTEND:20260420T180000'));
      expect(unfolded, contains('TRIGGER:-PT30M'));
      expect(unfolded, contains(r'sow\, hoe\, and cultivate'));
    });

    test('saveIcsFile writes valid .ics file to target directory', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'magic_calendar_ics_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final event = CalendarExportEvent(
        uid: 'test-1@magic-calendar',
        summary: 'Sow Carrots (Root Day)',
        description: 'Direct sow carrots in afternoon inhalation.',
        start: DateTime(2026, 4, 20, 16, 0),
        end: DateTime(2026, 4, 20, 18, 0),
      );
      final content = IcsCalendarExporter.formatEvent(event);
      final savedPath = await saveIcsFile(
        fileName: event.suggestedFileName,
        content: content,
        directoryPath: tempDir.path,
      );

      expect(savedPath, isNotNull);
      final savedFile = File(savedPath!);
      expect(await savedFile.exists(), isTrue);
      expect(await savedFile.readAsString(), equals(content));
    });
  });

  group('WeekAheadPlanner — 7-Day Biodynamic + Weather Synthesis', () {
    test('ranks dry/calm forecast intersections above rain/wind conflicts and attaches 1h stirring to BD 500/501', () {
      final start = DateTime(2026, 4, 15, 8, 0);
      final ephemeris = _buildOrbitingFakeEphemeris(start);

      // Day 0 (Apr 15): Heavy rain and strong wind (conflict)
      // Day 1..6 (Apr 16..21): Dry and calm (16°C, 0.0 mm, 2.2 m/s)
      final weatherPoints = <WeatherDataPoint>[];
      for (int day = 0; day < 7; day++) {
        for (int hour = 5; hour <= 20; hour++) {
          final pointTime = DateTime(2026, 4, 15 + day, hour);
          final isStormyFirstDay = day == 0;
          weatherPoints.add(
            WeatherDataPoint(
              time: pointTime,
              temperature: isStormyFirstDay ? 6.0 : 16.0,
              windSpeed: isStormyFirstDay ? 9.5 : 2.2,
              windDirection: 180.0,
              cloudCover: isStormyFirstDay ? 95.0 : 20.0,
              precipitation: isStormyFirstDay ? 4.5 : 0.0,
            ),
          );
        }
      }

      final digest = WeekAheadPlanner.buildDigest(
        startTime: start,
        ephemeris: ephemeris,
        weatherForecast: weatherPoints,
        days: 7,
        maxRankedWindows: 12,
      );

      expect(digest.dailyBriefs, hasLength(7));
      expect(
        digest.dailyBriefs.first.weatherStatus,
        WeatherIntersectionStatus.conflict,
      );
      expect(
        digest.dailyBriefs[1].weatherStatus,
        WeatherIntersectionStatus.harmonious,
      );

      expect(digest.rankedWindows, isNotEmpty);
      // Top-ranked window must be harmonious (dry & calm), not the stormy Day 0 window
      expect(
        digest.rankedWindows.first.weatherStatus,
        WeatherIntersectionStatus.harmonious,
      );
      expect(digest.rankedWindows.first.rank, 1);

      // Verify spray windows carry 1-hour stirring start time
      expect(digest.sprayWindows, isNotEmpty);
      for (final spray in digest.sprayWindows) {
        expect(spray.hasStirringLeadTime, isTrue);
        expect(spray.stirringDuration, const Duration(minutes: 60));
        expect(
          spray.stirringStart,
          spray.start.subtract(const Duration(hours: 1)),
        );
        expect(spray.exportEvent.hasStirringWindow, isTrue);
      }
    });
  });

  group('UI Components — WeekAheadCard, TaskPlannerCard & BiodynamicCard .ics Export', () {
    testWidgets(
      'WeekAheadCard filters ranked windows, jumps timeline, and opens IcsExportSheet',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final start = DateTime(2026, 4, 15, 8, 0);
        final ephemeris = _buildOrbitingFakeEphemeris(start);
        DateTime? jumpedTo;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: WeekAheadCard(
                  selectedDate: start,
                  ephemeris: ephemeris,
                  onTimeJump: (dt) {
                    jumpedTo = dt;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(find.text('Week Ahead: 7-Day Synthesis Brief'), findsOneWidget);
        expect(find.text('Export Week (.ics)'), findsOneWidget);

        // Tap day 2 pill on the 7-day strip
        final day2Pill = find.byKey(const ValueKey('week_ahead_day_2'));
        expect(day2Pill, findsOneWidget);
        await tester.tap(day2Pill);
        await tester.pump();
        expect(jumpedTo, DateTime(2026, 4, 17, 16));

        // Filter by BD 500/501 Sprays
        final spraysFilter = find.byKey(
          const ValueKey('week_ahead_filter_sprays'),
        );
        await tester.tap(spraysFilter);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('1-Hour Dynamization Stirring:'),
          findsWidgets,
        );

        // Open Export Week (.ics) sheet
        final exportWeekButton = find.byKey(
          const ValueKey('week_ahead_export_all_ics'),
        );
        await tester.tap(exportWeekButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Export 7-Day Biodynamic Brief (.ics)'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('ics_include_stirring_toggle')),
          findsOneWidget,
        );

        // Toggle raw .ics preview
        final previewButton = find.byKey(
          const ValueKey('ics_toggle_preview_button'),
        );
        await tester.ensureVisible(previewButton);
        await tester.tap(previewButton);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('ics_raw_preview_box')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'BiodynamicCard exports spray + 1h stirring .ics and TaskPlannerCard exports task window .ics',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final start = DateTime(2026, 4, 15, 16, 0);
        final ephemeris = _buildOrbitingFakeEphemeris(start);
        final sampleInfo = CalendarInfo(
          quality: PlantQuality.root,
          isGrayDay: false,
          message: 'Root Day',
          sapFlow: 'Descending: Sap recedes to roots',
          vitality: 'Waning',
          moonPhase: MoonPhaseInfo(
            illuminatedFraction: 0.35,
            isWaxing: false,
            phaseAngle: 220,
          ),
          planets: const [],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    BiodynamicCard(
                      info: sampleInfo,
                      selectedDate: start,
                      ephemeris: ephemeris,
                    ),
                    TaskPlannerCard(
                      selectedDate: start,
                      ephemeris: ephemeris,
                      onTimeJump: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 1. Tap BiodynamicCard "Export Spray + 1h Stir (.ics)"
        final bioExportButton = find.byKey(
          const ValueKey('biodynamic_export_ics_button'),
        );
        expect(bioExportButton, findsOneWidget);
        await tester.ensureVisible(bioExportButton);
        await tester.tap(bioExportButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Export Spray & 1h Stirring Reminder (.ics)'),
          findsOneWidget,
        );
        expect(find.textContaining('Stirring Start (60 min):'), findsWidgets);

        // Close sheet
        await tester.tap(find.byKey(const ValueKey('ics_export_close_button')));
        await tester.pumpAndSettle();

        // 2. Tap TaskPlannerCard window .ics button
        final taskWindowExportButton = find.byKey(
          const ValueKey('task_window_export_ics_0'),
        );
        expect(taskWindowExportButton, findsOneWidget);
        await tester.ensureVisible(taskWindowExportButton);
        await tester.tap(taskWindowExportButton);
        await tester.pumpAndSettle();

        expect(find.text('Export Task Window (.ics)'), findsOneWidget);
      },
    );
  });
}
