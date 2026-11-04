import 'climate/hardiness_zone.dart';
import 'models/models.dart';
import 'plants/flowers_and_green_manures_catalog.dart';
import 'plants/grains_and_arable_catalog.dart';
import 'plants/herbs_catalog.dart';
import 'plants/orchard_and_berries_catalog.dart';
import 'plants/vegetables_catalog.dart';

export 'climate/hardiness_zone.dart' show HardinessSubzone, HardinessZone;

/// Functional and botanical category of a plant in the biodynamic catalog.
enum PlantCategory {
  /// Annual, biennial, or perennial kitchen garden vegetables.
  vegetable(
    displayName: 'Vegetable',
    pluralNameEn: 'Vegetables',
    danishName: 'Grøntsag',
    pluralNameDa: 'Grøntsager',
  ),

  /// Aromatic kitchen and culinary herbs.
  culinaryHerb(
    displayName: 'Culinary Herb',
    pluralNameEn: 'Culinary Herbs',
    danishName: 'Køkkenurt',
    pluralNameDa: 'Køkkenurter',
  ),

  /// Apothecary, tea, and biodynamic preparation herbs.
  medicinalHerb(
    displayName: 'Medicinal Herb',
    pluralNameEn: 'Medicinal Herbs',
    danishName: 'Lægeplante',
    pluralNameDa: 'Lægeplanter',
  ),

  /// Temperate orchard pome, stone, and nut trees.
  fruitTree(
    displayName: 'Fruit & Nut Tree',
    pluralNameEn: 'Fruit & Nut Trees',
    danishName: 'Frugt- & Nøddetræ',
    pluralNameDa: 'Frugt- & Nøddetræer',
  ),

  /// Woody berry bushes and brambles.
  berryShrub(
    displayName: 'Berry Shrub',
    pluralNameEn: 'Berry Shrubs',
    danishName: 'Bærbusk',
    pluralNameDa: 'Bærbuske',
  ),

  /// Climbing fruiting vines and long-lived perennial crowns.
  vine(
    displayName: 'Perennial Vine & Crown',
    pluralNameEn: 'Vines & Perennial Crowns',
    danishName: 'Klatreplante & Flerårig Krone',
    pluralNameDa: 'Klatreplanter & Flerårige Kroner',
  ),

  /// Companion, insectary, bulb, and cut flowers.
  flower(
    displayName: 'Companion & Cut Flower',
    pluralNameEn: 'Flowers',
    danishName: 'Blomst & Insektplante',
    pluralNameDa: 'Blomster & Insektplanter',
  ),

  /// Nitrogen-fixing and soil-building cover crops and green manures.
  greenManure(
    displayName: 'Green Manure & Cover Crop',
    pluralNameEn: 'Green Manures',
    danishName: 'Grøngødning & Efterafgrøde',
    pluralNameDa: 'Grøngødning & Efterafgrøder',
  ),

  /// Traditional cereals, pseudocereals, and arable field crops.
  grain(
    displayName: 'Grain & Arable Crop',
    pluralNameEn: 'Grains & Field Crops',
    danishName: 'Korn & Markafgrøde',
    pluralNameDa: 'Korn & Markafgrøder',
  );

  /// English singular display label.
  final String displayName;

  /// English plural display label.
  final String pluralNameEn;

  /// Danish singular display label.
  final String danishName;

  /// Danish plural display label.
  final String pluralNameDa;

  const PlantCategory({
    required this.displayName,
    required this.pluralNameEn,
    required this.danishName,
    required this.pluralNameDa,
  });

  /// English singular display label.
  String get displayNameEn => displayName;

  /// Danish singular display label.
  String get displayNameDa => danishName;

  /// Bilingual label combining Danish and English singular names.
  String get bilingualName => '$danishName / $displayName';
}

/// Botanical life cycle of a plant entry.
enum PlantLifeCycle {
  /// Completes its life cycle within a single growing season.
  annual(displayName: 'Annual', danishName: 'Enårig'),

  /// Vegetative growth in the first year, flowering and seeding in the second.
  biennial(displayName: 'Biennial', danishName: 'Toårig'),

  /// Herbaceous perennial, woody shrub, vine, or tree living three or more years.
  perennial(displayName: 'Perennial', danishName: 'Flerårig / Staude');

  /// English display label.
  final String displayName;

  /// Danish display label.
  final String danishName;

  const PlantLifeCycle({required this.displayName, required this.danishName});

  /// English display label.
  String get displayNameEn => displayName;

  /// Danish display label.
  String get displayNameDa => danishName;

  /// Bilingual label combining Danish and English names.
  String get bilingualName => '$danishName / $displayName';
}

/// Secondary or organ-specific task schedule for multi-purpose plants
/// cultivated or harvested for more than one plant organ.
final class CropTaskSchedule {
  /// Unique snake_case identifier for this organ schedule.
  final String id;

  /// English label describing the organ and use.
  final String labelEn;

  /// Danish label describing the organ and use.
  final String labelDa;

  /// Sidereal [PlantQuality] governing this organ task.
  final PlantQuality quality;

  /// Optimal calendar months (1–12) for performing tasks on this organ.
  final List<int> months;

  /// Danish biodynamic guidance for this specific organ.
  final String noteDa;

  /// English biodynamic guidance for this specific organ.
  final String noteEn;

  /// Whether harvesting this organ for storage favors an Ascending Moon.
  final bool prefersAscendingMoon;

  /// Creates an immutable [CropTaskSchedule].
  ///
  /// It is an error if [id], [labelEn], or [labelDa] are empty.
  const CropTaskSchedule({
    required this.id,
    required this.labelEn,
    required this.labelDa,
    required this.quality,
    required this.months,
    this.noteDa = '',
    this.noteEn = '',
    bool? prefersAscendingMoon,
  }) : assert(id != ''),
       assert(labelEn != ''),
       assert(labelDa != ''),
       prefersAscendingMoon =
           prefersAscendingMoon ?? (quality != PlantQuality.root);

  /// Localized display title combining Danish and English labels.
  String get localizedLabel => '$labelDa ($labelEn)';

  /// Returns the localized note for [languageCode] ('da' or 'en').
  String note([String? languageCode]) {
    if (languageCode == 'da') return noteDa;
    return noteEn;
  }
}

/// Represents a vegetable or crop entry with astronomical and seasonal planting attributes.
final class VegetableEntry {
  /// Unique identifier for the vegetable.
  final String id;

  /// Danish localized common name.
  final String nameDa;

  /// English localized common name.
  final String nameEn;

  /// Botanical / scientific binomial nomenclature.
  final String scientificName;

  /// Biodynamic organ quality (root, leaf, flower, fruit).
  final PlantQuality quality;

  /// Functional and botanical plant category.
  final PlantCategory category;

  /// Botanical life cycle (annual, biennial, perennial).
  final PlantLifeCycle lifeCycle;

  /// Danish regional, apothecary, or culinary synonyms for search.
  final List<String> aliasesDa;

  /// English regional, apothecary, or culinary synonyms for search.
  final List<String> aliasesEn;

  /// Optimal calendar months for indoor starting / pre-cultivation (1-12).
  final List<int> indoorSowingMonths;

  /// Optimal calendar months for direct outdoor sowing or planting (1-12).
  final List<int> sowingMonths;

  /// Optimal calendar months for transplanting outdoors during a Descending Moon (1-12).
  final List<int> transplantMonths;

  /// Optimal calendar months for taking cuttings or layering during a Descending Moon (1-12).
  final List<int> cuttingMonths;

  /// Optimal calendar months for structural or summer pruning during a Descending Moon (1-12).
  final List<int> pruningMonths;

  /// Optimal calendar months for scion grafting or budding during an Ascending Moon (1-12).
  final List<int> graftingMonths;

  /// Optimal calendar months for dividing perennial crowns, rhizomes, or tubers during a Descending Moon (1-12).
  final List<int> divisionMonths;

  /// Primary harvest months (1-12).
  final List<int> harvestMonths;

  /// Danish localized practical cultivation notes.
  final String descriptionDa;

  /// English localized practical cultivation notes.
  final String descriptionEn;

  /// Danish Maria Thun (*Aussaattage*) specific research findings and cosmic guidance.
  final String thunNotesDa;

  /// English Maria Thun (*Aussaattage*) specific research findings and cosmic guidance.
  final String thunNotesEn;

  /// Companion plants that enhance growth or deter pests.
  final List<String> companionPlants;

  /// Antagonist plants that inhibit growth or share pests/diseases.
  final List<String> antagonistPlants;

  /// Secondary or organ-specific task schedules for multi-purpose plants.
  final List<CropTaskSchedule> secondaryOrganRules;

  /// Whether this crop's harvested organ is above ground and benefits from an Ascending Moon when harvesting for storage.
  ///
  /// In Maria Thun's framework, seed sowing is governed by the sidereal [quality] day
  /// rather than ascending/descending declination, while transplanting always favors
  /// a Descending Moon (*Pflanzzeit*).
  final bool prefersAscendingMoon;

  /// Whether this crop has a secondary affinity for a Waxing Moon in traditional synodic lore.
  ///
  /// Within Maria Thun's framework, the synodic phase (waxing/waning) is subordinate
  /// to the sidereal [quality] day and tropical ascending/descending rhythm.
  final bool prefersWaxingMoon;

  /// Whether this crop is killed or severely checked by air frost and must wait
  /// for frost-free conditions outdoors.
  final bool isFrostTender;

  /// Minimum frost-free season length in days needed for outdoor cultivation,
  /// or `null` when short cool-season windows suffice.
  final int? minFrostFreeDays;

  /// Minimum USDA [HardinessZone] for outdoor winter survival of perennials
  /// and overwintering biennials, or `null` for annuals.
  final HardinessZone? minHardinessZone;

  /// Whether this crop requires high summer warmth (and benefits from a
  /// greenhouse, cold frame, or warm south wall in cool-summer climates).
  final bool requiresWarmSummer;

  /// Whether this cool-season crop bolts rapidly or turns bitter when monthly
  /// mean temperatures reach or exceed 20 °C.
  final bool isBoltProneInHeat;

  /// Optional explicit minimum soil temperature (°C at 5–10 cm depth) required
  /// for outdoor seed germination or active root establishment.
  ///
  /// When `null`, [minimumGerminationSoilTempC] derives a botanical threshold
  /// from the plant's species and thermal traits.
  final double? minGerminationSoilTempC;

  /// Creates an immutable [VegetableEntry].
  ///
  /// It is an error if [id], [nameDa], or [nameEn] are empty.
  /// It is an error if any month in [indoorSowingMonths], [sowingMonths],
  /// [transplantMonths], [cuttingMonths], [pruningMonths], [graftingMonths],
  /// [divisionMonths], or [harvestMonths] is outside the range 1..12.
  const VegetableEntry({
    required this.id,
    required this.nameDa,
    required this.nameEn,
    required this.scientificName,
    required this.quality,
    this.category = PlantCategory.vegetable,
    this.lifeCycle = PlantLifeCycle.annual,
    this.aliasesDa = const [],
    this.aliasesEn = const [],
    this.indoorSowingMonths = const [],
    required this.sowingMonths,
    this.transplantMonths = const [],
    this.cuttingMonths = const [],
    this.pruningMonths = const [],
    this.graftingMonths = const [],
    this.divisionMonths = const [],
    required this.harvestMonths,
    required this.descriptionDa,
    required this.descriptionEn,
    this.thunNotesDa = '',
    this.thunNotesEn = '',
    required this.companionPlants,
    this.antagonistPlants = const [],
    this.secondaryOrganRules = const [],
    this.prefersAscendingMoon = false,
    this.prefersWaxingMoon = true,
    this.isFrostTender = false,
    this.minFrostFreeDays,
    this.minHardinessZone,
    this.requiresWarmSummer = false,
    this.isBoltProneInHeat = false,
    this.minGerminationSoilTempC,
  });

  /// Minimum 5–10 cm topsoil temperature (°C) required for reliable outdoor
  /// seed germination or root establishment.
  double get minimumGerminationSoilTempC {
    if (minGerminationSoilTempC case final explicit?) {
      return explicit;
    }
    if (_veryHardySoilIds.contains(id)) {
      return 5.0;
    }
    if (_moderateWarmthSoilIds.contains(id)) {
      return 10.0;
    }
    if (_warmHeatLovingSoilIds.contains(id)) {
      return 16.0;
    }
    if (isFrostTender && requiresWarmSummer) {
      return 15.0;
    }
    if (isFrostTender) {
      return 12.0;
    }
    if (requiresWarmSummer) {
      return 10.0;
    }
    return 7.0;
  }

  static const Set<String> _veryHardySoilIds = {
    'pea',
    'shelling_pea',
    'sugar_snap_pea',
    'snow_pea',
    'fava_bean',
    'broad_bean',
    'spinach',
    'radish',
    'winter_radish',
    'daikon',
    'black_radish',
    'parsnip',
    'jerusalem_artichoke',
    'garlic',
    'autumn_garlic',
    'spring_garlic',
    'lambs_lettuce',
    'winter_rye',
    'oats',
    'white_mustard',
    'crimson_clover',
    'red_clover',
    'white_clover',
    'hairy_vetch',
    'field_pea',
  };

  static const Set<String> _moderateWarmthSoilIds = {
    'celeriac',
    'celery',
    'fennel',
    'florence_fennel',
    'salsify',
    'scorzonera',
    'chicory',
    'endive',
    'sunflower',
    'nasturtium',
    'buckwheat',
  };

  static const Set<String> _warmHeatLovingSoilIds = {
    'melon',
    'watermelon',
    'aubergine',
    'sweet_potato',
  };

  /// Formatted localized title string showing Danish and English names.
  String get localizedDisplayName => '$nameDa ($nameEn)';

  /// Alias getter for [secondaryOrganRules].
  List<CropTaskSchedule> get taskSchedules => secondaryOrganRules;

  /// Alias getter for [secondaryOrganRules].
  List<CropTaskSchedule> get organRules => secondaryOrganRules;

  /// All distinct [PlantQuality] values applicable to this plant
  /// (primary [quality] first, followed by any secondary organ qualities).
  List<PlantQuality> get allQualities {
    if (secondaryOrganRules.isEmpty) {
      return List<PlantQuality>.unmodifiable(<PlantQuality>[quality]);
    }
    final result = <PlantQuality>[quality];
    for (final rule in secondaryOrganRules) {
      if (!result.contains(rule.quality)) {
        result.add(rule.quality);
      }
    }
    return List<PlantQuality>.unmodifiable(result);
  }

  /// Whether this plant can be cultivated or harvested for more than one plant organ.
  bool get hasMultipleOrgans => allQualities.length > 1;

  /// Whether this plant supports [targetQuality] either as its primary [quality]
  /// or via one of its [secondaryOrganRules].
  bool supportsQuality(PlantQuality targetQuality) {
    if (quality == targetQuality) return true;
    for (final rule in secondaryOrganRules) {
      if (rule.quality == targetQuality) return true;
    }
    return false;
  }

  /// Finds the first [CropTaskSchedule] matching [targetQuality], or `null`
  /// if [targetQuality] is not present in [secondaryOrganRules].
  CropTaskSchedule? findOrganRule(PlantQuality targetQuality) {
    for (final rule in secondaryOrganRules) {
      if (rule.quality == targetQuality) return rule;
    }
    return null;
  }

  /// Returns the localized name based on [languageCode] ('da' or 'en').
  ///
  /// If [languageCode] is null or unrecognized, returns [localizedDisplayName].
  String name([String? languageCode]) {
    if (languageCode == 'da') return nameDa;
    if (languageCode == 'en') return nameEn;
    return localizedDisplayName;
  }

  /// Returns the localized description based on [languageCode] ('da' or 'en').
  ///
  /// If [languageCode] is 'da', returns [descriptionDa]; otherwise returns [descriptionEn].
  String description([String? languageCode]) {
    if (languageCode == 'da') return descriptionDa;
    return descriptionEn;
  }

  /// Returns the localized Maria Thun note based on [languageCode] ('da' or 'en').
  String thunNotes([String? languageCode]) {
    if (languageCode == 'da') return thunNotesDa;
    return thunNotesEn;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VegetableEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'VegetableEntry($id, $localizedDisplayName, quality: ${quality.name}, category: ${category.name})';
}

/// In-memory catalog of biodynamic crops categorized by plant organ quality.
final class VegetableDatabase {
  VegetableDatabase._();

  /// Comprehensive list of curated biodynamic vegetable and crop entries.
  static const List<VegetableEntry> allEntries = [
    ...vegetablesCatalog,
    ...herbsCatalog,
    ...orchardAndBerriesCatalog,
    ...flowersAndGreenManuresCatalog,
    ...grainsAndArableCatalog,
  ];

  /// Searches all entries matching [query] across ID, Danish name, English name,
  /// scientific binomial name, Danish aliases, English aliases, and category names.
  ///
  /// Optionally filters by [quality] (including secondary organ rules when
  /// [includeSecondaryOrgans] is true) and/or [category].
  ///
  /// Performance: $O(N)$ where $N$ is the number of entries in [sourceList] or [allEntries].
  static List<VegetableEntry> search(
    String query, {
    PlantQuality? quality,
    PlantCategory? category,
    bool includeSecondaryOrgans = true,
    List<VegetableEntry>? sourceList,
  }) {
    final list = sourceList ?? allEntries;
    final normalized = query.trim().toLowerCase();

    return list
        .where((entry) {
          if (category != null && entry.category != category) {
            return false;
          }
          if (quality != null && quality != PlantQuality.none) {
            final matchesPrimary = entry.quality == quality;
            final matchesSecondary =
                includeSecondaryOrgans &&
                entry.secondaryOrganRules.any((r) => r.quality == quality);
            if (!matchesPrimary && !matchesSecondary) {
              return false;
            }
          }
          if (normalized.isEmpty) return true;

          if (entry.id.toLowerCase().contains(normalized) ||
              entry.nameDa.toLowerCase().contains(normalized) ||
              entry.nameEn.toLowerCase().contains(normalized) ||
              entry.scientificName.toLowerCase().contains(normalized) ||
              entry.category.displayName.toLowerCase().contains(normalized) ||
              entry.category.pluralNameEn.toLowerCase().contains(normalized) ||
              entry.category.danishName.toLowerCase().contains(normalized) ||
              entry.category.pluralNameDa.toLowerCase().contains(normalized)) {
            return true;
          }
          for (final alias in entry.aliasesDa) {
            if (alias.toLowerCase().contains(normalized)) return true;
          }
          for (final alias in entry.aliasesEn) {
            if (alias.toLowerCase().contains(normalized)) return true;
          }
          return false;
        })
        .toList(growable: false);
  }

  /// Returns all entries belonging to [category].
  ///
  /// Performance: $O(N)$ where $N$ is the total number of entries.
  static List<VegetableEntry> getVegetablesForCategory(PlantCategory category) {
    return allEntries
        .where((entry) => entry.category == category)
        .toList(growable: false);
  }

  /// Returns all vegetables whose primary [VegetableEntry.quality] matches [quality]
  /// (or also matching a secondary organ rule when [includeSecondaryOrgans] is `true`).
  ///
  /// Performance: $O(N)$ where $N$ is the total number of entries.
  static List<VegetableEntry> getVegetablesForQuality(
    PlantQuality quality, {
    bool includeSecondaryOrgans = false,
  }) {
    if (quality == PlantQuality.none) {
      return allEntries;
    }
    return allEntries
        .where(
          (entry) =>
              entry.quality == quality ||
              (includeSecondaryOrgans &&
                  entry.secondaryOrganRules.any((r) => r.quality == quality)),
        )
        .toList(growable: false);
  }

  /// Returns all vegetables suitable for indoor sowing, direct sowing, transplanting,
  /// taking cuttings, grafting, or dividing in [month] (1-12).
  ///
  /// The [month] must be between 1 and 12.
  /// Performance: $O(N)$ where $N$ is the total number of entries.
  static List<VegetableEntry> getVegetablesForMonth(
    int month, {
    PlantQuality? quality,
  }) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Must be between 1 and 12.');
    }
    return allEntries
        .where((entry) {
          final matchesPrimaryMonth =
              entry.sowingMonths.contains(month) ||
              entry.indoorSowingMonths.contains(month) ||
              entry.transplantMonths.contains(month) ||
              entry.cuttingMonths.contains(month) ||
              entry.graftingMonths.contains(month) ||
              entry.divisionMonths.contains(month);
          if (quality == null || quality == PlantQuality.none) {
            return matchesPrimaryMonth ||
                entry.secondaryOrganRules.any((r) => r.months.contains(month));
          }
          if (entry.quality == quality && matchesPrimaryMonth) {
            return true;
          }
          return entry.secondaryOrganRules.any(
            (r) => r.quality == quality && r.months.contains(month),
          );
        })
        .toList(growable: false);
  }

  /// Finds a vegetable by its unique [id], or returns null if not found.
  ///
  /// Performance: $O(N)$ where $N$ is the total number of entries.
  static VegetableEntry? findById(String id) {
    for (final entry in allEntries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Queries vegetable entries matching [quality] from [sourceList] or default [allEntries].
  static List<VegetableEntry> queryByQuality({
    required PlantQuality quality,
    List<VegetableEntry>? sourceList,
  }) {
    final list = sourceList ?? allEntries;
    if (quality == PlantQuality.none) {
      return identical(list, allEntries)
          ? allEntries
          : List<VegetableEntry>.unmodifiable(list);
    }
    return list.where((v) => v.quality == quality).toList(growable: false);
  }
}
