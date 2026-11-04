import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/algorithm.dart' as algo;
import '../../core/models/models.dart';
import '../../core/task_window_planner.dart';
import '../../core/vegetable_database.dart';
import '../../services/ephemeris_service.dart';
import '../../services/garden_service.dart';
import '../theme/goethean_palette.dart';
import 'field_journal_sheet.dart';
import 'organic_vessel_container.dart';

/// Drag payload carried when dragging a crop from the palette or moving an
/// existing planned crop bar across time or beds on the succession timeline.
final class SuccessionDragPayload {
  /// The crop being placed or moved.
  final VegetableEntry crop;

  /// Optional preferred planting action (`sowOutdoor` vs `transplant`).
  final TaskActionType? preferredAction;

  /// When moving an already-placed [QueuedGardenTask] bar, its task ID.
  final String? movingTaskId;

  /// Source bed name when dragging an already-placed bar.
  final String? sourceBedName;

  /// Creates an immutable [SuccessionDragPayload].
  const SuccessionDragPayload({
    required this.crop,
    this.preferredAction,
    this.movingTaskId,
    this.sourceBedName,
  });
}

/// Filter categories for the draggable crop palette in [BedSuccessionPlannerCard].
enum _PaletteFilter {
  all('All'),
  starred('★ Starred'),
  root('Root'),
  leaf('Leaf'),
  flower('Flower'),
  fruit('Fruit'),
  greenManure('Manure'),
  perennial('♾️ Perennials');

  final String label;
  const _PaletteFilter(this.label);
}

/// Time window span displayed across the bed timeline width.
enum _TimelineWindowSpan {
  threeMonths(3, '3M'),
  sixMonths(6, '6M'),
  fullYear(12, '12M');

  final int months;
  final String shortLabel;
  const _TimelineWindowSpan(this.months, this.shortLabel);
}

/// Interactive drag-and-drop bed succession planning tool where crops can be
/// dragged onto garden beds at specific points in time, rescheduled along a bed's
/// seasonal timeline, or moved across beds with live relay, indoor nursery
/// lead-time, and botanical family rotation feedback.
final class BedSuccessionPlannerCard extends StatefulWidget {
  /// Reactive controller managing the user's [GardenProfile], plots, and SQLite store.
  final GardenProfileController gardenController;

  /// Currently selected timeline instant.
  final DateTime selectedDate;

  /// Active [CalendarInfo] at [selectedDate], used when logging a planned slot.
  final CalendarInfo? info;

  /// Optional ephemeris service for snapping planned plantings to optimal Maria Thun windows.
  final EphemerisService? ephemeris;

  /// Optional weather notifier for FieldJournalSheet logging.
  final ValueNotifier<List<WeatherDataPoint>?>? weatherNotifier;

  /// Callback invoked when the user jumps the main timeline to a planned or active planting date.
  final ValueChanged<DateTime>? onTimeJump;

  /// Geographic latitude for cosmic window snapping.
  final double latitude;

  /// Geographic longitude for cosmic window snapping.
  final double longitude;

  /// Whether this planner is rendered in its dedicated full-screen view
  /// ([BedSuccessionPlannerPage]) with a pinned top palette, expanded bed list,
  /// and docked bottom inspector.
  final bool fullScreen;

  /// Optional callback invoked when the user taps the edit button on a bed row.
  final ValueChanged<GardenPlot>? onEditPlot;

  /// Creates an immutable [BedSuccessionPlannerCard].
  const BedSuccessionPlannerCard({
    super.key,
    required this.gardenController,
    required this.selectedDate,
    this.info,
    this.ephemeris,
    this.weatherNotifier,
    this.onTimeJump,
    this.latitude = DefaultLocations.copenhagenLatitude,
    this.longitude = DefaultLocations.copenhagenLongitude,
    this.fullScreen = false,
    this.onEditPlot,
  });

  @override
  State<BedSuccessionPlannerCard> createState() =>
      _BedSuccessionPlannerCardState();
}

final class _BedSuccessionPlannerCardState
    extends State<BedSuccessionPlannerCard> {
  static final TextStyle _yearLabelStyle = GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: GoetheanPalette.aspectGold,
  );
  static final TextStyle _titleHeaderStyle = GoogleFonts.cormorantGaramond(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: const Color(0xFFF6ECD8),
  );
  static final TextStyle _toolbarChipBoldWhiteStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  static final TextStyle _toolbarChipRegularWhiteStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    color: Colors.white,
  );
  static final TextStyle _toolbarCollapseChipStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: GoetheanPalette.aspectGold,
  );
  static final TextStyle _paletteFilterSelectedStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  static final TextStyle _paletteFilterUnselectedStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    fontWeight: FontWeight.w400,
    color: Colors.white70,
  );
  static final TextStyle _searchFieldTextStyle = GoogleFonts.outfit(
    fontSize: 11,
    color: Colors.white,
  );
  static final TextStyle _searchFieldHintStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    color: Colors.white38,
  );
  static final TextStyle _cropChipNameCompactStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  static final TextStyle _cropChipNameNormalStyle = GoogleFonts.outfit(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  static final TextStyle _cropChipMetaCompactStyle = GoogleFonts.outfit(
    fontSize: 9.5,
    color: const Color(0xFFF3E5C8),
  );
  static final TextStyle _cropChipMetaNormalStyle = GoogleFonts.outfit(
    fontSize: 10,
    color: const Color(0xFFF3E5C8),
  );
  static final TextStyle _dragFeedbackStyle = GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: const Color(0xFFF6ECD8),
  );
  static final TextStyle _monthAxisActiveStyle = GoogleFonts.outfit(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: GoetheanPalette.aspectGold,
  );
  static final TextStyle _monthAxisInactiveStyle = GoogleFonts.outfit(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: Colors.white60,
  );
  static final TextStyle _bedTitleStyle = GoogleFonts.outfit(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    color: const Color(0xFFF6ECD8),
  );
  static final TextStyle _nextOrganBadgeStyle = GoogleFonts.outfit(
    fontSize: 8.5,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  static final TextStyle _autoRelayBadgeStyle = GoogleFonts.outfit(
    fontSize: 8.5,
    fontWeight: FontWeight.w600,
    color: const Color(0xFFF6ECD8),
  );
  static final TextStyle _emptyTrackHintStyle = GoogleFonts.outfit(
    fontSize: 10,
    color: Colors.white38,
  );
  static final TextStyle _spanBarTitleStyle = GoogleFonts.outfit(
    fontSize: 9.5,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  static final TextStyle _moveSpanFeedbackStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  late int _planningYear;
  late int _windowStartMonth;
  _TimelineWindowSpan _windowSpan = _TimelineWindowSpan.fullYear;
  double _horizontalZoom = 1.0;
  bool _paletteCollapsed = false;
  bool _autoSnapToRelay = false;
  _PaletteFilter _paletteFilter = _PaletteFilter.all;
  TaskActionType? _preferredActionMode; // null = Auto, sowOutdoor, transplant
  String _cropSearchQuery = '';
  late final TextEditingController _searchController;
  late final ScrollController _horizontalTrackScrollController;

  /// Selected crop in the palette for tap-to-place accessibility.
  VegetableEntry? _selectedPaletteCrop;

  /// Selected planned task ID on a bed for fine-tuning / inspecting.
  String? _selectedPlannedTaskId;

  /// Reactive notifier for live drag hover evaluation so dragging over a track
  /// only updates the hovered bed track and preview banner without rebuilding
  /// the entire planner widget tree.
  final ValueNotifier<BedPlacementEvaluation?> _hoverEvaluationNotifier =
      ValueNotifier<BedPlacementEvaluation?>(null);

  /// Last snapped hover key to skip redundant [evaluateBedPlacement] calls
  /// when dragging within the same calendar day on the same plot.
  (
    String plotName,
    String cropId,
    int year,
    int month,
    int day,
    TaskActionType? preferredAction,
    String? movingTaskId,
  )?
  _lastHoverKey;

  /// Memoized palette crop list.
  (_PaletteFilter, String, Set<String>)? _cachedPaletteKey;
  List<VegetableEntry>? _cachedPaletteCrops;

  /// Memoized per-plot timeline spans, rotation advice, and succession plans
  /// invalidated when [GardenProfile] or selected day changes.
  GardenProfile? _lastCachedProfile;
  (int, int, int)? _lastCachedSelectedDay;
  final Map<
    String,
    (List<BedTimelineSpan>, PlotRotationAssessment, PlotSuccessionPlan)
  >
  _plotComputedCache = {};
  final Map<
    (String, String, int, String?, TaskActionType?),
    BedPlacementEvaluation
  >
  _plannedSpanEvalCache = {};
  final Map<
    (int, int, int, PlantQuality, TaskActionType, double, double),
    (String, Color)?
  >
  _cosmicAlignmentCache = {};

  static const List<String> _monthShort = [
    '',
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

  @override
  void initState() {
    super.initState();
    _planningYear = widget.selectedDate.year;
    _windowStartMonth = (widget.selectedDate.month - 1).clamp(1, 7);
    _searchController = TextEditingController();
    _horizontalTrackScrollController = ScrollController();
    widget.gardenController.addListener(_onGardenControllerChanged);
  }

  @override
  void didUpdateWidget(covariant BedSuccessionPlannerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gardenController != oldWidget.gardenController) {
      oldWidget.gardenController.removeListener(_onGardenControllerChanged);
      widget.gardenController.addListener(_onGardenControllerChanged);
      _onGardenControllerChanged();
    }
    if (widget.selectedDate.year != oldWidget.selectedDate.year &&
        _planningYear == oldWidget.selectedDate.year) {
      _planningYear = widget.selectedDate.year;
    }
    if (widget.ephemeris != oldWidget.ephemeris ||
        widget.latitude != oldWidget.latitude ||
        widget.longitude != oldWidget.longitude ||
        widget.info != oldWidget.info) {
      _cosmicAlignmentCache.clear();
    }
  }

  @override
  void dispose() {
    widget.gardenController.removeListener(_onGardenControllerChanged);
    _hoverEvaluationNotifier.dispose();
    _searchController.dispose();
    _horizontalTrackScrollController.dispose();
    super.dispose();
  }

  void _onGardenControllerChanged() {
    _lastCachedProfile = null;
    _plotComputedCache.clear();
    _plannedSpanEvalCache.clear();
    _clearHoverEvaluation();
  }

  void _clearHoverEvaluation() {
    _lastHoverKey = null;
    if (_hoverEvaluationNotifier.value != null) {
      _hoverEvaluationNotifier.value = null;
    }
  }

  void _ensurePlotCachesValid(GardenProfile profile) {
    final dayKey = (
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    if (!identical(_lastCachedProfile, profile) ||
        _lastCachedSelectedDay != dayKey) {
      _lastCachedProfile = profile;
      _lastCachedSelectedDay = dayKey;
      _plotComputedCache.clear();
      _plannedSpanEvalCache.clear();
    }
  }

  (List<BedTimelineSpan>, PlotRotationAssessment, PlotSuccessionPlan)
  _getPlotComputedData(String plotName) {
    if (_plotComputedCache[plotName] case final cached?) {
      return cached;
    }
    final spans = widget.gardenController.buildBedTimelineSpans(plotName);
    final rotation = widget.gardenController.evaluatePlotRotation(
      plotName,
      referenceTime: widget.selectedDate,
    );
    final successionPlan = widget.gardenController.buildPlotSuccessionPlan(
      plotName,
      referenceTime: widget.selectedDate,
    );
    final entry = (spans, rotation, successionPlan);
    _plotComputedCache[plotName] = entry;
    return entry;
  }

  BedPlacementEvaluation _getPlacementEvaluation({
    required String plotName,
    required String taskId,
    required VegetableEntry crop,
    required DateTime startDate,
    required TaskActionType? action,
  }) {
    final key = (
      plotName,
      taskId,
      startDate.millisecondsSinceEpoch,
      crop.id,
      action,
    );
    if (_plannedSpanEvalCache[key] case final cached?) {
      return cached;
    }
    final eval = widget.gardenController.evaluateBedPlacement(
      plotName: plotName,
      crop: crop,
      targetDate: startDate,
      preferredAction: action,
      movingTaskId: taskId,
    );
    _plannedSpanEvalCache[key] = eval;
    return eval;
  }

  BedPlacementEvaluation _getPlannedSpanEvaluation({
    required String plotName,
    required BedTimelineSpan span,
  }) => _getPlacementEvaluation(
    plotName: plotName,
    taskId: span.id,
    crop: span.crop!,
    startDate: span.startDate,
    action: span.plannedTask?.action,
  );

  (DateTime start, DateTime end) _activeWindowRange() {
    if (_windowSpan == _TimelineWindowSpan.fullYear) {
      return (
        DateTime(_planningYear, 1, 1),
        DateTime(_planningYear, 12, 31, 23, 59, 59),
      );
    }
    final spanMonths = _windowSpan.months;
    final maxStart = 13 - spanMonths;
    final startMonth = _windowStartMonth.clamp(1, maxStart);
    final endMonth = startMonth + spanMonths - 1;
    final lastDay = DateTime(_planningYear, endMonth + 1, 0).day;
    return (
      DateTime(_planningYear, startMonth, 1),
      DateTime(_planningYear, endMonth, lastDay, 23, 59, 59),
    );
  }

  void _stepWindow(int deltaMonths) {
    setState(() {
      if (_windowSpan == _TimelineWindowSpan.fullYear) {
        _planningYear += deltaMonths > 0 ? 1 : -1;
        return;
      }
      final maxStart = 13 - _windowSpan.months;
      final nextStart = _windowStartMonth + deltaMonths;
      if (nextStart < 1) {
        _planningYear -= 1;
        _windowStartMonth = maxStart;
      } else if (nextStart > maxStart) {
        _planningYear += 1;
        _windowStartMonth = 1;
      } else {
        _windowStartMonth = nextStart;
      }
    });
  }

  DateTime _dateFromDx(
    double dx,
    double trackWidth,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    final safeWidth = trackWidth <= 1.0 ? 1.0 : trackWidth;
    final fraction = (dx / safeWidth).clamp(0.0, 1.0);
    final totalMs = windowEnd.difference(windowStart).inMilliseconds;
    final targetMs =
        windowStart.millisecondsSinceEpoch + (totalMs * fraction).round();
    final raw = DateTime.fromMillisecondsSinceEpoch(targetMs);
    return DateTime(raw.year, raw.month, raw.day, 12);
  }

  double _fractionForDate(
    DateTime date,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    final totalMs = windowEnd.difference(windowStart).inMilliseconds;
    if (totalMs <= 0) return 0.0;
    final offsetMs = date.difference(windowStart).inMilliseconds;
    return (offsetMs / totalMs).clamp(0.0, 1.0);
  }

  List<VegetableEntry> _filteredPaletteCrops(Set<String> starredIds) {
    final cacheKey = (_paletteFilter, _cropSearchQuery, starredIds);
    if (_cachedPaletteKey case final prevKey?
        when prevKey.$1 == cacheKey.$1 &&
            prevKey.$2 == cacheKey.$2 &&
            setEquals(prevKey.$3, cacheKey.$3)) {
      if (_cachedPaletteCrops case final cached?) {
        return cached;
      }
    }

    final qualityFilter = switch (_paletteFilter) {
      _PaletteFilter.root => PlantQuality.root,
      _PaletteFilter.leaf => PlantQuality.leaf,
      _PaletteFilter.flower => PlantQuality.flower,
      _PaletteFilter.fruit => PlantQuality.fruit,
      _ => null,
    };
    final categoryFilter = _paletteFilter == _PaletteFilter.greenManure
        ? PlantCategory.greenManure
        : null;

    final searched = VegetableDatabase.search(
      _cropSearchQuery,
      quality: qualityFilter,
      category: categoryFilter,
    );

    final List<VegetableEntry> base;
    if (_paletteFilter == _PaletteFilter.perennial) {
      base = searched
          .where((c) => c.lifeCycle == PlantLifeCycle.perennial)
          .toList();
    } else if (_paletteFilter == _PaletteFilter.starred) {
      base = searched.where((c) => starredIds.contains(c.id)).toList();
    } else if (_cropSearchQuery.trim().isNotEmpty) {
      base = searched.toList();
    } else {
      base = searched
          .where((c) => c.lifeCycle != PlantLifeCycle.perennial)
          .toList();
    }

    // Prioritize starred crops first, then common succession vegetables.
    base.sort((a, b) {
      final aStar = starredIds.contains(a.id) ? 0 : 1;
      final bStar = starredIds.contains(b.id) ? 0 : 1;
      if (aStar != bStar) return aStar.compareTo(bStar);
      return a.nameEn.compareTo(b.nameEn);
    });
    final result = base.take(16).toList(growable: false);
    _cachedPaletteKey = cacheKey;
    _cachedPaletteCrops = result;
    return result;
  }

  Future<void> _handleDropOnBed({
    required GardenPlot plot,
    required SuccessionDragPayload payload,
    required DateTime rawTargetDate,
  }) async {
    final eval = widget.gardenController.evaluateBedPlacement(
      plotName: plot.name,
      crop: payload.crop,
      targetDate: rawTargetDate,
      preferredAction: payload.preferredAction ?? _preferredActionMode,
      movingTaskId: payload.movingTaskId,
    );

    final effectiveStart =
        (_autoSnapToRelay &&
            eval.status == BedPlacementStatus.bedOverlapWarning &&
            eval.suggestedRelayDate != null)
        ? eval.suggestedRelayDate!
        : eval.startDate;

    final placed = await widget.gardenController.placeCropOnBed(
      bedName: plot.name,
      crop: payload.crop,
      startDate: effectiveStart,
      action: eval.action,
      movingTaskId: payload.movingTaskId,
    );

    if (!mounted) return;
    _clearHoverEvaluation();
    setState(() {
      _selectedPlannedTaskId = placed.id;
    });
  }

  void _createStarterBeds() {
    widget.gardenController.upsertPlot(
      GardenPlot(
        name: 'Bed 1',
        areaName: 'Kitchen Garden',
        plotType: GardenPlotType.raisedBed,
        dimensions: '1.2m × 3.0m',
      ),
    );
    widget.gardenController.upsertPlot(
      GardenPlot(
        name: 'Bed 2',
        areaName: 'Kitchen Garden',
        plotType: GardenPlotType.openBed,
        dimensions: '1.2m × 3.0m',
      ),
    );
    widget.gardenController.upsertPlot(
      GardenPlot(
        name: 'Greenhouse Border',
        areaName: 'Glasshouse',
        plotType: GardenPlotType.greenhouse,
        dimensions: '0.8m × 4.0m',
      ),
    );
  }

  Color _statusColor(BedPlacementStatus status) => switch (status) {
    BedPlacementStatus.cleanRelay => const Color(0xFF10B981),
    BedPlacementStatus.staggeredHoldSaaning => const Color(0xFF38BDF8),
    BedPlacementStatus.bedOverlapWarning => const Color(0xFFF59E0B),
    BedPlacementStatus.familyRotationConflict => const Color(0xFFEF4444),
    BedPlacementStatus.outOfSeasonWarning => const Color(0xFFA78BFA),
  };

  QueuedGardenTask? _findSelectedTask(List<QueuedGardenTask> queue) {
    final id = _selectedPlannedTaskId;
    if (id == null) return null;
    for (final task in queue) {
      if (task.id == id &&
          task.plannedStartDate != null &&
          task.bedName != null) {
        return task;
      }
    }
    return null;
  }

  Future<void> _snapTaskToOptimalThunWindow(QueuedGardenTask task) async {
    final eph = widget.ephemeris;
    final start = task.plannedStartDate;
    final crop = task.crop;
    if (eph == null || start == null || crop == null) return;

    final searchStart = start.subtract(const Duration(days: 5));
    final result = TaskWindowPlanner.findUpcomingWindows(
      action: task.action,
      targetQuality: task.targetQuality,
      crop: crop,
      startTime: searchStart,
      ephemeris: eph,
      latitude: widget.latitude,
      longitude: widget.longitude,
      searchDays: 18,
      maxWindows: 6,
    );
    if (result.windows.isEmpty) return;

    TaskWindow best = result.windows.first;
    int bestDistanceHours = best.peakTime.difference(start).inHours.abs();
    for (final candidate in result.windows.skip(1)) {
      final dist = candidate.peakTime.difference(start).inHours.abs();
      final candidateBetterTier =
          candidate.suitability == TaskSuitability.optimal &&
          best.suitability != TaskSuitability.optimal;
      final sameTierCloser =
          candidate.suitability == best.suitability && dist < bestDistanceHours;
      if (candidateBetterTier || sameTierCloser) {
        best = candidate;
        bestDistanceHours = dist;
      }
    }

    await widget.gardenController.placeCropOnBed(
      bedName: task.bedName!,
      crop: crop,
      startDate: best.peakTime,
      action: task.action,
      targetQuality: task.targetQuality,
      movingTaskId: task.id,
      note:
          'Thun ${best.suitability == TaskSuitability.optimal ? "Optimal" : "Favorable"} window (${DateFormat("MMM d").format(best.peakTime)})',
    );
    if (!mounted) return;
    widget.onTimeJump?.call(best.peakTime);
  }

  /// Computes a concise biodynamic cosmic alignment summary for [targetDate]
  /// against [targetQuality] and [action].
  (String summary, Color badgeColor)? _describeCosmicAlignment({
    required DateTime targetDate,
    required PlantQuality targetQuality,
    required TaskActionType action,
  }) {
    final cacheKey = (
      targetDate.year,
      targetDate.month,
      targetDate.day,
      targetQuality,
      action,
      widget.latitude,
      widget.longitude,
    );
    if (_cosmicAlignmentCache.containsKey(cacheKey)) {
      return _cosmicAlignmentCache[cacheKey];
    }

    final eph = widget.ephemeris;
    final CalendarInfo? resolvedInfo;
    if (eph != null) {
      resolvedInfo = algo.getCalendarInfo(
        targetDate,
        eph,
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
    } else if (widget.info != null &&
        widget.selectedDate.year == targetDate.year &&
        widget.selectedDate.month == targetDate.month &&
        widget.selectedDate.day == targetDate.day) {
      resolvedInfo = widget.info;
    } else {
      resolvedInfo = null;
    }
    if (resolvedInfo == null) {
      _cosmicAlignmentCache[cacheKey] = null;
      return null;
    }

    (String, Color) result;
    if (resolvedInfo.isGrayDay) {
      final reason = resolvedInfo.message.isNotEmpty
          ? resolvedInfo.message
          : 'Lunar Node / Eclipse';
      result = (
        '🌑 Cosmic Rest ($reason) — tap "Snap to Thun Window"',
        const Color(0xFFEF4444),
      );
      _cosmicAlignmentCache[cacheKey] = result;
      return result;
    }

    final dayQuality = resolvedInfo.quality;
    final moonArc = resolvedInfo.isMoonAscending
        ? '↑ Ascending Moon'
        : '↓ Descending Moon (Pflanzzeit)';
    final matchesQuality = dayQuality == targetQuality;
    final needsDescending = action == TaskActionType.transplant;
    final descendingOk = !needsDescending || resolvedInfo.isMoonDescending;

    if (matchesQuality && descendingOk) {
      result = (
        '✨ Optimal ${dayQuality.displayName} Day · $moonArc',
        const Color(0xFF10B981),
      );
    } else if (matchesQuality && !descendingOk) {
      result = (
        '🌿 ${dayQuality.displayName} Day · $moonArc (Transplant prefers ↓ Descending)',
        GoetheanPalette.aspectGold,
      );
    } else {
      result = (
        '🌙 ${dayQuality.displayName} Day · $moonArc (Target: ${targetQuality.displayName} Day)',
        GoetheanPalette.getColor(dayQuality),
      );
    }
    _cosmicAlignmentCache[cacheKey] = result;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompactMobile = screenSize.width < 600 || screenSize.height < 640;

    return ListenableBuilder(
      listenable: widget.gardenController,
      builder: (context, _) {
        final profile = widget.gardenController.value;
        _ensurePlotCachesValid(profile);
        final plots = widget.gardenController.listPlots();
        final (windowStart, windowEnd) = _activeWindowRange();
        final paletteCrops = _filteredPaletteCrops(profile.starredCropIds);
        final selectedTask = _findSelectedTask(profile.taskQueue);

        if (widget.fullScreen) {
          return _buildFullScreenWorkspace(
            context: context,
            plots: plots,
            windowStart: windowStart,
            windowEnd: windowEnd,
            paletteCrops: paletteCrops,
            starredCropIds: profile.starredCropIds,
            selectedTask: selectedTask,
            isCompactMobile: isCompactMobile,
          );
        }

        return OrganicVesselContainer.inset(
          key: const ValueKey('bed_succession_planner_card'),
          accentColor: GoetheanPalette.leafWater,
          seed: 3.9,
          padding: EdgeInsets.all(isCompactMobile ? 8 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildToolbarAndControls(
                windowStart: windowStart,
                windowEnd: windowEnd,
                isCompactMobile: isCompactMobile,
                includeTitleHeader: true,
              ),
              const SizedBox(height: 8),
              if (!_paletteCollapsed) ...[
                _buildCropPalette(
                  paletteCrops,
                  profile.starredCropIds,
                  isCompactMobile: isCompactMobile,
                ),
                const SizedBox(height: 8),
              ],
              if (plots.isEmpty)
                _buildEmptyPlotsStarter()
              else
                _buildTimelineMatrixArea(
                  context: context,
                  plots: plots,
                  windowStart: windowStart,
                  windowEnd: windowEnd,
                  scrollableVertically: false,
                ),
              ValueListenableBuilder<BedPlacementEvaluation?>(
                valueListenable: _hoverEvaluationNotifier,
                builder: (context, hoverEval, _) {
                  if (hoverEval == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _buildLiveHoverBanner(hoverEval),
                  );
                },
              ),
              if (selectedTask != null) ...[
                const SizedBox(height: 8),
                _buildSelectedTaskInspector(context, selectedTask),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFullScreenWorkspace({
    required BuildContext context,
    required List<GardenPlot> plots,
    required DateTime windowStart,
    required DateTime windowEnd,
    required List<VegetableEntry> paletteCrops,
    required Set<String> starredCropIds,
    required QueuedGardenTask? selectedTask,
    required bool isCompactMobile,
  }) {
    final horizontalPad = isCompactMobile ? 6.0 : 14.0;
    return Container(
      key: const ValueKey('bed_succession_planner_card'),
      padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Pinned Compact Controls Bar
          _buildToolbarAndControls(
            windowStart: windowStart,
            windowEnd: windowEnd,
            isCompactMobile: isCompactMobile,
            includeTitleHeader: false,
          ),
          const SizedBox(height: 6),

          // 2. Pinned Compact Crop Palette (collapsible to give 100% height to beds)
          if (!_paletteCollapsed) ...[
            _buildCropPalette(
              paletteCrops,
              starredCropIds,
              isCompactMobile: isCompactMobile,
            ),
            const SizedBox(height: 6),
          ],

          // 3. Expanded Bed × Time Succession Matrix (fills remaining viewport)
          Expanded(
            child: plots.isEmpty
                ? Center(child: _buildEmptyPlotsStarter())
                : _buildTimelineMatrixArea(
                    context: context,
                    plots: plots,
                    windowStart: windowStart,
                    windowEnd: windowEnd,
                    scrollableVertically: true,
                  ),
          ),

          // 4. Docked Bottom Live Hover Banner & Selected Crop Inspector
          ValueListenableBuilder<BedPlacementEvaluation?>(
            valueListenable: _hoverEvaluationNotifier,
            builder: (context, hoverEval, _) {
              if (hoverEval == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildLiveHoverBanner(hoverEval),
              );
            },
          ),
          if (selectedTask != null) ...[
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: isCompactMobile ? 195 : 240,
              ),
              child: SingleChildScrollView(
                child: _buildSelectedTaskInspector(context, selectedTask),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbarAndControls({
    required DateTime windowStart,
    required DateTime windowEnd,
    required bool isCompactMobile,
    required bool includeTitleHeader,
  }) {
    final shortYear = "'${(_planningYear % 100).toString().padLeft(2, '0')}";
    final rangeLabel = _windowSpan == _TimelineWindowSpan.fullYear
        ? '$_planningYear'
        : isCompactMobile
        ? '${_monthShort[windowStart.month]}–${_monthShort[windowEnd.month]} $shortYear'
        : '${_monthShort[windowStart.month]}–${_monthShort[windowEnd.month]} $_planningYear';

    final yearAndWindowStepper = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('bed_timeline_prev_year'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: _windowSpan == _TimelineWindowSpan.fullYear
              ? 'Previous Year'
              : 'Previous Window',
          icon: const Icon(Icons.chevron_left, size: 18, color: Colors.white70),
          onPressed: () => _stepWindow(-_windowSpan.months),
        ),
        Text(
          rangeLabel,
          key: const ValueKey('bed_timeline_year_label'),
          style: _yearLabelStyle,
        ),
        IconButton(
          key: const ValueKey('bed_timeline_next_year'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: _windowSpan == _TimelineWindowSpan.fullYear
              ? 'Next Year'
              : 'Next Window',
          icon: const Icon(
            Icons.chevron_right,
            size: 18,
            color: Colors.white70,
          ),
          onPressed: () => _stepWindow(_windowSpan.months),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (includeTitleHeader) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: GoetheanPalette.leafWater.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.view_timeline_outlined,
                  size: 17,
                  color: GoetheanPalette.aspectGold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bed Succession Timeline',
                  style: _titleHeaderStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              yearAndWindowStepper,
            ],
          ),
          const SizedBox(height: 6),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (!includeTitleHeader) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: yearAndWindowStepper,
                ),
                const SizedBox(width: 6),
              ],
              // Window toggle (cycles 12M / 6M / 3M; preserves bed_timeline_window_toggle key)
              ChoiceChip(
                key: const ValueKey('bed_timeline_window_toggle'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.symmetric(
                  horizontal: isCompactMobile ? 2 : 6,
                ),
                labelPadding: EdgeInsets.symmetric(
                  horizontal: isCompactMobile ? 3 : 6,
                ),
                label: Text(switch (_windowSpan) {
                  _TimelineWindowSpan.fullYear =>
                    isCompactMobile ? '12M' : '🗓️ 12M',
                  _TimelineWindowSpan.sixMonths =>
                    isCompactMobile ? '6M' : '🔍 6M Focus',
                  _TimelineWindowSpan.threeMonths =>
                    isCompactMobile ? '3M' : '🔬 3M Quarter',
                }, style: _toolbarChipBoldWhiteStyle),
                selected: _windowSpan != _TimelineWindowSpan.fullYear,
                selectedColor: GoetheanPalette.aspectGold.withValues(
                  alpha: 0.28,
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                showCheckmark: false,
                onSelected: (_) {
                  setState(() {
                    _windowSpan = switch (_windowSpan) {
                      _TimelineWindowSpan.fullYear =>
                        _TimelineWindowSpan.sixMonths,
                      _TimelineWindowSpan.sixMonths =>
                        _TimelineWindowSpan.threeMonths,
                      _TimelineWindowSpan.threeMonths =>
                        _TimelineWindowSpan.fullYear,
                    };
                    if (_windowSpan != _TimelineWindowSpan.fullYear) {
                      final maxStart = 13 - _windowSpan.months;
                      _windowStartMonth = (widget.selectedDate.month - 1).clamp(
                        1,
                        maxStart,
                      );
                    }
                  });
                },
              ),
              const SizedBox(width: 4),
              // Horizontal Zoom toggle for wide mobile bars
              ChoiceChip(
                key: const ValueKey('bed_timeline_zoom_toggle'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.symmetric(
                  horizontal: isCompactMobile ? 2 : 6,
                ),
                labelPadding: EdgeInsets.symmetric(
                  horizontal: isCompactMobile ? 3 : 6,
                ),
                label: Text(
                  _horizontalZoom <= 1.01
                      ? (isCompactMobile ? '1× Fit' : '↔ 1× Fit')
                      : (isCompactMobile
                            ? '${_horizontalZoom.toStringAsFixed(0)}× Wide'
                            : '↔ ${_horizontalZoom.toStringAsFixed(1)}× Wide'),
                  style: _toolbarChipBoldWhiteStyle,
                ),
                selected: _horizontalZoom > 1.01,
                selectedColor: GoetheanPalette.leafWater.withValues(
                  alpha: 0.28,
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                showCheckmark: false,
                onSelected: (_) {
                  setState(() {
                    if (_horizontalZoom <= 1.01) {
                      _horizontalZoom = 2.0;
                    } else if (_horizontalZoom <= 2.1) {
                      _horizontalZoom = 3.0;
                    } else {
                      _horizontalZoom = 1.0;
                    }
                  });
                },
              ),
              const SizedBox(width: 4),
              ActionChip(
                key: const ValueKey('bed_palette_collapse_toggle'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.symmetric(
                  horizontal: isCompactMobile ? 2 : 6,
                ),
                labelPadding: EdgeInsets.symmetric(
                  horizontal: isCompactMobile ? 3 : 6,
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                label: Text(
                  _paletteCollapsed
                      ? (isCompactMobile ? '▼ Crops' : '▼ Show Crops')
                      : (isCompactMobile ? '▲ Crops' : '▲ Hide Crops'),
                  style: _toolbarCollapseChipStyle,
                ),
                onPressed: () {
                  setState(() {
                    _paletteCollapsed = !_paletteCollapsed;
                  });
                },
              ),
              const SizedBox(width: 4),
              FilterChip(
                key: const ValueKey('bed_timeline_auto_snap_relay'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.symmetric(
                  horizontal: isCompactMobile ? 2 : 6,
                ),
                labelPadding: EdgeInsets.symmetric(
                  horizontal: isCompactMobile ? 3 : 6,
                ),
                label: Text(
                  isCompactMobile
                      ? '🧲 Snap'
                      : '🧲 Auto-Snap Overlaps to Relay',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    color: _autoSnapToRelay
                        ? const Color(0xFF6EE7B7)
                        : Colors.white70,
                  ),
                ),
                selected: _autoSnapToRelay,
                selectedColor: const Color(0xFF10B981).withValues(alpha: 0.24),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                showCheckmark: false,
                onSelected: (val) {
                  setState(() {
                    _autoSnapToRelay = val;
                  });
                },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                key: const ValueKey('bed_timeline_mode_auto'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.symmetric(
                  horizontal: isCompactMobile ? 2 : 6,
                ),
                labelPadding: EdgeInsets.symmetric(
                  horizontal: isCompactMobile ? 3 : 6,
                ),
                label: Text(
                  isCompactMobile ? 'Auto' : 'Auto Sow/Transplant',
                  style: _toolbarChipRegularWhiteStyle,
                ),
                selected: _preferredActionMode == null,
                selectedColor: GoetheanPalette.aspectGold.withValues(
                  alpha: 0.28,
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                showCheckmark: false,
                onSelected: (_) {
                  setState(() {
                    _preferredActionMode = null;
                  });
                },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                key: const ValueKey('bed_timeline_mode_sow'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.symmetric(
                  horizontal: isCompactMobile ? 2 : 6,
                ),
                labelPadding: EdgeInsets.symmetric(
                  horizontal: isCompactMobile ? 3 : 6,
                ),
                label: Text(
                  isCompactMobile ? '🌱 Sow' : '🌱 Direct Sow',
                  style: _toolbarChipRegularWhiteStyle,
                ),
                selected: _preferredActionMode == TaskActionType.sowOutdoor,
                selectedColor: GoetheanPalette.leafWater.withValues(alpha: 0.3),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                showCheckmark: false,
                onSelected: (_) {
                  setState(() {
                    _preferredActionMode = TaskActionType.sowOutdoor;
                  });
                },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                key: const ValueKey('bed_timeline_mode_transplant'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.symmetric(
                  horizontal: isCompactMobile ? 2 : 6,
                ),
                labelPadding: EdgeInsets.symmetric(
                  horizontal: isCompactMobile ? 3 : 6,
                ),
                label: Text(
                  isCompactMobile ? '🪴 Modules' : '🪴 Transplant (Modules)',
                  style: _toolbarChipRegularWhiteStyle,
                ),
                selected: _preferredActionMode == TaskActionType.transplant,
                selectedColor: GoetheanPalette.aspectGold.withValues(
                  alpha: 0.3,
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                showCheckmark: false,
                onSelected: (_) {
                  setState(() {
                    _preferredActionMode = TaskActionType.transplant;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineMatrixArea({
    required BuildContext context,
    required List<GardenPlot> plots,
    required DateTime windowStart,
    required DateTime windowEnd,
    required bool scrollableVertically,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 380.0;
        final isZoomed = _horizontalZoom > 1.01;
        final canvasWidth = math.max(
          viewportWidth,
          viewportWidth * _horizontalZoom,
        );

        Widget buildRowsColumn() {
          final rows = <Widget>[
            for (final plot in plots)
              _buildBedTimelineRow(
                context: context,
                plot: plot,
                windowStart: windowStart,
                windowEnd: windowEnd,
              ),
          ];
          if (!scrollableVertically) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMonthAxisHeader(windowStart, windowEnd),
                const SizedBox(height: 4),
                ...rows,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMonthAxisHeader(windowStart, windowEnd),
              const SizedBox(height: 4),
              Expanded(
                child: ListView(
                  key: const ValueKey('bed_planner_vertical_scroll'),
                  padding: const EdgeInsets.only(bottom: 12),
                  children: rows,
                ),
              ),
            ],
          );
        }

        if (!isZoomed) {
          return buildRowsColumn();
        }

        return Scrollbar(
          controller: _horizontalTrackScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            key: const ValueKey('bed_planner_horizontal_scroll'),
            controller: _horizontalTrackScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: canvasWidth, child: buildRowsColumn()),
          ),
        );
      },
    );
  }

  Widget _buildCropPalette(
    List<VegetableEntry> crops,
    Set<String> starredIds, {
    required bool isCompactMobile,
  }) {
    final chipsWrap = Wrap(
      spacing: isCompactMobile ? 5 : 6,
      runSpacing: isCompactMobile ? 5 : 6,
      children: [
        for (final crop in crops)
          _buildDraggableCropChip(
            crop,
            starredIds.contains(crop.id),
            compact: isCompactMobile,
          ),
      ],
    );

    return RepaintBoundary(
      child: Container(
        key: const ValueKey('bed_succession_crop_palette'),
        padding: EdgeInsets.all(isCompactMobile ? 7 : 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in _PaletteFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ChoiceChip(
                              key: ValueKey(
                                'bed_palette_filter_${filter.name}',
                              ),
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                filter.label,
                                style: _paletteFilter == filter
                                    ? _paletteFilterSelectedStyle
                                    : _paletteFilterUnselectedStyle,
                              ),
                              selected: _paletteFilter == filter,
                              selectedColor: GoetheanPalette.aspectGold
                                  .withValues(alpha: 0.28),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                              showCheckmark: false,
                              onSelected: (_) {
                                setState(() {
                                  _paletteFilter = filter;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: isCompactMobile ? 124 : 150,
                  child: TextField(
                    key: const ValueKey('bed_succession_crop_search'),
                    controller: _searchController,
                    onChanged: (v) {
                      setState(() {
                        _cropSearchQuery = v;
                      });
                    },
                    style: _searchFieldTextStyle,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Filter crops...',
                      hintStyle: _searchFieldHintStyle,
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 13,
                        color: GoetheanPalette.aspectGold,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 22,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (crops.isEmpty)
              Text(
                'No crops match the selected filter.',
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white54),
              )
            else if (isCompactMobile)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 68),
                child: SingleChildScrollView(child: chipsWrap),
              )
            else
              chipsWrap,
            if (_selectedPaletteCrop != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '💡 Armed "${_selectedPaletteCrop!.nameEn}" — tap anywhere on a bed track below to place it at that date.',
                      key: const ValueKey('bed_palette_selected_hint'),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: GoetheanPalette.aspectGold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPaletteCrop = null;
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.close, size: 13, color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableCropChip(
    VegetableEntry crop,
    bool isStarred, {
    bool compact = false,
  }) {
    final organColor = GoetheanPalette.getColor(crop.quality);
    final maturity = CropMaturityProfile.forCrop(crop);
    final refMonth = widget.selectedDate.month;
    final effectiveAction = BedSuccessionAdvisor.resolveActionForCrop(
      crop: crop,
      month: refMonth,
      preferredAction: _preferredActionMode,
    );
    final daysInGround = maturity.seasonalDaysInGround(
      refMonth,
      action: effectiveAction == TaskActionType.transplant
          ? FieldJournalAction.transplant
          : FieldJournalAction.sowSeeds,
    );
    final nurseryLead = effectiveAction == TaskActionType.transplant
        ? maturity.seasonalModuleLeadTimeDays(refMonth)
        : 0;
    final isSelected = _selectedPaletteCrop?.id == crop.id;

    final payload = SuccessionDragPayload(
      crop: crop,
      preferredAction: _preferredActionMode,
    );

    final chipBody = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3.5 : 5,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? organColor.withValues(alpha: 0.32)
            : organColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? GoetheanPalette.aspectGold
              : organColor.withValues(alpha: 0.55),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.drag_indicator,
            size: compact ? 11 : 13,
            color: organColor.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 2),
          Text(
            '${isStarred ? "★ " : ""}${crop.nameEn}',
            style: compact
                ? _cropChipNameCompactStyle
                : _cropChipNameNormalStyle,
          ),
          const SizedBox(width: 4),
          Text(
            maturity.isPerennial
                ? '♾️'
                : '~${daysInGround}d'
                      '${nurseryLead > 0 ? " (🪴${nurseryLead}d)" : ""}'
                      '${maturity.supportsStaggeredSowing ? " 🔁" : ""}',
            style: compact
                ? _cropChipMetaCompactStyle
                : _cropChipMetaNormalStyle,
          ),
        ],
      ),
    );

    return Draggable<SuccessionDragPayload>(
      key: ValueKey('draggable_crop_${crop.id}'),
      data: payload,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragEnd: (_) {
        if (mounted) {
          _clearHoverEvaluation();
        }
      },
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1A14).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: organColor, width: 1.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            '${effectiveAction == TaskActionType.transplant ? "🪴" : "🌱"} ${crop.nameEn} (~${daysInGround}d in bed)',
            style: _dragFeedbackStyle,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.45, child: chipBody),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            _selectedPaletteCrop = isSelected ? null : crop;
          });
        },
        child: chipBody,
      ),
    );
  }

  Widget _buildLiveHoverBanner(BedPlacementEvaluation eval) {
    final color = _statusColor(eval.status);
    final cosmic = _describeCosmicAlignment(
      targetDate: eval.startDate,
      targetQuality: eval.crop.quality,
      action: eval.action,
    );
    return Container(
      key: const ValueKey('bed_succession_live_preview_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.65), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            eval.headline,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            eval.detailMessage,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              color: const Color(0xFFF6ECD8),
            ),
          ),
          if (cosmic != null) ...[
            const SizedBox(height: 2),
            Text(
              cosmic.$1,
              key: const ValueKey('bed_hover_cosmic_alignment'),
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: cosmic.$2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyPlotsStarter() {
    return Container(
      key: const ValueKey('bed_succession_empty_plots'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.grid_view_outlined,
            color: GoetheanPalette.aspectGold,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add your garden beds or create starter beds to drag and drop crops onto a seasonal timeline.',
              style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            key: const ValueKey('bed_succession_create_starter_beds'),
            onPressed: _createStarterBeds,
            icon: const Icon(Icons.add, size: 15),
            label: Text(
              'Create Starter Beds',
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthAxisHeader(DateTime windowStart, DateTime windowEnd) {
    final months = <int>[];
    int m = windowStart.month;
    while (m <= windowEnd.month) {
      months.add(m);
      m++;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          for (final month in months)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  border: Border(
                    left: BorderSide(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _monthShort[month],
                  style:
                      (widget.selectedDate.year == _planningYear &&
                          widget.selectedDate.month == month)
                      ? _monthAxisActiveStyle
                      : _monthAxisInactiveStyle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBedTimelineRow({
    required BuildContext context,
    required GardenPlot plot,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    final (spans, rotation, successionPlan) = _getPlotComputedData(plot.name);
    final nextOrganColor = GoetheanPalette.getColor(
      rotation.recommendedNextQuality,
    );

    final visibleSpans = spans
        .where(
          (s) =>
              s.overlapsRange(windowStart, windowEnd) ||
              (s.indoorStartDate != null &&
                  s.indoorStartDate!.isBefore(windowEnd) &&
                  s.endDate.isAfter(windowStart)),
        )
        .toList(growable: false);

    final maxLane = visibleSpans.isEmpty
        ? 0
        : visibleSpans.map((s) => s.laneIndex).reduce((a, b) => a > b ? a : b);
    final laneCount = (maxLane + 1).clamp(1, 5);
    final trackHeight = (laneCount * 28.0 + 10.0).clamp(42.0, 155.0);

    final monthsCount = windowEnd.month - windowStart.month + 1;
    final selectedDateFraction =
        (widget.selectedDate.year == _planningYear &&
            !widget.selectedDate.isBefore(windowStart) &&
            !widget.selectedDate.isAfter(windowEnd))
        ? _fractionForDate(widget.selectedDate, windowStart, windowEnd)
        : null;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ValueListenableBuilder<BedPlacementEvaluation?>(
          valueListenable: _hoverEvaluationNotifier,
          builder: (context, hoverEval, _) {
            final hoverOnThisPlot = hoverEval?.plot.name == plot.name
                ? hoverEval
                : null;
            return Container(
              key: ValueKey('bed_succession_row_${plot.name}'),
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hoverOnThisPlot != null
                      ? _statusColor(hoverOnThisPlot.status)
                      : Colors.white.withValues(alpha: 0.14),
                  width: hoverOnThisPlot != null ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compact Bed Row Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${plot.plotType.glyph} ${plot.displayTitle}'
                          '${plot.plotType.isProtectedEnvironment ? " (±1m)" : ""}',
                          style: _bedTitleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        flex: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: nextOrganColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: nextOrganColor.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            'Next: ${rotation.recommendedNextQuality.name.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _nextOrganBadgeStyle,
                          ),
                        ),
                      ),
                      if (successionPlan.candidates.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          flex: 0,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 135),
                            child: InkWell(
                              key: ValueKey('bed_auto_relay_${plot.name}'),
                              borderRadius: BorderRadius.circular(5),
                              onTap: () async {
                                final top = successionPlan.candidates.first;
                                await _handleDropOnBed(
                                  plot: plot,
                                  payload: SuccessionDragPayload(
                                    crop: top.crop,
                                    preferredAction:
                                        top.taskAction ==
                                            TaskActionType.transplant
                                        ? TaskActionType.transplant
                                        : TaskActionType.sowOutdoor,
                                  ),
                                  rawTargetDate: top.targetPlotDate,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: GoetheanPalette.aspectGold.withValues(
                                    alpha: 0.18,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: GoetheanPalette.aspectGold
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  '+ Relay: ${successionPlan.candidates.first.crop.nameEn}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _autoRelayBadgeStyle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (widget.onEditPlot != null) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          key: ValueKey('bed_planner_edit_plot_${plot.name}'),
                          borderRadius: BorderRadius.circular(5),
                          onTap: () => widget.onEditPlot!(plot),
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 13,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Interactive Timeline Track (DragTarget + Tap-to-place)
                  LayoutBuilder(
                    builder: (trackContext, constraints) {
                      final trackWidth = constraints.maxWidth;
                      return DragTarget<SuccessionDragPayload>(
                        key: ValueKey('bed_timeline_track_${plot.name}'),
                        onWillAcceptWithDetails: (_) => true,
                        onMove: (details) {
                          final box =
                              trackContext.findRenderObject() as RenderBox?;
                          if (box == null || !box.hasSize) return;
                          final localPos = box.globalToLocal(details.offset);
                          final targetDate = _dateFromDx(
                            localPos.dx,
                            trackWidth,
                            windowStart,
                            windowEnd,
                          );
                          final effectivePreferred =
                              details.data.preferredAction ??
                              _preferredActionMode;
                          final hoverKey = (
                            plot.name,
                            details.data.crop.id,
                            targetDate.year,
                            targetDate.month,
                            targetDate.day,
                            effectivePreferred,
                            details.data.movingTaskId,
                          );
                          if (_lastHoverKey == hoverKey &&
                              _hoverEvaluationNotifier.value != null) {
                            return;
                          }
                          _lastHoverKey = hoverKey;
                          final eval = widget.gardenController
                              .evaluateBedPlacement(
                                plotName: plot.name,
                                crop: details.data.crop,
                                targetDate: targetDate,
                                preferredAction: effectivePreferred,
                                movingTaskId: details.data.movingTaskId,
                              );
                          _hoverEvaluationNotifier.value = eval;
                        },
                        onLeave: (_) {
                          if (_hoverEvaluationNotifier.value?.plot.name ==
                              plot.name) {
                            _clearHoverEvaluation();
                          }
                        },
                        onAcceptWithDetails: (details) {
                          final box =
                              trackContext.findRenderObject() as RenderBox?;
                          DateTime targetDate = widget.selectedDate;
                          if (box != null && box.hasSize) {
                            final localPos = box.globalToLocal(details.offset);
                            targetDate = _dateFromDx(
                              localPos.dx,
                              trackWidth,
                              windowStart,
                              windowEnd,
                            );
                          }
                          _handleDropOnBed(
                            plot: plot,
                            payload: details.data,
                            rawTargetDate: targetDate,
                          );
                        },
                        builder: (context, candidateData, _) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (tapDetails) {
                              final paletteCrop = _selectedPaletteCrop;
                              if (paletteCrop == null) return;
                              final targetDate = _dateFromDx(
                                tapDetails.localPosition.dx,
                                trackWidth,
                                windowStart,
                                windowEnd,
                              );
                              _handleDropOnBed(
                                plot: plot,
                                payload: SuccessionDragPayload(
                                  crop: paletteCrop,
                                  preferredAction: _preferredActionMode,
                                ),
                                rawTargetDate: targetDate,
                              );
                            },
                            child: Container(
                              height: trackHeight,
                              width: trackWidth,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.34),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: candidateData.isNotEmpty
                                      ? GoetheanPalette.aspectGold
                                      : Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  // Month grid lines & selected date marker rendered in a single CustomPaint pass
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _BedTrackGridPainter(
                                          monthsCount: monthsCount,
                                          selectedDateFraction:
                                              selectedDateFraction,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Empty track hint when no spans exist on this bed
                                  if (visibleSpans.isEmpty &&
                                      hoverOnThisPlot == null)
                                    Center(
                                      child: Text(
                                        _selectedPaletteCrop != null
                                            ? 'Tap anywhere on ${plot.name} to place ${_selectedPaletteCrop!.nameEn}'
                                            : 'Drag or tap-place a crop onto ${plot.name}',
                                        style: _emptyTrackHintStyle,
                                      ),
                                    ),

                                  // Existing Harvested, Active, and Planned spans
                                  if (trackWidth > 12.0)
                                    for (final span in visibleSpans) ...[
                                      if (span.indoorStartDate != null &&
                                          span.indoorStartDate!.isBefore(
                                            span.startDate,
                                          ))
                                        _buildNurseryTailBar(
                                          span: span,
                                          trackWidth: trackWidth,
                                          windowStart: windowStart,
                                          windowEnd: windowEnd,
                                        ),
                                      _buildTimelineSpanBar(
                                        span: span,
                                        plot: plot,
                                        trackWidth: trackWidth,
                                        windowStart: windowStart,
                                        windowEnd: windowEnd,
                                      ),
                                    ],

                                  // Live Ghost Bar when hovering a drag over this bed
                                  if (hoverOnThisPlot != null &&
                                      trackWidth > 12.0)
                                    _buildGhostPreviewBar(
                                      eval: hoverOnThisPlot,
                                      laneIndex: maxLane,
                                      trackWidth: trackWidth,
                                      windowStart: windowStart,
                                      windowEnd: windowEnd,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNurseryTailBar({
    required BedTimelineSpan span,
    required double trackWidth,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    final startFrac = _fractionForDate(
      span.indoorStartDate!,
      windowStart,
      windowEnd,
    );
    final endFrac = _fractionForDate(span.startDate, windowStart, windowEnd);
    final maxLeft = math.max(0.0, trackWidth - 8.0);
    final left = (startFrac * trackWidth).clamp(0.0, maxLeft).toDouble();
    final availWidth = math.max(0.0, trackWidth - left);
    final width = ((endFrac - startFrac) * trackWidth)
        .clamp(math.min(12.0, availWidth), availWidth)
        .toDouble();
    final top = 5.0 + span.laneIndex * 28.0 + 4.0;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: 15,
      child: Container(
        key: ValueKey('nursery_tail_${span.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: GoetheanPalette.aspectGold.withValues(alpha: 0.18),
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
          border: Border.all(
            color: GoetheanPalette.aspectGold.withValues(alpha: 0.55),
          ),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          '🪴 ${span.nurseryLeadDays}d',
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: _autoRelayBadgeStyle,
        ),
      ),
    );
  }

  Widget _buildTimelineSpanBar({
    required BedTimelineSpan span,
    required GardenPlot plot,
    required double trackWidth,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    final startFrac = _fractionForDate(span.startDate, windowStart, windowEnd);
    final endFrac = _fractionForDate(span.endDate, windowStart, windowEnd);
    final maxLeft = math.max(0.0, trackWidth - 28.0);
    final left = (startFrac * trackWidth).clamp(0.0, maxLeft).toDouble();
    final availWidth = math.max(0.0, trackWidth - left);
    final width = ((endFrac - startFrac) * trackWidth)
        .clamp(math.min(36.0, availWidth), availWidth)
        .toDouble();
    final top = 5.0 + span.laneIndex * 28.0;
    final organColor = GoetheanPalette.getColor(span.quality);
    final isSelected =
        span.kind == BedTimelineSpanKind.planned &&
        _selectedPlannedTaskId == span.id;

    BedPlacementEvaluation? plannedEval;
    if (span.kind == BedTimelineSpanKind.planned && span.crop != null) {
      plannedEval = _getPlannedSpanEvaluation(plotName: plot.name, span: span);
    }
    final hasConflict =
        plannedEval != null &&
        (plannedEval.status == BedPlacementStatus.familyRotationConflict ||
            plannedEval.status == BedPlacementStatus.bedOverlapWarning);

    final barColor = switch (span.kind) {
      BedTimelineSpanKind.harvested => organColor.withValues(alpha: 0.16),
      BedTimelineSpanKind.activeInGround => organColor.withValues(alpha: 0.42),
      BedTimelineSpanKind.planned => organColor.withValues(alpha: 0.28),
    };

    final borderColor = hasConflict
        ? _statusColor(plannedEval.status)
        : (isSelected
              ? GoetheanPalette.aspectGold
              : organColor.withValues(
                  alpha: span.kind == BedTimelineSpanKind.harvested
                      ? 0.4
                      : 0.85,
                ));

    final isPerennialCrop = span.crop?.lifeCycle == PlantLifeCycle.perennial;
    final dateRangeText = isPerennialCrop
        ? '${_monthShort[span.startDate.month]} ${span.startDate.day}→♾️ Perennial'
        : '${_monthShort[span.startDate.month]} ${span.startDate.day}→${_monthShort[span.endDate.month]} ${span.endDate.day}';
    final barWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor,
          width: (isSelected || hasConflict) ? 1.6 : 1.1,
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        '${hasConflict ? "${plannedEval.status.glyph} " : "${span.kind.glyph} "}${span.title} ($dateRangeText)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _spanBarTitleStyle,
      ),
    );

    if (span.kind == BedTimelineSpanKind.planned && span.crop != null) {
      final dragPayload = SuccessionDragPayload(
        crop: span.crop!,
        preferredAction: span.plannedTask?.action,
        movingTaskId: span.id,
        sourceBedName: plot.name,
      );
      return Positioned(
        left: left,
        top: top,
        width: width,
        height: 24,
        child: Draggable<SuccessionDragPayload>(
          key: ValueKey('planned_bed_span_${span.id}'),
          data: dragPayload,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          onDragEnd: (_) {
            if (mounted) {
              _clearHoverEvaluation();
            }
          },
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              width: width.clamp(90.0, 180.0),
              height: 25,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1A14).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: GoetheanPalette.aspectGold,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                '📅 Move ${span.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _moveSpanFeedbackStyle,
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: barWidget),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedPlannedTaskId = isSelected ? null : span.id;
              });
            },
            child: barWidget,
          ),
        ),
      );
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: 24,
      child: GestureDetector(
        key: ValueKey('logged_bed_span_${span.id}'),
        onTap: () => widget.onTimeJump?.call(span.startDate),
        child: barWidget,
      ),
    );
  }

  Widget _buildGhostPreviewBar({
    required BedPlacementEvaluation eval,
    required int laneIndex,
    required double trackWidth,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    final startFrac = _fractionForDate(eval.startDate, windowStart, windowEnd);
    final endFrac = _fractionForDate(eval.endDate, windowStart, windowEnd);
    final maxLeft = math.max(0.0, trackWidth - 28.0);
    final left = (startFrac * trackWidth).clamp(0.0, maxLeft).toDouble();
    final availWidth = math.max(0.0, trackWidth - left);
    final width = ((endFrac - startFrac) * trackWidth)
        .clamp(math.min(36.0, availWidth), availWidth)
        .toDouble();
    final top = 5.0 + laneIndex * 28.0;
    final color = _statusColor(eval.status);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: 24,
      child: IgnorePointer(
        child: Container(
          key: const ValueKey('bed_timeline_ghost_bar'),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color, width: 1.5),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            '${eval.status.glyph} ${eval.crop.nameEn} (${_monthShort[eval.startDate.month]} ${eval.startDate.day}→${_monthShort[eval.endDate.month]} ${eval.endDate.day})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _spanBarTitleStyle,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTaskInspector(
    BuildContext context,
    QueuedGardenTask task,
  ) {
    final crop = task.crop;
    final bedName = task.bedName!;
    final start = task.plannedStartDate!;
    final eval = crop != null
        ? _getPlacementEvaluation(
            plotName: bedName,
            taskId: task.id,
            crop: crop,
            startDate: start,
            action: task.action,
          )
        : null;
    final statusColor = eval != null
        ? _statusColor(eval.status)
        : GoetheanPalette.aspectGold;
    final maturity = crop != null ? CropMaturityProfile.forCrop(crop) : null;

    return Container(
      key: const ValueKey('selected_planned_span_inspector'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  eval?.headline ?? task.summaryLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                icon: const Icon(Icons.close, size: 15, color: Colors.white60),
                onPressed: () {
                  setState(() {
                    _selectedPlannedTaskId = null;
                  });
                },
              ),
            ],
          ),
          if (eval != null) ...[
            const SizedBox(height: 1),
            Text(
              eval.detailMessage,
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                color: const Color(0xFFF6ECD8),
              ),
            ),
          ],
          if (_describeCosmicAlignment(
                targetDate: start,
                targetQuality: task.targetQuality,
                action: task.action,
              )
              case final cosmic?) ...[
            const SizedBox(height: 3),
            Text(
              cosmic.$1,
              key: const ValueKey('inspector_cosmic_alignment'),
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: cosmic.$2,
              ),
            ),
          ],
          if (crop != null && crop.secondaryOrganRules.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              key: const ValueKey('planned_span_organ_selector'),
              spacing: 5,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Organ Target:',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                for (final option
                    in <(String id, String label, PlantQuality quality)>[
                      (
                        'primary',
                        'Primary (${crop.quality.displayName})',
                        crop.quality,
                      ),
                      for (final rule in crop.secondaryOrganRules)
                        (
                          rule.id,
                          '${rule.labelEn} (${rule.quality.displayName})',
                          rule.quality,
                        ),
                    ])
                  ChoiceChip(
                    key: ValueKey('organ_target_${option.$1}'),
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                    selected: task.targetQuality == option.$3,
                    selectedColor: GoetheanPalette.getColor(option.$3)
                        .withValues(alpha: 0.32),
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    label: Text(
                      option.$2,
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: task.targetQuality == option.$3
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    onSelected: (_) {
                      widget.gardenController.placeCropOnBed(
                        bedName: bedName,
                        crop: crop,
                        startDate: start,
                        action: task.action,
                        targetQuality: option.$3,
                        movingTaskId: task.id,
                      );
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              OutlinedButton(
                key: const ValueKey('planned_span_shift_earlier'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  minimumSize: const Size(44, 26),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: crop == null
                    ? null
                    : () {
                        widget.gardenController.placeCropOnBed(
                          bedName: bedName,
                          crop: crop,
                          startDate: start.subtract(const Duration(days: 7)),
                          action: task.action,
                          movingTaskId: task.id,
                        );
                      },
                child: Text(
                  '◀ -7d',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton(
                key: const ValueKey('planned_span_shift_later'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  minimumSize: const Size(44, 26),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: crop == null
                    ? null
                    : () {
                        widget.gardenController.placeCropOnBed(
                          bedName: bedName,
                          crop: crop,
                          startDate: start.add(const Duration(days: 7)),
                          action: task.action,
                          movingTaskId: task.id,
                        );
                      },
                child: Text(
                  '+7d ▶',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (eval?.suggestedRelayDate case final relayDate?
                  when crop != null)
                OutlinedButton.icon(
                  key: const ValueKey('planned_span_snap_relay'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6EE7B7),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    minimumSize: const Size(52, 26),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    widget.gardenController.placeCropOnBed(
                      bedName: bedName,
                      crop: crop,
                      startDate: relayDate,
                      action: task.action,
                      movingTaskId: task.id,
                    );
                  },
                  icon: const Icon(Icons.auto_fix_high_outlined, size: 12),
                  label: Text(
                    'Snap to Relay (${_monthShort[relayDate.month]} ${relayDate.day})',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (widget.ephemeris != null && crop != null)
                OutlinedButton.icon(
                  key: const ValueKey('planned_span_snap_thun'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GoetheanPalette.aspectGold,
                    side: BorderSide(
                      color: GoetheanPalette.aspectGold.withValues(alpha: 0.6),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    minimumSize: const Size(52, 26),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _snapTaskToOptimalThunWindow(task),
                  icon: const Icon(Icons.auto_awesome_outlined, size: 12),
                  label: Text(
                    'Snap to Thun Window',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (crop != null)
                OutlinedButton(
                  key: const ValueKey('planned_span_toggle_action'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF6ECD8),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    minimumSize: const Size(52, 26),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    final nextAction = task.action == TaskActionType.transplant
                        ? TaskActionType.sowOutdoor
                        : TaskActionType.transplant;
                    widget.gardenController.placeCropOnBed(
                      bedName: bedName,
                      crop: crop,
                      startDate: start,
                      action: nextAction,
                      movingTaskId: task.id,
                    );
                  },
                  child: Text(
                    task.action == TaskActionType.transplant
                        ? 'Switch to 🌱 Direct Sow'
                        : 'Switch to 🪴 Transplant',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (maturity != null &&
                  crop != null &&
                  maturity.supportsStaggeredSowing)
                OutlinedButton.icon(
                  key: const ValueKey('planned_span_add_staggered'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    minimumSize: const Size(52, 26),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () async {
                    final interval = maturity.seasonalStaggeredIntervalDays(
                      start.month,
                    );
                    final nextDate = start.add(Duration(days: interval));
                    final nextTask = await widget.gardenController
                        .placeCropOnBed(
                          bedName: bedName,
                          crop: crop,
                          startDate: nextDate,
                          action: task.action,
                          targetQuality: task.targetQuality,
                          note: 'Hold-såning (+${interval}d)',
                        );
                    if (mounted) {
                      setState(() {
                        _selectedPlannedTaskId = nextTask.id;
                      });
                    }
                  },
                  icon: const Icon(Icons.repeat, size: 12),
                  label: Text(
                    '+ Hold-såning (+${maturity.seasonalStaggeredIntervalDays(start.month)}d)',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (widget.info != null)
                OutlinedButton.icon(
                  key: const ValueKey('planned_span_log_planted'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: GoetheanPalette.leafWater.withValues(alpha: 0.65),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    minimumSize: const Size(52, 26),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    final eph = widget.ephemeris;
                    final resolvedInfo = eph != null
                        ? algo.getCalendarInfo(
                            start,
                            eph,
                            includePlanets: true,
                            latitude: widget.latitude,
                            longitude: widget.longitude,
                          )
                        : widget.info!;
                    FieldJournalSheet.show(
                      context,
                      gardenController: widget.gardenController,
                      timestamp: start,
                      calendarInfo: resolvedInfo,
                      weatherSeries: widget.weatherNotifier?.value,
                      initialAction: task.action == TaskActionType.transplant
                          ? FieldJournalAction.transplant
                          : FieldJournalAction.sowSeeds,
                      initialCrop: crop,
                      initialQuality: task.targetQuality,
                      initialBedName: bedName,
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 12),
                  label: Text(
                    'Log as Planted',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                key: const ValueKey('planned_span_delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(
                    color: Colors.redAccent.withValues(alpha: 0.45),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  minimumSize: const Size(52, 26),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  widget.gardenController.removeQueuedTask(task.id);
                  setState(() {
                    _selectedPlannedTaskId = null;
                  });
                },
                icon: const Icon(Icons.delete_outline, size: 12),
                label: Text(
                  'Remove',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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

/// Lightweight custom painter for the bed timeline background grid and
/// selected-date marker, replacing 12+ layout children per bed row.
final class _BedTrackGridPainter extends CustomPainter {
  final int monthsCount;
  final double? selectedDateFraction;

  const _BedTrackGridPainter({
    required this.monthsCount,
    required this.selectedDateFraction,
  });

  static final Paint _gridLinePaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.08)
    ..strokeWidth = 1.0;

  static final Paint _selectedDateLinePaint = Paint()
    ..color = GoetheanPalette.aspectGold.withValues(alpha: 0.65)
    ..strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 ||
        size.height <= 0 ||
        !size.width.isFinite ||
        !size.height.isFinite) {
      return;
    }

    if (monthsCount > 1) {
      final step = size.width / monthsCount;
      for (var i = 1; i < monthsCount; i++) {
        final x = step * i;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), _gridLinePaint);
      }
    }

    final fraction = selectedDateFraction;
    if (fraction != null && fraction.isFinite && size.width > 1.5) {
      final x = (fraction * size.width)
          .clamp(0.0, math.max(0.0, size.width - 1.5))
          .toDouble();
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        _selectedDateLinePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BedTrackGridPainter oldDelegate) {
    return oldDelegate.monthsCount != monthsCount ||
        oldDelegate.selectedDateFraction != selectedDateFraction;
  }
}
