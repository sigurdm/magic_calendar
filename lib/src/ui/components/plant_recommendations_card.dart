import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/vegetable_database.dart';
import '../../services/ephemeris_service.dart';

/// Card widget displaying biodynamically recommended crops, seasonal sowing guidance,
/// and astronomical timing advice harmonized with elemental color themes.
final class PlantRecommendationsCard extends StatefulWidget {
  /// Current calendar info containing the active [PlantQuality].
  final CalendarInfo info;

  /// Currently selected inspection date.
  final DateTime selectedDate;

  /// Creates an immutable [PlantRecommendationsCard].
  ///
  /// It is an error if [info] or [selectedDate] are null.
  const PlantRecommendationsCard({
    super.key,
    required this.info,
    required this.selectedDate,
  });

  @override
  State<PlantRecommendationsCard> createState() =>
      _PlantRecommendationsCardState();
}

final class _PlantRecommendationsCardState
    extends State<PlantRecommendationsCard> {
  PlantQuality? _filterQuality;

  @override
  void didUpdateWidget(covariant PlantRecommendationsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.info.quality != widget.info.quality &&
        _filterQuality == null) {
      setState(() {});
    }
  }

  Color _getQualityColor(PlantQuality quality) {
    switch (quality) {
      case PlantQuality.root:
        return const Color(0xFF8D6E63);
      case PlantQuality.leaf:
        return const Color(0xFF66BB6A);
      case PlantQuality.flower:
        return const Color(0xFFAB47BC);
      case PlantQuality.fruit:
        return const Color(0xFFFFA726);
      case PlantQuality.none:
        return const Color(0xFF9E9E9E);
    }
  }

  String _getQualityName(PlantQuality quality) {
    switch (quality) {
      case PlantQuality.root:
        return 'Root (Earth)';
      case PlantQuality.leaf:
        return 'Leaf (Water)';
      case PlantQuality.flower:
        return 'Flower (Air/Light)';
      case PlantQuality.fruit:
        return 'Fruit (Fire/Warmth)';
      case PlantQuality.none:
        return 'All Crops';
    }
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

  @override
  Widget build(BuildContext context) {
    final activeQuality = _filterQuality ?? widget.info.quality;
    final currentMonth = widget.selectedDate.month;
    final cropsForQuality = VegetableDatabase.getVegetablesForQuality(
      activeQuality == PlantQuality.none ? PlantQuality.none : activeQuality,
    );
    final currentMonthCrops = cropsForQuality
        .where((crop) => crop.sowingMonths.contains(currentMonth))
        .toList(growable: false);

    final displayCrops = currentMonthCrops.isNotEmpty
        ? currentMonthCrops
        : cropsForQuality;
    final activeColor = _getQualityColor(activeQuality);

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
          const SizedBox(height: 12),
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
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
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
