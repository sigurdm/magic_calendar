import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/climate/climate.dart';
import '../theme/goethean_palette.dart';

/// Opens a modal bottom sheet displaying the 30-year [ClimateProfile] for
/// [latitude] and [longitude], its seasonal offset relative to the Danish
/// reference calendar, and any transferability caveats.
Future<void> showClimateDetailsSheet(
  BuildContext context, {
  required ClimateProfile profile,
  required double latitude,
  required double longitude,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => ClimateDetailsSheet(
      profile: profile,
      latitude: latitude,
      longitude: longitude,
    ),
  );
}

/// Modal bottom sheet presenting a location's Köppen–Geiger class, approximate
/// USDA hardiness zone, thermal and frost season dates, monthly climate
/// normals, and Danish calendar transferability.
final class ClimateDetailsSheet extends StatefulWidget {
  /// Resolved 30-year climate profile.
  final ClimateProfile profile;

  /// Active latitude in degrees.
  final double latitude;

  /// Active longitude in degrees.
  final double longitude;

  /// Creates a [ClimateDetailsSheet].
  const ClimateDetailsSheet({
    super.key,
    required this.profile,
    required this.latitude,
    required this.longitude,
  });

  static const List<String> _monthNames = [
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

  static String _formatSeasonOffsetDate(ClimateProfile profile, int? offset) {
    if (offset == null) return '—';
    final date = profile.dateAtOffset(offset);
    return '${_monthNames[date.month - 1]} ${date.day}';
  }

  static String _formatThermalSeason(
    ClimateProfile profile,
    ThermalSeason season,
  ) {
    if (season.isYearRound) return 'Year-round (365 d)';
    if (season.isNeverReached) return 'Never reached';
    final start = _formatSeasonOffsetDate(profile, season.start);
    final end = _formatSeasonOffsetDate(profile, season.end);
    return '$start – $end (${season.lengthInDays} d)';
  }

  static String _springOffsetComparison(ClimateProfile local) {
    final reference = DanishReferenceClimate.profile;
    final localGrowing = local.thermalSeason(5);
    final refGrowing = reference.thermalSeason(5);
    if (localGrowing.isYearRound) {
      return 'Year-round warm season (no winter thermal dormancy)';
    }
    if (localGrowing.isNeverReached || !refGrowing.isBounded) {
      return 'Thermal threshold (5 °C) not reached';
    }
    final localStartDay = local.dayOfYearAtOffset(localGrowing.start!);
    final refStartDay = reference.dayOfYearAtOffset(refGrowing.start!);
    var delta = localStartDay - refStartDay;
    if (delta > climateYearLength ~/ 2) delta -= climateYearLength;
    if (delta < -climateYearLength ~/ 2) delta += climateYearLength;
    if (delta == 0) {
      return 'Matches central Denmark (Årslev reference)';
    }
    if (!local.hasNorthernSeasons) {
      return 'Southern Hemisphere cycle (~6 months offset from Denmark)';
    }
    final absDays = delta.abs();
    return delta < 0
        ? 'Spring 5 °C threshold arrives $absDays d earlier than Denmark'
        : 'Spring 5 °C threshold arrives $absDays d later than Denmark';
  }

  @override
  State<ClimateDetailsSheet> createState() => _ClimateDetailsSheetState();
}

final class _ClimateDetailsSheetState extends State<ClimateDetailsSheet> {
  static final TextStyle _metricLabelStyle = GoogleFonts.outfit(
    fontSize: 11.5,
    color: Colors.white54,
  );
  static final TextStyle _metricValueStyle = GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: const Color(0xFFF3E5C8),
  );
  static final TextStyle _monthTitleStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: GoetheanPalette.aspectGold,
  );
  static final TextStyle _monthTempStyle = GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  static final TextStyle _monthPrecipStyle = GoogleFonts.outfit(
    fontSize: 10,
    color: Colors.white60,
  );

  ClimateProfile? _cachedProfile;
  late ClimateSeasonAlignment _alignment;
  late ThermalSeason _growing5;
  late ThermalSeason _warm10;
  late String _springComparison;
  late String _growing5Label;
  late String _warm10Label;

  void _ensureProfileCache() {
    if (identical(_cachedProfile, widget.profile)) return;
    final profile = widget.profile;
    _cachedProfile = profile;
    _alignment = ClimateSeasonAlignment(local: profile);
    _growing5 = profile.thermalSeason(5);
    _warm10 = profile.thermalSeason(10);
    _springComparison = ClimateDetailsSheet._springOffsetComparison(profile);
    _growing5Label = ClimateDetailsSheet._formatThermalSeason(
      profile,
      _growing5,
    );
    _warm10Label = ClimateDetailsSheet._formatThermalSeason(profile, _warm10);
  }

  @override
  Widget build(BuildContext context) {
    _ensureProfileCache();
    final profile = widget.profile;
    final latitude = widget.latitude;
    final longitude = widget.longitude;
    const warmGold = Color(0xFFF3E5C8);
    const accentGold = GoetheanPalette.aspectGold;
    final alignment = _alignment;
    final frost = profile.frost;
    final zone = profile.hardinessZone;

    final (
      Color transferColor,
      IconData transferIcon,
      String transferTitle,
    ) = switch (alignment.transferability) {
      CalendarTransferability.transfers => (
        const Color(0xFF10B981),
        Icons.check_circle_outline,
        'Danish sowing windows transfer with local thermal alignment',
      ),
      CalendarTransferability.transfersWithCaveats => (
        const Color(0xFFF59E0B),
        Icons.warning_amber_rounded,
        'Danish sowing windows transfer with local climate caveats',
      ),
      CalendarTransferability.doesNotTransfer => (
        const Color(0xFFEF4444),
        Icons.info_outline,
        'Danish seasonal months do not apply — follow cosmic rhythms & local rains',
      ),
    };

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1A15).withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(
                color: accentGold.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: accentGold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accentGold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        profile.koppen.code,
                        style: GoogleFonts.cinzel(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: warmGold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.koppen.description,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: warmGold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${latitude.toStringAsFixed(2)}°, ${longitude.toStringAsFixed(2)}°'
                            '${profile.elevation != null ? ' • ${profile.elevation!.round()} m elev.' : ''}'
                            ' • ${profile.firstYear}–${profile.lastYear} normals',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: transferColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: transferColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(transferIcon, size: 18, color: transferColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              transferTitle,
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: warmGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _springComparison,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      for (final caveat in alignment.caveats) ...[
                        const SizedBox(height: 6),
                        Text(
                          '• $caveat',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildMetricRow(
                  label: 'USDA Hardiness Zone (approx. ±1 zone)',
                  value:
                      'Zone ${zone.label} (mean annual min ${profile.meanAnnualExtremeMinimum.toStringAsFixed(1)} °C)',
                ),
                _buildMetricRow(
                  label: 'Growing Season (smoothed mean ≥ 5 °C)',
                  value: _growing5Label,
                ),
                _buildMetricRow(
                  label: 'Warm Season (smoothed mean ≥ 10 °C)',
                  value: _warm10Label,
                ),
                _buildMetricRow(
                  label: 'Air Frost (Tmin ≤ 0 °C)',
                  value: frost.hasFrost
                      ? '${frost.seasonsWithFrost}/${frost.seasonCount} winters • '
                            'last spring ${ClimateDetailsSheet._formatSeasonOffsetDate(profile, frost.medianLastSpringFrost)} '
                            '(90%: ${ClimateDetailsSheet._formatSeasonOffsetDate(profile, frost.lastSpringFrost90)}) • '
                            'first autumn ${ClimateDetailsSheet._formatSeasonOffsetDate(profile, frost.medianFirstAutumnFrost)} '
                            '(${frost.medianFrostFreeDays} frost-free d)'
                      : 'Frost-free in ${frost.seasonCount}/${frost.seasonCount} winters',
                ),
                const SizedBox(height: 16),
                Text(
                  'Monthly Normals (${profile.normals.meanAnnualTemperature.toStringAsFixed(1)} °C mean • '
                  '${profile.normals.annualPrecipitation.round()} mm/yr)',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: warmGold,
                  ),
                ),
                const SizedBox(height: 8),
                RepaintBoundary(child: _buildMonthlyGrid(profile)),
                const SizedBox(height: 14),
                Text(
                  'Climate data: ERA5 ${profile.firstYear}–${profile.lastYear} via Open-Meteo (CC BY 4.0). '
                  'Grid-cell temperatures and frost dates are regional averages (10–30 km).',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.white38,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _metricLabelStyle),
          const SizedBox(height: 2),
          Text(value, style: _metricValueStyle),
        ],
      ),
    );
  }

  Widget _buildMonthlyGrid(ClimateProfile profile) {
    final temperatures = profile.normals.temperature;
    final precipitations = profile.normals.precipitation;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var m = 0; m < 12; m++)
          Container(
            width: 68,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Text(
                  ClimateDetailsSheet._monthNames[m],
                  style: _monthTitleStyle,
                ),
                const SizedBox(height: 2),
                Text(
                  '${temperatures[m].toStringAsFixed(1)}°',
                  style: _monthTempStyle,
                ),
                Text(
                  '${precipitations[m].round()} mm',
                  style: _monthPrecipStyle,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
