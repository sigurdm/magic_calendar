import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../services/garden_service.dart';
import '../theme/goethean_palette.dart';
import 'field_journal_sheet.dart';
import 'organic_vessel_container.dart';

/// Filter options for [FieldJournalCard].
enum FieldJournalFilter {
  /// Show all journal entries.
  all('All Entries'),

  /// Only Root (Earth) entries.
  root('Root'),

  /// Only Leaf (Water) entries.
  leaf('Leaf'),

  /// Only Flower (Air) entries.
  flower('Flower'),

  /// Only Fruit (Fire) entries.
  fruit('Fruit'),

  /// Only biodynamic preparation sprays.
  sprays('BD Sprays'),

  /// Only entries with recorded comparative outcomes.
  outcomes('With Outcomes');

  /// Chip label.
  final String label;

  const FieldJournalFilter(this.label);
}

/// Interactive Biodynamic Field Journal & Shared Garden Diary card displaying
/// logged sowing, spraying, harvesting, and observation entries alongside their
/// captured [CalendarInfo] and weather snapshots, collaborative member notes,
/// seed-to-harvest links, and cloud sync controls.
final class FieldJournalCard extends StatefulWidget {
  /// Reactive controller managing the user's persisted [GardenProfile] and SQLite journal shards.
  final GardenProfileController gardenController;

  /// Currently selected timeline instant used when logging a new action directly.
  final DateTime selectedDate;

  /// Active [CalendarInfo] at [selectedDate].
  final CalendarInfo info;

  /// Optional weather notifier supplying hourly weather observations/forecasts.
  final ValueNotifier<List<WeatherDataPoint>?>? weatherNotifier;

  /// Callback invoked when the user taps a journal entry to jump the timeline
  /// to that entry's marker.
  final ValueChanged<DateTime> onTimeJump;

  /// Creates an immutable [FieldJournalCard].
  const FieldJournalCard({
    super.key,
    required this.gardenController,
    required this.selectedDate,
    required this.info,
    required this.onTimeJump,
    this.weatherNotifier,
  });

  @override
  State<FieldJournalCard> createState() => _FieldJournalCardState();
}

final class _FieldJournalCardState extends State<FieldJournalCard> {
  FieldJournalFilter _selectedFilter = FieldJournalFilter.all;
  String? _selectedBedFilter;
  bool _showAll = false;

  List<FieldJournalEntry> _filterEntries(List<FieldJournalEntry> entries) {
    final byCategory = switch (_selectedFilter) {
      FieldJournalFilter.all => entries,
      FieldJournalFilter.root =>
        entries.where((e) => e.quality == PlantQuality.root).toList(),
      FieldJournalFilter.leaf =>
        entries.where((e) => e.quality == PlantQuality.leaf).toList(),
      FieldJournalFilter.flower =>
        entries.where((e) => e.quality == PlantQuality.flower).toList(),
      FieldJournalFilter.fruit =>
        entries.where((e) => e.quality == PlantQuality.fruit).toList(),
      FieldJournalFilter.sprays =>
        entries
            .where((e) => e.action == FieldJournalAction.sprayPreparation)
            .toList(),
      FieldJournalFilter.outcomes =>
        entries.where((e) => e.hasOutcome).toList(),
    };
    if (_selectedBedFilter == null) return byCategory;
    return byCategory
        .where((e) => e.bedName?.trim() == _selectedBedFilter)
        .toList();
  }

  Future<void> _showAddCoGardenerNoteDialog(FieldJournalEntry entry) async {
    final noteController = TextEditingController();
    final authorController = TextEditingController(
      text: widget.gardenController.localAuthorName,
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1F1A14),
          title: Text(
            'Add Collaborative Note • ${entry.title}',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF6ECD8),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('co_gardener_author_input'),
                controller: authorController,
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Gardener Name',
                  labelStyle: GoogleFonts.outfit(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('co_gardener_note_input'),
                controller: noteController,
                maxLines: 3,
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  hintText:
                      'Add observation without overwriting existing notes...',
                  hintStyle: GoogleFonts.outfit(color: Colors.white38),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const ValueKey('co_gardener_note_save_button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Append Note'),
            ),
          ],
        ),
      );
      if (confirmed == true && noteController.text.trim().isNotEmpty) {
        final author = authorController.text.trim();
        if (author.isNotEmpty) {
          widget.gardenController.updateGardenIdentity(authorName: author);
        }
        await widget.gardenController.addNoteToJournalEntry(
          entryId: entry.id,
          body: noteController.text.trim(),
          authorName: author.isEmpty ? null : author,
        );
      }
    } finally {
      noteController.dispose();
      authorController.dispose();
    }
  }

  Future<void> _showSharedGardenSyncDialog() async {
    final authorCtrl = TextEditingController(
      text: widget.gardenController.localAuthorName,
    );
    final gardenNameCtrl = TextEditingController(
      text: widget.gardenController.gardenName,
    );
    final currentTransport = widget.gardenController.syncTransport;
    final initialPath = currentTransport is DirectoryGardenSyncTransport
        ? currentTransport.directory.path
        : '';
    final folderCtrl = TextEditingController(text: initialPath);

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1F1A14),
          title: Text(
            'Shared Garden & Sharded SQLite Cloud Sync',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF6ECD8),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Entries are partitioned into monthly SQLite shards (YYYY-MM.<sha256>.sqlite) with Hybrid Logical Clock (HLC) CRDT merge semantics so multiple gardeners can log offline and sync via any shared folder or WebDAV endpoint.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('shared_garden_name_input'),
                  controller: gardenNameCtrl,
                  style: GoogleFonts.outfit(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Shared Garden Name',
                    labelStyle: GoogleFonts.outfit(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('shared_garden_author_input'),
                  controller: authorCtrl,
                  style: GoogleFonts.outfit(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Your Gardener Name (shown on notes)',
                    labelStyle: GoogleFonts.outfit(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('shared_garden_folder_input'),
                  controller: folderCtrl,
                  style: GoogleFonts.outfit(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    labelText:
                        'Shared Cloud Folder Path or https:// WebDAV URL',
                    hintText: '/path/to/shared/garden or https://...',
                    labelStyle: GoogleFonts.outfit(color: Colors.white70),
                    hintStyle: GoogleFonts.outfit(color: Colors.white38),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              key: const ValueKey('shared_garden_sync_save_button'),
              onPressed: () async {
                widget.gardenController.updateGardenIdentity(
                  authorName: authorCtrl.text.trim(),
                  gardenName: gardenNameCtrl.text.trim(),
                );
                final endpoint = folderCtrl.text.trim();
                if (endpoint.isNotEmpty) {
                  if (endpoint.startsWith('https://')) {
                    widget.gardenController.setSyncTransport(
                      WebDavGardenSyncTransport(baseUri: Uri.parse(endpoint)),
                    );
                  } else {
                    widget.gardenController.setSyncTransport(
                      DirectoryGardenSyncTransport(endpoint),
                    );
                  }
                  await widget.gardenController.syncJournal();
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Save & Sync Now'),
            ),
          ],
        ),
      );
    } finally {
      authorCtrl.dispose();
      gardenNameCtrl.dispose();
      folderCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.gardenController,
      builder: (context, _) {
        final profile = widget.gardenController.value;
        final allEntries = profile.journalEntries;
        final knownBeds = widget.gardenController.listBedNames();
        final filtered = _filterEntries(allEntries);
        final visible = _showAll
            ? filtered
            : filtered.take(5).toList(growable: false);
        const accentColor = GoetheanPalette.aspectGold;

        final pflanzzeitCount = allEntries
            .where((e) => e.cosmicSnapshot.isMoonDescending)
            .length;
        final ratedEntries = allEntries
            .where((e) => e.effectiveOutcomeRating != null)
            .toList(growable: false);
        final avgRating = ratedEntries.isEmpty
            ? null
            : ratedEntries
                      .map((e) => e.effectiveOutcomeRating!)
                      .reduce((a, b) => a + b) /
                  ratedEntries.length;
        final openShardsCount =
            widget.gardenController.journalStore?.openShardCount;

        return OrganicVesselContainer(
          accentColor: accentColor,
          seed: 5.2,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.menu_book_outlined,
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
                          'Biodynamic Field Journal (${allEntries.length})',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF6ECD8),
                          ),
                        ),
                        Text(
                          '${widget.gardenController.gardenName} • ${widget.gardenController.localAuthorName}'
                          '${openShardsCount != null ? " • $openShardsCount SQLite shard(s) active" : ""}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('field_journal_sync_button'),
                    tooltip: 'Shared Garden & Cloud Sync Settings',
                    icon: Icon(
                      widget.gardenController.syncTransport != null
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_sync_outlined,
                      color: accentColor,
                      size: 20,
                    ),
                    onPressed: _showSharedGardenSyncDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Log Action Button + Quick Observation + Comparative Summary Strip
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    key: const ValueKey('field_journal_log_now_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor.withValues(alpha: 0.24),
                      foregroundColor: const Color(0xFFF6ECD8),
                      side: BorderSide(
                        color: accentColor.withValues(alpha: 0.65),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      FieldJournalSheet.show(
                        context,
                        gardenController: widget.gardenController,
                        timestamp: widget.selectedDate,
                        calendarInfo: widget.info,
                        weatherSeries: widget.weatherNotifier?.value,
                      );
                    },
                    icon: const Icon(
                      Icons.add_task_outlined,
                      size: 16,
                      color: accentColor,
                    ),
                    label: Text(
                      'Log Action at Selected Time',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('field_journal_quick_note_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF6ECD8),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      FieldJournalSheet.show(
                        context,
                        gardenController: widget.gardenController,
                        timestamp: widget.selectedDate,
                        calendarInfo: widget.info,
                        weatherSeries: widget.weatherNotifier?.value,
                        initialAction: FieldJournalAction.observation,
                      );
                    },
                    icon: const Icon(
                      Icons.sticky_note_2_outlined,
                      size: 15,
                      color: accentColor,
                    ),
                    label: Text(
                      'Jot Observation',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (allEntries.isNotEmpty) ...[
                    _buildSummaryChip(
                      'Pflanzzeit: $pflanzzeitCount/${allEntries.length}',
                      GoetheanPalette.rootEarth,
                    ),
                    if (avgRating != null)
                      _buildSummaryChip(
                        'Avg Trial Outcome: ★ ${avgRating.toStringAsFixed(1)}/5',
                        accentColor,
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              if (allEntries.isEmpty)
                OrganicVesselContainer.inset(
                  accentColor: accentColor,
                  seed: 3.4,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_stories_outlined,
                        color: accentColor,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Maria Thun\'s calendar grew out of comparative sowing logs. Tap "Log Action" on any crop, recommended window, or preparation spray to record a cosmic & weather snapshot and pin it directly onto the timeline.',
                          key: const ValueKey('field_journal_empty_state'),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFFF3E5C8),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // Filter Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in FieldJournalFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            key: ValueKey(
                              'field_journal_filter_${filter.name}',
                            ),
                            label: Text(
                              filter.label,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: _selectedFilter == filter
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: _selectedFilter == filter
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                            ),
                            selected: _selectedFilter == filter,
                            selectedColor: accentColor.withValues(alpha: 0.3),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.05,
                            ),
                            side: BorderSide(
                              color: _selectedFilter == filter
                                  ? accentColor
                                  : Colors.white.withValues(alpha: 0.14),
                            ),
                            showCheckmark: false,
                            onSelected: (_) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            },
                          ),
                        ),
                      for (final bed in knownBeds)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            key: ValueKey('field_journal_bed_filter_$bed'),
                            label: Text(
                              '📍 $bed',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: _selectedBedFilter == bed
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: _selectedBedFilter == bed
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                            ),
                            selected: _selectedBedFilter == bed,
                            selectedColor: GoetheanPalette.leafWater.withValues(
                              alpha: 0.3,
                            ),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.05,
                            ),
                            showCheckmark: false,
                            onSelected: (_) {
                              setState(() {
                                _selectedBedFilter = _selectedBedFilter == bed
                                    ? null
                                    : bed;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'No journal entries match the "${_selectedFilter.label}" filter.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  )
                else ...[
                  for (final entry in visible) _buildEntryTile(context, entry),
                  if (filtered.length > 5)
                    TextButton.icon(
                      key: const ValueKey('field_journal_toggle_all_button'),
                      onPressed: () {
                        setState(() {
                          _showAll = !_showAll;
                        });
                      },
                      icon: Icon(
                        _showAll ? Icons.expand_less : Icons.expand_more,
                        color: accentColor,
                        size: 18,
                      ),
                      label: Text(
                        _showAll
                            ? 'Show Recent 5 Entries'
                            : 'Show All ${filtered.length} Journal Entries',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF6ECD8),
        ),
      ),
    );
  }

  Widget _buildEntryTile(BuildContext context, FieldJournalEntry entry) {
    final entryColor = entry.quality == PlantQuality.none
        ? GoetheanPalette.aspectGold
        : GoetheanPalette.getColor(entry.quality);
    final dateFmt = DateFormat('EEE, MMM d, yyyy • HH:mm');
    final linkedParent = widget.gardenController.findPlantingBatch(
      entry.parentEntryId,
    );
    final activeNotes = entry.activeNotes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('journal_entry_${entry.id}'),
          onTap: () => widget.onTimeJump(entry.timestamp),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: entryColor.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: entryColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        entry.timelineMarkerGlyph,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${dateFmt.format(entry.timestamp)}'
                            '${entry.bedName != null ? " • ${entry.bedName}" : ""}'
                            '${entry.location != null ? " • ${entry.location!.displayLabel}" : ""}'
                            ' • by ${entry.authorName}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: const Color(0xFFF6ECD8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: ValueKey('journal_add_note_${entry.id}'),
                      tooltip: 'Add collaborative garden note',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.add_comment_outlined,
                        size: 17,
                        color: Colors.white70,
                      ),
                      onPressed: () => _showAddCoGardenerNoteDialog(entry),
                    ),
                    IconButton(
                      key: ValueKey('journal_jump_${entry.id}'),
                      tooltip: 'Jump timeline to logged event',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.ads_click_outlined,
                        size: 18,
                        color: GoetheanPalette.aspectGold,
                      ),
                      onPressed: () => widget.onTimeJump(entry.timestamp),
                    ),
                    IconButton(
                      key: ValueKey('journal_delete_${entry.id}'),
                      tooltip: 'Delete journal entry',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        widget.gardenController.removeJournalEntry(entry.id);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Cosmic, Weather, Bed & Seed-to-Harvest Badges
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildSnapshotPill(
                      entry.cosmicSnapshot.rhythmBadgeLabel,
                      entryColor,
                    ),
                    _buildSnapshotPill(
                      entry.cosmicSnapshot.moonBadgeLabel,
                      GoetheanPalette.aspectGold,
                    ),
                    if (entry.bedName != null && entry.bedName!.isNotEmpty)
                      _buildSnapshotPill(
                        '📍 ${entry.bedName!}',
                        GoetheanPalette.leafWater,
                      ),
                    if (linkedParent != null)
                      _buildSnapshotPill(
                        '🌱 ${linkedParent.daysElapsedAt(entry.timestamp)}d since ${linkedParent.title} (${linkedParent.cosmicSummary})',
                        GoetheanPalette.aspectGold,
                      ),
                    if (entry.cosmicSnapshot.diurnalPhaseName != null)
                      _buildSnapshotPill(
                        entry.cosmicSnapshot.diurnalPhaseName!,
                        const Color(0xFF38BDF8),
                      ),
                    if (entry.weatherSnapshot != null)
                      _buildSnapshotPill(
                        entry.weatherSnapshot!.compactSummary,
                        const Color(0xFF10B981),
                      ),
                  ],
                ),

                if (activeNotes.length > 1) ...[
                  const SizedBox(height: 8),
                  for (final note in activeNotes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${note.authorName}: ${note.body}'
                        '${note.outcomeRating != null ? " (★ ${note.outcomeRating}/5)" : ""}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                    ),
                ] else if (entry.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.notes,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.35,
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (entry.hasOutcome)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: GoetheanPalette.aspectGold.withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: GoetheanPalette.aspectGold.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Text(
                            '${entry.effectiveOutcomeRating != null ? "★ ${entry.effectiveOutcomeRating}/5" : "Outcome"}'
                            '${entry.outcomeNote.isNotEmpty ? " · ${entry.outcomeNote}" : ""}',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF6ECD8),
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          'Tap to jump timeline • Record comparative outcome',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            color: Colors.white54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: ValueKey('journal_record_outcome_${entry.id}'),
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
                        minimumSize: const Size(64, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        FieldJournalSheet.show(
                          context,
                          gardenController: widget.gardenController,
                          timestamp: entry.timestamp,
                          calendarInfo: widget.info,
                          existingEntry: entry,
                        );
                      },
                      icon: Icon(
                        entry.hasOutcome
                            ? Icons.edit_note_outlined
                            : Icons.rate_review_outlined,
                        size: 14,
                        color: GoetheanPalette.aspectGold,
                      ),
                      label: Text(
                        entry.hasOutcome ? 'Edit Outcome' : 'Log Outcome',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSnapshotPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF6ECD8),
        ),
      ),
    );
  }
}
