import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/agricultural_task_evaluator.dart';
import 'package:magic_calendar/src/core/algorithm.dart' as algo;
import 'package:magic_calendar/src/core/climate/climate.dart';
import 'package:magic_calendar/src/core/ecological_synthesis.dart';
import 'package:magic_calendar/src/core/plant_recommendations.dart';
import 'package:magic_calendar/src/core/task_window_planner.dart';
import 'package:magic_calendar/src/core/vegetable_database.dart';
import 'package:magic_calendar/src/core/week_ahead_planner.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:magic_calendar/src/services/garden_service.dart';
import 'package:magic_calendar/src/services/weather_service.dart';
import 'package:magic_calendar/src/ui/components/bed_succession_planner_card.dart';
import 'package:magic_calendar/src/ui/components/curved_text.dart';
import 'package:magic_calendar/src/ui/components/field_journal_card.dart';
import 'package:magic_calendar/src/ui/components/plant_recommendations_card.dart';
import 'package:magic_calendar/src/ui/components/stirring_timer_dialog.dart';
import 'package:magic_calendar/src/ui/painters/infinite_timeline_painter.dart';
import 'package:magic_calendar/src/ui/painters/moon_painter.dart';
import 'package:magic_calendar/src/ui/theme/app_theme.dart';
import 'package:magic_calendar/src/ui/views/calendar_home_page.dart';
import 'package:magic_calendar/src/ui/views/time_scroll_view.dart';
import 'package:sweph/sweph.dart';

import 'support/fakes.dart';
import 'support/sweph_test_loader.dart';

final class _CountingWeatherService implements WeatherService {
  int forecastCalls = 0;
  int historicalCalls = 0;
  final List<WeatherDataPoint> series;

  _CountingWeatherService(this.series);

  @override
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon) async {
    forecastCalls++;
    await Future<void>.delayed(Duration.zero);
    return series;
  }

  @override
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) async {
    historicalCalls++;
    await Future<void>.delayed(Duration.zero);
    return series
        .where((p) => !p.time.isBefore(start) && !p.time.isAfter(end))
        .toList();
  }

  @override
  void close() {}
}

void main() {
  setUpAll(() async {
    await ensureSwephLoaded();
    await Sweph.init();
  });

  group('Performance & Rendering Pipeline Regression Tests', () {
    test('InfiniteTimelinePainter.shouldRepaint returns false during pan translation when centerTime and data are unchanged', () {
      final ephemeris = AstronomiaEphemerisService();
      final baseTime = DateTime.utc(2026, 5, 15, 12);
      final intervals = <CalendarInterval>[
        CalendarInterval(
          start: baseTime.subtract(const Duration(hours: 6)),
          end: baseTime.add(const Duration(hours: 6)),
          quality: PlantQuality.fruit,
          isGrayDay: false,
          isSpecial: false,
          message: '',
        ),
      ];
      final weather = <WeatherDataPoint>[];
      final entries = <FieldJournalEntry>[];

      final painter1 = InfiniteTimelinePainter(
        centerTime: baseTime,
        hourWidth: 10.0,
        intervals: intervals,
        weatherData: weather,
        journalEntries: entries,
        ephemeris: ephemeris,
        latitude: 55.6761,
        longitude: 12.5683,
      );
      final painter2 = InfiniteTimelinePainter(
        centerTime: baseTime,
        hourWidth: 10.0,
        intervals: intervals,
        weatherData: weather,
        journalEntries: entries,
        ephemeris: ephemeris,
        latitude: 55.6761,
        longitude: 12.5683,
      );
      final painterMoved = InfiniteTimelinePainter(
        centerTime: baseTime.add(const Duration(hours: 4)),
        hourWidth: 10.0,
        intervals: intervals,
        weatherData: weather,
        journalEntries: entries,
        ephemeris: ephemeris,
        latitude: 55.6761,
        longitude: 12.5683,
      );

      expect(painter2.shouldRepaint(painter1), isFalse);
      expect(painterMoved.shouldRepaint(painter1), isTrue);
    });

    test('CurvedTextPainter caches glyph runs and performs zero TextPainter.layout calls on cache hits', () {
      CurvedTextPainter.clearCache();
      expect(CurvedTextPainter.cachedGlyphRunCount, equals(0));

      final path1 = Path()
        ..moveTo(20, 40)
        ..cubicTo(90, 15, 190, 15, 260, 40);
      final path2 = Path()
        ..moveTo(10, 50)
        ..cubicTo(100, 20, 200, 20, 290, 50);
      const style = TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 4.0,
        color: Color(0xFFFDFBF7),
      );

      final p1 = CurvedTextPainter(
        text: 'SPECIAL ALIGNMENT',
        path: path1,
        style: style,
      );
      final p1Same = CurvedTextPainter(
        text: 'SPECIAL ALIGNMENT',
        path: path1,
        style: style,
      );
      final p1Offset = CurvedTextPainter(
        text: 'SPECIAL ALIGNMENT',
        path: path1,
        style: style,
        startOffset: 8.0,
      );

      expect(p1Same.shouldRepaint(p1), isFalse);
      expect(p1Offset.shouldRepaint(p1), isTrue);

      // First paint populates the glyph run cache for ('SPECIAL ALIGNMENT', style, ltr).
      final recorder1 = ui.PictureRecorder();
      final canvas1 = Canvas(recorder1);
      p1.paint(canvas1, const Size(300, 80));
      recorder1.endRecording().dispose();

      expect(CurvedTextPainter.cachedGlyphRunCount, equals(1));

      // Painting 200 times across different paths and startOffsets with the
      // same (text, style) must reuse the single cached glyph run rapidly.
      final sw = Stopwatch()..start();
      for (int i = 0; i < 200; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final painter = CurvedTextPainter(
          text: 'SPECIAL ALIGNMENT',
          path: i.isEven ? path1 : path2,
          style: style,
          startOffset: (i % 10).toDouble(),
        );
        painter.paint(canvas, const Size(300, 80));
        recorder.endRecording().dispose();
      }
      sw.stop();

      expect(CurvedTextPainter.cachedGlyphRunCount, equals(1));
      expect(
        sw.elapsedMilliseconds,
        lessThan(80),
        reason:
            '200 cached CurvedTextPainter paints took ${sw.elapsedMilliseconds}ms',
      );
    });

    test('MoonPainter.shouldRepaint enforces sub-pixel phase threshold and caches static/lit geometry', () {
      const baseMoon = MoonPainter(
        info: MoonPhaseInfo(
          phaseAngle: 90.0,
          illuminatedFraction: 0.5000,
          isWaxing: true,
        ),
      );
      const subThresholdMoon = MoonPainter(
        info: MoonPhaseInfo(
          phaseAngle: 90.2,
          illuminatedFraction: 0.5015, // delta 0.0015 < 0.002 threshold
          isWaxing: true,
        ),
      );
      const aboveThresholdMoon = MoonPainter(
        info: MoonPhaseInfo(
          phaseAngle: 91.0,
          illuminatedFraction: 0.5025, // delta 0.0025 >= 0.002 threshold
          isWaxing: true,
        ),
      );
      const flippedWaxingMoon = MoonPainter(
        info: MoonPhaseInfo(
          phaseAngle: 90.0,
          illuminatedFraction: 0.5000,
          isWaxing: false,
        ),
      );

      expect(MoonPainter.phaseRepaintThreshold, equals(0.002));
      expect(subThresholdMoon.shouldRepaint(baseMoon), isFalse);
      expect(aboveThresholdMoon.shouldRepaint(baseMoon), isTrue);
      expect(flippedWaxingMoon.shouldRepaint(baseMoon), isTrue);

      // Warm static layer and lit path cache, then benchmark 200 paints.
      final warmRecorder = ui.PictureRecorder();
      baseMoon.paint(Canvas(warmRecorder), const Size(68, 68));
      warmRecorder.endRecording().dispose();

      final sw = Stopwatch()..start();
      for (int i = 0; i < 200; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final painter = MoonPainter(
          info: MoonPhaseInfo(
            phaseAngle: 90.0,
            illuminatedFraction: 0.5000 + (i % 3) * 0.0005,
            isWaxing: true,
          ),
        );
        painter.paint(canvas, const Size(68, 68));
        recorder.endRecording().dispose();
      }
      sw.stop();

      expect(
        sw.elapsedMilliseconds,
        lessThan(60),
        reason:
            '200 cached MoonPainter paints took ${sw.elapsedMilliseconds}ms',
      );
    });

    test('CombinedWeatherService binary search, sortedness tagging, and forecast/historical caching avoid redundant scans and fetches', () async {
      final anchor = DateTime.now().toUtc().subtract(const Duration(days: 50));
      final hourlySeries = List<WeatherDataPoint>.generate(2400, (i) {
        return WeatherDataPoint(
          time: anchor.add(Duration(hours: i)),
          temperature: 12.0 + (i % 24) * 0.4,
          precipitation: (i % 19 == 0) ? 1.8 : 0.0,
          windSpeed: 3.5 + (i % 7) * 0.5,
          windDirection: 180.0,
          cloudCover: 35.0,
        );
      }, growable: false);

      expect(
        CombinedWeatherService.isChronologicallySorted(hourlySeries),
        isTrue,
      );

      // Verify O(log N) findClosestPoint and findSortedRangeIndices match linear scan.
      final target = anchor.add(const Duration(hours: 1234, minutes: 22));
      final closest = CombinedWeatherService.findClosestPoint(
        hourlySeries,
        target,
      );
      expect(closest, isNotNull);
      expect(closest!.time, equals(anchor.add(const Duration(hours: 1234))));

      final rangeStart = anchor.add(const Duration(hours: 500));
      final rangeEnd = anchor.add(const Duration(hours: 572));
      final indices = CombinedWeatherService.findSortedRangeIndices(
        hourlySeries,
        rangeStart,
        rangeEnd,
      );
      expect(indices, equals((500, 573)));

      // Benchmark 1,000 binary search range + closest point lookups over 2,400 points.
      final swLookup = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        final t = anchor.add(Duration(hours: (i * 7) % 2300, minutes: 17));
        CombinedWeatherService.findClosestPoint(hourlySeries, t);
        CombinedWeatherService.findSortedRangeIndices(
          hourlySeries,
          t.subtract(const Duration(hours: 48)),
          t.add(const Duration(hours: 72)),
        );
      }
      swLookup.stop();
      expect(
        swLookup.elapsedMilliseconds,
        lessThan(25),
        reason:
            '1,000 binary search weather lookups took ${swLookup.elapsedMilliseconds}ms',
      );

      // Verify forecast + historical LRU cache and in-flight deduplication.
      final yrCounter = _CountingWeatherService(hourlySeries);
      final dmiCounter = _CountingWeatherService(hourlySeries);
      final combined = CombinedWeatherService(
        yrNoService: yrCounter,
        dmiService: dmiCounter,
      );

      final reqStart = DateTime.now().subtract(const Duration(days: 2));
      final reqEnd = DateTime.now();

      // Fire 4 concurrent forecast + historical requests for the same coordinate/window.
      final concurrentForecasts = await Future.wait<List<WeatherDataPoint>>([
        combined.getForecast(55.6761, 12.5683),
        combined.getForecast(55.6761, 12.5683),
        combined.getForecast(55.6761, 12.5683),
        combined.getForecast(55.6761, 12.5683),
      ]);
      final concurrentHistorical = await Future.wait<List<WeatherDataPoint>>([
        combined.getHistoricalData(55.6761, 12.5683, reqStart, reqEnd),
        combined.getHistoricalData(55.6761, 12.5683, reqStart, reqEnd),
        combined.getHistoricalData(55.6761, 12.5683, reqStart, reqEnd),
        combined.getHistoricalData(55.6761, 12.5683, reqStart, reqEnd),
      ]);

      expect(yrCounter.forecastCalls, equals(1));
      expect(dmiCounter.historicalCalls, equals(1));
      for (final res in [...concurrentForecasts, ...concurrentHistorical]) {
        expect(CombinedWeatherService.isChronologicallySorted(res), isTrue);
      }

      // Subsequent calls within the cached window hit memory with 0 network calls.
      for (int i = 0; i < 20; i++) {
        await combined.getForecast(55.6761, 12.5683);
        await combined.getHistoricalData(55.6761, 12.5683, reqStart, reqEnd);
      }
      expect(yrCounter.forecastCalls, equals(1));
      expect(dmiCounter.historicalCalls, equals(1));
    });

    test('EcologicalSynthesis, AgriculturalTaskEvaluator, PlantRecommendations, and WeekAheadPlanner memoize results and slice horizons in O(log N)', () {
      final ephemeris = AstronomiaEphemerisService();
      final baseTime = DateTime.utc(2026, 5, 15, 14);
      final info = algo.getCalendarInfo(
        baseTime,
        ephemeris,
        includePlanets: true,
        latitude: 55.6761,
        longitude: 12.5683,
      );

      final seriesStart = baseTime.subtract(const Duration(days: 30));
      final weatherSeries = List<WeatherDataPoint>.generate(1440, (i) {
        return WeatherDataPoint(
          time: seriesStart.add(Duration(hours: i)),
          temperature: 15.0 + (i % 24) * 0.3,
          precipitation: 0.0,
          windSpeed: 2.5,
          windDirection: 180.0,
          cloudCover: 20.0,
        );
      }, growable: false);
      expect(
        CombinedWeatherService.isChronologicallySorted(weatherSeries),
        isTrue,
      );
      final currentWeather = CombinedWeatherService.findClosestPoint(
        weatherSeries,
        baseTime,
      );

      // 1. EcologicalSynthesis.resolveHorizon & synthesize memoization.
      final h1 = EcologicalSynthesis.resolveHorizon(
        referenceTime: baseTime,
        currentWeather: currentWeather,
        weatherSeries: weatherSeries,
      );
      final h2 = EcologicalSynthesis.resolveHorizon(
        referenceTime: baseTime,
        currentWeather: currentWeather,
        weatherSeries: weatherSeries,
      );
      expect(identical(h1, h2), isTrue);

      final syn1 = EcologicalSynthesis.synthesize(
        calendarInfo: info,
        time: baseTime,
        weather: currentWeather,
        weatherSeries: weatherSeries,
        latitude: 55.6761,
      );
      final syn2 = EcologicalSynthesis.synthesize(
        calendarInfo: info,
        time: baseTime.add(const Duration(minutes: 4)),
        weather: currentWeather,
        horizon: h1,
        latitude: 55.6761,
      );
      expect(identical(syn1, syn2), isTrue);

      // 2. AgriculturalTaskEvaluator.evaluateAllTasks memoization.
      final tasks1 = AgriculturalTaskEvaluator.evaluateAllTasks(
        calendarInfo: info,
        time: baseTime,
        weather: currentWeather,
        weatherSeries: weatherSeries,
        ephemeris: ephemeris,
        latitude: 55.6761,
      );
      final tasks2 = AgriculturalTaskEvaluator.evaluateAllTasks(
        calendarInfo: info,
        time: baseTime,
        weather: currentWeather,
        weatherSeries: weatherSeries,
        ephemeris: ephemeris,
        latitude: 55.6761,
      );
      expect(identical(tasks1, tasks2), isTrue);

      // 3. PlantRecommendations.evaluate memoization with ClimateProfile.
      final seasons = ClimateSeasonAlignment(
        local: DanishReferenceClimate.profile,
      );
      final rec1 = PlantRecommendations.evaluate(
        quality: info.quality,
        isDescending: info.isMoonDescending,
        isWaxing: info.moonPhase.isWaxing,
        isGrayDay: info.isGrayDay,
        selectedTime: baseTime,
        latitude: 55.6761,
        seasons: seasons,
      );
      final rec2 = PlantRecommendations.evaluate(
        quality: info.quality,
        isDescending: info.isMoonDescending,
        isWaxing: info.moonPhase.isWaxing,
        isGrayDay: info.isGrayDay,
        selectedTime: baseTime.add(const Duration(hours: 2)),
        latitude: 55.6761,
        seasons: seasons,
      );
      expect(identical(rec1, rec2), isTrue);

      final swCore = Stopwatch()..start();
      for (int i = 0; i < 200; i++) {
        EcologicalSynthesis.synthesize(
          calendarInfo: info,
          time: baseTime,
          weather: currentWeather,
          weatherSeries: weatherSeries,
          latitude: 55.6761,
        );
        AgriculturalTaskEvaluator.evaluateAllTasks(
          calendarInfo: info,
          time: baseTime,
          weather: currentWeather,
          weatherSeries: weatherSeries,
          ephemeris: ephemeris,
          latitude: 55.6761,
        );
        PlantRecommendations.evaluate(
          quality: info.quality,
          isDescending: info.isMoonDescending,
          isWaxing: info.moonPhase.isWaxing,
          isGrayDay: info.isGrayDay,
          selectedTime: baseTime,
          latitude: 55.6761,
          seasons: seasons,
        );
      }
      swCore.stop();
      expect(
        swCore.elapsedMilliseconds,
        lessThan(40),
        reason:
            '200 cached synthesis + task + plant recommendation evaluations took ${swCore.elapsedMilliseconds}ms',
      );

      // 4. WeekAheadPlanner.buildDigest cold & warm microbenchmark.
      final swColdDigest = Stopwatch()..start();
      final digest1 = WeekAheadPlanner.buildDigest(
        startTime: baseTime,
        ephemeris: ephemeris,
        weatherForecast: weatherSeries,
        latitude: 55.6761,
        longitude: 12.5683,
        seasons: seasons,
      );
      swColdDigest.stop();
      expect(digest1.dailyBriefs.length, equals(7));
      expect(
        swColdDigest.elapsedMilliseconds,
        lessThan(800),
        reason:
            'Cold 7-day WeekAheadPlanner.buildDigest took ${swColdDigest.elapsedMilliseconds}ms',
      );

      final swWarmDigest = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        final digestCached = WeekAheadPlanner.buildDigest(
          startTime: baseTime,
          ephemeris: ephemeris,
          weatherForecast: weatherSeries,
          latitude: 55.6761,
          longitude: 12.5683,
          seasons: seasons,
        );
        expect(identical(digest1, digestCached), isTrue);
      }
      swWarmDigest.stop();
      expect(
        swWarmDigest.elapsedMilliseconds,
        lessThan(20),
        reason:
            '100 warm WeekAheadPlanner.buildDigest hits took ${swWarmDigest.elapsedMilliseconds}ms',
      );
    });

    test('InfiniteTimelinePainter binary search slices large interval, weather, and journal lists rapidly during 60-frame scrub', () {
      final ephemeris = AstronomiaEphemerisService();
      final start = DateTime.utc(2026, 5, 1);
      final intervals = ephemeris.getIntervals(
        start,
        start.add(const Duration(days: 60)),
      );
      final weatherData = List<WeatherDataPoint>.generate(1440, (i) {
        return WeatherDataPoint(
          time: start.add(Duration(hours: i)),
          temperature: 14.0 + (i % 24) * 0.4,
          precipitation: (i % 17 == 0) ? 1.2 : 0.0,
          windSpeed: 3.0,
          windDirection: 180.0,
          cloudCover: 25.0,
        );
      }, growable: false);

      final cosmicSnap = FieldJournalCosmicSnapshot.fromCalendarInfo(
        algo.getCalendarInfo(start, ephemeris),
      );
      // Descending order (matching GardenProfileController's default newest-first order).
      final descendingEntries = List<FieldJournalEntry>.generate(300, (i) {
        final ts = start.add(Duration(hours: (299 - i) * 4));
        return FieldJournalEntry(
          id: 'perf_entry_$i',
          timestamp: ts,
          action: FieldJournalAction.sowSeeds,
          title: 'Sow Entry $i',
          quality: PlantQuality.values[i % 4],
          cosmicSnapshot: cosmicSnap,
        );
      }, growable: false);

      final swScrub = Stopwatch()..start();
      for (int frame = 0; frame < 60; frame++) {
        final centerTime = start.add(Duration(days: 15, minutes: frame * 15));
        final painter = InfiniteTimelinePainter(
          centerTime: centerTime,
          hourWidth: 10.0,
          intervals: intervals,
          weatherData: weatherData,
          journalEntries: descendingEntries,
          ephemeris: ephemeris,
          latitude: 55.6761,
          longitude: 12.5683,
        );
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(411.4, 220.0));
        recorder.endRecording().dispose();
      }
      swScrub.stop();

      expect(
        swScrub.elapsedMilliseconds / 60.0,
        lessThan(8.0),
        reason:
            'Average InfiniteTimelinePainter scrub paint took ${swScrub.elapsedMilliseconds / 60.0}ms',
      );
    });

    test('GardenProfileController.ensureWindowLoaded is a no-op without listener notifications when within loaded window', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'magic_calendar_perf_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final sqlStore = ShardedSqliteJournalStore(
        rootDirectoryPath: tempDir.path,
      );
      final controller = GardenProfileController(journalStore: sqlStore);
      addTearDown(controller.dispose);

      final center = DateTime.now();
      await controller.ensureWindowLoaded(
        center.subtract(const Duration(days: 60)),
        center.add(const Duration(days: 60)),
      );

      int notifications = 0;
      controller.addListener(() {
        notifications++;
      });

      // Simulate 60 timeline drag frames within the already-loaded ±60d window.
      for (int i = 0; i < 60; i++) {
        final t = center.add(Duration(hours: i));
        await controller.ensureWindowLoaded(
          t.subtract(const Duration(days: 60)),
          t.add(const Duration(days: 60)),
        );
      }

      expect(
        notifications,
        equals(0),
        reason: 'Sliding within the covered window must not re-query SQLite or notify listeners',
      );
    });

    test('AstronomiaEphemerisService.getIntervals for 120 days and multi-task TaskWindowPlanner complete rapidly', () {
      final ephemeris = AstronomiaEphemerisService();
      final start = DateTime.utc(2026, 4, 1);
      final end = DateTime.utc(2026, 7, 30); // 120 days

      final swIntervals = Stopwatch()..start();
      final intervals = ephemeris.getIntervals(start, end);
      swIntervals.stop();

      expect(intervals, isNotEmpty);
      expect(
        swIntervals.elapsedMilliseconds,
        lessThan(1500),
        reason:
            '120-day getIntervals took ${swIntervals.elapsedMilliseconds}ms',
      );

      final swPlanner = Stopwatch()..start();
      final mainSearch = TaskWindowPlanner.findUpcomingWindows(
        action: TaskActionType.sowOutdoor,
        targetQuality: PlantQuality.root,
        crop: VegetableDatabase.findById('carrot'),
        startTime: start,
        ephemeris: ephemeris,
        searchDays: 30,
        maxWindows: 8,
      );
      // Simulate 5 active queued tasks sharing the same 2-hour ephemeris grid.
      for (final quality in const [
        PlantQuality.root,
        PlantQuality.leaf,
        PlantQuality.flower,
        PlantQuality.fruit,
        PlantQuality.root,
      ]) {
        TaskWindowPlanner.findUpcomingWindows(
          action: TaskActionType.transplant,
          targetQuality: quality,
          startTime: start,
          ephemeris: ephemeris,
          searchDays: 14,
          maxWindows: 1,
        );
      }
      swPlanner.stop();

      expect(mainSearch.windows, isNotEmpty);
      expect(
        swPlanner.elapsedMilliseconds,
        lessThan(1500),
        reason:
            '30-day planner + 5 queued tasks took ${swPlanner.elapsedMilliseconds}ms',
      );

      // Verify cached getCalendarInfo hit is sub-millisecond.
      final swCached = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        algo.getCalendarInfo(start, ephemeris, includePlanets: true);
      }
      swCached.stop();
      expect(swCached.elapsedMilliseconds, lessThan(20));

      // Simulate 60 horizontal pan frames with unaligned fractional-minute
      // timestamps (e.g. 6 minutes + 137ms per frame). Because isNearPerigee,
      // isNearApogee, isNearNode, and isNearEclipse snap their neighborhood
      // search grid to 1h/2h JD multiples, all 60 frames hit the warmed
      // geocentric moon cache instead of recomputing 33 Sweph points per frame.
      final swFractionalPan = Stopwatch()..start();
      for (int i = 0; i < 60; i++) {
        final panTime = start.add(
          Duration(minutes: i * 6, seconds: (i * 7) % 60, milliseconds: i * 13),
        );
        algo.getCalendarInfo(panTime, ephemeris, includePlanets: false);
      }
      swFractionalPan.stop();
      expect(
        swFractionalPan.elapsedMilliseconds,
        lessThan(150),
        reason:
            '60 fractional-timestamp pan frames took ${swFractionalPan.elapsedMilliseconds}ms',
      );

      // Verify sunrise/sunset daily cache and planetary position cache hits.
      final swSunrise = Stopwatch()..start();
      for (int i = 0; i < 200; i++) {
        ephemeris.getSunriseSunset(
          start.add(Duration(minutes: i * 3)),
          55.6761,
          12.5683,
        );
      }
      swSunrise.stop();
      expect(
        swSunrise.elapsedMilliseconds,
        lessThan(25),
        reason:
            '200 same-day getSunriseSunset calls took ${swSunrise.elapsedMilliseconds}ms',
      );
    });

    testWidgets(
      'StirringTimerDialog isolates vortex animation and guidance in RepaintBoundaries during countdown ticks',
      (tester) async {
        tester.view.physicalSize = const Size(800, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(
              body: Center(
                child: StirringTimerDialog(initialPrep: StirringPrepType.cpp),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('20:00'), findsOneWidget);
        expect(find.text('Goethean Dynamization Guidance'), findsOneWidget);

        // Verify the Goethean guidance section is isolated inside its own RepaintBoundary.
        final guidanceBoundary = find.ancestor(
          of: find.text('Goethean Dynamization Guidance'),
          matching: find.byType(RepaintBoundary),
        );
        expect(guidanceBoundary, findsWidgets);

        // Start the stirring countdown and pump several 1-second ticks.
        await tester.tap(find.text('Start Stirring'));
        await tester.pump();
        expect(find.text('Pause Stirring'), findsOneWidget);

        final swTicks = Stopwatch()..start();
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        swTicks.stop();

        expect(find.text('19:55'), findsOneWidget);
        expect(
          swTicks.elapsedMilliseconds,
          lessThan(250),
          reason:
              '5 StirringTimerDialog countdown ticks took ${swTicks.elapsedMilliseconds}ms',
        );

        // Pause timer before teardown so no pending periodic timer remains.
        await tester.tap(find.text('Pause Stirring'));
        await tester.pump();
      },
    );

    testWidgets(
      'CalendarHomePage on Pixel 6a viewport isolates horizontal pan and lazily culls below-the-fold cards',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.625; // Pixel 6a: ~411.4 x 914.3
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final ephemeris = AstronomiaEphemerisService();
        final weather = FakeWeatherService();
        final gardenController = GardenProfileController();
        addTearDown(gardenController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: CalendarHomePage(
              ephemeris: ephemeris,
              weather: weather,
              gardenController: gardenController,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. At top of scroll view (offset 0), below-the-fold FieldJournalCard
        // and BedSuccessionPlannerCard are lazily culled by SliverList.
        expect(find.byType(FieldJournalCard), findsNothing);
        expect(find.byType(BedSuccessionPlannerCard), findsNothing);

        // 2. Measure horizontal timeline drag across 10 frames on the Pixel 6a
        // viewport and verify no exceptions and low frame times.
        final timelineFinder = find.byType(TimeScrollView);
        expect(timelineFinder, findsOneWidget);

        final gesture = await tester.startGesture(
          tester.getCenter(timelineFinder),
        );
        final swPan = Stopwatch()..start();
        for (int i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(-14.0, 0.0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        swPan.stop();
        await gesture.up();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          swPan.elapsedMilliseconds / 10.0,
          lessThan(30.0),
          reason:
              'Average timeline pan frame took ${swPan.elapsedMilliseconds / 10.0}ms',
        );

        // 3. Measure vertical scroll down to below-the-fold cards and back up.
        final verticalScrollable = find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first;
        final scrollState = tester.state<ScrollableState>(verticalScrollable);

        final swVScroll = Stopwatch()..start();
        for (int i = 1; i <= 15; i++) {
          scrollState.position.jumpTo(i * 120.0);
          await tester.pump();
        }
        swVScroll.stop();

        expect(tester.takeException(), isNull);
        expect(
          swVScroll.elapsedMilliseconds / 15.0,
          lessThan(40.0),
          reason:
              'Average vertical scroll frame took ${swVScroll.elapsedMilliseconds / 15.0}ms',
        );

        await tester.scrollUntilVisible(
          find.byType(PlantRecommendationsCard),
          350.0,
          scrollable: verticalScrollable,
        );
        expect(find.byType(PlantRecommendationsCard), findsOneWidget);
      },
    );
  });
}
