import 'package:flutter/material.dart';

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
        latitude: _latNotifier.value,
        longitude: _lonNotifier.value,
      );
      _infoNotifier.value = info;
    } catch (e) {
      debugPrint('Failed to update calendar info: $e');
    }
  }

  /// Handles a selection that originated *from* the timeline.
  ///
  /// Deliberately does not call back into the timeline: it is already showing
  /// the chosen instant, and scrolling it again would fight the user's drag.
  void _onTimeSelected(DateTime time) {
    _selectedDateNotifier.value = time;
    _updateInfo(time);
  }

  /// Handles a selection made outside the timeline, e.g. the header's date
  /// picker, which must also bring the timeline to the chosen instant.
  void _onDateJump(DateTime time) {
    _onTimeSelected(time);
    _timeScrollController.scrollToTime(time);
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
              final isMobile = constraints.maxWidth < 600;
              final horizontalPadding = isMobile ? 8.0 : 16.0;
              final sectionSpacing = isMobile ? 14.0 : 20.0;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        8.0,
                        horizontalPadding,
                        sectionSpacing,
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
                            onDateSelected: _onDateJump,
                          ),
                          SizedBox(height: sectionSpacing),
                          ValueListenableBuilder<CalendarInfo?>(
                            valueListenable: _infoNotifier,
                            builder: (context, info, _) {
                              if (info == null) {
                                return const SizedBox(height: 140);
                              }
                              return ValueListenableBuilder<DateTime>(
                                valueListenable: _selectedDateNotifier,
                                builder: (context, selectedTime, _) {
                                  return PlantQualityCard(
                                    info: info,
                                    selectedTime: selectedTime,
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyTimelineDelegate(
                      height: 200.0,
                      horizontalPadding: horizontalPadding,
                      child: ListenableBuilder(
                        listenable: Listenable.merge([
                          _latNotifier,
                          _lonNotifier,
                        ]),
                        builder: (context, _) {
                          return TimeScrollView(
                            key: const PageStorageKey(
                              'sticky_time_scroll_view',
                            ),
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
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        sectionSpacing,
                        horizontalPadding,
                        24.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PlanetaryRibbon(
                            timeNotifier: _selectedDateNotifier,
                            ephemeris: widget.ephemeris,
                          ),
                          SizedBox(height: sectionSpacing),
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
                                          PlantRecommendationsCard(
                                            info: info,
                                            selectedDate: date,
                                            weatherNotifier: _weatherNotifier,
                                            ephemeris: widget.ephemeris,
                                            latitude: _latNotifier.value,
                                          ),
                                          const SizedBox(height: 20),
                                          BiodynamicCard(
                                            info: info,
                                            selectedDate: date,
                                            onTimeJump: _onDateJump,
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
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Delegate that pins the [TimeScrollView] timeline to the top of the viewport when scrolling down.
final class _StickyTimelineDelegate extends SliverPersistentHeaderDelegate {
  /// Height of the timeline header.
  final double height;

  /// Horizontal padding matching the page margins.
  final double horizontalPadding;

  /// The timeline content.
  final Widget child;

  /// Creates a [_StickyTimelineDelegate].
  ///
  /// Preconditions:
  /// * [height] must be non-negative. It is an error if [height] is negative.
  /// * [horizontalPadding] must be non-negative. It is an error if [horizontalPadding] is negative.
  _StickyTimelineDelegate({
    required this.height,
    required this.horizontalPadding,
    required this.child,
  }) : assert(height >= 0),
       assert(horizontalPadding >= 0);

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isPinned = overlapsContent || shrinkOffset > 0;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF181826),
        border: Border(
          bottom: BorderSide(
            color: isPinned
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.transparent,
            width: 1.0,
          ),
        ),
        boxShadow: isPinned
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTimelineDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.horizontalPadding != horizontalPadding ||
        oldDelegate.child != child;
  }
}
