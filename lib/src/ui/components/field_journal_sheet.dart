import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../core/vegetable_database.dart';
import '../../services/garden_service.dart';
import '../theme/goethean_palette.dart';
import 'organic_vessel_container.dart';

/// Modal bottom sheet for logging a new comparative biodynamic field action or
/// recording follow-up outcome observations on an existing [FieldJournalEntry].
final class FieldJournalSheet extends StatefulWidget {
  /// Controller persisting the user's [GardenProfile] and journal entries.
  final GardenProfileController gardenController;

  /// Timestamp of the action being logged.
  final DateTime timestamp;

  /// Active [CalendarInfo] captured at [timestamp].
  final CalendarInfo calendarInfo;

  /// Optional weather observation or forecast point closest to [timestamp].
  final WeatherDataPoint? weather;

  /// Optional multi-horizon soil/weather analysis at [timestamp].
  final MultiHorizonWeatherAnalysis? horizon;

  /// Initial action category to pre-select.
  final FieldJournalAction initialAction;

  /// Optional initial crop to pre-select.
  final VegetableEntry? initialCrop;

  /// Optional initial preparation code (e.g. `'BD 500'`, `'BD 501'`, `'CPP'`).
  final String? initialPrepCode;

  /// Optional initial plant organ quality override.
  final PlantQuality? initialQuality;

  /// Optional initial headline override.
  final String? initialTitle;

  /// Optional initial field notes.
  final String initialNotes;

  /// Existing entry when editing or recording a comparative outcome.
  final FieldJournalEntry? existingEntry;

  /// Creates a [FieldJournalSheet].
  const FieldJournalSheet({
    super.key,
    required this.gardenController,
    required this.timestamp,
    required this.calendarInfo,
    this.weather,
    this.horizon,
    this.initialAction = FieldJournalAction.sowSeeds,
    this.initialCrop,
    this.initialPrepCode,
    this.initialQuality,
    this.initialTitle,
    this.initialNotes = '',
    this.existingEntry,
  });

  /// Resolves the closest [WeatherDataPoint] to [time] from [weatherSeries].
  static WeatherDataPoint? resolveClosestWeather(
    DateTime time,
    List<WeatherDataPoint>? weatherSeries,
  ) {
    if (weatherSeries == null || weatherSeries.isEmpty) return null;
    WeatherDataPoint? closest;
    Duration? minDiff;
    for (final point in weatherSeries) {
      final diff = point.time.difference(time).abs();
      if (minDiff == null || diff < minDiff) {
        minDiff = diff;
        closest = point;
      }
    }
    if (minDiff != null && minDiff <= const Duration(hours: 6)) {
      return closest;
    }
    return null;
  }

  /// Opens the [FieldJournalSheet] modal bottom sheet and returns the saved
  /// [FieldJournalEntry] if the user confirmed.
  static Future<FieldJournalEntry?> show(
    BuildContext context, {
    required GardenProfileController gardenController,
    required DateTime timestamp,
    required CalendarInfo calendarInfo,
    WeatherDataPoint? weather,
    List<WeatherDataPoint>? weatherSeries,
    MultiHorizonWeatherAnalysis? horizon,
    FieldJournalAction initialAction = FieldJournalAction.sowSeeds,
    VegetableEntry? initialCrop,
    String? initialPrepCode,
    PlantQuality? initialQuality,
    String? initialTitle,
    String initialNotes = '',
    FieldJournalEntry? existingEntry,
  }) {
    final resolvedWeather =
        weather ?? resolveClosestWeather(timestamp, weatherSeries);
    final resolvedHorizon =
        horizon ??
        ((resolvedWeather != null || weatherSeries != null)
            ? MultiHorizonWeatherAnalysis.analyze(
                referenceTime: timestamp,
                weatherSeries: weatherSeries,
                currentWeather: resolvedWeather,
              )
            : null);

    return showModalBottomSheet<FieldJournalEntry>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => FieldJournalSheet(
        gardenController: gardenController,
        timestamp: existingEntry?.timestamp ?? timestamp,
        calendarInfo: calendarInfo,
        weather: resolvedWeather,
        horizon: resolvedHorizon,
        initialAction: existingEntry?.action ?? initialAction,
        initialCrop: existingEntry?.crop ?? initialCrop,
        initialPrepCode: existingEntry?.prepCode ?? initialPrepCode,
        initialQuality: existingEntry?.quality ?? initialQuality,
        initialTitle: existingEntry?.title ?? initialTitle,
        initialNotes: existingEntry?.notes ?? initialNotes,
        existingEntry: existingEntry,
      ),
    );
  }

  @override
  State<FieldJournalSheet> createState() => _FieldJournalSheetState();
}

final class _FieldJournalSheetState extends State<FieldJournalSheet> {
  late FieldJournalAction _action;
  VegetableEntry? _crop;
  String? _prepCode;
  late PlantQuality _quality;
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _outcomeController;
  int? _outcomeRating;
  bool _titleManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    _action = widget.initialAction;
    _crop = widget.initialCrop;
    _prepCode = widget.initialPrepCode;
    _quality =
        widget.initialQuality ??
        _crop?.quality ??
        (widget.calendarInfo.quality == PlantQuality.none
            ? PlantQuality.root
            : widget.calendarInfo.quality);
    _outcomeRating = widget.existingEntry?.outcomeRating;

    final defaultTitle =
        widget.initialTitle ??
        _computeAutoTitle(_action, _crop, _prepCode, _quality);
    _titleManuallyEdited =
        widget.existingEntry != null || widget.initialTitle != null;
    _titleController = TextEditingController(text: defaultTitle);
    _notesController = TextEditingController(text: widget.initialNotes);
    _outcomeController = TextEditingController(
      text: widget.existingEntry?.outcomeNote ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _outcomeController.dispose();
    super.dispose();
  }

  String _computeAutoTitle(
    FieldJournalAction action,
    VegetableEntry? crop,
    String? prepCode,
    PlantQuality quality,
  ) {
    if (prepCode != null && prepCode.trim().isNotEmpty) {
      return '${action.shortLabel} ${prepCode.trim()}';
    }
    if (crop != null) {
      return '${action.shortLabel} ${crop.localizedDisplayName}';
    }
    return '${action.displayName} (${quality.displayName})';
  }

  void _syncAutoTitle() {
    if (_titleManuallyEdited) return;
    _titleController.text = _computeAutoTitle(
      _action,
      _crop,
      _prepCode,
      _quality,
    );
  }

  Future<void> _save() async {
    final existing = widget.existingEntry;
    final cosmicSnapshot =
        existing?.cosmicSnapshot ??
        FieldJournalCosmicSnapshot.fromCalendarInfo(widget.calendarInfo);
    final weatherSnapshot =
        existing?.weatherSnapshot ??
        (widget.weather != null
            ? FieldJournalWeatherSnapshot.fromWeather(
                widget.weather!,
                horizon: widget.horizon,
              )
            : null);

    final rawTitle = _titleController.text.trim();
    final resolvedTitle = rawTitle.isNotEmpty
        ? rawTitle
        : _computeAutoTitle(_action, _crop, _prepCode, _quality);

    final entry = FieldJournalEntry(
      id:
          existing?.id ??
          'journal_${widget.timestamp.millisecondsSinceEpoch}_${_action.name}_${_crop?.id ?? _prepCode ?? _quality.name}',
      timestamp: widget.timestamp,
      action: _action,
      title: resolvedTitle,
      cropId: _crop?.id,
      prepCode: _prepCode,
      quality: _quality,
      cosmicSnapshot: cosmicSnapshot,
      weatherSnapshot: weatherSnapshot,
      location:
          existing?.location ?? widget.gardenController.value.activeLocation,
      notes: _notesController.text.trim(),
      outcomeNote: _outcomeController.text.trim(),
      outcomeRating: _outcomeRating,
    );

    await widget.gardenController.addJournalEntry(entry);
    if (!mounted) return;
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = GoetheanPalette.getColor(_quality);
    final cosmic =
        widget.existingEntry?.cosmicSnapshot ??
        FieldJournalCosmicSnapshot.fromCalendarInfo(widget.calendarInfo);
    final weatherSnap =
        widget.existingEntry?.weatherSnapshot ??
        (widget.weather != null
            ? FieldJournalWeatherSnapshot.fromWeather(
                widget.weather!,
                horizon: widget.horizon,
              )
            : null);
    final dateFmt = DateFormat('EEE, MMM d, yyyy • HH:mm');
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1612).withValues(alpha: 0.96),
              border: Border(
                top: BorderSide(
                  color: accentColor.withValues(alpha: 0.65),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                        Icons.menu_book_outlined,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingEntry != null
                                ? 'Update Comparative Journal Entry'
                                : 'Log Biodynamic Field Action',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFF6ECD8),
                            ),
                          ),
                          Text(
                            dateFmt.format(widget.timestamp),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: GoetheanPalette.aspectGold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white60),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Captured Cosmic + Weather Snapshot Box
                        OrganicVesselContainer.inset(
                          accentColor: accentColor,
                          seed: 2.3,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CAPTURED COSMIC & WEATHER SNAPSHOT',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.9,
                                  color: GoetheanPalette.aspectGold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildSnapshotBadge(
                                    icon: Icons.auto_awesome_outlined,
                                    label: cosmic.rhythmBadgeLabel,
                                    color: accentColor,
                                  ),
                                  _buildSnapshotBadge(
                                    icon: Icons.nightlight_round,
                                    label: cosmic.moonBadgeLabel,
                                    color: GoetheanPalette.aspectGold,
                                  ),
                                  if (cosmic.diurnalPhaseName != null)
                                    _buildSnapshotBadge(
                                      icon: Icons.air_outlined,
                                      label: cosmic.diurnalPhaseName!,
                                      color: const Color(0xFF38BDF8),
                                    ),
                                  if (weatherSnap != null)
                                    _buildSnapshotBadge(
                                      icon: Icons.thermostat_outlined,
                                      label: weatherSnap.compactSummary,
                                      color: const Color(0xFF10B981),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Action Selector
                        Text(
                          'ACTION PERFORMED',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: FieldJournalAction.values
                              .map((candidate) {
                                final isSelected = _action == candidate;
                                return ChoiceChip(
                                  key: ValueKey(
                                    'journal_sheet_action_${candidate.name}',
                                  ),
                                  label: Text(
                                    '${candidate.timelineGlyph} ${candidate.shortLabel}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: accentColor.withValues(
                                    alpha: 0.32,
                                  ),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.05,
                                  ),
                                  side: BorderSide(
                                    color: isSelected
                                        ? accentColor
                                        : Colors.white.withValues(alpha: 0.14),
                                  ),
                                  showCheckmark: false,
                                  onSelected: (_) {
                                    setState(() {
                                      _action = candidate;
                                      if (candidate ==
                                              FieldJournalAction
                                                  .sprayPreparation &&
                                          _prepCode == null) {
                                        _prepCode = 'BD 500';
                                      } else if (candidate !=
                                          FieldJournalAction.sprayPreparation) {
                                        _prepCode = null;
                                      }
                                      _syncAutoTitle();
                                    });
                                  },
                                );
                              })
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 12),

                        if (_action == FieldJournalAction.sprayPreparation) ...[
                          Text(
                            'PREPARATION',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children:
                                const ['BD 500', 'BD 501', 'CPP', 'BD 508']
                                    .map((code) {
                                      final selected = _prepCode == code;
                                      return ChoiceChip(
                                        key: ValueKey(
                                          'journal_sheet_prep_$code',
                                        ),
                                        label: Text(
                                          code,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11.5,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                            color: selected
                                                ? Colors.white
                                                : Colors.white70,
                                          ),
                                        ),
                                        selected: selected,
                                        selectedColor: GoetheanPalette
                                            .aspectGold
                                            .withValues(alpha: 0.3),
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.05),
                                        showCheckmark: false,
                                        onSelected: (_) {
                                          setState(() {
                                            _prepCode = code;
                                            _syncAutoTitle();
                                          });
                                        },
                                      );
                                    })
                                    .toList(growable: false),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Entry Title
                        Text(
                          'ENTRY HEADLINE',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          key: const ValueKey('field_journal_title_input'),
                          controller: _titleController,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                          onChanged: (_) {
                            _titleManuallyEdited = true;
                          },
                          decoration: _inputDecoration(
                            hint: 'e.g. Sow Carrot (Gulerod) - Bed 2',
                            accentColor: accentColor,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Field Notes
                        Text(
                          'FIELD NOTES (BED, CULTIVAR, SEED LOT)',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          key: const ValueKey('field_journal_notes_input'),
                          controller: _notesController,
                          maxLines: 2,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: Colors.white,
                          ),
                          decoration: _inputDecoration(
                            hint: 'Record bed location, seed variety, soil tilth, or stirring observations...',
                            accentColor: accentColor,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Comparative Outcome Section (Closing the Maria Thun Loop)
                        Text(
                          'MARIA THUN COMPARATIVE TRIAL OUTCOME (OPTIONAL)',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                            color: GoetheanPalette.aspectGold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'Vigor / Yield Rating:',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 8),
                            for (int star = 1; star <= 5; star++)
                              IconButton(
                                key: ValueKey('field_journal_star_$star'),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _outcomeRating = _outcomeRating == star
                                        ? null
                                        : star;
                                  });
                                },
                                icon: Icon(
                                  (_outcomeRating ?? 0) >= star
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: GoetheanPalette.aspectGold,
                                  size: 22,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          key: const ValueKey('field_journal_outcome_input'),
                          controller: _outcomeController,
                          maxLines: 2,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: Colors.white,
                          ),
                          decoration: _inputDecoration(
                            hint: 'Follow-up observation: days to emerge, root form, pest resistance, cellar storage life...',
                            accentColor: GoetheanPalette.aspectGold,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Save Button (pinned footer)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const ValueKey('field_journal_save_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor.withValues(alpha: 0.32),
                      foregroundColor: const Color(0xFFF6ECD8),
                      side: BorderSide(
                        color: GoetheanPalette.aspectGold.withValues(
                          alpha: 0.75,
                        ),
                        width: 1.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _save,
                    icon: const Icon(
                      Icons.bookmark_added_outlined,
                      size: 18,
                      color: GoetheanPalette.aspectGold,
                    ),
                    label: Text(
                      widget.existingEntry != null
                          ? 'Save Journal Update'
                          : 'Save to Field Journal & Pin on Timeline',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required Color accentColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.26),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: accentColor),
      ),
    );
  }

  Widget _buildSnapshotBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF6ECD8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
