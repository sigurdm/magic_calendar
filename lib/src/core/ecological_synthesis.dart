import 'dart:collection';

import 'climate/climate_profile.dart';
import 'climate/season_alignment.dart';
import 'models/models.dart';

/// Categories of weather alerts in ecological synthesis.
enum EcologicalAlertType {
  waterlogging,
  freezing,
  coldSoil,
  highWind,
  sprayWashoffRisk,
  springFrostRisk,
  favorable,
}

/// Severity of ecological alerts.
enum EcologicalAlertSeverity { info, warning, critical }

/// An actionable ecological alert synthesizing cosmic recommendations with real-time weather.
final class EcologicalAlert {
  final EcologicalAlertType type;
  final EcologicalAlertSeverity severity;
  final String title;
  final String description;
  final String practicalAdvice;
  final bool preventsTillage;
  final bool indoorSowingAdvised;
  final bool preventsSpray;
  final bool valerianSprayAdvised;

  const EcologicalAlert({
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.practicalAdvice,
    this.preventsTillage = false,
    this.indoorSowingAdvised = false,
    this.preventsSpray = false,
    this.valerianSprayAdvised = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EcologicalAlert &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          severity == other.severity &&
          title == other.title &&
          description == other.description &&
          practicalAdvice == other.practicalAdvice &&
          preventsTillage == other.preventsTillage &&
          indoorSowingAdvised == other.indoorSowingAdvised &&
          preventsSpray == other.preventsSpray &&
          valerianSprayAdvised == other.valerianSprayAdvised;

  @override
  int get hashCode => Object.hash(
    type,
    severity,
    title,
    description,
    practicalAdvice,
    preventsTillage,
    indoorSowingAdvised,
    preventsSpray,
    valerianSprayAdvised,
  );

  @override
  String toString() =>
      'EcologicalAlert(type: $type, title: $title, severity: $severity)';
}

/// Result of synthesizing astronomical rhythms with physical weather conditions.
final class EcologicalSynthesisResult {
  /// The collection of active weather alerts.
  final List<EcologicalAlert> alerts;

  /// Top-level synthesis banner title (e.g. "The Stars Incline, They Do Not Compel").
  final String bannerTitle;

  /// Explanatory synthesis subtitle summarizing current harmony or adaptation required.
  final String bannerSubtitle;

  /// True if any severe weather condition overrides or constrains cosmic work.
  final bool hasConflicts;

  /// Optional multi-horizon soil moisture, soil temperature, and forecast lookahead analysis.
  final MultiHorizonWeatherAnalysis? horizon;

  const EcologicalSynthesisResult({
    required this.alerts,
    required this.bannerTitle,
    required this.bannerSubtitle,
    required this.hasConflicts,
    this.horizon,
  });

  /// True if soil waterlogging (instantaneous or 48–72h antecedent) is detected.
  bool get hasWaterlogging =>
      alerts.any((a) => a.type == EcologicalAlertType.waterlogging);

  /// True if freezing temperatures are detected.
  bool get isFreezing =>
      alerts.any((a) => a.type == EcologicalAlertType.freezing);

  /// True if cold soil (< 5 °C) is detected despite above-freezing air temperature.
  bool get hasColdSoil =>
      alerts.any((a) => a.type == EcologicalAlertType.coldSoil);

  /// True if high wind exceeds spray threshold.
  bool get hasHighWind =>
      alerts.any((a) => a.type == EcologicalAlertType.highWind);

  /// True if upcoming rain threatens to wash off field sprays.
  bool get hasSprayWashoffRisk =>
      alerts.any((a) => a.type == EcologicalAlertType.sprayWashoffRisk);

  /// True if frost risk (instantaneous or 24–48h lookahead) is present.
  bool get hasFrostRisk =>
      alerts.any((a) => a.type == EcologicalAlertType.springFrostRisk);

  /// True if any alerts are active.
  bool get hasAlerts => alerts.isNotEmpty;
}

/// Synthesizes celestial rhythms with real-time and multi-horizon terrestrial weather data.
///
/// Implements the biodynamic principle "Astra inclinant, sed non necessitant":
/// The stars incline, they do not compel. Weather and soil conditions take
/// physical precedence over planting calendar windows.
abstract final class EcologicalSynthesis {
  /// Philosophical motto banner header.
  static const String bannerMotto = 'The Stars Incline, They Do Not Compel';

  static const int _maxCacheEntries = 512;

  static final Expando<
    (int, WeatherDataPoint, WeatherDataPoint, WeatherDataPoint, bool)
  >
  _sortedSeriesCache =
      Expando<
        (int, WeatherDataPoint, WeatherDataPoint, WeatherDataPoint, bool)
      >('EcologicalSynthesisSortedSeries');

  static final LinkedHashMap<Object, MultiHorizonWeatherAnalysis>
  _horizonCache = LinkedHashMap<Object, MultiHorizonWeatherAnalysis>();

  static final LinkedHashMap<Object, EcologicalSynthesisResult>
  _synthesisCache = LinkedHashMap<Object, EcologicalSynthesisResult>();

  static Object _seriesFingerprint(List<WeatherDataPoint> points) {
    final len = points.length;
    if (len == 0) return 0;
    if (len <= 32) return Object.hashAll(points);
    return (
      len,
      points.first,
      points.last,
      points[len >>> 1],
      points[len >>> 2],
      points[(len * 3) >>> 2],
    );
  }

  static bool _isSortedList(List<WeatherDataPoint> points) {
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
    if (_sortedSeriesCache[points] case final cached?
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
    _sortedSeriesCache[points] = (len, first, last, mid, sorted);
    return sorted;
  }

  /// Slices [points] to the window `[start, end]` inclusive in $O(\log N)$ time
  /// when [points] is sorted chronologically.
  static Iterable<WeatherDataPoint> _sliceHorizonWindow(
    List<WeatherDataPoint> points,
    DateTime start,
    DateTime end,
  ) {
    if (points.isEmpty || !_isSortedList(points)) {
      return points;
    }
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    int low = 0;
    int high = points.length;
    while (low < high) {
      final mid = (low + high) >>> 1;
      if (points[mid].time.millisecondsSinceEpoch < startMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final firstIdx = low;

    low = firstIdx;
    high = points.length;
    while (low < high) {
      final mid = (low + high) >>> 1;
      if (points[mid].time.millisecondsSinceEpoch <= endMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return points.getRange(firstIdx, low);
  }

  /// Resolves a [MultiHorizonWeatherAnalysis] for [referenceTime] using bounded
  /// LRU memoization and $O(\log N)$ binary search slicing when [weatherSeries]
  /// is a chronologically sorted [List].
  static MultiHorizonWeatherAnalysis? resolveHorizon({
    required DateTime referenceTime,
    Iterable<WeatherDataPoint>? weatherSeries,
    WeatherDataPoint? currentWeather,
    ClimateProfile? localProfile,
  }) {
    if (currentWeather == null && weatherSeries == null) {
      return null;
    }
    if (weatherSeries is List<WeatherDataPoint>) {
      final key = (
        identityHashCode(weatherSeries),
        _seriesFingerprint(weatherSeries),
        referenceTime.millisecondsSinceEpoch,
        referenceTime.isUtc,
        currentWeather,
        identityHashCode(localProfile),
      );
      final cached = _horizonCache.remove(key);
      if (cached != null) {
        _horizonCache[key] = cached;
        return cached;
      }

      final sliced = _sliceHorizonWindow(
        weatherSeries,
        referenceTime.subtract(const Duration(hours: 72)),
        referenceTime.add(const Duration(hours: 48)),
      );
      final computed = MultiHorizonWeatherAnalysis.analyze(
        referenceTime: referenceTime,
        weatherSeries: sliced,
        currentWeather: currentWeather,
        localProfile: localProfile,
      );
      if (_horizonCache.length >= _maxCacheEntries) {
        _horizonCache.remove(_horizonCache.keys.first);
      }
      _horizonCache[key] = computed;
      return computed;
    }

    return MultiHorizonWeatherAnalysis.analyze(
      referenceTime: referenceTime,
      weatherSeries: weatherSeries,
      currentWeather: currentWeather,
      localProfile: localProfile,
    );
  }

  /// Synthesizes [calendarInfo] with instantaneous [weather] and optional
  /// 72h-past / 48h-future [weatherSeries] (or precomputed [horizon]) at [time] and [latitude].
  static EcologicalSynthesisResult synthesize({
    required CalendarInfo calendarInfo,
    required DateTime time,
    WeatherDataPoint? weather,
    Iterable<WeatherDataPoint>? weatherSeries,
    MultiHorizonWeatherAnalysis? horizon,
    double latitude = DefaultLocations.copenhagenLatitude,
    SeasonAlignment? seasons,
  }) {
    final effectiveHorizon =
        horizon ??
        resolveHorizon(
          referenceTime: time,
          weatherSeries: weatherSeries,
          currentWeather: weather,
          localProfile: seasons?.localProfile,
        );

    final effectiveWeather = weather ?? effectiveHorizon?.currentPoint;
    if (effectiveWeather == null &&
        (effectiveHorizon == null || !effectiveHorizon.hasData)) {
      return const EcologicalSynthesisResult(
        alerts: [],
        bannerTitle: bannerMotto,
        bannerSubtitle: 'Awaiting terrestrial weather data. Observe physical soil moisture and local conditions.',
        hasConflicts: false,
      );
    }

    final alignment = seasons ?? HemisphereSeasonAlignment(latitude: latitude);
    final referenceMonth = alignment.referenceMonth(time);
    final cacheKey = (
      calendarInfo.quality,
      calendarInfo.isGrayDay,
      calendarInfo.isMoonAscending,
      calendarInfo.moonPhase.isWaxing,
      effectiveWeather,
      effectiveHorizon,
      referenceMonth,
      alignment.transferability,
    );
    final cachedResult = _synthesisCache.remove(cacheKey);
    if (cachedResult != null) {
      _synthesisCache[cacheKey] = cachedResult;
      return cachedResult;
    }

    final alerts = <EcologicalAlert>[];

    // 1. Waterlogged soil warning: instantaneous rain (> 2.0 mm) OR 48–72h antecedent saturation
    if (effectiveWeather != null && effectiveWeather.precipitation > 2.0) {
      final antecedentSuffix =
          (effectiveHorizon != null && effectiveHorizon.hasAntecedentHistory)
          ? ' (48h total: ${effectiveHorizon.precipitationLast48h.toStringAsFixed(1)} mm, API ${effectiveHorizon.antecedentPrecipitationIndex.toStringAsFixed(1)} mm)'
          : '';
      alerts.add(
        EcologicalAlert(
          type: EcologicalAlertType.waterlogging,
          severity: EcologicalAlertSeverity.critical,
          title: 'Soil Saturated: Waterlogging Warning',
          description:
              'Precipitation (${effectiveWeather.precipitation.toStringAsFixed(1)} mm)$antecedentSuffix has saturated soil pores.',
          practicalAdvice: 'Cease tillage, hoeing, and machinery traffic immediately. Cultivating wet soil destroys crumb structure and causes severe compaction.',
          preventsTillage: true,
        ),
      );
    } else if (effectiveHorizon != null && effectiveHorizon.isSoilSaturated) {
      alerts.add(
        EcologicalAlert(
          type: EcologicalAlertType.waterlogging,
          severity: EcologicalAlertSeverity.critical,
          title: 'Soil Saturated: Antecedent Rainfall (48–72h)',
          description:
              'Preceding rainfall (${effectiveHorizon.precipitationLast48h.toStringAsFixed(1)} mm in 48h, API ${effectiveHorizon.antecedentPrecipitationIndex.toStringAsFixed(1)} mm) leaves topsoil pores waterlogged even after rain has paused.',
          practicalAdvice: 'Hold off tillage, hoeing, and heavy foot traffic until topsoil drains to crumbly tilth. Working wet beds smears clay-humus aggregates into compaction pan.',
          preventsTillage: true,
        ),
      );
    }

    final temp = effectiveWeather?.temperature;

    // 2. Freezing ground conditions (air temp <= 0°C or frozen topsoil)
    if ((temp != null && temp <= 0.0) ||
        (effectiveHorizon != null && effectiveHorizon.isSoilFrozen)) {
      final displayTemp =
          temp ?? effectiveHorizon?.estimatedSoilTemperatureCelsius ?? 0.0;
      alerts.add(
        EcologicalAlert(
          type: EcologicalAlertType.freezing,
          severity: EcologicalAlertSeverity.critical,
          title: 'Freezing Conditions (<= 0°C)',
          description:
              'Temperature is ${displayTemp.toStringAsFixed(1)}°C (at or below freezing).',
          practicalAdvice: 'Postpone outdoor direct sowing. Start seedlings indoors in greenhouse trays or cold frames until ground thaws.',
          indoorSowingAdvised: true,
        ),
      );
    } else if (effectiveHorizon != null &&
        effectiveHorizon.hasAntecedentHistory &&
        effectiveHorizon.estimatedSoilTemperatureCelsius != null &&
        effectiveHorizon.estimatedSoilTemperatureCelsius! < 5.0) {
      // 2b. Thermally lagged cold topsoil (< 5°C) despite mild daytime air
      final soilTemp = effectiveHorizon.estimatedSoilTemperatureCelsius!;
      alerts.add(
        EcologicalAlert(
          type: EcologicalAlertType.coldSoil,
          severity: EcologicalAlertSeverity.warning,
          title:
              'Cold Topsoil (~${soilTemp.toStringAsFixed(1)}°C < 5°C Germination Minimum)',
          description:
              'Although air temperature is ${temp != null ? "${temp.toStringAsFixed(1)}°C" : "above freezing"}, 72-hour thermal lag keeps 5–10 cm topsoil at ~${soilTemp.toStringAsFixed(1)}°C.',
          practicalAdvice: 'Direct-sown seeds risk rotting in cold soil before germinating. Start seeds indoors or warm beds under fleece/cloches before sowing.',
          indoorSowingAdvised: true,
        ),
      );
    }

    // 3. High wind / spray drift (wind > 5.5 m/s)
    if (effectiveWeather != null && effectiveWeather.windSpeed > 5.5) {
      alerts.add(
        EcologicalAlert(
          type: EcologicalAlertType.highWind,
          severity: EcologicalAlertSeverity.warning,
          title: 'High Wind: Spray Drift Warning',
          description:
              'Wind speed (${effectiveWeather.windSpeed.toStringAsFixed(1)} m/s) exceeds the 5.5 m/s threshold for biodynamic field preparations.',
          practicalAdvice: 'Suspend foliar spraying of BD 501 Horn Silica and herbal teas to avoid spray drift and excessive droplet evaporation.',
          preventsSpray: true,
        ),
      );
    }

    // 4. Post-task spray wash-off lookahead (next 6–24h forecast rain)
    if (effectiveHorizon != null &&
        effectiveHorizon.hasForecastLookahead &&
        (effectiveWeather == null || effectiveWeather.precipitation <= 2.0) &&
        (effectiveHorizon.precipitationNext6h >= 1.5 ||
            effectiveHorizon.precipitationNext24h >= 6.0)) {
      alerts.add(
        EcologicalAlert(
          type: EcologicalAlertType.sprayWashoffRisk,
          severity: EcologicalAlertSeverity.warning,
          title:
              'Spray Wash-Off Risk (${effectiveHorizon.precipitationNext6h.toStringAsFixed(1)} mm in 6h • ${effectiveHorizon.precipitationNext24h.toStringAsFixed(1)} mm in 24h)',
          description: 'Upcoming rain within the next 6–24 hours risks washing biodynamic field preparations off foliage and topsoil before absorption.',
          practicalAdvice: 'Reschedule BD 500, BD 501, and BD 508 spraying to a window with at least 6 rain-free hours after application.',
          preventsSpray: true,
        ),
      );
    }

    // 5. Frost risk: instantaneous (< 2°C) OR 24–48h forecast lookahead (< 2°C)
    final isInstantFrost = temp != null && temp < 2.0;
    final isLookaheadFrost =
        !isInstantFrost &&
        effectiveHorizon != null &&
        effectiveHorizon.hasForecastLookahead &&
        effectiveHorizon.hasUpcomingFrost48h;

    if (isInstantFrost || isLookaheadFrost) {
      final isSpring =
          alignment.transferability !=
              CalendarTransferability.doesNotTransfer &&
          referenceMonth >= 3 &&
          referenceMonth <= 5;

      if (isInstantFrost) {
        final title = isSpring
            ? 'Spring Frost Risk (< 2°C)'
            : 'Frost Hazard (< 2°C)';
        final desc = isSpring
            ? 'Temperature dropped to ${temp.toStringAsFixed(1)}°C during active spring blossom and shoot development.'
            : 'Low temperature (${temp.toStringAsFixed(1)}°C) creates frost risk for tender plant organs.';

        alerts.add(
          EcologicalAlert(
            type: EcologicalAlertType.springFrostRisk,
            severity: EcologicalAlertSeverity.warning,
            title: title,
            description: desc,
            practicalAdvice: 'Spray BD 507 Valerian preparation in late evening. Valerian stimulates phosphorus and warmth forces, creating a protective thermal envelope around blossoms.',
            valerianSprayAdvised: true,
          ),
        );
      } else {
        final min48 = effectiveHorizon!.minTemperatureNext48h!;
        final title = isSpring
            ? 'Spring Frost Lookahead (${min48.toStringAsFixed(1)}°C within 48h)'
            : 'Upcoming Frost Risk (${min48.toStringAsFixed(1)}°C within 48h)';
        final desc =
            'Forecast drops to ${min48.toStringAsFixed(1)}°C within the next 24–48 hours despite milder current air.';

        alerts.add(
          EcologicalAlert(
            type: EcologicalAlertType.springFrostRisk,
            severity: EcologicalAlertSeverity.warning,
            title: title,
            description: desc,
            practicalAdvice: 'Hold off transplanting frost-tender seedlings, cover sensitive beds with fleece, and spray BD 507 Valerian preparation in the evening before the freeze.',
            valerianSprayAdvised: true,
          ),
        );
      }
    }

    final hasConflicts = alerts.any(
      (a) =>
          a.severity == EcologicalAlertSeverity.critical ||
          a.preventsTillage ||
          a.preventsSpray,
    );

    String subtitle;
    if (alerts.isEmpty) {
      subtitle = 'Cosmic rhythms and terrestrial weather are harmoniously aligned for field work.';
    } else if (hasConflicts) {
      subtitle = 'Cosmic rhythms are active, but physical weather overrides field operations. Respect soil and temperature limits.';
    } else {
      subtitle = 'Minor microclimate adjustments recommended. Adapt preparations and sowings accordingly.';
    }

    final result = EcologicalSynthesisResult(
      alerts: List<EcologicalAlert>.unmodifiable(alerts),
      bannerTitle: bannerMotto,
      bannerSubtitle: subtitle,
      hasConflicts: hasConflicts,
      horizon: effectiveHorizon,
    );
    if (_synthesisCache.length >= _maxCacheEntries) {
      _synthesisCache.remove(_synthesisCache.keys.first);
    }
    _synthesisCache[cacheKey] = result;
    return result;
  }
}
