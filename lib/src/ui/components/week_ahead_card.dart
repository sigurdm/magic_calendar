import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/climate/climate.dart';
import '../../core/ics_calendar_exporter.dart';
import '../../core/models/models.dart';
import '../../core/week_ahead_planner.dart';
import '../theme/goethean_palette.dart';
import 'ics_export_sheet.dart';
import 'organic_vessel_container.dart';

/// Filter mode for the 7-day ranked windows list in [WeekAheadCard].
enum WeekAheadFilter {
  /// All ranked synthesis windows.
  all('Top Intersections'),

  /// Only windows with harmonious or workable dry/calm weather.
  dryAndCalm('Dry & Calm'),

  /// Only Saturday and Sunday windows.
  weekend('Weekend Only'),

  /// Only biodynamic spray windows (BD 500, BD 501, CPP, BD 508).
  sprays('BD 500/501 Sprays');

  /// User-facing chip label.
  final String label;

  const WeekAheadFilter(this.label);
}

/// Interactive 7-day biodynamic + weather synthesis digest card ranking the
/// best upcoming windows over the next 7 days and offering one-tap timeline
/// jumps and `.ics` calendar exports.
final class WeekAheadCard extends StatefulWidget {
  /// Reference start date for the 7-day digest.
  final DateTime selectedDate;

  /// Ephemeris service used to compute sidereal qualities, lunar declination,
  /// and aspects across the 7-day horizon.
  final EphemerisService ephemeris;

  /// Callback invoked when the user taps a daily pill or a ranked window to
  /// scrub the timeline.
  final ValueChanged<DateTime> onTimeJump;

  /// Optional notifier supplying hourly weather forecast points.
  final ValueNotifier<List<WeatherDataPoint>?>? weatherNotifier;

  /// Geographic latitude in decimal degrees.
  final double latitude;

  /// Geographic longitude in decimal degrees.
  final double longitude;

  /// Optional seasonal alignment mapping local climate onto the Danish reference
  /// calendar.
  final SeasonAlignment? seasons;

  /// Creates an immutable [WeekAheadCard].
  const WeekAheadCard({
    super.key,
    required this.selectedDate,
    required this.ephemeris,
    required this.onTimeJump,
    this.weatherNotifier,
    this.latitude = DefaultLocations.copenhagenLatitude,
    this.longitude = DefaultLocations.copenhagenLongitude,
    this.seasons,
  });

  @override
  State<WeekAheadCard> createState() => _WeekAheadCardState();
}

final class _WeekAheadCardState extends State<WeekAheadCard> {
  WeekAheadFilter _selectedFilter = WeekAheadFilter.all;
  bool _showAllWindows = false;

  WeekAheadDigest? _cachedDigest;
  String? _cachedKey;

  WeekAheadDigest _resolveDigest(List<WeatherDataPoint>? forecast) {
    final hourBucket = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      widget.selectedDate.hour,
    );
    final key =
        '${hourBucket.millisecondsSinceEpoch}|'
        '${widget.latitude.toStringAsFixed(2)}|'
        '${widget.longitude.toStringAsFixed(2)}|'
        '${widget.seasons.runtimeType}:${widget.seasons?.shortLabel ?? ""}|'
        '${forecast?.length ?? 0}';

    if (_cachedKey == key && _cachedDigest != null) {
      return _cachedDigest!;
    }

    final digest = WeekAheadPlanner.buildDigest(
      startTime: widget.selectedDate,
      ephemeris: widget.ephemeris,
      weatherForecast: forecast,
      latitude: widget.latitude,
      longitude: widget.longitude,
      seasons: widget.seasons,
      days: 7,
      maxRankedWindows: 10,
    );
    _cachedKey = key;
    _cachedDigest = digest;
    return digest;
  }

  List<RankedSynthesisWindow> _applyFilter(WeekAheadDigest digest) =>
      switch (_selectedFilter) {
        WeekAheadFilter.all => digest.rankedWindows,
        WeekAheadFilter.dryAndCalm => digest.conflictFreeWindows,
        WeekAheadFilter.weekend => digest.weekendWindows,
        WeekAheadFilter.sprays => digest.sprayWindows,
      };

  @override
  Widget build(BuildContext context) {
    final notifier = widget.weatherNotifier;
    if (notifier == null) {
      return _buildContent(context, null);
    }
    return ValueListenableBuilder<List<WeatherDataPoint>?>(
      valueListenable: notifier,
      builder: (context, forecast, _) => _buildContent(context, forecast),
    );
  }

  Widget _buildContent(BuildContext context, List<WeatherDataPoint>? forecast) {
    final digest = _resolveDigest(forecast);
    final filteredWindows = _applyFilter(digest);
    final visibleWindows = _showAllWindows
        ? filteredWindows
        : filteredWindows.take(4).toList(growable: false);
    const accentColor = GoetheanPalette.aspectGold;

    return OrganicVesselContainer(
      accentColor: accentColor,
      seed: 4.1,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.date_range_outlined,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Week Ahead: 7-Day Synthesis Brief',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF6ECD8),
                      ),
                    ),
                    Text(
                      'Ranked intersections of Plant-Part quality, Pflanzzeit, diurnal breath & forecast weather',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (digest.conflictFreeWindows.isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('week_ahead_export_all_ics'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF6ECD8),
                backgroundColor: accentColor.withValues(alpha: 0.14),
                side: BorderSide(color: accentColor.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final events = digest.conflictFreeWindows
                    .map((window) => window.exportEvent)
                    .toList(growable: false);
                IcsExportSheet.show(
                  context,
                  events: events,
                  title: 'Export 7-Day Biodynamic Brief (.ics)',
                  subtitle:
                      '${events.length} top conflict-free windows (including 1-hour BD 500/501 stirring reminders)',
                );
              },
              icon: const Icon(
                Icons.calendar_month_outlined,
                size: 15,
                color: accentColor,
              ),
              label: Text(
                'Export Week (.ics)',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Narrative Synthesis Banner
          OrganicVesselContainer.inset(
            accentColor: accentColor,
            seed: 2.8,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    digest.headlineSummary,
                    key: const ValueKey('week_ahead_headline_summary'),
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: const Color(0xFFF6ECD8),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 7-Day Daily Rhythm Strip
          Text(
            '7-DAY RHYTHM & WEATHER STRIP',
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < digest.dailyBriefs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildDayPill(digest.dailyBriefs[i], index: i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: WeekAheadFilter.values
                  .map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: ValueKey('week_ahead_filter_${filter.name}'),
                        label: Text(
                          filter.label,
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: accentColor.withValues(alpha: 0.32),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        side: BorderSide(
                          color: isSelected
                              ? accentColor
                              : Colors.white.withValues(alpha: 0.14),
                        ),
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 12),

          if (visibleWindows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No synthesis windows match the "${_selectedFilter.label}" filter in this 7-day horizon.',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: Colors.white60,
                ),
              ),
            )
          else ...[
            for (final window in visibleWindows)
              _buildRankedWindowTile(context, window),
            if (filteredWindows.length > 4)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('week_ahead_toggle_all_button'),
                  onPressed: () {
                    setState(() {
                      _showAllWindows = !_showAllWindows;
                    });
                  },
                  icon: Icon(
                    _showAllWindows ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: accentColor,
                  ),
                  label: Text(
                    _showAllWindows
                        ? 'Show Top 4 Windows'
                        : 'Show All ${filteredWindows.length} Ranked Windows',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayPill(DailyBiodynamicBrief day, {required int index}) {
    final dayFormat = DateFormat('EEE');
    final dateFormat = DateFormat('MMM d');
    final qualityColor = day.isAllDayGray
        ? Colors.grey
        : GoetheanPalette.getColor(day.dominantQuality);
    final weatherBadgeColor = _weatherStatusColor(day.weatherStatus);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('week_ahead_day_$index'),
        onTap: () => widget.onTimeJump(
          DateTime(day.date.year, day.date.month, day.date.day, 16),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 136,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: qualityColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: day.isWeekend
                  ? GoetheanPalette.aspectGold.withValues(alpha: 0.65)
                  : qualityColor.withValues(alpha: 0.4),
              width: day.isWeekend ? 1.4 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      dayFormat.format(day.date).toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: day.isWeekend
                            ? GoetheanPalette.aspectGold
                            : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      dateFormat.format(day.date),
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: qualityColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      day.isAllDayGray
                          ? 'Gray Day'
                          : '${day.dominantQuality.displayName} ${day.isDescending ? "↓" : "↑"}',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF6ECD8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                day.hasWeatherForecast
                    ? '${day.maxTemperature?.round() ?? "--"}°C • ${day.totalPrecipitationMm.toStringAsFixed(1)}mm'
                    : day.weatherStatus.badgeLabel,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: weatherBadgeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankedWindowTile(
    BuildContext context,
    RankedSynthesisWindow window,
  ) {
    final qualityColor = GoetheanPalette.getColor(window.quality);
    final weatherColor = _weatherStatusColor(window.weatherStatus);
    final dateFormat = DateFormat('EEE, MMM d • HH:mm');
    final timeFormat = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('week_ahead_window_${window.id}'),
          onTap: () => widget.onTimeJump(window.peakTime),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: window.hasWeatherConflict
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
                    : qualityColor.withValues(alpha: 0.5),
                width: window.rank <= 3 ? 1.4 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badge Row + .ics Export Action
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: GoetheanPalette.aspectGold.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: GoetheanPalette.aspectGold.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Text(
                        '#${window.rank} • ${window.synergyScore.round()}% SYNERGY',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: GoetheanPalette.aspectGold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: weatherColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: weatherColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        window.weatherStatus.badgeLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: weatherColor,
                        ),
                      ),
                    ),
                    if (window.isWeekend)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'WEEKEND',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF6ECD8),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            window.title,
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${dateFormat.format(window.start)}–${timeFormat.format(window.end)} • ${window.subtitle}',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF6ECD8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: ValueKey('week_ahead_export_ics_${window.id}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GoetheanPalette.aspectGold,
                        side: BorderSide(
                          color: GoetheanPalette.aspectGold.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(64, 34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        IcsExportSheet.show(
                          context,
                          events: <CalendarExportEvent>[window.exportEvent],
                          title: 'Export Window (.ics)',
                          subtitle: window.title,
                        );
                      },
                      icon: const Icon(
                        Icons.event_available_outlined,
                        size: 14,
                        color: GoetheanPalette.aspectGold,
                      ),
                      label: Text(
                        '.ics',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                if (window.hasStirringLeadTime) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.38),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cyclone_outlined,
                          size: 14,
                          color: Color(0xFF34D399),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '1-Hour Dynamization Stirring: ${timeFormat.format(window.stirringStart!)}–${timeFormat.format(window.start)} '
                            '(before ${timeFormat.format(window.start)} spray)',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFA7F3D0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 6),
                Text(
                  window.explanation,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),

                if (window.recommendedCropNames.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: window.recommendedCropNames
                        .map(
                          (cropName) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: qualityColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: qualityColor.withValues(alpha: 0.32),
                              ),
                            ),
                            child: Text(
                              cropName,
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _weatherStatusColor(WeatherIntersectionStatus status) =>
      switch (status) {
        WeatherIntersectionStatus.harmonious => const Color(0xFF10B981),
        WeatherIntersectionStatus.acceptable => const Color(0xFF38BDF8),
        WeatherIntersectionStatus.unverified => Colors.white60,
        WeatherIntersectionStatus.conflict => const Color(0xFFF59E0B),
      };
}
