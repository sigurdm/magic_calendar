/// Enum representing the diurnal breathing cycle phases of the Earth.
enum DiurnalPhase {
  /// Sunrise to solar noon minus 45 minutes. Earth exhales; sap rises.
  morningExhalation,

  /// Solar zenith pause (solar noon ± 45 minutes). Still point in transpiration.
  solarNoonStillness,

  /// Solar noon plus 45 minutes to sunset. Earth inhales; sap draws into roots.
  eveningInhalation,

  /// Sunset to sunrise. Subterranean consolidation and plant rest.
  nightRest,
}

/// Model representing the diurnal Earth rhythm information for a given timestamp.
final class DiurnalRhythmInfo {
  /// The current diurnal phase.
  final DiurnalPhase phase;

  /// Human-readable title for the phase.
  final String title;

  /// Description of the biological and cosmic breathing process.
  final String description;

  /// Recommended agricultural/gardening tasks during this phase.
  final List<String> optimalTasks;

  /// Tasks cautioned or discouraged during this phase.
  final List<String> cautionedTasks;

  /// Sunrise time, if available.
  final DateTime? sunrise;

  /// Sunset time, if available.
  final DateTime? sunset;

  /// Solar noon (zenith) time.
  final DateTime solarNoon;

  /// Creates a [DiurnalRhythmInfo].
  const DiurnalRhythmInfo({
    required this.phase,
    required this.title,
    required this.description,
    required this.optimalTasks,
    required this.cautionedTasks,
    this.sunrise,
    this.sunset,
    required this.solarNoon,
  });

  /// Computes [DiurnalRhythmInfo] for a given [time] using [sunrise], [sunset], and [solarNoon].
  factory DiurnalRhythmInfo.fromSunTimes({
    required DateTime time,
    DateTime? sunrise,
    DateTime? sunset,
    required DateTime solarNoon,
  }) {
    final effectiveSunrise =
        sunrise ?? solarNoon.subtract(const Duration(hours: 6));
    final effectiveSunset = sunset ?? solarNoon.add(const Duration(hours: 6));

    final noonStillnessStart = solarNoon.subtract(const Duration(minutes: 45));
    final noonStillnessEnd = solarNoon.add(const Duration(minutes: 45));

    final DiurnalPhase phase;
    if (time.isBefore(effectiveSunrise)) {
      phase = DiurnalPhase.nightRest;
    } else if (time.isBefore(noonStillnessStart)) {
      phase = DiurnalPhase.morningExhalation;
    } else if (time.isBefore(noonStillnessEnd)) {
      phase = DiurnalPhase.solarNoonStillness;
    } else if (time.isBefore(effectiveSunset)) {
      phase = DiurnalPhase.eveningInhalation;
    } else {
      phase = DiurnalPhase.nightRest;
    }

    switch (phase) {
      case DiurnalPhase.morningExhalation:
        return DiurnalRhythmInfo(
          phase: phase,
          title: "Morning Exhalation",
          description:
              "Vital forces stream upwards into foliage, flowers, and fruits. Earth breathes out.",
          optimalTasks: const [
            "Foliar spraying (BD 501 Horn Silica)",
            "Harvesting above-ground crops, flowers, and fruits for immediate vitality",
            "Shallow weed scalping and morning hoeing",
          ],
          cautionedTasks: const [
            "Root disturbance and deep soil cultivation",
            "Applying soil preparations (BD 500 / CPP)",
          ],
          sunrise: sunrise,
          sunset: sunset,
          solarNoon: solarNoon,
        );

      case DiurnalPhase.solarNoonStillness:
        return DiurnalRhythmInfo(
          phase: phase,
          title: "Solar Noon Stillness",
          description:
              "Solar zenith pause. Transpiration slows down; plant sap flow pauses at the still point.",
          optimalTasks: const [
            "Planning, observation, and tool maintenance",
            "Quiet farm walk and plant inspection",
            "Rest and record keeping",
          ],
          cautionedTasks: const [
            "Soil cultivation and mechanical tillage",
            "Foliar spraying in direct midday sun",
            "Transplanting delicate seedlings",
          ],
          sunrise: sunrise,
          sunset: sunset,
          solarNoon: solarNoon,
        );

      case DiurnalPhase.eveningInhalation:
        return DiurnalRhythmInfo(
          phase: phase,
          title: "Evening Inhalation",
          description:
              "Vitality contracts downward into the root zone and rhizosphere. Earth breathes in.",
          optimalTasks: const [
            "Seed sowing and seedling transplanting",
            "Soil cultivation and root aeration",
            "Soil spraying (BD 500 Horn Manure & Cow Pat Pit)",
            "Watering and root drenching",
          ],
          cautionedTasks: const [
            "Foliar spraying with light-stimulating preparations (BD 501)",
            "Harvesting crops intended for long-term storage or fresh crispness",
          ],
          sunrise: sunrise,
          sunset: sunset,
          solarNoon: solarNoon,
        );

      case DiurnalPhase.nightRest:
        return DiurnalRhythmInfo(
          phase: phase,
          title: "Night Rest",
          description:
              "Subterranean consolidation and quiet plant regeneration under stellar rhythms.",
          optimalTasks: const [
            "Compost maturation and microbial rhizosphere activity",
            "Uninterrupted cosmic and lunar absorption",
          ],
          cautionedTasks: const [
            "Field disturbance and mechanical tillage",
            "Foliar application of field preparations",
          ],
          sunrise: sunrise,
          sunset: sunset,
          solarNoon: solarNoon,
        );
    }
  }

  @override
  String toString() =>
      "DiurnalRhythmInfo(phase: $phase, title: $title, solarNoon: $solarNoon)";
}
