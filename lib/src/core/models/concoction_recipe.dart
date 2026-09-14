/// Unit system for dosage calculations.
enum UnitSystem {
  /// Metric units (square meters, hectares, grams, liters).
  metric,

  /// Imperial units (square feet, acres, ounces, gallons).
  imperial,
}

/// Calculated dosage for a specific plot or field area.
final class ConcoctionDosage {
  /// Amount of raw or dried herb / preparation in grams.
  final double herbGrams;

  /// Volume of brewing water in liters.
  final double waterLiters;

  /// Total volume in liters after dilution.
  final double totalDilutedLiters;

  /// Active unit system for display formatting.
  final UnitSystem unitSystem;

  /// Creates an immutable [ConcoctionDosage].
  const ConcoctionDosage({
    required this.herbGrams,
    required this.waterLiters,
    required this.totalDilutedLiters,
    required this.unitSystem,
  });

  /// Formatted herb dosage string in kg/g or lbs/oz.
  String get herbDisplay => unitSystem == UnitSystem.metric
      ? (herbGrams >= 1000
            ? '${(herbGrams / 1000).toStringAsFixed(2)} kg'
            : '${herbGrams.toStringAsFixed(1)} g')
      : (herbGrams * 0.035274 >= 16
            ? '${((herbGrams * 0.035274) / 16).toStringAsFixed(2)} lbs'
            : '${(herbGrams * 0.035274).toStringAsFixed(1)} oz');

  /// Formatted water volume string in L or gal.
  String get waterDisplay => unitSystem == UnitSystem.metric
      ? '${waterLiters.toStringAsFixed(1)} L'
      : '${(waterLiters * 0.264172).toStringAsFixed(1)} gal';

  /// Formatted total diluted volume string in L or gal.
  String get totalDilutedDisplay => unitSystem == UnitSystem.metric
      ? '${totalDilutedLiters.toStringAsFixed(1)} L'
      : '${(totalDilutedLiters * 0.264172).toStringAsFixed(1)} gal';
}

/// Biodynamic preparation recipe definition.
final class ConcoctionRecipe {
  /// Unique recipe identifier.
  final String id;

  /// Localized Danish title.
  final String titleDa;

  /// Localized English title.
  final String titleEn;

  /// Primary agricultural intention and target pests/diseases.
  final String purpose;

  /// Optimal cosmic timing and lunar rhythm application window.
  final String cosmicTiming;

  /// Base herb / preparation rate per 100 square meters.
  final double herbGramsPer100Sqm;

  /// Base water rate per 100 square meters.
  final double waterLitersPer100Sqm;

  /// Recommended dilution factor after brewing (1 = no dilution, 5 = 1:5, 10 = 1:10).
  final int dilutionRatio;

  /// Detailed preparation steps.
  final List<String> steps;

  /// Creates an immutable [ConcoctionRecipe].
  const ConcoctionRecipe({
    required this.id,
    required this.titleDa,
    required this.titleEn,
    required this.purpose,
    required this.cosmicTiming,
    required this.herbGramsPer100Sqm,
    required this.waterLitersPer100Sqm,
    required this.dilutionRatio,
    required this.steps,
  });

  /// Localized display title.
  String get displayName => '$titleDa ($titleEn)';

  /// Computes dosage requirements for [areaValue] in either metric (m²) or imperial (sq ft).
  ConcoctionDosage calculateDosage(double areaValue, UnitSystem unitSystem) {
    // Metric: areaValue in m2
    // Imperial: areaValue in sq ft (1 m2 = 10.7639 sq ft)
    final areaInSqm = unitSystem == UnitSystem.metric
        ? areaValue
        : areaValue / 10.7639;

    final baseHerb = (herbGramsPer100Sqm / 100.0) * areaInSqm;
    final baseWater = (waterLitersPer100Sqm / 100.0) * areaInSqm;
    final total = baseWater * dilutionRatio;

    return ConcoctionDosage(
      herbGrams: baseHerb,
      waterLiters: baseWater,
      totalDilutedLiters: total,
      unitSystem: unitSystem,
    );
  }
}

/// Catalog of classic biodynamic concoctions and spray preparations.
abstract final class ConcoctionCatalog {
  /// Curated preparation recipes.
  static const List<ConcoctionRecipe> recipes = [
    ConcoctionRecipe(
      id: 'bd508_horsetail',
      titleDa: 'BD 508 Agerpadderok (Equisetum)',
      titleEn: 'BD 508 Horsetail Decoction',
      purpose: 'Natural organic fungicide against mildew, potato blight, rust, and damping-off.',
      cosmicTiming:
          'Apply on sunny mornings during Full Moon or Moon opposite Saturn.',
      herbGramsPer100Sqm: 20.0, // 20g dried per 100 sqm (or 100g per 500 sqm)
      waterLitersPer100Sqm: 2.0, // 2 L base decoction
      dilutionRatio: 5, // Dilute 1:5 with rainwater before spraying
      steps: [
        '1. Harvesting / Weighing: Use dried Equisetum arvense harvested in summer when silica content peaks.',
        '2. Simmering Decoction: Bring water to a boil and simmer gently covered for 20-30 minutes to release soluble silicic acid.',
        '3. Steeping Extraction: Remove from heat and allow to steep for 24 hours.',
        '4. Dynamization & Dilution: Strain liquid, dilute 1:5 with fresh rainwater, and stir vigorously for 15-20 minutes.',
        '5. Field Application: Spray as a fine mist over crop foliage and moist soil on a clear morning.',
      ],
    ),
    ConcoctionRecipe(
      id: 'bd500_horn_manure',
      titleDa: 'BD 500 Hornkogle / Hornjord',
      titleEn: 'BD 500 Horn Manure',
      purpose:
          'Root depth stimulation, soil humus buildup, and microbial vitality.',
      cosmicTiming: 'Apply late afternoon / sunset during Descending Moon (Earth Inhalation).',
      herbGramsPer100Sqm: 5.0, // ~50-60g per hectare, ~5g per 100 sqm garden
      waterLitersPer100Sqm: 3.5,
      dilutionRatio: 1, // Ready to spray directly after 1 hour stirring
      steps: [
        '1. Water Preparation: Warm clean rainwater to lukewarm (approx 35-37°C).',
        '2. 1-Hour Dynamization: Stir continuously for 60 minutes, alternating directions each minute to create deep vortex and chaotic crater collapse.',
        '3. Droplet Spraying: Apply within 1-2 hours of stirring using a coarse droplet spray onto bare or mulched soil.',
      ],
    ),
    ConcoctionRecipe(
      id: 'cpp_barrel_compost',
      titleDa: 'Maria Thun Tøndekompost (CPP)',
      titleEn: 'Cow Pat Pit (Maria Thun Barrel Compost)',
      purpose: 'Universal soil inoculant, humus builder, and microbial booster enriched with preparations BD 502–507, basalt, and eggshells.',
      cosmicTiming: 'Apply late afternoon / sunset during Descending Moon (Earth Inhalation) on Root or Fruit days.',
      herbGramsPer100Sqm: 35.0, // 35g per 100 sqm
      waterLitersPer100Sqm: 5.0, // 5L lukewarm rainwater per 100 sqm
      dilutionRatio: 1, // Ready to spray directly after 20-min stirring
      steps: [
        '1. Weigh Barrel Compost: Dissolve 35g of mature Cow Pat Pit barrel compost per 100 m² of garden or field.',
        '2. Water Preparation: Warm clean rainwater to lukewarm (approx. 35°C) in a wooden or stoneware vessel.',
        '3. 20-Minute Dynamization: Stir vigorously for 20 minutes (16 cycles of 75 seconds), creating deep vortex funnels and breaking them into dynamic chaos.',
        '4. Coarse Droplet Spraying: Apply immediately within 1-2 hours using a hearth broom or coarse droplet sprayer onto bare soil, mulch, or fresh compost.',
      ],
    ),
    ConcoctionRecipe(
      id: 'bd501_horn_silica',
      titleDa: 'BD 501 Hornkisel (Kvartsmel)',
      titleEn: 'BD 501 Horn Silica',
      purpose: 'Enhances photosynthesis, fruit aroma, sugar content, and fungal resistance.',
      cosmicTiming:
          'Apply at sunrise on Ascending Moon during Flower or Fruit days.',
      herbGramsPer100Sqm: 0.1, // ~1-2g per hectare, tiny pinch per 100 sqm
      waterLitersPer100Sqm: 3.0,
      dilutionRatio: 1,
      steps: [
        '1. Precision Measurement: Add a small pinch of horn silica powder to lukewarm rainwater.',
        '2. 1-Hour Dynamization: Stir vigorously for 60 minutes at daybreak, creating alternating deep vortexes.',
        '3. Atomized Mist Spray: Spray as an ultrafine floating mist into the air directly above crop foliage.',
      ],
    ),
    ConcoctionRecipe(
      id: 'nettle_ferment',
      titleDa: 'Brændenælegødning (Urtica)',
      titleEn: 'Fermented Stinging Nettle Tea',
      purpose: 'Rich nitrogen & iron liquid fertilizer; activates leaf chlorophyll and strengthens immunity.',
      cosmicTiming:
          'Water on Leaf days (Water element) in the morning or early evening.',
      herbGramsPer100Sqm: 100.0, // Fresh nettles
      waterLitersPer100Sqm: 1.0,
      dilutionRatio: 10, // Dilute 1:10 for watering, 1:20 for foliar spray
      steps: [
        '1. Chop Fresh Nettles: Collect young nettle stems before flowering, pack in non-metallic bucket.',
        '2. Fermentation: Cover with rainwater, stir daily. Ferment outdoors for 10-14 days until bubbling ceases.',
        '3. Filtration: Strain out fermented sludge (add to compost pile).',
        '4. Dilution: Dilute 1:10 with water for soil watering, or 1:20 for leaf spray.',
      ],
    ),
    ConcoctionRecipe(
      id: 'bd507_valerian',
      titleDa: 'BD 507 Baldrian Varme-spray',
      titleEn: 'BD 507 Valerian Warmth Spray',
      purpose: 'Frost protection envelope and blossom setting impulse.',
      cosmicTiming: 'Apply in the evening before forecasted late spring frost or cold snaps.',
      herbGramsPer100Sqm: 0.05, // 5-10 drops
      waterLitersPer100Sqm: 2.5,
      dilutionRatio: 1,
      steps: [
        '1. Extract Addition: Add 5-10 drops of fermented valerian extract into warm rainwater.',
        '2. Stirring: Stir gently for 10-15 minutes.',
        '3. Protective Mist: Spray delicate blossoms and orchard trees in late afternoon before frost.',
      ],
    ),
  ];

  /// Finds a recipe by [id], or null if not found.
  static ConcoctionRecipe? findById(String id) {
    for (final recipe in recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }
}
