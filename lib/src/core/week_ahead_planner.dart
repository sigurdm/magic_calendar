import 'dart:collection';

import 'algorithm.dart' as algo;
import 'biodynamic_prep.dart';
import 'climate/season_alignment.dart';
import 'ics_calendar_exporter.dart';
import 'models/models.dart';
import 'task_window_planner.dart';
import 'vegetable_database.dart';

/// Classification of how forecast weather intersects with a cosmic window.
enum WeatherIntersectionStatus {
  /// Dry, calm, and frost-free conditions ideal for field work or spraying.
  harmonious(
    badgeLabel: 'DRY & CALM',
    description: 'Forecast weather is dry, calm, and frost-free.',
  ),

  /// Mild or workable terrestrial conditions with no blocking hazards.
  acceptable(
    badgeLabel: 'WORKABLE',
    description: 'Forecast weather is workable with minor breeze or cloud.',
  ),

  /// Forecast rain, high wind, or frost conflicts with outdoor work or sprays.
  conflict(
    badgeLabel: 'WEATHER ALERT',
    description: 'Forecast rain, wind, or freezing temperatures conflict with outdoor work.',
  ),

  /// No hourly forecast points cover this time window yet.
  unverified(
    badgeLabel: 'COSMIC ONLY',
    description: 'Beyond current hourly weather forecast horizon.',
  );

  /// Short uppercase badge text displayed in UI chips.
  final String badgeLabel;

  /// Human-readable summary of the weather intersection status.
  final String description;

  const WeatherIntersectionStatus({
    required this.badgeLabel,
    required this.description,
  });
}

/// Functional category of a ranked synthesis window in the 7-day digest.
enum SynthesisWindowCategory {
  /// Sowing, transplanting, cuttings, division, and soil cultivation.
  plantingAndSoil(
    displayName: 'Planting & Soil',
    danishName: 'Såning & Udplantning',
  ),

  /// Above-ground harvesting, grafting, and canopy care.
  harvestAndCanopy(
    displayName: 'Harvest & Canopy',
    danishName: 'Høst & Podning',
  ),

  /// Biodynamic field preparations (BD 500, BD 501, CPP, BD 508).
  biodynamicSpray(
    displayName: 'Biodynamic Spray',
    danishName: 'Biodynamisk Sprøjtning',
  );

  /// English user-facing category label.
  final String displayName;

  /// Danish user-facing category label.
  final String danishName;

  const SynthesisWindowCategory({
    required this.displayName,
    required this.danishName,
  });
}

/// Day-level biodynamic and weather summary for a single calendar date in the
/// 7-day "Week Ahead" strip.
final class DailyBiodynamicBrief {
  /// Midnight local date for this daily brief.
  final DateTime date;

  /// Sidereal plant organ qualities active during daytime (06:00–20:00).
  final List<PlantQuality> qualities;

  /// Dominant daytime plant organ quality.
  final PlantQuality dominantQuality;

  /// Whether the Moon is descending (*Pflanzzeit*) during daytime.
  final bool isDescending;

  /// Whether the Moon is waxing at midday.
  final bool isWaxing;

  /// Whether any daytime hours fall within a Gray Day blackout.
  final bool hasGrayHours;

  /// Whether all daytime hours fall within a Gray Day blackout.
  final bool isAllDayGray;

  /// Whether a same-element planetary trine aspect occurs on this day.
  final bool isSpecialTrine;

  /// Whether [date] falls on Saturday or Sunday.
  final bool isWeekend;

  /// Minimum forecast air temperature in °C during daytime, if available.
  final double? minTemperature;

  /// Maximum forecast air temperature in °C during daytime, if available.
  final double? maxTemperature;

  /// Total daytime precipitation in millimeters across forecast hours.
  final double totalPrecipitationMm;

  /// Peak daytime wind speed in meters per second across forecast hours.
  final double maxWindSpeedMs;

  /// Overall weather intersection status for daytime field work.
  final WeatherIntersectionStatus weatherStatus;

  /// Concise one-line summary of the day's cosmic and terrestrial character.
  final String daySummary;

  /// Creates an immutable [DailyBiodynamicBrief].
  DailyBiodynamicBrief({
    required this.date,
    required List<PlantQuality> qualities,
    required this.dominantQuality,
    required this.isDescending,
    required this.isWaxing,
    required this.hasGrayHours,
    required this.isAllDayGray,
    required this.isSpecialTrine,
    required this.isWeekend,
    required this.minTemperature,
    required this.maxTemperature,
    required this.totalPrecipitationMm,
    required this.maxWindSpeedMs,
    required this.weatherStatus,
    required this.daySummary,
  }) : qualities = List.unmodifiable(qualities);

  /// Whether hourly weather forecast data is available for this date.
  bool get hasWeatherForecast =>
      minTemperature != null || maxTemperature != null;
}

/// A ranked multi-factor window over the next 7 days where cosmic quality,
/// Moon declination (*Pflanzzeit*), diurnal Earth breathing, and forecast
/// weather intersect.
final class RankedSynthesisWindow {
  /// Unique identifier for UI keys and `.ics` export.
  final String id;

  /// 1-based rank in the 7-day digest (1 is highest synergy).
  final int rank;

  /// Functional category of this window.
  final SynthesisWindowCategory category;

  /// Primary user-facing title.
  final String title;

  /// Subtitle summarizing Moon declination and diurnal breathing phase.
  final String subtitle;

  /// Window start time.
  final DateTime start;

  /// Window end time.
  final DateTime end;

  /// Recommended peak hour to jump the timeline to.
  final DateTime peakTime;

  /// Optional pre-spray dynamization stirring start time (`1 hour` before
  /// [start] for BD 500/501; `20 minutes` before [start] for CPP/BD 508).
  final DateTime? stirringStart;

  /// Optional pre-spray dynamization stirring duration.
  final Duration? stirringDuration;

  /// Associated biodynamic preparation when [category] is
  /// [SynthesisWindowCategory.biodynamicSpray].
  final BiodynamicPrepType? preparation;

  /// Representative garden task action when [category] is not a spray.
  final TaskActionType? primaryAction;

  /// Active sidereal plant organ quality.
  final PlantQuality quality;

  /// Active diurnal Earth breathing phase.
  final DiurnalPhase diurnalPhase;

  /// Whether the Moon is descending (*Pflanzzeit*).
  final bool isDescending;

  /// Whether the Moon is waxing.
  final bool isWaxing;

  /// Whether a same-element planetary trine aspect is active.
  final bool isSpecialTrine;

  /// Whether [start] falls on Saturday or Sunday.
  final bool isWeekend;

  /// Weather intersection status across `[start, end]`.
  final WeatherIntersectionStatus weatherStatus;

  /// Human-readable summary of forecast temperature, precipitation, and wind.
  final String weatherSummary;

  /// Representative forecast air temperature in °C during the window.
  final double? temperatureCelsius;

  /// Total forecast precipitation in mm across the window.
  final double? precipitationMm;

  /// Maximum forecast wind speed in m/s across the window.
  final double? windSpeedMs;

  /// Composite synergy score (`0.0` to `100.0`) ranking the intersection of
  /// cosmic quality, declination, diurnal breath, and dry/calm weather.
  final double synergyScore;

  /// Detailed synthesis explanation combining cosmic and terrestrial factors.
  final String explanation;

  /// Seasonal crops matching [quality] and the current month.
  final List<String> recommendedCropNames;

  /// Pre-built [CalendarExportEvent] for one-tap `.ics` export.
  final CalendarExportEvent exportEvent;

  /// Creates an immutable [RankedSynthesisWindow].
  RankedSynthesisWindow({
    required this.id,
    required this.rank,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.start,
    required this.end,
    required this.peakTime,
    this.stirringStart,
    this.stirringDuration,
    this.preparation,
    this.primaryAction,
    required this.quality,
    required this.diurnalPhase,
    required this.isDescending,
    required this.isWaxing,
    required this.isSpecialTrine,
    required this.isWeekend,
    required this.weatherStatus,
    required this.weatherSummary,
    this.temperatureCelsius,
    this.precipitationMm,
    this.windSpeedMs,
    required this.synergyScore,
    required this.explanation,
    required List<String> recommendedCropNames,
    required this.exportEvent,
  }) : recommendedCropNames = List.unmodifiable(recommendedCropNames);

  /// Whether this window includes a pre-spray stirring start time.
  bool get hasStirringLeadTime =>
      stirringStart != null &&
      stirringDuration != null &&
      stirringDuration!.inMinutes > 0;

  /// Whether forecast weather conflicts with outdoor execution in this window.
  bool get hasWeatherConflict =>
      weatherStatus == WeatherIntersectionStatus.conflict;
}

/// Complete 7-day biodynamic + weather synthesis digest.
final class WeekAheadDigest {
  /// Start timestamp of the digest horizon.
  final DateTime startDate;

  /// End timestamp of the digest horizon.
  final DateTime endDate;

  /// Day-by-day biodynamic and weather briefs (typically 7 days).
  final List<DailyBiodynamicBrief> dailyBriefs;

  /// Ranked upcoming synthesis windows ordered from highest synergy score to
  /// lowest.
  final List<RankedSynthesisWindow> rankedWindows;

  /// Narrative overview of the week's strongest windows, weekend outlook, and
  /// any Gray Day or weather cautions.
  final String headlineSummary;

  /// Creates an immutable [WeekAheadDigest].
  WeekAheadDigest({
    required this.startDate,
    required this.endDate,
    required List<DailyBiodynamicBrief> dailyBriefs,
    required List<RankedSynthesisWindow> rankedWindows,
    required this.headlineSummary,
  }) : dailyBriefs = List.unmodifiable(dailyBriefs),
       rankedWindows = List.unmodifiable(rankedWindows);

  /// Subset of [rankedWindows] that fall on Saturday or Sunday.
  List<RankedSynthesisWindow> get weekendWindows =>
      rankedWindows.where((window) => window.isWeekend).toList(growable: false);

  /// Subset of [rankedWindows] with no weather conflict.
  List<RankedSynthesisWindow> get conflictFreeWindows => rankedWindows
      .where((window) => !window.hasWeatherConflict)
      .toList(growable: false);

  /// Subset of [rankedWindows] where forecast weather is verified dry and calm.
  List<RankedSynthesisWindow> get dryAndCalmWindows => rankedWindows
      .where(
        (window) =>
            window.weatherStatus == WeatherIntersectionStatus.harmonious,
      )
      .toList(growable: false);

  /// Subset of [rankedWindows] for biodynamic field sprays (BD 500, BD 501, CPP, BD 508).
  List<RankedSynthesisWindow> get sprayWindows => rankedWindows
      .where(
        (window) => window.category == SynthesisWindowCategory.biodynamicSpray,
      )
      .toList(growable: false);
}

/// Synthesis engine computing the 7-day "Week Ahead" biodynamic + weather brief
/// and preparation export events.
abstract final class WeekAheadPlanner {
  static const int _maxDigestCacheEntries = 64;

  static final LinkedHashMap<Object, WeekAheadDigest> _digestCache =
      LinkedHashMap<Object, WeekAheadDigest>();

  static final Expando<
    (int, WeatherDataPoint, WeatherDataPoint, WeatherDataPoint, bool)
  >
  _sortedWeatherCache =
      Expando<
        (int, WeatherDataPoint, WeatherDataPoint, WeatherDataPoint, bool)
      >('WeekAheadPlannerSortedWeather');

  static final Map<(PlantQuality, int), List<String>> _cropNamesCache =
      <(PlantQuality, int), List<String>>{};

  static Object _weatherCacheKey(List<WeatherDataPoint>? weatherForecast) {
    if (weatherForecast == null || weatherForecast.isEmpty) {
      return 0;
    }
    final len = weatherForecast.length;
    if (len <= 32) {
      return (
        identityHashCode(weatherForecast),
        len,
        Object.hashAll(weatherForecast),
      );
    }
    return (
      identityHashCode(weatherForecast),
      len,
      weatherForecast.first,
      weatherForecast.last,
      weatherForecast[len >>> 1],
      weatherForecast[len >>> 2],
      weatherForecast[(len * 3) >>> 2],
    );
  }

  /// Builds a [WeekAheadDigest] over [days] starting from [startTime], ranking
  /// the best upcoming windows where cosmic quality, Moon declination
  /// (*Pflanzzeit*), diurnal breathing, and dry/calm forecast weather intersect.
  ///
  /// Both [days] and [maxRankedWindows] must be positive.
  static WeekAheadDigest buildDigest({
    required DateTime startTime,
    required EphemerisService ephemeris,
    List<WeatherDataPoint>? weatherForecast,
    double latitude = DefaultLocations.copenhagenLatitude,
    double longitude = DefaultLocations.copenhagenLongitude,
    SeasonAlignment? seasons,
    int days = 7,
    int maxRankedWindows = 10,
  }) {
    RangeError.checkValueInInterval(days, 1, 30, 'days');
    RangeError.checkValueInInterval(
      maxRankedWindows,
      1,
      50,
      'maxRankedWindows',
    );

    final alignment = seasons ?? HemisphereSeasonAlignment(latitude: latitude);
    final locVersion = algo.ephemerisLocationVersion(ephemeris);
    final cacheKey = locVersion == null
        ? null
        : (
            startTime.millisecondsSinceEpoch,
            startTime.isUtc,
            identityHashCode(ephemeris),
            locVersion,
            _weatherCacheKey(weatherForecast),
            (latitude * 1000).round(),
            (longitude * 1000).round(),
            identityHashCode(alignment.localProfile),
            alignment.hasNorthernSeasons,
            alignment.transferability,
            alignment.shortLabel,
            days,
            maxRankedWindows,
          );
    if (cacheKey != null) {
      final cachedDigest = _digestCache.remove(cacheKey);
      if (cachedDigest != null) {
        _digestCache[cacheKey] = cachedDigest;
        return cachedDigest;
      }
    }

    final baseDay = DateTime(startTime.year, startTime.month, startTime.day);
    final endLimit = DateTime(baseDay.year, baseDay.month, baseDay.day + days);

    final dailyBriefs = <DailyBiodynamicBrief>[];
    final candidateWindows = <_UnrankedWindowCandidate>[];

    for (int dayOffset = 0; dayOffset < days; dayOffset++) {
      final dayDate = DateTime(
        baseDay.year,
        baseDay.month,
        baseDay.day + dayOffset,
      );
      final isWeekend =
          dayDate.weekday == DateTime.saturday ||
          dayDate.weekday == DateTime.sunday;

      // Sample daytime hours (07:00, 10:00, 13:00, 16:00, 19:00) for daily brief
      final sampleHours = const <int>[7, 10, 13, 16, 19];
      final sampleInfos = <int, CalendarInfo>{};
      final qualityCounts = <PlantQuality, int>{};
      final distinctQualities = <PlantQuality>[];
      bool anyGray = false;
      bool allGray = true;
      bool anySpecial = false;
      int descendingCount = 0;

      for (final hour in sampleHours) {
        final sampleTime = DateTime(
          dayDate.year,
          dayDate.month,
          dayDate.day,
          hour,
        );
        final info = algo.getCalendarInfo(
          sampleTime,
          ephemeris,
          includePlanets: true,
          latitude: latitude,
          longitude: longitude,
        );
        sampleInfos[hour] = info;
        if (info.isGrayDay || info.isEclipse) {
          anyGray = true;
        } else {
          allGray = false;
        }
        if (info.isSpecial) anySpecial = true;
        if (info.isMoonDescending) descendingCount++;
        if (info.quality != PlantQuality.none) {
          qualityCounts[info.quality] = (qualityCounts[info.quality] ?? 0) + 1;
          if (!distinctQualities.contains(info.quality)) {
            distinctQualities.add(info.quality);
          }
        }
      }

      PlantQuality dominantQuality = PlantQuality.leaf;
      int bestCount = -1;
      for (final entry in qualityCounts.entries) {
        if (entry.value > bestCount) {
          bestCount = entry.value;
          dominantQuality = entry.key;
        }
      }

      final middayInfo = sampleInfos[13]!;
      final isDayDescending = descendingCount >= (sampleHours.length / 2);

      final dayWeather = _evaluateWeatherSpan(
        start: DateTime(dayDate.year, dayDate.month, dayDate.day, 6),
        end: DateTime(dayDate.year, dayDate.month, dayDate.day, 20),
        weatherForecast: weatherForecast,
        maxWindThreshold: 5.5,
        maxPrecipThreshold: 2.0,
      );

      final daySummary = _buildDailySummaryText(
        dominantQuality: dominantQuality,
        isDescending: isDayDescending,
        allGray: allGray,
        anyGray: anyGray,
        isSpecial: anySpecial,
        weather: dayWeather,
      );

      dailyBriefs.add(
        DailyBiodynamicBrief(
          date: dayDate,
          qualities: distinctQualities.isEmpty
              ? <PlantQuality>[dominantQuality]
              : distinctQualities,
          dominantQuality: dominantQuality,
          isDescending: isDayDescending,
          isWaxing: middayInfo.moonPhase.isWaxing,
          hasGrayHours: anyGray,
          isAllDayGray: allGray,
          isSpecialTrine: anySpecial,
          isWeekend: isWeekend,
          minTemperature: dayWeather.minTemperature,
          maxTemperature: dayWeather.maxTemperature,
          totalPrecipitationMm: dayWeather.totalPrecipitationMm,
          maxWindSpeedMs: dayWeather.maxWindSpeedMs,
          weatherStatus: dayWeather.status,
          daySummary: daySummary,
        ),
      );

      // 1. Morning Exhalation Slot (07:00–10:00, peak 08:00)
      final morningStart = DateTime(
        dayDate.year,
        dayDate.month,
        dayDate.day,
        7,
      );
      final morningEnd = DateTime(dayDate.year, dayDate.month, dayDate.day, 10);
      final morningPeak = DateTime(dayDate.year, dayDate.month, dayDate.day, 8);
      if (morningEnd.isAfter(startTime)) {
        final morningInfo = sampleInfos[7]!;
        if (!morningInfo.isGrayDay &&
            !morningInfo.isEclipse &&
            morningInfo.quality != PlantQuality.none) {
          _collectMorningCandidates(
            candidates: candidateWindows,
            dayDate: dayDate,
            morningStart: morningStart,
            morningEnd: morningEnd,
            morningPeak: morningPeak,
            info: morningInfo,
            isWeekend: isWeekend,
            weatherForecast: weatherForecast,
            alignment: alignment,
            latitude: latitude,
            longitude: longitude,
          );
        }
      }

      // 2. Afternoon / Evening Inhalation Slot (15:00–19:00, peak 16:00)
      final eveningStart = DateTime(
        dayDate.year,
        dayDate.month,
        dayDate.day,
        15,
      );
      final eveningEnd = DateTime(dayDate.year, dayDate.month, dayDate.day, 19);
      final eveningPeak = DateTime(
        dayDate.year,
        dayDate.month,
        dayDate.day,
        16,
      );
      if (eveningEnd.isAfter(startTime)) {
        final eveningInfo = sampleInfos[16]!;
        if (!eveningInfo.isGrayDay &&
            !eveningInfo.isEclipse &&
            eveningInfo.quality != PlantQuality.none) {
          _collectEveningCandidates(
            candidates: candidateWindows,
            dayDate: dayDate,
            eveningStart: eveningStart,
            eveningEnd: eveningEnd,
            eveningPeak: eveningPeak,
            info: eveningInfo,
            isWeekend: isWeekend,
            weatherForecast: weatherForecast,
            alignment: alignment,
            latitude: latitude,
            longitude: longitude,
          );
        }
      }
    }

    // Deduplicate redundant BD 500 spray candidates if multiple occur so the
    // digest highlights the top 2 BD 500 windows and top 2 BD 501 windows
    // alongside planting & harvest windows.
    final filteredCandidates = _curateCandidateMix(candidateWindows);

    filteredCandidates.sort((a, b) {
      final scoreComparison = b.synergyScore.compareTo(a.synergyScore);
      if (scoreComparison != 0) return scoreComparison;
      return a.start.compareTo(b.start);
    });

    final topCandidates = filteredCandidates
        .take(maxRankedWindows)
        .toList(growable: false);

    final rankedWindows = <RankedSynthesisWindow>[];
    for (int index = 0; index < topCandidates.length; index++) {
      final candidate = topCandidates[index];
      rankedWindows.add(candidate.toRankedWindow(rank: index + 1));
    }

    final headlineSummary = _buildHeadlineSummary(
      dailyBriefs: dailyBriefs,
      rankedWindows: rankedWindows,
    );

    final digest = WeekAheadDigest(
      startDate: startTime,
      endDate: endLimit,
      dailyBriefs: dailyBriefs,
      rankedWindows: rankedWindows,
      headlineSummary: headlineSummary,
    );
    if (cacheKey != null) {
      if (_digestCache.length >= _maxDigestCacheEntries) {
        _digestCache.remove(_digestCache.keys.first);
      }
      _digestCache[cacheKey] = digest;
    }
    return digest;
  }

  /// Builds a [CalendarExportEvent] for the active or next upcoming biodynamic
  /// field preparation spray (`BD 500`, `BD 501`, `CPP`, or `BD 508`) starting
  /// at or after [selectedDate], including its pre-spray dynamization stirring
  /// start time (`1 hour` prior for BD 500/501, `20 minutes` prior for CPP/BD 508).
  static CalendarExportEvent buildCurrentOrNextPrepExport({
    required CalendarInfo info,
    required DateTime selectedDate,
    EphemerisService? ephemeris,
    List<WeatherDataPoint>? weatherForecast,
    double latitude = DefaultLocations.copenhagenLatitude,
    double longitude = DefaultLocations.copenhagenLongitude,
  }) {
    final hour = selectedDate.hour;

    // 1. If selectedDate is already inside an active spray window, export it directly.
    if (!info.isGrayDay && !info.isEclipse) {
      if (info.isMoonDescending && hour >= 15 && hour <= 20) {
        final sprayStart = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          16,
        );
        final sprayEnd = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          19,
        );
        final weather = _evaluateWeatherSpan(
          start: sprayStart,
          end: sprayEnd,
          weatherForecast: weatherForecast,
          maxWindThreshold: 5.0,
          maxPrecipThreshold: 1.0,
        );
        return IcsCalendarExporter.fromBiodynamicSpray(
          preparation: BiodynamicPrepType.bd500,
          sprayStart: sprayStart,
          sprayEnd: sprayEnd,
          calendarInfo: info,
          weatherSummary: weather.summary,
          latitude: latitude,
          longitude: longitude,
        );
      }

      if (info.isMoonAscending &&
          hour >= 5 &&
          hour <= 9 &&
          (info.quality == PlantQuality.flower ||
              info.quality == PlantQuality.fruit)) {
        final sprayStart = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          6,
        );
        final sprayEnd = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          9,
        );
        final weather = _evaluateWeatherSpan(
          start: sprayStart,
          end: sprayEnd,
          weatherForecast: weatherForecast,
          maxWindThreshold: 5.5,
          maxPrecipThreshold: 1.0,
        );
        return IcsCalendarExporter.fromBiodynamicSpray(
          preparation: BiodynamicPrepType.bd501,
          sprayStart: sprayStart,
          sprayEnd: sprayEnd,
          calendarInfo: info,
          weatherSummary: weather.summary,
          latitude: latitude,
          longitude: longitude,
        );
      }
    }

    // 2. Otherwise search forward over the next 7 days if an EphemerisService is provided.
    if (ephemeris != null) {
      final digest = buildDigest(
        startTime: selectedDate,
        ephemeris: ephemeris,
        weatherForecast: weatherForecast,
        latitude: latitude,
        longitude: longitude,
        days: 7,
        maxRankedWindows: 14,
      );
      final sprayWindows = digest.sprayWindows;
      if (sprayWindows.isNotEmpty) {
        return sprayWindows.first.exportEvent;
      }
    }

    // 3. Fallback to the next diurnal preparation slot for the current Moon arc.
    final isDescending = info.isMoonDescending;
    final BiodynamicPrepType fallbackPrep = isDescending
        ? BiodynamicPrepType.bd500
        : BiodynamicPrepType.bd501;
    DateTime sprayStart;
    if (isDescending) {
      sprayStart = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        16,
      );
      if (!sprayStart.isAfter(selectedDate)) {
        sprayStart = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day + 1,
          16,
        );
      }
    } else {
      sprayStart = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        6,
      );
      if (!sprayStart.isAfter(selectedDate)) {
        sprayStart = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day + 1,
          6,
        );
      }
    }
    final sprayEnd = sprayStart.add(const Duration(hours: 3));
    final weather = _evaluateWeatherSpan(
      start: sprayStart,
      end: sprayEnd,
      weatherForecast: weatherForecast,
      maxWindThreshold: 5.0,
      maxPrecipThreshold: 1.0,
    );

    return IcsCalendarExporter.fromBiodynamicSpray(
      preparation: fallbackPrep,
      sprayStart: sprayStart,
      sprayEnd: sprayEnd,
      calendarInfo: info,
      weatherSummary: weather.summary,
      latitude: latitude,
      longitude: longitude,
    );
  }

  static void _collectMorningCandidates({
    required List<_UnrankedWindowCandidate> candidates,
    required DateTime dayDate,
    required DateTime morningStart,
    required DateTime morningEnd,
    required DateTime morningPeak,
    required CalendarInfo info,
    required bool isWeekend,
    required List<WeatherDataPoint>? weatherForecast,
    required SeasonAlignment alignment,
    required double latitude,
    required double longitude,
  }) {
    final quality = info.quality;
    final weather = _evaluateWeatherSpan(
      start: morningStart,
      end: morningEnd,
      weatherForecast: weatherForecast,
      maxWindThreshold: 5.5,
      maxPrecipThreshold: 1.5,
    );

    final cropNames = _recommendedCropNamesFor(
      quality: quality,
      date: morningPeak,
      alignment: alignment,
    );

    // Candidate A: Morning Exhalation Harvest / Grafting on Ascending Moon
    if (info.isMoonAscending &&
        (quality == PlantQuality.fruit ||
            quality == PlantQuality.flower ||
            quality == PlantQuality.leaf)) {
      final action =
          quality == PlantQuality.fruit || quality == PlantQuality.flower
          ? TaskActionType.harvestStorage
          : TaskActionType.harvestFresh;
      final score = _computeSynergyScore(
        declinationAligned: true,
        diurnalAligned: true,
        isSpecialTrine: info.isSpecial,
        isWeekend: isWeekend,
        weather: weather,
      );
      final title =
          '${quality.displayName} Day • Morning Exhalation Harvest & Care';
      final subtitle =
          'Ascending Moon + Morning Exhalation (07:00–10:00)${info.isSpecial ? " • Planetary Trine" : ""}';
      final explanation =
          'Rising sap (Ascending Moon) and Morning Exhalation fill ${quality.displayName.toLowerCase()} organs with sugars, essential oils, and crisp vitality. ${weather.summary}';

      final taskWindow = TaskWindow(
        start: morningStart,
        end: morningEnd,
        peakTime: morningPeak,
        suitability: TaskSuitability.optimal,
        quality: quality,
        isDescending: false,
        isWaxing: info.moonPhase.isWaxing,
        isSpecialTrine: info.isSpecial,
        isInSeason: true,
        headline: '${quality.displayName} Day • Ascending Moon',
        cosmicExplanation: explanation,
        weatherNote: weather.summary,
        hasWeatherConflict:
            weather.status == WeatherIntersectionStatus.conflict,
      );

      final exportEvent = IcsCalendarExporter.fromTaskWindow(
        window: taskWindow,
        action: action,
        latitude: latitude,
        longitude: longitude,
      );

      candidates.add(
        _UnrankedWindowCandidate(
          id: 'morning_harvest_${dayDate.year}_${dayDate.month}_${dayDate.day}',
          category: SynthesisWindowCategory.harvestAndCanopy,
          title: title,
          subtitle: subtitle,
          start: morningStart,
          end: morningEnd,
          peakTime: morningPeak,
          primaryAction: action,
          quality: quality,
          diurnalPhase: DiurnalPhase.morningExhalation,
          isDescending: false,
          isWaxing: info.moonPhase.isWaxing,
          isSpecialTrine: info.isSpecial,
          isWeekend: isWeekend,
          weatherStatus: weather.status,
          weatherSummary: weather.summary,
          temperatureCelsius: weather.meanTemperature,
          precipitationMm: weather.totalPrecipitationMm,
          windSpeedMs: weather.maxWindSpeedMs,
          synergyScore: score,
          explanation: explanation,
          recommendedCropNames: cropNames,
          exportEvent: exportEvent,
        ),
      );
    }

    // Candidate B: BD 501 Horn Silica Sunrise Spray (Ascending Moon + Flower/Fruit Day)
    if (info.isMoonAscending &&
        (quality == PlantQuality.flower || quality == PlantQuality.fruit)) {
      final sprayStart = DateTime(dayDate.year, dayDate.month, dayDate.day, 6);
      final sprayEnd = DateTime(dayDate.year, dayDate.month, dayDate.day, 9);
      final sprayPeak = DateTime(dayDate.year, dayDate.month, dayDate.day, 7);
      final sprayWeather = _evaluateWeatherSpan(
        start: sprayStart,
        end: sprayEnd,
        weatherForecast: weatherForecast,
        maxWindThreshold: 5.5,
        maxPrecipThreshold: 1.0,
      );
      final score =
          _computeSynergyScore(
            declinationAligned: true,
            diurnalAligned: true,
            isSpecialTrine: info.isSpecial,
            isWeekend: isWeekend,
            weather: sprayWeather,
          ) +
          2.0;

      final exportEvent = IcsCalendarExporter.fromBiodynamicSpray(
        preparation: BiodynamicPrepType.bd501,
        sprayStart: sprayStart,
        sprayEnd: sprayEnd,
        calendarInfo: info,
        weatherSummary: sprayWeather.summary,
        latitude: latitude,
        longitude: longitude,
      );

      candidates.add(
        _UnrankedWindowCandidate(
          id: 'bd501_${dayDate.year}_${dayDate.month}_${dayDate.day}',
          category: SynthesisWindowCategory.biodynamicSpray,
          title:
              'BD 501 Horn Silica • Sunrise Light Mist (${quality.displayName} Day)',
          subtitle:
              'Stir 05:00–06:00 (1h) • Spray 06:00–09:00 • Ascending Moon',
          start: sprayStart,
          end: sprayEnd,
          peakTime: sprayPeak,
          stirringStart: exportEvent.stirringStart,
          stirringDuration: exportEvent.stirringDuration,
          preparation: BiodynamicPrepType.bd501,
          quality: quality,
          diurnalPhase: DiurnalPhase.morningExhalation,
          isDescending: false,
          isWaxing: info.moonPhase.isWaxing,
          isSpecialTrine: info.isSpecial,
          isWeekend: isWeekend,
          weatherStatus: sprayWeather.status,
          weatherSummary: sprayWeather.summary,
          temperatureCelsius: sprayWeather.meanTemperature,
          precipitationMm: sprayWeather.totalPrecipitationMm,
          windSpeedMs: sprayWeather.maxWindSpeedMs,
          synergyScore: score.clamp(0.0, 100.0),
          explanation:
              'Ascending Moon on a ${quality.displayName} Day during Morning Exhalation activates photosynthesis, sugar formation, and crop ripening. Begin 1-hour dynamization at 05:00 before misting foliage at sunrise. ${sprayWeather.summary}',
          recommendedCropNames: cropNames,
          exportEvent: exportEvent,
        ),
      );
    }
  }

  static void _collectEveningCandidates({
    required List<_UnrankedWindowCandidate> candidates,
    required DateTime dayDate,
    required DateTime eveningStart,
    required DateTime eveningEnd,
    required DateTime eveningPeak,
    required CalendarInfo info,
    required bool isWeekend,
    required List<WeatherDataPoint>? weatherForecast,
    required SeasonAlignment alignment,
    required double latitude,
    required double longitude,
  }) {
    final quality = info.quality;
    final isDescending = info.isMoonDescending;
    final weather = _evaluateWeatherSpan(
      start: eveningStart,
      end: eveningEnd,
      weatherForecast: weatherForecast,
      maxWindThreshold: 5.5,
      maxPrecipThreshold: 2.0,
    );

    final cropNames = _recommendedCropNamesFor(
      quality: quality,
      date: eveningPeak,
      alignment: alignment,
    );

    // Candidate A: Evening Inhalation Planting / Pflanzzeit / Sowing Window
    final primaryAction = isDescending
        ? TaskActionType.transplant
        : TaskActionType.sowOutdoor;
    final score = _computeSynergyScore(
      declinationAligned: isDescending,
      diurnalAligned: true,
      isSpecialTrine: info.isSpecial,
      isWeekend: isWeekend,
      weather: weather,
    );

    final title = isDescending
        ? '${quality.displayName} Day Pflanzzeit • Sow, Transplant & Cultivate'
        : '${quality.displayName} Day • Evening Inhalation Direct Sowing';
    final subtitle = isDescending
        ? 'Descending Moon (Pflanzzeit) + Evening Inhalation (15:00–19:00)'
        : 'Ascending Moon + Evening Inhalation (15:00–19:00)';
    final explanation = isDescending
        ? 'Prime Maria Thun intersection: ${quality.displayName} constellation + Descending Moon (Pflanzzeit) + Evening Earth Inhalation draws sap and soil forces downward into roots and callus. ${weather.summary}'
        : 'Sidereal ${quality.displayName} impulse aligned with Afternoon Earth Inhalation (15:00–19:00) for direct seed sowing and hoeing. ${weather.summary}';

    final taskWindow = TaskWindow(
      start: eveningStart,
      end: eveningEnd,
      peakTime: eveningPeak,
      suitability: isDescending
          ? TaskSuitability.optimal
          : TaskSuitability.favorable,
      quality: quality,
      isDescending: isDescending,
      isWaxing: info.moonPhase.isWaxing,
      isSpecialTrine: info.isSpecial,
      isInSeason: true,
      headline:
          '${quality.displayName} Day • ${isDescending ? "Descending Moon (Pflanzzeit)" : "Ascending Moon"}',
      cosmicExplanation: explanation,
      weatherNote: weather.summary,
      hasWeatherConflict: weather.status == WeatherIntersectionStatus.conflict,
    );

    final exportEvent = IcsCalendarExporter.fromTaskWindow(
      window: taskWindow,
      action: primaryAction,
      latitude: latitude,
      longitude: longitude,
    );

    candidates.add(
      _UnrankedWindowCandidate(
        id: 'evening_plant_${dayDate.year}_${dayDate.month}_${dayDate.day}',
        category: SynthesisWindowCategory.plantingAndSoil,
        title: title,
        subtitle: subtitle,
        start: eveningStart,
        end: eveningEnd,
        peakTime: eveningPeak,
        primaryAction: primaryAction,
        quality: quality,
        diurnalPhase: DiurnalPhase.eveningInhalation,
        isDescending: isDescending,
        isWaxing: info.moonPhase.isWaxing,
        isSpecialTrine: info.isSpecial,
        isWeekend: isWeekend,
        weatherStatus: weather.status,
        weatherSummary: weather.summary,
        temperatureCelsius: weather.meanTemperature,
        precipitationMm: weather.totalPrecipitationMm,
        windSpeedMs: weather.maxWindSpeedMs,
        synergyScore: score,
        explanation: explanation,
        recommendedCropNames: cropNames,
        exportEvent: exportEvent,
      ),
    );

    // Candidate B: BD 500 Horn Manure Evening Soil Spray on Descending Moon
    if (isDescending) {
      final sprayStart = DateTime(dayDate.year, dayDate.month, dayDate.day, 16);
      final sprayEnd = DateTime(dayDate.year, dayDate.month, dayDate.day, 19);
      final sprayPeak = DateTime(dayDate.year, dayDate.month, dayDate.day, 17);
      final sprayWeather = _evaluateWeatherSpan(
        start: sprayStart,
        end: sprayEnd,
        weatherForecast: weatherForecast,
        maxWindThreshold: 5.0,
        maxPrecipThreshold: 1.0,
      );
      final rootBonus = quality == PlantQuality.root ? 4.0 : 0.0;
      final sprayScore =
          (_computeSynergyScore(
                    declinationAligned: true,
                    diurnalAligned: true,
                    isSpecialTrine: info.isSpecial,
                    isWeekend: isWeekend,
                    weather: sprayWeather,
                  ) +
                  rootBonus)
              .clamp(0.0, 100.0);

      final sprayExport = IcsCalendarExporter.fromBiodynamicSpray(
        preparation: BiodynamicPrepType.bd500,
        sprayStart: sprayStart,
        sprayEnd: sprayEnd,
        calendarInfo: info,
        weatherSummary: sprayWeather.summary,
        latitude: latitude,
        longitude: longitude,
      );

      candidates.add(
        _UnrankedWindowCandidate(
          id: 'bd500_${dayDate.year}_${dayDate.month}_${dayDate.day}',
          category: SynthesisWindowCategory.biodynamicSpray,
          title:
              'BD 500 Horn Manure & CPP • Evening Soil Spray (${quality.displayName} Day)',
          subtitle:
              'Stir 15:00–16:00 (1h) • Spray 16:00–19:00 • Descending Moon',
          start: sprayStart,
          end: sprayEnd,
          peakTime: sprayPeak,
          stirringStart: sprayExport.stirringStart,
          stirringDuration: sprayExport.stirringDuration,
          preparation: BiodynamicPrepType.bd500,
          quality: quality,
          diurnalPhase: DiurnalPhase.eveningInhalation,
          isDescending: true,
          isWaxing: info.moonPhase.isWaxing,
          isSpecialTrine: info.isSpecial,
          isWeekend: isWeekend,
          weatherStatus: sprayWeather.status,
          weatherSummary: sprayWeather.summary,
          temperatureCelsius: sprayWeather.meanTemperature,
          precipitationMm: sprayWeather.totalPrecipitationMm,
          windSpeedMs: sprayWeather.maxWindSpeedMs,
          synergyScore: sprayScore,
          explanation:
              'Descending Moon (Pflanzzeit) and Evening Earth Inhalation draw BD 500 Horn Manure and CPP droplets deep into the rhizosphere. Begin 1-hour dynamization at 15:00 for 16:00 application. ${sprayWeather.summary}',
          recommendedCropNames: cropNames,
          exportEvent: sprayExport,
        ),
      );
    }
  }

  static List<_UnrankedWindowCandidate> _curateCandidateMix(
    List<_UnrankedWindowCandidate> allCandidates,
  ) {
    final sorted = List<_UnrankedWindowCandidate>.of(allCandidates)
      ..sort((a, b) {
        final cmp = b.synergyScore.compareTo(a.synergyScore);
        if (cmp != 0) return cmp;
        return a.start.compareTo(b.start);
      });

    final curated = <_UnrankedWindowCandidate>[];
    int bd500Count = 0;
    int bd501Count = 0;

    for (final candidate in sorted) {
      if (candidate.preparation == BiodynamicPrepType.bd500) {
        if (bd500Count >= 2) continue;
        bd500Count++;
      } else if (candidate.preparation == BiodynamicPrepType.bd501) {
        if (bd501Count >= 2) continue;
        bd501Count++;
      }
      curated.add(candidate);
    }
    return curated;
  }

  static double _computeSynergyScore({
    required bool declinationAligned,
    required bool diurnalAligned,
    required bool isSpecialTrine,
    required bool isWeekend,
    required _WeatherSpanEvaluation weather,
  }) {
    double score = 38.0; // Base non-Gray sidereal Plant-Part Day
    score += declinationAligned ? 22.0 : 9.0;
    if (diurnalAligned) score += 15.0;
    if (isSpecialTrine) score += 6.0;
    if (isWeekend) score += 2.0;

    switch (weather.status) {
      case WeatherIntersectionStatus.harmonious:
        score += 20.0;
      case WeatherIntersectionStatus.acceptable:
        score += 11.0;
      case WeatherIntersectionStatus.unverified:
        score += 6.0;
      case WeatherIntersectionStatus.conflict:
        score -= 26.0;
    }

    return score.clamp(0.0, 100.0);
  }

  static bool _isSortedForecast(List<WeatherDataPoint> points) {
    final len = points.length;
    if (len <= 1) return true;
    if (len <= 32) {
      for (int i = 1; i < len; i++) {
        if (points[i].time.isBefore(points[i - 1].time)) {
          return false;
        }
      }
      return true;
    }
    final first = points.first;
    final last = points.last;
    final mid = points[len >>> 1];
    if (_sortedWeatherCache[points] case final cached?
        when cached.$1 == len &&
            cached.$2 == first &&
            cached.$3 == last &&
            cached.$4 == mid) {
      return cached.$5;
    }
    bool sorted = true;
    for (int i = 1; i < len; i++) {
      if (points[i].time.isBefore(points[i - 1].time)) {
        sorted = false;
        break;
      }
    }
    _sortedWeatherCache[points] = (len, first, last, mid, sorted);
    return sorted;
  }

  static _WeatherSpanEvaluation _evaluateWeatherSpan({
    required DateTime start,
    required DateTime end,
    required List<WeatherDataPoint>? weatherForecast,
    required double maxWindThreshold,
    required double maxPrecipThreshold,
  }) {
    if (weatherForecast == null || weatherForecast.isEmpty) {
      return const _WeatherSpanEvaluation(
        status: WeatherIntersectionStatus.unverified,
        summary:
            'Cosmic window verified (awaiting local hourly weather forecast).',
        minTemperature: null,
        maxTemperature: null,
        meanTemperature: null,
        totalPrecipitationMm: 0.0,
        maxWindSpeedMs: 0.0,
      );
    }

    final windowStartMs = start
        .subtract(const Duration(hours: 1))
        .millisecondsSinceEpoch;
    final windowEndMs = end
        .add(const Duration(hours: 1))
        .millisecondsSinceEpoch;

    double? minTemp;
    double? maxTemp;
    double tempSum = 0.0;
    int tempCount = 0;
    double totalPrecip = 0.0;
    double maxWind = 0.0;
    int matchCount = 0;

    if (_isSortedForecast(weatherForecast)) {
      int low = 0;
      int high = weatherForecast.length;
      while (low < high) {
        final mid = (low + high) >>> 1;
        if (weatherForecast[mid].time.millisecondsSinceEpoch < windowStartMs) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }
      for (int i = low; i < weatherForecast.length; i++) {
        final point = weatherForecast[i];
        if (point.time.millisecondsSinceEpoch > windowEndMs) {
          break;
        }
        matchCount++;
        if (point.temperature case final temperature?) {
          if (minTemp == null || temperature < minTemp) minTemp = temperature;
          if (maxTemp == null || temperature > maxTemp) maxTemp = temperature;
          tempSum += temperature;
          tempCount++;
        }
        totalPrecip += point.precipitation;
        if (point.windSpeed > maxWind) {
          maxWind = point.windSpeed;
        }
      }
    } else {
      for (final point in weatherForecast) {
        final ms = point.time.millisecondsSinceEpoch;
        if (ms < windowStartMs || ms > windowEndMs) continue;
        matchCount++;
        if (point.temperature case final temperature?) {
          if (minTemp == null || temperature < minTemp) minTemp = temperature;
          if (maxTemp == null || temperature > maxTemp) maxTemp = temperature;
          tempSum += temperature;
          tempCount++;
        }
        totalPrecip += point.precipitation;
        if (point.windSpeed > maxWind) {
          maxWind = point.windSpeed;
        }
      }
    }

    if (matchCount == 0) {
      return const _WeatherSpanEvaluation(
        status: WeatherIntersectionStatus.unverified,
        summary: 'Beyond hourly forecast horizon — observe local sky and soil moisture.',
        minTemperature: null,
        maxTemperature: null,
        meanTemperature: null,
        totalPrecipitationMm: 0.0,
        maxWindSpeedMs: 0.0,
      );
    }

    final meanTemp = tempCount > 0 ? tempSum / tempCount : null;
    final tempText = meanTemp != null
        ? '${meanTemp.toStringAsFixed(1)}°C'
        : 'N/A';

    if (minTemp != null && minTemp <= 0.0) {
      return _WeatherSpanEvaluation(
        status: WeatherIntersectionStatus.conflict,
        summary:
            'Weather Alert: Freezing forecast (${minTemp.toStringAsFixed(1)}°C) — avoid open-ground disturbance or spraying.',
        minTemperature: minTemp,
        maxTemperature: maxTemp,
        meanTemperature: meanTemp,
        totalPrecipitationMm: totalPrecip,
        maxWindSpeedMs: maxWind,
      );
    }

    if (totalPrecip > maxPrecipThreshold) {
      return _WeatherSpanEvaluation(
        status: WeatherIntersectionStatus.conflict,
        summary:
            'Weather Alert: Rain forecast (${totalPrecip.toStringAsFixed(1)} mm) risks soil compaction or spray wash-off.',
        minTemperature: minTemp,
        maxTemperature: maxTemp,
        meanTemperature: meanTemp,
        totalPrecipitationMm: totalPrecip,
        maxWindSpeedMs: maxWind,
      );
    }

    if (maxWind > maxWindThreshold) {
      return _WeatherSpanEvaluation(
        status: WeatherIntersectionStatus.conflict,
        summary:
            'Weather Alert: High wind (${maxWind.toStringAsFixed(1)} m/s) exceeds spray drift and seedling threshold.',
        minTemperature: minTemp,
        maxTemperature: maxTemp,
        meanTemperature: meanTemp,
        totalPrecipitationMm: totalPrecip,
        maxWindSpeedMs: maxWind,
      );
    }

    if (totalPrecip <= 0.3 &&
        maxWind <= 4.2 &&
        (minTemp == null || minTemp >= 4.0)) {
      return _WeatherSpanEvaluation(
        status: WeatherIntersectionStatus.harmonious,
        summary:
            'Dry & calm forecast ($tempText, ${totalPrecip.toStringAsFixed(1)} mm, ${maxWind.toStringAsFixed(1)} m/s wind).',
        minTemperature: minTemp,
        maxTemperature: maxTemp,
        meanTemperature: meanTemp,
        totalPrecipitationMm: totalPrecip,
        maxWindSpeedMs: maxWind,
      );
    }

    return _WeatherSpanEvaluation(
      status: WeatherIntersectionStatus.acceptable,
      summary:
          'Workable forecast ($tempText, ${totalPrecip.toStringAsFixed(1)} mm, ${maxWind.toStringAsFixed(1)} m/s wind).',
      minTemperature: minTemp,
      maxTemperature: maxTemp,
      meanTemperature: meanTemp,
      totalPrecipitationMm: totalPrecip,
      maxWindSpeedMs: maxWind,
    );
  }

  static List<String> _recommendedCropNamesFor({
    required PlantQuality quality,
    required DateTime date,
    required SeasonAlignment alignment,
  }) {
    final referenceMonth = alignment
        .referenceMonth(date, anchor: SeasonalAnchor.thermal)
        .clamp(1, 12);
    final key = (quality, referenceMonth);
    if (_cropNamesCache[key] case final cached?) {
      return cached;
    }
    final seasonalMatches = VegetableDatabase.getVegetablesForMonth(
      referenceMonth,
      quality: quality,
    );
    final source = seasonalMatches.isNotEmpty
        ? seasonalMatches
        : VegetableDatabase.getVegetablesForQuality(quality);
    final result = List<String>.unmodifiable(
      source.take(4).map((crop) => crop.localizedDisplayName),
    );
    return _cropNamesCache[key] = result;
  }

  static String _buildDailySummaryText({
    required PlantQuality dominantQuality,
    required bool isDescending,
    required bool allGray,
    required bool anyGray,
    required bool isSpecial,
    required _WeatherSpanEvaluation weather,
  }) {
    if (allGray) {
      return 'Gray Day blackout — rest beds, turn compost, and pause sowing/spraying.';
    }
    final arcText = isDescending
        ? 'Descending Moon (Pflanzzeit)'
        : 'Ascending Moon';
    final grayCaution = anyGray ? ' (partial Gray hours)' : '';
    final trineText = isSpecial ? ' • Planetary Trine' : '';
    return '${dominantQuality.displayName} Day$grayCaution • $arcText$trineText • ${weather.status.badgeLabel}';
  }

  static String _buildHeadlineSummary({
    required List<DailyBiodynamicBrief> dailyBriefs,
    required List<RankedSynthesisWindow> rankedWindows,
  }) {
    final conflictFree = rankedWindows
        .where((window) => !window.hasWeatherConflict)
        .toList(growable: false);
    final grayDaysCount = dailyBriefs.where((day) => day.hasGrayHours).length;
    final weekendBest = conflictFree
        .where((window) => window.isWeekend)
        .toList(growable: false);

    if (conflictFree.isEmpty) {
      return 'Challenging 7-day horizon: cosmic or weather cautions affect most windows. Inspect indoor propagation or wait for calmer skies.';
    }

    final best = conflictFree.first;
    final weekdayNames = const <String>[
      '',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final bestDayName =
        '${weekdayNames[best.start.weekday]} ${best.start.month}/${best.start.day}';
    final weekendSentence = weekendBest.isNotEmpty
        ? ' Weekend highlight: ${weekendBest.first.title} on ${weekdayNames[weekendBest.first.start.weekday]}.'
        : '';
    final graySentence = grayDaysCount > 0
        ? ' Note: $grayDaysCount day${grayDaysCount == 1 ? "" : "s"} include Gray Day blackout hours.'
        : '';

    return 'Top synthesis window: ${best.title} on $bestDayName (${best.weatherStatus.badgeLabel}).$weekendSentence$graySentence';
  }
}

final class _WeatherSpanEvaluation {
  final WeatherIntersectionStatus status;
  final String summary;
  final double? minTemperature;
  final double? maxTemperature;
  final double? meanTemperature;
  final double totalPrecipitationMm;
  final double maxWindSpeedMs;

  const _WeatherSpanEvaluation({
    required this.status,
    required this.summary,
    required this.minTemperature,
    required this.maxTemperature,
    required this.meanTemperature,
    required this.totalPrecipitationMm,
    required this.maxWindSpeedMs,
  });
}

final class _UnrankedWindowCandidate {
  final String id;
  final SynthesisWindowCategory category;
  final String title;
  final String subtitle;
  final DateTime start;
  final DateTime end;
  final DateTime peakTime;
  final DateTime? stirringStart;
  final Duration? stirringDuration;
  final BiodynamicPrepType? preparation;
  final TaskActionType? primaryAction;
  final PlantQuality quality;
  final DiurnalPhase diurnalPhase;
  final bool isDescending;
  final bool isWaxing;
  final bool isSpecialTrine;
  final bool isWeekend;
  final WeatherIntersectionStatus weatherStatus;
  final String weatherSummary;
  final double? temperatureCelsius;
  final double? precipitationMm;
  final double? windSpeedMs;
  final double synergyScore;
  final String explanation;
  final List<String> recommendedCropNames;
  final CalendarExportEvent exportEvent;

  const _UnrankedWindowCandidate({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.start,
    required this.end,
    required this.peakTime,
    this.stirringStart,
    this.stirringDuration,
    this.preparation,
    this.primaryAction,
    required this.quality,
    required this.diurnalPhase,
    required this.isDescending,
    required this.isWaxing,
    required this.isSpecialTrine,
    required this.isWeekend,
    required this.weatherStatus,
    required this.weatherSummary,
    this.temperatureCelsius,
    this.precipitationMm,
    this.windSpeedMs,
    required this.synergyScore,
    required this.explanation,
    required this.recommendedCropNames,
    required this.exportEvent,
  });

  RankedSynthesisWindow toRankedWindow({required int rank}) {
    return RankedSynthesisWindow(
      id: id,
      rank: rank,
      category: category,
      title: title,
      subtitle: subtitle,
      start: start,
      end: end,
      peakTime: peakTime,
      stirringStart: stirringStart,
      stirringDuration: stirringDuration,
      preparation: preparation,
      primaryAction: primaryAction,
      quality: quality,
      diurnalPhase: diurnalPhase,
      isDescending: isDescending,
      isWaxing: isWaxing,
      isSpecialTrine: isSpecialTrine,
      isWeekend: isWeekend,
      weatherStatus: weatherStatus,
      weatherSummary: weatherSummary,
      temperatureCelsius: temperatureCelsius,
      precipitationMm: precipitationMm,
      windSpeedMs: windSpeedMs,
      synergyScore: synergyScore,
      explanation: explanation,
      recommendedCropNames: recommendedCropNames,
      exportEvent: exportEvent,
    );
  }
}
