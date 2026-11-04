import 'package:flutter/material.dart';

import '../models/models.dart';
import '../task_window_planner.dart';
import '../vegetable_database.dart';
import 'field_journal_entry.dart';
import 'garden_profile.dart';

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
      deletedHlc!.isNotEmpty &&
      (updatedHlc == null ||
          updatedHlc!.isEmpty ||
          deletedHlc!.compareTo(updatedHlc!) >= 0);

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

  /// Serializes this [GardenPlot] to a JSON map.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    if (areaName.isNotEmpty) 'areaName': areaName,
    'plotType': plotType.name,
    if (dimensions.isNotEmpty) 'dimensions': dimensions,
    if (notes.isNotEmpty) 'notes': notes,
    if (lastSoilPrepSummary != null) 'lastSoilPrepSummary': lastSoilPrepSummary,
    if (lastSoilPrepTimestamp != null)
      'lastSoilPrepTimestamp': lastSoilPrepTimestamp!.toUtc().toIso8601String(),
    if (updatedHlc != null) 'updatedHlc': updatedHlc,
    if (deletedHlc != null) 'deletedHlc': deletedHlc,
  };

  /// Deserializes a [GardenPlot] from [json].
  ///
  /// Throws a [FormatException] if `name` is missing or empty.
  factory GardenPlot.fromJson(Map<String, Object?> json) {
    final nameRaw = json['name'];
    if (nameRaw is! String || nameRaw.trim().isEmpty) {
      throw const FormatException('GardenPlot requires a non-empty name');
    }
    final typeRaw = json['plotType'];
    GardenPlotType parsedType = GardenPlotType.openBed;
    if (typeRaw is String) {
      for (final candidate in GardenPlotType.values) {
        if (candidate.name == typeRaw) {
          parsedType = candidate;
          break;
        }
      }
    }
    final prepTimeRaw = json['lastSoilPrepTimestamp'];
    return GardenPlot(
      name: nameRaw.trim(),
      areaName: json['areaName'] is String ? json['areaName'] as String : '',
      plotType: parsedType,
      dimensions: json['dimensions'] is String
          ? json['dimensions'] as String
          : '',
      notes: json['notes'] is String ? json['notes'] as String : '',
      lastSoilPrepSummary: json['lastSoilPrepSummary'] is String
          ? json['lastSoilPrepSummary'] as String
          : null,
      lastSoilPrepTimestamp: prepTimeRaw is String
          ? DateTime.tryParse(prepTimeRaw)
          : null,
      updatedHlc: json['updatedHlc'] is String
          ? json['updatedHlc'] as String
          : null,
      deletedHlc: json['deletedHlc'] is String
          ? json['deletedHlc'] as String
          : null,
    );
  }

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
        batchesInPlot.where((b) => !b.isDeleted).toList(growable: false)
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
    final effectiveRefTime = referenceTime ?? DateTime.now();
    final targetYear = effectiveRefTime.year;
    final maxBreakWindow = minBreakYears > 3 ? minBreakYears : 3;

    PlantingBatchSummary? conflict;
    PlantingBatchSummary? sameCropStationaryMatch;
    int? yearsElapsed;

    for (final batch in sortedChronological.reversed) {
      if (batch.timestamp.year > targetYear) continue;
      final prevCrop = batch.crop;
      if (prevCrop == null) continue;
      final prevFamily = BotanicalFamily.forCrop(prevCrop);
      if (prevFamily != candidateFamily) continue;

      final yearDiff = targetYear - batch.timestamp.year;
      if (yearDiff >= maxBreakWindow) continue;

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

      // Within the same growing season (yearDiff == 0) or across the Dec -> Jan
      // New Year boundary within <= 60 days:
      // Distinguish staggered interval sowings (Hold-såning of the same short/medium
      // crop, e.g. a second sowing of carrot, spinach, radish, beetroot, or bush beans)
      // from back-to-back relay cropping of different species in a strict family
      // (e.g. Spring Radish followed by Winter Kale).
      final daysDelta = effectiveRefTime
          .difference(batch.timestamp)
          .inDays
          .abs();
      final isCrossYearStaggered =
          yearDiff == 1 &&
          daysDelta <= 60 &&
          prevCrop.id == candidateCrop.id &&
          CropMaturityProfile.forCrop(candidateCrop).supportsStaggeredSowing;
      if (yearDiff == 0 || isCrossYearStaggered) {
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
      final intervalDays = maturity.seasonalStaggeredIntervalDays(
        (referenceTime ?? DateTime.now()).month,
      );
      guidance =
          'Hold-såning (Staggered Sowing): Sowing a follow-up batch of ${candidateCrop.nameEn} in $plotName (~every $intervalDays days) extends continuous harvest within the season.';
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
/// profile for a [VegetableEntry], with Nordic seasonal adjustments for daylength,
/// propagation temperature, and overwintering across the *Persephone period*.
final class CropMaturityProfile {
  /// Baseline days the crop occupies the bed in mid-spring (April/May) from
  /// sowing/transplanting until clearing.
  final int estimatedDaysInGround;

  /// Baseline indoor/module nursery lead time in days in mid-spring (April/May)
  /// before outdoor transplanting (`0` if direct-sown only).
  final int moduleLeadTimeDays;

  /// Whether this crop is suitable for staggered interval sowings (*Hold-såning*)
  /// in the same bed within a single season.
  final bool supportsStaggeredSowing;

  /// Baseline recommended interval in days between staggered sowings when
  /// [supportsStaggeredSowing] is `true`.
  final int staggeredIntervalDays;

  /// Whether this crop is a multi-year perennial occupying the bed across seasons.
  final bool isPerennial;

  /// Creates an immutable [CropMaturityProfile].
  const CropMaturityProfile({
    required this.estimatedDaysInGround,
    this.moduleLeadTimeDays = 0,
    this.supportsStaggeredSowing = false,
    this.staggeredIntervalDays = 14,
    this.isPerennial = false,
  });

  /// Returns the season-adjusted indoor/module nursery lead time in days when
  /// sown in [propagationMonth] (`1` = January .. `12` = December).
  ///
  /// Accounts for the Nordic 55°N daylength and propagation temperature curve:
  /// - **Jan–Feb (`1.55×`)**: Low light near the *Persephone period* slows seedling root fill.
  /// - **Mar (`1.35×`)**: Cool early-spring glasshouse/windowsill propagation (~4–6 weeks).
  /// - **Apr (`1.05×`) / May (`0.90×`)**: Standard spring nursery baseline (~3–4 weeks).
  /// - **Jun–Jul (`0.70×`)**: Peak 17h daylight and 18–22 °C warmth; module plugs are ready in 14–20 days.
  /// - **Aug (`0.85×`)**: Warm soil with shortening late-summer days.
  /// - **Sep (`1.15×`) / Oct–Dec (`1.45×`)**: Rapidly shortening autumn daylight.
  int seasonalModuleLeadTimeDays(int propagationMonth) {
    if (moduleLeadTimeDays <= 0) return 0;
    final m = propagationMonth.clamp(1, 12);
    final factor = switch (m) {
      1 || 2 => 1.55,
      3 => 1.35,
      4 => 1.05,
      5 => 0.90,
      6 || 7 => 0.70,
      8 => 0.85,
      9 => 1.15,
      _ => 1.45,
    };
    return (moduleLeadTimeDays * factor).round().clamp(10, 75);
  }

  /// Returns the season-adjusted staggered sowing (*Hold-såning*) interval in days
  /// for [sowingMonth].
  int seasonalStaggeredIntervalDays(int sowingMonth) {
    if (!supportsStaggeredSowing) return staggeredIntervalDays;
    final m = sowingMonth.clamp(1, 12);
    final factor = switch (m) {
      <= 3 => 1.25,
      4 || 5 => 1.0,
      6 || 7 => 0.85,
      8 => 1.15,
      _ => 1.30,
    };
    return (staggeredIntervalDays * factor).round().clamp(10, 35);
  }

  /// Returns the season-adjusted days in the ground for a within-season crop
  /// planted in [plantingMonth], accounting for faster midsummer growth and slower
  /// early-spring / autumn maturity.
  int seasonalDaysInGround(
    int plantingMonth, {
    FieldJournalAction action = FieldJournalAction.sowSeeds,
  }) {
    final m = plantingMonth.clamp(1, 12);
    final seasonFactor = switch (m) {
      <= 3 => 1.20,
      4 => 1.05,
      5 => 0.95,
      6 || 7 => 0.82,
      8 => 1.05,
      _ => 1.25,
    };
    final scaledGroundDays = (estimatedDaysInGround * seasonFactor).round();
    if (action == FieldJournalAction.transplant && moduleLeadTimeDays > 0) {
      // Seedlings were raised in modules for roughly the preceding month's lead time.
      final priorMonth = m == 1 ? 12 : m - 1;
      final nurseryCredit = (seasonalModuleLeadTimeDays(priorMonth) * 0.55)
          .round();
      return (scaledGroundDays - nurseryCredit).clamp(20, 365);
    }
    return scaledGroundDays.clamp(20, 365);
  }

  /// Derives a [CropMaturityProfile] for [crop].
  static CropMaturityProfile forCrop(VegetableEntry crop) {
    if (crop.lifeCycle == PlantLifeCycle.perennial) {
      return const CropMaturityProfile(
        estimatedDaysInGround: 365 * 3,
        moduleLeadTimeDays: 0,
        supportsStaggeredSowing: false,
        isPerennial: true,
      );
    }

    final id = crop.id;
    final hasIndoorStart =
        crop.indoorSowingMonths.isNotEmpty && crop.transplantMonths.isNotEmpty;
    final isLongNurseryCrop = const {
      'tomato',
      'cherry_tomato',
      'pepper',
      'chili_pepper',
      'aubergine',
      'celeriac',
      'celery',
      'leek',
      'onion',
      'shallot',
    }.contains(id);
    final defaultLeadTime = hasIndoorStart ? (isLongNurseryCrop ? 35 : 28) : 0;

    // 1. Fast catch-crops (30–50 days baseline) with 14-day staggered Hold-såning
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

    // 2. Medium-short crops (55–75 days baseline) with 21-day staggered sowing
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

    // 3. Medium-season maincrops (75–95 days baseline)
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

    // 4. Long-season & overwintering maincrops (115 days baseline)
    return CropMaturityProfile(
      estimatedDaysInGround: 115,
      moduleLeadTimeDays: defaultLeadTime,
      supportsStaggeredSowing: false,
    );
  }

  /// Whether [crop] planted in [plantingMonth] overwinters through the Nordic
  /// *Persephone period* (<10h daylight from Nov–Feb) and clears the plot in spring/summer
  /// of the following year.
  static bool isOverwinteringPlanting(VegetableEntry crop, int plantingMonth) {
    if (plantingMonth < 8 || plantingMonth > 12) return false;
    final id = crop.id;
    // Autumn-planted alliums (autumn garlic, overwintering onion/shallot sets)
    if (const {
          'autumn_garlic',
          'garlic',
          'autumn_onion',
          'onion',
          'shallot',
        }.contains(id) &&
        plantingMonth >= 8) {
      return true;
    }
    // Overwintering green manures & cover crops sown Aug–Dec
    if (crop.category == PlantCategory.greenManure &&
        const {
          'winter_rye',
          'hairy_vetch',
          'crimson_clover',
          'winter_field_bean',
        }.contains(id)) {
      return true;
    }
    // Hardy overwintering brassicas & leeks planted Aug–Oct
    if (const {
      'kale',
      'brussels_sprouts',
      'savoy_cabbage',
      'purple_sprouting_broccoli',
      'leek',
    }.contains(id)) {
      return true;
    }
    // Hardy winter salads & autumn broad beans sown Sep–Dec
    if (plantingMonth >= 9 &&
        const {
          'lambs_lettuce',
          'winter_purslane',
          'spinach',
          'swiss_chard',
          'broad_bean',
        }.contains(id)) {
      return true;
    }
    // Structural check: planted in Aug–Dec while harvest window is in spring/summer (Jan–Jun)
    if (crop.harvestMonths.isNotEmpty &&
        crop.harvestMonths.any((m) => m >= 1 && m <= 6) &&
        !crop.harvestMonths.any((m) => m > plantingMonth && m <= 12)) {
      return true;
    }
    return false;
  }

  /// Estimates the date when [crop] planted at [plantedAt] will finish harvesting
  /// and release the plot, accounting for seasonal growth speed, transplant nursery
  /// credit, and *Persephone period* overwintering.
  static DateTime estimateClearingDateForCrop({
    required VegetableEntry? crop,
    required DateTime plantedAt,
    bool isTransplant = false,
  }) {
    if (crop == null) {
      return plantedAt.add(const Duration(days: 75));
    }

    if (crop.lifeCycle == PlantLifeCycle.perennial) {
      return DateTime.utc(
        plantedAt.year + 3,
        plantedAt.month,
        plantedAt.day,
        12,
      );
    }

    if (isOverwinteringPlanting(crop, plantedAt.month)) {
      final nextYear = plantedAt.year + 1;
      if (const {
        'autumn_garlic',
        'garlic',
        'autumn_onion',
        'onion',
        'shallot',
      }.contains(crop.id)) {
        return DateTime.utc(nextYear, 7, 10, 12);
      }
      if (crop.id == 'broad_bean') {
        return DateTime.utc(nextYear, 6, 15, 12);
      }
      if (crop.category == PlantCategory.greenManure ||
          const {
            'lambs_lettuce',
            'winter_purslane',
            'spinach',
          }.contains(crop.id)) {
        return DateTime.utc(nextYear, 4, 10, 12);
      }
      // Hardy overwintering brassicas and leeks clear around mid/late April.
      return DateTime.utc(nextYear, 4, 20, 12);
    }

    final profile = forCrop(crop);
    final effectiveDays = profile.seasonalDaysInGround(
      plantedAt.month,
      action: isTransplant
          ? FieldJournalAction.transplant
          : FieldJournalAction.sowSeeds,
    );
    return plantedAt.add(Duration(days: effectiveDays));
  }

  /// Estimates the date when [batch] will finish harvesting and release the plot,
  /// accounting for seasonal growth speed and *Persephone period* overwintering.
  static DateTime estimateClearingDate(PlantingBatchSummary batch) =>
      estimateClearingDateForCrop(
        crop: batch.crop,
        plantedAt: batch.timestamp,
        isTransplant: batch.action == FieldJournalAction.transplant,
      );
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

  /// Season-adjusted indoor/module nursery lead time in days when [stage] is
  /// [SuccessionStage.startInModulesNow] (`null` for direct sowings or immediate transplants).
  final int? nurseryLeadDays;

  /// Human-readable explanation of why this succession crop fits the plot now.
  final String reason;

  /// Creates an immutable [PlotSuccessionCandidate].
  const PlotSuccessionCandidate({
    required this.crop,
    required this.stage,
    required this.taskAction,
    required this.targetPlotDate,
    this.nurseryLeadDays,
    required this.reason,
  });

  /// Compact chip label for UI display.
  String get badgeLabel => switch (stage) {
    SuccessionStage.staggeredNextBatch =>
      '${stage.glyph} Hold-såning: ${crop.nameEn}',
    SuccessionStage.startInModulesNow =>
      nurseryLeadDays != null
          ? '${stage.glyph} Start in Modules (~${nurseryLeadDays}d): ${crop.nameEn}'
          : '${stage.glyph} Start in Modules: ${crop.nameEn}',
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
    Iterable<QueuedGardenTask> tasksInPlot = const <QueuedGardenTask>[],
    required DateTime referenceTime,
    Set<String> starredCropIds = const <String>{},
  }) {
    final validBatches =
        batchesInPlot.where((b) => !b.isDeleted).toList(growable: false)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final plannedTasks =
        tasksInPlot
            .where((t) => t.plannedStartDate != null)
            .toList(growable: false)
          ..sort((a, b) => a.plannedStartDate!.compareTo(b.plannedStartDate!));

    final currentYear = referenceTime.year;
    final harvestedThisYear = validBatches
        .where(
          (b) =>
              b.isHarvested &&
              (b.timestamp.year == currentYear ||
                  CropMaturityProfile.estimateClearingDate(b).year ==
                      currentYear),
        )
        .toList(growable: false);
    final active = validBatches
        .where((b) => b.isActiveInGround)
        .toList(growable: false);

    // Compute when the plot (or a relay slot in the plot) will clear.
    DateTime availableDate = referenceTime;
    final clearingDates = <DateTime>[
      ...active.map(CropMaturityProfile.estimateClearingDate),
      for (final task in plannedTasks)
        if (!task.plannedStartDate!.isAfter(referenceTime))
          ?task.effectiveEndDate,
    ]..sort();
    for (final clearDate in clearingDates) {
      if (clearDate.isAfter(referenceTime)) {
        availableDate = clearDate;
        break;
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
      final clearLabel = clearDate.year > a.timestamp.year
          ? '${_monthShort[clearDate.month]} \'${clearDate.year % 100}'
          : _monthShort[clearDate.month];
      stages.add('🌱 $name (${_monthShort[a.timestamp.month]}→~$clearLabel)');
    }
    for (final t in plannedTasks) {
      final start = t.plannedStartDate!;
      final end = t.effectiveEndDate ?? start.add(const Duration(days: 60));
      final name = t.crop?.nameEn ?? t.targetLabel;
      final endLabel = end.year > start.year
          ? '${_monthShort[end.month]} \'${end.year % 100}'
          : _monthShort[end.month];
      stages.add('📅 $name (${_monthShort[start.month]}→~$endLabel)');
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
        final intervalDays = maturity.seasonalStaggeredIntervalDays(
          referenceTime.month,
        );
        final nextSowDate = batch.timestamp.add(Duration(days: intervalDays));
        candidates.add(
          PlotSuccessionCandidate(
            crop: crop,
            stage: SuccessionStage.staggeredNextBatch,
            taskAction: TaskActionType.sowOutdoor,
            targetPlotDate: nextSowDate.isAfter(referenceTime)
                ? nextSowDate
                : referenceTime,
            reason:
                'Hold-såning: sow next staggered batch of ${crop.nameEn} in ${plot.name} (~${intervalDays}d seasonal interval)',
          ),
        );
      }
    }

    // 2. If plot has active crops clearing soon, find module-start relay crops
    //    whose seasonal nursery lead time matches daysUntilClear,
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

      final cropMaturity = CropMaturityProfile.forCrop(crop);
      final seasonalLeadDays = cropMaturity.seasonalModuleLeadTimeDays(
        currentMonth,
      );

      PlotSuccessionCandidate? candidate;
      if (active.isNotEmpty &&
          seasonalLeadDays > 0 &&
          daysUntilClear > 7 &&
          daysUntilClear >= (seasonalLeadDays - 14).clamp(7, 60) &&
          daysUntilClear <= seasonalLeadDays + 16) {
        // Plot is occupied now and clearing right around when seedlings started
        // in modules this month will be ready to transplant out.
        if (monthMatchesWithProtection(crop.transplantMonths, targetMonth) &&
            (crop.indoorSowingMonths.contains(currentMonth) ||
                crop.sowingMonths.contains(currentMonth))) {
          candidate = PlotSuccessionCandidate(
            crop: crop,
            stage: SuccessionStage.startInModulesNow,
            taskAction: TaskActionType.sowIndoor,
            targetPlotDate: availableDate,
            nurseryLeadDays: seasonalLeadDays,
            reason:
                'Start ${crop.nameEn} in modules now (~${seasonalLeadDays}d nursery in ${_monthShort[currentMonth]}) to transplant into ${plot.name} when bed clears (~${_monthShort[targetMonth]})',
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
      if (candidate.stage == SuccessionStage.startInModulesNow) {
        score += 15;
        // Bonus when the crop's seasonal module lead time closely matches daysUntilClear.
        if ((daysUntilClear - seasonalLeadDays).abs() <= 7) {
          score += 10;
        }
      }
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

/// Lifecycle stage of a [BedTimelineSpan] on a [GardenPlot]'s succession timeline.
enum BedTimelineSpanKind {
  /// A batch that has already been harvested.
  harvested(label: 'Harvested', glyph: '✓'),

  /// A batch currently growing in the ground.
  activeInGround(label: 'In Ground', glyph: '🌱'),

  /// A future or scheduled succession planting placed on the bed.
  planned(label: 'Planned', glyph: '📅');

  /// Display label.
  final String label;

  /// Compact status glyph.
  final String glyph;

  const BedTimelineSpanKind({required this.label, required this.glyph});
}

/// A single time-bounded occupancy bar on a [GardenPlot] timeline.
final class BedTimelineSpan {
  /// Unique span identifier (`entryId` for batches, `task.id` for planned tasks).
  final String id;

  /// Name of the plot/bed this span belongs to.
  final String bedName;

  /// Lifecycle state of this span (`harvested`, `activeInGround`, or `planned`).
  final BedTimelineSpanKind kind;

  /// Associated [VegetableEntry], if known.
  final VegetableEntry? crop;

  /// Display title of the crop or planting.
  final String title;

  /// Biodynamic organ quality of this planting.
  final PlantQuality quality;

  /// Date when the crop enters the bed (sowing or transplanting date).
  final DateTime startDate;

  /// Date when the crop finishes harvesting and releases the bed.
  final DateTime endDate;

  /// Optional indoor module propagation start date preceding [startDate]
  /// (when transplanted from nursery modules).
  final DateTime? indoorStartDate;

  /// Non-overlapping vertical sub-lane index (`0, 1, ...`) within the bed row.
  final int laneIndex;

  /// Backing [PlantingBatchSummary] when [kind] is `harvested` or `activeInGround`.
  final PlantingBatchSummary? batch;

  /// Backing [QueuedGardenTask] when [kind] is `planned`.
  final QueuedGardenTask? plannedTask;

  /// Creates an immutable [BedTimelineSpan].
  const BedTimelineSpan({
    required this.id,
    required this.bedName,
    required this.kind,
    this.crop,
    required this.title,
    required this.quality,
    required this.startDate,
    required this.endDate,
    this.indoorStartDate,
    this.laneIndex = 0,
    this.batch,
    this.plannedTask,
  });

  /// Total days the crop occupies the bed.
  int get daysInBed => endDate.difference(startDate).inDays.clamp(1, 366);

  /// Indoor module nursery lead time in days before [startDate], if any.
  int? get nurseryLeadDays => indoorStartDate != null
      ? startDate.difference(indoorStartDate!).inDays.clamp(1, 120)
      : null;

  /// Whether `[otherStart, otherEnd]` overlaps this span's in-bed occupancy `[startDate, endDate]`.
  bool overlapsRange(DateTime otherStart, DateTime otherEnd) =>
      startDate.isBefore(otherEnd) && endDate.isAfter(otherStart);

  /// Returns a copy of this span assigned to [laneIndex].
  BedTimelineSpan withLane(int laneIndex) => BedTimelineSpan(
    id: id,
    bedName: bedName,
    kind: kind,
    crop: crop,
    title: title,
    quality: quality,
    startDate: startDate,
    endDate: endDate,
    indoorStartDate: indoorStartDate,
    laneIndex: laneIndex,
    batch: batch,
    plannedTask: plannedTask,
  );
}

/// Outcome classification when evaluating a drag-and-drop crop placement on a bed at a target date.
enum BedPlacementStatus {
  /// Clean placement or relay with no overlap, rotation, or seasonal conflicts.
  cleanRelay(label: 'Clean Relay & Rotation OK', glyph: '✓'),

  /// Valid within-season staggered sowing (*Hold-såning*) of the same crop.
  staggeredHoldSaaning(label: 'Hold-såning (Staggered Sowing)', glyph: '🔁'),

  /// Target date overlaps another crop occupying the bed.
  bedOverlapWarning(label: 'Overlaps Bed Occupancy', glyph: '⚠️'),

  /// Violates a strict or moderate botanical family crop-rotation break rule.
  familyRotationConflict(label: 'Crop Rotation Alert', glyph: '⛔'),

  /// Target month is outside the crop's normal outdoor sowing/transplant season.
  outOfSeasonWarning(label: 'Outside Prime Season', glyph: '❄️');

  /// Short status label.
  final String label;

  /// Status badge glyph.
  final String glyph;

  const BedPlacementStatus({required this.label, required this.glyph});
}

/// Real-time evaluation of placing or dragging a [VegetableEntry] onto a [GardenPlot]
/// at a specific [startDate].
final class BedPlacementEvaluation {
  /// Target plot.
  final GardenPlot plot;

  /// Crop being placed.
  final VegetableEntry crop;

  /// Resolved planting action (`sowOutdoor` or `transplant`).
  final TaskActionType action;

  /// Target date when the crop enters the bed.
  final DateTime startDate;

  /// Estimated date when the crop clears the bed.
  final DateTime endDate;

  /// Optional indoor module propagation start date before [startDate].
  final DateTime? indoorStartDate;

  /// Primary status of this placement.
  final BedPlacementStatus status;

  /// Crop rotation assessment at [startDate] (accounting for both logged batches and earlier planned tasks).
  final PlotRotationAssessment rotationAssessment;

  /// Existing spans on [plot] that overlap `[startDate, endDate]`.
  final List<BedTimelineSpan> overlappingSpans;

  /// Suggested relay handover date immediately after the blocking crop clears, if any.
  final DateTime? suggestedRelayDate;

  /// Whether [startDate.month] is within the crop's sowing/transplant season for [plot].
  final bool isInSeason;

  /// Concise one-line headline suitable for live drag preview banners.
  final String headline;

  /// Detailed guidance or warning message.
  final String detailMessage;

  /// Creates an immutable [BedPlacementEvaluation].
  BedPlacementEvaluation({
    required this.plot,
    required this.crop,
    required this.action,
    required this.startDate,
    required this.endDate,
    this.indoorStartDate,
    required this.status,
    required this.rotationAssessment,
    Iterable<BedTimelineSpan> overlappingSpans = const [],
    this.suggestedRelayDate,
    required this.isInSeason,
    required this.headline,
    required this.detailMessage,
  }) : overlappingSpans = List<BedTimelineSpan>.unmodifiable(overlappingSpans);

  /// Days the crop occupies the bed.
  int get daysInBed => endDate.difference(startDate).inDays.clamp(1, 366);

  /// Nursery module lead days before [startDate], if any.
  int? get nurseryLeadDays => indoorStartDate != null
      ? startDate.difference(indoorStartDate!).inDays.clamp(1, 120)
      : null;
}

/// Builds lane-assigned [BedTimelineSpan]s and evaluates drag-and-drop crop placements
/// on a [GardenPlot].
abstract final class BedSuccessionAdvisor {
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

  /// Resolves the default [TaskActionType] (`sowOutdoor` vs `transplant`) when
  /// placing [crop] onto [plot] in [month].
  static TaskActionType resolveActionForCrop({
    required VegetableEntry crop,
    required int month,
    TaskActionType? preferredAction,
  }) {
    if (preferredAction == TaskActionType.transplant ||
        preferredAction == TaskActionType.sowOutdoor ||
        preferredAction == TaskActionType.sowIndoor) {
      return preferredAction!;
    }
    final m = month.clamp(1, 12);
    if (crop.transplantMonths.contains(m) && !crop.sowingMonths.contains(m)) {
      return TaskActionType.transplant;
    }
    if (crop.sowingMonths.isEmpty && crop.transplantMonths.isNotEmpty) {
      return TaskActionType.transplant;
    }
    return TaskActionType.sowOutdoor;
  }

  /// Builds all time-bounded [BedTimelineSpan]s (harvested, active in ground, and planned)
  /// for [plotName], assigning non-overlapping `laneIndex` values for clean visual stacking.
  static List<BedTimelineSpan> buildSpansForPlot({
    required String plotName,
    required Iterable<PlantingBatchSummary> batchesInPlot,
    required Iterable<QueuedGardenTask> tasksInPlot,
    Map<String, DateTime>? harvestTimestampsByParentId,
  }) {
    final trimmed = plotName.trim();
    final lower = trimmed.toLowerCase();
    final rawSpans = <BedTimelineSpan>[];

    for (final batch in batchesInPlot) {
      if (batch.isDeleted) continue;
      if (batch.bedName != null &&
          batch.bedName!.trim().toLowerCase() != lower) {
        continue;
      }
      final estimatedClear = CropMaturityProfile.estimateClearingDate(batch);
      DateTime endDate = estimatedClear;
      if (batch.isHarvested) {
        final actualHarvest = harvestTimestampsByParentId?[batch.entryId];
        if (actualHarvest != null && actualHarvest.isAfter(batch.timestamp)) {
          endDate = actualHarvest;
        }
      }
      if (!endDate.isAfter(batch.timestamp)) {
        endDate = batch.timestamp.add(const Duration(days: 14));
      }
      DateTime? indoorStart;
      if (batch.action == FieldJournalAction.transplant && batch.crop != null) {
        final lead = CropMaturityProfile.forCrop(batch.crop!)
            .seasonalModuleLeadTimeDays(batch.timestamp.month);
        if (lead > 0) {
          indoorStart = batch.timestamp.subtract(Duration(days: lead));
        }
      }
      rawSpans.add(
        BedTimelineSpan(
          id: batch.entryId,
          bedName: trimmed,
          kind: batch.isHarvested
              ? BedTimelineSpanKind.harvested
              : BedTimelineSpanKind.activeInGround,
          crop: batch.crop,
          title: batch.crop?.nameEn ?? batch.title,
          quality: batch.quality,
          startDate: batch.timestamp,
          endDate: endDate,
          indoorStartDate: indoorStart,
          batch: batch,
        ),
      );
    }

    for (final task in tasksInPlot) {
      final start = task.plannedStartDate;
      if (start == null) continue;
      if (task.bedName != null && task.bedName!.trim().toLowerCase() != lower) {
        continue;
      }
      final end = task.effectiveEndDate ?? start.add(const Duration(days: 60));
      final clampedEnd = end.isAfter(start)
          ? end
          : start.add(const Duration(days: 14));
      rawSpans.add(
        BedTimelineSpan(
          id: task.id,
          bedName: trimmed,
          kind: BedTimelineSpanKind.planned,
          crop: task.crop,
          title: task.crop?.nameEn ?? task.targetLabel,
          quality: task.targetQuality,
          startDate: start,
          endDate: clampedEnd,
          indoorStartDate: task.indoorNurseryStartDate,
          plannedTask: task,
        ),
      );
    }

    rawSpans.sort((a, b) {
      final startCmp = a.startDate.compareTo(b.startDate);
      if (startCmp != 0) return startCmp;
      return a.endDate.compareTo(b.endDate);
    });

    // Assign greedy non-overlapping lane indices.
    final laneEndDates = <DateTime>[];
    final assigned = <BedTimelineSpan>[];
    for (final span in rawSpans) {
      int chosenLane = -1;
      for (int i = 0; i < laneEndDates.length; i++) {
        if (!laneEndDates[i].isAfter(span.startDate)) {
          chosenLane = i;
          laneEndDates[i] = span.endDate;
          break;
        }
      }
      if (chosenLane < 0) {
        chosenLane = laneEndDates.length;
        laneEndDates.add(span.endDate);
      }
      assigned.add(span.withLane(chosenLane));
    }
    return List<BedTimelineSpan>.unmodifiable(assigned);
  }

  /// Evaluates placing or moving [crop] onto [plot] at [targetDate].
  static BedPlacementEvaluation evaluatePlacement({
    required GardenPlot plot,
    required VegetableEntry crop,
    required DateTime targetDate,
    required Iterable<PlantingBatchSummary> batchesInPlot,
    required Iterable<QueuedGardenTask> tasksInPlot,
    TaskActionType? preferredAction,
    String? movingTaskId,
  }) {
    final normalizedStart = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      12,
    );
    final action = resolveActionForCrop(
      crop: crop,
      month: normalizedStart.month,
      preferredAction: preferredAction,
    );
    final isTransplant = action == TaskActionType.transplant;
    final endDate = CropMaturityProfile.estimateClearingDateForCrop(
      crop: crop,
      plantedAt: normalizedStart,
      isTransplant: isTransplant,
    );
    final maturity = CropMaturityProfile.forCrop(crop);
    final leadDays = isTransplant
        ? maturity.seasonalModuleLeadTimeDays(normalizedStart.month)
        : 0;
    final indoorStartDate = leadDays > 0
        ? normalizedStart.subtract(Duration(days: leadDays))
        : null;

    final otherTasks = tasksInPlot
        .where((t) => t.id != movingTaskId)
        .toList(growable: false);
    final existingSpans = buildSpansForPlot(
      plotName: plot.name,
      batchesInPlot: batchesInPlot,
      tasksInPlot: otherTasks,
    );

    // Find overlapping non-harvested (or same-season) spans.
    final overlapping = <BedTimelineSpan>[];
    DateTime? latestOverlapEnd;
    for (final span in existingSpans) {
      if (span.kind == BedTimelineSpanKind.harvested &&
          !span.endDate.isAfter(normalizedStart)) {
        continue;
      }
      if (span.overlapsRange(normalizedStart, endDate)) {
        overlapping.add(span);
        if (latestOverlapEnd == null ||
            span.endDate.isAfter(latestOverlapEnd)) {
          latestOverlapEnd = span.endDate;
        }
      }
    }

    // Build combined batch history (logged batches + earlier planned tasks) for rotation assessment.
    final syntheticBatches = <PlantingBatchSummary>[
      ...batchesInPlot.where((b) => !b.isDeleted),
      for (final t in otherTasks)
        if (t.plannedStartDate != null &&
            t.cropId != null &&
            !t.plannedStartDate!.isAfter(endDate))
          PlantingBatchSummary(
            entryId: 'planned_${t.id}',
            shardKey:
                '${t.plannedStartDate!.year}-${t.plannedStartDate!.month.toString().padLeft(2, "0")}',
            timestamp: t.plannedStartDate!,
            action: t.action == TaskActionType.transplant
                ? FieldJournalAction.transplant
                : FieldJournalAction.sowSeeds,
            title: t.targetLabel,
            cropId: t.cropId,
            bedName: plot.name,
            quality: t.targetQuality,
            cosmicSummary: 'Planned',
            updatedHlc: '',
            harvestedByEntryId:
                (t.effectiveEndDate != null &&
                    !t.effectiveEndDate!.isAfter(normalizedStart))
                ? 'cleared_before_drop'
                : null,
          ),
    ];

    final rotation = PlotRotationAssessment.evaluate(
      plotName: plot.name,
      batchesInPlot: syntheticBatches,
      candidateCrop: crop,
      referenceTime: normalizedStart,
    );

    // Check seasonal suitability (with ±1 month protected environment extension).
    bool monthMatches(List<int> allowedMonths, int m) {
      if (allowedMonths.isEmpty) return true;
      if (allowedMonths.contains(m)) return true;
      if (!plot.plotType.isProtectedEnvironment) return false;
      final prev = m == 1 ? 12 : m - 1;
      final next = m == 12 ? 1 : m + 1;
      return allowedMonths.contains(prev) || allowedMonths.contains(next);
    }

    final targetMonths = isTransplant
        ? (crop.transplantMonths.isNotEmpty
              ? crop.transplantMonths
              : crop.sowingMonths)
        : (crop.sowingMonths.isNotEmpty
              ? crop.sowingMonths
              : crop.transplantMonths);
    final isInSeason = monthMatches(targetMonths, normalizedStart.month);

    final isHoldSaaningOverlap =
        overlapping.isNotEmpty &&
        maturity.supportsStaggeredSowing &&
        overlapping.every((s) => s.crop?.id == crop.id);

    final startLabel =
        '${_monthShort[normalizedStart.month]} ${normalizedStart.day}';
    final endLabel = endDate.year > normalizedStart.year
        ? '${_monthShort[endDate.month]} ${endDate.day} \'${endDate.year % 100}'
        : '${_monthShort[endDate.month]} ${endDate.day}';
    final daysInBed = endDate.difference(normalizedStart).inDays.clamp(1, 366);
    final nurseryNote = indoorStartDate != null
        ? ' (🪴 start modules ${_monthShort[indoorStartDate.month]} ${indoorStartDate.day}, ~${leadDays}d lead)'
        : '';

    BedPlacementStatus status;
    String headline;
    String detail;

    if (rotation.hasFamilyConflict) {
      status = BedPlacementStatus.familyRotationConflict;
      headline =
          '⛔ Rotation Alert on ${plot.name}: ${crop.nameEn} ($startLabel → $endLabel)';
      detail = rotation.conflictWarning ?? rotation.rotationGuidance;
    } else if (overlapping.isNotEmpty && !isHoldSaaningOverlap) {
      status = BedPlacementStatus.bedOverlapWarning;
      final blockerNames = overlapping.map((s) => s.title).toSet().join(', ');
      final clearStr = latestOverlapEnd != null
          ? '${_monthShort[latestOverlapEnd.month]} ${latestOverlapEnd.day}'
          : endLabel;
      headline = '⚠️ Overlaps $blockerNames in ${plot.name} until $clearStr';
      detail =
          'Bed occupied until $clearStr. Drop after $clearStr or tap "Snap to Relay ($clearStr)"$nurseryNote.';
    } else if (isHoldSaaningOverlap || rotation.isStaggeredSameSeasonSowing) {
      status = BedPlacementStatus.staggeredHoldSaaning;
      final interval = maturity.seasonalStaggeredIntervalDays(
        normalizedStart.month,
      );
      headline =
          '🔁 Hold-såning: ${crop.nameEn} in ${plot.name} ($startLabel → $endLabel, ~${daysInBed}d)';
      detail =
          'Staggered sowing (~${interval}d interval) for continuous ${crop.nameEn} harvest$nurseryNote.';
    } else if (!isInSeason) {
      status = BedPlacementStatus.outOfSeasonWarning;
      headline =
          '❄️ Outside prime season: ${crop.nameEn} on $startLabel → $endLabel (~${daysInBed}d)';
      detail =
          '${crop.nameEn} is normally ${isTransplant ? "transplanted" : "sown"} in ${targetMonths.map((m) => _monthShort[m]).join(", ")}${plot.plotType.isProtectedEnvironment ? " (±1m in ${plot.plotType.displayName})" : ""}.';
    } else {
      status = BedPlacementStatus.cleanRelay;
      final actionVerb = isTransplant ? 'Transplant' : 'Sow';
      headline =
          '✓ $actionVerb ${crop.nameEn} in ${plot.name}: $startLabel → $endLabel (~${daysInBed}d)';
      detail = '${rotation.rotationGuidance}$nurseryNote';
    }

    return BedPlacementEvaluation(
      plot: plot,
      crop: crop,
      action: action,
      startDate: normalizedStart,
      endDate: endDate,
      indoorStartDate: indoorStartDate,
      status: status,
      rotationAssessment: rotation,
      overlappingSpans: overlapping,
      suggestedRelayDate: latestOverlapEnd,
      isInSeason: isInSeason,
      headline: headline,
      detailMessage: detail,
    );
  }
}
