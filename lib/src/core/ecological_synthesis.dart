import 'models/models.dart';

/// Categories of weather alerts in ecological synthesis.
enum EcologicalAlertType {
  waterlogging,
  freezing,
  highWind,
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

  const EcologicalSynthesisResult({
    required this.alerts,
    required this.bannerTitle,
    required this.bannerSubtitle,
    required this.hasConflicts,
  });

  /// True if soil waterlogging is detected.
  bool get hasWaterlogging =>
      alerts.any((a) => a.type == EcologicalAlertType.waterlogging);

  /// True if freezing temperatures are detected.
  bool get isFreezing =>
      alerts.any((a) => a.type == EcologicalAlertType.freezing);

  /// True if high wind exceeds spray threshold.
  bool get hasHighWind =>
      alerts.any((a) => a.type == EcologicalAlertType.highWind);

  /// True if frost risk is present.
  bool get hasFrostRisk =>
      alerts.any((a) => a.type == EcologicalAlertType.springFrostRisk);

  /// True if any alerts are active.
  bool get hasAlerts => alerts.isNotEmpty;
}

/// Synthesizes celestial rhythms with real-time terrestrial weather data.
///
/// Implements the biodynamic principle "Astra inclinant, sed non necessitant":
/// The stars incline, they do not compel. Weather and soil conditions take
/// physical precedence over planting calendar windows.
abstract final class EcologicalSynthesis {
  /// Philosophical motto banner header.
  static const String bannerMotto = 'The Stars Incline, They Do Not Compel';

  /// Synthesizes [calendarInfo] with real-time [weather] at [time] and [latitude].
  static EcologicalSynthesisResult synthesize({
    required CalendarInfo calendarInfo,
    required DateTime time,
    WeatherDataPoint? weather,
    double latitude = 55.6761,
  }) {
    if (weather == null) {
      return const EcologicalSynthesisResult(
        alerts: [],
        bannerTitle: bannerMotto,
        bannerSubtitle: 'Awaiting terrestrial weather data. Observe physical soil moisture and local conditions.',
        hasConflicts: false,
      );
    }

    final alerts = <EcologicalAlert>[];

    // 1. Waterlogged soil warning (precipitation > 2.0 mm)
    if (weather.precipitation > 2.0) {
      alerts.add(
        EcologicalAlert(
          type: EcologicalAlertType.waterlogging,
          severity: EcologicalAlertSeverity.critical,
          title: 'Soil Saturated: Waterlogging Warning',
          description:
              'Precipitation (${weather.precipitation.toStringAsFixed(1)} mm) has saturated soil pores.',
          practicalAdvice: 'Cease tillage, hoeing, and machinery traffic immediately. Cultivating wet soil destroys crumb structure and causes severe compaction.',
          preventsTillage: true,
        ),
      );
    }

    // 2. Freezing ground conditions (temp <= 0°C)
    if (weather.temperature <= 0.0) {
      alerts.add(
        EcologicalAlert(
          type: EcologicalAlertType.freezing,
          severity: EcologicalAlertSeverity.critical,
          title: 'Freezing Conditions (<= 0°C)',
          description:
              'Air temperature is ${weather.temperature.toStringAsFixed(1)}°C (at or below freezing).',
          practicalAdvice: 'Postpone outdoor direct sowing. Start seedlings indoors in greenhouse trays or cold frames until ground thaws.',
          indoorSowingAdvised: true,
        ),
      );
    }

    // 3. High wind / spray drift (wind > 5.5 m/s)
    if (weather.windSpeed > 5.5) {
      alerts.add(
        EcologicalAlert(
          type: EcologicalAlertType.highWind,
          severity: EcologicalAlertSeverity.warning,
          title: 'High Wind: Spray Drift Warning',
          description:
              'Wind speed (${weather.windSpeed.toStringAsFixed(1)} m/s) exceeds the 5.5 m/s threshold for biodynamic field preparations.',
          practicalAdvice: 'Suspend foliar spraying of BD 501 Horn Silica and herbal teas to avoid spray drift and excessive droplet evaporation.',
          preventsSpray: true,
        ),
      );
    }

    // 4. Spring frost risk (< 2°C)
    if (weather.temperature < 2.0) {
      final isNorthern = latitude >= 0;
      final month = time.month;
      final isSpring = isNorthern
          ? (month >= 3 && month <= 5)
          : (month >= 9 && month <= 11);

      final title = isSpring
          ? 'Spring Frost Risk (< 2°C)'
          : 'Frost Hazard (< 2°C)';
      final desc = isSpring
          ? 'Temperature dropped to ${weather.temperature.toStringAsFixed(1)}°C during active spring blossom and shoot development.'
          : 'Low temperature (${weather.temperature.toStringAsFixed(1)}°C) creates frost risk for tender plant organs.';

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

    return EcologicalSynthesisResult(
      alerts: alerts,
      bannerTitle: bannerMotto,
      bannerSubtitle: subtitle,
      hasConflicts: hasConflicts,
    );
  }
}
