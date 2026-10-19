import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/algorithm.dart' as algo;
import 'package:magic_calendar/src/core/models/models.dart';
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
}
