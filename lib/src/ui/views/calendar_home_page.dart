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
import '../components/field_journal_card.dart';
import '../components/field_journal_sheet.dart';
import '../components/home_header.dart';
import '../components/organic_vessel_container.dart';
import '../components/planetary_ribbon.dart';
import '../components/plant_quality_card.dart';
import '../components/plant_recommendations_card.dart';
import '../components/task_planner_card.dart';
import '../components/week_ahead_card.dart';
import '../theme/goethean_palette.dart';
import 'bed_succession_planner_page.dart';
import 'time_scroll_view.dart';

/// Top-level workspace mode on the home screen.
enum _CalendarWorkspaceMode {
  /// Inspect cosmic and terrestrial conditions for the currently selected time.
  inspectTime,

  /// Plan a specific task ("When is a good time to...?") and jump to upcoming windows.
  planTask,

  /// Browse and log entries in the shared Biodynamic Garden Diary.
  gardenDiary,
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
  static const DiurnalSolarLighting _defaultLighting = DiurnalSolarLighting(
    lx: -0.4,
    ly: -0.7,
    lz: 0.5,
    sunAltitude: 0.6,
    daylightFactor: 0.9,
  );
  static final Color _bgMidColor = Color.lerp(
    GoetheanPalette.compostDark,
    const Color(0xFF2B2219),
    0.45,
  )!;
  static final TextStyle _modeSelectedTitleStyle = GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: const Color(0xFFF6ECD8),
  );
  static final TextStyle _modeUnselectedTitleStyle = GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Colors.white70,
  );
  static final TextStyle _modeSelectedSubtitleStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    color: Colors.white70,
  );
  static final TextStyle _modeUnselectedSubtitleStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    color: Colors.white38,
  );

  late final ValueNotifier<DateTime> _selectedDateNotifier;
  late final ValueNotifier<DateTime> _cardDateNotifier;
  late final ValueNotifier<DateTime> _diaryDateNotifier = ValueNotifier(
    DateTime(
      _selectedDateNotifier.value.year,
      _selectedDateNotifier.value.month,
      _selectedDateNotifier.value.day,
      12,
    ),
  );
  int? _lastInfoBucket;
  int? _lastInfoHourBucket;
  DateTime? _lastLoadedWindowCenter;
  final ValueNotifier<CalendarInfo?> _infoNotifier = ValueNotifier(null);
  final ValueNotifier<Color> _elementColorNotifier = ValueNotifier(
    GoetheanPalette.leafWater,
  );
  final ValueNotifier<(Color, DiurnalSolarLighting)> _lightingNotifier =
      ValueNotifier((GoetheanPalette.leafWater, _defaultLighting));
  final ValueNotifier<List<WeatherDataPoint>?> _weatherNotifier = ValueNotifier(
    null,
  );
  final ValueNotifier<ClimateProfile?> _climateNotifier = ValueNotifier(null);
  late GardenProfileController _gardenController;
  late bool _ownsGardenController;
  late final ValueNotifier<double> _latNotifier;
  late final ValueNotifier<double> _lonNotifier;
  late Listenable _timelineDependenciesListenable;
  late final Listenable _climateAndLocationListenable;
  late final Listenable _cardInfoAndDateListenable;
  late final Listenable _diaryInfoAndDateListenable;
  final _timeScrollController = TimeScrollController();
  late WeatherService _weatherService;
  int _weatherRequestId = 0;
  int _climateRequestId = 0;
  bool _syncingLocation = false;

  _CalendarWorkspaceMode _workspaceMode = _CalendarWorkspaceMode.inspectTime;
  TaskActionType? _plannerInitialAction;
  VegetableEntry? _plannerInitialCrop;

  @override
  void initState() {
    super.initState();
    final initialTime = DateTime.now();
    _selectedDateNotifier = ValueNotifier(initialTime);
    _cardDateNotifier = ValueNotifier(initialTime);
    _diaryDateNotifier.value = DateTime(
      initialTime.year,
      initialTime.month,
      initialTime.day,
      12,
    );
    _lastLoadedWindowCenter = initialTime;
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
    _timelineDependenciesListenable = Listenable.merge([
      _latNotifier,
      _lonNotifier,
      _gardenController,
    ]);
    _climateAndLocationListenable = Listenable.merge([
      _climateNotifier,
      _latNotifier,
      _lonNotifier,
    ]);
    _cardInfoAndDateListenable = Listenable.merge([
      _infoNotifier,
      _cardDateNotifier,
    ]);
    _diaryInfoAndDateListenable = Listenable.merge([
      _infoNotifier,
      _diaryDateNotifier,
    ]);
    _latNotifier.addListener(_onLocationChanged);
    _lonNotifier.addListener(_onLocationChanged);
    _gardenController.addListener(_onGardenProfileChanged);
    _fetchWeather();
    _fetchClimate();
    _updateInfo(_selectedDateNotifier.value, immediate: true);
  }

  @override
  void didUpdateWidget(covariant CalendarHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gardenController != oldWidget.gardenController) {
      _gardenController.removeListener(_onGardenProfileChanged);
      if (_ownsGardenController) {
        _gardenController.dispose();
      }
      if (widget.gardenController != null) {
        _gardenController = widget.gardenController!;
        _ownsGardenController = false;
      } else {
        _gardenController = GardenProfileController();
        _ownsGardenController = true;
      }
      _gardenController.addListener(_onGardenProfileChanged);
      _timelineDependenciesListenable = Listenable.merge([
        _latNotifier,
        _lonNotifier,
        _gardenController,
      ]);
      _onGardenProfileChanged();
    }
    if (widget.weather != oldWidget.weather) {
      _weatherService = widget.weather;
      _fetchWeather();
    }
    if (widget.climate != oldWidget.climate) {
      _climateNotifier.value = null;
      _fetchClimate();
    }
    if (widget.ephemeris != oldWidget.ephemeris) {
      _lastInfoBucket = null;
      _lastInfoHourBucket = null;
      _updateInfo(_selectedDateNotifier.value, immediate: true);
    }
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
    final requestId = ++_weatherRequestId;
    final lat = _latNotifier.value;
    final lon = _lonNotifier.value;
    final now = DateTime.now();
    try {
      final forecast = await _weatherService.getForecast(lat, lon);
      if (!mounted || requestId != _weatherRequestId) return;
      final combined = <WeatherDataPoint>[...forecast];
      try {
        final history = await _weatherService.getHistoricalData(
          lat,
          lon,
          now.subtract(const Duration(hours: 72)),
          now,
        );
        if (!mounted || requestId != _weatherRequestId) return;
        combined.addAll(history.where((p) => !p.time.isAfter(now)));
        combined.sort((a, b) => a.time.compareTo(b.time));
      } catch (_) {
        // Proceed with forecast if historical archive fetch fails.
      }
      if (!mounted || requestId != _weatherRequestId) return;
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

  void _syncLighting(CalendarInfo? info, DateTime cardTime) {
    final elementColor = info != null
        ? GoetheanPalette.getColor(info.quality)
        : GoetheanPalette.leafWater;
    _elementColorNotifier.value = elementColor;
    final lighting = info != null
        ? DiurnalSolarLighting.compute(cardTime, info)
        : _defaultLighting;
    _lightingNotifier.value = (elementColor, lighting);
  }

  void _updateInfo(DateTime time, {bool immediate = false}) {
    final bucket = time.millisecondsSinceEpoch ~/ 900000; // 15-minute bucket
    if (!immediate &&
        _lastInfoBucket == bucket &&
        _infoNotifier.value != null) {
      return;
    }
    _lastInfoBucket = bucket;
    final hourBucket = time.millisecondsSinceEpoch ~/ 3600000;
    final hourChanged = _lastInfoHourBucket != hourBucket;
    _lastInfoHourBucket = hourBucket;

    final queryTime = immediate
        ? time
        : DateTime.fromMillisecondsSinceEpoch(
            bucket * 900000,
            isUtc: time.isUtc,
          );
    try {
      final prevInfo = _infoNotifier.value;
      final info = algo.getCalendarInfo(
        queryTime,
        widget.ephemeris,
        includePlanets: true,
        latitude: _latNotifier.value,
        longitude: _lonNotifier.value,
      );
      final transitionOccurred =
          prevInfo != null &&
          (prevInfo.quality != info.quality ||
              prevInfo.isGrayDay != info.isGrayDay ||
              prevInfo.isSpecial != info.isSpecial ||
              prevInfo.isApogee != info.isApogee ||
              prevInfo.isMoonSaturnOpposition != info.isMoonSaturnOpposition ||
              prevInfo.isEclipse != info.isEclipse ||
              prevInfo.message != info.message ||
              prevInfo.sapFlow != info.sapFlow ||
              prevInfo.vitality != info.vitality ||
              prevInfo.isMoonAscending != info.isMoonAscending ||
              prevInfo.transitionEnvelope?.isTransition !=
                  info.transitionEnvelope?.isTransition ||
              prevInfo.transitionEnvelope?.toQuality !=
                  info.transitionEnvelope?.toQuality);

      if (immediate || prevInfo == null || hourChanged || transitionOccurred) {
        _infoNotifier.value = info;
      }
      if (prevInfo != null &&
          (prevInfo.quality != info.quality ||
              prevInfo.isGrayDay != info.isGrayDay ||
              prevInfo.isMoonAscending != info.isMoonAscending)) {
        _cardDateNotifier.value = time;
      }
      _syncLighting(_infoNotifier.value ?? info, _cardDateNotifier.value);
    } catch (e) {
      debugPrint('Failed to update calendar info: $e');
    }
  }

  /// Handles a selection that originated *from* the timeline.
  ///
  /// Deliberately does not call back into the timeline: it is already showing
  /// the chosen instant, and scrolling it again would fight the user's drag.
  void _onTimeSelected(DateTime time, {bool immediate = false}) {
    _selectedDateNotifier.value = time;

    final prevHourBucket =
        _cardDateNotifier.value.millisecondsSinceEpoch ~/ 3600000;
    final nextHourBucket = time.millisecondsSinceEpoch ~/ 3600000;
    if (immediate || prevHourBucket != nextHourBucket) {
      _cardDateNotifier.value = immediate
          ? time
          : DateTime.fromMillisecondsSinceEpoch(
              nextHourBucket * 3600000,
              isUtc: time.isUtc,
            );
    }

    _updateInfo(time, immediate: immediate);

    final prevDay = _diaryDateNotifier.value;
    if (immediate ||
        prevDay.year != time.year ||
        prevDay.month != time.month ||
        prevDay.day != time.day) {
      _diaryDateNotifier.value = DateTime(time.year, time.month, time.day, 12);
    }

    if (immediate ||
        _lastLoadedWindowCenter == null ||
        time.difference(_lastLoadedWindowCenter!).inHours.abs() >= 24) {
      _lastLoadedWindowCenter = time;
      _gardenController.ensureWindowLoaded(
        time.subtract(const Duration(days: 60)),
        time.add(const Duration(days: 60)),
      );
    }
  }

  /// Handles a selection made outside the timeline, e.g. the header's date
  /// picker, which must also bring the timeline to the chosen instant.
  void _onDateJump(DateTime time) {
    _onTimeSelected(time, immediate: true);
    _timeScrollController.scrollToTime(time);
  }

  void _openTaskPlannerFor({TaskActionType? action, VegetableEntry? crop}) {
    setState(() {
      _plannerInitialAction = action;
      _plannerInitialCrop = crop;
      _workspaceMode = _CalendarWorkspaceMode.planTask;
    });
  }

  void _openBedPlannerPage() {
    BedSuccessionPlannerPage.open(
      context,
      gardenController: _gardenController,
      selectedDate: _cardDateNotifier.value,
      info: _infoNotifier.value,
      ephemeris: widget.ephemeris,
      weatherNotifier: _weatherNotifier,
      onTimeJump: _onDateJump,
      latitude: _latNotifier.value,
      longitude: _lonNotifier.value,
    );
  }

  Widget _buildModeSwitcher(Color elementColor) {
    final isNarrow = MediaQuery.sizeOf(context).width < 680;
    final inspectBtn = _buildModeButton(
      key: const ValueKey('mode_inspect_time_button'),
      mode: _CalendarWorkspaceMode.inspectTime,
      icon: Icons.access_time_outlined,
      title: isNarrow ? 'At Selected Time' : 'What To Do At Selected Time',
      subtitle: 'Right now / inspect timeline',
      accentColor: elementColor,
    );
    final planTaskBtn = _buildModeButton(
      key: const ValueKey('mode_plan_task_button'),
      mode: _CalendarWorkspaceMode.planTask,
      icon: Icons.event_available_outlined,
      title: isNarrow ? 'When To Sow...?' : 'When Is a Good Time To...?',
      subtitle: 'Cuttings, sow, prune, harvest',
      accentColor: GoetheanPalette.aspectGold,
    );
    final diaryBtn = _buildModeButton(
      key: const ValueKey('mode_garden_diary_button'),
      mode: _CalendarWorkspaceMode.gardenDiary,
      icon: Icons.menu_book_outlined,
      title: 'Garden Diary',
      subtitle: 'Log work, notes & shared beds',
      accentColor: GoetheanPalette.aspectGold,
    );
    final bedPlannerBtn = _buildModeButton(
      key: const ValueKey('mode_bed_planner_button'),
      mode: null,
      onTapOverride: _openBedPlannerPage,
      icon: Icons.view_timeline_outlined,
      title: 'Bed Planner',
      subtitle: 'Full-screen crop succession',
      accentColor: GoetheanPalette.leafWater,
    );

    return OrganicVesselContainer.inset(
      accentColor: GoetheanPalette.aspectGold,
      seed: 1.9,
      padding: const EdgeInsets.all(6),
      child: isNarrow
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: inspectBtn),
                    const SizedBox(width: 6),
                    Expanded(child: planTaskBtn),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: diaryBtn),
                    const SizedBox(width: 6),
                    Expanded(child: bedPlannerBtn),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: inspectBtn),
                const SizedBox(width: 8),
                Expanded(child: planTaskBtn),
                const SizedBox(width: 8),
                Expanded(child: diaryBtn),
                const SizedBox(width: 8),
                Expanded(child: bedPlannerBtn),
              ],
            ),
    );
  }

  Widget _buildModeButton({
    required Key key,
    required _CalendarWorkspaceMode? mode,
    VoidCallback? onTapOverride,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    final isSelected = mode != null && _workspaceMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap:
            onTapOverride ??
            () {
              if (mode != null) {
                setState(() {
                  _workspaceMode = mode;
                });
              }
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
                      style: isSelected
                          ? _modeSelectedTitleStyle
                          : _modeUnselectedTitleStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: isSelected
                          ? _modeSelectedSubtitleStyle
                          : _modeUnselectedSubtitleStyle,
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
    _cardDateNotifier.dispose();
    _diaryDateNotifier.dispose();
    _infoNotifier.dispose();
    _elementColorNotifier.dispose();
    _lightingNotifier.dispose();
    _weatherNotifier.dispose();
    _climateNotifier.dispose();
    _latNotifier.dispose();
    _lonNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timelineChild = RepaintBoundary(
      child: ListenableBuilder(
        listenable: _timelineDependenciesListenable,
        builder: (context, _) {
          return TimeScrollView(
            key: const PageStorageKey('sticky_time_scroll_view'),
            ephemeris: widget.ephemeris,
            weatherService: _weatherService,
            controller: _timeScrollController,
            onTimeSelected: _onTimeSelected,
            onWeatherDataChanged: (weather) {
              _weatherNotifier.value = weather;
            },
            journalEntries: _gardenController.value.journalEntries,
            queuedTasks: _gardenController.value.taskQueue,
            onJournalEntryTapped: (entry) {
              final currentInfo = _infoNotifier.value;
              if (currentInfo != null) {
                FieldJournalSheet.show(
                  context,
                  gardenController: _gardenController,
                  timestamp: entry.timestamp,
                  calendarInfo: currentInfo,
                  weatherSeries: _weatherNotifier.value,
                  existingEntry: entry,
                );
              }
            },
            onPlannedTaskTapped: (task) {
              final currentInfo = _infoNotifier.value;
              final plannedDate = task.plannedStartDate;
              if (currentInfo != null && plannedDate != null) {
                FieldJournalSheet.show(
                  context,
                  gardenController: _gardenController,
                  timestamp: plannedDate,
                  calendarInfo: currentInfo,
                  weatherSeries: _weatherNotifier.value,
                  initialAction: task.action == TaskActionType.transplant
                      ? FieldJournalAction.transplant
                      : FieldJournalAction.sowSeeds,
                  initialCrop: task.crop,
                  initialQuality: task.targetQuality,
                  initialBedName: task.bedName,
                );
              }
            },
            latitude: _latNotifier.value,
            longitude: _lonNotifier.value,
          );
        },
      ),
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile ? 8.0 : 16.0;
    final sectionSpacing = isMobile ? 14.0 : 20.0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: ValueListenableBuilder<(Color, DiurnalSolarLighting)>(
                valueListenable: _lightingNotifier,
                builder: (context, state, _) {
                  final (elementColor, lighting) = state;

                  final bgTop = Color.lerp(
                    GoetheanPalette.topsoilWarm,
                    elementColor,
                    0.14 * lighting.daylightFactor + 0.06,
                  )!;
                  const bgBottom = GoetheanPalette.compostDark;

                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(lighting.lx * 0.6, -1.0),
                        end: Alignment(-lighting.lx * 0.4, 1.0),
                        colors: [bgTop, _bgMidColor, bgBottom],
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
                                      alpha:
                                          0.20 * lighting.daylightFactor + 0.08,
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
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: ListenableBuilder(
              listenable: _climateAndLocationListenable,
              builder: (context, _) {
                final climateProfile = _climateNotifier.value;
                final SeasonAlignment seasons = climateProfile != null
                    ? ClimateSeasonAlignment(local: climateProfile)
                    : HemisphereSeasonAlignment(latitude: _latNotifier.value);

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
                              climateNotifier: _climateNotifier,
                              gardenController: _gardenController,
                              onNowPressed: () {
                                _onDateJump(DateTime.now());
                              },
                              onDateSelected: _onDateJump,
                            ),
                            SizedBox(height: sectionSpacing),
                            RepaintBoundary(
                              child: ListenableBuilder(
                                listenable: _cardInfoAndDateListenable,
                                builder: (context, _) {
                                  final info = _infoNotifier.value;
                                  if (info == null) {
                                    return const SizedBox(height: 140);
                                  }
                                  return PlantQualityCard(
                                    info: info,
                                    selectedTime: _cardDateNotifier.value,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ValueListenableBuilder<Color>(
                      valueListenable: _elementColorNotifier,
                      builder: (context, elementColor, _) {
                        return SliverPersistentHeader(
                          pinned: true,
                          delegate: _StickyTimelineDelegate(
                            height: 200.0,
                            horizontalPadding: horizontalPadding,
                            elementColor: elementColor,
                            child: timelineChild,
                          ),
                        );
                      },
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        sectionSpacing,
                        horizontalPadding,
                        24.0,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          RepaintBoundary(
                            child: ValueListenableBuilder<Color>(
                              valueListenable: _elementColorNotifier,
                              builder: (context, elementColor, _) {
                                return _buildModeSwitcher(elementColor);
                              },
                            ),
                          ),
                          SizedBox(height: sectionSpacing),
                          if (_workspaceMode ==
                              _CalendarWorkspaceMode.planTask) ...[
                            RepaintBoundary(
                              child: ValueListenableBuilder<DateTime>(
                                valueListenable: _cardDateNotifier,
                                builder: (context, selectedTime, _) {
                                  return TaskPlannerCard(
                                    selectedDate: selectedTime,
                                    ephemeris: widget.ephemeris,
                                    weatherNotifier: _weatherNotifier,
                                    latitude: _latNotifier.value,
                                    longitude: _lonNotifier.value,
                                    seasons: seasons,
                                    gardenController: _gardenController,
                                    onTimeJump: _onDateJump,
                                    initialAction: _plannerInitialAction,
                                    initialCrop: _plannerInitialCrop,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (_workspaceMode ==
                              _CalendarWorkspaceMode.gardenDiary) ...[
                            RepaintBoundary(
                              child: ListenableBuilder(
                                listenable: _diaryInfoAndDateListenable,
                                builder: (context, _) {
                                  final info = _infoNotifier.value;
                                  if (info == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return FieldJournalCard(
                                    gardenController: _gardenController,
                                    selectedDate: _diaryDateNotifier.value,
                                    info: info,
                                    weatherNotifier: _weatherNotifier,
                                    onTimeJump: _onDateJump,
                                    ephemeris: widget.ephemeris,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          PlanetaryRibbon(
                            timeNotifier: _selectedDateNotifier,
                            ephemeris: widget.ephemeris,
                          ),
                          SizedBox(height: sectionSpacing),
                          if (_workspaceMode ==
                              _CalendarWorkspaceMode.inspectTime) ...[
                            RepaintBoundary(
                              child: CelestialDetailsCard(
                                selectedDateNotifier: _cardDateNotifier,
                                weatherNotifier: _weatherNotifier,
                                ephemeris: widget.ephemeris,
                              ),
                            ),
                            const SizedBox(height: 20),
                            RepaintBoundary(
                              child: ListenableBuilder(
                                listenable: _cardInfoAndDateListenable,
                                builder: (context, _) {
                                  final info = _infoNotifier.value;
                                  if (info == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return PlantRecommendationsCard(
                                    info: info,
                                    selectedDate: _cardDateNotifier.value,
                                    weatherNotifier: _weatherNotifier,
                                    ephemeris: widget.ephemeris,
                                    latitude: _latNotifier.value,
                                    seasons: seasons,
                                    gardenController: _gardenController,
                                    onPlanCropRequested: (crop) {
                                      _openTaskPlannerFor(crop: crop);
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          RepaintBoundary(
                            child: ListenableBuilder(
                              listenable: _cardInfoAndDateListenable,
                              builder: (context, _) {
                                final info = _infoNotifier.value;
                                if (info == null) {
                                  return const SizedBox.shrink();
                                }
                                return BiodynamicCard(
                                  info: info,
                                  selectedDate: _cardDateNotifier.value,
                                  seasons: seasons,
                                  onTimeJump: _onDateJump,
                                  ephemeris: widget.ephemeris,
                                  weatherNotifier: _weatherNotifier,
                                  latitude: _latNotifier.value,
                                  longitude: _lonNotifier.value,
                                  gardenController: _gardenController,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          RepaintBoundary(
                            child: ValueListenableBuilder<DateTime>(
                              valueListenable: _cardDateNotifier,
                              builder: (context, selectedTime, _) {
                                return WeekAheadCard(
                                  selectedDate: selectedTime,
                                  ephemeris: widget.ephemeris,
                                  weatherNotifier: _weatherNotifier,
                                  latitude: _latNotifier.value,
                                  longitude: _lonNotifier.value,
                                  seasons: seasons,
                                  gardenController: _gardenController,
                                  onTimeJump: _onDateJump,
                                );
                              },
                            ),
                          ),
                          if (_workspaceMode !=
                              _CalendarWorkspaceMode.gardenDiary) ...[
                            const SizedBox(height: 20),
                            RepaintBoundary(
                              child: ListenableBuilder(
                                listenable: _diaryInfoAndDateListenable,
                                builder: (context, _) {
                                  final info = _infoNotifier.value;
                                  if (info == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return FieldJournalCard(
                                    gardenController: _gardenController,
                                    selectedDate: _diaryDateNotifier.value,
                                    info: info,
                                    weatherNotifier: _weatherNotifier,
                                    onTimeJump: _onDateJump,
                                    ephemeris: widget.ephemeris,
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ]),
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
