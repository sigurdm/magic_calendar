import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:magic_calendar/src/core/algorithm.dart' as algo;
import 'package:magic_calendar/src/core/biodynamic_prep.dart';
import 'package:magic_calendar/src/core/dornach_boundaries.dart';
import 'package:magic_calendar/src/core/ecological_synthesis.dart';
import 'package:magic_calendar/src/core/ics_calendar_exporter.dart';
import 'package:magic_calendar/src/core/seasonal_calendar.dart';
import 'package:magic_calendar/src/core/task_window_planner.dart';
import 'package:magic_calendar/src/core/vegetable_database.dart';
import 'package:magic_calendar/src/repository/open_meteo_client.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:magic_calendar/src/services/garden_service.dart';
import 'package:magic_calendar/src/services/weather_service.dart'
    hide WeatherDataPoint;
import 'package:magic_calendar/src/ui/components/bed_succession_planner_card.dart';
import 'package:magic_calendar/src/ui/components/concoction_assistant_dialog.dart';
import 'package:magic_calendar/src/ui/components/curved_text.dart';
import 'package:magic_calendar/src/ui/components/field_journal_card.dart';
import 'package:magic_calendar/src/ui/components/home_header.dart';
import 'package:magic_calendar/src/ui/components/location_picker_dialog.dart';
import 'package:magic_calendar/src/ui/components/organic_vessel_container.dart';
import 'package:magic_calendar/src/ui/components/planetary_ribbon.dart';
import 'package:magic_calendar/src/ui/components/stirring_timer_dialog.dart';
import 'package:magic_calendar/src/ui/painters/infinite_timeline_painter.dart';
import 'package:magic_calendar/src/ui/painters/moon_painter.dart';
import 'package:magic_calendar/src/ui/theme/biodynamic_icons.dart';
import 'package:sweph/sweph.dart';

import 'support/sweph_test_loader.dart';

void main() {
  setUpAll(() async {
    await ensureSwephLoaded();
    await Sweph.init();
  });

  group('Regression Tests for Verified Bug Fixes', () {
    test('InfiniteTimelinePainter clamps solar dot product to prevent NaN blackout at zenith', () {
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
    });

    test('InfiniteTimelinePainter paints across DST spring forward transition without error', () {
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
    });

    test('InfiniteTimelinePainter does not throw division by zero on hourWidth <= 0', () {
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
    });

    test('getCalendarInfo computes dynamic sapFlow even with includePlanets: false', () {
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
        reason: 'sapFlow must vary based on Moon declination even when includePlanets is false',
      );
    });

    test('MoonPainter handles non-square aspect ratio without error and checks equality in shouldRepaint', () {
      const info = MoonPhaseInfo(
        illuminatedFraction: 0.5,
        isWaxing: true,
        phaseAngle: 90.0,
      );
      final painter = MoonPainter(info: info);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Non-square size: 200x50
      expect(() => painter.paint(canvas, const Size(200, 50)), returnsNormally);

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
    });

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

  group('Core Health Regression Tests', () {
    test('Polar latitude diurnal rhythm distinguishes night, morning, and afternoon phases', () {
      // Tromsø (69.65°N, 18.96°E) during summer solstice midnight sun
      final nightInfo = algo.getCalendarInfo(
        DateTime.utc(2026, 6, 20, 3, 0),
        AstronomiaEphemerisService(),
        latitude: 69.65,
        longitude: 18.96,
      );
      final morningInfo = algo.getCalendarInfo(
        DateTime.utc(2026, 6, 21, 8, 0),
        AstronomiaEphemerisService(),
        latitude: 69.65,
        longitude: 18.96,
      );
      final afternoonInfo = algo.getCalendarInfo(
        DateTime.utc(2026, 6, 22, 15, 0),
        AstronomiaEphemerisService(),
        latitude: 69.65,
        longitude: 18.96,
      );

      expect(nightInfo.diurnalRhythm?.phase, equals(DiurnalPhase.nightRest));
      expect(
        morningInfo.diurnalRhythm?.phase,
        equals(DiurnalPhase.morningExhalation),
      );
      expect(
        afternoonInfo.diurnalRhythm?.phase,
        equals(DiurnalPhase.eveningInhalation),
      );

      final directFromSunTimes = DiurnalRhythmInfo.fromSunTimes(
        time: DateTime.utc(2026, 6, 21, 8, 0),
        sunrise: null,
        sunset: null,
        solarNoon: DateTime.utc(2026, 6, 21, 8, 0),
      );
      expect(directFromSunTimes.phase, equals(DiurnalPhase.morningExhalation));
    });

    test('Floating-point degree normalization at -1e-15 maps to Pisces / Leaf instead of null', () {
      final boundary = findBoundaryForLongitude(-1e-15);
      expect(boundary, isNotNull);
      expect(boundary!.name, equals('Pisces'));
      expect(boundary.quality, equals(PlantQuality.leaf));
      expect(
        TransitionEnvelope.fromLongitude(-1e-15).toQuality,
        equals(PlantQuality.leaf),
      );
    });

    test('EcologicalSynthesis.resolveHorizon invalidates cache when weatherSeries is mutated in-place', () {
      final t = DateTime.utc(2026, 5, 10, 12);
      final series = <WeatherDataPoint>[
        WeatherDataPoint(
          time: t,
          temperature: 15.0,
          precipitation: 0.0,
          windSpeed: 2.0,
          windDirection: 180.0,
          cloudCover: 20.0,
        ),
      ];

      final first = EcologicalSynthesis.resolveHorizon(
        referenceTime: t,
        weatherSeries: series,
      );
      expect(first, isNotNull);
      expect(first!.soilMoisture, equals(SoilMoistureStatus.dryOrCrumbly));

      // Mutate list in place keeping same list identity and timestamp
      series[0] = WeatherDataPoint(
        time: t,
        temperature: 15.0,
        precipitation: 15.0,
        windSpeed: 2.0,
        windDirection: 180.0,
        cloudCover: 80.0,
      );

      final second = EcologicalSynthesis.resolveHorizon(
        referenceTime: t,
        weatherSeries: series,
      );
      expect(second, isNotNull);
      expect(second!.soilMoisture, equals(SoilMoistureStatus.saturated));
      expect(first == second, isFalse);
    });

    test('TaskWindowPlanner cache key distinguishes organRules with different months', () {
      final ephemeris = AstronomiaEphemerisService();
      final startTime = DateTime.utc(2026, 5, 15, 8);
      final crop = VegetableDatabase.findById('carrot')!;

      const mayRule = CropTaskSchedule(
        id: 'rule_may',
        quality: PlantQuality.leaf,
        months: <int>[5],
        labelDa: 'Testblad',
        labelEn: 'Test leaf',
      );
      const novRule = CropTaskSchedule(
        id: 'rule_nov',
        quality: PlantQuality.leaf,
        months: <int>[11],
        labelDa: 'Testblad',
        labelEn: 'Test leaf',
      );

      final resMay = TaskWindowPlanner.findUpcomingWindows(
        action: TaskActionType.sowOutdoor,
        targetQuality: PlantQuality.leaf,
        crop: crop,
        organRule: mayRule,
        startTime: startTime,
        ephemeris: ephemeris,
        searchDays: 5,
      );
      final resNov = TaskWindowPlanner.findUpcomingWindows(
        action: TaskActionType.sowOutdoor,
        targetQuality: PlantQuality.leaf,
        crop: crop,
        organRule: novRule,
        startTime: startTime,
        ephemeris: ephemeris,
        searchDays: 5,
      );

      expect(resMay.isCurrentlyInSeason, isTrue);
      expect(resNov.isCurrentlyInSeason, isFalse);
    });

    test('Seasonal calendar and burial progress preserve UTC and handle Easter daytime', () {
      final converted = toNorthernSeasonEquivalent(
        DateTime.utc(2026, 12, 31, 14, 30),
        isNorthern: false,
      );
      expect(converted.isUtc, isTrue);

      expect(() => southernHemisphereMonth(0), throwsRangeError);
      expect(() => southernHemisphereMonth(13), throwsRangeError);

      // Easter Sunday 2026 is April 5; at 18:00 UTC burial has completed
      final progress = BiodynamicPrepEvaluator.getSeasonalBurialProgress(
        DateTime.utc(2026, 4, 5, 18, 0),
        latitude: 50.0,
      );
      expect(progress.isUndergroundBurial, isFalse);
      expect(progress.progressFraction, equals(0.0));
    });

    test('IcsCalendarExporter escapes bare CR, validates stirringDuration, and clamps peakTime == end', () {
      final start = DateTime.utc(2026, 5, 10, 8, 0);
      final end = DateTime.utc(2026, 5, 11, 8, 0);

      expect(
        () => CalendarExportEvent(
          uid: 'u1',
          summary: 'Test',
          description: 'Desc',
          start: start,
          end: end,
          stirringStart: start.subtract(const Duration(minutes: 30)),
          stirringDuration: const Duration(seconds: -30),
        ),
        throwsArgumentError,
      );
      expect(
        () => CalendarExportEvent(
          uid: 'u2',
          summary: 'Test',
          description: 'Desc',
          start: start,
          end: end,
          stirringStart: start.subtract(const Duration(minutes: 30)),
        ),
        throwsArgumentError,
      );

      final eventWithCr = CalendarExportEvent(
        uid: 'cr-test',
        summary: 'CR Test',
        description: 'Line1\rLine2',
        start: start,
        end: start.add(const Duration(hours: 2)),
      );
      final formatted = IcsCalendarExporter.formatEvent(eventWithCr);
      expect(formatted, contains(r'Line1\nLine2'));
      final withoutCrLf = formatted.replaceAll('\r\n', '');
      expect(withoutCrLf.contains('\r'), isFalse);

      final windowAtEnd = TaskWindow(
        start: start,
        end: end,
        peakTime: end,
        quality: PlantQuality.root,
        suitability: TaskSuitability.optimal,
        isDescending: true,
        isWaxing: false,
        isSpecialTrine: false,
        isInSeason: true,
        headline: 'Root Day',
        cosmicExplanation: 'Good root window.',
      );
      final exported = IcsCalendarExporter.fromTaskWindow(
        window: windowAtEnd,
        action: TaskActionType.sowOutdoor,
      );
      expect(exported.duration, equals(const Duration(hours: 2)));
      expect(exported.end, equals(end));
    });

    test('CalendarInfo lists are unmodifiable', () {
      final info = algo.getCalendarInfo(
        DateTime.utc(2026, 5, 10, 12),
        AstronomiaEphemerisService(),
        includePlanets: true,
      );
      expect(info.planets.clear, throwsUnsupportedError);
      expect(info.activeAspects.clear, throwsUnsupportedError);
    });
  });

  group('Garden & Services Health Regression Tests', () {
    test('Hlc enforces 15-digit maxWallTimeMs, HlcClock validates actorId, and FieldJournalEntry sanitizes authorId', () {
      expect(
        () => Hlc(
          wallTimeMs: Hlc.maxWallTimeMs + 1,
          counter: 0,
          actorId: 'node1',
        ),
        throwsRangeError,
      );
      expect(
        () => HlcClock(
          actorId: 'bad actor!',
          initial: Hlc(wallTimeMs: 1000, counter: 0, actorId: 'ok'),
        ),
        throwsArgumentError,
      );

      final entry = FieldJournalEntry(
        id: 'e1',
        timestamp: DateTime.utc(2026, 5, 10, 9),
        action: FieldJournalAction.sowSeeds,
        title: 'Sow Carrots',
        quality: PlantQuality.root,
        authorId: 'Alice Smith!',
        cosmicSnapshot: FieldJournalCosmicSnapshot(
          quality: PlantQuality.root,
          isGrayDay: false,
          isSpecial: false,
          isMoonAscending: false,
        ),
      );
      expect(() => Hlc.parse(entry.updatedHlc), returnsNormally);
    });

    test('GardenInviteLink.tryParse handles malformed percent-encoding and trailing punctuation, and Bundle validates JSON', () {
      expect(
        GardenInviteLink.tryParse('magiccalendar://join-garden?folder=%ZZ'),
        isNull,
      );
      final parsed = GardenInviteLink.tryParse(
        'Join here (https://drive.google.com/drive/folders/1AbCdEfGhIjKlMnOpQrStUvWxYz).',
      );
      expect(parsed, isNotNull);
      expect(parsed!.driveFolderId, equals('1AbCdEfGhIjKlMnOpQrStUvWxYz'));

      expect(
        () => GardenSharedNoteBundle.fromJson(const <String, Object?>{
          'schemaVersion': 1,
          'exportedAt': 'not-a-date',
        }),
        throwsFormatException,
      );
      expect(
        () => GardenSharedNoteBundle.fromJson(const <String, Object?>{
          'schemaVersion': 1,
          'exportedAt': '2026-05-10T12:00:00Z',
          'entries': 'not-a-list',
        }),
        throwsFormatException,
      );
    });

    test('CRDT tombstone resurrection when updatedHlc > deletedHlc and shardKeyFor year bounds', () {
      final resurrectedEntry = FieldJournalEntry(
        id: 'res_1',
        timestamp: DateTime.utc(2026, 5, 10, 9),
        action: FieldJournalAction.sowSeeds,
        title: 'Resurrected',
        quality: PlantQuality.root,
        updatedHlc: '000200000000000-0000-node1',
        deletedHlc: '000100000000000-0000-node1',
        cosmicSnapshot: FieldJournalCosmicSnapshot(
          quality: PlantQuality.root,
          isGrayDay: false,
          isSpecial: false,
          isMoonAscending: false,
        ),
      );
      expect(resurrectedEntry.isDeleted, isFalse);

      final resurrectedBatch = PlantingBatchSummary.fromEntry(resurrectedEntry);
      expect(resurrectedBatch.isDeleted, isFalse);
      expect(resurrectedBatch.isActiveInGround, isTrue);

      final resurrectedPlot = GardenPlot(
        name: 'Bed 1',
        updatedHlc: '000200000000000-0000-node1',
        deletedHlc: '000100000000000-0000-node1',
      );
      expect(resurrectedPlot.isDeleted, isFalse);

      expect(
        () => FieldJournalEntry.shardKeyFor(DateTime.utc(10000, 1, 1)),
        throwsArgumentError,
      );
      expect(
        () => FieldJournalEntry.shardKeyFor(DateTime.utc(0, 1, 1)),
        throwsArgumentError,
      );
    });

    test('PlotRotationAssessment ignores future batches and PlotSuccessionPlan includes overwintered harvests', () {
      final kale = VegetableDatabase.findById('kale')!;
      final futureKaleBatch = PlantingBatchSummary(
        entryId: 'b_2027',
        shardKey: '2027-05',
        timestamp: DateTime.utc(2027, 5, 10),
        action: FieldJournalAction.transplant,
        title: 'Kale 2027',
        cropId: kale.id,
        bedName: 'Bed A',
        quality: PlantQuality.leaf,
        cosmicSummary: 'Leaf',
        updatedHlc: '000100000000000-0000-node1',
      );

      final assessment2025 = PlotRotationAssessment.evaluate(
        plotName: 'Bed A',
        batchesInPlot: <PlantingBatchSummary>[futureKaleBatch],
        candidateCrop: kale,
        referenceTime: DateTime.utc(2025, 5, 1),
      );
      expect(assessment2025.hasFamilyConflict, isFalse);

      final carrot = VegetableDatabase.findById('carrot')!;
      final overwinteredCarrot = PlantingBatchSummary(
        entryId: 'b_carrot_2025',
        shardKey: '2025-10',
        timestamp: DateTime.utc(2025, 10, 15),
        action: FieldJournalAction.sowSeeds,
        title: 'Autumn Carrot',
        cropId: carrot.id,
        bedName: 'Bed A',
        quality: PlantQuality.root,
        cosmicSummary: 'Root',
        updatedHlc: '000100000000000-0000-node1',
        harvestedByEntryId: 'harvest_2026',
      );

      final plan = PlotSuccessionPlan.build(
        plot: GardenPlot(name: 'Bed A'),
        batchesInPlot: <PlantingBatchSummary>[overwinteredCarrot],
        referenceTime: DateTime.utc(2026, 7, 20),
      );
      expect(
        plan.harvestedThisSeason.map((b) => b.entryId),
        contains('b_carrot_2025'),
      );
    });

    test('ShardedSqliteJournalStore escapes LIKE wildcards and advances HLC on remote meta merge', () {
      final tempDir = Directory.systemTemp.createTempSync('magic_cal_reg_');
      try {
        final localDir = Directory('${tempDir.path}/local');
        final remoteDir = Directory('${tempDir.path}/remote');
        final localStore = ShardedSqliteJournalStore(
          rootDirectoryPath: localDir.path,
          initialActorId: 'local_node',
        );
        final remoteStore = ShardedSqliteJournalStore(
          rootDirectoryPath: remoteDir.path,
          initialActorId: 'remote_node',
        );

        final snap = FieldJournalCosmicSnapshot(
          quality: PlantQuality.root,
          isGrayDay: false,
          isSpecial: false,
          isMoonAscending: false,
        );
        localStore.upsertEntry(
          FieldJournalEntry(
            id: 'e_plain',
            timestamp: DateTime.utc(2026, 5, 1, 10),
            action: FieldJournalAction.compostAndCare,
            title: 'Germination normal',
            notes: 'Healthy seedlings',
            quality: PlantQuality.root,
            cosmicSnapshot: snap,
          ),
        );
        localStore.upsertEntry(
          FieldJournalEntry(
            id: 'e_pct',
            timestamp: DateTime.utc(2026, 5, 2, 10),
            action: FieldJournalAction.compostAndCare,
            title: '100% sprout rate',
            notes: 'Full stand',
            quality: PlantQuality.root,
            cosmicSnapshot: snap,
          ),
        );

        final results = localStore.searchEntries('100%', limit: 10);
        expect(results.map((e) => e.id).toList(), equals(<String>['e_pct']));

        const futureHlc = '009999999999999-0005-remote_node';
        remoteStore.upsertPlot(
          GardenPlot(name: 'Future Bed', updatedHlc: futureHlc),
        );
        remoteStore.close();

        localStore.mergeRemoteMetaFile('${remoteDir.path}/garden_meta.sqlite');
        localStore.upsertPlot(GardenPlot(name: 'Local Bed'));
        final localPlot = localStore.listPlots().firstWhere(
          (p) => p.name == 'Local Bed',
        );
        expect(localPlot.updatedHlc, isNotNull);
        expect(localPlot.updatedHlc!.compareTo(futureHlc) > 0, isTrue);

        localStore.close();
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('Transport email validation, post-dispose controller safety, weather validation, and EphemerisWorker dispose', () async {
      final driveTransport = GoogleDriveGardenSyncTransport(
        rootFolderId: '1AbCdEfGhIjKlMnOpQrStUvWxYz',
        tokenProvider: () async => 'test_token',
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      await expectLater(
        driveTransport.shareFolderWithEmail(
          emailAddress: 'invalid@@example.com',
        ),
        throwsArgumentError,
      );
      driveTransport.close();

      final controller = GardenProfileController(
        store: MemoryGardenProfileStore(),
      );
      final windowFuture = controller.ensureWindowLoaded(
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 5, 31),
      );
      controller.dispose();
      await expectLater(windowFuture, completes);

      final mockHttp = MockClient((_) async => http.Response('{}', 200));
      final weatherService = CombinedWeatherService(
        yrNoService: YrNoWeatherService(
          client: mockHttp,
          userAgent: 'magic-calendar-test/1.0',
        ),
        dmiService: DmiWeatherService(
          openMeteoClient: OpenMeteoClient(client: mockHttp),
        ),
      );
      expect(
        () => weatherService.getHistoricalData(
          double.nan,
          10.0,
          DateTime.utc(2026, 5, 1),
          DateTime.utc(2026, 5, 2),
        ),
        throwsArgumentError,
      );

      final meteoClient = OpenMeteoClient(client: mockHttp);
      await expectLater(
        meteoClient.getHistoricalData(
          95.0,
          10.0,
          DateTime.utc(2026, 5, 1),
          DateTime.utc(2026, 5, 2),
        ),
        throwsArgumentError,
      );

      expect(EphemerisWorker.dispose, returnsNormally);
    });
  });

  group('Views, Painters & Cards Health Regression Tests', () {
    test('InfiniteTimelinePainter detects in-place list mutation and guards NaN weather and zero height', () {
      final ephemeris = AstronomiaEphemerisService();
      final t = DateTime.utc(2026, 5, 10, 12);
      final mutableEntries = <FieldJournalEntry>[];

      final painter1 = InfiniteTimelinePainter(
        centerTime: t,
        hourWidth: 12.0,
        intervals: const [],
        weatherData: const [],
        journalEntries: mutableEntries,
        latitude: 55.0,
        longitude: 10.0,
        ephemeris: ephemeris,
      );

      mutableEntries.add(
        FieldJournalEntry(
          id: 'in_place_1',
          timestamp: t,
          action: FieldJournalAction.sowSeeds,
          title: 'Sow',
          quality: PlantQuality.root,
          cosmicSnapshot: FieldJournalCosmicSnapshot(
            quality: PlantQuality.root,
            isGrayDay: false,
            isSpecial: false,
            isMoonAscending: false,
          ),
        ),
      );

      final painter2 = InfiniteTimelinePainter(
        centerTime: t,
        hourWidth: 12.0,
        intervals: const [],
        weatherData: const [],
        journalEntries: mutableEntries,
        latitude: 55.0,
        longitude: 10.0,
        ephemeris: ephemeris,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);

      final nanWeatherPainter = InfiniteTimelinePainter(
        centerTime: t,
        hourWidth: 12.0,
        intervals: const [],
        weatherData: <WeatherDataPoint>[
          WeatherDataPoint(
            time: t,
            temperature: double.nan,
            precipitation: double.nan,
            windSpeed: double.infinity,
            cloudCover: double.nan,
            windDirection: double.nan,
          ),
        ],
        latitude: 55.0,
        longitude: 10.0,
        ephemeris: ephemeris,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => nanWeatherPainter.paint(canvas, const Size(400, 0)),
        returnsNormally,
      );
      expect(
        () => nanWeatherPainter.paint(canvas, const Size(400, 200)),
        returnsNormally,
      );
    });

    testWidgets(
      'Custom painters guard against NaN fractions and tiny/zero canvas sizes',
      (tester) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);

        const nanMoon = MoonPhaseInfo(
          illuminatedFraction: double.nan,
          isWaxing: true,
          phaseAngle: double.nan,
        );
        final moonPainter = MoonPainter(info: nanMoon);
        expect(
          () => moonPainter.paint(canvas, const Size(0.5, 0.5)),
          returnsNormally,
        );
        expect(
          () => moonPainter.paint(canvas, const Size(40, 40)),
          returnsNormally,
        );

        final pathWithZeroContour = Path()
          ..moveTo(0, 0)
          ..lineTo(0, 0)
          ..moveTo(10, 10)
          ..lineTo(100, 10);
        final curvedPainter = CurvedTextPainter(
          text: 'EARTH',
          path: pathWithZeroContour,
          style: const TextStyle(fontSize: 12, letterSpacing: double.nan),
          startOffset: double.nan,
        );
        expect(
          () => curvedPainter.paint(canvas, const Size(120, 40)),
          returnsNormally,
        );

        final ribbonPainter = RibbonPainter(
          planets: const <PlanetInfo>[
            PlanetInfo(name: 'Sun', longitude: double.nan),
            PlanetInfo(name: 'Moon', longitude: 45.0),
          ],
          centerLongitude: double.nan,
        );
        expect(
          () => ribbonPainter.paint(canvas, const Size(300, 40)),
          returnsNormally,
        );
      },
    );

    testWidgets(
      'OrganicVesselContainer and BiodynamicIcon render safely at tiny sizes',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: OrganicVesselContainer(
                      padding: EdgeInsets.zero,
                      child: SizedBox.shrink(),
                    ),
                  ),
                  BiodynamicIcon(type: BiodynamicIconType.broadfork, size: 0),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'StirringTimerDialog -1 min skip at <= 60s completes timer and +1 min clears completion',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: StirringTimerDialog(
                  initialPrep: StirringPrepType.generalTea, // 15 mins
                ),
              ),
            ),
          ),
        );

        // Skip down 15 times (-1 min each) to reach 00:00
        for (int i = 0; i < 15; i++) {
          await tester.tap(find.text('-1 min'));
          await tester.pump();
        }

        expect(find.text('00:00'), findsOneWidget);
        expect(find.textContaining('Stirring complete.'), findsOneWidget);

        // Tap +1 min to add time back and clear completion banner
        await tester.tap(find.text('+1 min'));
        await tester.pump();

        expect(find.text('01:00'), findsOneWidget);
        expect(find.textContaining('Stirring complete.'), findsNothing);
      },
    );

    testWidgets(
      'ConcoctionAssistantDialog handles Infinity and NaN area inputs without crashing',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: ConcoctionAssistantDialog())),
          ),
        );

        final textField = find.byType(TextField);
        await tester.enterText(textField, 'Infinity');
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.enterText(textField, 'NaN');
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'LocationPickerDialog rejects NaN and out-of-range coordinates with error message',
      (tester) async {
        var saved = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationPickerDialog(
                initialLatitude: double.nan,
                initialLongitude: double.infinity,
                onLocationSaved: (_, _) => saved = true,
              ),
            ),
          ),
        );

        await tester.enterText(
          find.byKey(const ValueKey('location_latitude_field')),
          'NaN',
        );
        await tester.tap(find.byKey(const ValueKey('save_location_button')));
        await tester.pump();
        expect(saved, isFalse);
        expect(
          find.textContaining('Please enter valid decimal'),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const ValueKey('location_latitude_field')),
          '95.0',
        );
        await tester.enterText(
          find.byKey(const ValueKey('location_longitude_field')),
          '10.0',
        );
        await tester.tap(find.byKey(const ValueKey('save_location_button')));
        await tester.pump();
        expect(saved, isFalse);
        expect(
          find.textContaining('Latitude must be between -90 and 90'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'FieldJournalCard and BedSuccessionPlannerCard invalidate plot caches on upsertPlot',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = GardenProfileController(
          store: MemoryGardenProfileStore(),
        );
        addTearDown(controller.dispose);

        controller.upsertPlot(
          GardenPlot(name: 'South Bed', plotType: GardenPlotType.openBed),
        );

        final info = algo.getCalendarInfo(
          DateTime.utc(2026, 5, 10, 12),
          AstronomiaEphemerisService(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    FieldJournalCard(
                      gardenController: controller,
                      selectedDate: DateTime.utc(2026, 5, 10, 12),
                      info: info,
                      onTimeJump: (_) {},
                    ),
                    BedSuccessionPlannerCard(
                      gardenController: controller,
                      selectedDate: DateTime.utc(2026, 5, 10, 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('South Bed'), findsWidgets);

        controller.upsertPlot(
          GardenPlot(
            name: 'North Greenhouse',
            plotType: GardenPlotType.greenhouse,
          ),
        );
        await tester.pump();

        expect(find.textContaining('North Greenhouse'), findsWidgets);
      },
    );

    testWidgets(
      'HomeHeader clamps out-of-range pre-2000 selectedDate when opening date picker',
      (tester) async {
        final lat = ValueNotifier<double>(55.0);
        final lon = ValueNotifier<double>(10.0);
        final selectedDate = ValueNotifier<DateTime>(DateTime(1995, 6, 15));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeHeader(
                latNotifier: lat,
                lonNotifier: lon,
                selectedDateNotifier: selectedDate,
                onNowPressed: () {},
                onDateSelected: (_) {},
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('calendar_picker_button')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(DatePickerDialog), findsOneWidget);
      },
    );
  });
}
