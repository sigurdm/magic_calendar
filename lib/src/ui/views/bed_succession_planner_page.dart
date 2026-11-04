import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/models.dart';
import '../../services/ephemeris_service.dart';
import '../../services/garden_service.dart';
import '../components/bed_succession_planner_card.dart';
import '../theme/goethean_palette.dart';

/// Dedicated full-screen view for interactive drag-and-drop bed succession
/// planning, designed for optimal screen usage on mobile and desktop viewports.
///
/// Separates the bed timeline workspace from the main calendar scroll view so
/// the pinned horizontal crop palette, scrollable bed tracks, and docked
/// bottom inspector fit simultaneously on a phone screen.
final class BedSuccessionPlannerPage extends StatelessWidget {
  static final TextStyle _dialogTitleStyle = GoogleFonts.cormorantGaramond(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: const Color(0xFFF6ECD8),
  );
  static final TextStyle _inputTextStyle = GoogleFonts.outfit(
    fontSize: 13,
    color: Colors.white,
  );
  static final TextStyle _inputLabelStyle = GoogleFonts.outfit(
    color: Colors.white70,
  );
  static final TextStyle _sectionLabelStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: GoetheanPalette.aspectGold,
  );
  static final TextStyle _chipSelectedStyle = GoogleFonts.outfit(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  static final TextStyle _chipUnselectedStyle = GoogleFonts.outfit(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: Colors.white70,
  );
  static final TextStyle _topTitleStyle = GoogleFonts.cormorantGaramond(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: const Color(0xFFF6ECD8),
    height: 1.1,
  );
  static final TextStyle _topSubtitleStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    color: Colors.white60,
  );
  static final TextStyle _addBedButtonLabelStyle = GoogleFonts.outfit(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
  );
  static final ButtonStyle _addBedButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFFF6ECD8),
    side: BorderSide(color: GoetheanPalette.leafWater.withValues(alpha: 0.55)),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    minimumSize: const Size(64, 32),
    visualDensity: VisualDensity.compact,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
  static final BoxDecoration _topBarDecoration = BoxDecoration(
    color: Colors.black.withValues(alpha: 0.28),
    border: Border(
      bottom: BorderSide(
        color: GoetheanPalette.aspectGold.withValues(alpha: 0.22),
      ),
    ),
  );

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

  /// Creates an immutable [BedSuccessionPlannerPage].
  const BedSuccessionPlannerPage({
    super.key,
    required this.gardenController,
    required this.selectedDate,
    this.info,
    this.ephemeris,
    this.weatherNotifier,
    this.onTimeJump,
    this.latitude = DefaultLocations.copenhagenLatitude,
    this.longitude = DefaultLocations.copenhagenLongitude,
  });

  /// Pushes [BedSuccessionPlannerPage] as a full-screen route.
  static Future<void> open(
    BuildContext context, {
    required GardenProfileController gardenController,
    required DateTime selectedDate,
    CalendarInfo? info,
    EphemerisService? ephemeris,
    ValueNotifier<List<WeatherDataPoint>?>? weatherNotifier,
    ValueChanged<DateTime>? onTimeJump,
    double latitude = DefaultLocations.copenhagenLatitude,
    double longitude = DefaultLocations.copenhagenLongitude,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => BedSuccessionPlannerPage(
          gardenController: gardenController,
          selectedDate: selectedDate,
          info: info,
          ephemeris: ephemeris,
          weatherNotifier: weatherNotifier,
          onTimeJump: (targetDate) {
            onTimeJump?.call(targetDate);
            if (routeContext.mounted && Navigator.of(routeContext).canPop()) {
              Navigator.of(routeContext).pop();
            }
          },
          latitude: latitude,
          longitude: longitude,
        ),
      ),
    );
  }

  static Future<void> _showUpsertPlotDialog(
    BuildContext context,
    GardenProfileController controller, [
    GardenPlot? existing,
  ]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final areaCtrl = TextEditingController(text: existing?.areaName ?? '');
    final dimCtrl = TextEditingController(text: existing?.dimensions ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    GardenPlotType selectedType = existing?.plotType ?? GardenPlotType.openBed;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1F1A14),
            title: Text(
              existing == null
                  ? 'Add Garden Plot / Bed'
                  : 'Edit Plot • ${existing.name}',
              style: _dialogTitleStyle,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const ValueKey('bed_planner_plot_name_input'),
                    controller: nameCtrl,
                    enabled: existing == null,
                    style: _inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Plot / Bed Name (e.g. Bed 1, North Tunnel)',
                      labelStyle: _inputLabelStyle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('bed_planner_plot_area_input'),
                    controller: areaCtrl,
                    style: _inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Garden Section / Zone (e.g. Kitchen Garden, Greenhouse)',
                      labelStyle: _inputLabelStyle,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('PLOT ENVIRONMENT', style: _sectionLabelStyle),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: GardenPlotType.values
                        .map((type) {
                          final isSelected = selectedType == type;
                          return ChoiceChip(
                            key: ValueKey('bed_planner_plot_type_${type.name}'),
                            label: Text(
                              '${type.glyph} ${type.displayName}',
                              style: isSelected
                                  ? _chipSelectedStyle
                                  : _chipUnselectedStyle,
                            ),
                            selected: isSelected,
                            selectedColor: GoetheanPalette.aspectGold
                                .withValues(alpha: 0.3),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.05,
                            ),
                            showCheckmark: false,
                            onSelected: (_) {
                              setDialogState(() {
                                selectedType = type;
                              });
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('bed_planner_plot_dimensions_input'),
                    controller: dimCtrl,
                    style: _inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Dimensions / Area (e.g. 1.2m × 4.0m)',
                      labelStyle: _inputLabelStyle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('bed_planner_plot_notes_input'),
                    controller: notesCtrl,
                    maxLines: 2,
                    style: _inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Soil Type, Sun Exposure, or Notes',
                      labelStyle: _inputLabelStyle,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (existing != null)
                TextButton(
                  key: const ValueKey('bed_planner_plot_delete_button'),
                  onPressed: () {
                    controller.deletePlot(existing.name);
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text(
                    'Delete Plot',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                key: const ValueKey('bed_planner_plot_save_button'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save Plot'),
              ),
            ],
          ),
        ),
      );

      final trimmedName = nameCtrl.text.trim();
      if (confirmed == true && trimmedName.isNotEmpty) {
        final matchedExisting = existing ?? controller.findPlot(trimmedName);
        controller.upsertPlot(
          GardenPlot(
            name: matchedExisting?.name ?? trimmedName,
            areaName: areaCtrl.text.trim(),
            plotType: selectedType,
            dimensions: dimCtrl.text.trim(),
            notes: notesCtrl.text.trim(),
            lastSoilPrepSummary: matchedExisting?.lastSoilPrepSummary,
            lastSoilPrepTimestamp: matchedExisting?.lastSoilPrepTimestamp,
          ),
        );
      }
    } finally {
      nameCtrl.dispose();
      areaCtrl.dispose();
      dimCtrl.dispose();
      notesCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('bed_succession_planner_page'),
      backgroundColor: GoetheanPalette.compostDark,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              GoetheanPalette.topsoilWarm,
              Color(0xFF211A13),
              GoetheanPalette.compostDark,
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Slim Top Navigation Bar
              RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: _topBarDecoration,
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('bed_planner_back_button'),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Back to Calendar',
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFFF6ECD8),
                          size: 20,
                        ),
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.view_timeline_outlined,
                        size: 18,
                        color: GoetheanPalette.aspectGold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Bed Succession Planner',
                              style: _topTitleStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                            ListenableBuilder(
                              listenable: gardenController,
                              builder: (context, _) {
                                final plotCount = gardenController
                                    .listPlots()
                                    .length;
                                int plannedCount = 0;
                                for (final t
                                    in gardenController.value.taskQueue) {
                                  if (t.bedName != null &&
                                      t.plannedStartDate != null) {
                                    plannedCount++;
                                  }
                                }
                                return Text(
                                  '${gardenController.gardenName} • $plotCount bed${plotCount == 1 ? "" : "s"} • $plannedCount planned',
                                  style: _topSubtitleStyle,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('bed_planner_add_plot_button'),
                        style: _addBedButtonStyle,
                        onPressed: () =>
                            _showUpsertPlotDialog(context, gardenController),
                        icon: const Icon(
                          Icons.add,
                          size: 14,
                          color: GoetheanPalette.leafWater,
                        ),
                        label: Text('Add Bed', style: _addBedButtonLabelStyle),
                      ),
                    ],
                  ),
                ),
              ),
              // Full-screen workspace body
              Expanded(
                child: RepaintBoundary(
                  child: BedSuccessionPlannerCard(
                    gardenController: gardenController,
                    selectedDate: selectedDate,
                    info: info,
                    ephemeris: ephemeris,
                    weatherNotifier: weatherNotifier,
                    onTimeJump: onTimeJump,
                    latitude: latitude,
                    longitude: longitude,
                    fullScreen: true,
                    onEditPlot: (plot) =>
                        _showUpsertPlotDialog(context, gardenController, plot),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
