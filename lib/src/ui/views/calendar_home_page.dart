import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/algorithm.dart' as algo;
import '../../services/ephemeris_service.dart';
import '../../services/weather_service.dart';
import '../components/biodynamic_card.dart';
import '../components/celestial_details_card.dart';
import '../components/home_header.dart';
import '../components/plant_quality_card.dart';
import '../components/plant_recommendations_card.dart';
import '../components/planetary_ribbon.dart';
import 'time_scroll_view.dart';

/// Main calendar screen coordinating timeline scrolling, celestial rhythms, and agricultural advice.
final class CalendarHomePage extends StatefulWidget {
  /// Ephemeris service.
  final EphemerisService ephemeris;

  /// Weather service.
  final WeatherService weather;

  /// Creates a [CalendarHomePage].
  const CalendarHomePage({
    super.key,
    required this.ephemeris,
    required this.weather,
  });

  @override
  State<CalendarHomePage> createState() => _CalendarHomePageState();
}

final class _CalendarHomePageState extends State<CalendarHomePage> {
  final ValueNotifier<DateTime> _selectedDateNotifier = ValueNotifier(
    DateTime.now(),
  );
  final ValueNotifier<CalendarInfo?> _infoNotifier = ValueNotifier(null);
  final ValueNotifier<List<WeatherDataPoint>?> _weatherNotifier = ValueNotifier(
    null,
  );
  final ValueNotifier<double> _latNotifier = ValueNotifier(54.9037);
  final ValueNotifier<double> _lonNotifier = ValueNotifier(10.6074);
  final _timeScrollController = TimeScrollController();
  late final WeatherService _weatherService;

  @override
  void initState() {
    super.initState();
    _weatherService = widget.weather;
    _fetchWeather();
    _updateInfo(_selectedDateNotifier.value, immediate: true);
  }

  void _fetchWeather() async {
    try {
      final forecast = await _weatherService.getForecast(
        _latNotifier.value,
        _lonNotifier.value,
      );
      if (!mounted) return;
      _weatherNotifier.value = forecast;
    } catch (e) {
      debugPrint('Failed to fetch weather: $e');
    }
  }

  void _updateInfo(DateTime time, {bool immediate = false}) {
    try {
      final info = algo.getCalendarInfo(
        time,
        widget.ephemeris,
        includePlanets: true,
      );
      _infoNotifier.value = info;
    } catch (e) {
      debugPrint('Failed to update calendar info: $e');
    }
  }

  void _onTimeSelected(DateTime time) {
    _selectedDateNotifier.value = time;
    _updateInfo(time);
  }

  @override
  void dispose() {
    _selectedDateNotifier.dispose();
    _infoNotifier.dispose();
    _weatherNotifier.dispose();
    _latNotifier.dispose();
    _lonNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1E2E), Color(0xFF11111B)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                    maxWidth: constraints.maxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HomeHeader(
                        latNotifier: _latNotifier,
                        lonNotifier: _lonNotifier,
                        selectedDateNotifier: _selectedDateNotifier,
                        onNowPressed: () {
                          _timeScrollController.scrollToNow();
                        },
                        onDateSelected: _onTimeSelected,
                      ),
                      const SizedBox(height: 20),
                      ValueListenableBuilder<DateTime>(
                        valueListenable: _selectedDateNotifier,
                        builder: (context, date, _) {
                          final now = DateTime.now();
                          final isLive = date.difference(now).inMinutes.abs() < 45;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 16,
                                        color: isLive
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          DateFormat('EEEE, MMM d, y • HH:00')
                                              .format(date),
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isLive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'LIVE NOW',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                            color: const Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      _timeScrollController.scrollToNow();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFF59E0B)
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.history,
                                            size: 12,
                                            color: Color(0xFFF59E0B),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'INSPECTING (TAP FOR NOW)',
                                            style: GoogleFonts.outfit(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                              color: const Color(0xFFF59E0B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      ValueListenableBuilder<CalendarInfo?>(
                        valueListenable: _infoNotifier,
                        builder: (context, info, _) {
                          if (info == null) {
                            return const SizedBox(height: 140);
                          }
                          return PlantQualityCard(info: info);
                        },
                      ),
                      const SizedBox(height: 20),
                      ListenableBuilder(
                        listenable: Listenable.merge([
                          _latNotifier,
                          _lonNotifier,
                        ]),
                        builder: (context, _) {
                          return TimeScrollView(
                            ephemeris: widget.ephemeris,
                            weatherService: _weatherService,
                            controller: _timeScrollController,
                            onTimeSelected: _onTimeSelected,
                            onWeatherDataChanged: (weather) {
                              _weatherNotifier.value = weather;
                            },
                            latitude: _latNotifier.value,
                            longitude: _lonNotifier.value,
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      PlanetaryRibbon(
                        timeNotifier: _selectedDateNotifier,
                        ephemeris: widget.ephemeris,
                      ),
                      const SizedBox(height: 20),
                      ValueListenableBuilder<CalendarInfo?>(
                        valueListenable: _infoNotifier,
                        builder: (context, info, _) {
                          if (info == null) {
                            return const SizedBox();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CelestialDetailsCard(
                                selectedDateNotifier: _selectedDateNotifier,
                                weatherNotifier: _weatherNotifier,
                                ephemeris: widget.ephemeris,
                              ),
                              const SizedBox(height: 20),
                              ValueListenableBuilder<DateTime>(
                                valueListenable: _selectedDateNotifier,
                                builder: (context, date, _) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      BiodynamicCard(
                                        info: info,
                                        selectedDate: date,
                                        onTimeJump: _onTimeSelected,
                                      ),
                                      const SizedBox(height: 20),
                                      PlantRecommendationsCard(
                                        info: info,
                                        selectedDate: date,
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
