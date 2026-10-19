import 'package:flutter/material.dart';

import '../models/models.dart';
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

  /// Previous planting batch in [plotName] that triggered [hasFamilyConflict]
  /// or triggered a self-compatible compost note.
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
      final isPriorCrop =
          (yearDiff > 0 && yearDiff < 3) ||
          (yearDiff == 0 && batch.isHarvested);
      if (!isPriorCrop) continue;

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

      if (minBreakYears > 1 &&
          ((yearDiff > 0 && yearDiff < minBreakYears) ||
              (yearDiff == 0 && batch.isHarvested))) {
        conflict = batch;
        yearsElapsed = yearDiff;
        break;
      }
    }

    String? warning;
    if (conflict != null) {
      final prevName = conflict.crop?.nameEn ?? conflict.title;
      final whenLabel = yearsElapsed == 0
          ? 'earlier in ${conflict.timestamp.year}'
          : 'in ${conflict.timestamp.year} (${yearsElapsed}y ago)';
      final breakRequired = minBreakYears > 1 ? minBreakYears : 3;
      final reason = switch (candidateFamily) {
        BotanicalFamily.brassicaceae => 'to prevent clubroot (Plasmodiophora brassicae) and brassica pest buildup',
        BotanicalFamily.solanaceae => 'to prevent potato cyst nematodes (PCN) and shared Phytophthora blight',
        BotanicalFamily.alliaceae =>
          'to prevent persistent allium white rot (Sclerotium cepivorum)',
        BotanicalFamily.fabaceae =>
          'to prevent pea/broad-bean foot & root rot ("pea sickness")',
        _ => 'for root health and disease prevention',
      };
      warning =
          'Rotation Alert: $prevName (${candidateFamily.shortLabel}) grew in $plotName $whenLabel — '
          'recommend a $breakRequired-year break before planting ${candidateCrop.nameEn} $reason.';
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
      conflictingBatch: conflict ?? sameCropStationaryMatch,
      yearsSinceSameFamily: yearsElapsed,
      recommendedNextQuality: recommendedQuality,
      rotationGuidance: guidance,
      conflictWarning: warning,
      seasonTrail: trail,
    );
  }
}
