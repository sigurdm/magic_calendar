import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/ephemeris_service.dart';
import 'concoction_assistant_dialog.dart';
import 'stirring_timer_dialog.dart';

/// Interactive card widget summarizing biodynamic field preparation windows (BD 500, 501, 508)
/// and providing direct access to the stirring timer and concoction assistant.
final class BiodynamicCard extends StatelessWidget {
  /// Current calendar context information.
  final CalendarInfo info;

  /// Currently selected inspection date.
  final DateTime selectedDate;

  /// Optional callback to jump timeline to previous/next optimal preparation windows.
  final ValueChanged<DateTime>? onTimeJump;

  /// Creates an immutable [BiodynamicCard].
  ///
  /// It is an error if [info] or [selectedDate] are null.
  const BiodynamicCard({
    super.key,
    required this.info,
    required this.selectedDate,
    this.onTimeJump,
  });

  @override
  Widget build(BuildContext context) {
    final isDescending = info.sapFlow.startsWith('Descending');
    final isAscending = info.sapFlow.startsWith('Ascending');
    final hour = selectedDate.hour;

    String currentPrepStatus;
    Color statusColor;
    IconData statusIcon;

    if (info.isGrayDay) {
      currentPrepStatus =
          'Gray Day: Avoid stirring and spraying field preparations today.';
      statusColor = Colors.grey[400]!;
      statusIcon = Icons.do_not_disturb_on_outlined;
    } else if (isDescending && hour >= 15 && hour <= 20) {
      currentPrepStatus =
          'Optimal Window: BD 500 Horn Manure (Earth Inhalation / Root Activation)';
      statusColor = const Color(0xFF8D6E63);
      statusIcon = Icons.terrain;
    } else if (isAscending &&
        (hour >= 5 && hour <= 9) &&
        (info.quality == PlantQuality.flower ||
            info.quality == PlantQuality.fruit)) {
      currentPrepStatus =
          'Optimal Window: BD 501 Horn Silica (Light Exhalation / Photosynthesis)';
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.wb_sunny_outlined;
    } else if (hour >= 6 &&
        hour <= 11 &&
        info.moonPhase.illuminatedFraction > 0.8) {
      currentPrepStatus =
          'Optimal Window: BD 508 Horsetail Decoction (Fungal Shield)';
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.shield_outlined;
    } else {
      currentPrepStatus = isDescending
          ? 'Descending Moon: Soil biology active. Prepare BD 500 for evening application.'
          : 'Ascending Moon: Sap rising. Prepare BD 501 / foliar teas for morning misting.';
      statusColor = const Color(0xFF818CF8);
      statusIcon = Icons.eco_outlined;
    }

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
                        color: const Color(0xFF646CFF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.spa_outlined,
                        color: Color(0xFF818CF8),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Biodynamic Practice & Sprays',
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
                          color: Colors.white70,
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
                          color: Colors.white70,
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
              boxShadow: [
                if (currentPrepStatus.startsWith('Optimal Window:'))
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(statusIcon, color: statusColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (currentPrepStatus.startsWith('Optimal Window:')) ...[
                        Row(
                          children: [
                            Container(
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
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        currentPrepStatus,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.95),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Stirring Timer & Concoction Guide
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF646CFF)
                        .withValues(alpha: 0.3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF646CFF)),
                    ),
                  ),
                  onPressed: () => StirringTimerDialog.show(context),
                  icon: const Icon(
                    Icons.cyclone,
                    size: 18,
                    color: Color(0xFF818CF8),
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
                  icon: const Icon(
                    Icons.science_outlined,
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
            ],
          ),
        ],
      ),
    );
  }
}
