import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/agricultural_task_evaluator.dart';
import '../../core/climate/climate.dart';
import '../../core/ecological_synthesis.dart';
import '../../core/models/models.dart';
import '../../core/vegetable_database.dart';
import '../../services/ephemeris_service.dart';
import '../../services/garden_service.dart';
import '../theme/biodynamic_icons.dart';
import '../theme/goethean_palette.dart';
import 'organic_vessel_container.dart';

/// Navigation section within the plant recommendations card.
enum _RecommendationsSection { vegetableSowing, farmOrganismTasks }

/// Card widget displaying biodynamically recommended crops, farm organism tasks,
/// and "The Stars Incline, They Do Not Compel" weather synthesis.
final class PlantRecommendationsCard extends StatefulWidget {
  /// Current calendar info containing the active [PlantQuality].
  final CalendarInfo info;

  /// Currently selected inspection date.
  final DateTime selectedDate;

  /// Direct weather observation or forecast point if available.
  final WeatherDataPoint? weather;

  /// Notifier supplying the list of forecast/historical weather points.
  final ValueNotifier<List<WeatherDataPoint>?>? weatherNotifier;

  /// Ephemeris service for precise constellation determination.
  final EphemerisService? ephemeris;

  /// Geographic latitude for seasonal and diurnal adaptation.
  final double? latitude;

  /// Optional seasonal alignment mapping local climate onto the Danish reference calendar.
  final SeasonAlignment? seasons;

  /// Optional reactive controller for the user's persisted garden profile.
  final GardenProfileController? gardenController;

  /// Optional callback invoked when the user wants to plan upcoming windows for a specific crop.
  final ValueChanged<VegetableEntry>? onPlanCropRequested;

  /// Creates an immutable [PlantRecommendationsCard].
  ///
  /// It is an error if [info] or [selectedDate] are null.
  const PlantRecommendationsCard({
    super.key,
    required this.info,
    required this.selectedDate,
    this.weather,
    this.weatherNotifier,
    this.ephemeris,
    this.latitude,
    this.seasons,
    this.gardenController,
    this.onPlanCropRequested,
  });

  @override
  State<PlantRecommendationsCard> createState() =>
      _PlantRecommendationsCardState();
}

final class _PlantRecommendationsCardState
    extends State<PlantRecommendationsCard> {
  PlantQuality? _filterQuality;
  PlantCategory? _filterCategory;
  bool _onlyStarred = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  _RecommendationsSection _selectedSection =
      _RecommendationsSection.vegetableSowing;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getQualityColor(PlantQuality quality) {
    return GoetheanPalette.getColor(quality);
  }

  Color _climateRatingColor(CropClimateRating rating) => switch (rating) {
    CropClimateRating.wellSuited => const Color(0xFF10B981),
    CropClimateRating.needsWarmthProtection ||
    CropClimateRating.boltRiskInSummer ||
    CropClimateRating.needsWinterProtection => const Color(0xFFF59E0B),
    CropClimateRating.seasonTooShortOutdoors ||
    CropClimateRating.overwinterIndoors => const Color(0xFFF87171),
  };

  String _getQualityName(PlantQuality quality) {
    switch (quality) {
      case PlantQuality.root:
        return 'Root (Earth)';
      case PlantQuality.leaf:
        return 'Leaf (Water)';
      case PlantQuality.flower:
        return 'Flower (Air)';
      case PlantQuality.fruit:
        return 'Fruit (Fire)';
      case PlantQuality.none:
        return 'All Crops';
    }
  }

  WeatherDataPoint? _resolveWeather() {
    if (widget.weather != null) return widget.weather;
    final list = widget.weatherNotifier?.value;
    if (list == null || list.isEmpty) return null;

    WeatherDataPoint? closest;
    Duration? minDiff;
    for (final p in list) {
      final diff = p.time.difference(widget.selectedDate).abs();
      if (minDiff == null || diff < minDiff) {
        minDiff = diff;
        closest = p;
      }
    }
    return closest;
  }

  void _showCropDetails(BuildContext context, VegetableEntry crop) {
    final themeColor = _getQualityColor(crop.quality);
    final effectiveLatitude =
        widget.latitude ?? DefaultLocations.copenhagenLatitude;
    final alignment =
        widget.seasons ??
        HemisphereSeasonAlignment(latitude: effectiveLatitude);
    final sowAnchor = crop.isFrostTender
        ? SeasonalAnchor.frostTender
        : SeasonalAnchor.thermal;
    final localProfile = alignment.localProfile;
    final climateEval = localProfile == null
        ? null
        : CropClimateEvaluation.evaluate(crop, localProfile);

    List<int> localMonths(
      List<int> danishMonths, {
      SeasonalAnchor anchor = SeasonalAnchor.thermal,
    }) => alignment.localMonthsFor(danishMonths, anchor: anchor);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E).withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(
                    color: themeColor.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                crop.localizedDisplayName,
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                crop.scientificName,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            _getQualityName(crop.quality),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: themeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTimingBadge(
                          icon: Icons.category_outlined,
                          label: crop.category.bilingualName,
                          color: themeColor,
                        ),
                        _buildTimingBadge(
                          icon: Icons.autorenew_outlined,
                          label: crop.lifeCycle.bilingualName,
                          color: GoetheanPalette.aspectGold,
                        ),
                        if (crop.hasMultipleOrgans)
                          _buildTimingBadge(
                            icon: Icons.layers_outlined,
                            label:
                                'Multi-Organ: ${crop.allQualities.map((q) => q.displayName).join(', ')}',
                            color: const Color(0xFF38BDF8),
                          ),
                        if (climateEval != null)
                          _buildTimingBadge(
                            icon: climateEval.needsAttention
                                ? Icons.thermostat_outlined
                                : Icons.verified_outlined,
                            label: climateEval.badgeLabel,
                            color: _climateRatingColor(climateEval.rating),
                          ),
                        _buildTimingBadge(
                          icon: Icons.grass_outlined,
                          label:
                              'Min Soil Temp: ${crop.minimumGerminationSoilTempC.toStringAsFixed(0)}°C',
                          color: const Color(0xFF34D399),
                        ),
                      ],
                    ),
                    if (crop.aliasesDa.isNotEmpty ||
                        crop.aliasesEn.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Synonymer / Aliases: ${[...crop.aliasesDa, ...crop.aliasesEn].join(' • ')}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                    if (climateEval != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        key: const ValueKey('crop_modal_climate_fit'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _climateRatingColor(climateEval.rating)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _climateRatingColor(climateEval.rating)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.public_outlined,
                                  size: 16,
                                  color: _climateRatingColor(
                                    climateEval.rating,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Local Climate & Season Fit (${localProfile!.koppen.code} · USDA Zone ${localProfile.hardinessZone.label})',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _climateRatingColor(
                                        climateEval.rating,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              climateEval.summary,
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                color: Colors.white.withValues(alpha: 0.92),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              climateEval.localWindowNote,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: const Color(0xFFF3E5C8),
                                height: 1.35,
                              ),
                            ),
                            if (climateEval.hardinessNote != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                climateEval.hardinessNote!,
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  color: Colors.white70,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Cultivation Guidance (Vejledning)',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      crop.descriptionDa,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      crop.descriptionEn,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    if (crop.thunNotesDa.isNotEmpty ||
                        crop.thunNotesEn.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Maria Thun Biodynamic Notes (Aussaattage)',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: GoetheanPalette.aspectGold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (crop.thunNotesDa.isNotEmpty)
                        Text(
                          crop.thunNotesDa,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFFF6ECD8),
                            height: 1.4,
                          ),
                        ),
                      if (crop.thunNotesEn.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          crop.thunNotesEn,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                    if (crop.secondaryOrganRules.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Multi-Organ Timing Overrides',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...crop.secondaryOrganRules.map((rule) {
                        final ruleColor = _getQualityColor(rule.quality);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ruleColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: ruleColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    rule.localizedLabel,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  _buildTimingBadge(
                                    icon: Icons.auto_awesome_outlined,
                                    label:
                                        '${rule.quality.displayName} Day • ${_formatMonths(localMonths(rule.months))}',
                                    color: ruleColor,
                                  ),
                                ],
                              ),
                              if (rule.noteDa.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  rule.noteDa,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              if (rule.noteEn.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  rule.noteEn,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white70,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Biodynamic Rhythms & Timing (${alignment.shortLabel})',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTimingBadge(
                          icon: Icons.auto_awesome_outlined,
                          label:
                              'Sow & Hoe: ${_getQualityName(crop.quality)} Day',
                          color: themeColor,
                        ),
                        if (crop.indoorSowingMonths.isNotEmpty)
                          _buildTimingBadge(
                            icon: Icons.home_work_outlined,
                            label:
                                'Indoor Sow: ${_formatMonths(localMonths(crop.indoorSowingMonths, anchor: sowAnchor))}',
                            color: const Color(0xFF38BDF8),
                          ),
                        if (crop.sowingMonths.isNotEmpty)
                          _buildTimingBadge(
                            icon: Icons.calendar_month,
                            label:
                                'Direct Sow: ${_formatMonths(localMonths(crop.sowingMonths, anchor: sowAnchor))}',
                            color: const Color(0xFF646CFF),
                          ),
                        if (crop.transplantMonths.isNotEmpty)
                          _buildTimingBadge(
                            icon: Icons.south_outlined,
                            label:
                                'Transplant (Pflanzzeit): ${_formatMonths(localMonths(crop.transplantMonths, anchor: sowAnchor))}',
                            color: const Color(0xFF8B5CF6),
                          ),
                        if (crop.cuttingMonths.isNotEmpty)
                          _buildTimingBadge(
                            icon: Icons.content_cut_outlined,
                            label:
                                'Cuttings (Descending): ${_formatMonths(localMonths(crop.cuttingMonths, anchor: SeasonalAnchor.dormancy))}',
                            color: const Color(0xFFEC4899),
                          ),
                        if (crop.divisionMonths.isNotEmpty)
                          _buildTimingBadge(
                            icon: Icons.call_split_outlined,
                            label:
                                'Division (Pflanzzeit): ${_formatMonths(localMonths(crop.divisionMonths, anchor: sowAnchor))}',
                            color: const Color(0xFF14B8A6),
                          ),
                        if (crop.graftingMonths.isNotEmpty)
                          _buildTimingBadge(
                            icon: Icons.call_merge_outlined,
                            label:
                                'Grafting (Ascending): ${_formatMonths(localMonths(crop.graftingMonths, anchor: SeasonalAnchor.dormancy))}',
                            color: const Color(0xFFF97316),
                          ),
                        if (crop.pruningMonths.isNotEmpty)
                          _buildTimingBadge(
                            icon: Icons.carpenter_outlined,
                            label:
                                'Pruning (Descending): ${_formatMonths(localMonths(crop.pruningMonths, anchor: SeasonalAnchor.dormancy))}',
                            color: const Color(0xFFA855F7),
                          ),
                        _buildTimingBadge(
                          icon: Icons.agriculture,
                          label:
                              'Harvest: ${_formatMonths(localMonths(crop.harvestMonths, anchor: SeasonalAnchor.thermal))}',
                          color: const Color(0xFF10B981),
                        ),
                        _buildTimingBadge(
                          icon: Icons.inventory_2_outlined,
                          label: crop.quality == PlantQuality.root
                              ? 'Storage: Root Day + Descending Moon'
                              : 'Storage: ${crop.quality.displayName} Day + Ascending Moon',
                          color: const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Companion Plants (Gode Naboplanter)',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: crop.companionPlants
                          .map((plant) {
                            return Chip(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              label: Text(
                                plant,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                    if (crop.antagonistPlants.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Antagonist Plants (Dårlige Naboplanter)',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFCA5A5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: crop.antagonistPlants
                            .map((plant) {
                              return Chip(
                                backgroundColor: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.12),
                                side: BorderSide(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.35),
                                ),
                                label: Text(
                                  plant,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFFFECACA),
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (widget.gardenController != null) ...[
                      ValueListenableBuilder<GardenProfile>(
                        valueListenable: widget.gardenController!,
                        builder: (context, profile, _) {
                          final isStarred = profile.isCropStarred(crop.id);
                          return SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              key: ValueKey('modal_star_crop_${crop.id}'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isStarred
                                    ? GoetheanPalette.aspectGold.withValues(
                                        alpha: 0.2,
                                      )
                                    : Colors.white.withValues(alpha: 0.05),
                                foregroundColor: isStarred
                                    ? GoetheanPalette.aspectGold
                                    : Colors.white70,
                                side: BorderSide(
                                  color: isStarred
                                      ? GoetheanPalette.aspectGold
                                      : Colors.white24,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(
                                isStarred
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 20,
                                color: isStarred
                                    ? GoetheanPalette.aspectGold
                                    : Colors.white70,
                              ),
                              onPressed: () {
                                widget.gardenController!.toggleStarredCrop(
                                  crop.id,
                                );
                              },
                              label: Text(
                                isStarred
                                    ? 'In My Garden Patch ★ (Tap to Remove)'
                                    : 'Add ${crop.nameEn} to My Garden Patch',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (widget.onPlanCropRequested != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GoetheanPalette.aspectGold
                                .withValues(alpha: 0.25),
                            foregroundColor: const Color(0xFFF6ECD8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: GoetheanPalette.aspectGold.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                          icon: const Icon(
                            Icons.event_available_outlined,
                            size: 18,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onPlanCropRequested!(crop);
                          },
                          label: Text(
                            'Find Optimal Windows for ${crop.nameEn}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor.withValues(alpha: 0.3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: themeColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Close Guide',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimingBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMonths(List<int> months) {
    const monthNames = [
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
    if (months.isEmpty) return 'N/A';
    return months.map((m) => monthNames[m]).join(', ');
  }

  Widget _buildWeatherSynthesisBanner(
    BuildContext context,
    EcologicalSynthesisResult ecoResult,
  ) {
    final hasConflicts = ecoResult.hasConflicts;
    final bannerColor = hasConflicts
        ? const Color(0xFFF59E0B)
        : const Color(0xFF5B8A4E);

    final innerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              hasConflicts
                  ? Icons.warning_amber_rounded
                  : Icons.auto_awesome_outlined,
              color: !hasConflicts ? GoetheanPalette.aspectGold : bannerColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                EcologicalSynthesis.bannerMotto,
                style: GoogleFonts.cinzel(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: !hasConflicts
                      ? GoetheanPalette.aspectGold
                      : bannerColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          ecoResult.bannerSubtitle,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 15,
            fontStyle: FontStyle.italic,
            color: const Color(0xFFF3E5C8),
            height: 1.35,
          ),
        ),
        if (ecoResult.horizon != null && ecoResult.horizon!.hasData) ...[
          const SizedBox(height: 8),
          Wrap(
            key: const ValueKey('multi_horizon_synthesis_pills'),
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildHorizonChip(
                icon: Icons.terrain_outlined,
                label:
                    'Soil: ${ecoResult.horizon!.soilMoisture.shortLabel}'
                    '${ecoResult.horizon!.hasAntecedentHistory ? " (48h ${ecoResult.horizon!.precipitationLast48h.toStringAsFixed(1)} mm)" : ""}',
                color: ecoResult.horizon!.isSoilSaturated
                    ? const Color(0xFFEF4444)
                    : ecoResult.horizon!.soilMoisture ==
                          SoilMoistureStatus.moist
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF10B981),
              ),
              if (ecoResult.horizon!.estimatedSoilTemperatureCelsius != null)
                _buildHorizonChip(
                  icon: Icons.thermostat_outlined,
                  label:
                      'Est. Soil: ~${ecoResult.horizon!.estimatedSoilTemperatureCelsius!.toStringAsFixed(1)}°C',
                  color: GoetheanPalette.rootEarth,
                ),
              if (ecoResult.horizon!.hasForecastLookahead)
                _buildHorizonChip(
                  icon: Icons.schedule_outlined,
                  label:
                      'Next 24h: ${ecoResult.horizon!.precipitationNext24h.toStringAsFixed(1)} mm'
                      '${ecoResult.horizon!.minTemperatureNext48h != null ? " • 48h Min: ${ecoResult.horizon!.minTemperatureNext48h!.toStringAsFixed(1)}°C" : ""}',
                  color:
                      ecoResult.horizon!.hasUpcomingFrost48h ||
                          ecoResult.horizon!.hasSprayWashoffRisk
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFA594C4),
                ),
            ],
          ),
        ],
        if (ecoResult.alerts.isNotEmpty) ...[
          const SizedBox(height: 10),
          Column(
            children: ecoResult.alerts
                .map((alert) {
                  final isCrit =
                      alert.severity == EcologicalAlertSeverity.critical;
                  final alertColor = isCrit
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFF59E0B);
                  return Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: alertColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: alertColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          alert.preventsTillage
                              ? Icons.water_drop_outlined
                              : alert.preventsSpray
                              ? Icons.air_outlined
                              : alert.indoorSowingAdvised
                              ? Icons.ac_unit_outlined
                              : Icons.shield_outlined,
                          size: 15,
                          color: alertColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: alertColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                alert.practicalAdvice,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: double.infinity,
        child: OrganicVesselContainer.inset(
          padding: const EdgeInsets.all(14),
          accentColor: bannerColor,
          seed: 2.1,
          child: innerContent,
        ),
      ),
    );
  }

  Widget _buildHorizonChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF6ECD8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1612).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: GoetheanPalette.aspectGold.withValues(alpha: 0.22),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildSectionButton(
              title: 'Vegetable Sowing',
              icon: Icons.spa_outlined,
              isSelected:
                  _selectedSection == _RecommendationsSection.vegetableSowing,
              onTap: () {
                setState(() {
                  _selectedSection = _RecommendationsSection.vegetableSowing;
                });
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSectionButton(
              title: 'Farm Organism Tasks',
              customIcon: BiodynamicIcon(
                type: BiodynamicIconType.farmOrganism,
                size: 15,
                color:
                    _selectedSection ==
                        _RecommendationsSection.farmOrganismTasks
                    ? const Color(0xFFF6ECD8)
                    : Colors.white60,
              ),
              isSelected:
                  _selectedSection == _RecommendationsSection.farmOrganismTasks,
              onTap: () {
                setState(() {
                  _selectedSection = _RecommendationsSection.farmOrganismTasks;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionButton({
    required String title,
    IconData? icon,
    Widget? customIcon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const activeAccent = GoetheanPalette.leafWater;
    const activeTextColor = Color(0xFFF6ECD8);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? activeAccent.withValues(alpha: 0.28)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? GoetheanPalette.aspectGold.withValues(alpha: 0.65)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              customIcon ??
                  Icon(
                    icon,
                    size: 15,
                    color: isSelected ? activeTextColor : Colors.white60,
                  ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.cinzel(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.6,
                    color: isSelected ? activeTextColor : Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyGardenTodayBanner(
    GardenProfile profile,
    PlantQuality activeQuality,
    SeasonAlignment alignment,
  ) {
    final starred = profile.starredCrops;
    if (starred.isEmpty) return const SizedBox.shrink();

    final transfersSeasonally =
        alignment.transferability != CalendarTransferability.doesNotTransfer;

    int refMonthFor(VegetableEntry crop) => alignment.referenceMonth(
      widget.selectedDate,
      anchor: crop.isFrostTender
          ? SeasonalAnchor.frostTender
          : SeasonalAnchor.thermal,
    );

    final matchingToday = starred
        .where((crop) {
          if (widget.info.isGrayDay) return false;
          final matchesElement =
              widget.info.quality == PlantQuality.none ||
              crop.supportsQuality(widget.info.quality);
          if (!matchesElement) return false;
          if (!transfersSeasonally) return true;
          final m = refMonthFor(crop);
          return crop.sowingMonths.contains(m) ||
              crop.indoorSowingMonths.contains(m) ||
              crop.transplantMonths.contains(m) ||
              crop.cuttingMonths.contains(m) ||
              crop.divisionMonths.contains(m) ||
              crop.graftingMonths.contains(m) ||
              crop.harvestMonths.contains(m) ||
              crop.secondaryOrganRules.any(
                (r) =>
                    (widget.info.quality == PlantQuality.none ||
                        r.quality == widget.info.quality) &&
                    r.months.contains(m),
              );
        })
        .toList(growable: false);

    final summaryText = widget.info.isGrayDay
        ? 'Rest Day for your ${starred.length} starred garden crops.'
        : matchingToday.isNotEmpty
        ? '${matchingToday.length} of your ${starred.length} starred crops align with today\'s ${widget.info.quality.displayName} rhythm: ${matchingToday.map((c) => c.nameEn).join(', ')}.'
        : 'None of your ${starred.length} starred crops are in an active ${widget.info.quality.displayName} window today.';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        key: const ValueKey('my_garden_today_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: GoetheanPalette.aspectGold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: GoetheanPalette.aspectGold.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.star_rounded,
              size: 18,
              color: GoetheanPalette.aspectGold,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Garden Today (${starred.length} Starred)',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GoetheanPalette.aspectGold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summaryText,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: const Color(0xFFF3E5C8),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVegetableSowingView(
    BuildContext context,
    PlantQuality activeQuality,
    SeasonAlignment alignment,
    MultiHorizonWeatherAnalysis? horizon,
  ) {
    final gardenProfile = widget.gardenController?.value;
    final starredIds = gardenProfile?.starredCropIds ?? const <String>{};
    final baseCropsForQuality = VegetableDatabase.search(
      _searchQuery,
      quality: (_onlyStarred && _filterQuality == null)
          ? null
          : (activeQuality == PlantQuality.none ? null : activeQuality),
      category: _filterCategory,
    );
    final cropsForQuality = _onlyStarred
        ? baseCropsForQuality
              .where((c) => starredIds.contains(c.id))
              .toList(growable: false)
        : baseCropsForQuality;
    final transfersSeasonally =
        alignment.transferability != CalendarTransferability.doesNotTransfer;

    int refMonthFor(VegetableEntry crop) => alignment.referenceMonth(
      widget.selectedDate,
      anchor: crop.isFrostTender
          ? SeasonalAnchor.frostTender
          : SeasonalAnchor.thermal,
    );

    final currentMonthCrops = transfersSeasonally
        ? cropsForQuality
              .where((crop) {
                final m = refMonthFor(crop);
                return crop.sowingMonths.contains(m) ||
                    crop.indoorSowingMonths.contains(m) ||
                    crop.transplantMonths.contains(m) ||
                    crop.cuttingMonths.contains(m) ||
                    crop.divisionMonths.contains(m) ||
                    crop.graftingMonths.contains(m) ||
                    crop.secondaryOrganRules.any(
                      (r) =>
                          (activeQuality == PlantQuality.none ||
                              r.quality == activeQuality) &&
                          r.months.contains(m),
                    );
              })
              .toList(growable: false)
        : const <VegetableEntry>[];

    final unsortedDisplayCrops =
        (_onlyStarred ||
            _searchQuery.trim().isNotEmpty ||
            currentMonthCrops.isEmpty)
        ? cropsForQuality
        : currentMonthCrops;
    final displayCrops = starredIds.isEmpty
        ? unsortedDisplayCrops
        : <VegetableEntry>[
            ...unsortedDisplayCrops.where((c) => starredIds.contains(c.id)),
            ...unsortedDisplayCrops.where((c) => !starredIds.contains(c.id)),
          ];

    final isDescending = widget.info.isMoonDescending;
    final declinationNote = isDescending
        ? 'Descending Moon (Pflanzzeit) active: favorable for both sowing and transplanting.'
        : 'Ascending Moon active: favorable for seed sowing and above-ground harvest; hold root-disturbing transplants until Descending Moon.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.info.isGrayDay
              ? 'Lunar node / perigee interference: Avoid sowing and transplanting today. Aerate beds gently or prepare biodynamic compost.'
              : 'Optimal crops aligned with the ${widget.info.quality.name.toUpperCase()} constellation. $declinationNote',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 15.5,
            fontStyle: FontStyle.italic,
            color: const Color(0xFFE5DAC6),
            height: 1.35,
          ),
        ),
        if (gardenProfile != null && gardenProfile.hasStarredCrops)
          _buildMyGardenTodayBanner(gardenProfile, activeQuality, alignment),
        if (alignment.caveats.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: GoetheanPalette.aspectGold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: GoetheanPalette.aspectGold.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.thermostat_outlined,
                  size: 15,
                  color: GoetheanPalette.aspectGold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alignment.caveats.join(' '),
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: const Color(0xFFF3E5C8),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Organ quality selector tabs with minimum 48x48 touch targets
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterTab(
                label: 'Current (${widget.info.quality.name})',
                quality: null,
                isActive: _filterQuality == null,
                color: _getQualityColor(widget.info.quality),
              ),
              const SizedBox(width: 8),
              _buildFilterTab(
                label: 'Root',
                quality: PlantQuality.root,
                isActive: _filterQuality == PlantQuality.root,
                color: _getQualityColor(PlantQuality.root),
              ),
              const SizedBox(width: 8),
              _buildFilterTab(
                label: 'Leaf',
                quality: PlantQuality.leaf,
                isActive: _filterQuality == PlantQuality.leaf,
                color: _getQualityColor(PlantQuality.leaf),
              ),
              const SizedBox(width: 8),
              _buildFilterTab(
                label: 'Flower',
                quality: PlantQuality.flower,
                isActive: _filterQuality == PlantQuality.flower,
                color: _getQualityColor(PlantQuality.flower),
              ),
              const SizedBox(width: 8),
              _buildFilterTab(
                label: 'Fruit',
                quality: PlantQuality.fruit,
                isActive: _filterQuality == PlantQuality.fruit,
                color: _getQualityColor(PlantQuality.fruit),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // PlantCategory filter row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (widget.gardenController != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: const ValueKey('rec_filter_my_garden'),
                    avatar: Icon(
                      _onlyStarred
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 15,
                      color: GoetheanPalette.aspectGold,
                    ),
                    label: Text(
                      'My Garden (${starredIds.length})',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: _onlyStarred
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _onlyStarred
                            ? const Color(0xFFF6ECD8)
                            : Colors.white70,
                      ),
                    ),
                    selected: _onlyStarred,
                    selectedColor: GoetheanPalette.aspectGold.withValues(
                      alpha: 0.28,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    side: BorderSide(
                      color: _onlyStarred
                          ? GoetheanPalette.aspectGold
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                    showCheckmark: false,
                    onSelected: (selected) {
                      setState(() {
                        _onlyStarred = selected;
                      });
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  key: const ValueKey('rec_category_all'),
                  label: Text(
                    'All Categories',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: _filterCategory == null
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: _filterCategory == null
                          ? Colors.white
                          : Colors.white70,
                    ),
                  ),
                  selected: _filterCategory == null,
                  selectedColor: _getQualityColor(activeQuality)
                      .withValues(alpha: 0.3),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  side: BorderSide(
                    color: _filterCategory == null
                        ? _getQualityColor(activeQuality)
                        : Colors.white.withValues(alpha: 0.14),
                  ),
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() {
                      _filterCategory = null;
                    });
                  },
                ),
              ),
              for (final cat in PlantCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: ValueKey('rec_category_${cat.name}'),
                    label: Text(
                      cat.pluralNameEn,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: _filterCategory == cat
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: _filterCategory == cat
                            ? Colors.white
                            : Colors.white70,
                      ),
                    ),
                    selected: _filterCategory == cat,
                    selectedColor: _getQualityColor(activeQuality)
                        .withValues(alpha: 0.3),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    side: BorderSide(
                      color: _filterCategory == cat
                          ? _getQualityColor(activeQuality)
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        _filterCategory = cat;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Search box for filtering crops
        TextField(
          key: const ValueKey('recommendations_plant_search'),
          controller: _searchController,
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search 185+ plants, herbs, trees, aliases...',
            hintStyle: GoogleFonts.outfit(
              fontSize: 12.5,
              color: Colors.white38,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
              color: Colors.white54,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      size: 16,
                      color: Colors.white54,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.22),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _getQualityColor(activeQuality)),
            ),
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
        ),
        const SizedBox(height: 16),
        if (displayCrops.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Text(
                'No specific crops matching current criteria.',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: displayCrops
                .map((crop) {
                  final cropColor = _getQualityColor(crop.quality);
                  final cropMonth = refMonthFor(crop);
                  final localProfile = alignment.localProfile;
                  final climateEval = localProfile == null
                      ? null
                      : CropClimateEvaluation.evaluate(crop, localProfile);
                  final isOutdoorSeasonTooShort =
                      climateEval?.rating ==
                      CropClimateRating.seasonTooShortOutdoors;
                  final isDirectSow =
                      transfersSeasonally &&
                      !isOutdoorSeasonTooShort &&
                      crop.sowingMonths.contains(cropMonth);
                  final isIndoorSow =
                      transfersSeasonally &&
                      crop.indoorSowingMonths.contains(cropMonth);
                  final isTransplant =
                      transfersSeasonally &&
                      crop.transplantMonths.contains(cropMonth);
                  final isCutting =
                      transfersSeasonally &&
                      crop.cuttingMonths.contains(cropMonth);
                  final isDivision =
                      transfersSeasonally &&
                      crop.divisionMonths.contains(cropMonth);
                  final isGrafting =
                      transfersSeasonally &&
                      crop.graftingMonths.contains(cropMonth);
                  CropTaskSchedule? activeSecondaryRule;
                  if (transfersSeasonally) {
                    for (final r in crop.secondaryOrganRules) {
                      if ((activeQuality == PlantQuality.none ||
                              r.quality == activeQuality) &&
                          r.months.contains(cropMonth)) {
                        activeSecondaryRule = r;
                        break;
                      }
                    }
                  }
                  final isSeasonal =
                      isDirectSow ||
                      isIndoorSow ||
                      isTransplant ||
                      isCutting ||
                      isDivision ||
                      isGrafting ||
                      activeSecondaryRule != null;

                  final String windowLabel;
                  if (!transfersSeasonally) {
                    windowLabel = 'Cosmic Rhythm Match';
                  } else if (isDirectSow && isTransplant && isDescending) {
                    windowLabel = 'Optimal Sow & Transplant';
                  } else if (isDirectSow) {
                    windowLabel = 'Optimal Sow Window';
                  } else if (isIndoorSow && isTransplant && isDescending) {
                    windowLabel = 'Indoor Sow & Transplant';
                  } else if (isIndoorSow) {
                    windowLabel = 'Optimal Indoor Sow';
                  } else if (isTransplant) {
                    windowLabel = isDescending
                        ? 'Optimal Transplant (Pflanzzeit)'
                        : 'Transplant Month (Await Descending)';
                  } else if (isDivision) {
                    windowLabel = isDescending
                        ? 'Optimal Division (Pflanzzeit)'
                        : 'Division Month (Await Descending)';
                  } else if (isGrafting) {
                    windowLabel = !isDescending
                        ? 'Optimal Grafting (Ascending)'
                        : 'Grafting Month (Await Ascending)';
                  } else if (isCutting) {
                    windowLabel = isDescending
                        ? 'Optimal Cuttings (Descending)'
                        : 'Cuttings Month (Await Descending)';
                  } else if (activeSecondaryRule != null) {
                    windowLabel = activeSecondaryRule.labelEn;
                  } else if (isOutdoorSeasonTooShort &&
                      crop.sowingMonths.contains(cropMonth)) {
                    windowLabel = 'Greenhouse / Tunnel Only';
                  } else {
                    windowLabel = 'Off-Season';
                  }

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showCropDetails(context, crop),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: cropColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSeasonal
                                ? cropColor.withValues(alpha: 0.6)
                                : cropColor.withValues(alpha: 0.25),
                            width: isSeasonal ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSeasonal
                                  ? Icons.check_circle_outline
                                  : Icons.eco_outlined,
                              size: 16,
                              color: cropColor,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    crop.localizedDisplayName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    windowLabel,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      color: isSeasonal
                                          ? Colors.white70
                                          : Colors.white38,
                                    ),
                                  ),
                                  if (climateEval != null &&
                                      climateEval.needsAttention)
                                    Text(
                                      climateEval.badgeLabel,
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: _climateRatingColor(
                                          climateEval.rating,
                                        ),
                                      ),
                                    ),
                                  if ((isDirectSow || isTransplant) &&
                                      horizon?.estimatedSoilTemperatureCelsius !=
                                          null &&
                                      horizon!.estimatedSoilTemperatureCelsius! <
                                          crop.minimumGerminationSoilTempC)
                                    Text(
                                      'Cold Soil (~${horizon.estimatedSoilTemperatureCelsius!.toStringAsFixed(1)}°C < ${crop.minimumGerminationSoilTempC.toStringAsFixed(0)}°C min)',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFF59E0B),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (widget.gardenController != null)
                              GestureDetector(
                                key: ValueKey('star_crop_${crop.id}'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  widget.gardenController!.toggleStarredCrop(
                                    crop.id,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Icon(
                                    starredIds.contains(crop.id)
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 17,
                                    color: starredIds.contains(crop.id)
                                        ? GoetheanPalette.aspectGold
                                        : Colors.white38,
                                  ),
                                ),
                              ),
                            const Icon(
                              Icons.chevron_right,
                              size: 14,
                              color: Colors.white38,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
      ],
    );
  }

  Widget _buildFarmOrganismTasksView(
    BuildContext context,
    WeatherDataPoint? effectiveWeather,
    MultiHorizonWeatherAnalysis? horizon,
  ) {
    final tasks = AgriculturalTaskEvaluator.evaluateAllTasks(
      calendarInfo: widget.info,
      time: widget.selectedDate,
      weather: effectiveWeather,
      weatherSeries: widget.weatherNotifier?.value,
      horizon: horizon,
      ephemeris: widget.ephemeris,
      latitude: widget.latitude ?? DefaultLocations.copenhagenLatitude,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Holistic farm activities beyond seed sowing harmonized with cosmic breathing and soil microbiology:',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        ...tasks.map(_buildTaskCard),
      ],
    );
  }

  Widget _buildTaskCard(AgriculturalTaskAdvice advice) {
    Color badgeColor;
    String badgeLabel;
    switch (advice.suitability) {
      case TaskSuitability.optimal:
        badgeColor = const Color(0xFF10B981);
        badgeLabel = 'Optimal';
        break;
      case TaskSuitability.favorable:
        badgeColor = const Color(0xFF3B82F6);
        badgeLabel = 'Favorable';
        break;
      case TaskSuitability.neutral:
        badgeColor = const Color(0xFF9CA3AF);
        badgeLabel = 'Neutral';
        break;
      case TaskSuitability.unfavorable:
        badgeColor = const Color(0xFFF59E0B);
        badgeLabel = 'Unfavorable';
        break;
      case TaskSuitability.restricted:
        badgeColor = const Color(0xFFEF4444);
        badgeLabel = 'Restricted';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: advice.hasWeatherConflict
              ? const Color(0xFFEF4444).withValues(alpha: 0.4)
              : badgeColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: BiodynamicIcon.fromTask(
                  advice.task,
                  size: 18,
                  color: badgeColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advice.title,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeLabel,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: badgeColor,
                            ),
                          ),
                        ),
                        if (advice.hasWeatherConflict) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 11,
                                  color: Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Weather Conflict',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.stars, size: 13, color: Color(0xFF818CF8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        advice.cosmicReasoning,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: const Color(0xFFC7D2FE),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.eco, size: 13, color: Color(0xFF34D399)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        advice.terrestrialReasoning,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: Colors.white70,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.build_outlined,
                      size: 13,
                      color: Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Action: ${advice.practicalAction}',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFFDE68A),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[
      if (widget.weatherNotifier != null) widget.weatherNotifier!,
      if (widget.gardenController != null) widget.gardenController!,
    ];
    if (listenables.isEmpty) return _buildCard(context);
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) => _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final activeQuality = _filterQuality ?? widget.info.quality;
    final effectiveLatitude =
        widget.latitude ?? DefaultLocations.copenhagenLatitude;
    final alignment =
        widget.seasons ??
        HemisphereSeasonAlignment(latitude: effectiveLatitude);
    final activeColor = _getQualityColor(activeQuality);
    final effectiveWeather = _resolveWeather();

    final ecoResult = EcologicalSynthesis.synthesize(
      calendarInfo: widget.info,
      time: widget.selectedDate,
      weather: effectiveWeather,
      weatherSeries: widget.weatherNotifier?.value,
      latitude: effectiveLatitude,
      seasons: alignment,
    );

    final innerColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.45),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Planting Recommendations',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: const Color(0xFFF6ECD8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.info.isGrayDay)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Gray Day: Rest Soil',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.grey[300],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _buildWeatherSynthesisBanner(context, ecoResult),
        _buildSectionToggle(),
        const SizedBox(height: 16),
        if (_selectedSection == _RecommendationsSection.vegetableSowing)
          _buildVegetableSowingView(
            context,
            activeQuality,
            alignment,
            ecoResult.horizon,
          )
        else
          _buildFarmOrganismTasksView(
            context,
            effectiveWeather,
            ecoResult.horizon,
          ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: OrganicVesselContainer(
        padding: const EdgeInsets.all(20),
        accentColor: activeColor,
        seed: 1.8,
        child: innerColumn,
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required PlantQuality? quality,
    required bool isActive,
    required Color color,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: InkWell(
        onTap: () {
          setState(() {
            _filterQuality = quality;
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isActive ? color : Colors.white.withValues(alpha: 0.15),
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
