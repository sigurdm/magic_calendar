import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/biodynamic_prep.dart';
import '../../core/climate/climate.dart';
import '../../core/ics_calendar_exporter.dart';
import '../../core/models/models.dart';
import '../../core/week_ahead_planner.dart';
import '../../services/garden_service.dart';
import '../theme/biodynamic_icons.dart';
import '../theme/goethean_palette.dart';
import 'concoction_assistant_dialog.dart';
import 'field_journal_sheet.dart';
import 'ics_export_sheet.dart';
import 'organic_vessel_container.dart';
import 'stirring_timer_dialog.dart';

/// Interactive card widget summarizing biodynamic field preparation windows (BD 500, BD 501, CPP, BD 508),
/// seasonal compost preparation burial cycles (BD 502–507),
/// and providing direct access to the stirring timer, concoction assistant, and `.ics` calendar export.
final class BiodynamicCard extends StatelessWidget {
  /// Current calendar context information.
  final CalendarInfo info;

  /// Currently selected inspection date.
  final DateTime selectedDate;

  /// Optional seasonal alignment mapping local climate onto the Danish reference calendar.
  final SeasonAlignment? seasons;

  /// Optional callback to jump timeline to previous/next optimal preparation windows.
  final ValueChanged<DateTime>? onTimeJump;

  /// Optional ephemeris service used to locate the next upcoming preparation window.
  final EphemerisService? ephemeris;

  /// Optional notifier supplying hourly weather forecast points.
  final ValueNotifier<List<WeatherDataPoint>?>? weatherNotifier;

  /// Geographic latitude in decimal degrees.
  final double latitude;

  /// Geographic longitude in decimal degrees.
  final double longitude;

  /// Optional reactive controller for the user's persisted garden profile and field journal.
  final GardenProfileController? gardenController;

  /// Creates an immutable [BiodynamicCard].
  const BiodynamicCard({
    super.key,
    required this.info,
    required this.selectedDate,
    this.seasons,
    this.onTimeJump,
    this.ephemeris,
    this.weatherNotifier,
    this.latitude = DefaultLocations.copenhagenLatitude,
    this.longitude = DefaultLocations.copenhagenLongitude,
    this.gardenController,
  });

  @override
  Widget build(BuildContext context) {
    final isDescending = info.isMoonDescending;
    final isAscending = info.isMoonAscending;
    final hour = selectedDate.hour;

    // Evaluate CPP suitability
    final cppSuitability = BiodynamicPrepEvaluator.evaluateSpray(
      prep: BiodynamicPrepType.cpp,
      time: selectedDate,
      calendarInfo: info,
    );

    String currentPrepStatus;
    Color statusColor;
    IconData statusIcon;

    if (info.isGrayDay) {
      currentPrepStatus =
          'Gray Day: Avoid stirring and spraying field preparations today.';
      statusColor = Colors.grey[400]!;
      statusIcon = Icons.do_not_disturb_on_outlined;
    } else if (cppSuitability.isFavorable ||
        (isDescending && hour >= 15 && hour <= 20)) {
      currentPrepStatus = 'Optimal Window: BD 500 Horn Manure & CPP Cow Pat Pit (Earth Inhalation / Soil Vitality)';
      statusColor = GoetheanPalette.rootEarth;
      statusIcon = Icons.terrain;
    } else if (isAscending &&
        (hour >= 5 && hour <= 9) &&
        (info.quality == PlantQuality.flower ||
            info.quality == PlantQuality.fruit)) {
      currentPrepStatus = 'Optimal Window: BD 501 Horn Silica (Light Exhalation / Photosynthesis)';
      statusColor = GoetheanPalette.aspectGold;
      statusIcon = Icons.wb_sunny_outlined;
    } else if (hour >= 6 &&
        hour <= 11 &&
        info.moonPhase.illuminatedFraction > 0.8) {
      currentPrepStatus =
          'Optimal Window: BD 508 Horsetail Decoction (Fungal Shield)';
      statusColor = GoetheanPalette.leafWater;
      statusIcon = Icons.shield_outlined;
    } else {
      currentPrepStatus = isDescending
          ? 'Descending Moon: Soil biology active. Prepare BD 500 & CPP for evening application.'
          : 'Ascending Moon: Sap rising. Prepare BD 501 / foliar teas for morning misting.';
      statusColor = GoetheanPalette.aspectGold;
      statusIcon = Icons.eco_outlined;
    }

    final burialProgress = BiodynamicPrepEvaluator.getSeasonalBurialProgress(
      selectedDate,
      seasons: seasons,
    );

    const primaryAccent = GoetheanPalette.aspectGold;
    const primaryIconColor = GoetheanPalette.aspectGold;
    const headerTextColor = Color(0xFFF6ECD8);

    final statusBannerContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(statusIcon, color: statusColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentPrepStatus.startsWith('Optimal Window:')) ...[
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'RECOMMENDED WINDOW',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                currentPrepStatus,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFFF6ECD8),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final innerColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row with Title and Responsive Action Icons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.spa_outlined,
                      color: primaryIconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Biodynamic Practice & Sprays',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: headerTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onTimeJump != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: IconButton(
                      tooltip: 'Previous Day',
                      icon: const Icon(
                        Icons.chevron_left,
                        color: GoetheanPalette.aspectGold,
                      ),
                      onPressed: () => onTimeJump!(
                        selectedDate.subtract(const Duration(days: 1)),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: IconButton(
                      tooltip: 'Next Day',
                      icon: const Icon(
                        Icons.chevron_right,
                        color: GoetheanPalette.aspectGold,
                      ),
                      onPressed: () => onTimeJump!(
                        selectedDate.add(const Duration(days: 1)),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Cosmic Timing Status Banner
        SizedBox(
          width: double.infinity,
          child: OrganicVesselContainer.inset(
            padding: const EdgeInsets.all(14),
            accentColor: statusColor,
            seed: 3.1,
            child: statusBannerContent,
          ),
        ),
        const SizedBox(height: 16),

        // Action Buttons: Stirring Timer, CPP Stirrer & Concoction Guide
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryAccent.withValues(alpha: 0.25),
                  foregroundColor: headerTextColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: primaryAccent.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                onPressed: () => StirringTimerDialog.show(context),
                icon: const BiodynamicIcon(
                  type: BiodynamicIconType.dynamizationVortex,
                  size: 18,
                  color: primaryIconColor,
                ),
                label: Text(
                  'Stirring Timer (1 Hr)',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D6E63)
                      .withValues(alpha: 0.3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF8D6E63)),
                  ),
                ),
                onPressed: () => StirringTimerDialog.show(
                  context,
                  prep: StirringPrepType.cpp,
                ),
                icon: const Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: Color(0xFFD7CCC8),
                ),
                label: Text(
                  'CPP Stirrer (20 Min)',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981)
                      .withValues(alpha: 0.25),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF10B981)),
                  ),
                ),
                onPressed: () => ConcoctionAssistantDialog.show(context),
                icon: const BiodynamicIcon(
                  type: BiodynamicIconType.herbalCauldron,
                  size: 18,
                  color: Color(0xFF34D399),
                ),
                label: Text(
                  'Concoction Assistant',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: OutlinedButton.icon(
                key: const ValueKey('biodynamic_export_ics_button'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: primaryAccent.withValues(alpha: 0.14),
                  foregroundColor: headerTextColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: primaryAccent.withValues(alpha: 0.65),
                  ),
                ),
                onPressed: () {
                  final prepExport =
                      WeekAheadPlanner.buildCurrentOrNextPrepExport(
                        info: info,
                        selectedDate: selectedDate,
                        ephemeris: ephemeris,
                        weatherForecast: weatherNotifier?.value,
                        latitude: latitude,
                        longitude: longitude,
                      );
                  IcsExportSheet.show(
                    context,
                    events: <CalendarExportEvent>[prepExport],
                    title: 'Export Spray & 1h Stirring Reminder (.ics)',
                    subtitle: prepExport.summary,
                  );
                },
                icon: const Icon(
                  Icons.event_available_outlined,
                  size: 18,
                  color: primaryIconColor,
                ),
                label: Text(
                  'Export Spray + 1h Stir (.ics)',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (gardenController != null)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: OutlinedButton.icon(
                  key: const ValueKey('biodynamic_log_action_button'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: statusColor.withValues(alpha: 0.16),
                    foregroundColor: headerTextColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: statusColor.withValues(alpha: 0.6)),
                  ),
                  onPressed: () {
                    final prepCode = isDescending ? 'BD 500' : 'BD 501';
                    FieldJournalSheet.show(
                      context,
                      gardenController: gardenController!,
                      timestamp: selectedDate,
                      calendarInfo: info,
                      weatherSeries: weatherNotifier?.value,
                      initialAction: FieldJournalAction.sprayPreparation,
                      initialPrepCode: prepCode,
                      initialQuality: info.quality,
                    );
                  },
                  icon: Icon(
                    Icons.menu_book_outlined,
                    size: 18,
                    color: statusColor,
                  ),
                  label: Text(
                    'Log Spray Action',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Seasonal BD 502–507 Compost Preparation Burial Cycle Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isNarrow = headerConstraints.maxWidth < 420;
                  final seasonBadge = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (burialProgress.isUndergroundBurial
                                  ? const Color(0xFF8D6E63)
                                  : const Color(0xFF10B981))
                              .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            (burialProgress.isUndergroundBurial
                                    ? const Color(0xFF8D6E63)
                                    : const Color(0xFF10B981))
                                .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      burialProgress.seasonName,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: burialProgress.isUndergroundBurial
                            ? const Color(0xFFD7CCC8)
                            : const Color(0xFF6EE7B7),
                      ),
                    ),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.eco,
                            size: 16,
                            color: GoetheanPalette.leafWater,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Compost Preparations (BD 502–507)',
                              style: GoogleFonts.cinzel(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: headerTextColor,
                              ),
                            ),
                          ),
                          if (!isNarrow) ...[
                            const SizedBox(width: 8),
                            seasonBadge,
                          ],
                        ],
                      ),
                      if (isNarrow) ...[const SizedBox(height: 6), seasonBadge],
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                burialProgress.stageDescription,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFFD6C9B4),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: burialProgress.progressFraction,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    burialProgress.isUndergroundBurial
                        ? GoetheanPalette.rootEarth
                        : GoetheanPalette.leafWater,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildPrepOrganChip('BD 502 Yarrow', 'Stag bladder'),
                  _buildPrepOrganChip('BD 503 Chamomile', 'Cow intestine'),
                  _buildPrepOrganChip('BD 504 Nettle', 'Peat mantle'),
                  _buildPrepOrganChip('BD 505 Oak Bark', 'Animal skull'),
                  _buildPrepOrganChip('BD 506 Dandelion', 'Mesentery'),
                  _buildPrepOrganChip('BD 507 Valerian', 'Amber glass'),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: OrganicVesselContainer(
        padding: const EdgeInsets.all(20),
        accentColor: statusColor,
        seed: 3.6,
        child: innerColumn,
      ),
    );
  }

  Widget _buildPrepOrganChip(String name, String organ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        '$name: $organ',
        style: GoogleFonts.outfit(fontSize: 10.5, color: Colors.white70),
      ),
    );
  }
}
