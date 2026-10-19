import 'package:flutter/material.dart';

import '../models/models.dart';
import '../task_window_planner.dart';
import '../vegetable_database.dart';
import 'field_journal_entry.dart';

/// Physical environment and structure of a [GardenPlot].
enum GardenPlotType {
  /// Unprotected open-ground garden bed or field row.
  openBed(
    displayName: 'Open Ground Bed',
    danishName: 'Frilandsbed',
    glyph: '🌱',
    icon: Icons.landscape_outlined,
    isProtectedEnvironment: false,
  ),

  /// Framed or mounded raised bed that warms and drains faster in spring.
  raisedBed(
    displayName: 'Raised Bed',
    danishName: 'Højbed',
    glyph: '🪵',
    icon: Icons.view_agenda_outlined,
    isProtectedEnvironment: false,
  ),

  /// Glasshouse or polytunnel extending the growing season.
  greenhouse(
    displayName: 'Greenhouse / Polytunnel',
    danishName: 'Drivhus / Tunnel',
    glyph: '🏡',
    icon: Icons.home_work_outlined,
    isProtectedEnvironment: true,
  ),

  /// Cold frame, hotbed, or low cloche tunnel.
  coldFrame(
    displayName: 'Cold Frame / Cloche',
    danishName: 'Mistbænk',
    glyph: '🪟',
    icon: Icons.window_outlined,
    isProtectedEnvironment: true,
  ),

  /// Perennial orchard row, espalier, or berry bush guild.
  orchard(
    displayName: 'Orchard / Berry Row',
    danishName: 'Frugthave / Bærrække',
    glyph: '🌳',
    icon: Icons.park_outlined,
    isProtectedEnvironment: false,
  ),

  /// Perennial herb, cut-flower, or pollinator border.
  perennialBed(
    displayName: 'Perennial & Herb Border',
    danishName: 'Staude- & Urtebed',
    glyph: '🌿',
    icon: Icons.grass_outlined,
    isProtectedEnvironment: false,
  ),

  /// Balcony box, pot, or courtyard container.
  container(
    displayName: 'Container / Pot',
    danishName: 'Krukke / Altan',
    glyph: '🪴',
    icon: Icons.yard_outlined,
    isProtectedEnvironment: false,
  );

  /// English display name.
  final String displayName;

  /// Danish display name.
  final String danishName;

  /// Compact emoji glyph for badges and chips.
  final String glyph;

  /// Material icon representing this plot environment.
  final IconData icon;

  /// Whether this plot provides frost/wind protection (greenhouse or cold frame).
  final bool isProtectedEnvironment;

  const GardenPlotType({
    required this.displayName,
    required this.danishName,
    required this.glyph,
    required this.icon,
    required this.isProtectedEnvironment,
  });

  /// Bilingual label combining Danish and English names.
  String get bilingualName => '$danishName / $displayName';
}

/// Botanical plant family used for multi-year crop rotation planning on a [GardenPlot].
enum BotanicalFamily {
  /// Cabbage, kale, broccoli, kohlrabi, radish, turnip, mustard, rocket (*Brassicaceae*).
  brassicaceae(
    displayName: 'Brassicaceae (Brassicas)',
    danishName: 'Korsblomstrede (Kål)',
    shortLabel: 'Brassicaceae',
    minBreakYears: 3,
    isHeavyFeeder: true,
    isNitrogenFixer: false,
  ),

  /// Tomato, potato, pepper, chili, eggplant, physalis (*Solanaceae*).
  solanaceae(
    displayName: 'Solanaceae (Nightshades)',
    danishName: 'Natskyggefamilien',
    shortLabel: 'Solanaceae',
    minBreakYears: 3,
    isHeavyFeeder: true,
    isNitrogenFixer: false,
  ),

  /// Onion, garlic, leek, shallot, chives (*Alliaceae* / *Amaryllidaceae*).
  alliaceae(
    displayName: 'Alliaceae (Alliums)',
    danishName: 'Løgfamilien',
    shortLabel: 'Alliaceae',
    minBreakYears: 3,
    isHeavyFeeder: false,
    isNitrogenFixer: false,
  ),

  /// Carrot, parsnip, celeriac, celery, parsley, fennel, dill (*Apiaceae*).
  apiaceae(
    displayName: 'Apiaceae (Umbellifers)',
    danishName: 'Skærmplantefamilien',
    shortLabel: 'Apiaceae',
    minBreakYears: 3,
    isHeavyFeeder: false,
    isNitrogenFixer: false,
  ),

  /// Pea, bean, broad bean, clover, lupin, vetch, alfalfa (*Fabaceae*).
  fabaceae(
    displayName: 'Fabaceae (Legumes / N-Fixers)',
    danishName: 'Ærteblomstrede (Kvælstofsamler)',
    shortLabel: 'Fabaceae',
    minBreakYears: 2,
    isHeavyFeeder: false,
    isNitrogenFixer: true,
  ),

  /// Beetroot, swiss chard, spinach, quinoa, good-king-henry (*Amaranthaceae* / *Chenopodiaceae*).
  amaranthaceae(
    displayName: 'Amaranthaceae (Beets & Spinach)',
    danishName: 'Amarant- & Salturtfamilien',
    shortLabel: 'Amaranthaceae',
    minBreakYears: 2,
    isHeavyFeeder: false,
    isNitrogenFixer: false,
  ),

  /// Courgette, pumpkin, winter squash, cucumber, melon (*Cucurbitaceae*).
  cucurbitaceae(
    displayName: 'Cucurbitaceae (Cucurbits)',
    danishName: 'Græskarfamilien',
    shortLabel: 'Cucurbitaceae',
    minBreakYears: 2,
    isHeavyFeeder: true,
    isNitrogenFixer: false,
  ),

  /// Lettuce, chicory, endive, salsify, scorzonera, Jerusalem artichoke, calendula (*Asteraceae*).
  asteraceae(
    displayName: 'Asteraceae (Composites)',
    danishName: 'Kurvblomstrede',
    shortLabel: 'Asteraceae',
    minBreakYears: 1,
    isHeavyFeeder: false,
    isNitrogenFixer: false,
  ),

  /// Sweetcorn, rye, wheat, oats, barley, millet (*Poaceae*).
  poaceae(
    displayName: 'Poaceae (Grasses & Corn)',
    danishName: 'Græsfamilien',
    shortLabel: 'Poaceae',
    minBreakYears: 1,
    isHeavyFeeder: true,
    isNitrogenFixer: false,
  ),

  /// Strawberry, raspberry, apple, pear, plum, cherry (*Rosaceae*).
  rosaceae(
    displayName: 'Rosaceae (Rose & Berry Family)',
    danishName: 'Rosenfamilien',
    shortLabel: 'Rosaceae',
    minBreakYears: 3,
    isHeavyFeeder: false,
    isNitrogenFixer: false,
  ),

  /// Other botanical families with low rotation disease carryover.
  other(
    displayName: 'Other Family',
    danishName: 'Øvrig familie',
    shortLabel: 'Other',
    minBreakYears: 1,
    isHeavyFeeder: false,
    isNitrogenFixer: false,
  );

  /// English display name.
  final String displayName;

  /// Danish display name.
  final String danishName;

  /// Compact Latin family name for badges.
  final String shortLabel;

  /// Recommended minimum number of years before replanting the same annual family in a plot.
  final int minBreakYears;

  /// Whether crops in this family are heavy soil nutrient feeders.
  final bool isHeavyFeeder;

  /// Whether crops in this family fix atmospheric nitrogen via rhizobia.
  final bool isNitrogenFixer;

  const BotanicalFamily({
    required this.displayName,
    required this.danishName,
    required this.shortLabel,
    required this.minBreakYears,
    required this.isHeavyFeeder,
    required this.isNitrogenFixer,
  });

  /// Resolves the [BotanicalFamily] for [crop] from its [VegetableEntry.scientificName].
  static BotanicalFamily forCrop(VegetableEntry crop) {
    final trimmed = crop.scientificName.trim();
    final genus = trimmed.split(RegExp(r'\s+')).first.toLowerCase();
    return switch (genus) {
      'brassica' ||
      'raphanus' ||
      'sinapis' ||
      'eruca' ||
      'crambe' ||
      'armoracia' ||
      'nasturtium' ||
      'lepidium' ||
      'matthiola' ||
      'barbarea' => BotanicalFamily.brassicaceae,
      'solanum' ||
      'capsicum' ||
      'physalis' ||
      'lycopersicon' => BotanicalFamily.solanaceae,
      'allium' => BotanicalFamily.alliaceae,
      'daucus' ||
      'apium' ||
      'pastinaca' ||
      'petroselinum' ||
      'foeniculum' ||
      'anethum' ||
      'coriandrum' ||
      'carum' ||
      'levisticum' ||
      'anthriscus' ||
      'pimpinella' ||
      'myrrhis' ||
      'angelica' => BotanicalFamily.apiaceae,
      'pisum' ||
      'phaseolus' ||
      'vicia' ||
      'lupinus' ||
      'trifolium' ||
      'medicago' ||
      'melilotus' ||
      'lens' ||
      'cicer' ||
      'glycine' ||
      'onobrychis' ||
      'ornithopus' ||
      'lathyrus' => BotanicalFamily.fabaceae,
      'beta' ||
      'spinacia' ||
      'chenopodium' ||
      'atriplex' ||
      'amaranthus' ||
      'blitum' => BotanicalFamily.amaranthaceae,
      'cucurbita' ||
      'cucumis' ||
      'citrullus' ||
      'lagenaria' => BotanicalFamily.cucurbitaceae,
      'lactuca' ||
      'cichorium' ||
      'helianthus' ||
      'cynara' ||
      'tragopogon' ||
      'scorzonera' ||
      'matricaria' ||
      'calendula' ||
      'achillea' ||
      'arnica' ||
      'echinacea' ||
      'tagetes' ||
      'centaurea' ||
      'taraxacum' ||
      'artemisia' ||
      'inula' ||
      'silybum' => BotanicalFamily.asteraceae,
      'zea' ||
      'triticum' ||
      'secale' ||
      'hordeum' ||
      'avena' ||
      'panicum' ||
      'sorghum' => BotanicalFamily.poaceae,
      'fragaria' ||
      'malus' ||
      'pyrus' ||
      'prunus' ||
      'rubus' ||
      'rosa' ||
      'cydonia' ||
      'mespilus' ||
      'sorbus' ||
      'aronia' => BotanicalFamily.rosaceae,
      _ => BotanicalFamily.other,
    };
  }
}

/// First-class garden plot / bed definition stored in `garden_meta.sqlite` and
/// synchronized across garden members via Hybrid Logical Clock (HLC) CRDT state.
final class GardenPlot {
  /// Primary plot or bed name (e.g. `'Bed 1'`, `'North Greenhouse'`).
  final String name;

  /// Optional parent section or zone in the garden (e.g. `'Kitchen Garden'`, `'Orchard'`).
  final String areaName;

  /// Physical structure and microclimate environment of this plot.
  final GardenPlotType plotType;

  /// Optional dimensions or area note (e.g. `'1.2m × 4.0m'`).
  final String dimensions;

  /// Optional soil type, aspect, or permanent notes.
  final String notes;

  /// Summary of the most recent soil preparation, compost, or BD 500 spray on this plot.
  final String? lastSoilPrepSummary;

  /// Timestamp of the most recent soil preparation or BD 500 spray on this plot.
  final DateTime? lastSoilPrepTimestamp;

  /// HLC watermark of the latest update to this plot's metadata.
  final String? updatedHlc;

  /// HLC watermark if this plot was soft-deleted.
  final String? deletedHlc;

  /// Creates an immutable [GardenPlot].
  ///
  /// The [name] must not be empty after trimming.
  GardenPlot({
    required String name,
    this.areaName = '',
    this.plotType = GardenPlotType.openBed,
    this.dimensions = '',
    this.notes = '',
    this.lastSoilPrepSummary,
    this.lastSoilPrepTimestamp,
    this.updatedHlc,
    this.deletedHlc,
  }) : name = name.trim() {
    if (this.name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty');
    }
  }

  /// Whether this plot has been soft-deleted.
  bool get isDeleted =>
      deletedHlc != null &&
      (updatedHlc == null || deletedHlc!.compareTo(updatedHlc!) >= 0);

  /// Display title combining [areaName] and [name] when [areaName] is present.
  String get displayTitle =>
      areaName.trim().isNotEmpty ? '${areaName.trim()} · $name' : name;

  /// Compact badge label with environment glyph.
  String get badgeLabel => '${plotType.glyph} $name';

  /// Days elapsed since [lastSoilPrepTimestamp] relative to [reference], or `null` if never prepped.
  int? daysSinceSoilPrepAt(DateTime reference) {
    final prepTime = lastSoilPrepTimestamp;
    if (prepTime == null) return null;
    return reference.toUtc().difference(prepTime.toUtc()).inDays;
  }

  /// Returns a copy of this plot with updated fields.
  GardenPlot copyWith({
    String? name,
    String? areaName,
    GardenPlotType? plotType,
    String? dimensions,
    String? notes,
    String? lastSoilPrepSummary,
    DateTime? lastSoilPrepTimestamp,
    String? updatedHlc,
    String? deletedHlc,
  }) => GardenPlot(
    name: name ?? this.name,
    areaName: areaName ?? this.areaName,
    plotType: plotType ?? this.plotType,
    dimensions: dimensions ?? this.dimensions,
    notes: notes ?? this.notes,
    lastSoilPrepSummary: lastSoilPrepSummary ?? this.lastSoilPrepSummary,
    lastSoilPrepTimestamp: lastSoilPrepTimestamp ?? this.lastSoilPrepTimestamp,
    updatedHlc: updatedHlc ?? this.updatedHlc,
    deletedHlc: deletedHlc ?? this.deletedHlc,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GardenPlot &&
          name == other.name &&
          areaName == other.areaName &&
          plotType == other.plotType &&
          dimensions == other.dimensions &&
          notes == other.notes &&
          lastSoilPrepSummary == other.lastSoilPrepSummary &&
          lastSoilPrepTimestamp == other.lastSoilPrepTimestamp &&
          updatedHlc == other.updatedHlc &&
          deletedHlc == other.deletedHlc;

  @override
  int get hashCode => Object.hash(
    name,
    areaName,
    plotType,
    dimensions,
    notes,
    lastSoilPrepSummary,
    lastSoilPrepTimestamp,
    updatedHlc,
    deletedHlc,
  );
}

/// Evidence-based crop rotation sensitivity tier grounded in Maria Thun's
/// *Aussaattage* research, RHS pathology guidance, and long-term no-dig trials.
enum RotationSensitivity {
  /// Strict 3–4 year break required due to persistent soil-borne resting spores
  /// or cysts (e.g. Brassica clubroot, Potato cyst nematode, Allium white rot,
  /// Pea foot-rot complex).
  strict(
    label: 'Strict Rotation (3–4 yr break)',
    danishLabel: 'Streng sædskifte (3–4 års pause)',
  ),

  /// Self-compatible / stationary crop that tolerates repeated cultivation in the
  /// same plot when nourished with crop-specific biodynamic compost (e.g. Maria
  /// Thun's tomato-haulm compost method for Tomatoes, or permanent Runner/French
  /// Bean trenches), while still avoiding cross-infection with incompatible relatives
  /// (such as Tomatoes after Potatoes).
  selfCompatibleWithCompost(
    label: 'Self-Tolerant with Compost (Maria Thun / RHS Exception)',
    danishLabel: 'Selv-tolerant ved kompostpleje (Maria Thun)',
  ),

  /// Moderate 2-year rotation benefit (e.g. Umbellifers / Apiaceae and Beets /
  /// Amaranthaceae — helps reduce violet root rot and parsnip canker, though
  /// airborne pests like carrot fly require mesh rather than rotation).
  moderate(
    label: 'Moderate Rotation (2 yr break)',
    danishLabel: 'Moderat sædskifte (2 års pause)',
  ),

  /// Flexible crops without persistent home-garden soil plagues (Cucurbits,
  /// Sweetcorn, Lettuce/Salads) that can be planted wherever compost and space allow.
  flexible(
    label: 'Flexible / No Strict Rotation Needed',
    danishLabel: 'Fleksibel (kræver ikke fast sædskifte)',
  ),

  /// Multi-year perennial crowns, berry beds, and orchard plantings.
  perennial(
    label: 'Perennial / Multi-Year Bed',
    danishLabel: 'Flerårig kultur',
  );

  /// English label.
  final String label;

  /// Danish label.
  final String danishLabel;

  const RotationSensitivity({required this.label, required this.danishLabel});
}

/// Evaluation of a candidate [VegetableEntry] against a [GardenPlot]'s multi-year
/// planting history (`planting_index`).
final class PlotRotationAssessment {
  /// Target plot name.
  final String plotName;

  /// Candidate crop being evaluated, if any.
  final VegetableEntry? candidateCrop;

  /// Botanical family of [candidateCrop], if any.
  final BotanicalFamily? candidateFamily;

  /// Evidence-based rotation sensitivity tier for [candidateCrop], if any.
  final RotationSensitivity? sensitivity;

  /// Whether planting [candidateCrop] in [plotName] violates a strict or moderate
  /// soil-borne disease rotation rule.
  final bool hasFamilyConflict;

  /// Whether [candidateCrop] is a valid within-season staggered sowing (*Hold-såning*)
  /// of the same short/medium-cycle crop in [plotName].
  final bool isStaggeredSameSeasonSowing;

  /// Previous planting batch in [plotName] that triggered [hasFamilyConflict]
  /// or triggered a self-compatible compost / staggered sowing note.
  final PlantingBatchSummary? conflictingBatch;

  /// Years elapsed since [conflictingBatch] was planted in [plotName].
  final int? yearsSinceSameFamily;

  /// Recommended next biodynamic organ quality for [plotName] based on its last planting.
  final PlantQuality recommendedNextQuality;

  /// Explanation of the recommended next step in the biodynamic rotation
  /// (including crop-specific stationary/flexible notes).
  final String rotationGuidance;

  /// Warning message when [hasFamilyConflict] is `true`.
  final String? conflictWarning;

  /// Chronological season-by-season summary badges (e.g. `['2025: Kale (Brassicaceae)', '2026: Carrot (Apiaceae)']`).
  final List<String> seasonTrail;

  /// Creates an immutable [PlotRotationAssessment].
  PlotRotationAssessment({
    required this.plotName,
    this.candidateCrop,
    this.candidateFamily,
    this.sensitivity,
    required this.hasFamilyConflict,
    this.isStaggeredSameSeasonSowing = false,
    this.conflictingBatch,
    this.yearsSinceSameFamily,
    required this.recommendedNextQuality,
    required this.rotationGuidance,
    this.conflictWarning,
    Iterable<String> seasonTrail = const [],
  }) : seasonTrail = List<String>.unmodifiable(seasonTrail);

  /// Classifies the [RotationSensitivity] and effective minimum break years for [crop].
  static (RotationSensitivity sensitivity, int minBreakYears) classifyCrop(
    VegetableEntry crop,
  ) {
    if (crop.lifeCycle == PlantLifeCycle.perennial) {
      return (RotationSensitivity.perennial, 0);
    }
    final genus = crop.scientificName
        .trim()
        .split(RegExp(r'\s+'))
        .first
        .toLowerCase();
    final species = crop.scientificName.toLowerCase();

    // 1. Maria Thun & RHS self-tolerant exceptions:
    // - Tomato (Solanum lycopersicum): Maria Thun demonstrated tomatoes thrive in
    //   the same bed/greenhouse year after year when mulched with tomato-leaf compost
    //   (only conflicting with Potatoes due to shared late blight / nematodes).
    if (species.startsWith('solanum lycopersicum') ||
        crop.id.contains('tomato')) {
      return (RotationSensitivity.selfCompatibleWithCompost, 0);
    }
    // - Runner beans & French/climbing beans (Phaseolus): thrive in permanent
    //   composted bean trenches, unlike Peas (Pisum) and Broad Beans (Vicia) which
    //   suffer from foot/root rot ("pea sickness").
    if (genus == 'phaseolus') {
      return (RotationSensitivity.selfCompatibleWithCompost, 0);
    }

    final family = BotanicalFamily.forCrop(crop);
    return switch (family) {
      // Clubroot (Plasmodiophora brassicae), PCN (Globodera), Allium White Rot (Sclerotium cepivorum)
      BotanicalFamily.brassicaceae ||
      BotanicalFamily.solanaceae ||
      BotanicalFamily.alliaceae => (RotationSensitivity.strict, 3),
      // Pisum (pea) & Vicia (broad bean) foot-rot complex
      BotanicalFamily.fabaceae
          when genus == 'pisum' || genus == 'vicia' || genus == 'lathyrus' =>
        (RotationSensitivity.strict, 3),
      // Nitrogen-fixing clovers, lupins, vetches, soy/chickpea/lentil
      BotanicalFamily.fabaceae => (RotationSensitivity.moderate, 2),
      // Apiaceae (parsnip canker / violet root rot) & Amaranthaceae (beet cyst nematode / downy mildew)
      BotanicalFamily.apiaceae ||
      BotanicalFamily.amaranthaceae => (RotationSensitivity.moderate, 2),
      // Cucurbits, Sweetcorn/Poaceae, Lettuce/Asteraceae do not suffer from
      // persistent home-garden soil cysts and can be rotated flexibly with compost.
      BotanicalFamily.cucurbitaceae ||
      BotanicalFamily.poaceae ||
      BotanicalFamily.asteraceae ||
      BotanicalFamily.rosaceae ||
      BotanicalFamily.other => (RotationSensitivity.flexible, 0),
    };
  }

  static bool _isTomato(VegetableEntry crop) =>
      crop.scientificName.toLowerCase().startsWith('solanum lycopersicum') ||
      crop.id.contains('tomato');

  static bool _isPotato(VegetableEntry crop) =>
      crop.scientificName.toLowerCase().startsWith('solanum tuberosum') ||
      crop.id.contains('potato');

  /// Computes a [PlotRotationAssessment] for [plotName] given all historical and
  /// active [batchesInPlot] (ordered newest-first or arbitrary) and an optional
  /// [candidateCrop] at [referenceTime].
  factory PlotRotationAssessment.evaluate({
    required String plotName,
    required Iterable<PlantingBatchSummary> batchesInPlot,
    VegetableEntry? candidateCrop,
    DateTime? referenceTime,
  }) {
    final sortedChronological =
        batchesInPlot.where((b) => b.deletedHlc == null).toList(growable: false)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final trail = <String>[];
    for (final batch in sortedChronological) {
      final crop = batch.crop;
      final year = batch.timestamp.year;
      final label = crop != null
          ? '$year: ${crop.nameEn} (${BotanicalFamily.forCrop(crop).shortLabel})'
          : '$year: ${batch.title} (${batch.quality.displayName})';
      if (!trail.contains(label)) {
        trail.add(label);
      }
    }

    // Determine recommended next organ quality from the most recent batch in the plot.
    PlantQuality recommendedQuality = PlantQuality.leaf;
    String guidance =
        'Open plot — start rotation with nitrogen-fixing legumes/green manure or compost-fed Leaf/Fruit crops.';
    if (sortedChronological.isNotEmpty) {
      final latest = sortedChronological.last;
      final latestCrop = latest.crop;
      final latestFamily = latestCrop != null
          ? BotanicalFamily.forCrop(latestCrop)
          : null;
      if (latestCrop?.category == PlantCategory.greenManure ||
          (latestFamily?.isNitrogenFixer ?? false)) {
        recommendedQuality = PlantQuality.leaf;
        guidance =
            'Follow nitrogen-fixing ${latestCrop?.nameEn ?? latest.title} with heavy-feeding Leaf (Brassicas/Leeks) or Fruit crops.';
      } else if (latestFamily?.isHeavyFeeder == true ||
          latest.quality == PlantQuality.leaf ||
          latest.quality == PlantQuality.fruit) {
        recommendedQuality = PlantQuality.root;
        guidance =
            'Follow ${latestCrop?.nameEn ?? latest.title} (${latest.quality.displayName}) with Root crops (Earth element) to draw roots deep.';
      } else if (latest.quality == PlantQuality.root) {
        recommendedQuality = PlantQuality.flower;
        guidance =
            'Follow Root crop (${latestCrop?.nameEn ?? latest.title}) with Flower/Herb crops or nitrogen-building Legumes.';
      } else {
        recommendedQuality = PlantQuality.fruit;
        guidance =
            'Follow Flower crop (${latestCrop?.nameEn ?? latest.title}) with legumes/green manure or compost-fed Fruit/Leaf crops.';
      }
    }

    if (candidateCrop == null) {
      return PlotRotationAssessment(
        plotName: plotName,
        hasFamilyConflict: false,
        recommendedNextQuality: recommendedQuality,
        rotationGuidance: guidance,
        seasonTrail: trail,
      );
    }

    final candidateFamily = BotanicalFamily.forCrop(candidateCrop);
    final (sensitivity, minBreakYears) = classifyCrop(candidateCrop);
    final targetYear = (referenceTime ?? DateTime.now()).year;

    PlantingBatchSummary? conflict;
    PlantingBatchSummary? sameCropStationaryMatch;
    int? yearsElapsed;

    for (final batch in sortedChronological.reversed) {
      final prevCrop = batch.crop;
      if (prevCrop == null) continue;
      final prevFamily = BotanicalFamily.forCrop(prevCrop);
      if (prevFamily != candidateFamily) continue;

      final yearDiff = (targetYear - batch.timestamp.year).abs();
      if (yearDiff >= 3) continue;

      // Special case: Tomatoes (Solanum lycopersicum)
      if (_isTomato(candidateCrop)) {
        if (_isPotato(prevCrop)) {
          // Tomato after Potato IS a strict conflict (shared Phytophthora blight & PCN).
          conflict = batch;
          yearsElapsed = yearDiff;
          break;
        }
        if (_isTomato(prevCrop)) {
          sameCropStationaryMatch = batch;
          yearsElapsed = yearDiff;
          break;
        }
        continue;
      }

      // Special case: Potato after Tomato is also a strict blight/nematode conflict.
      if (_isPotato(candidateCrop) && _isTomato(prevCrop)) {
        conflict = batch;
        yearsElapsed = yearDiff;
        break;
      }

      // Special case: Phaseolus (Runner / French beans) are self-compatible in a
      // permanent bean trench.
      if (sensitivity == RotationSensitivity.selfCompatibleWithCompost) {
        sameCropStationaryMatch = batch;
        yearsElapsed = yearDiff;
        break;
      }

      // Within the same growing season (yearDiff == 0):
      // Distinguish staggered interval sowings (Hold-såning of the same short/medium
      // crop, e.g. a second sowing of carrot, spinach, radish, beetroot, or bush beans)
      // from back-to-back relay cropping of different species in a strict family
      // (e.g. Spring Radish followed by Winter Kale).
      if (yearDiff == 0) {
        final maturity = CropMaturityProfile.forCrop(candidateCrop);
        if (prevCrop.id == candidateCrop.id &&
            maturity.supportsStaggeredSowing) {
          sameCropStationaryMatch = batch;
          yearsElapsed = 0;
          break;
        }
        if (minBreakYears > 1 &&
            (prevCrop.id != candidateCrop.id || batch.isHarvested)) {
          conflict = batch;
          yearsElapsed = 0;
          break;
        }
        continue;
      }

      if (minBreakYears > 1 && yearDiff > 0 && yearDiff < minBreakYears) {
        conflict = batch;
        yearsElapsed = yearDiff;
        break;
      }
    }

    final isStaggered =
        conflict == null &&
        sameCropStationaryMatch != null &&
        yearsElapsed == 0 &&
        sameCropStationaryMatch.crop?.id == candidateCrop.id &&
        CropMaturityProfile.forCrop(candidateCrop).supportsStaggeredSowing;

    String? warning;
    if (conflict != null) {
      final prevName = conflict.crop?.nameEn ?? conflict.title;
      final breakRequired = minBreakYears > 1 ? minBreakYears : 3;
      final reason = switch (candidateFamily) {
        BotanicalFamily.brassicaceae => 'to prevent clubroot (Plasmodiophora brassicae), cabbage root fly, and flea beetle buildup',
        BotanicalFamily.solanaceae => 'to prevent potato cyst nematodes (PCN) and shared Phytophthora blight',
        BotanicalFamily.alliaceae =>
          'to prevent persistent allium white rot (Sclerotium cepivorum)',
        BotanicalFamily.fabaceae =>
          'to prevent pea/broad-bean foot & root rot ("pea sickness")',
        _ => 'for root health and disease prevention',
      };
      if (yearsElapsed == 0) {
        warning =
            'Same-Season Relay Alert: Following $prevName with ${candidateCrop.nameEn} (${candidateFamily.shortLabel}) in $plotName within the same season bridges pest and disease cycles — '
            'choose a different family for your relay crop ($reason).';
      } else {
        warning =
            'Rotation Alert: $prevName (${candidateFamily.shortLabel}) grew in $plotName in ${conflict.timestamp.year} (${yearsElapsed}y ago) — '
            'recommend a $breakRequired-year break before planting ${candidateCrop.nameEn} $reason.';
      }
    } else if (isStaggered) {
      final maturity = CropMaturityProfile.forCrop(candidateCrop);
      guidance =
          'Hold-såning (Staggered Sowing): Sowing a follow-up batch of ${candidateCrop.nameEn} in $plotName (~every ${maturity.staggeredIntervalDays} days) extends continuous harvest within the season.';
    } else if (sameCropStationaryMatch != null) {
      if (_isTomato(candidateCrop)) {
        guidance =
            'Maria Thun Stationary Note: ${candidateCrop.nameEn} grew in $plotName in ${sameCropStationaryMatch.timestamp.year}. '
            'Tomatoes thrive in the same bed/greenhouse year after year when mulched with compost from their own healthy haulm and nettle (avoid following Potatoes).';
      } else {
        guidance =
            'Stationary Legume Note: ${candidateCrop.nameEn} (Phaseolus) tolerates repeat planting in the same trench when replenished with mature compost.';
      }
    } else if (sensitivity == RotationSensitivity.flexible) {
      guidance =
          '${candidateCrop.nameEn} (${candidateFamily.shortLabel}) has low soil-borne rotation sensitivity and can be planted in $plotName wherever compost and space allow. $guidance';
    }

    return PlotRotationAssessment(
      plotName: plotName,
      candidateCrop: candidateCrop,
      candidateFamily: candidateFamily,
      sensitivity: sensitivity,
      hasFamilyConflict: conflict != null,
      isStaggeredSameSeasonSowing: isStaggered,
      conflictingBatch: conflict ?? sameCropStationaryMatch,
      yearsSinceSameFamily: yearsElapsed,
      recommendedNextQuality: recommendedQuality,
      rotationGuidance: guidance,
      conflictWarning: warning,
      seasonTrail: trail,
    );
  }
}

/// Agronomic maturity, bed-occupancy duration, and staggered-sowing (*Hold-såning*)
/// profile for a [VegetableEntry].
final class CropMaturityProfile {
  /// Estimated days the crop occupies the bed from sowing/transplanting until clearing.
  final int estimatedDaysInGround;

  /// Typical indoor/module nursery lead time in days before outdoor transplanting (`0` if direct-sown only).
  final int moduleLeadTimeDays;

  /// Whether this crop is suitable for staggered interval sowings (*Hold-såning*)
  /// in the same bed within a single season.
  final bool supportsStaggeredSowing;

  /// Recommended interval in days between staggered sowings when [supportsStaggeredSowing] is `true`.
  final int staggeredIntervalDays;

  /// Creates an immutable [CropMaturityProfile].
  const CropMaturityProfile({
    required this.estimatedDaysInGround,
    this.moduleLeadTimeDays = 0,
    this.supportsStaggeredSowing = false,
    this.staggeredIntervalDays = 14,
  });

  /// Derives a [CropMaturityProfile] for [crop].
  static CropMaturityProfile forCrop(VegetableEntry crop) {
    if (crop.lifeCycle == PlantLifeCycle.perennial) {
      return const CropMaturityProfile(
        estimatedDaysInGround: 365,
        moduleLeadTimeDays: 0,
        supportsStaggeredSowing: false,
      );
    }

    final id = crop.id;
    final hasIndoorStart =
        crop.indoorSowingMonths.isNotEmpty && crop.transplantMonths.isNotEmpty;
    final defaultLeadTime = hasIndoorStart ? 28 : 0;

    // 1. Fast catch-crops (30–50 days) with 14-day staggered Hold-såning
    if (const {
      'radish',
      'spinach',
      'lettuce',
      'romaine_lettuce',
      'arugula',
      'cress',
      'coriander',
      'dill',
      'pak_choi',
      'mizuna',
      'lambs_lettuce',
      'winter_purslane',
    }.contains(id)) {
      return CropMaturityProfile(
        estimatedDaysInGround: id == 'radish' ? 32 : 45,
        moduleLeadTimeDays: hasIndoorStart ? 21 : 0,
        supportsStaggeredSowing: true,
        staggeredIntervalDays: 14,
      );
    }

    // 2. Medium-short crops (55–75 days) with 14–21 day staggered sowing
    if (const {
      'turnip',
      'kohlrabi',
      'bush_bean',
      'spring_onion',
      'pea',
      'sugar_snap_pea',
      'snow_pea',
      'fennel',
      'swiss_chard',
      'beetroot',
      'carrot',
    }.contains(id)) {
      return CropMaturityProfile(
        estimatedDaysInGround: (id == 'carrot' || id == 'beetroot') ? 75 : 60,
        moduleLeadTimeDays: hasIndoorStart ? 24 : 0,
        supportsStaggeredSowing: true,
        staggeredIntervalDays: 21,
      );
    }

    // 3. Medium-season maincrops (75–95 days)
    if (const {
      'pointed_cabbage',
      'broccoli',
      'cauliflower',
      'romanesco',
      'courgette',
      'cucumber',
      'sweetcorn',
      'broad_bean',
      'runner_bean',
      'climbing_bean',
    }.contains(id)) {
      return CropMaturityProfile(
        estimatedDaysInGround: 85,
        moduleLeadTimeDays: defaultLeadTime,
        supportsStaggeredSowing: false,
      );
    }

    // 4. Long-season & overwintering maincrops (110–150 days)
    return CropMaturityProfile(
      estimatedDaysInGround: 115,
      moduleLeadTimeDays: defaultLeadTime,
      supportsStaggeredSowing: false,
    );
  }

  /// Estimates the date when [batch] will finish harvesting and release the plot.
  static DateTime estimateClearingDate(PlantingBatchSummary batch) {
    final crop = batch.crop;
    if (crop == null) {
      return batch.timestamp.add(const Duration(days: 75));
    }
    final profile = forCrop(crop);
    // Transplanting starts with seedlings already raised for moduleLeadTimeDays.
    final effectiveDays =
        batch.action == FieldJournalAction.transplant &&
            profile.moduleLeadTimeDays > 0
        ? (profile.estimatedDaysInGround - (profile.moduleLeadTimeDays ~/ 2))
              .clamp(25, 365)
        : profile.estimatedDaysInGround;
    return batch.timestamp.add(Duration(days: effectiveDays));
  }
}

/// How a [PlotSuccessionCandidate] fits into a plot's current season timeline.
enum SuccessionStage {
  ///Sow another batch of an active short/medium-cycle crop (*Hold-såning*).
  staggeredNextBatch(label: 'Hold-såning (Next Batch)', glyph: '🔁'),

  /// Start seedlings in module trays now so they are ready to transplant as soon
  /// as the current crop in the plot is harvested.
  startInModulesNow(label: 'Start in Modules for Relay', glyph: '🪴'),

  /// Direct-sow or transplant immediately into an open or newly harvested plot.
  directRelayNow(label: 'Relay in Plot Now', glyph: '🌱');

  /// Display label.
  final String label;

  /// Compact emoji glyph.
  final String glyph;

  const SuccessionStage({required this.label, required this.glyph});
}

/// A recommended follow-up or staggered succession crop for a [GardenPlot].
final class PlotSuccessionCandidate {
  /// Target crop from [VegetableDatabase].
  final VegetableEntry crop;

  /// How this candidate enters the plot (`staggeredNextBatch`, `startInModulesNow`, `directRelayNow`).
  final SuccessionStage stage;

  /// Task planner action to queue when selected (`sowIndoor`, `sowOutdoor`, or `transplant`).
  final TaskActionType taskAction;

  /// Date when the plot is expected to be ready for this crop.
  final DateTime targetPlotDate;

  /// Human-readable explanation of why this succession crop fits the plot now.
  final String reason;

  /// Creates an immutable [PlotSuccessionCandidate].
  const PlotSuccessionCandidate({
    required this.crop,
    required this.stage,
    required this.taskAction,
    required this.targetPlotDate,
    required this.reason,
  });

  /// Compact chip label for UI display.
  String get badgeLabel => switch (stage) {
    SuccessionStage.staggeredNextBatch =>
      '${stage.glyph} Hold-såning: ${crop.nameEn}',
    SuccessionStage.startInModulesNow =>
      '${stage.glyph} Start in Modules: ${crop.nameEn}',
    SuccessionStage.directRelayNow =>
      '${stage.glyph} ${taskAction == TaskActionType.transplant ? "Transplant" : "Sow"}: ${crop.nameEn}',
  };
}

/// Complete within-season succession plan for a [GardenPlot], combining harvested
/// spring/summer crops, active crops with estimated clearing dates, and relay or
/// staggered (*Hold-såning*) candidates.
final class PlotSuccessionPlan {
  /// Target plot.
  final GardenPlot plot;

  /// Batches already harvested in [referenceTime.year] in this plot.
  final List<PlantingBatchSummary> harvestedThisSeason;

  /// Batches currently active in the ground in this plot.
  final List<PlantingBatchSummary> activeInGround;

  /// Estimated date when the plot becomes open for a relay crop (equals [referenceTime] if already open).
  final DateTime estimatedAvailableDate;

  /// Ranked succession candidates (staggered sowings, module pre-starts, or immediate relays).
  final List<PlotSuccessionCandidate> candidates;

  /// Concise one-line summary of the plot's Spring → Summer → Autumn pipeline in the current year.
  final String seasonPipelineSummary;

  /// Creates an immutable [PlotSuccessionPlan].
  PlotSuccessionPlan({
    required this.plot,
    required Iterable<PlantingBatchSummary> harvestedThisSeason,
    required Iterable<PlantingBatchSummary> activeInGround,
    required this.estimatedAvailableDate,
    required Iterable<PlotSuccessionCandidate> candidates,
    required this.seasonPipelineSummary,
  }) : harvestedThisSeason = List<PlantingBatchSummary>.unmodifiable(
         harvestedThisSeason,
       ),
       activeInGround = List<PlantingBatchSummary>.unmodifiable(activeInGround),
       candidates = List<PlotSuccessionCandidate>.unmodifiable(candidates);

  static const List<String> _monthShort = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Builds a [PlotSuccessionPlan] for [plot] at [referenceTime].
  factory PlotSuccessionPlan.build({
    required GardenPlot plot,
    required Iterable<PlantingBatchSummary> batchesInPlot,
    required DateTime referenceTime,
    Set<String> starredCropIds = const <String>{},
  }) {
    final validBatches =
        batchesInPlot.where((b) => b.deletedHlc == null).toList(growable: false)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final currentYear = referenceTime.year;
    final harvestedThisYear = validBatches
        .where((b) => b.timestamp.year == currentYear && b.isHarvested)
        .toList(growable: false);
    final active = validBatches
        .where((b) => b.isActiveInGround)
        .toList(growable: false);

    // Compute when the plot (or a relay slot in the plot) will clear.
    DateTime availableDate = referenceTime;
    if (active.isNotEmpty) {
      final clearingDates =
          active
              .map(CropMaturityProfile.estimateClearingDate)
              .toList(growable: false)
            ..sort();
      // Earliest clearing batch frees the first relay slot in the bed.
      if (clearingDates.first.isAfter(referenceTime)) {
        availableDate = clearingDates.first;
      }
    }

    // Build season pipeline summary string for the current year.
    final stages = <String>[];
    for (final h in harvestedThisYear) {
      final name = h.crop?.nameEn ?? h.title;
      stages.add('✓ $name (${_monthShort[h.timestamp.month]})');
    }
    for (final a in active) {
      final name = a.crop?.nameEn ?? a.title;
      final clearDate = CropMaturityProfile.estimateClearingDate(a);
      stages.add(
        '🌱 $name (${_monthShort[a.timestamp.month]}→~${_monthShort[clearDate.month]})',
      );
    }

    final baseRotation = PlotRotationAssessment.evaluate(
      plotName: plot.name,
      batchesInPlot: validBatches,
      referenceTime: referenceTime,
    );

    final candidates = <PlotSuccessionCandidate>[];
    final seenCropIds = <String>{};

    // 1. Check active batches for Staggered Interval Sowing (Hold-såning)
    for (final batch in active) {
      final crop = batch.crop;
      if (crop == null || !seenCropIds.add(crop.id)) continue;
      final maturity = CropMaturityProfile.forCrop(crop);
      if (maturity.supportsStaggeredSowing &&
          crop.sowingMonths.contains(referenceTime.month)) {
        final nextSowDate = batch.timestamp.add(
          Duration(days: maturity.staggeredIntervalDays),
        );
        candidates.add(
          PlotSuccessionCandidate(
            crop: crop,
            stage: SuccessionStage.staggeredNextBatch,
            taskAction: TaskActionType.sowOutdoor,
            targetPlotDate: nextSowDate.isAfter(referenceTime)
                ? nextSowDate
                : referenceTime,
            reason:
                'Hold-såning: sow next staggered batch of ${crop.nameEn} in ${plot.name} (~${maturity.staggeredIntervalDays}d interval)',
          ),
        );
      }
    }

    // 2. If plot has active crops clearing within 45 days, find module-start relay crops
    //    OR if plot is already open/clearing now, find direct relay crops.
    final daysUntilClear = availableDate.difference(referenceTime).inDays;
    final targetMonth = availableDate.month;
    final currentMonth = referenceTime.month;

    bool monthMatchesWithProtection(List<int> months, int month) {
      if (months.contains(month)) return true;
      if (!plot.plotType.isProtectedEnvironment) return false;
      final prevMonth = month == 1 ? 12 : month - 1;
      final nextMonth = month == 12 ? 1 : month + 1;
      return months.contains(prevMonth) || months.contains(nextMonth);
    }

    final allCrops = VegetableDatabase.allEntries;
    final scoredRelay = <(int score, PlotSuccessionCandidate candidate)>[];

    for (final crop in allCrops) {
      if (seenCropIds.contains(crop.id)) continue;
      if (crop.lifeCycle == PlantLifeCycle.perennial) continue;

      final assessment = PlotRotationAssessment.evaluate(
        plotName: plot.name,
        batchesInPlot: validBatches,
        candidateCrop: crop,
        referenceTime: availableDate,
      );
      if (assessment.hasFamilyConflict) continue;

      PlotSuccessionCandidate? candidate;
      if (active.isNotEmpty && daysUntilClear > 7 && daysUntilClear <= 45) {
        // Plot is occupied now but clearing soon -> look for crops to start in modules now
        // for transplanting when the bed clears, or direct-sow at clearing time.
        if (monthMatchesWithProtection(crop.transplantMonths, targetMonth) &&
            (crop.indoorSowingMonths.contains(currentMonth) ||
                crop.sowingMonths.contains(currentMonth))) {
          candidate = PlotSuccessionCandidate(
            crop: crop,
            stage: SuccessionStage.startInModulesNow,
            taskAction: TaskActionType.sowIndoor,
            targetPlotDate: availableDate,
            reason:
                'Start ${crop.nameEn} in modules now to transplant into ${plot.name} when bed clears (~${_monthShort[targetMonth]})',
          );
        }
      } else if (active.isEmpty || daysUntilClear <= 7) {
        // Plot is open now (or clearing within a week) -> direct sow or transplant now!
        if (monthMatchesWithProtection(crop.transplantMonths, currentMonth)) {
          candidate = PlotSuccessionCandidate(
            crop: crop,
            stage: SuccessionStage.directRelayNow,
            taskAction: TaskActionType.transplant,
            targetPlotDate: referenceTime,
            reason:
                'Transplant ${crop.nameEn} into ${plot.name} (${crop.quality.displayName} succession)',
          );
        } else if (monthMatchesWithProtection(
          crop.sowingMonths,
          currentMonth,
        )) {
          candidate = PlotSuccessionCandidate(
            crop: crop,
            stage: SuccessionStage.directRelayNow,
            taskAction: TaskActionType.sowOutdoor,
            targetPlotDate: referenceTime,
            reason:
                'Direct-sow ${crop.nameEn} into ${plot.name} (${crop.quality.displayName} succession)',
          );
        }
      }

      if (candidate == null) continue;

      int score = 0;
      if (starredCropIds.contains(crop.id)) score += 30;
      if (crop.quality == baseRotation.recommendedNextQuality) score += 20;
      if (currentMonth >= 8 && crop.category == PlantCategory.greenManure) {
        score += 25;
      }
      if (candidate.stage == SuccessionStage.startInModulesNow) score += 15;
      scoredRelay.add((score, candidate));
    }

    scoredRelay.sort((a, b) => b.$1.compareTo(a.$1));
    for (final item in scoredRelay.take(5)) {
      if (seenCropIds.add(item.$2.crop.id)) {
        candidates.add(item.$2);
      }
    }

    return PlotSuccessionPlan(
      plot: plot,
      harvestedThisSeason: harvestedThisYear,
      activeInGround: active,
      estimatedAvailableDate: availableDate,
      candidates: candidates,
      seasonPipelineSummary: stages.join(' → '),
    );
  }
}
