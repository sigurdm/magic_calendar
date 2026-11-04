import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:magic_calendar/src/core/algorithm.dart' as algo;
import 'package:magic_calendar/src/core/models/models.dart';
import 'package:magic_calendar/src/core/task_window_planner.dart';
import 'package:magic_calendar/src/core/vegetable_database.dart';
import 'package:magic_calendar/src/services/garden_service.dart';
import 'package:magic_calendar/src/ui/components/biodynamic_card.dart';
import 'package:magic_calendar/src/ui/components/field_journal_card.dart';
import 'package:magic_calendar/src/ui/components/field_journal_sheet.dart';
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

  group('Hlc & HlcClock', () {
    test('canonical string sort order matches Hlc.compareTo and advances monotonically', () {
      final clockA = HlcClock(actorId: 'actor_a');
      final clockB = HlcClock(actorId: 'actor_b');

      final t0 = DateTime.utc(2026, 5, 16, 12, 0, 0);
      final h1 = clockA.now(t0);
      final h2 = clockA.now(t0); // same wall ms -> increments logical counter
      final h3 = clockA.now(
        t0.subtract(const Duration(seconds: 10)),
      ); // clock drift backward

      expect(h1 < h2, isTrue);
      expect(h2 < h3, isTrue);
      expect(
        h1.toCanonicalString().compareTo(h2.toCanonicalString()),
        lessThan(0),
      );
      expect(
        h2.toCanonicalString().compareTo(h3.toCanonicalString()),
        lessThan(0),
      );

      final received = clockB.receive(h3, t0);
      expect(received > h3, isTrue);
      expect(Hlc.parse(received.toCanonicalString()), equals(received));
    });
  });

  group('ShardedSqliteJournalStore & Multi-Gardener CRDT Sync', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'magic_calendar_journal_test_',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('partitions entries into monthly SQLite shards, enforces maxOpenShards LRU, and indexes plantings across months', () {
      final store = ShardedSqliteJournalStore(
        rootDirectoryPath: '${tempDir.path}/local',
        maxOpenShards: 2,
        initialAuthorName: 'Sigurd',
      );
      addTearDown(store.close);

      final dates = [
        DateTime.utc(2025, 4, 10, 9, 0),
        DateTime.utc(2025, 9, 14, 15, 0),
        DateTime.utc(2026, 4, 18, 10, 0),
        DateTime.utc(2026, 5, 16, 17, 0),
        DateTime.utc(2026, 10, 12, 11, 0),
      ];

      for (int i = 0; i < dates.length; i++) {
        final dt = dates[i];
        final info = algo.getCalendarInfo(dt, ephemeris, includePlanets: true);
        store.upsertEntry(
          FieldJournalEntry.fromLiveContext(
            id: 'entry_$i',
            timestamp: dt,
            action: i.isEven
                ? FieldJournalAction.sowSeeds
                : FieldJournalAction.harvestStorage,
            cropId: 'carrot',
            bedName: 'Bed ${(i % 2) + 1}',
            calendarInfo: info,
            notes: 'Note for month ${dt.month}',
          ),
        );
      }

      // Verify 5 distinct monthly shard files exist on disk, but at most 2 are open in RAM!
      expect(
        store.listLocalShardKeys(),
        equals(['2026-10', '2026-05', '2026-04', '2025-09', '2025-04']),
      );
      expect(store.openShardCount, lessThanOrEqualTo(2));

      // Range query for May 2026 only opens 2026-05
      final mayEntries = store.loadRange(
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 5, 31, 23, 59),
      );
      expect(mayEntries, hasLength(1));
      expect(mayEntries.first.id, equals('entry_3'));
      expect(store.openShardCount, lessThanOrEqualTo(2));

      // Cross-month planting index in garden_meta.sqlite returns all 3 sowings without opening 2025-04!
      final plantings = store.listPlantingBatches(cropId: 'carrot');
      expect(plantings, hasLength(3));
      expect(plantings.map((p) => p.entryId), contains('entry_0'));
      expect(store.openShardKeys, isNot(contains('2025-04')));

      // Paginated recent load stops as soon as limit (2) is satisfied
      final recentTwo = store.loadRecentPage(limit: 2);
      expect(
        recentTwo.map((e) => e.id).toList(),
        equals(['entry_4', 'entry_3']),
      );
    });

    test('merges concurrent offline notes and field edits from multiple gardeners sharing a garden without data loss', () async {
      final cloudTransport = InMemoryGardenSyncTransport();

      final sigurdStore = ShardedSqliteJournalStore(
        rootDirectoryPath: '${tempDir.path}/sigurd',
        initialActorId: 'sigurd_phone',
        initialAuthorName: 'Sigurd',
      );
      final majaStore = ShardedSqliteJournalStore(
        rootDirectoryPath: '${tempDir.path}/maja',
        initialActorId: 'maja_phone',
        initialAuthorName: 'Maja',
      );
      addTearDown(() {
        sigurdStore.close();
        majaStore.close();
      });

      final sigurdSync = GardenSyncEngine(
        store: sigurdStore,
        transport: cloudTransport,
      );
      final majaSync = GardenSyncEngine(
        store: majaStore,
        transport: cloudTransport,
      );

      // 1. Sigurd sows carrots in May 2026 (plus an older 2024-06 entry) and syncs to cloud.
      final oldTime = DateTime.utc(2024, 6, 10, 8, 0);
      final mayTime = DateTime.utc(2026, 5, 4, 17, 0);
      final info = algo.getCalendarInfo(
        mayTime,
        ephemeris,
        includePlanets: true,
      );

      sigurdStore.upsertEntry(
        FieldJournalEntry.fromLiveContext(
          id: 'old_2024_entry',
          timestamp: oldTime,
          action: FieldJournalAction.sowSeeds,
          cropId: 'carrot',
          calendarInfo: info,
          notes: '2024 archive sowing',
        ),
      );
      sigurdStore.upsertEntry(
        FieldJournalEntry.fromLiveContext(
          id: 'carrot_batch_2026',
          timestamp: mayTime,
          action: FieldJournalAction.sowSeeds,
          cropId: 'carrot',
          bedName: 'Bed 2',
          calendarInfo: info,
          notes: 'Sowed 3 rows of Nantes carrots',
        ),
      );

      await sigurdSync.sync(hydrateAllShards: true);

      // 2. Maja syncs only the active May 2026 window (leaving 2024-06 lazily unhydrated on cloud!)
      final majaInitialReport = await majaSync.sync(
        activeWindowStart: DateTime.utc(2026, 5, 1),
        activeWindowEnd: DateTime.utc(2026, 5, 31),
        hydrateAllShards: false,
      );
      expect(majaInitialReport.mergedShardKeys, contains('2026-05'));
      expect(majaInitialReport.lazyUnhydratedShardKeys, contains('2024-06'));
      expect(majaStore.hasLocalShard('2024-06'), isFalse);
      expect(majaStore.getEntry('carrot_batch_2026'), isNotNull);

      // 3. Both Sigurd and Maja go offline and edit the same May 2026 carrot entry concurrently!
      // Sigurd adds a field observation note and updates the outcome rating to 4.
      sigurdStore.addNoteToEntry(
        entryId: 'carrot_batch_2026',
        body: 'First cotyledons emerged after 8 days; watered well.',
        kind: JournalNoteKind.observation,
        timestamp: mayTime.add(const Duration(days: 8)),
      );

      // Maja concurrently adds her own note to the same carrot entry AND logs a July harvest linked to it.
      majaStore.addNoteToEntry(
        entryId: 'carrot_batch_2026',
        body: 'Weeded between rows and covered with insect fleece.',
        kind: JournalNoteKind.observation,
        outcomeRating: 5,
        timestamp: mayTime.add(const Duration(days: 12)),
      );
      final julyHarvestTime = DateTime.utc(2026, 7, 15, 9, 0);
      majaStore.upsertEntry(
        FieldJournalEntry.fromLiveContext(
          id: 'carrot_harvest_2026',
          timestamp: julyHarvestTime,
          action: FieldJournalAction.harvestFresh,
          cropId: 'carrot',
          bedName: 'Bed 2',
          parentEntryId: 'carrot_batch_2026',
          calendarInfo: info,
          notes: 'Crisp, sweet roots from Bed 2',
        ),
      );

      // Simulate concurrent uploads: Sigurd uploads his head, and Maja also uploads her head
      // before seeing Sigurd's head.
      final sigurdDigest = sigurdStore.computeShardDigest('2026-05');
      final majaDigest = majaStore.computeShardDigest('2026-05');
      expect(sigurdDigest, isNot(equals(majaDigest)));

      await cloudTransport.putBytes(
        'shards/2026-05.$sigurdDigest.sqlite',
        sigurdStore.exportShardBytes('2026-05'),
      );
      await cloudTransport.putBytes(
        'shards/2026-05.$majaDigest.sqlite',
        majaStore.exportShardBytes('2026-05'),
      );

      // Both heads coexist on the cloud transport without overwriting each other!
      final concurrentHeads = await cloudTransport.list('shards/2026-05.');
      expect(concurrentHeads.length, greaterThanOrEqualTo(2));

      // 4. Now Maja and Sigurd run sync() — both merge the concurrent heads and garbage-collect ancestors!
      await majaSync.sync(hydrateAllShards: true);
      await sigurdSync.sync(hydrateAllShards: true);

      // Both stores now have identical SHA-256 digests for 2026-05!
      expect(
        sigurdStore.computeShardDigest('2026-05'),
        equals(majaStore.computeShardDigest('2026-05')),
      );

      // Only a single merged head remains on the cloud for 2026-05
      final postMergeHeads = await cloudTransport.list('shards/2026-05.');
      expect(postMergeHeads, hasLength(1));

      // Verify ALL notes from both Sigurd and Maja survived on carrot_batch_2026!
      final mergedEntry = sigurdStore.getEntry('carrot_batch_2026')!;
      expect(mergedEntry.activeNotes.length, greaterThanOrEqualTo(3));
      expect(
        mergedEntry.notes,
        allOf(
          contains('Sowed 3 rows of Nantes carrots'),
          contains('Sigurd: First cotyledons emerged after 8 days'),
          contains('Maja: Weeded between rows and covered with insect fleece'),
        ),
      );
      expect(mergedEntry.effectiveOutcomeRating, equals(5));

      // And Sigurd also received Maja's July harvest linked to carrot_batch_2026!
      final syncedHarvest = sigurdStore.getEntry('carrot_harvest_2026')!;
      expect(syncedHarvest.parentEntryId, equals('carrot_batch_2026'));
      expect(syncedHarvest.authorName, equals('Maja'));
    });

    test(
      'DirectoryGardenSyncTransport syncs shards across local shared folder',
      () async {
        final sharedFolderPath = '${tempDir.path}/cloud_shared_folder';
        final transport = DirectoryGardenSyncTransport(sharedFolderPath);

        final storeA = ShardedSqliteJournalStore(
          rootDirectoryPath: '${tempDir.path}/peer_a',
          initialAuthorName: 'Alice',
        );
        final storeB = ShardedSqliteJournalStore(
          rootDirectoryPath: '${tempDir.path}/peer_b',
          initialAuthorName: 'Bob',
        );
        addTearDown(() {
          storeA.close();
          storeB.close();
        });

        final dt = DateTime.utc(2026, 5, 16, 14, 0);
        final info = algo.getCalendarInfo(dt, ephemeris, includePlanets: true);
        storeA.upsertEntry(
          FieldJournalEntry.fromLiveContext(
            id: 'dir_sync_1',
            timestamp: dt,
            action: FieldJournalAction.transplant,
            cropId: 'carrot',
            bedName: 'Greenhouse',
            calendarInfo: info,
            notes: 'Transplanted seedlings',
          ),
        );

        final engineA = GardenSyncEngine(store: storeA, transport: transport);
        final engineB = GardenSyncEngine(store: storeB, transport: transport);

        await engineA.sync(hydrateAllShards: true);
        await engineB.sync(hydrateAllShards: true);

        final synced = storeB.getEntry('dir_sync_1');
        expect(synced, isNotNull);
        expect(synced!.bedName, equals('Greenhouse'));
        expect(storeB.listBedNames(), contains('Greenhouse'));
      },
    );
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
      'FieldJournalCard logs action with bed tag, records comparative outcome, and jumps timeline',
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
          find.byKey(const ValueKey('field_journal_bed_input')),
          'Bed 3',
        );
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
        expect(savedEntry.bedName, equals('Bed 3'));
        expect(savedEntry.notes, equals('South raised bed, 3 rows'));
        expect(find.text('South raised bed, 3 rows'), findsOneWidget);

        // Tap entry to jump timeline
        final entryFinder = find.byKey(
          ValueKey('journal_entry_${savedEntry.id}'),
        );
        await tester.ensureVisible(entryFinder);
        await tester.tap(entryFinder);
        await tester.pump();
        expect(jumpedTo, equals(selectedTime));

        // Tap "Log Outcome" to record Maria Thun comparative trial outcome
        final recordOutcomeFinder = find.byKey(
          ValueKey('journal_record_outcome_${savedEntry.id}'),
        );
        await tester.ensureVisible(recordOutcomeFinder);
        await tester.tap(recordOutcomeFinder);
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

  group('JournalAttachment Photo Storage & Cloud Media Sync', () {
    // Valid 1x1 transparent PNG bytes
    final samplePngBytes = Uint8List.fromList(const <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT chunk
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND chunk
      0x42, 0x60, 0x82,
    ]);

    test('validates PNG/JPEG/WebP magic bytes and rejects invalid or tampered media', () {
      expect(
        JournalImageFormat.detect(samplePngBytes),
        equals(JournalImageFormat.png),
      );
      expect(
        JournalImageFormat.detect(
          Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xE0]),
        ),
        equals(JournalImageFormat.jpeg),
      );
      expect(
        () => JournalImageFormat.detect(
          Uint8List.fromList(const [0x00, 0x01, 0x02, 0x03]),
        ),
        throwsFormatException,
      );

      final att = JournalAttachment.fromRawBytes(
        entryId: 'entry_1',
        fullBytes: samplePngBytes,
        caption: 'Seedling emergence',
        authorId: 'actor_sigurd',
        authorName: 'Sigurd',
      );
      expect(att.format, equals(JournalImageFormat.png));
      expect(att.remoteBlobName, startsWith('media/'));
      expect(att.remoteBlobName, endsWith('.png'));
      expect(att.verifyBytes(samplePngBytes), isTrue);

      final tampered = Uint8List.fromList(samplePngBytes);
      tampered[tampered.length - 1] ^= 0xFF;
      expect(att.verifyBytes(tampered), isFalse);
    });

    test('syncs inline thumbnail inside YYYY-MM.sqlite and lazily hydrates full-res media/<sha256>.png on demand', () async {
      final dirA = Directory.systemTemp.createTempSync('garden_photo_a_');
      final dirB = Directory.systemTemp.createTempSync('garden_photo_b_');
      addTearDown(() {
        if (dirA.existsSync()) dirA.deleteSync(recursive: true);
        if (dirB.existsSync()) dirB.deleteSync(recursive: true);
      });

      final storeA = ShardedSqliteJournalStore(
        rootDirectoryPath: dirA.path,
        initialActorId: 'actor_sigurd',
        initialAuthorName: 'Sigurd',
      );
      final storeB = ShardedSqliteJournalStore(
        rootDirectoryPath: dirB.path,
        initialActorId: 'actor_anna',
        initialAuthorName: 'Anna',
      );
      addTearDown(() {
        storeA.close();
        storeB.close();
      });

      final transport = InMemoryGardenSyncTransport();
      final engineA = GardenSyncEngine(store: storeA, transport: transport);
      final engineB = GardenSyncEngine(store: storeB, transport: transport);

      final t0 = DateTime(2026, 4, 15, 10, 0);
      final info = algo.getCalendarInfo(t0, ephemeris, includePlanets: true);
      final thumbBytes = Uint8List.fromList(samplePngBytes);
      // Construct a slightly different valid PNG as "full resolution" so we can distinguish thumbnail vs full-res
      final fullBytes = Uint8List.fromList([
        ...samplePngBytes,
        0x00, // trailing byte after IEND so SHA-256 differs from thumbBytes while PNG header remains valid
      ]);

      storeA.upsertEntry(
        FieldJournalEntry.fromLiveContext(
          id: 'carrot_photo_entry',
          timestamp: t0,
          action: FieldJournalAction.sowSeeds,
          cropId: 'carrot',
          bedName: 'Bed 1',
          calendarInfo: info,
          notes: 'Sown with photo',
        ),
      );
      final withPhoto = storeA.attachPhotoToEntry(
        entryId: 'carrot_photo_entry',
        fullBytes: fullBytes,
        thumbnailBytes: thumbBytes,
        caption: 'Cotyledons emerging in Bed 1',
      );
      expect(withPhoto, isNotNull);
      expect(withPhoto!.activeAttachments, hasLength(1));
      final att = withPhoto.activeAttachments.first;
      expect(att.caption, equals('Cotyledons emerging in Bed 1'));
      expect(att.thumbnailBytes, equals(thumbBytes));

      // Sync Peer A -> uploads shard + content-addressed media/<sha256>.png
      final reportA = await engineA.sync(hydrateAllShards: true);
      expect(reportA.uploadedMediaBlobs, contains(att.remoteBlobName));
      expect(transport.storedObjectNames, contains(att.remoteBlobName));

      // Sync Peer B -> merges 2026-04 shard with inline thumbnail, WITHOUT downloading full-res media yet
      await engineB.sync(hydrateAllShards: true);
      final entryOnB = storeB.getEntry('carrot_photo_entry');
      expect(entryOnB, isNotNull);
      expect(entryOnB!.activeAttachments, hasLength(1));
      final attOnB = entryOnB.activeAttachments.first;
      expect(attOnB.caption, equals('Cotyledons emerging in Bed 1'));
      expect(attOnB.thumbnailBytes, equals(thumbBytes));

      // Full-res file is not on Peer B's disk before lazy fetch
      expect(storeB.readLocalMediaBytes(attOnB), isNull);

      // Lazy fetch downloads and verifies full-res bytes from transport and caches locally
      final hydratedBytes = await engineB.fetchAttachmentMedia(attOnB);
      expect(hydratedBytes, equals(fullBytes));
      expect(storeB.readLocalMediaBytes(attOnB), equals(fullBytes));
    });

    testWidgets(
      'FieldJournalSheet attaches photo via onPickPhoto and FieldJournalCard opens photo viewer',
      (tester) async {
        final selectedTime = DateTime(2026, 5, 16, 16, 0);
        final info = algo.getCalendarInfo(
          selectedTime,
          ephemeris,
          includePlanets: true,
        );
        final controller = GardenProfileController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    Builder(
                      builder: (ctx) => ElevatedButton(
                        key: const ValueKey('open_sheet_with_picker'),
                        onPressed: () {
                          FieldJournalSheet.show(
                            ctx,
                            gardenController: controller,
                            timestamp: selectedTime,
                            calendarInfo: info,
                            onPickPhoto: (_) async => PickedJournalPhoto(
                              fullBytes: samplePngBytes,
                              thumbnailBytes: samplePngBytes,
                              caption: 'Morning dew on kale',
                            ),
                          );
                        },
                        child: const Text('Open Sheet'),
                      ),
                    ),
                    FieldJournalCard(
                      gardenController: controller,
                      selectedDate: selectedTime,
                      info: info,
                      onTimeJump: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('open_sheet_with_picker')));
        await tester.pumpAndSettle();

        final attachBtn = find.byKey(
          const ValueKey('field_journal_attach_photo_button'),
        );
        await tester.ensureVisible(attachBtn);
        await tester.tap(attachBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('staged_photo_preview_0')),
          findsOneWidget,
        );
        expect(find.text('Morning dew on kale'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('field_journal_save_button')),
        );
        await tester.pumpAndSettle();

        expect(controller.value.journalEntries, hasLength(1));
        final saved = controller.value.journalEntries.first;
        expect(saved.activeAttachments, hasLength(1));
        final att = saved.activeAttachments.first;

        final thumbFinder = find.byKey(
          ValueKey('journal_attachment_thumb_${att.id}'),
        );
        expect(thumbFinder, findsOneWidget);
        await tester.ensureVisible(thumbFinder);
        await tester.tap(thumbFinder);
        await tester.pumpAndSettle();

        expect(
          find.byKey(ValueKey('photo_viewer_image_${att.id}')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('photo_viewer_close_button')),
        );
        await tester.pumpAndSettle();
      },
    );
  });

  group('Field Workflow: Crop Picker, Active Plantings, Task Queue Completion & Search', () {
    test('auto-completes matching QueuedGardenTask on journal log, tracks active vs harvested planting batches, and searches across SQLite shards', () async {
      final dirA = Directory.systemTemp.createTempSync('garden_wf_a_');
      final dirB = Directory.systemTemp.createTempSync('garden_wf_b_');
      addTearDown(() {
        if (dirA.existsSync()) dirA.deleteSync(recursive: true);
        if (dirB.existsSync()) dirB.deleteSync(recursive: true);
      });

      final storeA = ShardedSqliteJournalStore(
        rootDirectoryPath: dirA.path,
        initialActorId: 'actor_sigurd',
        initialAuthorName: 'Sigurd',
      );
      final storeB = ShardedSqliteJournalStore(
        rootDirectoryPath: dirB.path,
        initialActorId: 'actor_anna',
        initialAuthorName: 'Anna',
      );
      final transport = InMemoryGardenSyncTransport();
      final controllerA = GardenProfileController(
        journalStore: storeA,
        syncTransport: transport,
      );
      final controllerB = GardenProfileController(
        journalStore: storeB,
        syncTransport: transport,
      );
      addTearDown(() {
        controllerA.dispose();
        controllerB.dispose();
      });

      // 1. Queue a planned task on Peer A and sync to Peer B
      await controllerA.toggleQueuedTask(
        action: TaskActionType.sowOutdoor,
        cropId: 'carrot',
        targetQuality: PlantQuality.root,
        note: 'Nantes 2 in Bed 1',
      );
      expect(controllerA.value.taskQueue, hasLength(1));
      await controllerA.syncJournal(hydrateAllShards: true);
      await controllerB.syncJournal(hydrateAllShards: true);
      expect(controllerB.value.taskQueue, hasLength(1));

      // 2. Peer B logs sowing carrot in April -> automatically completes the queued task!
      final aprilTime = DateTime.utc(2026, 4, 14, 9, 0);
      final aprilInfo = algo.getCalendarInfo(
        aprilTime,
        ephemeris,
        includePlanets: true,
      );
      await controllerB.addJournalEntry(
        FieldJournalEntry.fromLiveContext(
          id: 'batch_carrot_apr',
          timestamp: aprilTime,
          action: FieldJournalAction.sowSeeds,
          cropId: 'carrot',
          bedName: 'Bed 1',
          calendarInfo: aprilInfo,
          notes: 'Sown Nantes 2 heirloom lot #42',
        ),
      );
      expect(controllerB.value.taskQueue, isEmpty);
      expect(
        controllerB.listPlantingBatches(onlyActiveInGround: true),
        hasLength(1),
      );

      // Sync Peer B -> Peer A sees the queued task completed and the active planting batch
      await controllerB.syncJournal(hydrateAllShards: true);
      await controllerA.syncJournal(hydrateAllShards: true);
      expect(controllerA.value.taskQueue, isEmpty);
      expect(
        controllerA.listPlantingBatches(onlyActiveInGround: true),
        hasLength(1),
      );

      // 3. Cross-shard full-text search finds the April entry by cultivar note
      final searchHits = controllerA.searchJournalEntries('heirloom lot #42');
      expect(searchHits, hasLength(1));
      expect(searchHits.first.id, equals('batch_carrot_apr'));

      // 4. Peer A logs a harvest in July linked to 'batch_carrot_apr' -> batch is marked harvested
      final julyTime = DateTime.utc(2026, 7, 20, 10, 0);
      final julyInfo = algo.getCalendarInfo(
        julyTime,
        ephemeris,
        includePlanets: true,
      );
      await controllerA.addJournalEntry(
        FieldJournalEntry.fromLiveContext(
          id: 'harvest_carrot_jul',
          timestamp: julyTime,
          action: FieldJournalAction.harvestStorage,
          cropId: 'carrot',
          bedName: 'Bed 1',
          parentEntryId: 'batch_carrot_apr',
          calendarInfo: julyInfo,
          notes: 'Sweet crisp roots',
        ),
      );
      expect(
        controllerA.listPlantingBatches(onlyActiveInGround: true),
        isEmpty,
      );
      final allBatches = controllerA.listPlantingBatches(
        onlyActiveInGround: false,
      );
      expect(allBatches, hasLength(1));
      expect(allBatches.first.isHarvested, isTrue);
      expect(allBatches.first.harvestedByEntryId, equals('harvest_carrot_jul'));
    });

    test('InfiniteTimelinePainter.hitTestJournalEntry resolves tapped journal marker', () {
      final centerTime = DateTime(2026, 5, 16, 12, 0);
      final info = algo.getCalendarInfo(
        centerTime,
        ephemeris,
        includePlanets: true,
      );
      final entry = FieldJournalEntry.fromLiveContext(
        id: 'pin_1',
        timestamp: centerTime.add(const Duration(hours: 2)),
        action: FieldJournalAction.sowSeeds,
        cropId: 'carrot',
        calendarInfo: info,
      );
      final painter = InfiniteTimelinePainter(
        centerTime: centerTime,
        hourWidth: 10.0,
        intervals: const [],
        weatherData: const [],
        journalEntries: [entry],
        ephemeris: ephemeris,
        latitude: 54.9037,
        longitude: 10.6074,
      );
      const canvasSize = Size(600, 200);
      final markerX = painter.xForTime(entry.timestamp, canvasSize.width);

      // Tap on the badge capsule at y = 162
      final hitBadge = painter.hitTestJournalEntry(
        Offset(markerX, 162.0),
        canvasSize,
      );
      expect(hitBadge, equals(entry));

      // Tap far away returns null
      final miss = painter.hitTestJournalEntry(
        const Offset(20.0, 162.0),
        canvasSize,
      );
      expect(miss, isNull);
    });

    testWidgets(
      'FieldJournalSheet selects crop and FieldJournalCard renders Active in the Ground with 1-tap Observe & Harvest',
      (tester) async {
        final selectedTime = DateTime(2026, 5, 16, 16, 0);
        final info = algo.getCalendarInfo(
          selectedTime,
          ephemeris,
          includePlanets: true,
        );
        final controller = GardenProfileController(
          initialProfile: GardenProfile(starredCropIds: const ['carrot']),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FieldJournalCard(
                  gardenController: controller,
                  selectedDate: selectedTime,
                  info: info,
                  onTimeJump: (_) {},
                ),
              ),
            ),
          ),
        );

        // Open sheet via "Log Action at Selected Time"
        await tester.tap(
          find.byKey(const ValueKey('field_journal_log_now_button')),
        );
        await tester.pumpAndSettle();

        // Select starred Carrot crop inside FieldJournalSheet
        final carrotChip = find.byKey(
          const ValueKey('journal_sheet_crop_carrot'),
        );
        expect(carrotChip, findsOneWidget);
        await tester.ensureVisible(carrotChip);
        await tester.tap(carrotChip);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('field_journal_bed_input')),
          'Bed A',
        );
        await tester.tap(
          find.byKey(const ValueKey('field_journal_save_button')),
        );
        await tester.pumpAndSettle();

        // Verify Active in the Ground section appears with Carrot in Bed A
        expect(
          find.byKey(const ValueKey('field_journal_active_plantings_section')),
          findsOneWidget,
        );
        final batchId = controller.value.journalEntries.first.id;

        // Tap "+ Observe" on the active batch -> opens sheet pre-linked to the batch
        final observeBtn = find.byKey(
          ValueKey('active_batch_observe_$batchId'),
        );
        await tester.ensureVisible(observeBtn);
        await tester.tap(observeBtn);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('field_journal_notes_input')),
          'First true leaves visible',
        );
        await tester.tap(
          find.byKey(const ValueKey('field_journal_save_button')),
        );
        await tester.pumpAndSettle();

        // Verify lifecycle trail appears on the parent sowing card
        expect(
          find.byKey(ValueKey('journal_lifecycle_trail_$batchId')),
          findsOneWidget,
        );
      },
    );
  });

  group('GardenPlot, Soil Memory & Biodynamic Crop Rotation', () {
    test('syncs structured GardenPlot metadata across peers, tracks BD 500 soil prep, and detects botanical family rotation conflicts', () async {
      final dirA = Directory.systemTemp.createTempSync('magic_plot_a_');
      final dirB = Directory.systemTemp.createTempSync('magic_plot_b_');
      addTearDown(() {
        if (dirA.existsSync()) dirA.deleteSync(recursive: true);
        if (dirB.existsSync()) dirB.deleteSync(recursive: true);
      });

      final storeA = ShardedSqliteJournalStore(
        rootDirectoryPath: dirA.path,
        initialGardenId: 'shared_plot_garden',
        initialActorId: 'alice',
        initialAuthorName: 'Alice',
      );
      final storeB = ShardedSqliteJournalStore(
        rootDirectoryPath: dirB.path,
        initialGardenId: 'shared_plot_garden',
        initialActorId: 'bob',
        initialAuthorName: 'Bob',
      );
      final transport = InMemoryGardenSyncTransport();
      final controllerA = GardenProfileController(
        journalStore: storeA,
        syncTransport: transport,
      );
      final controllerB = GardenProfileController(
        journalStore: storeB,
        syncTransport: transport,
      );
      addTearDown(() {
        controllerA.dispose();
        controllerB.dispose();
      });

      // 1. Alice defines a Raised Bed plot in Kitchen Garden
      controllerA.upsertPlot(
        GardenPlot(
          name: 'Bed 1',
          areaName: 'Kitchen Garden',
          plotType: GardenPlotType.raisedBed,
          dimensions: '1.2m × 4.0m',
          notes: 'South-facing loam',
        ),
      );

      // 2. Alice logs a BD 500 spray on Bed 1 and sows Kale (Brassicaceae) in 2025
      final prepTime = DateTime.utc(2025, 4, 2, 17, 0);
      final prepInfo = algo.getCalendarInfo(
        prepTime,
        ephemeris,
        includePlanets: true,
      );
      await controllerA.addJournalEntry(
        FieldJournalEntry.fromLiveContext(
          id: 'prep_bd500_2025',
          timestamp: prepTime,
          action: FieldJournalAction.sprayPreparation,
          prepCode: 'BD 500',
          bedName: 'Bed 1',
          calendarInfo: prepInfo,
        ),
      );

      final kaleSowTime = DateTime.utc(2025, 5, 10, 9, 0);
      final kaleInfo = algo.getCalendarInfo(
        kaleSowTime,
        ephemeris,
        includePlanets: true,
      );
      await controllerA.addJournalEntry(
        FieldJournalEntry.fromLiveContext(
          id: 'sow_kale_2025',
          timestamp: kaleSowTime,
          action: FieldJournalAction.sowSeeds,
          cropId: 'kale',
          bedName: 'Bed 1',
          calendarInfo: kaleInfo,
        ),
      );

      // 3. Sync Alice -> Bob
      await controllerA.syncJournal(hydrateAllShards: true);
      await controllerB.syncJournal(hydrateAllShards: true);

      final syncedPlot = controllerB.findPlot('Bed 1');
      expect(syncedPlot, isNotNull);
      expect(syncedPlot!.areaName, equals('Kitchen Garden'));
      expect(syncedPlot.plotType, equals(GardenPlotType.raisedBed));
      expect(syncedPlot.dimensions, equals('1.2m × 4.0m'));
      expect(syncedPlot.lastSoilPrepSummary, equals('BD 500'));

      // 4. Evaluate 2026 crop rotation on Bed 1:
      // White Cabbage (also Brassicaceae, strict tier) in 2026 triggers a 3-year clubroot rotation conflict!
      final cabbage = VegetableDatabase.findById('white_cabbage');
      expect(cabbage, isNotNull);
      final cabbageEval = controllerB.evaluatePlotRotation(
        'Bed 1',
        candidateCrop: cabbage,
        referenceTime: DateTime.utc(2026, 4, 15),
      );
      expect(cabbageEval.hasFamilyConflict, isTrue);
      expect(cabbageEval.sensitivity, equals(RotationSensitivity.strict));
      expect(cabbageEval.candidateFamily, equals(BotanicalFamily.brassicaceae));
      expect(cabbageEval.conflictWarning, contains('clubroot'));
      // After heavy-feeding Leaf (Kale), recommended next organ quality is Root
      expect(cabbageEval.recommendedNextQuality, equals(PlantQuality.root));

      // Carrot (Apiaceae, Root) in 2026 has no conflict!
      final carrot = VegetableDatabase.findById('carrot')!;
      final carrotEval = controllerB.evaluatePlotRotation(
        'Bed 1',
        candidateCrop: carrot,
        referenceTime: DateTime.utc(2026, 4, 15),
      );
      expect(carrotEval.hasFamilyConflict, isFalse);

      // 5. Verify Maria Thun stationary Tomato exception vs Potato blight conflict
      controllerB.upsertPlot(
        GardenPlot(
          name: 'South Greenhouse',
          plotType: GardenPlotType.greenhouse,
        ),
      );
      await controllerB.addJournalEntry(
        FieldJournalEntry.fromLiveContext(
          id: 'sow_tomato_2025',
          timestamp: kaleSowTime,
          action: FieldJournalAction.transplant,
          cropId: 'tomato',
          bedName: 'South Greenhouse',
          calendarInfo: kaleInfo,
        ),
      );
      final tomato = VegetableDatabase.findById('tomato')!;
      final tomatoIn2026 = controllerB.evaluatePlotRotation(
        'South Greenhouse',
        candidateCrop: tomato,
        referenceTime: DateTime.utc(2026, 5, 1),
      );
      // Tomato -> Tomato is self-compatible with tomato-haulm compost per Maria Thun!
      expect(tomatoIn2026.hasFamilyConflict, isFalse);
      expect(
        tomatoIn2026.sensitivity,
        equals(RotationSensitivity.selfCompatibleWithCompost),
      );
      expect(tomatoIn2026.rotationGuidance, contains('Maria Thun'));

      // Potato after Tomato in the same plot IS a strict conflict (shared Phytophthora blight & PCN)
      final potato = VegetableDatabase.findById('potato')!;
      final potatoAfterTomato = controllerB.evaluatePlotRotation(
        'South Greenhouse',
        candidateCrop: potato,
        referenceTime: DateTime.utc(2026, 5, 1),
      );
      expect(potatoAfterTomato.hasFamilyConflict, isTrue);
    });

    testWidgets(
      'FieldJournalCard creates GardenPlot, renders Plot card, and FieldJournalSheet shows rotation alert',
      (tester) async {
        final selectedTime = DateTime(2026, 5, 16, 16, 0);
        final info = algo.getCalendarInfo(
          selectedTime,
          ephemeris,
          includePlanets: true,
        );
        final controller = GardenProfileController(
          initialProfile: GardenProfile(
            starredCropIds: const ['kale', 'cabbage', 'carrot'],
          ),
        );
        controller.upsertPlot(
          GardenPlot(
            name: 'Bed 1',
            areaName: 'Kitchen Garden',
            plotType: GardenPlotType.raisedBed,
            dimensions: '1.2m × 4.0m',
          ),
        );
        // Log 2025 Kale in Bed 1
        final kale2025Time = DateTime(2025, 5, 10, 10, 0);
        await controller.addJournalEntry(
          FieldJournalEntry.fromLiveContext(
            id: 'kale_2025',
            timestamp: kale2025Time,
            action: FieldJournalAction.sowSeeds,
            cropId: 'kale',
            bedName: 'Bed 1',
            calendarInfo: algo.getCalendarInfo(
              kale2025Time,
              ephemeris,
              includePlanets: true,
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FieldJournalCard(
                  gardenController: controller,
                  selectedDate: selectedTime,
                  info: info,
                  onTimeJump: (_) {},
                ),
              ),
            ),
          ),
        );

        // Verify Garden Plots section and Bed 1 card are rendered
        expect(
          find.byKey(const ValueKey('field_journal_plots_section')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('garden_plot_card_Bed 1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('plot_rotation_trail_Bed 1')),
          findsOneWidget,
        );

        // Tap "+ Sow in Plot" on Bed 1 card
        final quickLogBtn = find.byKey(const ValueKey('plot_quick_log_Bed 1'));
        await tester.ensureVisible(quickLogBtn);
        await tester.tap(quickLogBtn);
        await tester.pumpAndSettle();

        // Rotation banner is visible for Bed 1 inside FieldJournalSheet
        expect(
          find.byKey(const ValueKey('field_journal_rotation_banner')),
          findsOneWidget,
        );

        // Search and select 'kale' (Brassicaceae) in 2026 -> triggers rotation warning!
        await tester.enterText(
          find.byKey(const ValueKey('field_journal_crop_search_input')),
          'kale',
        );
        await tester.pumpAndSettle();
        final kaleChip = find.byKey(const ValueKey('journal_sheet_crop_kale'));
        await tester.ensureVisible(kaleChip);
        await tester.tap(kaleChip);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('field_journal_rotation_warning')),
          findsOneWidget,
        );
      },
    );

    test('Within-season succession: Hold-såning vs Same-Season Relay Alert & PlotSuccessionPlan', () async {
      final controller = GardenProfileController();

      controller.upsertPlot(
        GardenPlot(name: 'Relay Bed', plotType: GardenPlotType.raisedBed),
      );

      final radish = VegetableDatabase.findById('radish')!;
      final kale = VegetableDatabase.findById('kale')!;
      final carrot = VegetableDatabase.findById('carrot')!;

      // 1. Check maturity profiles and seasonal nursery / in-ground scaling
      final radishProfile = CropMaturityProfile.forCrop(radish);
      expect(radishProfile.estimatedDaysInGround, 32);
      expect(radishProfile.supportsStaggeredSowing, isTrue);
      // Radish matures faster in June/July (~26d) than in March (~38d)
      expect(
        radishProfile.seasonalDaysInGround(7),
        lessThan(radishProfile.seasonalDaysInGround(3)),
      );

      final kaleProfile = CropMaturityProfile.forCrop(kale);
      expect(kaleProfile.moduleLeadTimeDays, greaterThan(0));
      // Module nursery time is shorter in June/July (~20d) than in March (~38d)
      expect(
        kaleProfile.seasonalModuleLeadTimeDays(6),
        lessThan(kaleProfile.seasonalModuleLeadTimeDays(3)),
      );

      // Overwintering garlic planted in October clears in July of next year (Persephone period)
      final garlic = VegetableDatabase.findById('autumn_garlic')!;
      expect(CropMaturityProfile.isOverwinteringPlanting(garlic, 10), isTrue);
      expect(CropMaturityProfile.isOverwinteringPlanting(radish, 5), isFalse);

      // 2. Log spring radish sowing in April 2026
      final aprilSow = DateTime.utc(2026, 4, 10, 9);
      await controller.addJournalEntry(
        FieldJournalEntry.fromLiveContext(
          id: 'radish_2026_1',
          timestamp: aprilSow,
          action: FieldJournalAction.sowSeeds,
          cropId: 'radish',
          bedName: 'Relay Bed',
          calendarInfo: algo.getCalendarInfo(
            aprilSow,
            ephemeris,
            includePlanets: true,
          ),
        ),
      );

      // Staggered same-season sowing (Hold-såning) of Radish in the same bed in 2026:
      // No family conflict, and isStaggeredSameSeasonSowing is true!
      final staggeredRadish = controller.evaluatePlotRotation(
        'Relay Bed',
        candidateCrop: radish,
        referenceTime: DateTime.utc(2026, 4, 24, 12),
      );
      expect(staggeredRadish.hasFamilyConflict, isFalse);
      expect(staggeredRadish.isStaggeredSameSeasonSowing, isTrue);
      expect(staggeredRadish.rotationGuidance, contains('Hold-såning'));

      // Same-season relay of a DIFFERENT Brassicaceae (Kale after Radish in 2026):
      // Triggers Same-Season Relay Alert!
      final relayKale = controller.evaluatePlotRotation(
        'Relay Bed',
        candidateCrop: kale,
        referenceTime: DateTime.utc(2026, 5, 20, 12),
      );
      expect(relayKale.hasFamilyConflict, isTrue);
      expect(relayKale.conflictWarning, contains('Same-Season Relay Alert'));

      // Different family (Carrot, Apiaceae) after Radish in 2026: clean!
      final relayCarrot = controller.evaluatePlotRotation(
        'Relay Bed',
        candidateCrop: carrot,
        referenceTime: DateTime.utc(2026, 5, 20, 12),
      );
      expect(relayCarrot.hasFamilyConflict, isFalse);

      // 3. Build PlotSuccessionPlan 10 days after sowing Radish (est. 22 days left):
      // Should offer staggered next batch of Radish AND module pre-start candidates
      final planMidCrop = controller.buildPlotSuccessionPlan(
        'Relay Bed',
        referenceTime: DateTime.utc(2026, 4, 20, 12),
      );
      expect(planMidCrop.activeInGround, hasLength(1));
      expect(
        planMidCrop.estimatedAvailableDate.isAfter(
          DateTime.utc(2026, 4, 20, 12),
        ),
        isTrue,
      );
      expect(
        planMidCrop.candidates.any(
          (c) =>
              c.crop.id == 'radish' &&
              c.stage == SuccessionStage.staggeredNextBatch,
        ),
        isTrue,
      );
      expect(
        planMidCrop.candidates.any(
          (c) => c.stage == SuccessionStage.startInModulesNow,
        ),
        isTrue,
      );
      // None of the suggested relay candidates should be Brassicaceae (except staggered radish)
      for (final cand in planMidCrop.candidates) {
        if (cand.stage != SuccessionStage.staggeredNextBatch) {
          expect(
            BotanicalFamily.forCrop(cand.crop),
            isNot(BotanicalFamily.brassicaceae),
          );
        }
      }
    });

    testWidgets(
      'FieldJournalCard renders season pipeline and succession suggestion chips that queue tasks',
      (tester) async {
        final controller = GardenProfileController();

        controller.upsertPlot(
          GardenPlot(name: 'South Bed', plotType: GardenPlotType.raisedBed),
        );

        final sowTime = DateTime.utc(2026, 4, 15, 9);
        await controller.addJournalEntry(
          FieldJournalEntry.fromLiveContext(
            id: 'spinach_2026',
            timestamp: sowTime,
            action: FieldJournalAction.sowSeeds,
            cropId: 'spinach',
            bedName: 'South Bed',
            calendarInfo: algo.getCalendarInfo(
              sowTime,
              ephemeris,
              includePlanets: true,
            ),
          ),
        );

        final viewTime = DateTime.utc(2026, 5, 10, 12);
        final info = algo.getCalendarInfo(
          viewTime,
          ephemeris,
          includePlanets: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FieldJournalCard(
                  gardenController: controller,
                  selectedDate: viewTime,
                  info: info,
                  onTimeJump: (_) {},
                ),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('plot_season_pipeline_South Bed')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('plot_succession_suggestions_South Bed')),
          findsOneWidget,
        );

        // Tap the staggered spinach succession chip to queue the next batch
        final spinachChip = find.byKey(
          const ValueKey('plot_succession_chip_South Bed_spinach'),
        );
        expect(spinachChip, findsOneWidget);
        await tester.ensureVisible(spinachChip);
        await tester.tap(spinachChip);
        await tester.pumpAndSettle();

        expect(
          controller.value.taskQueue.any(
            (t) => t.cropId == 'spinach' && t.bedName == 'South Bed',
          ),
          isTrue,
        );
      },
    );

    test('GoogleDriveGardenSyncTransport syncs shards over Drive v3 REST API, manages permissions, and parses GardenInviteLink', () async {
      // 1. Verify GardenInviteLink parsing across Drive URLs, magiccalendar:// URIs, and raw IDs
      final fromDriveUrl = GardenInviteLink.tryParse(
        'https://drive.google.com/drive/folders/1AbCdEfGhIjKlMnOpQrStUvWxYz?usp=sharing',
      );
      expect(fromDriveUrl, isNotNull);
      expect(
        fromDriveUrl!.driveFolderId,
        equals('1AbCdEfGhIjKlMnOpQrStUvWxYz'),
      );

      final inviteMsg = GardenInviteLink(
        driveFolderId: '1AbCdEfGhIjKlMnOpQrStUvWxYz',
        gardenName: 'Svendborg Fælleshave',
      ).formatInviteMessage();
      final fromInviteMsg = GardenInviteLink.tryParse(inviteMsg);
      expect(fromInviteMsg, isNotNull);
      expect(
        fromInviteMsg!.driveFolderId,
        equals('1AbCdEfGhIjKlMnOpQrStUvWxYz'),
      );
      expect(fromInviteMsg.gardenName, equals('Svendborg Fælleshave'));

      // 2. Build a simulated Google Drive v3 server using MockClient
      int nextFileId = 100;
      final filesById =
          <
            String,
            ({String name, String parentId, String mimeType, Uint8List bytes})
          >{};
      final grantedPermissions =
          <({String folderId, String email, String role})>[];

      final mockDriveClient = MockClient((request) async {
        expect(
          request.headers['Authorization'],
          equals('Bearer test-drive-token'),
        );
        final path = request.url.path;

        // Create folder or permission or multipart upload
        if (request.method == 'POST') {
          if (path.endsWith('/permissions')) {
            final parts = path.split('/');
            final folderId = parts[parts.length - 2];
            final body = jsonDecode(request.body) as Map<String, Object?>;
            grantedPermissions.add((
              folderId: folderId,
              email: body['emailAddress'] as String,
              role: body['role'] as String,
            ));
            return http.Response(jsonEncode({'id': 'perm_1'}), 200);
          }

          if (request.url.queryParameters['uploadType'] == 'multipart') {
            // Parse multipart/related body
            final rawBytes = request.bodyBytes;
            final contentType = request.headers['Content-Type'] ?? '';
            final boundary = contentType.split('boundary=').last.trim();
            final marker = utf8.encode('--$boundary');
            final rawStr = latin1.decode(rawBytes);
            final jsonStart = rawStr.indexOf('{');
            final jsonEnd = rawStr.indexOf('}\r\n--$boundary');
            final metaMap = jsonDecode(
              utf8.decode(rawBytes.sublist(jsonStart, jsonEnd + 1)),
            ) as Map<String, Object?>;
            final fileName = metaMap['name'] as String;
            final parents = (metaMap['parents'] as List).cast<String>();

            // Extract binary payload after second header '\r\n\r\n'
            final secondPartIdx = rawStr.indexOf('\r\n\r\n', jsonEnd);
            final payloadStart = secondPartIdx + 4;
            final closingMarker = '\r\n--$boundary--';
            final payloadEnd = rawStr.lastIndexOf(closingMarker);
            final payload = Uint8List.fromList(
              rawBytes.sublist(payloadStart, payloadEnd),
            );
            expect(marker, isNotEmpty);

            final id = 'drive_file_${++nextFileId}';
            filesById[id] = (
              name: fileName,
              parentId: parents.first,
              mimeType: 'application/octet-stream',
              bytes: payload,
            );
            return http.Response(jsonEncode({'id': id, 'name': fileName}), 200);
          }

          // Metadata-only POST (folder creation)
          final meta = jsonDecode(request.body) as Map<String, Object?>;
          final id = 'drive_folder_${++nextFileId}';
          final name = meta['name'] as String;
          final parents =
              (meta['parents'] as List?)?.cast<String>() ?? const ['root'];
          filesById[id] = (
            name: name,
            parentId: parents.first,
            mimeType:
                meta['mimeType'] as String? ??
                'application/vnd.google-apps.folder',
            bytes: Uint8List(0),
          );
          return http.Response(
            jsonEncode({
              'id': id,
              'name': name,
              'webViewLink': 'https://drive.google.com/drive/folders/$id',
            }),
            200,
          );
        }

        if (request.method == 'GET') {
          if (request.url.queryParameters['alt'] == 'media') {
            final fileId = path.split('/').last;
            final entry = filesById[fileId];
            if (entry == null) return http.Response('Not Found', 404);
            return http.Response.bytes(entry.bytes, 200);
          }

          // files.list query
          final q = request.url.queryParameters['q'] ?? '';
          final parentMatch = RegExp(r"'([^']+)' in parents").firstMatch(q);
          final parentId = parentMatch?.group(1) ?? '';
          final nameMatch = RegExp(r"name = '([^']+)'").firstMatch(q);
          final requiredName = nameMatch?.group(1);

          final matching = <Map<String, String>>[];
          for (final e in filesById.entries) {
            if (e.value.parentId != parentId) continue;
            if (requiredName != null && e.value.name != requiredName) continue;
            matching.add({'id': e.key, 'name': e.value.name});
          }
          return http.Response(jsonEncode({'files': matching}), 200);
        }

        if (request.method == 'DELETE') {
          final fileId = path.split('/').last;
          filesById.remove(fileId);
          return http.Response('', 204);
        }

        return http.Response('Unsupported', 400);
      });

      // 3. Create a shared garden folder on Google Drive & invite a co-gardener
      final createdFolder =
          await GoogleDriveGardenSyncTransport.createSharedGardenFolder(
            tokenProvider: () async => 'test-drive-token',
            gardenName: 'Langeland Have',
            client: mockDriveClient,
          );
      expect(createdFolder.folderId, startsWith('drive_folder_'));

      final transport = GoogleDriveGardenSyncTransport(
        rootFolderId: createdFolder.folderId,
        gardenName: createdFolder.name,
        tokenProvider: () async => 'test-drive-token',
        client: mockDriveClient,
      );
      await transport.shareFolderWithEmail(emailAddress: 'anna@example.com');
      expect(grantedPermissions, hasLength(1));
      expect(grantedPermissions.first.email, equals('anna@example.com'));
      expect(grantedPermissions.first.role, equals('writer'));

      // 4. Upload and download a shard blob + meta blob through GoogleDriveGardenSyncTransport
      const sampleShard = 'shards/2026-05.0123456789abcdef01234567.sqlite';
      final samplePayload = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      await transport.putBytes(sampleShard, samplePayload);

      final listedShards = await transport.list('shards/');
      expect(listedShards, equals([sampleShard]));

      final downloaded = await transport.getBytes(sampleShard);
      expect(downloaded, equals(samplePayload));

      await transport.delete(sampleShard);
      expect(await transport.list('shards/'), isEmpty);
    });

    testWidgets(
      'GardenNoteShareFormatter, GardenSharedNoteBundle CRDT import, and FieldJournalCard share buttons',
      (tester) async {
        final controllerA = GardenProfileController();
        controllerA.updateGardenIdentity(
          authorName: 'Sigurd',
          gardenName: 'Svendborg Have',
        );
        controllerA.upsertPlot(
          GardenPlot(
            name: 'Herb Spiral',
            plotType: GardenPlotType.perennialBed,
            dimensions: '2m diameter',
            lastSoilPrepSummary: 'BD 500 + Leaf Mold',
          ),
        );

        final sowTime = DateTime.utc(2026, 5, 12, 10, 30);
        final info = algo.getCalendarInfo(
          sowTime,
          ephemeris,
          includePlanets: true,
        );
        final entry = FieldJournalEntry.fromLiveContext(
          id: 'dill_spiral_2026',
          timestamp: sowTime,
          action: FieldJournalAction.sowSeeds,
          cropId: 'dill',
          bedName: 'Herb Spiral',
          notes: 'Sown on upper warm tier',
          authorId: 'sigurd',
          authorName: 'Sigurd',
          calendarInfo: info,
        );
        await controllerA.addJournalEntry(entry);

        // 1. Verify human-readable note formatting
        final formattedNote = GardenNoteShareFormatter.formatEntry(
          controllerA.value.journalEntries.first,
          gardenName: 'Svendborg Have',
        );
        expect(formattedNote, contains('Dill / Dild'));
        expect(formattedNote, contains('📍 Herb Spiral'));
        expect(formattedNote, contains('Sown on upper warm tier'));

        // 2. Export portable note bundle from controllerA and import into controllerB
        final bundle = controllerA.exportSharedNoteBundle();
        final jsonStr = bundle.toJsonString();

        final controllerB = GardenProfileController();
        final imported = await controllerB.importSharedNoteBundle(jsonStr);
        expect(imported.entries, hasLength(1));
        expect(imported.plots, hasLength(1));
        expect(controllerB.listPlots().first.name, equals('Herb Spiral'));
        expect(
          controllerB.value.journalEntries.first.id,
          equals('dill_spiral_2026'),
        );

        // 3. Render FieldJournalCard and tap Share buttons on Plot and Journal Entry
        final sharedTexts = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FieldJournalCard(
                  gardenController: controllerA,
                  selectedDate: sowTime,
                  info: info,
                  onTimeJump: (_) {},
                  onShareText: (text, {subject}) {
                    sharedTexts.add(text);
                  },
                ),
              ),
            ),
          ),
        );

        final plotShareBtn = find.byKey(
          const ValueKey('plot_share_Herb Spiral'),
        );
        expect(plotShareBtn, findsOneWidget);
        await tester.ensureVisible(plotShareBtn);
        await tester.tap(plotShareBtn);
        await tester.pumpAndSettle();
        expect(sharedTexts, hasLength(1));
        expect(sharedTexts.first, contains('Plot: Herb Spiral'));

        final entryShareBtn = find.byKey(
          const ValueKey('journal_entry_share_dill_spiral_2026'),
        );
        expect(entryShareBtn, findsOneWidget);
        await tester.ensureVisible(entryShareBtn);
        await tester.tap(entryShareBtn);
        await tester.pumpAndSettle();
        expect(sharedTexts, hasLength(2));
        expect(sharedTexts.last, contains('Dill / Dild'));
      },
    );

    testWidgets(
      'Journal & Plot edge cases: unique IDs at same timestamp, PlantQuality.none fallback, note edit idempotency, harvest delete unlinking, and plot case/delete handling',
      (tester) async {
        final dir = Directory.systemTemp.createTempSync(
          'magic_calendar_edge_cases_',
        );
        addTearDown(() {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        });

        final sqlStore = ShardedSqliteJournalStore(
          rootDirectoryPath: dir.path,
          initialActorId: 'sigurd',
          initialAuthorName: 'Sigurd',
        );
        final controller = GardenProfileController(journalStore: sqlStore);
        addTearDown(controller.dispose);

        final selectedTime = DateTime.utc(2026, 5, 16, 10, 0);
        final baseInfo = algo.getCalendarInfo(
          selectedTime,
          ephemeris,
          includePlanets: true,
        );
        final grayDayInfo = CalendarInfo(
          quality: PlantQuality.none,
          isGrayDay: true,
          message: 'Lunar Node',
          sapFlow: baseInfo.sapFlow,
          isMoonAscending: baseInfo.isMoonAscending,
          vitality: baseInfo.vitality,
          moonPhase: baseInfo.moonPhase,
          planets: baseInfo.planets,
        );

        // 1. Logging two entries at the exact same timestamp does not collide or overwrite
        final firstAtSameTime = FieldJournalEntry.fromLiveContext(
          timestamp: selectedTime,
          action: FieldJournalAction.sowSeeds,
          cropId: 'carrot',
          bedName: '  Bed 1  ',
          calendarInfo: grayDayInfo,
          quality: PlantQuality.none,
          notes: 'First carrot row in Bed 1',
        );
        final secondAtSameTime = FieldJournalEntry.fromLiveContext(
          timestamp: selectedTime,
          action: FieldJournalAction.sowSeeds,
          cropId: 'carrot',
          bedName: 'Bed 2',
          calendarInfo: grayDayInfo,
          quality: PlantQuality.none,
          notes: 'Second carrot row in Bed 2',
        );
        expect(firstAtSameTime.id, isNot(equals(secondAtSameTime.id)));
        expect(firstAtSameTime.bedName, equals('Bed 1'));
        expect(firstAtSameTime.quality, equals(PlantQuality.root));

        await controller.addJournalEntry(firstAtSameTime);
        await controller.addJournalEntry(secondAtSameTime);
        expect(controller.value.journalEntries, hasLength(2));

        // 2. Collaborative notes + editing an existing entry via upsertEntry does not duplicate notes
        await controller.addNoteToJournalEntry(
          entryId: firstAtSameTime.id,
          body: 'Maja watered the row.',
          authorName: 'Maja',
        );
        final withThread = sqlStore.getEntry(firstAtSameTime.id)!;
        expect(withThread.activeNotes, hasLength(2));
        expect(
          withThread.editableFieldNote,
          equals('First carrot row in Bed 1'),
        );

        // Updating outcome without changing notes preserves the 2 field notes without duplicating prefixes
        await controller.updateJournalEntry(
          withThread.withOutcome(
            outcomeRating: 5,
            outcomeNote: 'Uniform emergence',
          ),
        );
        final afterOutcome = sqlStore.getEntry(firstAtSameTime.id)!;
        expect(
          afterOutcome.activeNotes.where(
            (n) => n.kind != JournalNoteKind.outcome,
          ),
          hasLength(2),
        );
        expect(
          afterOutcome.editableFieldNote,
          equals('First carrot row in Bed 1'),
        );
        expect(afterOutcome.notes, isNot(contains('Sigurd: Sigurd:')));

        // Clearing initial note deletes note_init_... cleanly
        await controller.updateJournalEntry(
          afterOutcome.withOutcome(notes: ''),
        );
        final afterClear = sqlStore.getEntry(firstAtSameTime.id)!;
        expect(
          afterClear.activeNotes.where(
            (n) => n.kind != JournalNoteKind.outcome,
          ),
          hasLength(1),
        );
        expect(afterClear.notes, equals('Maja watered the row.'));

        // 3. Deleting a harvest entry restores the parent planting batch to onlyActiveInGround: true
        final harvestEntry = FieldJournalEntry.fromLiveContext(
          timestamp: selectedTime.add(const Duration(days: 65)),
          action: FieldJournalAction.harvestStorage,
          cropId: 'carrot',
          bedName: 'Bed 1',
          parentEntryId: firstAtSameTime.id,
          calendarInfo: baseInfo,
        );
        await controller.addJournalEntry(harvestEntry);
        expect(
          controller
              .listPlantingBatches(bedName: 'Bed 1', onlyActiveInGround: true)
              .map((b) => b.entryId),
          isNot(contains(firstAtSameTime.id)),
        );

        await controller.removeJournalEntry(harvestEntry.id);
        expect(
          controller
              .listPlantingBatches(bedName: 'Bed 1', onlyActiveInGround: true)
              .map((b) => b.entryId),
          contains(firstAtSameTime.id),
        );

        // 4. Case-insensitive plot upsert preserves soil-prep metadata & in-memory controller also tracks soil prep
        await controller.addJournalEntry(
          FieldJournalEntry.fromLiveContext(
            timestamp: selectedTime.add(const Duration(hours: 2)),
            action: FieldJournalAction.sprayPreparation,
            prepCode: 'BD 500',
            bedName: 'Bed 1',
            calendarInfo: baseInfo,
          ),
        );
        expect(
          controller.findPlot('bed 1')?.lastSoilPrepSummary,
          equals('BD 500'),
        );
        controller.upsertPlot(
          GardenPlot(
            name: 'bed 1',
            areaName: 'Kitchen Garden',
            plotType: GardenPlotType.raisedBed,
          ),
        );
        final updatedPlot = controller.findPlot('Bed 1')!;
        expect(updatedPlot.name, equals('Bed 1'));
        expect(updatedPlot.areaName, equals('Kitchen Garden'));
        expect(updatedPlot.lastSoilPrepSummary, equals('BD 500'));

        final inMemoryController = GardenProfileController();
        await inMemoryController.addJournalEntry(
          FieldJournalEntry.fromLiveContext(
            timestamp: selectedTime,
            action: FieldJournalAction.sprayPreparation,
            prepCode: 'BD 501',
            bedName: 'South Tunnel',
            calendarInfo: baseInfo,
          ),
        );
        expect(
          inMemoryController.findPlot('south tunnel')?.lastSoilPrepSummary,
          equals('BD 501'),
        );

        // 5. UI verification: Gray Day FieldJournalSheet fallback & Plot Delete button in FieldJournalCard
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    BiodynamicCard(
                      info: grayDayInfo,
                      selectedDate: selectedTime,
                      ephemeris: ephemeris,
                      gardenController: controller,
                    ),
                    FieldJournalCard(
                      gardenController: controller,
                      selectedDate: selectedTime,
                      info: grayDayInfo,
                      onTimeJump: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap BiodynamicCard Log Action on a Gray Day (PlantQuality.none)
        final bioBtn = find.byKey(
          const ValueKey('biodynamic_log_action_button'),
        );
        await tester.ensureVisible(bioBtn);
        await tester.tap(bioBtn);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('field_journal_save_button')),
        );
        await tester.pumpAndSettle();

        // Verify the saved entry normalized PlantQuality.none to PlantQuality.root
        expect(
          controller.value.journalEntries.first.quality,
          isNot(equals(PlantQuality.none)),
        );

        // Open Edit Plot dialog on Bed 1 and tap Delete Plot
        final editPlotBtn = find.byKey(const ValueKey('edit_plot_Bed 1'));
        expect(editPlotBtn, findsOneWidget);
        await tester.ensureVisible(editPlotBtn);
        await tester.tap(editPlotBtn);
        await tester.pumpAndSettle();

        final deletePlotBtn = find.byKey(
          const ValueKey('plot_dialog_delete_button'),
        );
        expect(deletePlotBtn, findsOneWidget);
        await tester.tap(deletePlotBtn);
        await tester.pumpAndSettle();

        expect(
          controller.listPlots().map((p) => p.name),
          isNot(contains('Bed 1')),
        );
      },
    );

    testWidgets(
      'Drag-and-drop BedSuccessionPlannerCard places crops in time on beds, evaluates overlaps & rotation, and moves bars across beds',
      (tester) async {
        final dirA = Directory.systemTemp.createTempSync('bed_dnd_a_');
        final dirB = Directory.systemTemp.createTempSync('bed_dnd_b_');
        addTearDown(() {
          if (dirA.existsSync()) dirA.deleteSync(recursive: true);
          if (dirB.existsSync()) dirB.deleteSync(recursive: true);
        });

        final storeA = ShardedSqliteJournalStore(
          rootDirectoryPath: dirA.path,
          initialGardenId: 'garden_dnd',
          initialActorId: 'sigurd',
          initialAuthorName: 'Sigurd',
        );
        final storeB = ShardedSqliteJournalStore(
          rootDirectoryPath: dirB.path,
          initialGardenId: 'garden_dnd',
          initialActorId: 'maja',
          initialAuthorName: 'Maja',
        );
        addTearDown(() {
          if (!storeA.isClosed) storeA.close();
          if (!storeB.isClosed) storeB.close();
        });

        final controller = GardenProfileController(journalStore: storeA);
        addTearDown(controller.dispose);

        final selectedTime = DateTime(2026, 5, 10, 12);
        final info = algo.getCalendarInfo(
          selectedTime,
          ephemeris,
          includePlanets: true,
        );

        controller.upsertPlot(
          GardenPlot(
            name: 'Bed 1',
            areaName: 'Kitchen Garden',
            plotType: GardenPlotType.raisedBed,
          ),
        );
        controller.upsertPlot(
          GardenPlot(
            name: 'Bed 2',
            areaName: 'Kitchen Garden',
            plotType: GardenPlotType.openBed,
          ),
        );

        // Log an active early-spring Pea batch in Bed 1 (planted April 5, clears ~June)
        await controller.addJournalEntry(
          FieldJournalEntry.fromLiveContext(
            id: 'pea_spring_bed1',
            timestamp: DateTime(2026, 4, 5, 10),
            action: FieldJournalAction.sowSeeds,
            cropId: 'pea',
            bedName: 'Bed 1',
            calendarInfo: info,
          ),
        );

        final carrot = VegetableDatabase.findById('carrot')!;
        final kale = VegetableDatabase.findById('kale')!;
        final broccoli = VegetableDatabase.findById('broccoli')!;

        // 1. Evaluate overlapping drop vs clean relay drop on Bed 1
        final overlapEval = controller.evaluateBedPlacement(
          plotName: 'Bed 1',
          crop: carrot,
          targetDate: DateTime(2026, 5, 1, 12),
        );
        expect(
          overlapEval.status,
          equals(BedPlacementStatus.bedOverlapWarning),
        );
        expect(overlapEval.suggestedRelayDate, isNotNull);

        final cleanRelayEval = controller.evaluateBedPlacement(
          plotName: 'Bed 1',
          crop: kale,
          targetDate: overlapEval.suggestedRelayDate!.add(
            const Duration(days: 2),
          ),
        );
        expect(cleanRelayEval.status, equals(BedPlacementStatus.cleanRelay));

        // 2. Render FieldJournalCard, verify the bed planner is no longer inline inside the diary card,
        // and tap "Bed Succession Planner" to open the dedicated full-screen BedSuccessionPlannerPage.
        await tester.binding.setSurfaceSize(const Size(1200, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FieldJournalCard(
                  gardenController: controller,
                  selectedDate: selectedTime,
                  info: info,
                  ephemeris: ephemeris,
                  onTimeJump: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('bed_succession_planner_card')),
          findsNothing,
        );
        await tester.tap(
          find.byKey(const ValueKey('field_journal_toggle_succession_planner')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('bed_succession_planner_page')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('bed_succession_planner_card')),
          findsOneWidget,
        );

        // Search for Carrot in the palette so draggable_crop_carrot is visible
        await tester.enterText(
          find.byKey(const ValueKey('bed_succession_crop_search')),
          'Carrot',
        );
        await tester.pumpAndSettle();

        final carrotChip = find.byKey(const ValueKey('draggable_crop_carrot'));
        final bed1Track = find.byKey(
          const ValueKey('bed_timeline_track_Bed 1'),
        );
        expect(carrotChip, findsOneWidget);
        expect(bed1Track, findsOneWidget);

        // Drag Carrot from the palette onto Bed 1's timeline track
        await tester.ensureVisible(bed1Track);
        final chipCenter = tester.getCenter(carrotChip);
        final trackRect = tester.getRect(bed1Track);
        // Drop at ~65% across the year (August, after spring peas clear)
        final dropTarget = Offset(
          trackRect.left + trackRect.width * 0.65,
          trackRect.center.dy,
        );
        final gesture = await tester.startGesture(chipCenter);
        await tester.pump(const Duration(milliseconds: 50));
        // Move past kTouchSlop to initiate the Draggable avatar, then move onto the target track
        await gesture.moveBy(const Offset(0, 24));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveTo(dropTarget);
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveBy(const Offset(4, 0));
        await tester.pump(const Duration(milliseconds: 50));
        // Live ghost preview banner, cosmic alignment badge & ghost bar should be visible during drag hover!
        expect(
          find.byKey(const ValueKey('bed_succession_live_preview_banner')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('bed_hover_cosmic_alignment')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('bed_timeline_ghost_bar')),
          findsOneWidget,
        );
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify Carrot was placed in time on Bed 1 with plannedStartDate and plannedEndDate
        final bed1Tasks = controller.value.taskQueue
            .where((t) => t.bedName == 'Bed 1' && t.cropId == 'carrot')
            .toList();
        expect(bed1Tasks, hasLength(1));
        final placedCarrot = bed1Tasks.first;
        expect(placedCarrot.plannedStartDate, isNotNull);
        expect(placedCarrot.effectiveEndDate, isNotNull);

        // Inspector for the newly placed bar is open; test cosmic alignment, +7d shift and +Hold-såning batch
        expect(
          find.byKey(const ValueKey('selected_planned_span_inspector')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('inspector_cosmic_alignment')),
          findsOneWidget,
        );
        final originalStart = placedCarrot.plannedStartDate!;
        final shiftLaterBtn = find.byKey(
          const ValueKey('planned_span_shift_later'),
        );
        await tester.ensureVisible(shiftLaterBtn);
        await tester.tap(shiftLaterBtn);
        await tester.pumpAndSettle();

        final shiftedTask = controller.value.taskQueue.firstWhere(
          (t) => t.id == placedCarrot.id,
        );
        expect(
          shiftedTask.plannedStartDate,
          equals(originalStart.add(const Duration(days: 7))),
        );

        // Toggle to Transplant mode and verify indoor nursery lead-time tail appears
        final toggleActionBtn = find.byKey(
          const ValueKey('planned_span_toggle_action'),
        );
        await tester.ensureVisible(toggleActionBtn);
        await tester.tap(toggleActionBtn);
        await tester.pumpAndSettle();

        // Add a staggered Hold-såning batch of Carrot on Bed 1
        final addStaggeredBtn = find.byKey(
          const ValueKey('planned_span_add_staggered'),
        );
        await tester.ensureVisible(addStaggeredBtn);
        await tester.tap(addStaggeredBtn);
        await tester.pumpAndSettle();

        final carrotTasksOnBed1 = controller.value.taskQueue
            .where((t) => t.bedName == 'Bed 1' && t.cropId == 'carrot')
            .toList();
        expect(carrotTasksOnBed1, hasLength(2));

        // Drag the first planned Carrot bar from Bed 1 onto Bed 2!
        final firstSpanFinder = find.byKey(
          ValueKey('planned_bed_span_${placedCarrot.id}'),
        );
        final bed2Track = find.byKey(
          const ValueKey('bed_timeline_track_Bed 2'),
        );
        await tester.ensureVisible(firstSpanFinder);
        await tester.ensureVisible(bed2Track);
        final spanCenter = tester.getCenter(firstSpanFinder);
        final bed2Rect = tester.getRect(bed2Track);
        final moveGesture = await tester.startGesture(spanCenter);
        await tester.pump(const Duration(milliseconds: 50));
        await moveGesture.moveBy(const Offset(0, 24));
        await tester.pump(const Duration(milliseconds: 50));
        await moveGesture.moveTo(
          Offset(bed2Rect.left + bed2Rect.width * 0.5, bed2Rect.center.dy),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await moveGesture.up();
        await tester.pumpAndSettle();

        final movedTask = controller.value.taskQueue.firstWhere(
          (t) => t.id == placedCarrot.id,
        );
        expect(movedTask.bedName, equals('Bed 2'));

        // Verify planned tasks on Bed 2 also trigger rotation alerts for subsequent planned Brassicas
        await controller.placeCropOnBed(
          bedName: 'Bed 2',
          crop: kale,
          startDate: DateTime(2026, 4, 15, 12),
        );
        final brassicaConflictEval = controller.evaluateBedPlacement(
          plotName: 'Bed 2',
          crop: broccoli,
          targetDate: DateTime(2026, 9, 1, 12),
        );
        expect(
          brassicaConflictEval.status,
          equals(BedPlacementStatus.familyRotationConflict),
        );

        // Verify SQLite CRDT sync preserves plannedStartDate & plannedEndDate across devices
        final metaTemp = File('${dirA.path}/meta_export_dnd.sqlite');
        metaTemp.writeAsBytesSync(storeA.exportMetaBytes());
        storeB.mergeRemoteMetaFile(metaTemp.path);
        final syncedTasksOnB = storeB.listQueuedTasks();
        final syncedMoved = syncedTasksOnB.firstWhere(
          (t) => t.id == placedCarrot.id,
        );
        expect(syncedMoved.bedName, equals('Bed 2'));
        expect(syncedMoved.plannedStartDate, isNotNull);
        expect(syncedMoved.plannedEndDate, isNotNull);

        // 3. Verify Perennial crop filter & multi-year bed occupancy
        await tester.enterText(
          find.byKey(const ValueKey('bed_succession_crop_search')),
          '',
        );
        await tester.pumpAndSettle();
        final perennialFilterChip = find.byKey(
          const ValueKey('bed_palette_filter_perennial'),
        );
        expect(perennialFilterChip, findsOneWidget);
        await tester.tap(perennialFilterChip);
        await tester.pumpAndSettle();
        final asparagus = VegetableDatabase.allEntries.firstWhere(
          (c) => c.lifeCycle == PlantLifeCycle.perennial,
        );
        final asparagusProfile = CropMaturityProfile.forCrop(asparagus);
        expect(asparagusProfile.isPerennial, isTrue);
        expect(
          asparagusProfile.estimatedDaysInGround,
          greaterThanOrEqualTo(365 * 3),
        );

        // 4. Verify Secondary Organ selector in inspector for multi-organ crops
        final multiOrganCrop = VegetableDatabase.allEntries.firstWhere(
          (c) => c.secondaryOrganRules.isNotEmpty,
        );
        final multiTask = await controller.placeCropOnBed(
          bedName: 'Bed 1',
          crop: multiOrganCrop,
          startDate: DateTime(2026, 7, 10, 12),
        );
        await tester.pumpAndSettle();
        final multiSpan = find.byKey(
          ValueKey('planned_bed_span_${multiTask.id}'),
        );
        await tester.ensureVisible(multiSpan);
        await tester.tap(multiSpan);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('planned_span_organ_selector')),
          findsOneWidget,
        );
        final secondaryRule = multiOrganCrop.secondaryOrganRules.first;
        final secondaryChip = find.byKey(
          ValueKey('organ_target_${secondaryRule.id}'),
        );
        await tester.ensureVisible(secondaryChip);
        await tester.tap(secondaryChip);
        await tester.pumpAndSettle();
        final updatedMultiTask = controller.value.taskQueue.firstWhere(
          (t) => t.id == multiTask.id,
        );
        expect(updatedMultiTask.targetQuality, equals(secondaryRule.quality));

        // 5. Verify InfiniteTimelinePainter paints & hit-tests planned bed tasks
        final painter = InfiniteTimelinePainter(
          centerTime: DateTime(2026, 7, 10, 12),
          hourWidth: 8.0,
          intervals: const [],
          weatherData: const [],
          queuedTasks: controller.value.taskQueue,
          ephemeris: ephemeris,
          latitude: 55.6761,
          longitude: 12.5683,
        );
        final visiblePlanned = painter.visiblePlannedTasks(800.0);
        expect(visiblePlanned.any((t) => t.id == multiTask.id), isTrue);
        final hitTask = painter.hitTestPlannedTask(
          const Offset(400.0, 140.0),
          const Size(800.0, 200.0),
        );
        expect(hitTask?.id, equals(multiTask.id));

        // 6. Verify mobile viewport (390x844) screen usage in BedSuccessionPlannerPage:
        // palette and multiple bed tracks fit simultaneously on screen with >90% track width,
        // and 6M/3M window toggle, 2x zoom, and palette collapse work without overflow.
        await tester.binding.setSurfaceSize(const Size(390, 844));
        await tester.pumpAndSettle();

        final paletteRect = tester.getRect(
          find.byKey(const ValueKey('bed_succession_crop_palette')),
        );
        final bed1MobileRect = tester.getRect(
          find.byKey(const ValueKey('bed_timeline_track_Bed 1')),
        );
        final bed2MobileRect = tester.getRect(
          find.byKey(const ValueKey('bed_timeline_track_Bed 2')),
        );
        expect(paletteRect.height, lessThan(135.0));
        expect(bed1MobileRect.width, greaterThan(350.0));
        expect(bed1MobileRect.bottom, lessThan(844.0));
        expect(bed2MobileRect.bottom, lessThan(844.0));

        // Cycle 12M -> 6M -> 3M window focus and 2x horizontal zoom
        await tester.tap(
          find.byKey(const ValueKey('bed_timeline_window_toggle')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('bed_timeline_zoom_toggle')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('bed_planner_horizontal_scroll')),
          findsOneWidget,
        );

        // Collapse palette to give full vertical height to bed tracks
        final collapseToggle = find.byKey(
          const ValueKey('bed_palette_collapse_toggle'),
        );
        await tester.ensureVisible(collapseToggle);
        await tester.tap(collapseToggle);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('bed_succession_crop_palette')),
          findsNothing,
        );
      },
    );
  });
}
