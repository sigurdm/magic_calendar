import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../core/vegetable_database.dart';
import '../../services/garden_service.dart';
import '../theme/goethean_palette.dart';
import 'organic_vessel_container.dart';

/// A raw photo and optional thumbnail/caption selected in [FieldJournalSheet].
final class PickedJournalPhoto {
  /// Full-resolution image bytes (PNG, JPEG, or WebP).
  final Uint8List fullBytes;

  /// Optional compact thumbnail bytes (`<= 64 KB`).
  final Uint8List? thumbnailBytes;

  /// Optional caption describing the photo.
  final String caption;

  /// Optional width in pixels.
  final int? width;

  /// Optional height in pixels.
  final int? height;

  /// Creates a [PickedJournalPhoto].
  const PickedJournalPhoto({
    required this.fullBytes,
    this.thumbnailBytes,
    this.caption = '',
    this.width,
    this.height,
  });
}

/// Modal bottom sheet for logging a new comparative biodynamic field action or
/// recording follow-up collaborative notes and trial outcomes on an existing
/// [FieldJournalEntry].
final class FieldJournalSheet extends StatefulWidget {
  /// Controller persisting the user's [GardenProfile] and monthly SQLite journal shards.
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

  /// Optional initial garden bed or plot name.
  final String? initialBedName;

  /// Optional initial parent planting batch entry ID for observations or harvests.
  final String? initialParentEntryId;

  /// Existing entry when editing or recording a comparative outcome / follow-up note.
  final FieldJournalEntry? existingEntry;

  /// Optional custom photo picker callback (for mobile camera/gallery plugins or tests).
  final Future<PickedJournalPhoto?> Function(BuildContext context)? onPickPhoto;

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
    this.initialBedName,
    this.initialParentEntryId,
    this.existingEntry,
    this.onPickPhoto,
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
    String? initialBedName,
    String? initialParentEntryId,
    FieldJournalEntry? existingEntry,
    Future<PickedJournalPhoto?> Function(BuildContext context)? onPickPhoto,
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
        initialBedName: existingEntry?.bedName ?? initialBedName,
        initialParentEntryId:
            existingEntry?.parentEntryId ?? initialParentEntryId,
        existingEntry: existingEntry,
        onPickPhoto: onPickPhoto,
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
  String? _parentEntryId;
  late PlantQuality _quality;
  late final TextEditingController _titleController;
  late final TextEditingController _bedController;
  late final TextEditingController _notesController;
  late final TextEditingController _outcomeController;
  late final TextEditingController _cropSearchController;
  String _cropSearchQuery = '';
  int? _outcomeRating;
  bool _titleManuallyEdited = false;
  final List<PickedJournalPhoto> _stagedPhotos = <PickedJournalPhoto>[];
  String? _photoErrorMessage;

  @override
  void initState() {
    super.initState();
    _action = widget.initialAction;
    _crop = widget.initialCrop;
    _prepCode = widget.initialPrepCode;
    _parentEntryId =
        widget.existingEntry?.parentEntryId ?? widget.initialParentEntryId;
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
    _bedController = TextEditingController(
      text: widget.existingEntry?.bedName ?? widget.initialBedName ?? '',
    );
    _notesController = TextEditingController(text: widget.initialNotes);
    _outcomeController = TextEditingController(
      text: widget.existingEntry?.outcomeNote ?? '',
    );
    _cropSearchController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bedController.dispose();
    _notesController.dispose();
    _outcomeController.dispose();
    _cropSearchController.dispose();
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

  Future<void> _handleAttachPhoto() async {
    setState(() {
      _photoErrorMessage = null;
    });
    try {
      final PickedJournalPhoto? picked;
      if (widget.onPickPhoto != null) {
        picked = await widget.onPickPhoto!(context);
      } else {
        picked = await _promptForLocalPhotoFile();
      }
      if (picked == null) return;
      // Validate format and 10 MB limit immediately.
      if (picked.fullBytes.isEmpty ||
          picked.fullBytes.length > JournalAttachment.maxPhotoBytes) {
        setState(() {
          _photoErrorMessage = 'Photo must be non-empty and at most 10 MB.';
        });
        return;
      }
      JournalImageFormat.detect(picked.fullBytes);
      Uint8List? thumbBytes = picked.thumbnailBytes;
      if (thumbBytes == null &&
          picked.fullBytes.length > JournalAttachment.maxInlineThumbnailBytes) {
        thumbBytes = await _downscalePhotoThumbnail(picked.fullBytes);
      }
      if (!mounted) return;
      setState(() {
        _stagedPhotos.add(
          PickedJournalPhoto(
            fullBytes: picked!.fullBytes,
            thumbnailBytes: thumbBytes ?? picked.thumbnailBytes,
            caption: picked.caption,
            width: picked.width,
            height: picked.height,
          ),
        );
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _photoErrorMessage = e.message;
      });
    }
  }

  Future<Uint8List?> _downscalePhotoThumbnail(Uint8List fullBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(fullBytes, targetWidth: 200);
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      frame.image.dispose();
      codec.dispose();
      if (byteData == null) return null;
      final encoded = byteData.buffer.asUint8List();
      if (encoded.length <= JournalAttachment.maxInlineThumbnailBytes) {
        return encoded;
      }
    } catch (_) {
      // Fallback to null if codec downscaling is unavailable.
    }
    return null;
  }

  Future<PickedJournalPhoto?> _promptForLocalPhotoFile() async {
    final pathCtrl = TextEditingController();
    final captionCtrl = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1F1A14),
          title: Text(
            'Attach Garden Photo',
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
                key: const ValueKey('journal_photo_path_input'),
                controller: pathCtrl,
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Image File Path (.jpg, .png, .webp)',
                  hintText: '/path/to/photo.jpg',
                  labelStyle: GoogleFonts.outfit(color: Colors.white70),
                  hintStyle: GoogleFonts.outfit(color: Colors.white38),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('journal_photo_caption_input'),
                controller: captionCtrl,
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Caption (Optional)',
                  hintText: 'e.g. First true leaves in Bed 2',
                  labelStyle: GoogleFonts.outfit(color: Colors.white70),
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
              key: const ValueKey('journal_photo_dialog_confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Attach'),
            ),
          ],
        ),
      );
      if (confirmed != true || pathCtrl.text.trim().isEmpty) return null;
      final file = File(pathCtrl.text.trim());
      if (!await file.exists()) {
        throw const FormatException('Selected image file does not exist');
      }
      final bytes = await file.readAsBytes();
      return PickedJournalPhoto(
        fullBytes: bytes,
        caption: captionCtrl.text.trim(),
      );
    } finally {
      pathCtrl.dispose();
      captionCtrl.dispose();
    }
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
    final rawBed = _bedController.text.trim();
    final entryId =
        existing?.id ??
        'journal_${widget.timestamp.millisecondsSinceEpoch}_${_action.name}_${_crop?.id ?? _prepCode ?? _quality.name}';
    final authorId = existing?.authorId ?? widget.gardenController.localActorId;
    final authorName =
        existing?.authorName ?? widget.gardenController.localAuthorName;

    final mergedAttachments = <JournalAttachment>[
      ...(existing?.attachments ?? const <JournalAttachment>[]),
    ];
    final fullBytesByAttachmentId = <String, Uint8List>{};
    for (int i = 0; i < _stagedPhotos.length; i++) {
      final staged = _stagedPhotos[i];
      final attachment = JournalAttachment.fromRawBytes(
        entryId: entryId,
        fullBytes: staged.fullBytes,
        thumbnailBytes: staged.thumbnailBytes,
        width: staged.width,
        height: staged.height,
        caption: staged.caption,
        authorId: widget.gardenController.localActorId,
        authorName: widget.gardenController.localAuthorName,
        timestamp: DateTime.now().add(Duration(microseconds: i)),
      );
      mergedAttachments.add(attachment);
      fullBytesByAttachmentId[attachment.id] = staged.fullBytes;
    }

    final entry = FieldJournalEntry(
      id: entryId,
      timestamp: widget.timestamp,
      action: _action,
      title: resolvedTitle,
      cropId: _crop?.id,
      prepCode: _prepCode,
      bedName: rawBed.isEmpty ? null : rawBed,
      parentEntryId: _parentEntryId,
      quality: _quality,
      authorId: authorId,
      authorName: authorName,
      cosmicSnapshot: cosmicSnapshot,
      weatherSnapshot: weatherSnapshot,
      location:
          existing?.location ?? widget.gardenController.value.activeLocation,
      notes: _notesController.text.trim(),
      outcomeNote: _outcomeController.text.trim(),
      outcomeRating: _outcomeRating,
      noteThread: existing?.noteThread ?? const [],
      attachments: mergedAttachments,
    );

    await widget.gardenController.addJournalEntry(
      entry,
      fullMediaBytesByAttachmentId: fullBytesByAttachmentId.isEmpty
          ? null
          : fullBytesByAttachmentId,
    );
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
    final knownBeds = widget.gardenController.listBedNames();
    final candidateBatches = widget.gardenController
        .listPlantingBatches(cropId: _crop?.id)
        .where((b) => b.entryId != widget.existingEntry?.id)
        .take(6)
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
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
                            '${dateFmt.format(widget.timestamp)} • ${widget.gardenController.localAuthorName}',
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

                        // Target Organ / Element Quality Selector
                        Text(
                          'TARGET ORGAN QUALITY',
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
                              const [
                                    PlantQuality.root,
                                    PlantQuality.leaf,
                                    PlantQuality.flower,
                                    PlantQuality.fruit,
                                  ]
                                  .map((q) {
                                    final selected = _quality == q;
                                    final qColor = GoetheanPalette.getColor(q);
                                    return ChoiceChip(
                                      key: ValueKey(
                                        'journal_sheet_quality_${q.name}',
                                      ),
                                      label: Text(
                                        q.displayName,
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
                                      selectedColor: qColor.withValues(
                                        alpha: 0.35,
                                      ),
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      side: BorderSide(
                                        color: selected
                                            ? qColor
                                            : Colors.white.withValues(
                                                alpha: 0.14,
                                              ),
                                      ),
                                      showCheckmark: false,
                                      onSelected: (_) {
                                        setState(() {
                                          _quality = q;
                                          _syncAutoTitle();
                                        });
                                      },
                                    );
                                  })
                                  .toList(growable: false),
                        ),
                        const SizedBox(height: 12),

                        // Crop / Plant Selector
                        if (_action.supportsCropSelection) ...[
                          Text(
                            'CROP / PLANT (OPTIONAL)',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            key: const ValueKey(
                              'field_journal_crop_search_input',
                            ),
                            controller: _cropSearchController,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _cropSearchQuery = val;
                              });
                            },
                            decoration: _inputDecoration(
                              hint:
                                  'Search crop (e.g. Carrot, Tomato, Kale)...',
                              accentColor: accentColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ChoiceChip(
                                key: const ValueKey('journal_sheet_crop_none'),
                                label: Text(
                                  'General / None',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: _crop == null
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: _crop == null
                                        ? Colors.white
                                        : Colors.white70,
                                  ),
                                ),
                                selected: _crop == null,
                                selectedColor: accentColor.withValues(
                                  alpha: 0.28,
                                ),
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.05,
                                ),
                                showCheckmark: false,
                                onSelected: (_) {
                                  setState(() {
                                    _crop = null;
                                    _syncAutoTitle();
                                  });
                                },
                              ),
                              for (final candidate in _candidateCrops())
                                ChoiceChip(
                                  key: ValueKey(
                                    'journal_sheet_crop_${candidate.id}',
                                  ),
                                  label: Text(
                                    candidate.localizedDisplayName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: _crop?.id == candidate.id
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: _crop?.id == candidate.id
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                  ),
                                  selected: _crop?.id == candidate.id,
                                  selectedColor: GoetheanPalette.getColor(
                                    candidate.quality,
                                  ).withValues(alpha: 0.35),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.05,
                                  ),
                                  showCheckmark: false,
                                  onSelected: (_) {
                                    setState(() {
                                      _crop = _crop?.id == candidate.id
                                          ? null
                                          : candidate;
                                      if (_crop != null) {
                                        _quality = _crop!.quality;
                                      }
                                      _syncAutoTitle();
                                    });
                                  },
                                ),
                            ],
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

                        // Garden Bed / Plot Tag
                        Text(
                          'GARDEN BED / PLOT (SHARED ACROSS GARDEN)',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (knownBeds.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: knownBeds
                                .map((bed) {
                                  final selected =
                                      _bedController.text.trim() == bed;
                                  final plotMeta = widget.gardenController
                                      .findPlot(bed);
                                  final chipText = plotMeta != null
                                      ? plotMeta.badgeLabel
                                      : bed;
                                  return ActionChip(
                                    key: ValueKey('journal_sheet_bed_$bed'),
                                    label: Text(
                                      chipText,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: selected
                                            ? GoetheanPalette.aspectGold
                                            : Colors.white70,
                                      ),
                                    ),
                                    backgroundColor: selected
                                        ? GoetheanPalette.aspectGold.withValues(
                                            alpha: 0.2,
                                          )
                                        : Colors.white.withValues(alpha: 0.05),
                                    onPressed: () {
                                      setState(() {
                                        _bedController.text = selected
                                            ? ''
                                            : bed;
                                      });
                                    },
                                  );
                                })
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 6),
                        ],
                        TextField(
                          key: const ValueKey('field_journal_bed_input'),
                          controller: _bedController,
                          onChanged: (_) {
                            setState(() {});
                          },
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: Colors.white,
                          ),
                          decoration: _inputDecoration(
                            hint: 'e.g. Bed 2, South Greenhouse, Orchard Row A',
                            accentColor: accentColor,
                          ),
                        ),
                        if (_bedController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final plotName = _bedController.text.trim();
                              final plotMeta = widget.gardenController.findPlot(
                                plotName,
                              );
                              final rotation = widget.gardenController
                                  .evaluatePlotRotation(
                                    plotName,
                                    candidateCrop: _crop,
                                    referenceTime: widget.timestamp,
                                  );
                              final hasWarning = rotation.hasFamilyConflict;
                              final bannerColor = hasWarning
                                  ? const Color(0xFFF59E0B)
                                  : GoetheanPalette.leafWater;
                              return Container(
                                key: const ValueKey(
                                  'field_journal_rotation_banner',
                                ),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: bannerColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: bannerColor.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          hasWarning
                                              ? Icons.warning_amber_rounded
                                              : Icons.autorenew_rounded,
                                          size: 15,
                                          color: bannerColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            plotMeta != null
                                                ? '${plotMeta.badgeLabel} (${plotMeta.plotType.displayName})'
                                                      '${plotMeta.dimensions.isNotEmpty ? " • ${plotMeta.dimensions}" : ""}'
                                                : 'Plot Rotation & Soil Memory • $plotName',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFFF6ECD8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (rotation.conflictWarning != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        rotation.conflictWarning!,
                                        key: const ValueKey(
                                          'field_journal_rotation_warning',
                                        ),
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFFCD34D),
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      rotation.rotationGuidance,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: Colors.white70,
                                        height: 1.3,
                                      ),
                                    ),
                                    if (rotation.seasonTrail.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'History: ${rotation.seasonTrail.join(" → ")}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          color: GoetheanPalette.aspectGold,
                                        ),
                                      ),
                                    ],
                                    if (_action.isHarvestAction) ...[
                                      const SizedBox(height: 6),
                                      Builder(
                                        builder: (context) {
                                          final plan = widget.gardenController
                                              .buildPlotSuccessionPlan(
                                                plotName,
                                                referenceTime: widget.timestamp,
                                              );
                                          if (plan.candidates.isEmpty) {
                                            return const SizedBox.shrink();
                                          }
                                          return Column(
                                            key: const ValueKey(
                                              'harvest_succession_strip',
                                            ),
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'QUEUE NEXT SUCCESSION CROP FOR ${plotName.toUpperCase()}:',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: GoetheanPalette
                                                      .aspectGold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: plan.candidates
                                                    .take(3)
                                                    .map((cand) {
                                                      return ActionChip(
                                                        key: ValueKey(
                                                          'harvest_succession_chip_${cand.crop.id}',
                                                        ),
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        backgroundColor: Colors
                                                            .white
                                                            .withValues(
                                                              alpha: 0.08,
                                                            ),
                                                        label: Text(
                                                          cand.badgeLabel,
                                                          style:
                                                              GoogleFonts.outfit(
                                                                fontSize: 10.5,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        ),
                                                        onPressed: () {
                                                          widget
                                                              .gardenController
                                                              .toggleQueuedTask(
                                                                action: cand
                                                                    .taskAction,
                                                                cropId: cand
                                                                    .crop
                                                                    .id,
                                                                targetQuality:
                                                                    cand
                                                                        .crop
                                                                        .quality,
                                                                bedName:
                                                                    plotName,
                                                                note:
                                                                    cand.reason,
                                                              );
                                                          setState(() {});
                                                        },
                                                      );
                                                    })
                                                    .toList(growable: false),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Seed-to-Harvest Lifecycle Link
                        if (candidateBatches.isNotEmpty) ...[
                          Text(
                            'LINK TO EARLIER SOWING / PLANTING BATCH (OPTIONAL)',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                              color: GoetheanPalette.aspectGold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: candidateBatches
                                .map((batch) {
                                  final isLinked =
                                      _parentEntryId == batch.entryId;
                                  final days = batch.daysElapsedAt(
                                    widget.timestamp,
                                  );
                                  return ChoiceChip(
                                    key: ValueKey(
                                      'journal_sheet_parent_${batch.entryId}',
                                    ),
                                    label: Text(
                                      '${batch.action.timelineGlyph} ${batch.title}'
                                      '${batch.bedName != null ? " (${batch.bedName})" : ""}'
                                      ' • ${days >= 0 ? "${days}d ago" : batch.shardKey}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: isLinked
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: isLinked
                                            ? Colors.white
                                            : Colors.white70,
                                      ),
                                    ),
                                    selected: isLinked,
                                    selectedColor: GoetheanPalette.aspectGold
                                        .withValues(alpha: 0.28),
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.05,
                                    ),
                                    showCheckmark: false,
                                    onSelected: (_) {
                                      setState(() {
                                        _parentEntryId = isLinked
                                            ? null
                                            : batch.entryId;
                                        if (_parentEntryId != null &&
                                            _bedController.text
                                                .trim()
                                                .isEmpty &&
                                            batch.bedName != null) {
                                          _bedController.text = batch.bedName!;
                                        }
                                      });
                                    },
                                  );
                                })
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Field Notes
                        Text(
                          'FIELD NOTES (BED, CULTIVAR, SEED LOT, OBSERVATIONS)',
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
                        const SizedBox(height: 12),

                        // Photo Attachments Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'GARDEN PHOTOS (THUMBNAIL + CLOUD MEDIA)',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.9,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              key: const ValueKey(
                                'field_journal_attach_photo_button',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: GoetheanPalette.aspectGold,
                                side: BorderSide(
                                  color: GoetheanPalette.aspectGold.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                minimumSize: const Size(64, 30),
                              ),
                              onPressed: _handleAttachPhoto,
                              icon: const Icon(
                                Icons.add_a_photo_outlined,
                                size: 15,
                                color: GoetheanPalette.aspectGold,
                              ),
                              label: Text(
                                'Attach Photo',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_photoErrorMessage != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _photoErrorMessage!,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                        if ((widget
                                    .existingEntry
                                    ?.activeAttachments
                                    .isNotEmpty ??
                                false) ||
                            _stagedPhotos.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 68,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final existingAtt
                                    in widget
                                            .existingEntry
                                            ?.activeAttachments ??
                                        const <JournalAttachment>[])
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _buildStagedPhotoPreview(
                                      bytes: existingAtt.thumbnailBytes,
                                      caption: existingAtt.caption,
                                      accentColor: accentColor,
                                    ),
                                  ),
                                for (int i = 0; i < _stagedPhotos.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _buildStagedPhotoPreview(
                                      key: ValueKey('staged_photo_preview_$i'),
                                      bytes:
                                          _stagedPhotos[i].thumbnailBytes ??
                                          _stagedPhotos[i].fullBytes,
                                      caption: _stagedPhotos[i].caption,
                                      accentColor: accentColor,
                                      onRemove: () {
                                        setState(() {
                                          _stagedPhotos.removeAt(i);
                                        });
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
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

  List<VegetableEntry> _candidateCrops() {
    final starredIds = widget.gardenController.value.starredCropIds;
    final seen = <String>{};
    final results = <VegetableEntry>[];

    void addUnique(VegetableEntry? v) {
      if (v != null && seen.add(v.id)) {
        results.add(v);
      }
    }

    addUnique(_crop);
    if (_cropSearchQuery.trim().isNotEmpty) {
      for (final match in VegetableDatabase.search(_cropSearchQuery).take(10)) {
        addUnique(match);
      }
      return results;
    }

    for (final id in starredIds) {
      addUnique(VegetableDatabase.findById(id));
    }
    for (final v in VegetableDatabase.getVegetablesForQuality(
      _quality,
    ).take(8)) {
      addUnique(v);
      if (results.length >= 10) break;
    }
    return results;
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

  Widget _buildStagedPhotoPreview({
    Key? key,
    required Uint8List? bytes,
    required String caption,
    required Color accentColor,
    VoidCallback? onRemove,
  }) {
    return Container(
      key: key,
      width: 96,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bytes != null)
            Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  Icons.photo_outlined,
                  color: Colors.white70,
                  size: 22,
                ),
              ),
            )
          else
            const Center(
              child: Icon(
                Icons.photo_outlined,
                color: Colors.white70,
                size: 22,
              ),
            ),
          if (caption.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                color: Colors.black.withValues(alpha: 0.65),
                child: Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 9.5, color: Colors.white),
                ),
              ),
            ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: InkWell(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 13, color: Colors.white),
                ),
              ),
            ),
        ],
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
