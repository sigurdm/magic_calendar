import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/ephemeris_service.dart';
import '../theme/goethean_palette.dart';
import 'moon_phase_widget.dart';
import 'organic_vessel_container.dart';

/// Card detailing real-time celestial rhythms (sap flow, lunar vitality, illumination) and predicted weather.
final class CelestialDetailsCard extends StatelessWidget {
  /// Selected date notifier.
  final ValueNotifier<DateTime> selectedDateNotifier;

  /// Weather data points notifier.
  final ValueNotifier<List<WeatherDataPoint>?> weatherNotifier;

  /// Ephemeris service.
  final EphemerisService ephemeris;

  /// Creates a [CelestialDetailsCard].
  const CelestialDetailsCard({
    super.key,
    required this.selectedDateNotifier,
    required this.weatherNotifier,
    required this.ephemeris,
  });

  Widget _buildDetailRow(String label, String value, {String? explanation}) {
    const labelColor = Color(0xFFD6C9B4);
    const valueColor = Color(0xFFF6ECD8);
    const explainColor = Color(0xFFB5A690);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.cinzel(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: labelColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (explanation != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              explanation,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 14.5,
                color: explainColor,
                fontStyle: FontStyle.italic,
                height: 1.28,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const headerColor = Color(0xFFF6ECD8);
    const badgeAccent = GoetheanPalette.aspectGold;
    const badgeIconColor = GoetheanPalette.aspectGold;
    const weatherBadgeAccent = GoetheanPalette.fruitWarmth;
    const weatherIconColor = GoetheanPalette.fruitWarmth;

    final content = ValueListenableBuilder<DateTime>(
      valueListenable: selectedDateNotifier,
      builder: (context, date, _) {
        final moonPhase = ephemeris.getMoonPhase(date);

        final dec1 = ephemeris.getMoonDeclination(date);
        final dec2 = ephemeris.getMoonDeclination(
          date.add(const Duration(hours: 1)),
        );
        final realTimeSapFlow = dec2 > dec1 ? 'Ascending' : 'Descending';

        final isAscending = dec2 > dec1;
        final sapExplanation = isAscending
            ? 'Sap rises into leaves, flowers, and fruits. Ideal for above-ground storage harvest, grafting, and BD 501; sow seeds by Plant-Part Day.'
            : 'Descending Moon (Pflanzzeit): Sap draws into the soil. Ideal for transplanting, pruning, soil cultivation, BD 500, and root harvest.';

        final vitalityExplanation = moonPhase.isWaxing
            ? 'Secondary synodic rhythm: rising moisture and germination pull (peaks 48h before Full Moon). Subordinate to Plant-Part Day.'
            : 'Secondary synodic rhythm: receding moisture pressure supports timber curing (Mondholz) and lower fungal pressure.';

        String illumExplanation;
        if (moonPhase.illuminatedFraction > 0.8) {
          illumExplanation = 'High nocturnal light stimulates foliage growth.';
        } else if (moonPhase.illuminatedFraction < 0.2) {
          illumExplanation =
              'Dark nights encourage root formation and plant rest.';
        } else {
          illumExplanation = 'Balanced lunar light influence.';
        }

        return ValueListenableBuilder<List<WeatherDataPoint>?>(
          valueListenable: weatherNotifier,
          builder: (context, weatherList, _) {
            WeatherDataPoint? selectedWeather;
            if (weatherList != null && weatherList.isNotEmpty) {
              selectedWeather = weatherList.reduce(
                (a, b) =>
                    a.time.difference(date).inSeconds.abs() <
                        b.time.difference(date).inSeconds.abs()
                    ? a
                    : b,
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 420;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Celestial Rhythms Section
                    if (isCompact) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: badgeAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: badgeIconColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Celestial Rhythms',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: headerColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MoonPhaseWidget(info: moonPhase, size: 60),
                            const SizedBox(height: 8),
                            Text(
                              moonPhase.isWaxing ? 'Waxing' : 'Waning',
                              style: GoogleFonts.cinzel(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.8,
                                color: GoetheanPalette.aspectGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildDetailRow(
                        'Sap Flow',
                        realTimeSapFlow,
                        explanation: sapExplanation,
                      ),
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        'Vitality',
                        moonPhase.name,
                        explanation: vitalityExplanation,
                      ),
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        'Illumination',
                        '${(moonPhase.illuminatedFraction * 100).toStringAsFixed(1)}%',
                        explanation: illumExplanation,
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: badgeAccent.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.auto_awesome,
                                        color: badgeIconColor,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Celestial Rhythms',
                                      style: GoogleFonts.cormorantGaramond(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: headerColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildDetailRow(
                                  'Sap Flow',
                                  realTimeSapFlow,
                                  explanation: sapExplanation,
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  'Vitality',
                                  moonPhase.name,
                                  explanation: vitalityExplanation,
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  'Illumination',
                                  '${(moonPhase.illuminatedFraction * 100).toStringAsFixed(1)}%',
                                  explanation: illumExplanation,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MoonPhaseWidget(info: moonPhase, size: 68),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (moonPhase.isWaxing
                                                ? GoetheanPalette.aspectGold
                                                : GoetheanPalette.flowerAir)
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    moonPhase.isWaxing ? 'Waxing' : 'Waning',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: moonPhase.isWaxing
                                          ? GoetheanPalette.aspectGold
                                          : GoetheanPalette.flowerAir,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Weather Metrics Grid Section
                    if (selectedWeather != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Divider(
                          color: GoetheanPalette.aspectGold.withValues(
                            alpha: 0.22,
                          ),
                          height: 1,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: weatherBadgeAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.wb_sunny_outlined,
                              color: weatherIconColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Predicted Weather',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: headerColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildWeatherMetricCard(
                            icon: Icons.thermostat,
                            iconColor: GoetheanPalette.rootEarth,
                            label: 'Temperature',
                            value: selectedWeather.temperature != null
                                ? '${selectedWeather.temperature!.round()}°C'
                                : '--',
                            width: isCompact
                                ? ((constraints.maxWidth - 8) / 2).clamp(
                                    100.0,
                                    200.0,
                                  )
                                : ((constraints.maxWidth - 24) / 4).clamp(
                                    110.0,
                                    200.0,
                                  ),
                            seed: 0.5,
                          ),
                          _buildWeatherMetricCard(
                            icon: Icons.air,
                            iconColor: GoetheanPalette.flowerAir,
                            label: 'Wind',
                            value: '${selectedWeather.windSpeed.round()} m/s',
                            width: isCompact
                                ? ((constraints.maxWidth - 8) / 2).clamp(
                                    100.0,
                                    200.0,
                                  )
                                : ((constraints.maxWidth - 24) / 4).clamp(
                                    110.0,
                                    200.0,
                                  ),
                            seed: 1.5,
                          ),
                          _buildWeatherMetricCard(
                            icon: Icons.cloud_outlined,
                            iconColor: const Color(0xFFC2B9AC),
                            label: 'Cloud Cover',
                            value: '${selectedWeather.cloudCover.round()}%',
                            width: isCompact
                                ? ((constraints.maxWidth - 8) / 2).clamp(
                                    100.0,
                                    200.0,
                                  )
                                : ((constraints.maxWidth - 24) / 4).clamp(
                                    110.0,
                                    200.0,
                                  ),
                            seed: 2.5,
                          ),
                          _buildWeatherMetricCard(
                            icon: Icons.water_drop_outlined,
                            iconColor: GoetheanPalette.leafWater,
                            label: 'Precipitation',
                            value:
                                '${selectedWeather.precipitation.toStringAsFixed(1)} mm',
                            width: isCompact
                                ? ((constraints.maxWidth - 8) / 2).clamp(
                                    100.0,
                                    200.0,
                                  )
                                : ((constraints.maxWidth - 24) / 4).clamp(
                                    110.0,
                                    200.0,
                                  ),
                            seed: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );

    return SizedBox(
      width: double.infinity,
      child: OrganicVesselContainer(
        padding: const EdgeInsets.all(24),
        accentColor: GoetheanPalette.aspectGold,
        seed: 0.4,
        child: content,
      ),
    );
  }

  Widget _buildWeatherMetricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required double width,
    required double seed,
  }) {
    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.cinzel(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: const Color(0xFFD6C9B4),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFF6ECD8),
          ),
        ),
      ],
    );

    return SizedBox(
      width: width,
      child: OrganicVesselContainer.inset(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        accentColor: iconColor,
        seed: seed,
        child: inner,
      ),
    );
  }
}
