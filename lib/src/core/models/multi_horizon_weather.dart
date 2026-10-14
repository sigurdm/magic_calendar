import 'dart:math' as math;

import '../climate/climate_profile.dart';
import 'weather_data_point.dart';

/// Topsoil moisture and workability classification derived from both
/// instantaneous precipitation and the 48–72 hour antecedent rainfall history.
enum SoilMoistureStatus {
  /// Friable, crumbly topsoil with low residual pore water.
  dryOrCrumbly(
    displayName: 'Crumbly & Friable',
    danishName: 'Bekvem & Tør',
    shortLabel: 'Crumbly',
    preventsTillage: false,
    favorsSoilSpray: false,
  ),

  /// Moist, biologically active topsoil suitable for transplanting and soil sprays.
  moist(
    displayName: 'Moist & Workable',
    danishName: 'Fugtig & Arbejdsom',
    shortLabel: 'Moist',
    preventsTillage: false,
    favorsSoilSpray: true,
  ),

  /// Waterlogged topsoil where cultivation or machinery traffic smears aggregates.
  saturated(
    displayName: 'Saturated (Waterlogged)',
    danishName: 'Vandmættet',
    shortLabel: 'Saturated',
    preventsTillage: true,
    favorsSoilSpray: false,
  );

  /// English user-facing status label.
  final String displayName;

  /// Danish user-facing status label.
  final String danishName;

  /// Compact badge label for UI cards.
  final String shortLabel;

  /// Whether soil cultivation, hoeing, and bed preparation must be suspended.
  final bool preventsTillage;

  /// Whether soil moisture is ideal for absorbing BD 500 Horn Manure or CPP sprays.
  final bool favorsSoilSpray;

  const SoilMoistureStatus({
    required this.displayName,
    required this.danishName,
    required this.shortLabel,
    required this.preventsTillage,
    required this.favorsSoilSpray,
  });
}

/// Multi-horizon synthesis of antecedent soil moisture (past 48–72 hours),
/// thermally lagged topsoil temperature (5–10 cm depth), instantaneous weather,
/// and post-task forecast lookahead (next 6–48 hours).
final class MultiHorizonWeatherAnalysis {
  /// Target evaluation timestamp.
  final DateTime referenceTime;

  /// Closest hourly observation or forecast point within 6 hours of [referenceTime].
  final WeatherDataPoint? currentPoint;

  /// Cumulative precipitation (mm) during the 24 hours preceding [referenceTime].
  final double precipitationLast24h;

  /// Cumulative precipitation (mm) during the 48 hours preceding [referenceTime].
  final double precipitationLast48h;

  /// Cumulative precipitation (mm) during the 72 hours preceding [referenceTime].
  final double precipitationLast72h;

  /// Exponentially decayed 72-hour Antecedent Precipitation Index (API) in mm.
  ///
  /// Weights each hourly rainfall observation in `[referenceTime - 72h, referenceTime]`
  /// by $k^{\Delta t / 24}$, where the daily recession factor $k$ adjusts for
  /// temperature-driven evapotranspiration and wind drying.
  final double antecedentPrecipitationIndex;

  /// Topsoil workability classification combining instantaneous and 48–72h antecedent rain.
  final SoilMoistureStatus soilMoisture;

  /// Estimated topsoil temperature (°C at 5–10 cm depth), accounting for 72-hour
  /// thermal inertia, cloud-cover insolation, and optional 30-year climate normals.
  final double? estimatedSoilTemperatureCelsius;

  /// Cumulative forecast precipitation (mm) in the 6 hours following [referenceTime].
  final double precipitationNext6h;

  /// Cumulative forecast precipitation (mm) in the 24 hours following [referenceTime].
  final double precipitationNext24h;

  /// Cumulative forecast precipitation (mm) in the 48 hours following [referenceTime].
  final double precipitationNext48h;

  /// Peak wind speed (m/s) in the 6 hours following [referenceTime] (including [currentPoint]).
  final double maxWindSpeedNext6h;

  /// Minimum forecast 2m air temperature (°C) in the 24 hours following [referenceTime].
  final double? minTemperatureNext24h;

  /// Minimum forecast 2m air temperature (°C) in the 48 hours following [referenceTime].
  final double? minTemperatureNext48h;

  /// Maximum forecast 2m air temperature (°C) in the 24 hours following [referenceTime].
  final double? maxTemperatureNext24h;

  /// Number of distinct hourly observations in `[referenceTime - 72h, referenceTime]`.
  final int antecedentPointCount;

  /// Number of distinct hourly forecast points in `(referenceTime, referenceTime + 48h]`.
  final int lookaheadPointCount;

  /// Creates an immutable [MultiHorizonWeatherAnalysis].
  const MultiHorizonWeatherAnalysis({
    required this.referenceTime,
    required this.currentPoint,
    required this.precipitationLast24h,
    required this.precipitationLast48h,
    required this.precipitationLast72h,
    required this.antecedentPrecipitationIndex,
    required this.soilMoisture,
    required this.estimatedSoilTemperatureCelsius,
    required this.precipitationNext6h,
    required this.precipitationNext24h,
    required this.precipitationNext48h,
    required this.maxWindSpeedNext6h,
    required this.minTemperatureNext24h,
    required this.minTemperatureNext48h,
    required this.maxTemperatureNext24h,
    required this.antecedentPointCount,
    required this.lookaheadPointCount,
  });

  /// Whether any weather observation or forecast data was available around [referenceTime].
  bool get hasData =>
      currentPoint != null ||
      antecedentPointCount > 0 ||
      lookaheadPointCount > 0;

  /// Whether multiple antecedent observations were available prior to [referenceTime].
  bool get hasAntecedentHistory => antecedentPointCount > 1;

  /// Whether forecast points after [referenceTime] were available.
  bool get hasForecastLookahead => lookaheadPointCount > 0;

  /// Whether soil pores are saturated from either active rain or antecedent rainfall.
  bool get isSoilSaturated => soilMoisture == SoilMoistureStatus.saturated;

  /// Whether soil saturation is caused by prior 48–72h rainfall despite low current-hour rain.
  bool get isAntecedentWaterlogging =>
      isSoilSaturated &&
      (currentPoint == null || currentPoint!.precipitation <= 2.0);

  /// Whether topsoil or air temperature at [referenceTime] is at or below freezing (0 °C).
  bool get isSoilFrozen =>
      (estimatedSoilTemperatureCelsius != null &&
          estimatedSoilTemperatureCelsius! <= 0.0) ||
      (currentPoint?.temperature != null && currentPoint!.temperature! <= 0.0);

  /// Whether rain in the next 6–24 hours risks washing off biodynamic field sprays.
  bool get hasSprayWashoffRisk =>
      (currentPoint != null && currentPoint!.precipitation > 1.0) ||
      precipitationNext6h >= 1.5 ||
      precipitationNext24h >= 6.0;

  /// Whether rain in the next 6 hours risks washing foliar sprays (BD 501, BD 508) off leaves.
  bool get hasFoliarSprayWashoffRisk =>
      (currentPoint != null && currentPoint!.precipitation > 0.5) ||
      precipitationNext6h >= 1.0;

  /// Whether temperatures in the next 48 hours drop into the frost-hazard zone (< 2.0 °C).
  bool get hasUpcomingFrost48h =>
      minTemperatureNext48h != null && minTemperatureNext48h! < 2.0;

  /// Whether temperatures in the next 48 hours drop to or below freezing (<= 0.0 °C).
  bool get hasUpcomingHardFreeze48h =>
      minTemperatureNext48h != null && minTemperatureNext48h! <= 0.0;

  /// Whether rain in the next 24 hours risks wetting fresh pruning cuts and spreading canker spores.
  bool get hasPruningRainRisk24h =>
      (currentPoint != null && currentPoint!.precipitation > 2.0) ||
      precipitationNext24h >= 3.0;

  /// Whether [estimatedSoilTemperatureCelsius] meets or exceeds [minimumSoilTemperatureCelsius].
  ///
  /// Returns `true` if no temperature data is available.
  bool isSoilWarmEnoughFor(double minimumSoilTemperatureCelsius) {
    final effectiveTemp =
        estimatedSoilTemperatureCelsius ?? currentPoint?.temperature;
    if (effectiveTemp == null) return true;
    return effectiveTemp >= minimumSoilTemperatureCelsius;
  }

  /// Concise summary of topsoil temperature and 48–72h moisture state.
  String get soilSummary {
    final soilTempText = estimatedSoilTemperatureCelsius != null
        ? '${estimatedSoilTemperatureCelsius!.toStringAsFixed(1)}°C soil'
        : 'soil temp N/A';
    return '${soilMoisture.shortLabel} ($soilTempText, 48h rain ${precipitationLast48h.toStringAsFixed(1)} mm, API ${antecedentPrecipitationIndex.toStringAsFixed(1)} mm)';
  }

  /// Concise summary of 24h precipitation and 48h minimum temperature lookahead.
  String get lookaheadSummary {
    final min48Text = minTemperatureNext48h != null
        ? '48h min ${minTemperatureNext48h!.toStringAsFixed(1)}°C'
        : '48h min N/A';
    return 'Next 24h rain ${precipitationNext24h.toStringAsFixed(1)} mm • $min48Text';
  }

  /// Synthesizes a [MultiHorizonWeatherAnalysis] centered at [referenceTime]
  /// from [weatherSeries], an optional instantaneous [currentWeather] point,
  /// and an optional 30-year [localProfile].
  static MultiHorizonWeatherAnalysis analyze({
    required DateTime referenceTime,
    Iterable<WeatherDataPoint>? weatherSeries,
    WeatherDataPoint? currentWeather,
    ClimateProfile? localProfile,
  }) {
    // Deduplicate points by hour bucket around referenceTime within [-72h, +48h].
    final byHourBucket = <int, WeatherDataPoint>{};

    void addPoint(WeatherDataPoint point) {
      final diffMinutes = point.time.difference(referenceTime).inMinutes;
      if (diffMinutes < -72 * 60 || diffMinutes > 48 * 60) {
        return;
      }
      final hourBucket = (diffMinutes / 60.0).round();
      final existing = byHourBucket[hourBucket];
      if (existing == null) {
        byHourBucket[hourBucket] = point;
      } else {
        final existingTargetTime = referenceTime.add(
          Duration(hours: hourBucket),
        );
        if (point.time.difference(existingTargetTime).abs() <
            existing.time.difference(existingTargetTime).abs()) {
          byHourBucket[hourBucket] = point;
        }
      }
    }

    if (weatherSeries != null) {
      for (final point in weatherSeries) {
        addPoint(point);
      }
    }
    if (currentWeather != null) {
      addPoint(currentWeather);
    }

    // Resolve closest currentPoint within 6 hours of referenceTime.
    WeatherDataPoint? resolvedCurrent = currentWeather;
    if (resolvedCurrent == null) {
      Duration? minDiff;
      for (final point in byHourBucket.values) {
        final diff = point.time.difference(referenceTime).abs();
        if (diff <= const Duration(hours: 6) &&
            (minDiff == null || diff < minDiff)) {
          minDiff = diff;
          resolvedCurrent = point;
        }
      }
    }

    double precip24 = 0.0;
    double precip48 = 0.0;
    double precip72 = 0.0;
    double api = 0.0;
    int antecedentCount = 0;

    double weightedTempSum = 0.0;
    double tempWeightTotal = 0.0;
    double cloudSum = 0.0;
    int cloudCount = 0;
    double maxAntecedentSpanHours = 0.0;

    double precipNext6 = 0.0;
    double precipNext24 = 0.0;
    double precipNext48 = 0.0;
    double maxWindNext6 = resolvedCurrent?.windSpeed ?? 0.0;
    double? minTemp24 = resolvedCurrent?.temperature;
    double? minTemp48 = resolvedCurrent?.temperature;
    double? maxTemp24 = resolvedCurrent?.temperature;
    int lookaheadCount = 0;

    for (final entry in byHourBucket.entries) {
      final bucketHours = entry.key;
      final point = entry.value;

      if (bucketHours <= 0 && bucketHours >= -72) {
        antecedentCount++;
        final hoursAgo = -bucketHours.toDouble();
        if (hoursAgo > maxAntecedentSpanHours) {
          maxAntecedentSpanHours = hoursAgo;
        }

        if (hoursAgo <= 24.0) {
          precip24 += point.precipitation;
        }
        if (hoursAgo <= 48.0) {
          precip48 += point.precipitation;
        }
        precip72 += point.precipitation;

        // Daily recession factor k adjusted for evapotranspiration (temp & wind).
        final temp = point.temperature ?? 10.0;
        final k =
            (0.84 - 0.006 * (temp - 10.0) - 0.005 * (point.windSpeed - 3.0))
                .clamp(0.70, 0.94);
        final decayWeight = math.pow(k, hoursAgo / 24.0).toDouble();
        api += point.precipitation * decayWeight;

        if (point.temperature != null) {
          // 36-hour e-folding thermal inertia for 5-10cm topsoil.
          final thermalWeight = math.exp(-hoursAgo / 36.0);
          weightedTempSum += point.temperature! * thermalWeight;
          tempWeightTotal += thermalWeight;
        }
        if (hoursAgo <= 48.0) {
          cloudSum += point.cloudCover;
          cloudCount++;
        }
      }

      if (bucketHours > 0 && bucketHours <= 48) {
        lookaheadCount++;
        if (bucketHours <= 6) {
          precipNext6 += point.precipitation;
          if (point.windSpeed > maxWindNext6) {
            maxWindNext6 = point.windSpeed;
          }
        }
        if (bucketHours <= 24) {
          precipNext24 += point.precipitation;
          if (point.temperature case final t?) {
            if (minTemp24 == null || t < minTemp24) minTemp24 = t;
            if (maxTemp24 == null || t > maxTemp24) maxTemp24 = t;
          }
        }
        precipNext48 += point.precipitation;
        if (point.temperature case final t?) {
          if (minTemp48 == null || t < minTemp48) minTemp48 = t;
        }
      }
    }

    // Estimate 5-10cm topsoil temperature.
    double? estimatedSoilTemp;
    if (tempWeightTotal > 0.0) {
      double soilTemp = weightedTempSum / tempWeightTotal;
      // Apply clear-sky solar warming / heavy-cloud cooling when multi-hour history exists.
      if (maxAntecedentSpanHours >= 6.0 && cloudCount > 0 && soilTemp > 2.0) {
        final meanCloud = cloudSum / cloudCount;
        final insolationOffset = ((50.0 - meanCloud) / 100.0) * 0.8;
        soilTemp += insolationOffset;
      }
      // Blend with 30-year monthly climate normal to represent deeper subsoil thermal buffering.
      if (localProfile != null) {
        final monthlyNormal =
            localProfile.normals.temperature[referenceTime.month - 1];
        final normalWeight = maxAntecedentSpanHours >= 12.0 ? 0.15 : 0.25;
        soilTemp =
            soilTemp * (1.0 - normalWeight) + monthlyNormal * normalWeight;
      }
      estimatedSoilTemp = soilTemp;
    } else if (resolvedCurrent?.temperature != null) {
      final airTemp = resolvedCurrent!.temperature!;
      if (localProfile != null) {
        final monthlyNormal =
            localProfile.normals.temperature[referenceTime.month - 1];
        estimatedSoilTemp = airTemp * 0.75 + monthlyNormal * 0.25;
      } else {
        estimatedSoilTemp = airTemp;
      }
    }

    final currentRain = resolvedCurrent?.precipitation ?? 0.0;
    final SoilMoistureStatus moistureStatus;
    if (currentRain > 2.0 ||
        api >= 10.0 ||
        precip24 >= 10.0 ||
        precip48 >= 15.0) {
      moistureStatus = SoilMoistureStatus.saturated;
    } else if (currentRain > 0.5 || api >= 4.0 || precip48 >= 5.0) {
      moistureStatus = SoilMoistureStatus.moist;
    } else {
      moistureStatus = SoilMoistureStatus.dryOrCrumbly;
    }

    return MultiHorizonWeatherAnalysis(
      referenceTime: referenceTime,
      currentPoint: resolvedCurrent,
      precipitationLast24h: precip24,
      precipitationLast48h: precip48,
      precipitationLast72h: precip72,
      antecedentPrecipitationIndex: api,
      soilMoisture: moistureStatus,
      estimatedSoilTemperatureCelsius: estimatedSoilTemp,
      precipitationNext6h: precipNext6,
      precipitationNext24h: precipNext24,
      precipitationNext48h: precipNext48,
      maxWindSpeedNext6h: maxWindNext6,
      minTemperatureNext24h: minTemp24,
      minTemperatureNext48h: minTemp48,
      maxTemperatureNext24h: maxTemp24,
      antecedentPointCount: antecedentCount,
      lookaheadPointCount: lookaheadCount,
    );
  }
}
