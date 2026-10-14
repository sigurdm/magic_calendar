import '../vegetable_database.dart';
import 'climate_profile.dart';

/// Suitability tier of a [VegetableEntry] in a local [ClimateProfile].
enum CropClimateRating {
  /// Open-field season length, summer warmth, and winter hardiness match.
  wellSuited,

  /// Summer warmth is cool-temperate for this heat-demanding crop; a
  /// greenhouse, cold frame, or warm south-facing wall is recommended.
  needsWarmthProtection,

  /// Local USDA hardiness zone is within one half-zone of the crop's minimum;
  /// winter crown mulching or sheltered siting is advised.
  needsWinterProtection,

  /// Local winter extremes are colder than the perennial's hardiness limit;
  /// overwinter frost-free in containers or cultivate as an annual.
  overwinterIndoors,

  /// Local summer normals exceed 20 °C for a cool-season crop prone to
  /// heat-induced bolting; favor spring and autumn sowings.
  boltRiskInSummer,

  /// Local frost-free or thermal growing season is shorter than the crop's
  /// minimum requirement; protected glasshouse cultivation is required.
  seasonTooShortOutdoors,
}

/// Evaluates how a [VegetableEntry] fits a local [ClimateProfile].
final class CropClimateEvaluation {
  /// The evaluated crop entry.
  final VegetableEntry crop;

  /// The local climate profile.
  final ClimateProfile profile;

  /// Overall climate suitability rating.
  final CropClimateRating rating;

  /// Compact badge label for crop chips and planner banners.
  final String badgeLabel;

  /// Concise explanation referencing local climatological metrics.
  final String summary;

  /// Optional USDA hardiness comparison note for perennials and biennials.
  final String? hardinessNote;

  /// Local climatological frost-free or thermal window note.
  final String localWindowNote;

  /// Creates an immutable [CropClimateEvaluation].
  const CropClimateEvaluation({
    required this.crop,
    required this.profile,
    required this.rating,
    required this.badgeLabel,
    required this.summary,
    required this.hardinessNote,
    required this.localWindowNote,
  });

  /// Whether local climate conditions require special grower attention
  /// (greenhouse protection, winter mulching, indoor overwintering, or bolt
  /// avoidance).
  bool get needsAttention => rating != CropClimateRating.wellSuited;

  /// Evaluates [crop] against [profile].
  static CropClimateEvaluation evaluate(
    VegetableEntry crop,
    ClimateProfile profile,
  ) {
    final localZone = profile.hardinessZone;
    final minZone = crop.minHardinessZone;
    final halfZonesMargin = minZone == null
        ? null
        : localZone.halfZonesWarmerThan(minZone);

    final String? hardinessNote;
    if (minZone == null) {
      hardinessNote = null;
    } else if (halfZonesMargin! < 0) {
      hardinessNote =
          'Hardy to USDA Zone ${minZone.label} (local: Zone ${localZone.label}, '
          'mean annual min ${profile.meanAnnualExtremeMinimum.toStringAsFixed(1)} °C) — '
          'overwinter frost-free or grow as an annual.';
    } else if (halfZonesMargin <= 1) {
      hardinessNote =
          'Marginal winter hardiness in local USDA Zone ${localZone.label} '
          '(hardy to Zone ${minZone.label}) — mulch crowns deeply and shelter from winter wet.';
    } else {
      hardinessNote =
          'Winter-hardy to USDA Zone ${minZone.label} '
          '(local: Zone ${localZone.label}, mean annual min '
          '${profile.meanAnnualExtremeMinimum.toStringAsFixed(1)} °C).';
    }

    final localWindowNote = _buildLocalWindowNote(crop, profile);

    final s5 = profile.thermalSeason(5);
    final s10 = profile.thermalSeason(10);
    final warmestMonth = profile.normals.warmestMonthTemperature;
    final frostFreeDays = profile.frost.medianFrostFreeDays;
    final minDays = crop.minFrostFreeDays;

    // 1. Season too short outdoors
    if (s5.isNeverReached ||
        (minDays != null &&
            ((profile.frost.hasFrost && frostFreeDays < minDays) ||
                (!crop.isFrostTender && s5.lengthInDays < minDays)))) {
      final availableDays = crop.isFrostTender
          ? '$frostFreeDays median frost-free days'
          : '${s5.lengthInDays} days ≥ 5 °C';
      return CropClimateEvaluation(
        crop: crop,
        profile: profile,
        rating: CropClimateRating.seasonTooShortOutdoors,
        badgeLabel: 'Greenhouse Required',
        summary:
            '${crop.nameEn} requires ~${minDays ?? 90} growing days, '
            'but local ${profile.koppen.code} climate offers $availableDays — '
            'cultivate in a protected greenhouse or polytunnel.',
        hardinessNote: hardinessNote,
        localWindowNote: localWindowNote,
      );
    }

    // 2. Perennial winter survival below minimum hardiness zone
    if (minZone != null && halfZonesMargin! < 0) {
      return CropClimateEvaluation(
        crop: crop,
        profile: profile,
        rating: CropClimateRating.overwinterIndoors,
        badgeLabel: 'Overwinter Frost-Free',
        summary:
            '${crop.nameEn} requires USDA Zone ${minZone.label}+ for outdoor '
            'winter survival (local: Zone ${localZone.label}) — grow in containers '
            'to overwinter frost-free or treat as an annual.',
        hardinessNote: hardinessNote,
        localWindowNote: localWindowNote,
      );
    }

    // 3. Heat-loving crop in a cool-summer climate
    if (crop.requiresWarmSummer &&
        (warmestMonth < 18.5 || s10.lengthInDays < 150)) {
      return CropClimateEvaluation(
        crop: crop,
        profile: profile,
        rating: CropClimateRating.needsWarmthProtection,
        badgeLabel: 'Greenhouse / Warm Wall',
        summary:
            '${crop.nameEn} thrives on high summer heat. With a local warmest '
            'month of ${warmestMonth.toStringAsFixed(1)} °C (${s10.lengthInDays} days ≥ 10 °C), '
            'start early indoors and grow in a greenhouse, cold frame, or sheltered south wall.',
        hardinessNote: hardinessNote,
        localWindowNote: localWindowNote,
      );
    }

    // 4. Marginal winter hardiness (within 1 half-zone of minimum)
    if (minZone != null && halfZonesMargin! <= 1) {
      return CropClimateEvaluation(
        crop: crop,
        profile: profile,
        rating: CropClimateRating.needsWinterProtection,
        badgeLabel: 'Winter Mulch (Zone ${localZone.label})',
        summary:
            '${crop.nameEn} is near its winter hardiness limit in local USDA '
            'Zone ${localZone.label} (min Zone ${minZone.label}) — plant in '
            'well-drained soil and mulch crowns before hard frost.',
        hardinessNote: hardinessNote,
        localWindowNote: localWindowNote,
      );
    }

    // 5. Cool-season bolt-prone crop in a hot-summer climate
    if (crop.isBoltProneInHeat &&
        (profile.koppen.hasHotSummer || warmestMonth >= 20.0)) {
      return CropClimateEvaluation(
        crop: crop,
        profile: profile,
        rating: CropClimateRating.boltRiskInSummer,
        badgeLabel: 'Spring/Autumn Crop (Heat Bolt)',
        summary:
            'Cool-season ${crop.nameEn} bolts rapidly when monthly normals '
            'exceed 20 °C (local warmest month ${warmestMonth.toStringAsFixed(1)} °C) — '
            'schedule sowings for cool spring and autumn windows.',
        hardinessNote: hardinessNote,
        localWindowNote: localWindowNote,
      );
    }

    // 6. Well suited to open-field cultivation
    return CropClimateEvaluation(
      crop: crop,
      profile: profile,
      rating: CropClimateRating.wellSuited,
      badgeLabel: 'Well Suited (${profile.koppen.code} · ${localZone.label})',
      summary:
          '${crop.nameEn} is well matched to local ${profile.koppen.code} · '
          'USDA Zone ${localZone.label} conditions ($frostFreeDays frost-free days, '
          'warmest month ${warmestMonth.toStringAsFixed(1)} °C).',
      hardinessNote: hardinessNote,
      localWindowNote: localWindowNote,
    );
  }

  static String _buildLocalWindowNote(
    VegetableEntry crop,
    ClimateProfile profile,
  ) {
    if (crop.isFrostTender) {
      final spring90 = profile.frost.lastSpringFrost90;
      final autumn10 = profile.frost.firstAutumnFrost10;
      if (spring90 != null && autumn10 != null) {
        final springStr = formatClimateMonthDay(profile.dateAtOffset(spring90));
        final autumnStr = formatClimateMonthDay(profile.dateAtOffset(autumn10));
        return 'Safe outdoor frost-free window (90% probability): '
            '~$springStr – $autumnStr (${profile.frost.medianFrostFreeDays} median frost-free days).';
      }
      if (!profile.frost.hasFrost) {
        return 'Frost-free year-round in local ${profile.koppen.code} climate.';
      }
    }

    final s5 = profile.thermalSeason(5);
    if (s5.isBounded) {
      final startStr = formatClimateMonthDay(profile.dateAtOffset(s5.start!));
      final endStr = formatClimateMonthDay(profile.dateAtOffset(s5.end!));
      return 'Local thermal growing season (≥ 5 °C): '
          '~$startStr – $endStr (${s5.lengthInDays} days).';
    }
    if (s5.isYearRound) {
      return 'Thermal growing season (≥ 5 °C) is year-round in local ${profile.koppen.code} climate.';
    }
    return 'Daily mean normal stays below 5 °C year-round; protected cultivation required.';
  }
}

/// Formats the month and day of [date] as `MMM d` (e.g. `Apr 25`).
String formatClimateMonthDay(DateTime date) {
  const months = [
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
  return '${months[date.month - 1]} ${date.day}';
}
