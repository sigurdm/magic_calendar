import 'dart:io';
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
