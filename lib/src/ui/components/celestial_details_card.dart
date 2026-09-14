import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/ephemeris_service.dart';
import 'moon_phase_widget.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
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
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ValueListenableBuilder<DateTime>(
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
              ? 'Sap rises, bringing energy to leaves, flowers and fruits. Ideal for harvesting above-ground crops.'
              : 'Sap recedes to the soil. Ideal for planting, pruning, and harvesting root crops.';

          final vitalityExplanation = moonPhase.isWaxing
              ? 'Increasing lunar vitality stimulates above-ground growth and germination.'
              : 'Decreasing lunar vitality supports root development and soil consolidation.';

          String illumExplanation;
          if (moonPhase.illuminatedFraction > 0.8) {
            illumExplanation =
                'High nocturnal light stimulates foliage growth.';
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
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Color(0xFFA5B4FC),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Celestial Rhythms',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MoonPhaseWidget(info: moonPhase, size: 52),
                              const SizedBox(height: 6),
                              Text(
                                moonPhase.isWaxing ? 'Waxing' : 'Waning',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.white70,
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
                                          color: const Color(0xFF6366F1)
                                              .withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.auto_awesome,
                                          color: Color(0xFFA5B4FC),
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Celestial Rhythms',
                                        style: GoogleFonts.outfit(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
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
                                                  ? const Color(0xFF38BDF8)
                                                  : const Color(0xFFA78BFA))
                                              .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      moonPhase.isWaxing ? 'Waxing' : 'Waning',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: moonPhase.isWaxing
                                            ? const Color(0xFF38BDF8)
                                            : const Color(0xFFA78BFA),
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
                            color: Colors.white.withValues(alpha: 0.1),
                            height: 1,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.wb_sunny_outlined,
                                color: Color(0xFF38BDF8),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Predicted Weather',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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
                              iconColor: const Color(0xFFF97316),
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
                            ),
                            _buildWeatherMetricCard(
                              icon: Icons.air,
                              iconColor: const Color(0xFF38BDF8),
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
                            ),
                            _buildWeatherMetricCard(
                              icon: Icons.cloud_outlined,
                              iconColor: const Color(0xFF94A3B8),
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
                            ),
                            _buildWeatherMetricCard(
                              icon: Icons.water_drop_outlined,
                              iconColor: const Color(0xFF60A5FA),
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
      ),
    );
  }

  Widget _buildWeatherMetricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.white60,
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
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
