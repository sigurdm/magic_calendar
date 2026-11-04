import 'dart:collection';

import 'package:flutter/material.dart';

import 'algorithm.dart' as algo;
import 'climate/climate_profile.dart';
import 'climate/crop_climate_suitability.dart';
import 'climate/season_alignment.dart';
import 'ecological_synthesis.dart';
import 'models/models.dart';
import 'vegetable_database.dart';

export 'vegetable_database.dart' show CropTaskSchedule;

/// Garden and farm actions that can be scheduled for a specific plant or organ
/// within Maria Thun's biodynamic calendar framework.
enum TaskActionType {
  /// Direct outdoor seed sowing or tuber planting.
  sowOutdoor(
    displayName: 'Sow Outdoors',
    danishName: 'Direkte såning',
    icon: Icons.grass_outlined,
    requiresDescendingMoon: false,
    requiresAscendingMoon: false,
    prefersAfternoonInhalation: true,
    ruleSummary: 'Governed primarily by the sidereal Plant-Part Day (Root, Leaf, Flower, or Fruit). Not restricted by ascending/descending or waxing/waning Moon.',
  ),

  /// Indoor seed starting or greenhouse propagation.
  sowIndoor(
    displayName: 'Sow Indoors',
    danishName: 'Forkultivering',
    icon: Icons.home_work_outlined,
    requiresDescendingMoon: false,
    requiresAscendingMoon: false,
    prefersAfternoonInhalation: true,
    ruleSummary: 'Governed primarily by the sidereal Plant-Part Day in a protected greenhouse or cold frame, avoiding Gray Days.',
  ),

  /// Transplanting seedlings, dividing perennials, or planting bare-root stock.
  transplant(
    displayName: 'Transplant',
    danishName: 'Udplantning (Pflanzzeit)',
    icon: Icons.south_outlined,
    requiresDescendingMoon: true,
    requiresAscendingMoon: false,
    prefersAfternoonInhalation: true,
    ruleSummary: 'Requires a Descending Moon (Pflanzzeit) aligned with the plant\'s sidereal Plant-Part Day so sap and soil forces draw roots rapidly into the earth.',
  ),

  /// Dividing perennial crowns, rhizomes, or tubers and layering.
  divide(
    displayName: 'Divide Perennials',
    danishName: 'Deling af stauder',
    icon: Icons.call_split_outlined,
    requiresDescendingMoon: true,
    requiresAscendingMoon: false,
    prefersAfternoonInhalation: true,
    ruleSummary: 'Requires a Descending Moon (Pflanzzeit) aligned with the plant\'s sidereal Plant-Part Day so divided crowns and rhizomes anchor rapidly in the earth.',
  ),

  /// Taking hardwood, semi-ripe, or herbaceous cuttings and layering.
  takeCuttings(
    displayName: 'Take Cuttings',
    danishName: 'Stiklinger & Aflægning',
    icon: Icons.content_cut_outlined,
    requiresDescendingMoon: true,
    requiresAscendingMoon: false,
    prefersAfternoonInhalation: true,
    ruleSummary: 'Requires the plant\'s sidereal Plant-Part Day during a Descending Moon (Pflanzzeit) so vitality concentrates downward into basal callus and adventitious root formation.',
  ),

  /// Grafting scions or budding onto rootstock.
  graft(
    displayName: 'Graft Scions',
    danishName: 'Podning',
    icon: Icons.call_merge_outlined,
    requiresDescendingMoon: false,
    requiresAscendingMoon: true,
    prefersAfternoonInhalation: false,
    ruleSummary: 'Requires the plant\'s sidereal Plant-Part Day (typically Fruit or Flower) during an Ascending Moon so rising sap unites stock and scion.',
  ),

  /// Pruning fruit trees, grapevines, berry bushes, or roses.
  prune(
    displayName: 'Prune',
    danishName: 'Beskæring',
    icon: Icons.carpenter_outlined,
    requiresDescendingMoon: true,
    requiresAscendingMoon: false,
    prefersAfternoonInhalation: true,
    ruleSummary: 'Requires a Descending Moon aligned with the plant\'s sidereal Plant-Part Day so sap pressure recedes into the root zone and cuts heal without bleeding.',
  ),

  /// Hoeing and cultivating beds to stimulate elemental impulses in the soil.
  cultivateSoil(
    displayName: 'Hoe & Cultivate',
    danishName: 'Hakning & Jordpleje',
    icon: Icons.landscape_outlined,
    requiresDescendingMoon: false,
    requiresAscendingMoon: false,
    prefersAfternoonInhalation: true,
    ruleSummary: 'Hoeing a crop bed on its matching sidereal Plant-Part Day (especially during a Descending Moon afternoon) transmits that element\'s impulse into the root zone.',
  ),

  /// Harvesting crops, roots, fruits, or herbs for cellar storage or drying.
  harvestStorage(
    displayName: 'Harvest (Storage / Dry)',
    danishName: 'Høst til lagring & tørring',
    icon: Icons.inventory_2_outlined,
    requiresDescendingMoon: false,
    requiresAscendingMoon: false,
    prefersAfternoonInhalation: false,
    ruleSummary: 'Root crops & medicinal roots require a Root Day + Descending Moon; above-ground fruits, seeds, and flowers require their matching Plant-Part Day + Ascending Moon.',
  ),

  /// Harvesting crops for immediate fresh consumption.
  harvestFresh(
    displayName: 'Harvest (Fresh Table)',
    danishName: 'Frisk høst',
    icon: Icons.restaurant_outlined,
    requiresDescendingMoon: false,
    requiresAscendingMoon: false,
    prefersAfternoonInhalation: false,
    ruleSummary: 'Best during Morning Exhalation on the crop\'s matching Plant-Part Day (with Ascending Moon for above-ground organs or Descending Moon for roots).',
  );

  /// English user-facing action label.
  final String displayName;

  /// Danish user-facing action label.
  final String danishName;

  /// Icon representing this action in the UI.
  final IconData icon;

  /// Whether this action requires a Descending Moon (*Pflanzzeit*) for optimal results.
  final bool requiresDescendingMoon;

  /// Whether this action requires an Ascending Moon for optimal results.
  final bool requiresAscendingMoon;

  /// Whether afternoon/evening Earth inhalation (15:00–19:00) is the preferred diurnal window.
  final bool prefersAfternoonInhalation;

  /// Concise summary of Maria Thun's biodynamic rule for this action.
  final String ruleSummary;

  const TaskActionType({
    required this.displayName,
    required this.danishName,
    required this.icon,
    required this.requiresDescendingMoon,
    required this.requiresAscendingMoon,
    required this.prefersAfternoonInhalation,
    required this.ruleSummary,
  });

  /// Whether this action requires a Descending Moon for the given [targetQuality].
  bool requiresDescendingFor(PlantQuality targetQuality) {
    if (this == TaskActionType.harvestStorage ||
        this == TaskActionType.harvestFresh) {
      return targetQuality == PlantQuality.root;
    }
    return requiresDescendingMoon;
  }

  /// Whether this action requires an Ascending Moon for the given [targetQuality].
  bool requiresAscendingFor(PlantQuality targetQuality) {
    if (this == TaskActionType.harvestStorage ||
        this == TaskActionType.harvestFresh) {
      return targetQuality != PlantQuality.root &&
          targetQuality != PlantQuality.none;
    }
    return requiresAscendingMoon;
  }

  /// Whether afternoon Earth inhalation (15:00–19:00) is preferred for [targetQuality].
  bool prefersAfternoonFor(PlantQuality targetQuality) {
    if (this == TaskActionType.harvestStorage) {
      return targetQuality == PlantQuality.root;
    }
    if (this == TaskActionType.harvestFresh) {
      return false;
    }
    return prefersAfternoonInhalation;
  }

  /// Returns the [SeasonalAnchor] governing seasonal timing of this action for [crop].
  SeasonalAnchor seasonalAnchorFor(VegetableEntry? crop) => switch (this) {
    TaskActionType.prune ||
    TaskActionType.takeCuttings ||
    TaskActionType.graft => SeasonalAnchor.dormancy,
    TaskActionType.harvestStorage ||
    TaskActionType.harvestFresh => SeasonalAnchor.thermal,
    TaskActionType.sowOutdoor ||
    TaskActionType.sowIndoor ||
    TaskActionType.transplant ||
    TaskActionType.divide ||
    TaskActionType.cultivateSoil =>
      (crop?.isFrostTender ?? false)
          ? SeasonalAnchor.frostTender
          : SeasonalAnchor.thermal,
  };

  /// Returns the Northern Hemisphere seasonal months configured on [crop] for this action.
  List<int> seasonalMonthsForCrop(VegetableEntry crop) {
    switch (this) {
      case TaskActionType.sowOutdoor:
      case TaskActionType.cultivateSoil:
        return crop.sowingMonths;
      case TaskActionType.sowIndoor:
        return crop.indoorSowingMonths.isNotEmpty
            ? crop.indoorSowingMonths
            : crop.sowingMonths;
      case TaskActionType.transplant:
        return crop.transplantMonths.isNotEmpty
            ? crop.transplantMonths
            : crop.sowingMonths;
      case TaskActionType.divide:
        if (crop.divisionMonths.isNotEmpty) return crop.divisionMonths;
        if (crop.transplantMonths.isNotEmpty) return crop.transplantMonths;
        if (crop.cuttingMonths.isNotEmpty) return crop.cuttingMonths;
        return crop.sowingMonths;
      case TaskActionType.takeCuttings:
        if (crop.cuttingMonths.isNotEmpty) return crop.cuttingMonths;
        if (crop.transplantMonths.isNotEmpty) return crop.transplantMonths;
        return crop.sowingMonths;
      case TaskActionType.graft:
        if (crop.graftingMonths.isNotEmpty) return crop.graftingMonths;
        if (crop.cuttingMonths.isNotEmpty) return crop.cuttingMonths;
        if (crop.transplantMonths.isNotEmpty) return crop.transplantMonths;
        return crop.sowingMonths;
      case TaskActionType.prune:
        if (crop.pruningMonths.isNotEmpty) return crop.pruningMonths;
        return const [1, 2, 3, 7, 8, 11, 12];
      case TaskActionType.harvestStorage:
      case TaskActionType.harvestFresh:
        return crop.harvestMonths;
    }
  }
}

/// Curated quick-select preset combining a [TaskActionType] with a specific crop or organ.
final class QuickTaskPreset {
  /// Short label shown on the preset chip.
  final String label;

  /// Subtitle or Danish translation.
  final String subtitle;

  /// The action to perform.
  final TaskActionType action;

  /// Identifier of the target crop in [VegetableDatabase], or null for a general organ preset.
  final String? cropId;

  /// Fallback organ quality when [cropId] is null.
  final PlantQuality quality;

  /// Creates an immutable [QuickTaskPreset].
  const QuickTaskPreset({
    required this.label,
    required this.subtitle,
    required this.action,
    this.cropId,
    required this.quality,
  });
}

/// A contiguous upcoming time window suitable for a requested biodynamic task.
final class TaskWindow {
  /// Start of the favorable window.
  final DateTime start;

  /// End of the favorable window.
  final DateTime end;

  /// Recommended peak hour within [start]..[end] to jump the timeline to.
  final DateTime peakTime;

  /// Suitability rating ([TaskSuitability.optimal] or [TaskSuitability.favorable]).
  final TaskSuitability suitability;

  /// Active sidereal plant organ quality during this window.
  final PlantQuality quality;

  /// Whether the Moon is descending (*Pflanzzeit*) at [peakTime].
  final bool isDescending;

  /// Whether the Moon is waxing at [peakTime].
  final bool isWaxing;

  /// Whether a special same-element planetary trine is active at [peakTime].
  final bool isSpecialTrine;

  /// Whether [peakTime] falls within the selected crop's seasonal month window.
  final bool isInSeason;

  /// Concise summary of the active cosmic factors.
  final String headline;

  /// Explanation of why this window matches Maria Thun's hierarchy and which time of day is best.
  final String cosmicExplanation;

  /// Optional weather synthesis note when forecast data covers this window.
  final String? weatherNote;

  /// Whether forecast weather conflicts with performing the task in this window.
  final bool hasWeatherConflict;

  /// Optional climatological suitability or frost/thermal risk note for [peakTime].
  final String? climateNote;

  /// Whether normal climatology at [peakTime] poses a frost, cold-soil, or heat-bolt risk.
  final bool hasClimateRisk;

  /// Optional multi-horizon soil moisture, soil temperature, and forecast lookahead analysis at [peakTime].
  final MultiHorizonWeatherAnalysis? weatherHorizon;

  /// Creates an immutable [TaskWindow].
  const TaskWindow({
    required this.start,
    required this.end,
    required this.peakTime,
    required this.suitability,
    required this.quality,
    required this.isDescending,
    required this.isWaxing,
    required this.isSpecialTrine,
    required this.isInSeason,
    required this.headline,
    required this.cosmicExplanation,
    this.weatherNote,
    this.hasWeatherConflict = false,
    this.climateNote,
    this.hasClimateRisk = false,
    this.weatherHorizon,
  });

  /// Duration of the window.
  Duration get duration => end.difference(start);
}

/// Complete search result returned by [TaskWindowPlanner.findUpcomingWindows].
final class TaskWindowSearchResult {
  /// The evaluated action.
  final TaskActionType action;

  /// The target plant organ quality.
  final PlantQuality targetQuality;

  /// The optional specific crop entry.
  final VegetableEntry? crop;

  /// The active secondary organ schedule when a multi-organ override is applied.
  final CropTaskSchedule? activeOrganRule;

  /// The starting reference time of the search.
  final DateTime searchStart;

  /// Upcoming optimal and favorable windows ordered chronologically.
  final List<TaskWindow> windows;

  /// Hemisphere-adjusted calendar months (1-12) considered in-season for this task.
  final List<int> seasonalMonths;

  /// Whether [searchStart] is currently within [seasonalMonths] (or true when no crop restriction applies).
  final bool isCurrentlyInSeason;

  /// Start date of the next prime seasonal window when [isCurrentlyInSeason] is false.
  final DateTime? nextSeasonalStartDate;

  /// Maria Thun rule explanation customized for [action], [targetQuality], and [crop].
  final String ruleExplanation;

  /// Per-crop climate suitability evaluation when both [crop] and a local [ClimateProfile] are active.
  final CropClimateEvaluation? cropClimate;

  /// Summary of local climatological frost or thermal growing season dates when a local [ClimateProfile] is active.
  final String? localSeasonSummary;

  /// Creates an immutable [TaskWindowSearchResult].
  TaskWindowSearchResult({
    required this.action,
    required this.targetQuality,
    required this.crop,
    this.activeOrganRule,
    required this.searchStart,
    required List<TaskWindow> windows,
    required List<int> seasonalMonths,
    required this.isCurrentlyInSeason,
    required this.nextSeasonalStartDate,
    required this.ruleExplanation,
    this.cropClimate,
    this.localSeasonSummary,
  }) : windows = List.unmodifiable(windows),
       seasonalMonths = List.unmodifiable(seasonalMonths);
}

/// Planner engine that searches forward in time for optimal biodynamic task windows
/// according to Maria Thun's factor hierarchy.
abstract final class TaskWindowPlanner {
  static const int _maxSearchCacheEntries = 128;

  static final LinkedHashMap<Object, TaskWindowSearchResult> _searchCache =
      LinkedHashMap<Object, TaskWindowSearchResult>();

  /// Curated quick-select presets covering common garden, vineyard, orchard, and herb tasks.
  static const List<QuickTaskPreset> presets = [
    QuickTaskPreset(
      label: 'Take Grape Cuttings',
      subtitle: 'Vindrue stiklinger • Fruit + Descending',
      action: TaskActionType.takeCuttings,
      cropId: 'grapevine',
      quality: PlantQuality.fruit,
    ),
    QuickTaskPreset(
      label: 'Sow Lettuce',
      subtitle: 'Så hovedsalat • Leaf Day',
      action: TaskActionType.sowOutdoor,
      cropId: 'lettuce',
      quality: PlantQuality.leaf,
    ),
    QuickTaskPreset(
      label: 'Harvest Marshmallow Root',
      subtitle: 'Lægestokrose rod • Root + Descending',
      action: TaskActionType.harvestStorage,
      cropId: 'marshmallow_root',
      quality: PlantQuality.root,
    ),
    QuickTaskPreset(
      label: 'Transplant Tomatoes',
      subtitle: 'Udplant tomat • Fruit + Descending',
      action: TaskActionType.transplant,
      cropId: 'tomato',
      quality: PlantQuality.fruit,
    ),
    QuickTaskPreset(
      label: 'Sow Carrots',
      subtitle: 'Så gulerod • Root Day',
      action: TaskActionType.sowOutdoor,
      cropId: 'carrot',
      quality: PlantQuality.root,
    ),
    QuickTaskPreset(
      label: 'Prune Fruit Trees & Vines',
      subtitle: 'Beskæring • Fruit + Descending',
      action: TaskActionType.prune,
      cropId: 'apple_tree',
      quality: PlantQuality.fruit,
    ),
    QuickTaskPreset(
      label: 'Take Rose Cuttings',
      subtitle: 'Rosenstiklinger • Flower + Descending',
      action: TaskActionType.takeCuttings,
      cropId: 'rose',
      quality: PlantQuality.flower,
    ),
  ];

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

  /// Searches forward from [startTime] over [searchDays] to find up to [maxWindows]
  /// optimal or favorable windows for [action] on [crop] or [targetQuality].
  ///
  /// When [organRule] is provided, or when [crop] defines a secondary organ rule
  /// matching [targetQuality], the search evaluates that secondary organ's
  /// [PlantQuality] and seasonal months.
  ///
  /// The [searchDays] and [maxWindows] must be positive.
  static TaskWindowSearchResult findUpcomingWindows({
    required TaskActionType action,
    required PlantQuality targetQuality,
    VegetableEntry? crop,
    CropTaskSchedule? organRule,
    required DateTime startTime,
    required EphemerisService ephemeris,
    List<WeatherDataPoint>? weatherForecast,
    double latitude = DefaultLocations.copenhagenLatitude,
    double longitude = DefaultLocations.copenhagenLongitude,
    SeasonAlignment? seasons,
    int searchDays = 30,
    int maxWindows = 8,
  }) {
    RangeError.checkValidRange(1, null, searchDays, 'searchDays');
    RangeError.checkValidRange(1, null, maxWindows, 'maxWindows');

    final alignment = seasons ?? HemisphereSeasonAlignment(latitude: latitude);
    final localProfile = alignment.localProfile;
    final locVersion = algo.ephemerisLocationVersion(ephemeris);

    final cacheKey = locVersion == null
        ? null
        : (
            action,
            targetQuality,
            crop?.id,
            organRule?.id,
            organRule?.localizedLabel,
            organRule?.quality,
            Object.hashAll(organRule?.months ?? const <int>[]),
            organRule?.noteEn,
            startTime.millisecondsSinceEpoch,
            startTime.isUtc,
            identityHashCode(ephemeris),
            locVersion,
            _weatherCacheKey(weatherForecast),
            (latitude * 1000).round(),
            (longitude * 1000).round(),
            identityHashCode(localProfile),
            alignment.hasNorthernSeasons,
            alignment.transferability,
            alignment.shortLabel,
            searchDays,
            maxWindows,
          );
    if (cacheKey != null) {
      final cachedResult = _searchCache.remove(cacheKey);
      if (cachedResult != null) {
        _searchCache[cacheKey] = cachedResult;
        return cachedResult;
      }
    }

    final CropTaskSchedule? activeOrganRule =
        organRule ??
        (crop != null &&
                targetQuality != PlantQuality.none &&
                targetQuality != crop.quality
            ? crop.findOrganRule(targetQuality)
            : null);

    final effectiveQuality =
        activeOrganRule?.quality ??
        (crop != null &&
                targetQuality != PlantQuality.none &&
                crop.supportsQuality(targetQuality)
            ? targetQuality
            : crop?.quality) ??
        (targetQuality == PlantQuality.none
            ? PlantQuality.leaf
            : targetQuality);

    final cropClimate = (crop != null && localProfile != null)
        ? CropClimateEvaluation.evaluate(crop, localProfile)
        : null;
    final anchor = action.seasonalAnchorFor(crop);
    final localSeasonSummary = localProfile == null
        ? null
        : _buildLocalSeasonSummary(localProfile, anchor: anchor);
    final List<int> rawSeasonalMonths;
    if (alignment.transferability == CalendarTransferability.doesNotTransfer) {
      rawSeasonalMonths = const <int>[];
    } else if (activeOrganRule != null && activeOrganRule.months.isNotEmpty) {
      rawSeasonalMonths = activeOrganRule.months;
    } else if (crop != null) {
      rawSeasonalMonths = action.seasonalMonthsForCrop(crop);
    } else {
      rawSeasonalMonths = const <int>[];
    }
    final localSeasonalMonths = alignment.localMonthsFor(
      rawSeasonalMonths,
      anchor: anchor,
    );

    final daySeasonCache = <(int, int, int), bool>{};
    bool isDateInSeason(DateTime time) {
      if (rawSeasonalMonths.isEmpty) return true;
      final dayKey = (time.year, time.month, time.day);
      return daySeasonCache[dayKey] ??= rawSeasonalMonths.contains(
        alignment.referenceMonth(time, anchor: anchor),
      );
    }

    final isCurrentlyInSeason = isDateInSeason(startTime);

    final DateTime? nextSeasonalStartDate = isCurrentlyInSeason
        ? null
        : _computeNextSeasonalDate(startTime, isDateInSeason);

    final ruleExplanation = _buildRuleExplanation(
      action: action,
      quality: effectiveQuality,
      crop: crop,
      activeOrganRule: activeOrganRule,
    );

    // Step in 2-hour increments across [startTime, startTime + searchDays].
    const step = Duration(hours: 2);
    final endLimit = startTime.add(Duration(days: searchDays));

    final windows = <TaskWindow>[];
    DateTime? activeStart;
    DateTime? activeLastMatch;
    TaskSuitability activeBestSuitability = TaskSuitability.neutral;
    bool activeHasDescending = false;
    bool activeHasAscending = false;
    bool activeIsWaxing = false;
    bool activeHasSpecialTrine = false;

    DateTime cursor = startTime.isUtc
        ? DateTime.utc(
            startTime.year,
            startTime.month,
            startTime.day,
            startTime.hour,
          )
        : DateTime(
            startTime.year,
            startTime.month,
            startTime.day,
            startTime.hour,
          );

    while (cursor.isBefore(endLimit) && windows.length < maxWindows) {
      final info = algo.getCalendarInfo(
        cursor,
        ephemeris,
        includePlanets: true,
        latitude: latitude,
        longitude: longitude,
      );

      final eval = _evaluateInstant(
        action: action,
        targetQuality: effectiveQuality,
        info: info,
      );

      if (eval != null) {
        if (activeStart == null) {
          activeStart = cursor;
          activeBestSuitability = eval;
          activeHasDescending = info.isMoonDescending;
          activeHasAscending = info.isMoonAscending;
          activeIsWaxing = info.moonPhase.isWaxing;
          activeHasSpecialTrine = info.isSpecial;
        } else {
          if (eval == TaskSuitability.optimal) {
            activeBestSuitability = TaskSuitability.optimal;
          }
          if (info.isMoonDescending) activeHasDescending = true;
          if (info.isMoonAscending) activeHasAscending = true;
          if (info.isSpecial) activeHasSpecialTrine = true;
        }
        activeLastMatch = cursor;
      } else if (activeStart != null && activeLastMatch != null) {
        final windowEnd = activeLastMatch.add(step);
        if (windowEnd.difference(activeStart).inHours >= 2) {
          windows.add(
            _finalizeWindow(
              action: action,
              targetQuality: effectiveQuality,
              crop: crop,
              start: activeStart,
              end: windowEnd,
              suitability: activeBestSuitability,
              hasDescending: activeHasDescending,
              hasAscending: activeHasAscending,
              isWaxing: activeIsWaxing,
              isSpecialTrine: activeHasSpecialTrine,
              isDateInSeason: isDateInSeason,
              weatherForecast: weatherForecast,
              localProfile: localProfile,
              cropClimate: cropClimate,
            ),
          );
        }
        activeStart = null;
        activeLastMatch = null;
      }

      cursor = cursor.add(step);
    }

    if (activeStart != null &&
        activeLastMatch != null &&
        windows.length < maxWindows) {
      final windowEnd = activeLastMatch.add(step);
      if (windowEnd.difference(activeStart).inHours >= 2) {
        windows.add(
          _finalizeWindow(
            action: action,
            targetQuality: effectiveQuality,
            crop: crop,
            start: activeStart,
            end: windowEnd,
            suitability: activeBestSuitability,
            hasDescending: activeHasDescending,
            hasAscending: activeHasAscending,
            isWaxing: activeIsWaxing,
            isSpecialTrine: activeHasSpecialTrine,
            isDateInSeason: isDateInSeason,
            weatherForecast: weatherForecast,
            localProfile: localProfile,
            cropClimate: cropClimate,
          ),
        );
      }
    }

    // Windows are collected and returned in chronological order.
    final result = TaskWindowSearchResult(
      action: action,
      targetQuality: effectiveQuality,
      crop: crop,
      activeOrganRule: activeOrganRule,
      searchStart: startTime,
      windows: windows,
      seasonalMonths: localSeasonalMonths,
      isCurrentlyInSeason: isCurrentlyInSeason,
      nextSeasonalStartDate: nextSeasonalStartDate,
      ruleExplanation: ruleExplanation,
      cropClimate: cropClimate,
      localSeasonSummary: localSeasonSummary,
    );
    if (cacheKey != null) {
      if (_searchCache.length >= _maxSearchCacheEntries) {
        _searchCache.remove(_searchCache.keys.first);
      }
      _searchCache[cacheKey] = result;
    }
    return result;
  }

  /// Evaluates whether [info] matches the cosmic requirements for [action] and [targetQuality].
  ///
  /// Returns [TaskSuitability.optimal], [TaskSuitability.favorable], or `null` if unsuitable.
  static TaskSuitability? _evaluateInstant({
    required TaskActionType action,
    required PlantQuality targetQuality,
    required CalendarInfo info,
  }) {
    // Tier 1 Veto: Gray Days (lunar nodes, perigee) and eclipses block all tasks.
    if (info.isGrayDay || info.isEclipse) {
      return null;
    }

    // Tier 2 Primary Factor: Sidereal Plant-Part Day must match targetQuality.
    if (info.quality != targetQuality) {
      return null;
    }

    // Tier 3 Secondary Factor: Tropical Declination (Ascending vs Descending Moon).
    final needsDescending = action.requiresDescendingFor(targetQuality);
    final needsAscending = action.requiresAscendingFor(targetQuality);

    if (needsDescending) {
      return info.isMoonDescending
          ? TaskSuitability.optimal
          : TaskSuitability.favorable;
    }
    if (needsAscending) {
      return info.isMoonAscending
          ? TaskSuitability.optimal
          : TaskSuitability.favorable;
    }

    // For seed sowing and hoeing, the sidereal Plant-Part Day is itself optimal
    // (with Descending Moon afternoon offering an additional soil-inhalation bonus for hoeing).
    if (action == TaskActionType.cultivateSoil && !info.isMoonDescending) {
      return TaskSuitability.favorable;
    }

    return TaskSuitability.optimal;
  }

  static TaskWindow _finalizeWindow({
    required TaskActionType action,
    required PlantQuality targetQuality,
    required VegetableEntry? crop,
    required DateTime start,
    required DateTime end,
    required TaskSuitability suitability,
    required bool hasDescending,
    required bool hasAscending,
    required bool isWaxing,
    required bool isSpecialTrine,
    required bool Function(DateTime time) isDateInSeason,
    required List<WeatherDataPoint>? weatherForecast,
    required ClimateProfile? localProfile,
    required CropClimateEvaluation? cropClimate,
  }) {
    final prefersAfternoon = action.prefersAfternoonFor(targetQuality);
    final peakTime = _selectPeakTime(
      start: start,
      end: end,
      prefersAfternoon: prefersAfternoon,
    );

    final needsDescending = action.requiresDescendingFor(targetQuality);
    final needsAscending = action.requiresAscendingFor(targetQuality);
    final effectiveDescending = needsDescending
        ? hasDescending
        : (needsAscending ? !hasAscending : hasDescending);

    final arcLabel = effectiveDescending
        ? 'Descending Moon (Pflanzzeit)'
        : 'Ascending Moon';
    final trineBadge = isSpecialTrine ? ' • Planetary Trine' : '';
    final headline = '${targetQuality.displayName} Day • $arcLabel$trineBadge';

    final diurnalAdvice = prefersAfternoon
        ? 'Best in late afternoon (15:00–19:00) during Earth Inhalation.'
        : 'Best in morning hours (07:00–11:00) during Earth Exhalation.';

    final targetName =
        crop?.localizedDisplayName ??
        '${targetQuality.displayName.toLowerCase()} crops';

    final String cosmicExplanation;
    if (suitability == TaskSuitability.optimal) {
      if (needsDescending) {
        cosmicExplanation =
            'Optimal ${targetQuality.displayName} constellation aligned with Descending Moon (Pflanzzeit) for $targetName. $diurnalAdvice';
      } else if (needsAscending) {
        cosmicExplanation =
            'Optimal ${targetQuality.displayName} constellation aligned with Ascending Moon for $targetName. $diurnalAdvice';
      } else {
        cosmicExplanation =
            'Optimal sidereal ${targetQuality.displayName} impulse for $targetName ($arcLabel). $diurnalAdvice';
      }
    } else {
      final missingArc = needsDescending ? 'Descending Moon' : 'Ascending Moon';
      cosmicExplanation =
          'Favorable ${targetQuality.displayName} Day for $targetName, though the Moon is not in $missingArc. $diurnalAdvice';
    }

    final isInSeason = isDateInSeason(peakTime);

    final weatherCheck = _checkWeatherForWindow(
      action: action,
      crop: crop,
      peakTime: peakTime,
      weatherForecast: weatherForecast,
      localProfile: localProfile,
    );
    final climateCheck = _checkClimateForWindow(
      action: action,
      crop: crop,
      peakTime: peakTime,
      localProfile: localProfile,
      cropClimate: cropClimate,
    );

    return TaskWindow(
      start: start,
      end: end,
      peakTime: peakTime,
      suitability: suitability,
      quality: targetQuality,
      isDescending: effectiveDescending,
      isWaxing: isWaxing,
      isSpecialTrine: isSpecialTrine,
      isInSeason: isInSeason,
      headline: headline,
      cosmicExplanation: cosmicExplanation,
      weatherNote: weatherCheck.note,
      hasWeatherConflict: weatherCheck.conflict,
      climateNote: climateCheck.note,
      hasClimateRisk: climateCheck.risk,
      weatherHorizon: weatherCheck.horizon,
    );
  }

  static String _buildLocalSeasonSummary(
    ClimateProfile profile, {
    required SeasonalAnchor anchor,
  }) {
    if (anchor == SeasonalAnchor.frostTender) {
      final spring90 = profile.frost.lastSpringFrost90;
      final autumn10 = profile.frost.firstAutumnFrost10;
      if (spring90 != null && autumn10 != null) {
        final safeDays = (autumn10 - spring90).clamp(0, climateYearLength);
        return 'Local frost-safe window (90% confidence): ~${formatClimateMonthDay(profile.dateAtOffset(spring90))} – ${formatClimateMonthDay(profile.dateAtOffset(autumn10))} ($safeDays safe days, ${profile.frost.medianFrostFreeDays} median; Zone ${profile.hardinessZone.label}).';
      }
      if (!profile.frost.hasFrost) {
        return 'Local climate is frost-free year-round (${profile.koppen.code}, Zone ${profile.hardinessZone.label}).';
      }
      return 'Local frost-free season: ~${profile.frost.medianFrostFreeDays} median days (${profile.koppen.code}, Zone ${profile.hardinessZone.label}).';
    }
    final s5 = profile.thermalSeason(5);
    if (s5.isBounded) {
      return 'Local thermal growing season (≥ 5 °C): ~${formatClimateMonthDay(profile.dateAtOffset(s5.start!))} – ${formatClimateMonthDay(profile.dateAtOffset(s5.end!))} (${s5.lengthInDays} days; Zone ${profile.hardinessZone.label}).';
    }
    if (s5.isYearRound) {
      return 'Local thermal growing season (≥ 5 °C) is active year-round (${profile.koppen.code}, Zone ${profile.hardinessZone.label}).';
    }
    return 'Local climate remains below 5 °C daily mean (${profile.koppen.code}, Zone ${profile.hardinessZone.label}).';
  }

  static ({String? note, bool risk}) _checkClimateForWindow({
    required TaskActionType action,
    required VegetableEntry? crop,
    required DateTime peakTime,
    required ClimateProfile? localProfile,
    required CropClimateEvaluation? cropClimate,
  }) {
    if (localProfile == null || action == TaskActionType.sowIndoor) {
      return (note: null, risk: false);
    }

    final offset = localProfile.seasonOffsetOf(climateDayOfYear(peakTime));
    final monthlyNormal = localProfile.normals.temperature[peakTime.month - 1];
    final s5 = localProfile.thermalSeason(5);

    if (crop != null &&
        crop.isFrostTender &&
        (action == TaskActionType.sowOutdoor ||
            action == TaskActionType.transplant)) {
      final spring90 = localProfile.frost.lastSpringFrost90;
      final autumn10 = localProfile.frost.firstAutumnFrost10;
      if (spring90 != null && offset < spring90) {
        return (
          note:
              'Climate Caution: ${formatClimateMonthDay(peakTime)} is before the local 90% frost-free date (~${formatClimateMonthDay(localProfile.dateAtOffset(spring90))}) — frost risk for ${crop.localizedDisplayName} without cloche/greenhouse protection.',
          risk: true,
        );
      }
      if (autumn10 != null && offset >= autumn10) {
        return (
          note:
              'Climate Caution: ${formatClimateMonthDay(peakTime)} is after the local 10% early autumn frost date (~${formatClimateMonthDay(localProfile.dateAtOffset(autumn10))}) — frost risk for ${crop.localizedDisplayName}.',
          risk: true,
        );
      }
      if (cropClimate?.rating == CropClimateRating.seasonTooShortOutdoors &&
          action == TaskActionType.sowOutdoor) {
        return (
          note:
              'Climate Caution: Local frost-free season (${localProfile.frost.medianFrostFreeDays} d) is shorter than ${crop.localizedDisplayName} requires (${crop.minFrostFreeDays} d) — sow under glass/polytunnel.',
          risk: true,
        );
      }
    }

    final isOutsideThermal5 =
        s5.isNeverReached ||
        (s5.isBounded && (offset < s5.start! || offset >= s5.end!));
    if ((action == TaskActionType.sowOutdoor ||
            action == TaskActionType.transplant ||
            action == TaskActionType.divide ||
            action == TaskActionType.cultivateSoil) &&
        isOutsideThermal5) {
      return (
        note:
            'Climate Caution: Outside the local ≥ 5 °C thermal growing season (monthly normal ${monthlyNormal.toStringAsFixed(1)} °C) — outdoor soil is typically cold or dormant.',
        risk: true,
      );
    }

    if ((crop?.isBoltProneInHeat ?? false) &&
        (action == TaskActionType.sowOutdoor ||
            action == TaskActionType.transplant) &&
        monthlyNormal >= 19.5) {
      return (
        note:
            'Climate Caution: Warm monthly normal (${monthlyNormal.toStringAsFixed(1)} °C) — heat-bolting risk for ${crop!.localizedDisplayName}; provide shade and cool moisture.',
        risk: true,
      );
    }

    if (cropClimate != null && cropClimate.needsAttention) {
      return (
        note: '${cropClimate.badgeLabel}: ${cropClimate.summary}',
        risk:
            cropClimate.rating == CropClimateRating.seasonTooShortOutdoors ||
            cropClimate.rating == CropClimateRating.overwinterIndoors,
      );
    }

    return (note: null, risk: false);
  }

  static DateTime _selectPeakTime({
    required DateTime start,
    required DateTime end,
    required bool prefersAfternoon,
  }) {
    final targetHour = prefersAfternoon ? 16 : 9;
    DateTime candidate = start.isUtc
        ? DateTime.utc(start.year, start.month, start.day, targetHour)
        : DateTime(start.year, start.month, start.day, targetHour);
    if (candidate.isBefore(start)) {
      candidate = start.isUtc
          ? DateTime.utc(start.year, start.month, start.day + 1, targetHour)
          : DateTime(start.year, start.month, start.day + 1, targetHour);
    }
    if (!candidate.isBefore(start) && !candidate.isAfter(end)) {
      return candidate;
    }
    final halfHours = end.difference(start).inHours ~/ 2;
    return start.add(Duration(hours: halfHours));
  }

  static ({String? note, bool conflict, MultiHorizonWeatherAnalysis? horizon})
  _checkWeatherForWindow({
    required TaskActionType action,
    required VegetableEntry? crop,
    required DateTime peakTime,
    required List<WeatherDataPoint>? weatherForecast,
    required ClimateProfile? localProfile,
  }) {
    if (weatherForecast == null || weatherForecast.isEmpty) {
      return (note: null, conflict: false, horizon: null);
    }

    final horizon = EcologicalSynthesis.resolveHorizon(
      referenceTime: peakTime,
      weatherSeries: weatherForecast,
      localProfile: localProfile,
    );

    final closest = horizon?.currentPoint;
    if (horizon == null || closest == null) {
      return (note: null, conflict: false, horizon: null);
    }

    final temp = closest.temperature;
    final rain = closest.precipitation;
    final tempText = temp != null ? '${temp.toStringAsFixed(1)}°C' : 'N/A';
    final soilTemp = horizon.estimatedSoilTemperatureCelsius;
    final soilTempText = soilTemp != null
        ? '~${soilTemp.toStringAsFixed(1)}°C soil'
        : null;

    if (action == TaskActionType.sowIndoor) {
      return (
        note:
            'Protected indoor/greenhouse task ($tempText outside${soilTempText != null ? ", $soilTempText" : ""}).',
        conflict: false,
        horizon: horizon,
      );
    }

    if ((temp != null && temp < 0.0) || horizon.isSoilFrozen) {
      return (
        note:
            'Weather Alert: Frost forecast ($tempText) — avoid pruning or disturbing frozen soil.',
        conflict: true,
        horizon: horizon,
      );
    }

    // Post-task 24–48h frost lookahead for transplanting, frost-tender sowing, pruning, or division
    if (horizon.hasForecastLookahead &&
        horizon.hasUpcomingFrost48h &&
        (action == TaskActionType.transplant ||
            (action == TaskActionType.sowOutdoor &&
                (crop?.isFrostTender ?? false)) ||
            (horizon.hasUpcomingHardFreeze48h &&
                (action == TaskActionType.prune ||
                    action == TaskActionType.divide)))) {
      final min48 = horizon.minTemperatureNext48h!;
      return (
        note:
            'Weather Alert: Night frost lookahead (${min48.toStringAsFixed(1)}°C within 48h) — postpone ${action.displayName.toLowerCase()} or protect with fleece / evening BD 507 Valerian.',
        conflict: true,
        horizon: horizon,
      );
    }

    // Instantaneous rain (> 2.0 mm) OR 48–72h antecedent soil waterlogging
    final isSoilSensitiveTask =
        action == TaskActionType.sowOutdoor ||
        action == TaskActionType.transplant ||
        action == TaskActionType.divide ||
        action == TaskActionType.cultivateSoil ||
        action == TaskActionType.harvestStorage;

    if (isSoilSensitiveTask && (rain > 2.0 || horizon.isSoilSaturated)) {
      if (horizon.isAntecedentWaterlogging) {
        return (
          note:
              'Weather Alert: Soil saturated from 48–72h rain (${horizon.precipitationLast48h.toStringAsFixed(1)} mm in 48h, API ${horizon.antecedentPrecipitationIndex.toStringAsFixed(1)} mm) — wait for crumbly tilth to avoid compaction.',
          conflict: true,
          horizon: horizon,
        );
      }
      return (
        note:
            'Weather Alert: Wet conditions (${rain.toStringAsFixed(1)} mm) — avoid compacting wet beds or storing damp crops.',
        conflict: true,
        horizon: horizon,
      );
    }

    // Post-task 24h rain lookahead for pruning cuts
    if (action == TaskActionType.prune &&
        horizon.hasForecastLookahead &&
        horizon.hasPruningRainRisk24h) {
      return (
        note:
            'Weather Alert: Rain forecast within 24h (${horizon.precipitationNext24h.toStringAsFixed(1)} mm) — wet pruning cuts invite fungal canker spores.',
        conflict: true,
        horizon: horizon,
      );
    }

    // Soil temperature vs. crop germination / establishment minimum
    if ((action == TaskActionType.sowOutdoor ||
            action == TaskActionType.transplant) &&
        soilTemp != null) {
      final minSoilTemp = crop?.minimumGerminationSoilTempC ?? 5.0;
      if (soilTemp < minSoilTemp) {
        final targetLabel =
            crop?.localizedDisplayName ?? 'outdoor seed germination';
        return (
          note:
              'Soil Temp Alert: Estimated topsoil temp (${soilTemp.toStringAsFixed(1)}°C) is below ${minSoilTemp.toStringAsFixed(0)}°C minimum for $targetLabel — pre-warm beds with fleece or start under glass.',
          conflict: true,
          horizon: horizon,
        );
      }
    }

    final soilClause = soilTempText != null ? ' ($soilTempText)' : '';
    final tilthClause = horizon.hasAntecedentHistory
        ? ', Soil ${horizon.soilMoisture.shortLabel} (48h ${horizon.precipitationLast48h.toStringAsFixed(1)} mm)'
        : '';
    final lookaheadClause =
        horizon.hasForecastLookahead && horizon.minTemperatureNext48h != null
        ? ', 48h min ${horizon.minTemperatureNext48h!.toStringAsFixed(1)}°C'
        : '';

    return (
      note:
          'Forecast: $tempText$soilClause, ${rain.toStringAsFixed(1)} mm precip$tilthClause$lookaheadClause — favorable terrestrial conditions.',
      conflict: false,
      horizon: horizon,
    );
  }

  static DateTime? _computeNextSeasonalDate(
    DateTime from,
    bool Function(DateTime time) isDateInSeason,
  ) {
    for (int dayOffset = 1; dayOffset <= 366; dayOffset++) {
      final candidate = DateTime(
        from.year,
        from.month,
        from.day + dayOffset,
        9,
        0,
      );
      if (isDateInSeason(candidate)) return candidate;
    }
    return null;
  }

  static String _buildRuleExplanation({
    required TaskActionType action,
    required PlantQuality quality,
    required VegetableEntry? crop,
    CropTaskSchedule? activeOrganRule,
  }) {
    final String targetLabel;
    if (crop != null && activeOrganRule != null) {
      targetLabel =
          '${crop.localizedDisplayName} • ${activeOrganRule.localizedLabel} (${quality.displayName})';
    } else if (crop != null) {
      targetLabel = '${crop.localizedDisplayName} (${quality.displayName})';
    } else {
      targetLabel = '${quality.displayName} plants';
    }
    final needsDescending = action.requiresDescendingFor(quality);
    final needsAscending = action.requiresAscendingFor(quality);

    final String declinationClause;
    if (needsDescending) {
      declinationClause = 'Requires a Descending Moon (Pflanzzeit) so sap and formative forces draw downward into roots and callus.';
    } else if (needsAscending) {
      declinationClause = 'Requires an Ascending Moon so rising sap fills above-ground organs with sugars, oils, and vitality.';
    } else {
      declinationClause = 'Sidereal Plant-Part Day is the primary factor; ascending/descending and waxing/waning Moon do not restrict this task.';
    }

    final organNote =
        activeOrganRule != null && activeOrganRule.noteEn.isNotEmpty
        ? ' ${activeOrganRule.noteEn}'
        : '';

    return '$targetLabel — ${action.displayName}: Seek a non-Gray ${quality.displayName} Day. $declinationClause$organNote';
  }
}
