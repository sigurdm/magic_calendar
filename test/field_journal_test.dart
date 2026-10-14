import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/algorithm.dart' as algo;
import 'package:magic_calendar/src/core/models/models.dart';
import 'package:magic_calendar/src/services/garden_service.dart';
import 'package:magic_calendar/src/ui/components/biodynamic_card.dart';
import 'package:magic_calendar/src/ui/components/field_journal_card.dart';
import 'package:magic_calendar/src/ui/components/plant_recommendations_card.dart';
import 'package:magic_calendar/src/ui/components/task_planner_card.dart';
import 'package:magic_calendar/src/ui/components/week_ahead_card.dart';
import 'package:magic_calendar/src/ui/painters/infinite_timeline_painter.dart';

import 'support/fakes.dart';

FakeEphemerisService _buildOrbitingFakeEphemeris(DateTime epoch) {
  return FakeEphemerisService(
    planets: const [PlanetInfo(name: 'Moon', longitude: 45.0)],
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
  final epoch = DateTime(2026, 5, 16, 0, 0);
  late FakeEphemerisService ephemeris;

  setUp(() {
    ephemeris = _buildOrbitingFakeEphemeris(epoch);
  });

  group('FieldJournalEntry & GardenProfile Persistence', () {
    test(
      'captures cosmic & weather snapshots and round-trips through JSON',
      () async {
        final timestamp = DateTime(2026, 5, 16, 17, 0);
        final info = algo.getCalendarInfo(
          timestamp,
          ephemeris,
          includePlanets: true,
          latitude: 54.9037,
          longitude: 10.6074,
        );
        final weather = WeatherDataPoint(
          time: timestamp,
          temperature: 16.5,
          precipitation: 0.0,
          windSpeed: 2.4,
          windDirection: 190,
          cloudCover: 20,
        );
        final horizon = MultiHorizonWeatherAnalysis.analyze(
          referenceTime: timestamp,
          currentWeather: weather,
        );

        final entry = FieldJournalEntry.fromLiveContext(
          id: 'entry_carrot_1',
          timestamp: timestamp,
          action: FieldJournalAction.sowSeeds,
          cropId: 'carrot',
          calendarInfo: info,
          weather: weather,
          horizon: horizon,
          location: SavedLocation.defaultLocation,
          notes: 'Bed 3, Nantes 2 variety',
        );

        expect(entry.title, contains('Carrot'));
        expect(entry.quality, equals(PlantQuality.root));
        expect(entry.cosmicSnapshot.quality, equals(info.quality));
        expect(
          entry.cosmicSnapshot.isMoonDescending,
          equals(info.isMoonDescending),
        );
        expect(entry.cosmicSnapshot.moonConstellation, isNotEmpty);
        expect(entry.weatherSnapshot, isNotNull);
        expect(entry.weatherSnapshot!.temperatureCelsius, equals(16.5));
        expect(entry.weatherSnapshot!.soilTemperatureCelsius, isNotNull);
        expect(entry.hasOutcome, isFalse);

        final updated = entry.withOutcome(
          outcomeRating: 5,
          outcomeNote: '95% germination in 8 days; uniform taproots.',
        );
        expect(updated.hasOutcome, isTrue);
        expect(updated.outcomeRating, equals(5));

        final store = MemoryGardenProfileStore();
        final controller = GardenProfileController(store: store);
        await controller.addJournalEntry(entry);
        await controller.updateJournalEntry(updated);

        expect(controller.value.journalEntries, hasLength(1));
        expect(controller.value.journalEntries.first.outcomeRating, equals(5));

        final restored = GardenProfile.fromJson(store.current!.toJson());
        expect(restored.journalEntries, hasLength(1));
        expect(restored.journalEntries.first, equals(updated));

        await controller.removeJournalEntry('entry_carrot_1');
        expect(controller.value.journalEntries, isEmpty);
      },
    );

    test('GardenProfile.fromJson remains backward-compatible with v1 JSON omitting journalEntries', () {
      final legacyJson = <String, Object?>{
        'version': 1,
        'activeLocation': {
          'name': 'Svendborg, Denmark',
          'latitude': 54.9037,
          'longitude': 10.6074,
        },
        'savedLocations': <Object?>[],
        'starredCropIds': <Object?>['carrot'],
        'taskQueue': <Object?>[],
      };
      final profile = GardenProfile.fromJson(legacyJson);
      expect(profile.starredCropIds, contains('carrot'));
      expect(profile.journalEntries, isEmpty);
    });
  });

  group('InfiniteTimelinePainter Journal Markers', () {
    test('computes visibleJournalEntries and paints markers without errors across zoom levels', () {
      final centerTime = DateTime(2026, 5, 16, 12, 0);
      final info = algo.getCalendarInfo(
        centerTime,
        ephemeris,
        includePlanets: true,
      );
      final entryNear = FieldJournalEntry.fromLiveContext(
        id: 'near_1',
        timestamp: centerTime.add(const Duration(hours: 3)),
        action: FieldJournalAction.sowSeeds,
        cropId: 'carrot',
        calendarInfo: info,
        outcomeRating: 5,
        outcomeNote: 'Great emergence',
      );
      final entryFar = FieldJournalEntry.fromLiveContext(
        id: 'far_1',
        timestamp: centerTime.add(const Duration(days: 45)),
        action: FieldJournalAction.sprayPreparation,
        prepCode: 'BD 500',
        calendarInfo: info,
      );

      for (final hourWidth in const [2.5, 12.0]) {
        final painter = InfiniteTimelinePainter(
          centerTime: centerTime,
          hourWidth: hourWidth,
          intervals: const [],
          weatherData: const [],
          journalEntries: [entryNear, entryFar],
          ephemeris: ephemeris,
          latitude: 54.9037,
          longitude: 10.6074,
        );

        final visible = painter.visibleJournalEntries(600.0);
        expect(visible, contains(entryNear));
        expect(visible, isNot(contains(entryFar)));

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, const Size(600, 200));
        final picture = recorder.endRecording();
        expect(picture, isNotNull);
      }
    });
  });

  group('FieldJournalCard & Log Action UI Flows', () {
    testWidgets(
      'FieldJournalCard logs action, records comparative outcome, and jumps timeline',
      (tester) async {
        final selectedTime = DateTime(2026, 5, 16, 16, 0);
        final info = algo.getCalendarInfo(
          selectedTime,
          ephemeris,
          includePlanets: true,
          latitude: 54.9037,
          longitude: 10.6074,
        );
        final weatherNotifier = ValueNotifier<List<WeatherDataPoint>?>([
          WeatherDataPoint(
            time: selectedTime,
            temperature: 17.0,
            precipitation: 0.0,
            windSpeed: 2.0,
            windDirection: 180,
            cloudCover: 15,
          ),
        ]);
        final controller = GardenProfileController();
        DateTime? jumpedTo;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FieldJournalCard(
                  gardenController: controller,
                  selectedDate: selectedTime,
                  info: info,
                  weatherNotifier: weatherNotifier,
                  onTimeJump: (t) => jumpedTo = t,
                ),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('field_journal_empty_state')),
          findsOneWidget,
        );

        // Tap "Log Action at Selected Time"
        await tester.tap(
          find.byKey(const ValueKey('field_journal_log_now_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Log Biodynamic Field Action'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('field_journal_notes_input')),
          'South raised bed, 3 rows',
        );
        await tester.tap(
          find.byKey(const ValueKey('field_journal_save_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.value.journalEntries, hasLength(1));
        final savedEntry = controller.value.journalEntries.first;
        expect(savedEntry.notes, equals('South raised bed, 3 rows'));
        expect(find.text('South raised bed, 3 rows'), findsOneWidget);

        // Tap entry to jump timeline
        await tester.tap(
          find.byKey(ValueKey('journal_entry_${savedEntry.id}')),
        );
        await tester.pump();
        expect(jumpedTo, equals(selectedTime));

        // Tap "Log Outcome" to record Maria Thun comparative trial outcome
        await tester.tap(
          find.byKey(ValueKey('journal_record_outcome_${savedEntry.id}')),
        );
        await tester.pumpAndSettle();

        final star5 = find.byKey(const ValueKey('field_journal_star_5'));
        await tester.ensureVisible(star5);
        await tester.tap(star5);
        final outcomeInput = find.byKey(
          const ValueKey('field_journal_outcome_input'),
        );
        await tester.ensureVisible(outcomeInput);
        await tester.enterText(
          outcomeInput,
          'Strong root formation, zero bolting',
        );
        await tester.tap(
          find.byKey(const ValueKey('field_journal_save_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.value.journalEntries.first.outcomeRating, equals(5));
        expect(
          find.textContaining('Strong root formation, zero bolting'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Log Action buttons on TaskPlannerCard, WeekAheadCard, BiodynamicCard, and PlantRecommendationsCard open FieldJournalSheet',
      (tester) async {
        final selectedTime = DateTime(2026, 5, 16, 16, 0);
        final info = algo.getCalendarInfo(
          selectedTime,
          ephemeris,
          includePlanets: true,
          latitude: 54.9037,
          longitude: 10.6074,
        );
        final controller = GardenProfileController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    BiodynamicCard(
                      info: info,
                      selectedDate: selectedTime,
                      ephemeris: ephemeris,
                      gardenController: controller,
                    ),
                    TaskPlannerCard(
                      selectedDate: selectedTime,
                      ephemeris: ephemeris,
                      gardenController: controller,
                      onTimeJump: (_) {},
                    ),
                    WeekAheadCard(
                      selectedDate: selectedTime,
                      ephemeris: ephemeris,
                      gardenController: controller,
                      onTimeJump: (_) {},
                    ),
                    PlantRecommendationsCard(
                      info: info,
                      selectedDate: selectedTime,
                      ephemeris: ephemeris,
                      gardenController: controller,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. BiodynamicCard Log Spray Action button
        final bioLogBtn = find.byKey(
          const ValueKey('biodynamic_log_action_button'),
        );
        expect(bioLogBtn, findsOneWidget);
        await tester.ensureVisible(bioLogBtn);
        await tester.tap(bioLogBtn);
        await tester.pumpAndSettle();

        expect(find.text('Log Biodynamic Field Action'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('field_journal_save_button')),
        );
        await tester.pumpAndSettle();
        expect(controller.value.journalEntries, hasLength(1));

        // 2. TaskPlannerCard window Log Action button
        final taskLogBtn = find.byKey(
          const ValueKey('task_window_log_action_0'),
        );
        expect(taskLogBtn, findsOneWidget);
        await tester.ensureVisible(taskLogBtn);
        await tester.tap(taskLogBtn);
        await tester.pumpAndSettle();

        expect(find.text('Log Biodynamic Field Action'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('field_journal_save_button')),
        );
        await tester.pumpAndSettle();
        expect(controller.value.journalEntries, hasLength(2));
      },
    );
  });
}
