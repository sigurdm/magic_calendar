import 'package:flutter/material.dart';

import '../biodynamic_prep.dart';
import '../dornach_boundaries.dart';
import '../models/models.dart';
import '../task_window_planner.dart';
import '../vegetable_database.dart';
import 'garden_profile.dart';

/// Categories of field actions recorded in the Biodynamic Field Journal.
enum FieldJournalAction {
  /// Direct or indoor seed sowing.
  sowSeeds('Sow Seeds', 'Sow', '🌱', Icons.grass_outlined),

  /// Transplanting seedlings or bare-root stock during Descending Moon (*Pflanzzeit*).
  transplant(
    'Transplant (Pflanzzeit)',
    'Transplant',
    '🪴',
    Icons.south_outlined,
  ),

  /// Taking softwood or hardwood cuttings.
  takeCuttings('Take Cuttings', 'Cuttings', '✂️', Icons.content_cut_outlined),

  /// Dividing perennial crowns, bulbs, or rhizomes.
  dividePerennials(
    'Divide Perennials',
    'Divide',
    '🌿',
    Icons.call_split_outlined,
  ),

  /// Scion or bud grafting on fruit trees and vines.
  graft('Graft', 'Graft', '🌳', Icons.call_merge_outlined),

  /// Pruning orchard trees, vines, or bushes.
  prune('Prune', 'Prune', '🪚', Icons.carpenter_outlined),

  /// Hoeing, weeding, or deep soil aeration.
  cultivateSoil(
    'Hoe & Cultivate Soil',
    'Cultivate',
    '⛏️',
    Icons.landscape_outlined,
  ),

  /// Stirring and spraying biodynamic preparations (BD 500, BD 501, CPP, BD 508).
  sprayPreparation('Spray Preparation', 'Spray', '🌀', Icons.cyclone_outlined),

  /// Harvesting crops for immediate fresh consumption.
  harvestFresh(
    'Harvest (Fresh)',
    'Harvest',
    '🧺',
    Icons.shopping_basket_outlined,
  ),

  /// Harvesting crops for long cellar storage or seed saving.
  harvestStorage('Harvest & Store', 'Store', '🏺', Icons.inventory_2_outlined),

  /// Inoculating compost (BD 502–507), mulching, or general field care.
  compostAndCare('Compost & Field Care', 'Compost', '♻️', Icons.eco_outlined);

  /// User-facing action label.
  final String displayName;

  /// Compact badge label for timeline markers and chips.
  final String shortLabel;

  /// Unicode glyph rendered inside timeline markers.
  final String timelineGlyph;

  /// Material icon representing the action in cards and modals.
  final IconData icon;

  const FieldJournalAction(
    this.displayName,
    this.shortLabel,
    this.timelineGlyph,
    this.icon,
  );

  /// Maps a [TaskActionType] from [TaskWindowPlanner] to a [FieldJournalAction].
  static FieldJournalAction fromTaskAction(TaskActionType action) =>
      switch (action) {
        TaskActionType.sowOutdoor ||
        TaskActionType.sowIndoor => FieldJournalAction.sowSeeds,
        TaskActionType.transplant => FieldJournalAction.transplant,
        TaskActionType.takeCuttings => FieldJournalAction.takeCuttings,
        TaskActionType.divide => FieldJournalAction.dividePerennials,
        TaskActionType.graft => FieldJournalAction.graft,
        TaskActionType.prune => FieldJournalAction.prune,
        TaskActionType.cultivateSoil => FieldJournalAction.cultivateSoil,
        TaskActionType.harvestStorage => FieldJournalAction.harvestStorage,
        TaskActionType.harvestFresh => FieldJournalAction.harvestFresh,
      };

  /// Maps an [AgriculturalTaskType] to a [FieldJournalAction].
  static FieldJournalAction fromAgriculturalTask(
    AgriculturalTaskType task,
  ) => switch (task) {
    AgriculturalTaskType.soilCultivation => FieldJournalAction.cultivateSoil,
    AgriculturalTaskType.pruning => FieldJournalAction.prune,
    AgriculturalTaskType.harvestStorage => FieldJournalAction.harvestStorage,
    AgriculturalTaskType.harvestFresh => FieldJournalAction.harvestFresh,
    AgriculturalTaskType.timberFelling => FieldJournalAction.prune,
    AgriculturalTaskType.peppering => FieldJournalAction.compostAndCare,
  };

  /// Maps a [BiodynamicPrepType] to a [FieldJournalAction].
  static FieldJournalAction fromPrepType(BiodynamicPrepType prep) =>
      switch (prep.category) {
        PrepCategory.fieldSpray => FieldJournalAction.sprayPreparation,
        PrepCategory.compostPrep => FieldJournalAction.compostAndCare,
      };
}

/// Immutable snapshot of the astronomical/biodynamic [CalendarInfo] at the moment a field action was logged.
final class FieldJournalCosmicSnapshot {
  /// Active sidereal plant organ quality ([PlantQuality]).
  final PlantQuality quality;

  /// Whether the timestamp fell within a Gray Day (lunar node, perigee, apogee, Saturn opposition, or eclipse).
  final bool isGrayDay;

  /// Whether a planetary trine or special cosmic aspect was active.
  final bool isSpecial;

  /// Whether the Moon was ascending in declination (rising sap).
  final bool isMoonAscending;

  /// Whether the Moon was descending in declination (*Pflanzzeit* / rooting impulse).
  bool get isMoonDescending => !isMoonAscending;

  /// Sidereal constellation of the Moon at the logged instant (e.g. `'Taurus'`), if known.
  final String moonConstellation;

  /// Illuminated fraction of the Moon (`0.0` to `1.0`).
  final double moonIllumination;

  /// Whether the synodic Moon phase was waxing toward Full Moon.
  final bool isWaxing;

  /// Optional diurnal Earth breathing phase label (e.g. `'Morning Exhalation'`).
  final String? diurnalPhaseName;

  /// Summary message from [CalendarInfo.message].
  final String summaryMessage;

  /// Creates a [FieldJournalCosmicSnapshot].
  ///
  /// The [moonIllumination] must be between `0.0` and `1.0`.
  FieldJournalCosmicSnapshot({
    required this.quality,
    required this.isGrayDay,
    this.isSpecial = false,
    required this.isMoonAscending,
    this.moonConstellation = '',
    this.moonIllumination = 0.5,
    this.isWaxing = true,
    this.diurnalPhaseName,
    this.summaryMessage = '',
  }) {
    if (!moonIllumination.isFinite ||
        moonIllumination < 0.0 ||
        moonIllumination > 1.0) {
      throw ArgumentError.value(
        moonIllumination,
        'moonIllumination',
        'Must be between 0.0 and 1.0',
      );
    }
  }

  /// Captures a [FieldJournalCosmicSnapshot] from an active [CalendarInfo].
  factory FieldJournalCosmicSnapshot.fromCalendarInfo(CalendarInfo info) {
    String constellation = '';
    for (final planet in info.planets) {
      if (planet.name.toLowerCase() == 'moon') {
        constellation = findBoundaryForLongitude(planet.longitude)?.name ?? '';
        break;
      }
    }
    return FieldJournalCosmicSnapshot(
      quality: info.quality,
      isGrayDay: info.isGrayDay,
      isSpecial: info.isSpecial,
      isMoonAscending: info.isMoonAscending,
      moonConstellation: constellation,
      moonIllumination: info.moonPhase.illuminatedFraction.clamp(0.0, 1.0),
      isWaxing: info.moonPhase.isWaxing,
      diurnalPhaseName: info.diurnalRhythm?.title,
      summaryMessage: info.message,
    );
  }

  /// Concise cosmic rhythm badge (e.g. `'Root · Descending (Pflanzzeit)'`).
  String get rhythmBadgeLabel {
    if (isGrayDay) {
      return 'Gray Day · ${isMoonDescending ? "Descending ↓" : "Ascending ↑"}';
    }
    final qualityText = quality == PlantQuality.none
        ? 'Neutral'
        : quality.displayName;
    final declText = isMoonDescending
        ? 'Descending ↓ (Pflanzzeit)'
        : 'Ascending ↑';
    return '$qualityText · $declText';
  }

  /// Concise lunar phase and constellation label (e.g. `'Taurus · 72% Waxing'`).
  String get moonBadgeLabel {
    final pct = '${(moonIllumination * 100).round()}%';
    final phaseDir = isWaxing ? 'Waxing' : 'Waning';
    if (moonConstellation.trim().isEmpty) {
      return 'Moon $pct $phaseDir';
    }
    return '${moonConstellation.trim()} · $pct $phaseDir';
  }

  /// Serializes this cosmic snapshot to a JSON map.
  Map<String, Object?> toJson() => {
    'quality': quality.name,
    'isGrayDay': isGrayDay,
    'isSpecial': isSpecial,
    'isMoonAscending': isMoonAscending,
    if (moonConstellation.isNotEmpty) 'moonConstellation': moonConstellation,
    'moonIllumination': moonIllumination,
    'isWaxing': isWaxing,
    if (diurnalPhaseName != null && diurnalPhaseName!.isNotEmpty)
      'diurnalPhaseName': diurnalPhaseName,
    if (summaryMessage.isNotEmpty) 'summaryMessage': summaryMessage,
  };

  /// Deserializes a [FieldJournalCosmicSnapshot] from [json].
  ///
  /// Throws a [FormatException] if required fields are missing or invalid.
  factory FieldJournalCosmicSnapshot.fromJson(Map<String, Object?> json) {
    final qualityRaw = json['quality'];
    if (qualityRaw is! String) {
      throw const FormatException(
        'FieldJournalCosmicSnapshot requires a quality string',
      );
    }
    PlantQuality? parsedQuality;
    for (final candidate in PlantQuality.values) {
      if (candidate.name == qualityRaw) {
        parsedQuality = candidate;
        break;
      }
    }
    if (parsedQuality == null) {
      throw FormatException('Unknown PlantQuality', qualityRaw);
    }

    final isGrayDay = json['isGrayDay'] == true;
    final isSpecial = json['isSpecial'] == true;
    final isMoonAscending = json['isMoonAscending'] == true;
    final moonConstellation = json['moonConstellation'] is String
        ? json['moonConstellation'] as String
        : '';
    final illumRaw = json['moonIllumination'];
    final moonIllumination = illumRaw is num
        ? illumRaw.toDouble().clamp(0.0, 1.0)
        : 0.5;
    final isWaxing = json['isWaxing'] != false;
    final diurnalPhaseName = json['diurnalPhaseName'] is String
        ? json['diurnalPhaseName'] as String
        : null;
    final summaryMessage = json['summaryMessage'] is String
        ? json['summaryMessage'] as String
        : '';

    return FieldJournalCosmicSnapshot(
      quality: parsedQuality,
      isGrayDay: isGrayDay,
      isSpecial: isSpecial,
      isMoonAscending: isMoonAscending,
      moonConstellation: moonConstellation,
      moonIllumination: moonIllumination,
      isWaxing: isWaxing,
      diurnalPhaseName: diurnalPhaseName,
      summaryMessage: summaryMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldJournalCosmicSnapshot &&
          quality == other.quality &&
          isGrayDay == other.isGrayDay &&
          isSpecial == other.isSpecial &&
          isMoonAscending == other.isMoonAscending &&
          moonConstellation == other.moonConstellation &&
          moonIllumination == other.moonIllumination &&
          isWaxing == other.isWaxing &&
          diurnalPhaseName == other.diurnalPhaseName &&
          summaryMessage == other.summaryMessage;

  @override
  int get hashCode => Object.hash(
    quality,
    isGrayDay,
    isSpecial,
    isMoonAscending,
    moonConstellation,
    moonIllumination,
    isWaxing,
    diurnalPhaseName,
    summaryMessage,
  );
}

/// Immutable snapshot of local weather and soil conditions at the moment a field action was logged.
final class FieldJournalWeatherSnapshot {
  /// Air temperature at 2m in degrees Celsius, if available.
  final double? temperatureCelsius;

  /// Root-zone soil temperature in degrees Celsius, if available.
  final double? soilTemperatureCelsius;

  /// Hourly precipitation in millimeters.
  final double precipitationMm;

  /// Wind speed in meters per second.
  final double windSpeedMs;

  /// Cloud cover percentage (`0.0` to `100.0`).
  final double cloudCoverPercent;

  /// Optional multi-horizon soil moisture label (e.g. `'Workable'`, `'Moist'`, `'Waterlogged'`).
  final String? soilMoistureLabel;

  /// Creates a [FieldJournalWeatherSnapshot].
  ///
  /// The [precipitationMm] and [windSpeedMs] must be non-negative.
  FieldJournalWeatherSnapshot({
    this.temperatureCelsius,
    this.soilTemperatureCelsius,
    this.precipitationMm = 0.0,
    this.windSpeedMs = 0.0,
    this.cloudCoverPercent = 0.0,
    this.soilMoistureLabel,
  }) {
    if (!precipitationMm.isFinite || precipitationMm < 0.0) {
      throw ArgumentError.value(
        precipitationMm,
        'precipitationMm',
        'Must be non-negative',
      );
    }
    if (!windSpeedMs.isFinite || windSpeedMs < 0.0) {
      throw ArgumentError.value(
        windSpeedMs,
        'windSpeedMs',
        'Must be non-negative',
      );
    }
  }

  /// Captures a [FieldJournalWeatherSnapshot] from a [WeatherDataPoint] and optional [horizon].
  factory FieldJournalWeatherSnapshot.fromWeather(
    WeatherDataPoint point, {
    MultiHorizonWeatherAnalysis? horizon,
  }) {
    return FieldJournalWeatherSnapshot(
      temperatureCelsius: point.temperature,
      soilTemperatureCelsius: horizon?.estimatedSoilTemperatureCelsius,
      precipitationMm: point.precipitation.clamp(0.0, double.infinity),
      windSpeedMs: point.windSpeed.clamp(0.0, double.infinity),
      cloudCoverPercent: point.cloudCover.clamp(0.0, 100.0),
      soilMoistureLabel: horizon?.soilMoisture.shortLabel,
    );
  }

  /// Compact one-line summary for journal cards.
  String get compactSummary {
    final parts = <String>[];
    if (temperatureCelsius != null) {
      parts.add('${temperatureCelsius!.toStringAsFixed(1)}°C');
    }
    if (soilTemperatureCelsius != null) {
      parts.add('Soil ${soilTemperatureCelsius!.toStringAsFixed(1)}°C');
    }
    parts.add('${precipitationMm.toStringAsFixed(1)}mm');
    parts.add('${windSpeedMs.toStringAsFixed(1)}m/s');
    if (soilMoistureLabel != null && soilMoistureLabel!.isNotEmpty) {
      parts.add(soilMoistureLabel!);
    }
    return parts.join(' · ');
  }

  /// Serializes this weather snapshot to a JSON map.
  Map<String, Object?> toJson() => {
    if (temperatureCelsius != null) 'temperatureCelsius': temperatureCelsius,
    if (soilTemperatureCelsius != null)
      'soilTemperatureCelsius': soilTemperatureCelsius,
    'precipitationMm': precipitationMm,
    'windSpeedMs': windSpeedMs,
    'cloudCoverPercent': cloudCoverPercent,
    if (soilMoistureLabel != null && soilMoistureLabel!.isNotEmpty)
      'soilMoistureLabel': soilMoistureLabel,
  };

  /// Deserializes a [FieldJournalWeatherSnapshot] from [json].
  factory FieldJournalWeatherSnapshot.fromJson(Map<String, Object?> json) {
    final tempRaw = json['temperatureCelsius'];
    final soilTempRaw = json['soilTemperatureCelsius'];
    final precipRaw = json['precipitationMm'];
    final windRaw = json['windSpeedMs'];
    final cloudRaw = json['cloudCoverPercent'];
    final moistureRaw = json['soilMoistureLabel'];

    return FieldJournalWeatherSnapshot(
      temperatureCelsius: tempRaw is num ? tempRaw.toDouble() : null,
      soilTemperatureCelsius: soilTempRaw is num
          ? soilTempRaw.toDouble()
          : null,
      precipitationMm: precipRaw is num
          ? precipRaw.toDouble().clamp(0.0, double.infinity)
          : 0.0,
      windSpeedMs: windRaw is num
          ? windRaw.toDouble().clamp(0.0, double.infinity)
          : 0.0,
      cloudCoverPercent: cloudRaw is num
          ? cloudRaw.toDouble().clamp(0.0, 100.0)
          : 0.0,
      soilMoistureLabel: moistureRaw is String ? moistureRaw : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldJournalWeatherSnapshot &&
          temperatureCelsius == other.temperatureCelsius &&
          soilTemperatureCelsius == other.soilTemperatureCelsius &&
          precipitationMm == other.precipitationMm &&
          windSpeedMs == other.windSpeedMs &&
          cloudCoverPercent == other.cloudCoverPercent &&
          soilMoistureLabel == other.soilMoistureLabel;

  @override
  int get hashCode => Object.hash(
    temperatureCelsius,
    soilTemperatureCelsius,
    precipitationMm,
    windSpeedMs,
    cloudCoverPercent,
    soilMoistureLabel,
  );
}

/// A comparative sowing, spraying, or harvesting entry in the Biodynamic Field Journal.
///
/// Captures what the gardener performed alongside a snapshot of the active
/// [CalendarInfo] ([cosmicSnapshot]) and local [WeatherDataPoint] ([weatherSnapshot]),
/// plus optional comparative trial outcome notes and rating.
final class FieldJournalEntry {
  /// Unique identifier for this journal entry.
  final String id;

  /// Timestamp of the logged garden action.
  final DateTime timestamp;

  /// Category of agricultural action performed.
  final FieldJournalAction action;

  /// Human-readable headline (e.g. `'Sow Carrot (Gulerod)'` or `'Spray BD 500 Horn Manure'`).
  final String title;

  /// Optional crop identifier in [VegetableDatabase].
  final String? cropId;

  /// Optional biodynamic preparation code (e.g. `'BD 500'`, `'BD 501'`, `'CPP'`).
  final String? prepCode;

  /// Target or active plant organ quality governing the entry's pigment color.
  final PlantQuality quality;

  /// Snapshot of the cosmic/biodynamic conditions at [timestamp].
  final FieldJournalCosmicSnapshot cosmicSnapshot;

  /// Optional snapshot of local weather and soil conditions at [timestamp].
  final FieldJournalWeatherSnapshot? weatherSnapshot;

  /// Optional saved location where the action took place.
  final SavedLocation? location;

  /// Field notes recorded at the time of logging (e.g. bed, seed lot, row count).
  final String notes;

  /// Follow-up comparative trial notes (e.g. germination days, vigor, cellar keeping quality).
  final String outcomeNote;

  /// Optional comparative trial rating from `1` (poor) to `5` (exceptional).
  final int? outcomeRating;

  /// Creates a [FieldJournalEntry].
  ///
  /// It is an error if [id] or [title] is empty, or if [outcomeRating] is non-null
  /// and outside `1..5`.
  FieldJournalEntry({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.title,
    required this.quality,
    required this.cosmicSnapshot,
    this.cropId,
    this.prepCode,
    this.weatherSnapshot,
    this.location,
    this.notes = '',
    this.outcomeNote = '',
    this.outcomeRating,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Must not be empty');
    }
    if (outcomeRating != null) {
      RangeError.checkValueInInterval(outcomeRating!, 1, 5, 'outcomeRating');
    }
  }

  /// Creates a [FieldJournalEntry] from live [CalendarInfo] and optional [WeatherDataPoint].
  factory FieldJournalEntry.fromLiveContext({
    String? id,
    required DateTime timestamp,
    required FieldJournalAction action,
    String? title,
    String? cropId,
    String? prepCode,
    PlantQuality? quality,
    required CalendarInfo calendarInfo,
    WeatherDataPoint? weather,
    MultiHorizonWeatherAnalysis? horizon,
    SavedLocation? location,
    String notes = '',
    String outcomeNote = '',
    int? outcomeRating,
  }) {
    final crop = cropId != null ? VegetableDatabase.findById(cropId) : null;
    final effectiveQuality = quality ?? crop?.quality ?? calendarInfo.quality;
    final resolvedTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : _buildDefaultTitle(
            action: action,
            crop: crop,
            prepCode: prepCode,
            quality: effectiveQuality,
          );
    final resolvedId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : 'journal_${timestamp.millisecondsSinceEpoch}_${action.name}_${cropId ?? prepCode ?? effectiveQuality.name}';

    return FieldJournalEntry(
      id: resolvedId,
      timestamp: timestamp,
      action: action,
      title: resolvedTitle,
      cropId: cropId,
      prepCode: prepCode,
      quality: effectiveQuality,
      cosmicSnapshot: FieldJournalCosmicSnapshot.fromCalendarInfo(calendarInfo),
      weatherSnapshot: weather != null
          ? FieldJournalWeatherSnapshot.fromWeather(weather, horizon: horizon)
          : null,
      location: location,
      notes: notes.trim(),
      outcomeNote: outcomeNote.trim(),
      outcomeRating: outcomeRating,
    );
  }

  static String _buildDefaultTitle({
    required FieldJournalAction action,
    required VegetableEntry? crop,
    required String? prepCode,
    required PlantQuality quality,
  }) {
    if (prepCode != null && prepCode.trim().isNotEmpty) {
      return '${action.shortLabel} ${prepCode.trim()}';
    }
    if (crop != null) {
      return '${action.shortLabel} ${crop.localizedDisplayName}';
    }
    if (quality != PlantQuality.none) {
      return '${action.displayName} (${quality.displayName})';
    }
    return action.displayName;
  }

  /// Resolved [VegetableEntry] from [VegetableDatabase], if [cropId] is set.
  VegetableEntry? get crop =>
      cropId == null ? null : VegetableDatabase.findById(cropId!);

  /// Unicode glyph for timeline markers.
  String get timelineMarkerGlyph => action.timelineGlyph;

  /// Short label displayed next to the marker on [InfiniteTimelinePainter] when zoomed in.
  String get timelineMarkerLabel {
    if (prepCode != null && prepCode!.trim().isNotEmpty) {
      return prepCode!.trim();
    }
    final resolvedCrop = crop;
    if (resolvedCrop != null) {
      return resolvedCrop.nameEn;
    }
    return action.shortLabel;
  }

  /// Whether the gardener has recorded a follow-up comparative outcome note or star rating.
  bool get hasOutcome => outcomeRating != null || outcomeNote.trim().isNotEmpty;

  /// Returns a copy of this entry with updated [notes], [outcomeNote], or [outcomeRating].
  FieldJournalEntry withOutcome({
    String? notes,
    String? outcomeNote,
    int? outcomeRating,
    bool clearRating = false,
  }) {
    return FieldJournalEntry(
      id: id,
      timestamp: timestamp,
      action: action,
      title: title,
      cropId: cropId,
      prepCode: prepCode,
      quality: quality,
      cosmicSnapshot: cosmicSnapshot,
      weatherSnapshot: weatherSnapshot,
      location: location,
      notes: notes ?? this.notes,
      outcomeNote: outcomeNote ?? this.outcomeNote,
      outcomeRating: clearRating ? null : (outcomeRating ?? this.outcomeRating),
    );
  }

  /// Serializes this entry to a JSON map.
  Map<String, Object?> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'action': action.name,
    'title': title,
    if (cropId != null && cropId!.isNotEmpty) 'cropId': cropId,
    if (prepCode != null && prepCode!.isNotEmpty) 'prepCode': prepCode,
    'quality': quality.name,
    'cosmicSnapshot': cosmicSnapshot.toJson(),
    if (weatherSnapshot != null) 'weatherSnapshot': weatherSnapshot!.toJson(),
    if (location != null) 'location': location!.toJson(),
    if (notes.isNotEmpty) 'notes': notes,
    if (outcomeNote.isNotEmpty) 'outcomeNote': outcomeNote,
    if (outcomeRating != null) 'outcomeRating': outcomeRating,
  };

  /// Deserializes a [FieldJournalEntry] from [json].
  ///
  /// Throws a [FormatException] if required fields are missing or invalid.
  factory FieldJournalEntry.fromJson(Map<String, Object?> json) {
    final idRaw = json['id'];
    final timestampRaw = json['timestamp'];
    final actionRaw = json['action'];
    final titleRaw = json['title'];
    final qualityRaw = json['quality'];
    final cosmicRaw = json['cosmicSnapshot'];

    if (idRaw is! String || idRaw.trim().isEmpty) {
      throw const FormatException('FieldJournalEntry requires a non-empty id');
    }
    if (timestampRaw is! String) {
      throw const FormatException(
        'FieldJournalEntry requires an ISO-8601 timestamp',
      );
    }
    final parsedTimestamp = DateTime.tryParse(timestampRaw);
    if (parsedTimestamp == null) {
      throw FormatException('Invalid timestamp', timestampRaw);
    }
    if (actionRaw is! String) {
      throw const FormatException('FieldJournalEntry requires an action name');
    }
    FieldJournalAction? parsedAction;
    for (final candidate in FieldJournalAction.values) {
      if (candidate.name == actionRaw) {
        parsedAction = candidate;
        break;
      }
    }
    if (parsedAction == null) {
      throw FormatException('Unknown FieldJournalAction', actionRaw);
    }

    if (titleRaw is! String || titleRaw.trim().isEmpty) {
      throw const FormatException('FieldJournalEntry requires a title');
    }
    if (qualityRaw is! String) {
      throw const FormatException('FieldJournalEntry requires a quality');
    }
    PlantQuality? parsedQuality;
    for (final candidate in PlantQuality.values) {
      if (candidate.name == qualityRaw) {
        parsedQuality = candidate;
        break;
      }
    }
    if (parsedQuality == null) {
      throw FormatException('Unknown PlantQuality', qualityRaw);
    }

    if (cosmicRaw is! Map<String, Object?>) {
      throw const FormatException(
        'FieldJournalEntry requires a cosmicSnapshot map',
      );
    }
    final cosmicSnapshot = FieldJournalCosmicSnapshot.fromJson(cosmicRaw);

    FieldJournalWeatherSnapshot? weatherSnapshot;
    if (json['weatherSnapshot'] case final Map<String, Object?> weatherRaw) {
      weatherSnapshot = FieldJournalWeatherSnapshot.fromJson(weatherRaw);
    }

    SavedLocation? location;
    if (json['location'] case final Map<String, Object?> locRaw) {
      try {
        location = SavedLocation.fromJson(locRaw);
      } on FormatException {
        location = null;
      }
    }

    final cropIdRaw = json['cropId'];
    final prepCodeRaw = json['prepCode'];
    final notesRaw = json['notes'];
    final outcomeNoteRaw = json['outcomeNote'];
    final ratingRaw = json['outcomeRating'];
    int? parsedRating;
    if (ratingRaw is int && ratingRaw >= 1 && ratingRaw <= 5) {
      parsedRating = ratingRaw;
    }

    return FieldJournalEntry(
      id: idRaw,
      timestamp: parsedTimestamp,
      action: parsedAction,
      title: titleRaw,
      cropId: cropIdRaw is String && cropIdRaw.isNotEmpty ? cropIdRaw : null,
      prepCode: prepCodeRaw is String && prepCodeRaw.isNotEmpty
          ? prepCodeRaw
          : null,
      quality: parsedQuality,
      cosmicSnapshot: cosmicSnapshot,
      weatherSnapshot: weatherSnapshot,
      location: location,
      notes: notesRaw is String ? notesRaw : '',
      outcomeNote: outcomeNoteRaw is String ? outcomeNoteRaw : '',
      outcomeRating: parsedRating,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldJournalEntry &&
          id == other.id &&
          timestamp == other.timestamp &&
          action == other.action &&
          title == other.title &&
          cropId == other.cropId &&
          prepCode == other.prepCode &&
          quality == other.quality &&
          cosmicSnapshot == other.cosmicSnapshot &&
          weatherSnapshot == other.weatherSnapshot &&
          location == other.location &&
          notes == other.notes &&
          outcomeNote == other.outcomeNote &&
          outcomeRating == other.outcomeRating;

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    action,
    title,
    cropId,
    prepCode,
    quality,
    cosmicSnapshot,
    weatherSnapshot,
    location,
    notes,
    outcomeNote,
    outcomeRating,
  );
}
