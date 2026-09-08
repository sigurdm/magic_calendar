import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/agricultural_task_evaluator.dart';
import '../../core/ecological_synthesis.dart';
import '../../core/vegetable_database.dart';
import '../../services/ephemeris_service.dart';
import '../theme/biodynamic_icons.dart';
import '../theme/goethean_palette.dart';

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
  });

  @override
  State<PlantRecommendationsCard> createState() =>
      _PlantRecommendationsCardState();
}

final class _PlantRecommendationsCardState
    extends State<PlantRecommendationsCard> {
  PlantQuality? _filterQuality;
  _RecommendationsSection _selectedSection =
      _RecommendationsSection.vegetableSowing;

  @override
  void didUpdateWidget(covariant PlantRecommendationsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.info.quality != widget.info.quality &&
        _filterQuality == null) {
      setState(() {});
    }
  }

  Color _getQualityColor(PlantQuality quality) {
    return GoetheanPalette.getColor(quality);
  }

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
    showModalBottomSheet(
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
                    const SizedBox(height: 16),
                    Text(
                      'Astronomical Rhythms & Timing',
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
                          icon: Icons.calendar_month,
                          label: 'Sow: ${_formatMonths(crop.sowingMonths)}',
                          color: const Color(0xFF646CFF),
                        ),
                        _buildTimingBadge(
                          icon: Icons.agriculture,
                          label:
                              'Harvest: ${_formatMonths(crop.harvestMonths)}',
                          color: const Color(0xFF10B981),
                        ),
                        _buildTimingBadge(
                          icon: Icons.swap_vert,
                          label: crop.prefersAscendingMoon
                              ? 'Ascending Moon (Sap Up)'
                              : 'Descending Moon (Sap Down)',
                          color: const Color(0xFF8B5CF6),
                        ),
                        _buildTimingBadge(
                          icon: Icons.nightlight_round,
                          label: crop.prefersWaxingMoon
                              ? 'Waxing Moon (Growth)'
                              : 'Waning Moon (Root/Rest)',
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
                    const SizedBox(height: 24),
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
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: bannerColor.withValues(alpha: hasConflicts ? 0.4 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                hasConflicts
                    ? Icons.warning_amber_rounded
                    : Icons.auto_awesome_outlined,
                color: bannerColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  EcologicalSynthesis.bannerMotto,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                    color: bannerColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ecoResult.bannerSubtitle,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.35,
            ),
          ),
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
      ),
    );
  }

  Widget _buildSectionToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                    ? Colors.white
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
                ? const Color(0xFF646CFF).withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF646CFF).withValues(alpha: 0.6)
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
                    color: isSelected ? Colors.white : Colors.white60,
                  ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.white70,
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

  Widget _buildVegetableSowingView(
    BuildContext context,
    PlantQuality activeQuality,
    int currentMonth,
  ) {
    final cropsForQuality = VegetableDatabase.getVegetablesForQuality(
      activeQuality == PlantQuality.none ? PlantQuality.none : activeQuality,
    );
    final currentMonthCrops = cropsForQuality
        .where((crop) => crop.sowingMonths.contains(currentMonth))
        .toList(growable: false);

    final displayCrops = currentMonthCrops.isNotEmpty
        ? currentMonthCrops
        : cropsForQuality;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.info.isGrayDay
              ? 'Lunar node / perigee interference: Avoid sowing and transplanting today. Aerate beds gently or prepare biodynamic compost.'
              : 'Optimal crops aligned with the current ${widget.info.quality.name.toUpperCase()} element and seasonal sowing window:',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        // Category selector tabs with minimum 48x48 touch targets
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
                  final isSeasonal = crop.sowingMonths.contains(currentMonth);

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
                                    isSeasonal
                                        ? 'Optimal Sow Window'
                                        : 'Off-Season',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      color: isSeasonal
                                          ? Colors.white70
                                          : Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
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
  ) {
    final tasks = AgriculturalTaskEvaluator.evaluateAllTasks(
      calendarInfo: widget.info,
      time: widget.selectedDate,
      weather: effectiveWeather,
      ephemeris: widget.ephemeris,
      latitude: widget.latitude ?? 55.6761,
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
        ...tasks.map((advice) => _buildTaskCard(advice)),
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
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.2),
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
    final activeQuality = _filterQuality ?? widget.info.quality;
    final currentMonth = widget.selectedDate.month;
    final activeColor = _getQualityColor(activeQuality);
    final effectiveWeather = _resolveWeather();

    final ecoResult = EcologicalSynthesis.synthesize(
      calendarInfo: widget.info,
      time: widget.selectedDate,
      weather: effectiveWeather,
      latitude: widget.latitude ?? 55.6761,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
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
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Planting Recommendations',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.info.isGrayDay)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.4),
                    ),
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
            _buildVegetableSowingView(context, activeQuality, currentMonth)
          else
            _buildFarmOrganismTasksView(context, effectiveWeather),
        ],
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
