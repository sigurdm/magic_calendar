import 'dart:collection';

import 'climate/climate_profile.dart';
import 'climate/crop_climate_suitability.dart';
import 'climate/season_alignment.dart';
import 'models/models.dart';
import 'vegetable_database.dart';

/// Season of the year relative to local geographical hemisphere.
enum GardenSeason { spring, summer, autumn, winter }

/// Helper class computing practical sowing, transplanting, and harvesting recommendations adapted to season, hemisphere, moon phase, and Danish vegetable database.
final class PlantRecommendations {
  static const int _maxCacheEntries = 256;

  static final Map<PlantQuality, List<VegetableEntry>>
  _defaultEntriesByQuality = <PlantQuality, List<VegetableEntry>>{
    for (final q in PlantQuality.values)
      q: List<VegetableEntry>.unmodifiable(
        VegetableDatabase.queryByQuality(quality: q),
      ),
  };

  static final Expando<String> _profileNoteCache = Expando<String>(
    'PlantRecommendationsProfileNote',
  );

  static final Expando<Map<PlantQuality, Map<String, CropClimateEvaluation>>>
  _profileEvaluationsCache =
      Expando<Map<PlantQuality, Map<String, CropClimateEvaluation>>>(
        'PlantRecommendationsProfileEvaluations',
      );

  static final LinkedHashMap<Object, PlantRecommendations> _evalCache =
      LinkedHashMap<Object, PlantRecommendations>();

  final GardenSeason season;
  final int weekNumber;
  final List<String> sowIndoorPlants;
  final List<String> sowOutdoorPlants;
  final List<String> transplantActions;
  final List<String> harvestActions;
  final String generalAdvice;

  /// Per-crop climate suitability evaluations keyed by [VegetableEntry.id]
  /// when a local [ClimateProfile] is active.
  final Map<String, CropClimateEvaluation> cropClimateEvaluations;

  /// Summary of local climatological frost and thermal season dates when a
  /// local [ClimateProfile] is active.
  final String? localClimateNote;

  const PlantRecommendations({
    required this.season,
    required this.weekNumber,
    required this.sowIndoorPlants,
    required this.sowOutdoorPlants,
    required this.transplantActions,
    required this.harvestActions,
    required this.generalAdvice,
    this.cropClimateEvaluations = const <String, CropClimateEvaluation>{},
    this.localClimateNote,
  });

  /// Computes the ISO 8601 week number (1 to 53) for [date].
  static int computeWeekNumber(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final dayOfWeek = d.weekday; // 1 = Monday, 7 = Sunday
    final thursday = d.add(Duration(days: 4 - dayOfWeek));
    final firstDayOfYear = DateTime.utc(thursday.year, 1, 1);
    final dayOfYear = thursday.difference(firstDayOfYear).inDays + 1;
    final week = ((dayOfYear - 1) / 7).floor() + 1;
    return week.clamp(1, 53);
  }

  static Map<String, CropClimateEvaluation> _defaultProfileEvaluations(
    ClimateProfile profile,
    PlantQuality quality,
    List<VegetableEntry> matchingVegs,
  ) {
    var byQuality = _profileEvaluationsCache[profile];
    if (byQuality == null) {
      byQuality = <PlantQuality, Map<String, CropClimateEvaluation>>{};
      _profileEvaluationsCache[profile] = byQuality;
    }
    if (byQuality[quality] case final cached?) {
      return cached;
    }
    final computed = Map<String, CropClimateEvaluation>.unmodifiable(
      <String, CropClimateEvaluation>{
        for (final v in matchingVegs)
          v.id: CropClimateEvaluation.evaluate(v, profile),
      },
    );
    byQuality[quality] = computed;
    return computed;
  }

  /// Evaluates plant recommendations for the given agricultural and celestial state
  /// following Maria Thun's factor hierarchy:
  ///
  /// 1. **Gray Days (`isGrayDay`)**: Lunar nodes and perigee veto all sowing,
  ///    transplanting, and storage harvest.
  /// 2. **Sidereal Plant-Part Day ([quality])**: The primary determinant for
  ///    both indoor pre-cultivation ([sowIndoorPlants]) and direct outdoor
  ///    sowing ([sowOutdoorPlants]). Sowing is *not* restricted by [isDescending]
  ///    or [isWaxing].
  /// 3. **Tropical Declination ([isDescending] / *Pflanzzeit*)**: Secondary
  ///    structural rhythm governing [transplantActions]. Transplanting is
  ///    recommended on matching [quality] days when the Moon is descending so
  ///    roots anchor rapidly in the soil.
  /// 4. **Synodic Moon Phase ([isWaxing])**: Minor tertiary rhythm noted in
  ///    [generalAdvice] for moisture and germination pull without suppressing
  ///    sidereal sowing windows.
  static PlantRecommendations evaluate({
    required PlantQuality quality,
    required bool isDescending,
    required bool isWaxing,
    required bool isGrayDay,
    required DateTime selectedTime,
    required double latitude,
    SeasonAlignment? seasons,
    List<VegetableEntry>? dbEntries,
  }) {
    final alignment = seasons ?? HemisphereSeasonAlignment(latitude: latitude);
    final profile = alignment.localProfile;
    final useDefaultDb =
        dbEntries == null || identical(dbEntries, VegetableDatabase.allEntries);

    if (useDefaultDb) {
      final cacheKey = (
        quality,
        isDescending,
        isWaxing,
        isGrayDay,
        selectedTime.year,
        selectedTime.month,
        selectedTime.day,
        alignment.hasNorthernSeasons,
        alignment.transferability,
        alignment.shortLabel,
        alignment.referenceMonth(selectedTime),
        alignment.referenceMonth(
          selectedTime,
          anchor: SeasonalAnchor.frostTender,
        ),
        alignment.referenceMonth(selectedTime, anchor: SeasonalAnchor.thermal),
        identityHashCode(profile),
      );
      final cached = _evalCache.remove(cacheKey);
      if (cached != null) {
        _evalCache[cacheKey] = cached;
        return cached;
      }

      final result = _evaluateUncached(
        quality: quality,
        isDescending: isDescending,
        isWaxing: isWaxing,
        isGrayDay: isGrayDay,
        selectedTime: selectedTime,
        alignment: alignment,
        profile: profile,
        dbEntries: null,
      );
      if (_evalCache.length >= _maxCacheEntries) {
        _evalCache.remove(_evalCache.keys.first);
      }
      _evalCache[cacheKey] = result;
      return result;
    }

    return _evaluateUncached(
      quality: quality,
      isDescending: isDescending,
      isWaxing: isWaxing,
      isGrayDay: isGrayDay,
      selectedTime: selectedTime,
      alignment: alignment,
      profile: profile,
      dbEntries: dbEntries,
    );
  }

  static PlantRecommendations _evaluateUncached({
    required PlantQuality quality,
    required bool isDescending,
    required bool isWaxing,
    required bool isGrayDay,
    required DateTime selectedTime,
    required SeasonAlignment alignment,
    required ClimateProfile? profile,
    required List<VegetableEntry>? dbEntries,
  }) {
    final month = alignment.referenceMonth(selectedTime);
    final climateNote = profile == null ? null : _buildProfileNote(profile);

    final GardenSeason season = switch (month) {
      >= 3 && <= 5 => GardenSeason.spring,
      >= 6 && <= 8 => GardenSeason.summer,
      >= 9 && <= 11 => GardenSeason.autumn,
      _ => GardenSeason.winter,
    };

    final week = computeWeekNumber(selectedTime);
    final seasonName = season.name[0].toUpperCase() + season.name.substring(1);
    final hemisphereText = alignment.shortLabel;

    if (isGrayDay) {
      return PlantRecommendations(
        season: season,
        weekNumber: week,
        sowIndoorPlants: const [],
        sowOutdoorPlants: const [],
        transplantActions: const [],
        harvestActions: const [],
        generalAdvice: 'Gray Day (Lunar Node or Perigee): Avoid sowing, planting out, pruning, or harvesting today. Sprouting will be erratic and crops decay quickly.',
        localClimateNote: climateNote,
      );
    }

    final declinationNote = isDescending
        ? 'Descending Moon (Pflanzzeit): optimal for transplanting, soil cultivation, and root storage harvest.'
        : 'Ascending Moon: optimal for above-ground storage harvest and foliar sprays (postpone transplanting).';
    final synodicNote = isWaxing
        ? 'Waxing Moon (secondary moisture/germination pull).'
        : 'Waning Moon (secondary low-moisture curing phase).';
    final caveatSuffix = alignment.caveats.isEmpty
        ? ''
        : ' ${alignment.caveats.join(' ')}';

    if (alignment.transferability == CalendarTransferability.doesNotTransfer) {
      return PlantRecommendations(
        season: season,
        weekNumber: week,
        sowIndoorPlants: const [],
        sowOutdoorPlants: const [],
        transplantActions: const [],
        harvestActions: const [],
        generalAdvice:
            '$seasonName ($hemisphereText, Week $week): ${quality.displayName} Day (primary sidereal impulse for sowing & hoeing). $declinationNote $synodicNote$caveatSuffix',
        localClimateNote: climateNote,
      );
    }

    final matchingVegs = dbEntries == null
        ? (_defaultEntriesByQuality[quality] ?? const <VegetableEntry>[])
        : VegetableDatabase.queryByQuality(
            quality: quality,
            sourceList: dbEntries,
          );

    final Map<String, CropClimateEvaluation> evaluations;
    if (profile == null) {
      evaluations = const <String, CropClimateEvaluation>{};
    } else if (dbEntries == null) {
      evaluations = _defaultProfileEvaluations(profile, quality, matchingVegs);
    } else {
      evaluations = Map<String, CropClimateEvaluation>.unmodifiable(
        <String, CropClimateEvaluation>{
          for (final v in matchingVegs)
            v.id: CropClimateEvaluation.evaluate(v, profile),
        },
      );
    }

    final frostTenderMonth = alignment.referenceMonth(
      selectedTime,
      anchor: SeasonalAnchor.frostTender,
    );
    final thermalMonth = alignment.referenceMonth(
      selectedTime,
      anchor: SeasonalAnchor.thermal,
    );

    int sowMonthFor(VegetableEntry crop) =>
        crop.isFrostTender ? frostTenderMonth : thermalMonth;

    bool isOutdoorViable(VegetableEntry crop) {
      final eval = evaluations[crop.id];
      if (eval != null &&
          eval.rating == CropClimateRating.seasonTooShortOutdoors) {
        return false;
      }
      return true;
    }

    // 1. Sidereal Plant-Part Day + Season governs both indoor and outdoor sowing
    // regardless of whether the Moon is ascending/descending or waxing/waning.
    final sowIndoor = List<String>.unmodifiable(
      matchingVegs
          .where((v) => v.indoorSowingMonths.contains(sowMonthFor(v)))
          .map((v) => v.localizedDisplayName),
    );

    final sowOutdoor = List<String>.unmodifiable(
      matchingVegs
          .where(
            (v) =>
                v.sowingMonths.contains(sowMonthFor(v)) && isOutdoorViable(v),
          )
          .map((v) => v.localizedDisplayName),
    );

    // 2. Descending Moon (Pflanzzeit) + Sidereal Plant-Part Day governs transplanting.
    final transplant = isDescending
        ? List<String>.unmodifiable(
            matchingVegs
                .where((v) => v.transplantMonths.contains(sowMonthFor(v)))
                .map((v) => v.localizedDisplayName),
          )
        : const <String>[];

    final harvest = List<String>.unmodifiable(
      matchingVegs
          .where((v) => v.harvestMonths.contains(month))
          .map((v) => v.localizedDisplayName),
    );

    final String advice =
        '$seasonName ($hemisphereText, Week $week): ${quality.displayName} Day (primary sidereal impulse for sowing & hoeing). $declinationNote $synodicNote$caveatSuffix';

    return PlantRecommendations(
      season: season,
      weekNumber: week,
      sowIndoorPlants: sowIndoor,
      sowOutdoorPlants: sowOutdoor,
      transplantActions: transplant,
      harvestActions: harvest,
      generalAdvice: advice,
      cropClimateEvaluations: evaluations,
      localClimateNote: climateNote,
    );
  }

  static String _buildProfileNote(ClimateProfile p) {
    if (_profileNoteCache[p] case final cached?) {
      return cached;
    }
    final s5 = p.thermalSeason(5);
    final spring90 = p.frost.lastSpringFrost90;
    final autumn10 = p.frost.firstAutumnFrost10;
    final frostClause = spring90 != null && autumn10 != null
        ? 'safe frost-free window ~${formatClimateMonthDay(p.dateAtOffset(spring90))} – ${formatClimateMonthDay(p.dateAtOffset(autumn10))}'
        : (p.frost.hasFrost
              ? '${p.frost.medianFrostFreeDays} median frost-free days'
              : 'frost-free year-round');
    final thermalClause = s5.isBounded
        ? 'thermal season ≥ 5 °C ~${formatClimateMonthDay(p.dateAtOffset(s5.start!))} – ${formatClimateMonthDay(p.dateAtOffset(s5.end!))} (${s5.lengthInDays} d)'
        : (s5.isYearRound
              ? 'thermal season ≥ 5 °C year-round'
              : 'sub-5 °C climate');
    final note =
        '${p.koppen.code} · USDA Zone ${p.hardinessZone.label}: $frostClause; $thermalClause.';
    _profileNoteCache[p] = note;
    return note;
  }
}
