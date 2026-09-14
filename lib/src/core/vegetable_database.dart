import 'models/models.dart';

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

  /// Optimal calendar months for direct sowing or indoor starting (1-12).
  final List<int> sowingMonths;

  /// Primary harvest months (1-12).
  final List<int> harvestMonths;

  /// Danish localized practical cultivation notes.
  final String descriptionDa;

  /// English localized practical cultivation notes.
  final String descriptionEn;

  /// Companion plants that enhance growth or deter pests.
  final List<String> companionPlants;

  /// Whether this crop thrives when sown during an Ascending Moon (sap rising).
  final bool prefersAscendingMoon;

  /// Whether this crop thrives when sown during a Waxing Moon (increasing lunar vitality).
  final bool prefersWaxingMoon;

  /// Creates an immutable [VegetableEntry].
  ///
  /// It is an error if [id], [nameDa], or [nameEn] are empty.
  /// It is an error if any month in [sowingMonths] or [harvestMonths] is outside the range 1..12.
  const VegetableEntry({
    required this.id,
    required this.nameDa,
    required this.nameEn,
    required this.scientificName,
    required this.quality,
    required this.sowingMonths,
    required this.harvestMonths,
    required this.descriptionDa,
    required this.descriptionEn,
    required this.companionPlants,
    this.prefersAscendingMoon = false,
    this.prefersWaxingMoon = true,
  });

  /// Formatted localized title string showing Danish and English names.
  String get localizedDisplayName => '$nameDa ($nameEn)';

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
      'VegetableEntry($id, $localizedDisplayName, quality: ${quality.name})';
}

/// In-memory catalog of biodynamic crops categorized by plant organ quality.
final class VegetableDatabase {
  VegetableDatabase._();

  /// Comprehensive list of curated biodynamic vegetable and crop entries.
  static const List<VegetableEntry> allEntries = [
    // ------------------- ROOT CROPS (EARTH) -------------------
    VegetableEntry(
      id: 'carrot',
      nameDa: 'Gulerod',
      nameEn: 'Carrot',
      scientificName: 'Daucus carota',
      quality: PlantQuality.root,
      sowingMonths: [3, 4, 5, 6],
      harvestMonths: [6, 7, 8, 9, 10, 11],
      descriptionDa:
          'Sås på Rod-dage i let, dybdemuldet jord. Dybdegående hakning under aftagende måne fremmer lige rodudvikling.',
      descriptionEn:
          'Sow on Root days in loose, stone-free soil. Deep aeration during descending moon encourages downward taproot growth.',
      companionPlants: ['Løg', 'Porre', 'Rosmarin', 'Salvie'],
      prefersAscendingMoon: false,
      prefersWaxingMoon: false,
    ),
    VegetableEntry(
      id: 'beetroot',
      nameDa: 'Rødbede',
      nameEn: 'Beetroot',
      scientificName: 'Beta vulgaris subsp. vulgaris',
      quality: PlantQuality.root,
      sowingMonths: [4, 5, 6],
      harvestMonths: [7, 8, 9, 10, 11],
      descriptionDa:
          'Trives bedst ved såning på Rod-dage under nedstigende måne. Høst på Rod-dage for maksimal lagringsevne.',
      descriptionEn:
          'Thrives when sown on Root days during descending moon. Harvest on Root days for prolonged winter cellar storage.',
      companionPlants: ['Løg', 'Kålrabi', 'Dild', 'Salat'],
      prefersAscendingMoon: false,
      prefersWaxingMoon: false,
    ),
    VegetableEntry(
      id: 'potato',
      nameDa: 'Kartoffel',
      nameEn: 'Potato',
      scientificName: 'Solanum tuberosum',
      quality: PlantQuality.root,
      sowingMonths: [3, 4, 5],
      harvestMonths: [6, 7, 8, 9, 10],
      descriptionDa:
          'Lægges på Rod-dage i aftagende/nedstigende måne efter jordtemperatur når 8°C. Hypning på Rod-dage styrker knolddannelse.',
      descriptionEn:
          'Plant seed tubers on Root days during descending moon. Hilling up on Root days stimulates uniform tuber initiation.',
      companionPlants: ['Hestebønne', 'Tagetes', 'Kommen', 'Majs'],
      prefersAscendingMoon: false,
      prefersWaxingMoon: false,
    ),
    VegetableEntry(
      id: 'onion',
      nameDa: 'Zittauerløg',
      nameEn: 'Yellow Onion',
      scientificName: 'Allium cepa',
      quality: PlantQuality.root,
      sowingMonths: [3, 4, 5],
      harvestMonths: [8, 9, 10],
      descriptionDa:
          'Sætteløg stikkes på Rod-dage. Undgå kvælstofholdig gødning sent på sæsonen for at forhindre råd under lagring.',
      descriptionEn:
          'Set out onion sets on Root days. Avoid late nitrogen fertilization to maintain solid bulb storage firmness.',
      companionPlants: ['Gulerod', 'Rødbede', 'Jordbær', 'Kamille'],
      prefersAscendingMoon: false,
      prefersWaxingMoon: false,
    ),
    VegetableEntry(
      id: 'radish',
      nameDa: 'Radise',
      nameEn: 'Radish',
      scientificName: 'Raphanus sativus',
      quality: PlantQuality.root,
      sowingMonths: [3, 4, 5, 6, 7, 8, 9],
      harvestMonths: [4, 5, 6, 7, 8, 9, 10],
      descriptionDa:
          'Hurtigvoksende mellemafgrøde. Sås hver anden uge på Rod-dage for sprøde, ikke-træede radiser.',
      descriptionEn:
          'Fast-growing succession crop. Sow bi-weekly on Root days for crisp, tender roots without pithiness.',
      companionPlants: ['Salat', 'Spinat', 'Gulerod', 'Karse'],
      prefersAscendingMoon: false,
      prefersWaxingMoon: false,
    ),
    VegetableEntry(
      id: 'celeriac',
      nameDa: 'Knoldselleri',
      nameEn: 'Celeriac',
      scientificName: 'Apium graveolens var. rapaceum',
      quality: PlantQuality.root,
      sowingMonths: [2, 3, 4],
      harvestMonths: [9, 10, 11],
      descriptionDa:
          'Kræver lang udviklingstid. Forkultiveres indendørs og udplantes i maj på en Rod-dag med rigelig kompost.',
      descriptionEn:
          'Long-season root crop. Start indoors and transplant in May on a Root day with abundant compost.',
      companionPlants: ['Porre', 'Buskbønne', 'Kål', 'Tomat'],
      prefersAscendingMoon: false,
      prefersWaxingMoon: false,
    ),

    // ------------------- LEAF CROPS (WATER) -------------------
    VegetableEntry(
      id: 'lettuce',
      nameDa: 'Hovedsalat',
      nameEn: 'Butterhead Lettuce',
      scientificName: 'Lactuca sativa',
      quality: PlantQuality.leaf,
      sowingMonths: [3, 4, 5, 6, 7, 8],
      harvestMonths: [5, 6, 7, 8, 9, 10],
      descriptionDa:
          'Sås og udplantes på Blad-dage under voksende måne for saftige blade. Vanding på Blad-dage udnyttes bedst.',
      descriptionEn:
          'Sow and transplant on Leaf days during waxing moon for succulent foliage. Irrigation on Leaf days is absorbed most efficiently.',
      companionPlants: ['Gulerod', 'Radise', 'Løg', 'Jordbær'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),
    VegetableEntry(
      id: 'spinach',
      nameDa: 'Spinat',
      nameEn: 'Spinach',
      scientificName: 'Spinacia oleracea',
      quality: PlantQuality.leaf,
      sowingMonths: [3, 4, 5, 8, 9],
      harvestMonths: [4, 5, 6, 9, 10, 11],
      descriptionDa:
          'Trives i køligt vejr. Sås tidligt forår og sensommer på Blad-dage for at undgå for tidlig stokløb.',
      descriptionEn:
          'Cool-weather crop. Sow in early spring and late summer on Leaf days to minimize premature bolting.',
      companionPlants: ['Jordbær', 'Kål', 'Bønne', 'Radise'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),
    VegetableEntry(
      id: 'kale',
      nameDa: 'Grønkål',
      nameEn: 'Curly Kale',
      scientificName: 'Brassica oleracea var. sabellica',
      quality: PlantQuality.leaf,
      sowingMonths: [4, 5, 6],
      harvestMonths: [9, 10, 11, 12, 1, 2],
      descriptionDa:
          'Robust vintergrøntsag. Udplantes på Blad-dage under nedstigende måne for stærkt rodnet.',
      descriptionEn:
          'Hardy winter staple. Transplant on Leaf days during descending moon to establish vigorous root support.',
      companionPlants: ['Tomat', 'Salvie', 'Mynte', 'Timian'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),
    VegetableEntry(
      id: 'swiss_chard',
      nameDa: 'Sølvbede / Bladbede',
      nameEn: 'Swiss Chard',
      scientificName: 'Beta vulgaris subsp. vulgaris',
      quality: PlantQuality.leaf,
      sowingMonths: [4, 5, 6, 7],
      harvestMonths: [6, 7, 8, 9, 10, 11],
      descriptionDa:
          'Høst de yderste stilke løbende på Blad-dage for kontinuerlig genvækst igennem hele sommeren.',
      descriptionEn:
          'Harvest outer stalks on Leaf days to stimulate continuous flush of new tender stems throughout summer.',
      companionPlants: ['Løg', 'Kålrabi', 'Bønner'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),
    VegetableEntry(
      id: 'leek',
      nameDa: 'Vinterporre',
      nameEn: 'Winter Leek',
      scientificName: 'Allium ampeloprasum var. porrum',
      quality: PlantQuality.leaf,
      sowingMonths: [3, 4, 5],
      harvestMonths: [9, 10, 11, 12, 1, 2, 3],
      descriptionDa:
          'Udplantes dybt på Blad-dage i juni. Hypning giver lange, møre hvide skafter.',
      descriptionEn:
          'Deep-transplant on Leaf days in June. Trenching and hilling creates long, tender blanched shafts.',
      companionPlants: ['Gulerod', 'Knoldselleri', 'Jordbær'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),

    // ------------------- FLOWER CROPS (AIR / LIGHT) -------------------
    VegetableEntry(
      id: 'broccoli',
      nameDa: 'Broccoli',
      nameEn: 'Broccoli',
      scientificName: 'Brassica oleracea var. italica',
      quality: PlantQuality.flower,
      sowingMonths: [3, 4, 5, 6],
      harvestMonths: [6, 7, 8, 9, 10, 11],
      descriptionDa:
          'Sås og passes på Blomst-dage for tætte, velformede blomsterknopper uden for tidlig udspring.',
      descriptionEn:
          'Sow and cultivate on Flower days for tight, dense floral heads with prolonged holding quality.',
      companionPlants: ['Dild', 'Kamille', 'Mynte', 'Rosmarin'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),
    VegetableEntry(
      id: 'cauliflower',
      nameDa: 'Blomkål',
      nameEn: 'Cauliflower',
      scientificName: 'Brassica oleracea var. botrytis',
      quality: PlantQuality.flower,
      sowingMonths: [3, 4, 5],
      harvestMonths: [6, 7, 8, 9, 10],
      descriptionDa:
          'Følsom over for udtørring. Plejes og gødes på Blomst-dage under opstigende måne.',
      descriptionEn:
          'Sensitive to moisture fluctuations. Cultivate on Flower days during ascending moon for pure white curds.',
      companionPlants: ['Selleri', 'Bønner', 'Oregano'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),
    VegetableEntry(
      id: 'artichoke',
      nameDa: 'Karyatide / Artiskok',
      nameEn: 'Globe Artichoke',
      scientificName: 'Cynara cardunculus var. scolymus',
      quality: PlantQuality.flower,
      sowingMonths: [2, 3, 4],
      harvestMonths: [7, 8, 9, 10],
      descriptionDa:
          'Flerårig pragtplante. Høst de uåbnede blomsterknopper på Blomst-dage for den fineste nøddeagtige smag.',
      descriptionEn:
          'Perennial delicacy. Harvest immature flower buds on Flower days for peak tenderness and aromatic oils.',
      companionPlants: ['Solsikke', 'Morgenfrue', 'Lavendel'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),
    VegetableEntry(
      id: 'chamomile',
      nameDa: 'Lægekamille',
      nameEn: 'German Chamomile',
      scientificName: 'Matricaria chamomilla',
      quality: PlantQuality.flower,
      sowingMonths: [3, 4, 5, 8, 9],
      harvestMonths: [6, 7, 8, 9],
      descriptionDa:
          'Vigtig biodynamisk præparatplante. Høst blomsterhoveder midt på formiddagen på en solrig Blomst-dag.',
      descriptionEn:
          'Crucial biodynamic compost preparation herb. Harvest flower heads mid-morning on sunny Flower days for maximum essential oils.',
      companionPlants: ['Løg', 'Kål', 'Hvede'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),
    VegetableEntry(
      id: 'sunflower',
      nameDa: 'Solsikke',
      nameEn: 'Sunflower',
      scientificName: 'Helianthus annuus',
      quality: PlantQuality.flower,
      sowingMonths: [4, 5, 6],
      harvestMonths: [8, 9, 10],
      descriptionDa:
          'Kanaliserer lys- og varmeimpulser til jorden. Sås direkte på Blomst-dage.',
      descriptionEn:
          'Channels high light and warmth impulses into soil ecology. Direct-sow on Flower days.',
      companionPlants: ['Agurk', 'Græskar', 'Majs'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),

    // ------------------- FRUIT & SEED CROPS (FIRE / WARMTH) -------------------
    VegetableEntry(
      id: 'tomato',
      nameDa: 'Tomat',
      nameEn: 'Tomato',
      scientificName: 'Solanum lycopersicum',
      quality: PlantQuality.fruit,
      sowingMonths: [2, 3, 4],
      harvestMonths: [7, 8, 9, 10],
      descriptionDa:
          'Forkultiveres i varme. Sideskud fjernes og frugter høstes på Frugt-dage for sødme og aromastoffer.',
      descriptionEn:
          'Start indoors with gentle bottom heat. Prune suckers and harvest on Fruit days for maximum sugar and aromatics.',
      companionPlants: ['Basilikum', 'Tagetes', 'Hvidløg', 'Gulerod'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),
    VegetableEntry(
      id: 'bell_pepper',
      nameDa: 'Sød Peberfrugt',
      nameEn: 'Bell Pepper',
      scientificName: 'Capsicum annuum',
      quality: PlantQuality.fruit,
      sowingMonths: [2, 3, 4],
      harvestMonths: [7, 8, 9, 10],
      descriptionDa:
          'Varmekrævende afgrøde. Sås tidligt på Frugt-dage i voksende måne for hurtig spiring.',
      descriptionEn:
          'Heat-loving crop. Sow early on Fruit days during waxing moon for vigorous germination and sturdy flowering.',
      companionPlants: ['Basilikum', 'Løg', 'Gulerod', 'Oregano'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),
    VegetableEntry(
      id: 'cucumber',
      nameDa: 'Frilandsagurk / Drivagurk',
      nameEn: 'Cucumber',
      scientificName: 'Cucumis sativus',
      quality: PlantQuality.fruit,
      sowingMonths: [4, 5, 6],
      harvestMonths: [7, 8, 9, 10],
      descriptionDa:
          'Sås lunt i maj. Høst løbende på Frugt-dage under opstigende måne for sprøde, saftige frugter.',
      descriptionEn:
          'Sow in warm soil. Pick continuously on Fruit days during ascending moon for crisp, non-bitter yields.',
      companionPlants: ['Bønner', 'Solsikke', 'Dild', 'Majs'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),
    VegetableEntry(
      id: 'bush_bean',
      nameDa: 'Buskbønne',
      nameEn: 'Bush Bean',
      scientificName: 'Phaseolus vulgaris',
      quality: PlantQuality.fruit,
      sowingMonths: [5, 6, 7],
      harvestMonths: [7, 8, 9, 10],
      descriptionDa:
          'Sås når jorden er mindst 12°C. Såning på Frugt-dage under voksende måne giver rigelig bælgdannelse og kvælstoffiksering.',
      descriptionEn:
          'Sow once soil reaches 12°C. Sowing on Fruit days during waxing moon boosts pod set and root nodule nitrogen fixation.',
      companionPlants: ['Bønneurt', 'Majs', 'Græskar', 'Kartoffel'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),
    VegetableEntry(
      id: 'squash',
      nameDa: 'Squash / Courgette',
      nameEn: 'Zucchini / Summer Squash',
      scientificName: 'Cucurbita pepo',
      quality: PlantQuality.fruit,
      sowingMonths: [4, 5, 6],
      harvestMonths: [7, 8, 9, 10],
      descriptionDa:
          'Hurtigvoksende og yderig. Høst frugterne unge (15-20 cm) på Frugt-dage for fortsat blomstring.',
      descriptionEn:
          'Prolific producer. Harvest fruits young on Fruit days to stimulate relentless continuous flowering.',
      companionPlants: ['Majs', 'Morgenfrue', 'Bønner', 'Radise'],
      prefersAscendingMoon: true,
      prefersWaxingMoon: true,
    ),
  ];

  /// Returns all vegetables matching the given [quality].
  ///
  /// Performance: $O(N)$ where $N$ is the total number of entries.
  static List<VegetableEntry> getVegetablesForQuality(PlantQuality quality) {
    if (quality == PlantQuality.none) {
      return allEntries;
    }
    return allEntries
        .where((entry) => entry.quality == quality)
        .toList(growable: false);
  }

  /// Returns all vegetables suitable for sowing or planting in [month] (1-12).
  ///
  /// It is an error if [month] is less than 1 or greater than 12.
  /// Performance: $O(N)$ where $N$ is the total number of entries.
  static List<VegetableEntry> getVegetablesForMonth(
    int month, {
    PlantQuality? quality,
  }) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(
        month,
        'month',
        'Month must be between 1 and 12.',
      );
    }
    return allEntries
        .where((entry) {
          final matchesMonth = entry.sowingMonths.contains(month);
          if (quality == null || quality == PlantQuality.none) {
            return matchesMonth;
          }
          return matchesMonth && entry.quality == quality;
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
    if (quality == PlantQuality.none) return list;
    return list.where((v) => v.quality == quality).toList();
  }
}
