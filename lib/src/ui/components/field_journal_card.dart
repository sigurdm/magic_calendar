import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../services/ephemeris_service.dart';
import '../../services/garden_service.dart';
import '../theme/goethean_palette.dart';
import '../views/bed_succession_planner_page.dart';
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

  /// Optional callback invoked when the user shares a formatted garden note,
  /// plot summary, invite link, or portable note bundle (e.g. to open the native
  /// mobile share sheet). Always copies to the system clipboard as well.
  final void Function(String text, {String? subject})? onShareText;

  /// Optional mobile OAuth2 access token provider for Google Drive sync.
  final GoogleDriveAccessTokenProvider? googleDriveTokenProvider;

  /// Optional ephemeris service for snapping planned bed succession crops to optimal Maria Thun windows.
  final EphemerisService? ephemeris;

  /// Creates an immutable [FieldJournalCard].
  const FieldJournalCard({
    super.key,
    required this.gardenController,
    required this.selectedDate,
    required this.info,
    required this.onTimeJump,
    this.weatherNotifier,
    this.onShareText,
    this.googleDriveTokenProvider,
    this.ephemeris,
  });

  @override
  State<FieldJournalCard> createState() => _FieldJournalCardState();
}

final class _FieldJournalCardState extends State<FieldJournalCard> {
  static final DateFormat _entryDateFmt = DateFormat(
    'EEE, MMM d, yyyy • HH:mm',
  );
  static final DateFormat _shortDateFmt = DateFormat('MMM d');

  FieldJournalFilter _selectedFilter = FieldJournalFilter.all;
  String? _selectedBedFilter;
  String? _selectedShardFilter;
  String _searchQuery = '';
  bool _showAll = false;
  late final TextEditingController _searchController;

  // Memoized derived state to eliminate redundant plot evaluations, batch scans,
  // and entry filtering across rebuilds when underlying data hasn't changed.
  GardenProfile? _cachedProfile;
  int? _cachedOpenShardsCount;
  int? _cachedDayBucket;
  List<String> _cachedKnownBeds = const <String>[];
  List<GardenPlot> _cachedKnownPlots = const <GardenPlot>[];
  List<String> _cachedKnownShards = const <String>[];
  List<PlantingBatchSummary> _cachedActiveBatches =
      const <PlantingBatchSummary>[];
  int _cachedPflanzzeitCount = 0;
  double? _cachedAvgRating;
  Map<String, PlotRotationAssessment> _cachedPlotRotations =
      const <String, PlotRotationAssessment>{};
  Map<String, PlotSuccessionPlan> _cachedPlotSuccessions =
      const <String, PlotSuccessionPlan>{};
  Map<String, List<PlantingBatchSummary>> _cachedPlotActiveBatches =
      const <String, List<PlantingBatchSummary>>{};
  Map<String, List<QueuedGardenTask>> _cachedPlotTasks =
      const <String, List<QueuedGardenTask>>{};
  Map<String, List<FieldJournalEntry>> _cachedChildrenByParentId =
      const <String, List<FieldJournalEntry>>{};
  Map<String, PlantingBatchSummary> _cachedBatchesByEntryId =
      const <String, PlantingBatchSummary>{};

  String? _cachedFilterKey;
  List<FieldJournalEntry> _cachedFilteredEntries = const <FieldJournalEntry>[];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _ensureDerivedJournalCache(GardenProfile profile, int? openShardsCount) {
    final dayBucket = DateTime.utc(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    ).millisecondsSinceEpoch;
    final currentBeds = widget.gardenController.listBedNames();
    final currentPlots = widget.gardenController.listPlots();
    final currentShards = widget.gardenController.listKnownShardKeys();

    final baseChanged =
        !identical(_cachedProfile, profile) ||
        _cachedOpenShardsCount != openShardsCount ||
        _cachedDayBucket != dayBucket ||
        !identical(_cachedKnownBeds, currentBeds) ||
        !identical(_cachedKnownPlots, currentPlots) ||
        !identical(_cachedKnownShards, currentShards);

    if (baseChanged) {
      _cachedProfile = profile;
      _cachedOpenShardsCount = openShardsCount;
      _cachedDayBucket = dayBucket;
      _cachedFilterKey = null;

      final allEntries = profile.journalEntries;
      _cachedKnownBeds = currentBeds;
      _cachedKnownPlots = currentPlots;
      _cachedKnownShards = currentShards;
      if (_selectedBedFilter != null &&
          !currentBeds.any(
            (b) => b.toLowerCase() == _selectedBedFilter!.toLowerCase(),
          )) {
        _selectedBedFilter = null;
      }
      if (_selectedShardFilter != null &&
          !currentShards.contains(_selectedShardFilter)) {
        _selectedShardFilter = null;
      }
      _cachedActiveBatches = widget.gardenController.listPlantingBatches(
        onlyActiveInGround: true,
      );
      final allBatches = widget.gardenController.listPlantingBatches(
        onlyActiveInGround: false,
      );
      _cachedBatchesByEntryId = <String, PlantingBatchSummary>{
        for (final b in allBatches) b.entryId: b,
      };

      var pflanzzeit = 0;
      var ratingSum = 0;
      var ratingCount = 0;
      final childrenMap = <String, List<FieldJournalEntry>>{};
      for (final e in allEntries) {
        if (e.cosmicSnapshot.isMoonDescending) {
          pflanzzeit++;
        }
        final rating = e.effectiveOutcomeRating;
        if (rating != null) {
          ratingSum += rating;
          ratingCount++;
        }
        final parentId = e.parentEntryId;
        if (parentId != null && !e.isDeleted) {
          (childrenMap[parentId] ??= <FieldJournalEntry>[]).add(e);
        }
      }
      for (final list in childrenMap.values) {
        if (list.length > 1) {
          list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }
      }
      _cachedPflanzzeitCount = pflanzzeit;
      _cachedAvgRating = ratingCount == 0 ? null : ratingSum / ratingCount;
      _cachedChildrenByParentId = childrenMap;

      if (_cachedKnownPlots.isEmpty) {
        _cachedPlotRotations = const <String, PlotRotationAssessment>{};
        _cachedPlotSuccessions = const <String, PlotSuccessionPlan>{};
        _cachedPlotActiveBatches = const <String, List<PlantingBatchSummary>>{};
        _cachedPlotTasks = const <String, List<QueuedGardenTask>>{};
      } else {
        final rotations = <String, PlotRotationAssessment>{};
        final successions = <String, PlotSuccessionPlan>{};
        final plotBatches = <String, List<PlantingBatchSummary>>{};
        final plotTasks = <String, List<QueuedGardenTask>>{};
        final taskQueue = profile.taskQueue;

        for (final plot in _cachedKnownPlots) {
          final name = plot.name;
          plotBatches[name] = _cachedActiveBatches
              .where((b) => b.bedName == name)
              .toList(growable: false);
          plotTasks[name] = taskQueue
              .where((t) => t.bedName == name)
              .toList(growable: false);
          rotations[name] = widget.gardenController.evaluatePlotRotation(
            name,
            referenceTime: widget.selectedDate,
          );
          successions[name] = widget.gardenController.buildPlotSuccessionPlan(
            name,
            referenceTime: widget.selectedDate,
          );
        }
        _cachedPlotRotations = rotations;
        _cachedPlotSuccessions = successions;
        _cachedPlotActiveBatches = plotBatches;
        _cachedPlotTasks = plotTasks;
      }
    }

    final filterKey =
        '$_searchQuery|${_selectedFilter.name}|${_selectedBedFilter ?? ""}|${_selectedShardFilter ?? ""}';
    if (_cachedFilterKey != filterKey) {
      _cachedFilterKey = filterKey;
      final baseEntries = _searchQuery.trim().isEmpty
          ? profile.journalEntries
          : widget.gardenController.searchJournalEntries(_searchQuery);
      _cachedFilteredEntries = _filterEntries(baseEntries);
    }
  }

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
    final byBed = _selectedBedFilter == null
        ? byCategory
        : byCategory
              .where((e) => e.bedName?.trim() == _selectedBedFilter)
              .toList();
    if (_selectedShardFilter == null) return byBed;
    return byBed.where((e) => e.shardKey == _selectedShardFilter).toList();
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
      if (!mounted) return;
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

  Future<void> _showPhotoViewerDialog(
    FieldJournalEntry entry,
    JournalAttachment attachment,
  ) async {
    final fullBytesFuture = widget.gardenController.loadFullAttachmentBytes(
      attachment,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1F1A14),
        title: Text(
          attachment.caption.isNotEmpty ? attachment.caption : entry.title,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFF6ECD8),
          ),
        ),
        content: FutureBuilder<Uint8List?>(
          future: fullBytesFuture,
          builder: (context, snapshot) {
            final bytes = snapshot.data ?? attachment.thumbnailBytes;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  key: ValueKey('photo_viewer_image_${attachment.id}'),
                  width: 320,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: GoetheanPalette.aspectGold.withValues(alpha: 0.45),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: bytes != null
                      ? Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(
                              Icons.photo_outlined,
                              color: Colors.white70,
                              size: 40,
                            ),
                          ),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
                const SizedBox(height: 10),
                Text(
                  'By ${attachment.authorName} • '
                  '${attachment.remoteBlobName.length > 22 ? "${attachment.remoteBlobName.substring(0, 22)}…" : attachment.remoteBlobName}',
                  key: ValueKey('photo_viewer_meta_${attachment.id}'),
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: Colors.white70,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            key: const ValueKey('photo_viewer_close_button'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareOrCopyText(
    String text, {
    required String label,
    String? subject,
  }) async {
    widget.onShareText?.call(text, subject: subject ?? label);
    unawaited(Clipboard.setData(ClipboardData(text: text)).catchError((_) {}));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const ValueKey('field_journal_share_snackbar'),
        content: Text('$label copied & ready to share'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showSharedGardenSyncDialog() async {
    final authorCtrl = TextEditingController(
      text: widget.gardenController.localAuthorName,
    );
    final gardenNameCtrl = TextEditingController(
      text: widget.gardenController.gardenName,
    );
    final currentTransport = widget.gardenController.syncTransport;
    final initialPath = switch (currentTransport) {
      DirectoryGardenSyncTransport(:final directory) => directory.path,
      WebDavGardenSyncTransport(:final baseUri) => baseUri.toString(),
      _ => '',
    };
    final initialDriveFolder =
        currentTransport is GoogleDriveGardenSyncTransport
        ? currentTransport.rootFolderId
        : '';
    final folderCtrl = TextEditingController(text: initialPath);
    final driveFolderCtrl = TextEditingController(text: initialDriveFolder);
    final driveTokenCtrl = TextEditingController();
    final inviteEmailCtrl = TextEditingController();
    final importBundleCtrl = TextEditingController();
    String? statusFeedback;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final activeTransport = widget.gardenController.syncTransport;
            final driveTransport =
                activeTransport is GoogleDriveGardenSyncTransport
                ? activeTransport
                : null;
            return AlertDialog(
              backgroundColor: const Color(0xFF1F1A14),
              title: Text(
                'Google Drive Sync & Share Garden Notes',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF6ECD8),
                ),
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Entries are partitioned into monthly SQLite shards (YYYY-MM.<sha256>.sqlite) with HLC CRDT merge so co-gardeners can log offline on mobile and sync via Google Drive, a shared folder, or portable note bundles.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                      if (activeTransport != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          key: const ValueKey('active_sync_transport_banner'),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cloud_done_outlined,
                                size: 16,
                                color: Color(0xFF6EE7B7),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Connected: ${activeTransport.displayName}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFA7F3D0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('shared_garden_name_input'),
                        controller: gardenNameCtrl,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Shared Garden Name',
                          labelStyle: GoogleFonts.outfit(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const ValueKey('shared_garden_author_input'),
                        controller: authorCtrl,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Your Gardener Name (shown on notes)',
                          labelStyle: GoogleFonts.outfit(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'GOOGLE DRIVE MOBILE SYNC',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: GoetheanPalette.aspectGold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        key: const ValueKey('drive_folder_input'),
                        controller: driveFolderCtrl,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              'Google Drive Folder Link, ID, or Invite Code',
                          hintText: 'https://drive.google.com/drive/folders/... or magiccalendar://...',
                          labelStyle: GoogleFonts.outfit(color: Colors.white70),
                          hintStyle: GoogleFonts.outfit(color: Colors.white38),
                        ),
                      ),
                      if (widget.googleDriveTokenProvider == null) ...[
                        const SizedBox(height: 6),
                        TextField(
                          key: const ValueKey('drive_access_token_input'),
                          controller: driveTokenCtrl,
                          obscureText: true,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                'Google OAuth Access Token (Drive Scope)',
                            labelStyle: GoogleFonts.outfit(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                      if (driveTransport != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            OutlinedButton.icon(
                              key: const ValueKey('drive_copy_invite_button'),
                              onPressed: () async {
                                final msg = driveTransport.inviteLink
                                    .formatInviteMessage();
                                await _shareOrCopyText(
                                  msg,
                                  label: 'Google Drive Garden Invite',
                                );
                              },
                              icon: const Icon(Icons.share_outlined, size: 14),
                              label: const Text('Share Garden Invite Link'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey('drive_invite_email_input'),
                                controller: inviteEmailCtrl,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  labelText:
                                      'Invite Co-Gardener on Drive (Email)',
                                  labelStyle: GoogleFonts.outfit(
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              key: const ValueKey('drive_invite_email_button'),
                              onPressed: () async {
                                final email = inviteEmailCtrl.text.trim();
                                if (email.isEmpty) return;
                                try {
                                  await driveTransport.shareFolderWithEmail(
                                    emailAddress: email,
                                  );
                                  if (!dialogContext.mounted) return;
                                  setDialogState(() {
                                    statusFeedback =
                                        'Granted Google Drive write access to $email';
                                    inviteEmailCtrl.clear();
                                  });
                                } catch (e) {
                                  if (!dialogContext.mounted) return;
                                  setDialogState(() {
                                    statusFeedback = 'Drive share failed: $e';
                                  });
                                }
                              },
                              child: const Text('Invite'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'LOCAL SHARED FOLDER OR WEBDAV (OPTIONAL)',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Colors.white60,
                        ),
                      ),
                      TextField(
                        key: const ValueKey('shared_garden_folder_input'),
                        controller: folderCtrl,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              'Shared Cloud Folder Path or https:// WebDAV URL',
                          hintText: '/path/to/shared/garden or https://...',
                          labelStyle: GoogleFonts.outfit(color: Colors.white70),
                          hintStyle: GoogleFonts.outfit(color: Colors.white38),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'PORTABLE GARDEN NOTE BUNDLES (NO ACCOUNT NEEDED)',
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
                        runSpacing: 6,
                        children: [
                          OutlinedButton.icon(
                            key: const ValueKey('export_note_bundle_button'),
                            onPressed: () async {
                              final bundle = widget.gardenController
                                  .exportSharedNoteBundle();
                              await _shareOrCopyText(
                                bundle.toJsonString(),
                                label:
                                    'Portable Garden Bundle (${bundle.entries.length} notes)',
                              );
                            },
                            icon: const Icon(
                              Icons.ios_share_outlined,
                              size: 14,
                            ),
                            label: const Text('Copy Note Bundle'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey('import_note_bundle_input'),
                              controller: importBundleCtrl,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Paste Shared Note Bundle JSON',
                                labelStyle: GoogleFonts.outfit(
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            key: const ValueKey('import_note_bundle_button'),
                            onPressed: () async {
                              final raw = importBundleCtrl.text.trim();
                              if (raw.isEmpty) return;
                              try {
                                final imported = await widget.gardenController
                                    .importSharedNoteBundle(raw);
                                if (!dialogContext.mounted) return;
                                setDialogState(() {
                                  statusFeedback =
                                      'Merged ${imported.entries.length} note(s) & ${imported.plots.length} plot(s) from ${imported.exportedBy}';
                                  importBundleCtrl.clear();
                                });
                              } catch (e) {
                                if (!dialogContext.mounted) return;
                                setDialogState(() {
                                  statusFeedback = 'Bundle import failed: $e';
                                });
                              }
                            },
                            child: const Text('Import'),
                          ),
                        ],
                      ),
                      if (statusFeedback != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          statusFeedback!,
                          key: const ValueKey('sync_dialog_status_feedback'),
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: const Color(0xFFA7F3D0),
                          ),
                        ),
                      ],
                    ],
                  ),
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
                    final driveTarget = driveFolderCtrl.text.trim();
                    final endpoint = folderCtrl.text.trim();
                    if (driveTarget.isNotEmpty) {
                      final provider =
                          widget.googleDriveTokenProvider ??
                          () async => driveTokenCtrl.text.trim();
                      widget.gardenController.connectGoogleDrive(
                        folderIdOrInvite: driveTarget,
                        tokenProvider: provider,
                        gardenName: gardenNameCtrl.text.trim(),
                      );
                      await widget.gardenController.syncJournal();
                    } else if (endpoint.isNotEmpty) {
                      if (endpoint.contains('drive.google.com') ||
                          endpoint.startsWith('magiccalendar://')) {
                        final provider =
                            widget.googleDriveTokenProvider ??
                            () async => driveTokenCtrl.text.trim();
                        widget.gardenController.connectGoogleDrive(
                          folderIdOrInvite: endpoint,
                          tokenProvider: provider,
                          gardenName: gardenNameCtrl.text.trim(),
                        );
                      } else if (endpoint.startsWith('https://')) {
                        final parsedUri = Uri.tryParse(endpoint);
                        if (parsedUri == null || !parsedUri.hasAuthority) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              statusFeedback = 'Invalid WebDAV URL: $endpoint';
                            });
                          }
                          return;
                        }
                        widget.gardenController.setSyncTransport(
                          WebDavGardenSyncTransport(baseUri: parsedUri),
                        );
                      } else {
                        widget.gardenController.setSyncTransport(
                          DirectoryGardenSyncTransport(endpoint),
                        );
                      }
                      await widget.gardenController.syncJournal();
                    } else if (widget.gardenController.syncTransport != null) {
                      await widget.gardenController.syncJournal();
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Save & Sync Now'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      authorCtrl.dispose();
      gardenNameCtrl.dispose();
      folderCtrl.dispose();
      driveFolderCtrl.dispose();
      driveTokenCtrl.dispose();
      inviteEmailCtrl.dispose();
      importBundleCtrl.dispose();
    }
  }

  Future<void> _showUpsertPlotDialog([GardenPlot? existing]) async {
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
              style: GoogleFonts.cormorantGaramond(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF6ECD8),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const ValueKey('plot_dialog_name_input'),
                    controller: nameCtrl,
                    enabled: existing == null,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Plot / Bed Name (e.g. Bed 1, North Tunnel)',
                      labelStyle: GoogleFonts.outfit(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('plot_dialog_area_input'),
                    controller: areaCtrl,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Garden Section / Zone (e.g. Kitchen Garden, Greenhouse)',
                      labelStyle: GoogleFonts.outfit(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'PLOT ENVIRONMENT',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: GoetheanPalette.aspectGold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: GardenPlotType.values
                        .map((type) {
                          final isSelected = selectedType == type;
                          return ChoiceChip(
                            key: ValueKey('plot_dialog_type_${type.name}'),
                            label: Text(
                              '${type.glyph} ${type.displayName}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                              ),
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
                    key: const ValueKey('plot_dialog_dimensions_input'),
                    controller: dimCtrl,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Dimensions / Area (e.g. 1.2m × 4.0m)',
                      labelStyle: GoogleFonts.outfit(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('plot_dialog_notes_input'),
                    controller: notesCtrl,
                    maxLines: 2,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Soil Type, Sun Exposure, or Notes',
                      labelStyle: GoogleFonts.outfit(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (existing != null)
                TextButton(
                  key: const ValueKey('plot_dialog_delete_button'),
                  onPressed: () {
                    widget.gardenController.deletePlot(existing.name);
                    if (mounted &&
                        _selectedBedFilter != null &&
                        _selectedBedFilter!.toLowerCase() ==
                            existing.name.toLowerCase()) {
                      setState(() {
                        _selectedBedFilter = null;
                      });
                    }
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
                key: const ValueKey('plot_dialog_save_button'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save Plot'),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;
      final trimmedName = nameCtrl.text.trim();
      if (confirmed == true && trimmedName.isNotEmpty) {
        final matchedExisting =
            existing ?? widget.gardenController.findPlot(trimmedName);
        widget.gardenController.upsertPlot(
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
    return ListenableBuilder(
      listenable: widget.gardenController,
      builder: (context, _) {
        final profile = widget.gardenController.value;
        final openShardsCount =
            widget.gardenController.journalStore?.openShardCount;
        _ensureDerivedJournalCache(profile, openShardsCount);

        final allEntries = profile.journalEntries;
        final knownBeds = _cachedKnownBeds;
        final knownPlots = _cachedKnownPlots;
        final knownShards = _cachedKnownShards;
        final activeBatches = _cachedActiveBatches;
        final filtered = _cachedFilteredEntries;
        final visible = _showAll
            ? filtered
            : filtered.take(5).toList(growable: false);
        const accentColor = GoetheanPalette.aspectGold;

        final pflanzzeitCount = _cachedPflanzzeitCount;
        final avgRating = _cachedAvgRating;

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

              // Log Action Button + Quick Observation + Add Plot + Comparative Summary Strip
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
                  OutlinedButton.icon(
                    key: const ValueKey('field_journal_add_plot_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF6ECD8),
                      side: BorderSide(
                        color: GoetheanPalette.leafWater.withValues(
                          alpha: 0.45,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _showUpsertPlotDialog,
                    icon: const Icon(
                      Icons.grid_view_outlined,
                      size: 15,
                      color: GoetheanPalette.leafWater,
                    ),
                    label: Text(
                      '+ Add Plot / Bed',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey(
                      'field_journal_toggle_succession_planner',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF6ECD8),
                      backgroundColor: GoetheanPalette.leafWater.withValues(
                        alpha: 0.18,
                      ),
                      side: BorderSide(
                        color: GoetheanPalette.aspectGold.withValues(
                          alpha: 0.55,
                        ),
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
                      BedSuccessionPlannerPage.open(
                        context,
                        gardenController: widget.gardenController,
                        selectedDate: widget.selectedDate,
                        info: widget.info,
                        ephemeris: widget.ephemeris,
                        weatherNotifier: widget.weatherNotifier,
                        onTimeJump: widget.onTimeJump,
                        latitude: profile.activeLocation.latitude,
                        longitude: profile.activeLocation.longitude,
                      );
                    },
                    icon: const Icon(
                      Icons.open_in_full_outlined,
                      size: 14,
                      color: GoetheanPalette.aspectGold,
                    ),
                    label: Text(
                      'Bed Succession Planner',
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

              if (knownPlots.isNotEmpty) ...[
                RepaintBoundary(
                  child: _buildPlotsOverviewSection(
                    context,
                    knownPlots,
                    activeBatches,
                    profile.taskQueue,
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (activeBatches.isNotEmpty) ...[
                RepaintBoundary(
                  child: _buildActivePlantingsSection(context, activeBatches),
                ),
                const SizedBox(height: 14),
              ],

              if (allEntries.isEmpty && knownShards.isEmpty)
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
                // Search Bar + Month Shard Browser
                TextField(
                  key: const ValueKey('field_journal_search_input'),
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search diary notes, crops, beds, cultivars, or outcomes...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 17,
                      color: accentColor,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.clear,
                              size: 16,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.24),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ),
                if (knownShards.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            key: const ValueKey('field_journal_shard_all'),
                            label: Text(
                              'All Loaded Months',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: _selectedShardFilter == null
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: _selectedShardFilter == null
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                            ),
                            selected: _selectedShardFilter == null,
                            selectedColor: accentColor.withValues(alpha: 0.28),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.05,
                            ),
                            showCheckmark: false,
                            onSelected: (_) {
                              setState(() {
                                _selectedShardFilter = null;
                              });
                            },
                          ),
                        ),
                        for (final shardKey in knownShards)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              key: ValueKey('field_journal_shard_$shardKey'),
                              label: Text(
                                '${widget.gardenController.isShardHydrated(shardKey) ? "🗓️" : "☁️"} $shardKey',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: _selectedShardFilter == shardKey
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: _selectedShardFilter == shardKey
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                              selected: _selectedShardFilter == shardKey,
                              selectedColor: accentColor.withValues(alpha: 0.3),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                              showCheckmark: false,
                              onSelected: (_) async {
                                final parts = shardKey.split('-');
                                final year = int.parse(parts[0]);
                                final month = int.parse(parts[1]);
                                final monthStart = DateTime.utc(year, month, 1);
                                final monthEnd = DateTime.utc(
                                  year,
                                  month + 1,
                                  0,
                                  23,
                                  59,
                                  59,
                                );
                                await widget.gardenController
                                    .ensureWindowLoaded(monthStart, monthEnd);
                                if (!mounted) return;
                                setState(() {
                                  _selectedShardFilter =
                                      _selectedShardFilter == shardKey
                                      ? null
                                      : shardKey;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),

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
                  for (final entry in visible)
                    _buildEntryTile(context, entry, allEntries),
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

  Widget _buildPlotsOverviewSection(
    BuildContext context,
    List<GardenPlot> plots,
    List<PlantingBatchSummary> activeBatches,
    List<QueuedGardenTask> taskQueue,
  ) {
    return OrganicVesselContainer.inset(
      key: const ValueKey('field_journal_plots_section'),
      accentColor: GoetheanPalette.aspectGold,
      seed: 4.8,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.grid_view_outlined,
                size: 16,
                color: GoetheanPalette.aspectGold,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'GARDEN PLOTS & BEDS (${plots.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: GoetheanPalette.aspectGold,
                  ),
                ),
              ),
              if (_selectedBedFilter != null)
                TextButton(
                  key: const ValueKey('clear_plot_filter_button'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedBedFilter = null;
                    });
                  },
                  child: Text(
                    'Show All Plots',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: GoetheanPalette.aspectGold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final plot in plots)
            Builder(
              builder: (context) {
                final plotActive =
                    _cachedPlotActiveBatches[plot.name] ??
                    activeBatches
                        .where((b) => b.bedName == plot.name)
                        .toList(growable: false);
                final plotTasks =
                    _cachedPlotTasks[plot.name] ??
                    taskQueue
                        .where((t) => t.bedName == plot.name)
                        .toList(growable: false);
                final rotation =
                    _cachedPlotRotations[plot.name] ??
                    widget.gardenController.evaluatePlotRotation(
                      plot.name,
                      referenceTime: widget.selectedDate,
                    );
                final successionPlan =
                    _cachedPlotSuccessions[plot.name] ??
                    widget.gardenController.buildPlotSuccessionPlan(
                      plot.name,
                      referenceTime: widget.selectedDate,
                    );
                final isSelected = _selectedBedFilter == plot.name;
                final prepDays = plot.daysSinceSoilPrepAt(widget.selectedDate);
                final nextOrganColor = GoetheanPalette.getColor(
                  rotation.recommendedNextQuality,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    key: ValueKey('garden_plot_card_${plot.name}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        _selectedBedFilter = isSelected ? null : plot.name;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? GoetheanPalette.aspectGold.withValues(alpha: 0.14)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? GoetheanPalette.aspectGold
                              : Colors.white.withValues(alpha: 0.15),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${plot.plotType.glyph} ${plot.displayTitle}'
                                  '${plot.dimensions.isNotEmpty ? " • ${plot.dimensions}" : ""}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFF6ECD8),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: nextOrganColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: nextOrganColor.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  plotActive.isEmpty
                                      ? 'Fallow • Next: ${rotation.recommendedNextQuality.displayName}'
                                      : '${plotActive.length} Active • Next: ${rotation.recommendedNextQuality.displayName}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                key: ValueKey('edit_plot_${plot.name}'),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                tooltip: 'Edit plot details',
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 15,
                                  color: Colors.white70,
                                ),
                                onPressed: () => _showUpsertPlotDialog(plot),
                              ),
                            ],
                          ),
                          if (plot.notes.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              plot.notes,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                          if (successionPlan
                              .seasonPipelineSummary
                              .isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              'Season Pipeline: ${successionPlan.seasonPipelineSummary}',
                              key: ValueKey(
                                'plot_season_pipeline_${plot.name}',
                              ),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFF3E5C8),
                              ),
                            ),
                          ],
                          if (plotActive.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: plotActive
                                  .map(
                                    (b) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: GoetheanPalette.getColor(
                                          b.quality,
                                        ).withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${b.action.timelineGlyph} ${b.crop?.nameEn ?? b.title} (${b.daysElapsedAt(widget.selectedDate)}d)',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ],
                          if (plotTasks.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            for (final task in plotTasks)
                              Text(
                                '📋 Planned: ${task.summaryLabel}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: const Color(0xFF6EE7B7),
                                ),
                              ),
                          ],
                          if (successionPlan.candidates.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Column(
                              key: ValueKey(
                                'plot_succession_suggestions_${plot.name}',
                              ),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SUCCESSION & RELAY SUGGESTIONS (TAP TO QUEUE):',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.7,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: successionPlan.candidates
                                      .take(4)
                                      .map((cand) {
                                        final isQueued = widget
                                            .gardenController
                                            .value
                                            .isTaskQueued(
                                              action: cand.taskAction,
                                              cropId: cand.crop.id,
                                              targetQuality: cand.crop.quality,
                                              bedName: plot.name,
                                            );
                                        return ActionChip(
                                          key: ValueKey(
                                            'plot_succession_chip_${plot.name}_${cand.crop.id}',
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: isQueued
                                              ? const Color(0xFF10B981)
                                                    .withValues(alpha: 0.24)
                                              : Colors.white.withValues(
                                                  alpha: 0.06,
                                                ),
                                          side: BorderSide(
                                            color: isQueued
                                                ? const Color(0xFF10B981)
                                                : GoetheanPalette.getColor(
                                                    cand.crop.quality,
                                                  ).withValues(alpha: 0.45),
                                          ),
                                          label: Text(
                                            '${isQueued ? "✓ " : ""}${cand.badgeLabel}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 10.5,
                                              fontWeight: isQueued
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isQueued
                                                  ? const Color(0xFF6EE7B7)
                                                  : Colors.white,
                                            ),
                                          ),
                                          onPressed: () {
                                            widget.gardenController
                                                .toggleQueuedTask(
                                                  action: cand.taskAction,
                                                  cropId: cand.crop.id,
                                                  targetQuality:
                                                      cand.crop.quality,
                                                  bedName: plot.name,
                                                  note: cand.reason,
                                                );
                                          },
                                        );
                                      })
                                      .toList(growable: false),
                                ),
                              ],
                            ),
                          ],
                          if (plot.lastSoilPrepSummary != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '🌀 Last Soil Prep: ${plot.lastSoilPrepSummary}'
                              '${prepDays != null && prepDays >= 0 ? " (${prepDays}d ago)" : ""}',
                              key: ValueKey('plot_soil_prep_${plot.name}'),
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                color: const Color(0xFFF3E5C8),
                              ),
                            ),
                          ],
                          if (rotation.seasonTrail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Rotation: ${rotation.seasonTrail.join(" → ")}',
                              key: ValueKey('plot_rotation_trail_${plot.name}'),
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                color: GoetheanPalette.aspectGold,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              OutlinedButton.icon(
                                key: ValueKey('plot_quick_log_${plot.name}'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: nextOrganColor.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: const Size(56, 28),
                                ),
                                onPressed: () {
                                  FieldJournalSheet.show(
                                    context,
                                    gardenController: widget.gardenController,
                                    timestamp: widget.selectedDate,
                                    calendarInfo: widget.info,
                                    weatherSeries:
                                        widget.weatherNotifier?.value,
                                    initialAction: FieldJournalAction.sowSeeds,
                                    initialQuality:
                                        rotation.recommendedNextQuality,
                                    initialBedName: plot.name,
                                  );
                                },
                                icon: const Icon(
                                  Icons.grass_outlined,
                                  size: 13,
                                ),
                                label: Text(
                                  '+ Sow in Plot',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                key: ValueKey('plot_quick_prep_${plot.name}'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFF6ECD8),
                                  side: BorderSide(
                                    color: GoetheanPalette.aspectGold
                                        .withValues(alpha: 0.45),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: const Size(56, 28),
                                ),
                                onPressed: () {
                                  FieldJournalSheet.show(
                                    context,
                                    gardenController: widget.gardenController,
                                    timestamp: widget.selectedDate,
                                    calendarInfo: widget.info,
                                    weatherSeries:
                                        widget.weatherNotifier?.value,
                                    initialAction:
                                        FieldJournalAction.sprayPreparation,
                                    initialBedName: plot.name,
                                  );
                                },
                                icon: const Icon(
                                  Icons.cyclone_outlined,
                                  size: 13,
                                ),
                                label: Text(
                                  '🌀 Prep / BD 500',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                key: ValueKey('plot_share_${plot.name}'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: const Size(56, 28),
                                ),
                                onPressed: () {
                                  final plotEntries = widget
                                      .gardenController
                                      .value
                                      .journalEntries
                                      .where(
                                        (e) =>
                                            e.bedName?.trim().toLowerCase() ==
                                            plot.name.trim().toLowerCase(),
                                      );
                                  final summary =
                                      GardenNoteShareFormatter.formatPlotSummary(
                                        plot: plot,
                                        rotation: rotation,
                                        successionPlan: successionPlan,
                                        recentEntries: plotEntries,
                                      );
                                  _shareOrCopyText(
                                    summary,
                                    label: 'Plot "${plot.name}" summary',
                                  );
                                },
                                icon: const Icon(
                                  Icons.share_outlined,
                                  size: 13,
                                ),
                                label: Text(
                                  'Share Plot',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
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
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActivePlantingsSection(
    BuildContext context,
    List<PlantingBatchSummary> activeBatches,
  ) {
    return OrganicVesselContainer.inset(
      key: const ValueKey('field_journal_active_plantings_section'),
      accentColor: GoetheanPalette.leafWater,
      seed: 4.1,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.grass_outlined,
                size: 16,
                color: GoetheanPalette.leafWater,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ACTIVE IN THE GROUND (${activeBatches.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: GoetheanPalette.aspectGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final batch in activeBatches.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                key: ValueKey('active_batch_tile_${batch.entryId}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: GoetheanPalette.getColor(batch.quality)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${batch.action.timelineGlyph} ${batch.title}'
                            '${batch.bedName != null ? " • 📍 ${batch.bedName}" : ""}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${batch.daysElapsedAt(widget.selectedDate) >= 0 ? "${batch.daysElapsedAt(widget.selectedDate)}d in ground" : batch.shardKey}'
                            ' • ${batch.cosmicSummary}',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: const Color(0xFFF6ECD8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      key: ValueKey('active_batch_observe_${batch.entryId}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(52, 26),
                      ),
                      onPressed: () {
                        FieldJournalSheet.show(
                          context,
                          gardenController: widget.gardenController,
                          timestamp: widget.selectedDate,
                          calendarInfo: widget.info,
                          weatherSeries: widget.weatherNotifier?.value,
                          initialAction: FieldJournalAction.observation,
                          initialCrop: batch.crop,
                          initialQuality: batch.quality,
                          initialBedName: batch.bedName,
                          initialParentEntryId: batch.entryId,
                        );
                      },
                      child: Text(
                        '+ Observe',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      key: ValueKey('active_batch_harvest_${batch.entryId}'),
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
                        minimumSize: const Size(56, 26),
                      ),
                      onPressed: () {
                        FieldJournalSheet.show(
                          context,
                          gardenController: widget.gardenController,
                          timestamp: widget.selectedDate,
                          calendarInfo: widget.info,
                          weatherSeries: widget.weatherNotifier?.value,
                          initialAction: FieldJournalAction.harvestFresh,
                          initialCrop: batch.crop,
                          initialQuality: batch.quality,
                          initialBedName: batch.bedName,
                          initialParentEntryId: batch.entryId,
                        );
                      },
                      child: Text(
                        '🧺 Harvest',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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

  Widget _buildEntryTile(
    BuildContext context,
    FieldJournalEntry entry,
    List<FieldJournalEntry> allEntries,
  ) {
    final entryColor = entry.quality == PlantQuality.none
        ? GoetheanPalette.aspectGold
        : GoetheanPalette.getColor(entry.quality);
    final dateFmt = _entryDateFmt;
    final linkedParent = entry.parentEntryId == null
        ? null
        : (_cachedBatchesByEntryId[entry.parentEntryId!] ??
              widget.gardenController.findPlantingBatch(entry.parentEntryId));
    final childEntries =
        _cachedChildrenByParentId[entry.id] ?? const <FieldJournalEntry>[];
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
                    if (entry.activeAttachments.isNotEmpty)
                      _buildSnapshotPill(
                        '📷 ${entry.activeAttachments.length}',
                        GoetheanPalette.aspectGold,
                      ),
                  ],
                ),

                if (entry.activeAttachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: entry.activeAttachments.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final att = entry.activeAttachments[idx];
                        return InkWell(
                          key: ValueKey('journal_attachment_thumb_${att.id}'),
                          onTap: () => _showPhotoViewerDialog(entry, att),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 84,
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: entryColor.withValues(alpha: 0.45),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (att.thumbnailBytes != null)
                                  Image.memory(
                                    att.thumbnailBytes!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(
                                        Icons.photo_camera_back_outlined,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                    ),
                                  )
                                else
                                  const Center(
                                    child: Icon(
                                      Icons.photo_camera_back_outlined,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                  ),
                                if (att.caption.isNotEmpty)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1.5,
                                      ),
                                      color: Colors.black.withValues(
                                        alpha: 0.65,
                                      ),
                                      child: Text(
                                        att.caption,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 9,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                if (childEntries.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    key: ValueKey('journal_lifecycle_trail_${entry.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: entryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      [
                        '${entry.action.timelineGlyph} ${entry.action.shortLabel}',
                        for (final child in childEntries)
                          '${child.action.timelineGlyph} ${child.action.shortLabel} (${_shortDateFmt.format(child.timestamp)})',
                      ].join(' → '),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF6ECD8),
                      ),
                    ),
                  ),
                ],

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
                    IconButton(
                      key: ValueKey('journal_entry_share_${entry.id}'),
                      tooltip: 'Share Note',
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(
                        Icons.share_outlined,
                        size: 15,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        final formatted = GardenNoteShareFormatter.formatEntry(
                          entry,
                          gardenName: widget.gardenController.gardenName,
                        );
                        _shareOrCopyText(
                          formatted,
                          label: 'Note "${entry.title}"',
                        );
                      },
                    ),
                    const SizedBox(width: 4),
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
