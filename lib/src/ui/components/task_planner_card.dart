import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/algorithm.dart' as algo;
import '../../core/climate/climate.dart';
import '../../core/ics_calendar_exporter.dart';
import '../../core/models/models.dart';
import '../../core/task_window_planner.dart';
import '../../core/vegetable_database.dart';
import '../../services/garden_service.dart';
import '../theme/goethean_palette.dart';
import 'field_journal_sheet.dart';
import 'ics_export_sheet.dart';
import 'organic_vessel_container.dart';

/// Interactive task-focused planner card answering "When is a good time to...?"
/// by combining a [TaskActionType] with a specific [VegetableEntry] or [PlantQuality]
/// and finding upcoming Maria Thun windows on the timeline.
final class TaskPlannerCard extends StatefulWidget {
  /// Currently selected inspection date on the timeline.
  final DateTime selectedDate;

  /// Ephemeris service used to compute upcoming cosmic windows.
  final EphemerisService ephemeris;

  /// Optional notifier supplying weather forecast points.
  final ValueNotifier<List<WeatherDataPoint>?>? weatherNotifier;

  /// Geographic latitude for seasonal and diurnal adaptation.
  final double latitude;

  /// Geographic longitude for topocentric sun/moon calculations.
  final double longitude;

  /// Optional seasonal alignment mapping local climate onto the Danish reference calendar.
  final SeasonAlignment? seasons;

  /// Optional reactive controller for the user's persisted garden profile.
  final GardenProfileController? gardenController;

  /// Callback invoked when the user selects a found window or jumps to a prime season.
  final ValueChanged<DateTime> onTimeJump;

  /// Optional initial action to pre-select.
  final TaskActionType? initialAction;

  /// Optional initial crop to pre-select.
  final VegetableEntry? initialCrop;

  /// Optional initial organ quality when [initialCrop] is null.
  final PlantQuality? initialQuality;

  /// Creates an immutable [TaskPlannerCard].
  const TaskPlannerCard({
    super.key,
    required this.selectedDate,
    required this.ephemeris,
    required this.onTimeJump,
    this.weatherNotifier,
    this.latitude = DefaultLocations.copenhagenLatitude,
    this.longitude = DefaultLocations.copenhagenLongitude,
    this.seasons,
    this.gardenController,
    this.initialAction,
    this.initialCrop,
    this.initialQuality,
  });

  @override
  State<TaskPlannerCard> createState() => _TaskPlannerCardState();
}

final class _TaskPlannerCardState extends State<TaskPlannerCard> {
  late TaskActionType _selectedAction;
  VegetableEntry? _selectedCrop;
  late PlantQuality _selectedQuality;
  PlantCategory? _selectedCategory;
  String? _selectedPlotName;
  bool _onlyStarredCrops = false;
  bool _onlyOptimal = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Cached window search result to avoid redundant ephemeris scans across rebuilds.
  TaskWindowSearchResult? _cachedResult;
  String? _cachedKey;

  @override
  void initState() {
    super.initState();
    _selectedAction = widget.initialAction ?? TaskActionType.takeCuttings;
    _selectedCrop =
        widget.initialCrop ?? VegetableDatabase.findById('grapevine');
    _selectedQuality =
        _selectedCrop?.quality ?? widget.initialQuality ?? PlantQuality.fruit;
  }

  @override
  void didUpdateWidget(covariant TaskPlannerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialAction != null &&
        widget.initialAction != oldWidget.initialAction) {
      _selectedAction = widget.initialAction!;
    }
    if (widget.initialCrop != null &&
        widget.initialCrop != oldWidget.initialCrop) {
      _selectedCrop = widget.initialCrop;
      _selectedQuality = widget.initialCrop!.quality;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyPreset(QuickTaskPreset preset) {
    setState(() {
      _selectedAction = preset.action;
      _selectedCrop = preset.cropId != null
          ? VegetableDatabase.findById(preset.cropId!)
          : null;
      _selectedQuality = _selectedCrop?.quality ?? preset.quality;
    });
  }

  TaskWindowSearchResult _resolveSearchResult(
    List<WeatherDataPoint>? forecast,
  ) {
    final hourBucket = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      widget.selectedDate.hour,
    );
    final key =
        '${hourBucket.millisecondsSinceEpoch}|${_selectedAction.name}|'
        '${_selectedQuality.name}|${_selectedCrop?.id ?? "none"}|'
        '${widget.latitude.toStringAsFixed(2)}|${widget.longitude.toStringAsFixed(2)}|'
        '${widget.seasons.runtimeType}:${widget.seasons?.shortLabel ?? ""}|'
        '${forecast?.length ?? 0}';

    if (_cachedKey == key && _cachedResult != null) {
      return _cachedResult!;
    }

    final result = TaskWindowPlanner.findUpcomingWindows(
      action: _selectedAction,
      targetQuality: _selectedQuality,
      crop: _selectedCrop,
      startTime: widget.selectedDate,
      ephemeris: widget.ephemeris,
      weatherForecast: forecast,
      latitude: widget.latitude,
      longitude: widget.longitude,
      seasons: widget.seasons,
      searchDays: 30,
      maxWindows: 8,
    );

    _cachedKey = key;
    _cachedResult = result;
    return result;
  }

  String _formatMonthList(List<int> months) {
    const names = [
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
    return months.map((m) => names[m]).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[
      if (widget.weatherNotifier != null) widget.weatherNotifier!,
      if (widget.gardenController != null) widget.gardenController!,
    ];
    if (listenables.isEmpty) {
      return _buildContent(context, null);
    }
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) =>
          _buildContent(context, widget.weatherNotifier?.value),
    );
  }

  Widget _buildActiveTaskQueueSection(
    GardenProfile profile,
    List<WeatherDataPoint>? forecast,
  ) {
    if (!profile.hasQueuedTasks) return const SizedBox.shrink();
    final dateFmt = DateFormat('EEE, MMM d • HH:mm');

    return Column(
      key: const ValueKey('active_task_queue_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MY ACTIVE TASK QUEUE (${profile.taskQueue.length})',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: GoetheanPalette.aspectGold,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: profile.taskQueue
              .map((task) {
                final taskColor = GoetheanPalette.getColor(task.targetQuality);
                final isSelected = task.matchesSelection(
                  selectedAction: _selectedAction,
                  selectedCropId: _selectedCrop?.id,
                  selectedQuality: _selectedQuality,
                );
                final taskSearch = TaskWindowPlanner.findUpcomingWindows(
                  action: task.action,
                  targetQuality: task.targetQuality,
                  crop: task.crop,
                  startTime: widget.selectedDate,
                  ephemeris: widget.ephemeris,
                  weatherForecast: forecast,
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                  seasons: widget.seasons,
                  searchDays: 14,
                  maxWindows: 1,
                );
                final nextWindow = taskSearch.windows.firstOrNull;

                return Container(
                  key: ValueKey('queued_task_${task.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? taskColor.withValues(alpha: 0.20)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? taskColor
                          : taskColor.withValues(alpha: 0.35),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _selectedAction = task.action;
                        _selectedCrop = task.crop;
                        _selectedQuality = task.targetQuality;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(task.action.icon, size: 18, color: taskColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.summaryLabel,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  nextWindow != null
                                      ? 'Next window: ${dateFmt.format(nextWindow.peakTime)} (${nextWindow.suitability == TaskSuitability.optimal ? "Optimal" : "Favorable"})'
                                      : 'No window in next 14 days — tap to inspect 30-day horizon',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: nextWindow != null
                                        ? const Color(0xFFF3E5C8)
                                        : Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (nextWindow != null)
                            IconButton(
                              key: ValueKey('jump_queued_task_${task.id}'),
                              tooltip: 'Jump to next window',
                              icon: const Icon(
                                Icons.ads_click_outlined,
                                size: 18,
                                color: GoetheanPalette.aspectGold,
                              ),
                              onPressed: () =>
                                  widget.onTimeJump(nextWindow.peakTime),
                            ),
                          IconButton(
                            key: ValueKey('remove_queued_task_${task.id}'),
                            tooltip: 'Mark done / remove from queue',
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Color(0xFF10B981),
                            ),
                            onPressed: () {
                              widget.gardenController?.removeQueuedTask(
                                task.id,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildContent(BuildContext context, List<WeatherDataPoint>? forecast) {
    final result = _resolveSearchResult(forecast);
    final accentColor = GoetheanPalette.getColor(result.targetQuality);
    final gardenProfile = widget.gardenController?.value;
    final starredIds = gardenProfile?.starredCropIds ?? const <String>{};
    final filteredWindows = _onlyOptimal
        ? result.windows
              .where((w) => w.suitability == TaskSuitability.optimal)
              .toList(growable: false)
        : result.windows;

    final baseSearchedCrops = VegetableDatabase.search(
      _searchQuery,
      quality: (_onlyStarredCrops || _searchQuery.trim().isNotEmpty)
          ? null
          : _selectedQuality,
      category: _selectedCategory,
    );
    final searchedCrops = _onlyStarredCrops
        ? baseSearchedCrops
              .where((c) => starredIds.contains(c.id))
              .toList(growable: false)
        : <VegetableEntry>[
            ...baseSearchedCrops.where((c) => starredIds.contains(c.id)),
            ...baseSearchedCrops.where((c) => !starredIds.contains(c.id)),
          ];
    final matchingCrops = <VegetableEntry>[
      if (_selectedCrop != null &&
          !searchedCrops.any((c) => c.id == _selectedCrop!.id))
        _selectedCrop!,
      ...searchedCrops,
    ];

    return OrganicVesselContainer(
      accentColor: accentColor,
      seed: 4.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.event_available_outlined,
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
                      'When Is a Good Time To...?',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF6ECD8),
                      ),
                    ),
                    Text(
                      'Plan garden, orchard & herb tasks using Maria Thun\'s cosmic hierarchy',
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
          const SizedBox(height: 16),
          if (gardenProfile != null)
            _buildActiveTaskQueueSection(gardenProfile, forecast),

          // Quick Presets Row
          Text(
            'QUICK EXAMPLES',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: GoetheanPalette.aspectGold,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: TaskWindowPlanner.presets
                  .map((preset) {
                    final isSelected =
                        _selectedAction == preset.action &&
                        _selectedCrop?.id == preset.cropId;
                    final presetColor = GoetheanPalette.getColor(
                      preset.quality,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        key: ValueKey(
                          'preset_${preset.action.name}_${preset.cropId}',
                        ),
                        onTap: () => _applyPreset(preset),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? presetColor.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? presetColor
                                  : Colors.white.withValues(alpha: 0.14),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                preset.action.icon,
                                size: 16,
                                color: presetColor,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    preset.label,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    preset.subtitle,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 18),

          // Step 1: Select Action
          Text(
            '1. SELECT ACTION',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TaskActionType.values
                .map((action) {
                  final isSelected = _selectedAction == action;
                  return ChoiceChip(
                    key: ValueKey('task_action_${action.name}'),
                    avatar: Icon(
                      action.icon,
                      size: 16,
                      color: isSelected ? Colors.white : accentColor,
                    ),
                    label: Text(
                      action.displayName,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: accentColor.withValues(alpha: 0.35),
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    side: BorderSide(
                      color: isSelected
                          ? accentColor
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        _selectedAction = action;
                      });
                    },
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 18),

          // Step 2: Select Plant or Organ Category
          Text(
            '2. SELECT PLANT OR PLANT ORGAN',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),

          // Organ Category Filter / General Organ Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final quality in const [
                  PlantQuality.root,
                  PlantQuality.leaf,
                  PlantQuality.flower,
                  PlantQuality.fruit,
                ]) ...[
                  _buildOrganCategoryButton(quality),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Plant Category Filter Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (widget.gardenController != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: const ValueKey('planner_filter_my_garden'),
                      avatar: Icon(
                        _onlyStarredCrops
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 15,
                        color: GoetheanPalette.aspectGold,
                      ),
                      label: Text(
                        'My Garden (${starredIds.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: _onlyStarredCrops
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _onlyStarredCrops
                              ? const Color(0xFFF6ECD8)
                              : Colors.white70,
                        ),
                      ),
                      selected: _onlyStarredCrops,
                      selectedColor: GoetheanPalette.aspectGold.withValues(
                        alpha: 0.28,
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      side: BorderSide(
                        color: _onlyStarredCrops
                            ? GoetheanPalette.aspectGold
                            : Colors.white.withValues(alpha: 0.14),
                      ),
                      showCheckmark: false,
                      onSelected: (selected) {
                        setState(() {
                          _onlyStarredCrops = selected;
                        });
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: const ValueKey('planner_category_all'),
                    label: Text(
                      'All Categories',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: _selectedCategory == null
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: _selectedCategory == null
                            ? Colors.white
                            : Colors.white70,
                      ),
                    ),
                    selected: _selectedCategory == null,
                    selectedColor: accentColor.withValues(alpha: 0.3),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    side: BorderSide(
                      color: _selectedCategory == null
                          ? accentColor
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        _selectedCategory = null;
                      });
                    },
                  ),
                ),
                for (final category in PlantCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('planner_category_${category.name}'),
                      label: Text(
                        category.pluralNameEn,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: _selectedCategory == category
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _selectedCategory == category
                              ? Colors.white
                              : Colors.white70,
                        ),
                      ),
                      selected: _selectedCategory == category,
                      selectedColor: accentColor.withValues(alpha: 0.3),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      side: BorderSide(
                        color: _selectedCategory == category
                            ? accentColor
                            : Colors.white.withValues(alpha: 0.14),
                      ),
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search Box for Specific Plants
          TextField(
            key: const ValueKey('task_planner_plant_search'),
            controller: _searchController,
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search 185+ plants, Danish/English names, scientific names, or aliases...',
              hintStyle: GoogleFonts.outfit(
                fontSize: 12.5,
                color: Colors.white38,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: Colors.white54,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        size: 16,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.22),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
          const SizedBox(height: 10),

          // Specific Plant Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: ValueKey('general_organ_${_selectedQuality.name}'),
                label: Text(
                  'Any ${_selectedQuality.displayName} Plant',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: _selectedCrop == null
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: _selectedCrop == null
                        ? Colors.white
                        : Colors.white70,
                  ),
                ),
                selected: _selectedCrop == null,
                selectedColor: accentColor.withValues(alpha: 0.35),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                side: BorderSide(
                  color: _selectedCrop == null
                      ? accentColor
                      : Colors.white.withValues(alpha: 0.15),
                ),
                showCheckmark: false,
                onSelected: (_) {
                  setState(() {
                    _selectedCrop = null;
                  });
                },
              ),
              ...matchingCrops.map((crop) {
                final isSelected = _selectedCrop?.id == crop.id;
                final cropColor = GoetheanPalette.getColor(crop.quality);
                return ChoiceChip(
                  key: ValueKey('planner_crop_${crop.id}'),
                  label: Text(
                    crop.localizedDisplayName,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: cropColor.withValues(alpha: 0.35),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  side: BorderSide(
                    color: isSelected
                        ? cropColor
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() {
                      _selectedCrop = crop;
                      if (_searchQuery.trim().isNotEmpty ||
                          !crop.supportsQuality(_selectedQuality)) {
                        _selectedQuality = crop.quality;
                      }
                    });
                  },
                );
              }),
            ],
          ),

          // Multi-Organ Target Selector for Multi-Purpose Crops
          if (_selectedCrop != null && _selectedCrop!.hasMultipleOrgans) ...[
            const SizedBox(height: 12),
            Text(
              'TARGET ORGAN FOR ${_selectedCrop!.nameEn.toUpperCase()} (MULTI-ORGAN CROP)',
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: GoetheanPalette.aspectGold,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedCrop!.allQualities
                  .map((quality) {
                    final isSelected = _selectedQuality == quality;
                    final organColor = GoetheanPalette.getColor(quality);
                    final secondaryRule = quality == _selectedCrop!.quality
                        ? null
                        : _selectedCrop!.findOrganRule(quality);
                    final chipLabel = secondaryRule != null
                        ? '${quality.displayName}: ${secondaryRule.localizedLabel}'
                        : '${quality.displayName} (Primary)';
                    return ChoiceChip(
                      key: ValueKey('crop_organ_override_${quality.name}'),
                      label: Text(
                        chipLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: organColor.withValues(alpha: 0.35),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      side: BorderSide(
                        color: isSelected
                            ? organColor
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() {
                          _selectedQuality = quality;
                        });
                      },
                    );
                  })
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 18),

          // Maria Thun Rule & Seasonal Context Banner
          OrganicVesselContainer.inset(
            accentColor: accentColor,
            seed: 2.3,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: accentColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Maria Thun Timing Rule',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  result.ruleExplanation,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
                if (result.activeOrganRule != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'Active Multi-Organ Schedule: ${result.activeOrganRule!.localizedLabel}'
                      '${result.activeOrganRule!.noteDa.isNotEmpty ? " — ${result.activeOrganRule!.noteDa}" : ""}',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: const Color(0xFFF6ECD8),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
                if (_selectedCrop != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildMetaPill(
                        label: _selectedCrop!.category.bilingualName,
                        color: accentColor,
                      ),
                      _buildMetaPill(
                        label: _selectedCrop!.lifeCycle.bilingualName,
                        color: GoetheanPalette.aspectGold,
                      ),
                      _buildMetaPill(
                        label: _selectedCrop!.scientificName,
                        color: Colors.white70,
                        italic: true,
                      ),
                    ],
                  ),
                  if (_selectedCrop!.aliasesDa.isNotEmpty ||
                      _selectedCrop!.aliasesEn.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Aliases / Synonymer: ${[..._selectedCrop!.aliasesDa, ..._selectedCrop!.aliasesEn].join(' • ')}',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _selectedCrop!.descriptionEn,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 14.5,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFFE5DAC6),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedCrop!.descriptionDa,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.35,
                    ),
                  ),
                  if (_selectedCrop!.thunNotesEn.isNotEmpty ||
                      _selectedCrop!.thunNotesDa.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: GoetheanPalette.aspectGold.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: GoetheanPalette.aspectGold.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.menu_book_outlined,
                                size: 14,
                                color: GoetheanPalette.aspectGold,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Maria Thun Note (Aussaattage)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: GoetheanPalette.aspectGold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_selectedCrop!.thunNotesEn.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _selectedCrop!.thunNotesEn,
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: const Color(0xFFF6ECD8),
                                height: 1.3,
                              ),
                            ),
                          ],
                          if (_selectedCrop!.thunNotesDa.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              _selectedCrop!.thunNotesDa,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.white70,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (_selectedCrop!.indoorSowingMonths.isNotEmpty)
                        _buildMetaPill(
                          label:
                              'Indoor Sow: ${_formatMonthList(_selectedCrop!.indoorSowingMonths)}',
                          color: const Color(0xFF38BDF8),
                        ),
                      if (_selectedCrop!.sowingMonths.isNotEmpty)
                        _buildMetaPill(
                          label:
                              'Direct Sow: ${_formatMonthList(_selectedCrop!.sowingMonths)}',
                          color: const Color(0xFF646CFF),
                        ),
                      if (_selectedCrop!.transplantMonths.isNotEmpty)
                        _buildMetaPill(
                          label:
                              'Transplant: ${_formatMonthList(_selectedCrop!.transplantMonths)}',
                          color: const Color(0xFF8B5CF6),
                        ),
                      if (_selectedCrop!.cuttingMonths.isNotEmpty)
                        _buildMetaPill(
                          label:
                              'Cuttings: ${_formatMonthList(_selectedCrop!.cuttingMonths)}',
                          color: const Color(0xFFEC4899),
                        ),
                      if (_selectedCrop!.divisionMonths.isNotEmpty)
                        _buildMetaPill(
                          label:
                              'Division: ${_formatMonthList(_selectedCrop!.divisionMonths)}',
                          color: const Color(0xFF14B8A6),
                        ),
                      if (_selectedCrop!.graftingMonths.isNotEmpty)
                        _buildMetaPill(
                          label:
                              'Grafting: ${_formatMonthList(_selectedCrop!.graftingMonths)}',
                          color: const Color(0xFFF97316),
                        ),
                      if (_selectedCrop!.pruningMonths.isNotEmpty)
                        _buildMetaPill(
                          label:
                              'Pruning: ${_formatMonthList(_selectedCrop!.pruningMonths)}',
                          color: const Color(0xFFA855F7),
                        ),
                      if (_selectedCrop!.harvestMonths.isNotEmpty)
                        _buildMetaPill(
                          label:
                              'Harvest: ${_formatMonthList(_selectedCrop!.harvestMonths)}',
                          color: const Color(0xFF10B981),
                        ),
                    ],
                  ),
                  if (_selectedCrop!.companionPlants.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Companions (Gode naboer): ${_selectedCrop!.companionPlants.join(', ')}',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: const Color(0xFFA7F3D0),
                      ),
                    ),
                  ],
                  if (_selectedCrop!.antagonistPlants.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Antagonists (Undgå): ${_selectedCrop!.antagonistPlants.join(', ')}',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: const Color(0xFFFCA5A5),
                      ),
                    ),
                  ],
                ],
                if (result.seasonalMonths.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            result.isCurrentlyInSeason
                                ? Icons.check_circle_outline
                                : Icons.schedule_outlined,
                            size: 16,
                            color: result.isCurrentlyInSeason
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              result.isCurrentlyInSeason
                                  ? 'In Season Now (${_formatMonthList(result.seasonalMonths)})'
                                  : 'Traditional Season: ${_formatMonthList(result.seasonalMonths)} (currently out of season)',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: result.isCurrentlyInSeason
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!result.isCurrentlyInSeason &&
                          result.nextSeasonalStartDate != null)
                        TextButton.icon(
                          key: const ValueKey('jump_to_prime_season_button'),
                          onPressed: () =>
                              widget.onTimeJump(result.nextSeasonalStartDate!),
                          icon: const Icon(
                            Icons.fast_forward,
                            size: 15,
                            color: Color(0xFFF59E0B),
                          ),
                          label: Text(
                            'Jump to ${DateFormat('MMM yyyy').format(result.nextSeasonalStartDate!)}',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.15),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (result.localSeasonSummary != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.thermostat_outlined,
                        size: 15,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          result.localSeasonSummary!,
                          key: const ValueKey('task_planner_local_season'),
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: Colors.white70,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (result.cropClimate != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    key: const ValueKey('task_planner_crop_climate'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _climateRatingColor(result.cropClimate!.rating)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _climateRatingColor(result.cropClimate!.rating)
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          result.cropClimate!.needsAttention
                              ? Icons.warning_amber_rounded
                              : Icons.verified_outlined,
                          size: 15,
                          color: _climateRatingColor(
                            result.cropClimate!.rating,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${result.cropClimate!.badgeLabel}: ${result.cropClimate!.summary}',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.gardenController != null) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final knownPlots = widget.gardenController!.listPlots();
                final isQueued =
                    gardenProfile?.isTaskQueued(
                      action: _selectedAction,
                      cropId: _selectedCrop?.id,
                      targetQuality: _selectedQuality,
                      bedName: _selectedPlotName,
                    ) ??
                    false;
                final targetLabel =
                    _selectedCrop?.localizedDisplayName ??
                    'Any ${_selectedQuality.displayName} Plant';
                final plotSuffix = _selectedPlotName != null
                    ? ' (${_selectedPlotName!})'
                    : '';
                final plotRotation =
                    (_selectedPlotName != null && _selectedCrop != null)
                    ? widget.gardenController!.evaluatePlotRotation(
                        _selectedPlotName!,
                        candidateCrop: _selectedCrop,
                        referenceTime: widget.selectedDate,
                      )
                    : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (knownPlots.isNotEmpty) ...[
                      Text(
                        'TARGET PLOT / BED (OPTIONAL SUCCESSION ASSIGNMENT)',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            key: const ValueKey('planner_plot_any'),
                            label: Text(
                              'Any Plot',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: _selectedPlotName == null
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: _selectedPlotName == null
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                            ),
                            selected: _selectedPlotName == null,
                            selectedColor: accentColor.withValues(alpha: 0.3),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.05,
                            ),
                            showCheckmark: false,
                            onSelected: (_) {
                              setState(() {
                                _selectedPlotName = null;
                              });
                            },
                          ),
                          for (final plot in knownPlots)
                            ChoiceChip(
                              key: ValueKey('planner_plot_${plot.name}'),
                              label: Text(
                                plot.badgeLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: _selectedPlotName == plot.name
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: _selectedPlotName == plot.name
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                              selected: _selectedPlotName == plot.name,
                              selectedColor: GoetheanPalette.leafWater
                                  .withValues(alpha: 0.32),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                              showCheckmark: false,
                              onSelected: (_) {
                                setState(() {
                                  _selectedPlotName =
                                      _selectedPlotName == plot.name
                                      ? null
                                      : plot.name;
                                });
                              },
                            ),
                        ],
                      ),
                      if (plotRotation != null &&
                          plotRotation.conflictWarning != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          key: const ValueKey('planner_plot_rotation_warning'),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            plotRotation.conflictWarning!,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: const Color(0xFFFCD34D),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('toggle_queue_task_button'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isQueued
                              ? const Color(0xFF10B981).withValues(alpha: 0.16)
                              : GoetheanPalette.aspectGold.withValues(
                                  alpha: 0.12,
                                ),
                          foregroundColor: isQueued
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFFF6ECD8),
                          side: BorderSide(
                            color: isQueued
                                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                : GoetheanPalette.aspectGold.withValues(
                                    alpha: 0.45,
                                  ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          isQueued
                              ? Icons.playlist_add_check_rounded
                              : Icons.playlist_add_rounded,
                          size: 18,
                        ),
                        onPressed: () {
                          widget.gardenController!.toggleQueuedTask(
                            action: _selectedAction,
                            cropId: _selectedCrop?.id,
                            targetQuality: _selectedQuality,
                            bedName: _selectedPlotName,
                          );
                        },
                        label: Text(
                          isQueued
                              ? 'In My Task Queue: ${_selectedAction.displayName} · $targetLabel$plotSuffix (Tap to Remove)'
                              : 'Add to My Task Queue: ${_selectedAction.displayName} · $targetLabel$plotSuffix',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 18),

          // Upcoming Windows Header + Optimal Filter Toggle + .ics Export
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'UPCOMING WINDOWS (NEXT 30 DAYS FROM ${DateFormat('MMM d').format(widget.selectedDate).toUpperCase()})',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.white70,
                ),
              ),
              if (filteredWindows.isNotEmpty)
                OutlinedButton.icon(
                  key: const ValueKey('task_planner_export_all_ics'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GoetheanPalette.aspectGold,
                    side: BorderSide(
                      color: GoetheanPalette.aspectGold.withValues(alpha: 0.55),
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
                    final events = filteredWindows
                        .map(
                          (window) => IcsCalendarExporter.fromTaskWindow(
                            window: window,
                            action: result.action,
                            crop: result.crop,
                            organRule: result.activeOrganRule,
                            latitude: widget.latitude,
                            longitude: widget.longitude,
                          ),
                        )
                        .toList(growable: false);
                    IcsExportSheet.show(
                      context,
                      events: events,
                      title:
                          'Export ${result.action.displayName} Windows (.ics)',
                      subtitle:
                          '${events.length} upcoming windows for ${result.crop?.localizedDisplayName ?? "${result.targetQuality.displayName} plants"}',
                    );
                  },
                  icon: const Icon(
                    Icons.calendar_month_outlined,
                    size: 14,
                    color: GoetheanPalette.aspectGold,
                  ),
                  label: Text(
                    'Export All (.ics)',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              FilterChip(
                label: Text(
                  'Optimal Only',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: _onlyOptimal ? Colors.white : Colors.white70,
                  ),
                ),
                selected: _onlyOptimal,
                selectedColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                onSelected: (val) {
                  setState(() {
                    _onlyOptimal = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (filteredWindows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No matching windows found in this 30-day range. Try disabling "Optimal Only" or jumping to another month.',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.white60),
              ),
            )
          else
            Column(
              children: [
                for (int index = 0; index < filteredWindows.length; index++)
                  _buildWindowTile(
                    context,
                    filteredWindows[index],
                    accentColor,
                    result: result,
                    index: index,
                    showSeasonBadge: result.seasonalMonths.isNotEmpty,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Color _climateRatingColor(CropClimateRating rating) => switch (rating) {
    CropClimateRating.wellSuited => const Color(0xFF10B981),
    CropClimateRating.needsWarmthProtection ||
    CropClimateRating.boltRiskInSummer ||
    CropClimateRating.needsWinterProtection => const Color(0xFFF59E0B),
    CropClimateRating.seasonTooShortOutdoors ||
    CropClimateRating.overwinterIndoors => const Color(0xFFF87171),
  };

  Widget _buildMetaPill({
    required String label,
    required Color color,
    bool italic = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildOrganCategoryButton(PlantQuality quality) {
    final isSelected = _selectedQuality == quality;
    final color = GoetheanPalette.getColor(quality);
    return InkWell(
      key: ValueKey('organ_category_${quality.name}'),
      onTap: () {
        setState(() {
          _selectedQuality = quality;
          if (_selectedCrop != null &&
              !_selectedCrop!.supportsQuality(quality)) {
            _selectedCrop = null;
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.14),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              quality.displayName,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowTile(
    BuildContext context,
    TaskWindow window,
    Color accentColor, {
    required TaskWindowSearchResult result,
    required int index,
    bool showSeasonBadge = false,
  }) {
    final isOptimal = window.suitability == TaskSuitability.optimal;
    final badgeColor = isOptimal
        ? const Color(0xFF10B981)
        : const Color(0xFF38BDF8);
    final seasonBadgeColor = window.isInSeason
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);
    final dateFmt = DateFormat('EEE, MMM d • HH:mm');
    final peakFmt = DateFormat('EEE, MMM d \'at\' HH:mm');
    final hours = window.duration.inHours;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onTimeJump(window.peakTime),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isOptimal
                    ? accentColor.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.14),
                width: isOptimal ? 1.4 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        isOptimal ? 'OPTIMAL' : 'FAVORABLE',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: badgeColor,
                        ),
                      ),
                    ),
                    if (showSeasonBadge) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: seasonBadgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: seasonBadgeColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          window.isInSeason ? 'IN SEASON' : 'OFF-SEASON',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: seasonBadgeColor,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        window.headline,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.ads_click_outlined,
                      size: 15,
                      color: GoetheanPalette.aspectGold.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Jump Timeline',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: GoetheanPalette.aspectGold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${dateFmt.format(window.start)} → ${dateFmt.format(window.end)} (${hours}h)',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF6ECD8),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.gardenController != null) ...[
                          OutlinedButton.icon(
                            key: ValueKey('task_window_log_action_$index'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF6ECD8),
                              backgroundColor: accentColor.withValues(
                                alpha: 0.16,
                              ),
                              side: BorderSide(
                                color: accentColor.withValues(alpha: 0.55),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(64, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              final peakInfo = algo.getCalendarInfo(
                                window.peakTime,
                                widget.ephemeris,
                                includePlanets: true,
                                latitude: widget.latitude,
                                longitude: widget.longitude,
                              );
                              FieldJournalSheet.show(
                                context,
                                gardenController: widget.gardenController!,
                                timestamp: window.peakTime,
                                calendarInfo: peakInfo,
                                horizon: window.weatherHorizon,
                                weatherSeries: widget.weatherNotifier?.value,
                                initialAction:
                                    FieldJournalAction.fromTaskAction(
                                      result.action,
                                    ),
                                initialCrop: result.crop,
                                initialQuality: result.targetQuality,
                                initialTitle: window.headline,
                              );
                            },
                            icon: Icon(
                              Icons.menu_book_outlined,
                              size: 13,
                              color: accentColor,
                            ),
                            label: Text(
                              'Log Action',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        OutlinedButton.icon(
                          key: ValueKey('task_window_export_ics_$index'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GoetheanPalette.aspectGold,
                            side: BorderSide(
                              color: GoetheanPalette.aspectGold.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: const Size(56, 28),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            final event = IcsCalendarExporter.fromTaskWindow(
                              window: window,
                              action: result.action,
                              crop: result.crop,
                              organRule: result.activeOrganRule,
                              latitude: widget.latitude,
                              longitude: widget.longitude,
                            );
                            IcsExportSheet.show(
                              context,
                              events: <CalendarExportEvent>[event],
                              title: 'Export Task Window (.ics)',
                              subtitle: event.summary,
                            );
                          },
                          icon: const Icon(
                            Icons.event_available_outlined,
                            size: 13,
                            color: GoetheanPalette.aspectGold,
                          ),
                          label: Text(
                            '.ics',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Recommended peak time: ${peakFmt.format(window.peakTime)}',
                  style: GoogleFonts.outfit(fontSize: 11.5, color: accentColor),
                ),
                const SizedBox(height: 6),
                Text(
                  window.cosmicExplanation,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
                if (window.weatherNote != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        window.hasWeatherConflict
                            ? Icons.warning_amber_rounded
                            : Icons.wb_sunny_outlined,
                        size: 14,
                        color: window.hasWeatherConflict
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          window.weatherNote!,
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: window.hasWeatherConflict
                                ? const Color(0xFFF59E0B)
                                : Colors.white60,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (window.climateNote != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        window.hasClimateRisk
                            ? Icons.ac_unit_outlined
                            : Icons.thermostat_outlined,
                        size: 14,
                        color: window.hasClimateRisk
                            ? const Color(0xFFF87171)
                            : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          window.climateNote!,
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: window.hasClimateRisk
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFFDE68A),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
