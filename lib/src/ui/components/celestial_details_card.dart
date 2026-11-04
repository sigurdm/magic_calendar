import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/ephemeris_service.dart';
import '../theme/goethean_palette.dart';
import 'moon_phase_widget.dart';
import 'organic_vessel_container.dart';

/// Card detailing real-time celestial rhythms (sap flow, lunar vitality, illumination) and predicted weather.
final class CelestialDetailsCard extends StatefulWidget {
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

  @override
  State<CelestialDetailsCard> createState() => _CelestialDetailsCardState();
}

final class _CelestialDetailsCardState extends State<CelestialDetailsCard> {
  static const _labelColor = Color(0xFFD6C9B4);
  static const _valueColor = Color(0xFFF6ECD8);
  static const _explainColor = Color(0xFFB5A690);
  static const _headerColor = Color(0xFFF6ECD8);
  static const _badgeAccent = GoetheanPalette.aspectGold;
  static const _badgeIconColor = GoetheanPalette.aspectGold;
  static const _weatherBadgeAccent = GoetheanPalette.fruitWarmth;
  static const _weatherIconColor = GoetheanPalette.fruitWarmth;

  static final TextStyle _detailLabelStyle = GoogleFonts.cinzel(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    color: _labelColor,
  );
  static final TextStyle _detailValueStyle = GoogleFonts.cormorantGaramond(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: _valueColor,
  );
  static final TextStyle _detailExplainStyle = GoogleFonts.cormorantGaramond(
    fontSize: 14.5,
    color: _explainColor,
    fontStyle: FontStyle.italic,
    height: 1.28,
  );
  static final TextStyle _metricLabelStyle = GoogleFonts.cinzel(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: _labelColor,
  );
  static final TextStyle _metricValueStyle = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: _valueColor,
  );

  int? _cachedLunarBucket;
  EphemerisService? _cachedEphemeris;
  MoonPhaseInfo? _cachedMoonPhase;
  String _cachedSapFlow = 'Ascending';
  String _cachedSapExplanation = '';
  String _cachedVitalityExplanation = '';
  String _cachedIllumExplanation = '';
  String _cachedIllumValue = '0.0%';

  int? _cachedWeatherBucket;
  int? _cachedWeatherIdentity;
  int? _cachedWeatherLength;
  int? _cachedWeatherFirstMs;
  int? _cachedWeatherLastMs;
  WeatherDataPoint? _cachedSelectedWeather;
  MultiHorizonWeatherAnalysis? _cachedHorizon;

  void _ensureLunarCache(DateTime date) {
    final bucket = date.millisecondsSinceEpoch ~/ (5 * 60 * 1000);
    if (_cachedLunarBucket == bucket &&
        identical(_cachedEphemeris, widget.ephemeris) &&
        _cachedMoonPhase != null) {
      return;
    }
    final moonPhase = widget.ephemeris.getMoonPhase(date);
    final dec1 = widget.ephemeris.getMoonDeclination(date);
    final dec2 = widget.ephemeris.getMoonDeclination(
      date.add(const Duration(hours: 1)),
    );
    final isAscending = dec2 > dec1;

    _cachedLunarBucket = bucket;
    _cachedEphemeris = widget.ephemeris;
    _cachedMoonPhase = moonPhase;
    _cachedSapFlow = isAscending ? 'Ascending' : 'Descending';
    _cachedSapExplanation = isAscending
        ? 'Sap rises into leaves, flowers, and fruits. Ideal for above-ground storage harvest, grafting, and BD 501; sow seeds by Plant-Part Day.'
        : 'Descending Moon (Pflanzzeit): Sap draws into the soil. Ideal for transplanting, pruning, soil cultivation, BD 500, and root harvest.';
    _cachedVitalityExplanation = moonPhase.isWaxing
        ? 'Secondary synodic rhythm: rising moisture and germination pull (peaks 48h before Full Moon). Subordinate to Plant-Part Day.'
        : 'Secondary synodic rhythm: receding moisture pressure supports timber curing (Mondholz) and lower fungal pressure.';
    if (moonPhase.illuminatedFraction > 0.8) {
      _cachedIllumExplanation =
          'High nocturnal light stimulates foliage growth.';
    } else if (moonPhase.illuminatedFraction < 0.2) {
      _cachedIllumExplanation =
          'Dark nights encourage root formation and plant rest.';
    } else {
      _cachedIllumExplanation = 'Balanced lunar light influence.';
    }
    _cachedIllumValue =
        '${(moonPhase.illuminatedFraction * 100).toStringAsFixed(1)}%';
  }

  static WeatherDataPoint _findClosestWeather(
    List<WeatherDataPoint> weatherList,
    DateTime target,
  ) {
    if (weatherList.length <= 4) {
      return weatherList.reduce(
        (a, b) =>
            a.time.difference(target).inSeconds.abs() <
                b.time.difference(target).inSeconds.abs()
            ? a
            : b,
      );
    }
    // Check if sorted ascending for binary search.
    final isSorted = !weatherList.last.time.isBefore(weatherList.first.time);
    if (!isSorted) {
      return weatherList.reduce(
        (a, b) =>
            a.time.difference(target).inSeconds.abs() <
                b.time.difference(target).inSeconds.abs()
            ? a
            : b,
      );
    }
    final targetMs = target.millisecondsSinceEpoch;
    var low = 0;
    var high = weatherList.length - 1;
    while (low <= high) {
      final mid = (low + high) >>> 1;
      final midMs = weatherList[mid].time.millisecondsSinceEpoch;
      if (midMs < targetMs) {
        low = mid + 1;
      } else if (midMs > targetMs) {
        high = mid - 1;
      } else {
        return weatherList[mid];
      }
    }
    if (low <= 0) return weatherList.first;
    if (low >= weatherList.length) return weatherList.last;
    final before = weatherList[low - 1];
    final after = weatherList[low];
    return (targetMs - before.time.millisecondsSinceEpoch).abs() <=
            (after.time.millisecondsSinceEpoch - targetMs).abs()
        ? before
        : after;
  }

  void _ensureWeatherCache(DateTime date, List<WeatherDataPoint>? weatherList) {
    final bucket = date.millisecondsSinceEpoch ~/ (15 * 60 * 1000);
    final listId = weatherList == null ? 0 : identityHashCode(weatherList);
    final listLen = weatherList?.length ?? 0;
    final firstMs = (weatherList != null && weatherList.isNotEmpty)
        ? weatherList.first.time.millisecondsSinceEpoch
        : null;
    final lastMs = (weatherList != null && weatherList.isNotEmpty)
        ? weatherList.last.time.millisecondsSinceEpoch
        : null;
    if (_cachedWeatherBucket == bucket &&
        _cachedWeatherIdentity == listId &&
        _cachedWeatherLength == listLen &&
        _cachedWeatherFirstMs == firstMs &&
        _cachedWeatherLastMs == lastMs) {
      return;
    }
    _cachedWeatherBucket = bucket;
    _cachedWeatherIdentity = listId;
    _cachedWeatherLength = listLen;
    _cachedWeatherFirstMs = firstMs;
    _cachedWeatherLastMs = lastMs;

    if (weatherList == null || weatherList.isEmpty) {
      _cachedSelectedWeather = null;
      _cachedHorizon = null;
      return;
    }

    final selectedWeather = _findClosestWeather(weatherList, date);
    _cachedSelectedWeather = selectedWeather;
    _cachedHorizon = MultiHorizonWeatherAnalysis.analyze(
      referenceTime: date,
      weatherSeries: weatherList,
      currentWeather: selectedWeather,
    );
  }

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
                style: _detailLabelStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                style: _detailValueStyle,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (explanation != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(explanation, style: _detailExplainStyle),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ValueListenableBuilder<DateTime>(
      valueListenable: widget.selectedDateNotifier,
      builder: (context, date, _) {
        _ensureLunarCache(date);
        final moonPhase = _cachedMoonPhase!;
        final realTimeSapFlow = _cachedSapFlow;
        final sapExplanation = _cachedSapExplanation;
        final vitalityExplanation = _cachedVitalityExplanation;
        final illumExplanation = _cachedIllumExplanation;
        final illumValue = _cachedIllumValue;

        return ValueListenableBuilder<List<WeatherDataPoint>?>(
          valueListenable: widget.weatherNotifier,
          builder: (context, weatherList, _) {
            _ensureWeatherCache(date, weatherList);
            final selectedWeather = _cachedSelectedWeather;
            final horizon = _cachedHorizon;

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
                              color: _badgeAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: _badgeIconColor,
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
                                color: _headerColor,
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
                            RepaintBoundary(
                              child: MoonPhaseWidget(info: moonPhase, size: 60),
                            ),
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
                        illumValue,
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
                                        color: _badgeAccent.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.auto_awesome,
                                        color: _badgeIconColor,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Celestial Rhythms',
                                      style: GoogleFonts.cormorantGaramond(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: _headerColor,
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
                                  illumValue,
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
                                RepaintBoundary(
                                  child: MoonPhaseWidget(
                                    info: moonPhase,
                                    size: 68,
                                  ),
                                ),
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
                              color: _weatherBadgeAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.wb_sunny_outlined,
                              color: _weatherIconColor,
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
                              color: _headerColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      RepaintBoundary(
                        child: Wrap(
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
                            if (horizon != null &&
                                horizon.estimatedSoilTemperatureCelsius != null)
                              _buildWeatherMetricCard(
                                icon: Icons.grass_outlined,
                                iconColor: GoetheanPalette.aspectGold,
                                label: 'Est. Soil Temp',
                                value:
                                    '~${horizon.estimatedSoilTemperatureCelsius!.toStringAsFixed(1)}°C',
                                width: isCompact
                                    ? ((constraints.maxWidth - 8) / 2).clamp(
                                        100.0,
                                        200.0,
                                      )
                                    : ((constraints.maxWidth - 24) / 4).clamp(
                                        110.0,
                                        200.0,
                                      ),
                                seed: 4.5,
                              ),
                            if (horizon != null)
                              _buildWeatherMetricCard(
                                icon: Icons.layers_outlined,
                                iconColor: horizon.isSoilSaturated
                                    ? const Color(0xFFEF4444)
                                    : GoetheanPalette.leafWater,
                                label: 'Soil Tilth (72h)',
                                value: horizon.soilMoisture.shortLabel,
                                width: isCompact
                                    ? ((constraints.maxWidth - 8) / 2).clamp(
                                        100.0,
                                        200.0,
                                      )
                                    : ((constraints.maxWidth - 24) / 4).clamp(
                                        110.0,
                                        200.0,
                                      ),
                                seed: 5.5,
                              ),
                          ],
                        ),
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
                style: _metricLabelStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: _metricValueStyle),
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
