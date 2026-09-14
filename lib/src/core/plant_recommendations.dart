import 'models/models.dart';
import 'seasonal_calendar.dart';
import 'vegetable_database.dart';

/// Season of the year relative to local geographical hemisphere.
enum GardenSeason { spring, summer, autumn, winter }

/// Helper class computing practical sowing, transplanting, and harvesting recommendations adapted to season, hemisphere, moon phase, and Danish vegetable database.
final class PlantRecommendations {
  final GardenSeason season;
  final int weekNumber;
  final List<String> sowIndoorPlants;
  final List<String> sowOutdoorPlants;
  final List<String> transplantActions;
  final List<String> harvestActions;
  final String generalAdvice;

  const PlantRecommendations({
    required this.season,
    required this.weekNumber,
    required this.sowIndoorPlants,
    required this.sowOutdoorPlants,
    required this.transplantActions,
    required this.harvestActions,
    required this.generalAdvice,
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

  /// Evaluates plant recommendations for the given agricultural and celestial state.
  ///
  /// **Incomplete:** [isDescending] and [isWaxing] are accepted but not yet
  /// used, and the returned [PlantRecommendations.sowIndoorPlants] and
  /// [PlantRecommendations.transplantActions] are consequently always empty.
  ///
  /// The intent is evidently to filter crops by lunar state:
  /// [VegetableEntry.prefersAscendingMoon] and
  /// [VegetableEntry.prefersWaxingMoon] are populated on every database entry
  /// but read nowhere. Finishing this needs two product decisions that cannot
  /// be inferred from the code:
  ///
  ///  * which crops count as "sow indoors" — [VegetableEntry.sowingMonths] is
  ///    documented as covering direct sowing *and* indoor starting, so the data
  ///    does not currently distinguish them; and
  ///  * what a transplant recommendation should list, since there is no
  ///    transplant-window data on [VegetableEntry].
  static PlantRecommendations evaluate({
    required PlantQuality quality,
    required bool isDescending,
    required bool isWaxing,
    required bool isGrayDay,
    required DateTime selectedTime,
    required double latitude,
    List<VegetableEntry>? dbEntries,
  }) {
    final isNorthern = latitude >= 0;
    int month = selectedTime.month;
    if (!isNorthern) {
      month = southernHemisphereMonth(month);
    }

    GardenSeason season;
    if (month >= 3 && month <= 5) {
      season = GardenSeason.spring;
    } else if (month >= 6 && month <= 8) {
      season = GardenSeason.summer;
    } else if (month >= 9 && month <= 11) {
      season = GardenSeason.autumn;
    } else {
      season = GardenSeason.winter;
    }

    final week = computeWeekNumber(selectedTime);
    final seasonName = season.name[0].toUpperCase() + season.name.substring(1);
    final hemisphereText = isNorthern ? 'Northern' : 'Southern';

    if (isGrayDay) {
      return PlantRecommendations(
        season: season,
        weekNumber: week,
        sowIndoorPlants: const [],
        sowOutdoorPlants: const [],
        transplantActions: const [],
        harvestActions: const [],
        generalAdvice: 'Gray Day (Lunar Node or Perigee): Avoid sowing, planting out, pruning, or harvesting today. Sprouting will be erratic and crops decay quickly.',
      );
    }

    final List<String> sowIndoor = [];
    List<String> sowOutdoor = [];
    final List<String> transplant = [];
    List<String> harvest = [];

    final matchingVegs = VegetableDatabase.queryByQuality(
      quality: quality,
      sourceList: dbEntries,
    );

    sowOutdoor = matchingVegs
        .where((v) => v.sowingMonths.contains(month))
        .map((v) => v.localizedDisplayName)
        .toList();

    harvest = matchingVegs
        .where((v) => v.harvestMonths.contains(month))
        .map((v) => v.localizedDisplayName)
        .toList();

    final String advice =
        '$seasonName ($hemisphereText, Week $week): ${quality.name[0].toUpperCase() + quality.name.substring(1)} Day evaluation derived from Havenyt.dk & Maria Thun database.';

    return PlantRecommendations(
      season: season,
      weekNumber: week,
      sowIndoorPlants: sowIndoor,
      sowOutdoorPlants: sowOutdoor,
      transplantActions: transplant,
      harvestActions: harvest,
      generalAdvice: advice,
    );
  }
}
