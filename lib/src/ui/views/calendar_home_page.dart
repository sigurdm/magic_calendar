import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/algorithm.dart' as algo;
import '../../core/task_window_planner.dart';
import '../../core/vegetable_database.dart';
import '../../services/climate_service.dart';
import '../../services/ephemeris_service.dart';
import '../../services/garden_service.dart';
import '../../services/weather_service.dart';
import '../components/biodynamic_card.dart';
import '../components/celestial_details_card.dart';
import '../components/home_header.dart';
import '../components/organic_vessel_container.dart';
import '../components/planetary_ribbon.dart';
import '../components/plant_quality_card.dart';
import '../components/plant_recommendations_card.dart';
import '../components/task_planner_card.dart';
import '../theme/goethean_palette.dart';
import 'time_scroll_view.dart';

/// Top-level workspace mode on the home screen.
enum _CalendarWorkspaceMode {
  /// Inspect cosmic and terrestrial conditions for the currently selected time.
  inspectTime,

  /// Plan a specific task ("When is a good time to...?") and jump to upcoming windows.
  planTask,
}

/// Main calendar screen coordinating timeline scrolling, celestial rhythms, and agricultural advice.
final class CalendarHomePage extends StatefulWidget {
  /// Ephemeris service.
  final EphemerisService ephemeris;

  /// Weather service.
  final WeatherService weather;

  /// Optional 30-year climate normal service.
  final ClimateService? climate;

  /// Optional reactive controller for the user's persisted garden profile.
  final GardenProfileController? gardenController;

  /// Creates a [CalendarHomePage].
  const CalendarHomePage({
    super.key,
    required this.ephemeris,
    required this.weather,
    this.climate,
    this.gardenController,
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
  final ValueNotifier<ClimateProfile?> _climateNotifier = ValueNotifier(null);
  late final GardenProfileController _gardenController;
  late final bool _ownsGardenController;
  late final ValueNotifier<double> _latNotifier;
  late final ValueNotifier<double> _lonNotifier;
  final _timeScrollController = TimeScrollController();
  late final WeatherService _weatherService;
  int _climateRequestId = 0;
  bool _syncingLocation = false;

  _CalendarWorkspaceMode _workspaceMode = _CalendarWorkspaceMode.inspectTime;
  TaskActionType? _plannerInitialAction;
  VegetableEntry? _plannerInitialCrop;

  @override
  void initState() {
    super.initState();
    _weatherService = widget.weather;
    if (widget.gardenController != null) {
      _gardenController = widget.gardenController!;
      _ownsGardenController = false;
    } else {
      _gardenController = GardenProfileController();
      _ownsGardenController = true;
    }
    final initialLoc = _gardenController.value.activeLocation;
    _latNotifier = ValueNotifier(initialLoc.latitude);
    _lonNotifier = ValueNotifier(initialLoc.longitude);
    _latNotifier.addListener(_onLocationChanged);
    _lonNotifier.addListener(_onLocationChanged);
    _gardenController.addListener(_onGardenProfileChanged);
    _fetchWeather();
    _fetchClimate();
    _updateInfo(_selectedDateNotifier.value, immediate: true);
  }

  void _onGardenProfileChanged() {
    if (_syncingLocation) return;
    final activeLoc = _gardenController.value.activeLocation;
    if (!activeLoc.matchesCoordinates(_latNotifier.value, _lonNotifier.value)) {
      _syncingLocation = true;
      _latNotifier.value = activeLoc.latitude;
      _lonNotifier.value = activeLoc.longitude;
      _syncingLocation = false;
    }
  }

  void _onLocationChanged() {
    if (!_syncingLocation) {
      _syncingLocation = true;
      final currentActive = _gardenController.value.activeLocation;
      final preservedName =
          currentActive.matchesCoordinates(
            _latNotifier.value,
            _lonNotifier.value,
          )
          ? currentActive.name
          : null;
      _gardenController.setCoordinates(
        _latNotifier.value,
        _lonNotifier.value,
        name: preservedName,
        saveIfNamed: false,
      );
      _syncingLocation = false;
    }
    _climateNotifier.value = null;
    _fetchWeather();
    _fetchClimate();
    _updateInfo(_selectedDateNotifier.value, immediate: true);
  }

  void _fetchWeather() async {
    final lat = _latNotifier.value;
    final lon = _lonNotifier.value;
    final now = DateTime.now();
    try {
      final forecast = await _weatherService.getForecast(lat, lon);
      final combined = <WeatherDataPoint>[...forecast];
      try {
        final history = await _weatherService.getHistoricalData(
          lat,
          lon,
          now.subtract(const Duration(hours: 72)),
          now,
        );
        combined.addAll(history.where((p) => !p.time.isAfter(now)));
        combined.sort((a, b) => a.time.compareTo(b.time));
      } catch (_) {
        // Proceed with forecast if historical archive fetch fails.
      }
      if (!mounted) return;
      _weatherNotifier.value = combined;
    } catch (e) {
      debugPrint('Failed to fetch weather: $e');
    }
  }

  Future<void> _fetchClimate() async {
    final service = widget.climate;
    if (service == null) return;
    final requestId = ++_climateRequestId;
    final lat = _latNotifier.value;
    final lon = _lonNotifier.value;
    try {
      final profile = await service.profileFor(lat, lon);
      if (!mounted || requestId != _climateRequestId) return;
      _climateNotifier.value = profile;
    } catch (e) {
      debugPrint('Failed to fetch climate profile: $e');
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

  void _openTaskPlannerFor({TaskActionType? action, VegetableEntry? crop}) {
    setState(() {
      _plannerInitialAction = action;
      _plannerInitialCrop = crop;
      _workspaceMode = _CalendarWorkspaceMode.planTask;
    });
  }

  Widget _buildModeSwitcher(Color elementColor) {
    return OrganicVesselContainer.inset(
      accentColor: GoetheanPalette.aspectGold,
      seed: 1.9,
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              key: const ValueKey('mode_inspect_time_button'),
              mode: _CalendarWorkspaceMode.inspectTime,
              icon: Icons.access_time_outlined,
              title: 'What To Do At Selected Time',
              subtitle: 'Right now / inspect timeline',
              accentColor: elementColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildModeButton(
              key: const ValueKey('mode_plan_task_button'),
              mode: _CalendarWorkspaceMode.planTask,
              icon: Icons.event_available_outlined,
              title: 'When Is a Good Time To...?',
              subtitle: 'Cuttings, sow, prune, harvest',
              accentColor: GoetheanPalette.aspectGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required Key key,
    required _CalendarWorkspaceMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    final isSelected = _workspaceMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: () {
          setState(() {
            _workspaceMode = mode;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.65)
                  : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? accentColor : Colors.white60,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFFF6ECD8)
                            : Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        color: isSelected ? Colors.white70 : Colors.white38,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _latNotifier.removeListener(_onLocationChanged);
    _lonNotifier.removeListener(_onLocationChanged);
    _gardenController.removeListener(_onGardenProfileChanged);
    if (_ownsGardenController) {
      _gardenController.dispose();
    }
    _selectedDateNotifier.dispose();
    _infoNotifier.dispose();
    _weatherNotifier.dispose();
    _climateNotifier.dispose();
    _latNotifier.dispose();
    _lonNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<CalendarInfo?>(
        valueListenable: _infoNotifier,
        builder: (context, info, _) {
          return ValueListenableBuilder<DateTime>(
            valueListenable: _selectedDateNotifier,
            builder: (context, selectedTime, _) {
              final elementColor = info != null
                  ? GoetheanPalette.getColor(info.quality)
                  : GoetheanPalette.leafWater;
              final lighting = info != null
                  ? DiurnalSolarLighting.compute(selectedTime, info)
                  : const DiurnalSolarLighting(
                      lx: -0.4,
                      ly: -0.7,
                      lz: 0.5,
                      sunAltitude: 0.6,
                      daylightFactor: 0.9,
                    );

              final bgTop = Color.lerp(
                GoetheanPalette.topsoilWarm,
                elementColor,
                0.14 * lighting.daylightFactor + 0.06,
              )!;
              final bgMid = Color.lerp(
                GoetheanPalette.compostDark,
                const Color(0xFF2B2219),
                0.45,
              )!;
              const bgBottom = GoetheanPalette.compostDark;

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(lighting.lx * 0.6, -1.0),
                    end: Alignment(-lighting.lx * 0.4, 1.0),
                    colors: [bgTop, bgMid, bgBottom],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -80,
                      left: -40,
                      right: -40,
                      height: 680,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment(lighting.lx * 0.45, -0.25),
                              radius: 0.92,
                              colors: [
                                elementColor.withValues(
                                  alpha: 0.20 * lighting.daylightFactor + 0.08,
                                ),
                                GoetheanPalette.aspectGold.withValues(
                                  alpha: 0.07 * lighting.daylightFactor,
                                ),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.52, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      HomeHeader(
                                        latNotifier: _latNotifier,
                                        lonNotifier: _lonNotifier,
                                        selectedDateNotifier:
                                            _selectedDateNotifier,
                                        climateNotifier: _climateNotifier,
                                        gardenController: _gardenController,
                                        onNowPressed:
                                            _timeScrollController.scrollToNow,
                                        onDateSelected: _onDateJump,
                                      ),
                                      SizedBox(height: sectionSpacing),
                                      if (info == null)
                                        const SizedBox(height: 140)
                                      else
                                        PlantQualityCard(
                                          info: info,
                                          selectedTime: selectedTime,
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
                                  elementColor: elementColor,
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
                                  child: ListenableBuilder(
                                    listenable: Listenable.merge([
                                      _climateNotifier,
                                      _latNotifier,
                                      _lonNotifier,
                                    ]),
                                    builder: (context, _) {
                                      final climateProfile =
                                          _climateNotifier.value;
                                      final SeasonAlignment seasons =
                                          climateProfile != null
                                          ? ClimateSeasonAlignment(
                                              local: climateProfile,
                                            )
                                          : HemisphereSeasonAlignment(
                                              latitude: _latNotifier.value,
                                            );
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _buildModeSwitcher(elementColor),
                                          SizedBox(height: sectionSpacing),
                                          if (_workspaceMode ==
                                              _CalendarWorkspaceMode
                                                  .planTask) ...[
                                            TaskPlannerCard(
                                              selectedDate: selectedTime,
                                              ephemeris: widget.ephemeris,
                                              weatherNotifier: _weatherNotifier,
                                              latitude: _latNotifier.value,
                                              longitude: _lonNotifier.value,
                                              seasons: seasons,
                                              gardenController:
                                                  _gardenController,
                                              onTimeJump: _onDateJump,
                                              initialAction:
                                                  _plannerInitialAction,
                                              initialCrop: _plannerInitialCrop,
                                            ),
                                            const SizedBox(height: 20),
                                          ],
                                          PlanetaryRibbon(
                                            timeNotifier: _selectedDateNotifier,
                                            ephemeris: widget.ephemeris,
                                          ),
                                          SizedBox(height: sectionSpacing),
                                          if (info != null)
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (_workspaceMode ==
                                                    _CalendarWorkspaceMode
                                                        .inspectTime) ...[
                                                  CelestialDetailsCard(
                                                    selectedDateNotifier:
                                                        _selectedDateNotifier,
                                                    weatherNotifier:
                                                        _weatherNotifier,
                                                    ephemeris: widget.ephemeris,
                                                  ),
                                                  const SizedBox(height: 20),
                                                  PlantRecommendationsCard(
                                                    info: info,
                                                    selectedDate: selectedTime,
                                                    weatherNotifier:
                                                        _weatherNotifier,
                                                    ephemeris: widget.ephemeris,
                                                    latitude:
                                                        _latNotifier.value,
                                                    seasons: seasons,
                                                    gardenController:
                                                        _gardenController,
                                                    onPlanCropRequested:
                                                        (crop) {
                                                          _openTaskPlannerFor(
                                                            crop: crop,
                                                          );
                                                        },
                                                  ),
                                                  const SizedBox(height: 20),
                                                ],
                                                BiodynamicCard(
                                                  info: info,
                                                  selectedDate: selectedTime,
                                                  seasons: seasons,
                                                  onTimeJump: _onDateJump,
                                                ),
                                                const SizedBox(height: 24),
                                              ],
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
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

  /// Element pigment accent color.
  final Color elementColor;

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
    required this.elementColor,
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
    final bgColor = Color.lerp(
      GoetheanPalette.topsoilWarm,
      elementColor,
      0.08,
    )!;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: GoetheanPalette.aspectGold.withValues(alpha: 0.16),
            width: 1.0,
          ),
          bottom: BorderSide(
            color: GoetheanPalette.aspectGold.withValues(alpha: 0.24),
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
        oldDelegate.elementColor != elementColor ||
        oldDelegate.child != child;
  }
}
