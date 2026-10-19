import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/garden/garden.dart';
import '../core/models/models.dart';
import '../core/task_window_planner.dart';
import '../core/vegetable_database.dart';
import 'journal_sqlite_store.dart';
import 'journal_sync_service.dart';

export '../core/garden/garden.dart';
export 'garden_profile_store_stub.dart'
    if (dart.library.io) 'garden_profile_store_io.dart';
export 'journal_sqlite_store.dart';
export 'journal_sync_service.dart';

/// Persistent or in-memory store for the user's [GardenProfile].
abstract interface class GardenProfileStore {
  /// Reads the stored [GardenProfile], or returns `null` if absent or unreadable.
  Future<GardenProfile?> read();

  /// Persists [profile].
  Future<void> write(GardenProfile profile);
}

/// In-memory implementation of [GardenProfileStore] for tests and fallback environments.
final class MemoryGardenProfileStore implements GardenProfileStore {
  GardenProfile? _stored;

  /// Creates an in-memory store optionally seeded with [initialProfile].
  MemoryGardenProfileStore([this._stored]);

  /// Currently stored profile snapshot in memory.
  GardenProfile? get current => _stored;

  @override
  Future<GardenProfile?> read() async => _stored;

  @override
  Future<void> write(GardenProfile profile) async {
    _stored = profile;
  }
}

/// Reactive controller managing the user's [GardenProfile], monthly SQLite
/// journal shards ([journalStore]), and optional cloud sync ([syncTransport]).
final class GardenProfileController extends ValueNotifier<GardenProfile> {
  /// Optional backing store for persisting lightweight profile settings.
  final GardenProfileStore? store;

  /// Optional monthly SQLite-sharded journal store for partial loading and CRDT sync.
  final ShardedSqliteJournalStore? journalStore;

  GardenSyncTransport? _syncTransport;
  GardenSyncReport? _lastSyncReport;
  bool _isSyncing = false;
  DateTime? _loadedWindowStart;
  DateTime? _loadedWindowEnd;

  /// Creates a [GardenProfileController] initialized with [initialProfile].
  GardenProfileController({
    GardenProfile? initialProfile,
    this.store,
    this.journalStore,
    GardenSyncTransport? syncTransport,
  }) : super(initialProfile ?? GardenProfile()) {
    _syncTransport = syncTransport;
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      // Seed any entries or queued tasks passed in initialProfile into SQLite shards, then load initial window.
      if (initialProfile != null) {
        for (final task in initialProfile.taskQueue) {
          sqlStore.upsertQueuedTask(task);
        }
        for (final entry in initialProfile.journalEntries) {
          sqlStore.upsertEntry(entry);
        }
      }
      _refreshEntriesFromSqlite();
    }
  }

  /// Active cloud or shared-folder sync transport, if configured.
  GardenSyncTransport? get syncTransport => _syncTransport;

  /// Report from the most recent [syncJournal] pass, if any.
  GardenSyncReport? get lastSyncReport => _lastSyncReport;

  /// Whether a cloud or shared-folder sync is currently in progress.
  bool get isSyncing => _isSyncing;

  /// Display name of the local gardener (from [journalStore] if backed by SQLite).
  String get localAuthorName => journalStore?.localAuthorName ?? 'Gardener';

  /// Unique actor ID of the local gardener.
  String get localActorId => journalStore?.localActorId ?? 'local';

  /// Display name of the shared garden.
  String get gardenName =>
      journalStore?.gardenName ?? 'Shared Biodynamic Garden';

  /// Loads the persisted [GardenProfile] from [store] and initializes windowed
  /// journal entries from [journalStore], falling back to [fallback] if absent.
  static Future<GardenProfileController> load({
    GardenProfileStore? store,
    ShardedSqliteJournalStore? journalStore,
    GardenSyncTransport? syncTransport,
    GardenProfile? fallback,
  }) async {
    GardenProfile? loaded;
    if (store != null) {
      try {
        loaded = await store.read();
      } catch (_) {
        loaded = null;
      }
    }
    return GardenProfileController(
      initialProfile: loaded ?? fallback ?? GardenProfile(),
      store: store,
      journalStore: journalStore,
      syncTransport: syncTransport,
    );
  }

  void _refreshEntriesFromSqlite({DateTime? windowStart, DateTime? windowEnd}) {
    final sqlStore = journalStore;
    if (sqlStore == null || sqlStore.isClosed) return;

    final now = DateTime.now();
    final effectiveStart =
        windowStart ??
        _loadedWindowStart ??
        now.subtract(const Duration(days: 90));
    final effectiveEnd =
        windowEnd ?? _loadedWindowEnd ?? now.add(const Duration(days: 90));
    _loadedWindowStart = effectiveStart;
    _loadedWindowEnd = effectiveEnd;

    final windowed = sqlStore.loadRange(effectiveStart, effectiveEnd);
    final recent = sqlStore.loadRecentPage(limit: 40);
    final mergedById = <String, FieldJournalEntry>{
      for (final e in windowed) e.id: e,
      for (final e in recent) e.id: e,
    };
    final syncedQueue = sqlStore.listQueuedTasks();
    value = GardenProfile(
      activeLocation: value.activeLocation,
      savedLocations: value.savedLocations,
      starredCropIds: value.starredCropIds,
      taskQueue: syncedQueue,
      journalEntries: mergedById.values,
    );
  }

  /// Ensures monthly SQLite shards overlapping `[start, end]` are loaded into
  /// the active memory window (and lazily hydrated from [syncTransport] if needed).
  Future<void> ensureWindowLoaded(DateTime start, DateTime end) async {
    final sqlStore = journalStore;
    if (sqlStore == null || sqlStore.isClosed) return;

    final minTime = start.isBefore(end) ? start : end;
    final maxTime = start.isBefore(end) ? end : start;

    final transport = _syncTransport;
    if (transport != null) {
      final unhydrated = sqlStore.listUnhydratedRemoteShardKeys().toSet();
      if (unhydrated.isNotEmpty) {
        final neededKeys = ShardedSqliteJournalStore.shardKeysInRange(
          minTime,
          maxTime,
        );
        final engine = GardenSyncEngine(store: sqlStore, transport: transport);
        for (final key in neededKeys) {
          if (unhydrated.contains(key)) {
            await engine.hydrateShard(key);
          }
        }
      }
    }

    _refreshEntriesFromSqlite(windowStart: minTime, windowEnd: maxTime);
  }

  Future<void> _update(GardenProfile next, {bool persistProfile = true}) async {
    if (next == value) return;
    value = next;
    if (!persistProfile) return;
    final backingStore = store;
    if (backingStore != null) {
      try {
        // When backed by ShardedSqliteJournalStore, keep garden_profile.json lightweight
        // by storing journal entries in the monthly SQLite shards instead of duplicating
        // multi-year history in the JSON profile file.
        final profileToWrite = journalStore != null
            ? GardenProfile(
                activeLocation: next.activeLocation,
                savedLocations: next.savedLocations,
                starredCropIds: next.starredCropIds,
                taskQueue: next.taskQueue,
                journalEntries: const [],
              )
            : next;
        await backingStore.write(profileToWrite);
      } catch (_) {
        // Ignore persistence errors so UI state remains responsive.
      }
    }
  }

  /// Sets [location] as the active garden location and optionally saves it if named.
  Future<void> setActiveLocation(
    SavedLocation location, {
    bool saveIfNamed = true,
  }) => _update(value.withActiveLocation(location, saveIfNamed: saveIfNamed));

  /// Updates active coordinates to [latitude] and [longitude] with an optional [name].
  Future<void> setCoordinates(
    double latitude,
    double longitude, {
    String? name,
    bool saveIfNamed = true,
  }) {
    String resolvedName = name?.trim() ?? '';
    if (resolvedName.isEmpty) {
      for (final saved in value.savedLocations) {
        if (saved.matchesCoordinates(latitude, longitude)) {
          resolvedName = saved.name;
          break;
        }
      }
    }
    final location = SavedLocation.validated(
      latitude: latitude,
      longitude: longitude,
      name: resolvedName,
    );
    return setActiveLocation(location, saveIfNamed: saveIfNamed);
  }

  /// Removes [location] from the user's saved locations list.
  Future<void> removeSavedLocation(SavedLocation location) =>
      _update(value.withoutSavedLocation(location));

  /// Toggles whether [cropId] is starred in the user's garden patch.
  Future<void> toggleStarredCrop(String cropId) =>
      _update(value.withToggledCrop(cropId));

  /// Adds [task] to the active garden task queue.
  Future<void> addQueuedTask(QueuedGardenTask task) {
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      sqlStore.upsertQueuedTask(task);
    }
    return _update(value.withQueuedTask(task));
  }

  /// Removes the task with [taskId] from the active garden task queue.
  Future<void> removeQueuedTask(String taskId) {
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      sqlStore.removeQueuedTask(taskId);
    }
    return _update(value.withoutQueuedTask(taskId));
  }

  /// Toggles a task in the active garden queue for [action], [cropId], [targetQuality],
  /// and optional [bedName].
  Future<void> toggleQueuedTask({
    required TaskActionType action,
    String? cropId,
    required PlantQuality targetQuality,
    String note = '',
    String? bedName,
  }) {
    final id = QueuedGardenTask.canonicalIdFor(
      action: action,
      cropId: cropId,
      targetQuality: targetQuality,
      bedName: bedName,
    );
    if (value.isTaskQueued(
      action: action,
      cropId: cropId,
      targetQuality: targetQuality,
      bedName: bedName,
    )) {
      return removeQueuedTask(id);
    }
    return addQueuedTask(
      QueuedGardenTask(
        id: id,
        action: action,
        cropId: cropId,
        targetQuality: targetQuality,
        note: note,
        bedName: bedName,
      ),
    );
  }

  /// Adds or updates [entry] in the user's Biodynamic Field Journal & Diary.
  ///
  /// Also automatically completes/dequeues any matching [QueuedGardenTask] in
  /// the active task queue (same action and crop/organ quality).
  ///
  /// When [fullMediaBytesByAttachmentId] is provided, each full-resolution image
  /// is verified and saved to `media/<sha256>.<ext>` in [journalStore].
  Future<void> addJournalEntry(
    FieldJournalEntry entry, {
    Map<String, Uint8List>? fullMediaBytesByAttachmentId,
  }) async {
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      if (fullMediaBytesByAttachmentId != null) {
        for (final attachment in entry.attachments) {
          if (fullMediaBytesByAttachmentId[attachment.id]
              case final Uint8List fullBytes) {
            sqlStore.saveMediaBytesForAttachment(attachment, fullBytes);
          }
        }
      }
      final saved = sqlStore.upsertEntry(entry);
      GardenProfile next = value.withJournalEntry(saved);
      for (final task in value.taskQueue) {
        final bedMatches =
            task.bedName == null ||
            saved.bedName == null ||
            task.bedName == saved.bedName;
        if (saved.action.fulfillsTaskAction(task.action) &&
            bedMatches &&
            (task.cropId == saved.cropId ||
                (task.cropId == null && task.targetQuality == saved.quality))) {
          next = next.withoutQueuedTask(task.id);
        }
      }
      await _update(next, persistProfile: false);
      return;
    }

    GardenProfile next = value.withJournalEntry(entry);
    for (final task in value.taskQueue) {
      final bedMatches =
          task.bedName == null ||
          entry.bedName == null ||
          task.bedName == entry.bedName;
      if (entry.action.fulfillsTaskAction(task.action) &&
          bedMatches &&
          (task.cropId == entry.cropId ||
              (task.cropId == null && task.targetQuality == entry.quality))) {
        next = next.withoutQueuedTask(task.id);
      }
    }
    await _update(next);
  }

  /// Attaches a photo ([fullBytes] + optional [thumbnailBytes]) to [entryId]
  /// without overwriting existing attachments or notes from other garden members.
  Future<FieldJournalEntry?> attachPhotoToJournalEntry({
    required String entryId,
    String? noteId,
    required Uint8List fullBytes,
    Uint8List? thumbnailBytes,
    int? width,
    int? height,
    String caption = '',
    String? authorName,
    DateTime? timestamp,
    String? attachmentId,
  }) async {
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      final updated = sqlStore.attachPhotoToEntry(
        entryId: entryId,
        noteId: noteId,
        fullBytes: fullBytes,
        thumbnailBytes: thumbnailBytes,
        width: width,
        height: height,
        caption: caption,
        authorName: authorName,
        timestamp: timestamp,
        attachmentId: attachmentId,
      );
      if (updated != null) {
        await _update(value.withJournalEntry(updated), persistProfile: false);
      }
      return updated;
    }

    FieldJournalEntry? target;
    for (final existing in value.journalEntries) {
      if (existing.id == entryId) {
        target = existing;
        break;
      }
    }
    if (target == null) return null;

    final attachment = JournalAttachment.fromRawBytes(
      id: attachmentId,
      entryId: entryId,
      noteId: noteId,
      fullBytes: fullBytes,
      thumbnailBytes: thumbnailBytes,
      width: width,
      height: height,
      caption: caption,
      authorId: localActorId,
      authorName: authorName ?? localAuthorName,
      timestamp: timestamp,
    );
    final updated = target.withAddedAttachment(attachment);
    await _update(value.withJournalEntry(updated));
    return updated;
  }

  /// Loads the verified full-resolution image bytes for [attachment] from local
  /// `media/<sha256>.<ext>` cache or lazily downloads it from [syncTransport],
  /// falling back to [JournalAttachment.thumbnailBytes] if offline.
  Future<Uint8List?> loadFullAttachmentBytes(
    JournalAttachment attachment,
  ) async {
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      final localBytes = sqlStore.readLocalMediaBytes(attachment);
      if (localBytes != null) return localBytes;
      final transport = _syncTransport;
      if (transport != null) {
        final engine = GardenSyncEngine(store: sqlStore, transport: transport);
        final fetched = await engine.fetchAttachmentMedia(attachment);
        if (fetched != null) return fetched;
      }
    }
    return attachment.thumbnailBytes;
  }

  /// Updates an existing [entry] (such as comparative outcome notes/rating) in the journal.
  Future<void> updateJournalEntry(FieldJournalEntry entry) =>
      addJournalEntry(entry);

  /// Appends a collaborative [JournalNote] to [entryId] without overwriting
  /// notes written by other garden members.
  Future<FieldJournalEntry?> addNoteToJournalEntry({
    required String entryId,
    required String body,
    JournalNoteKind kind = JournalNoteKind.observation,
    int? outcomeRating,
    String? authorName,
    DateTime? timestamp,
  }) async {
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      final updated = sqlStore.addNoteToEntry(
        entryId: entryId,
        body: body,
        kind: kind,
        outcomeRating: outcomeRating,
        authorName: authorName,
        timestamp: timestamp,
      );
      if (updated != null) {
        await _update(value.withJournalEntry(updated), persistProfile: false);
      }
      return updated;
    }

    FieldJournalEntry? target;
    for (final existing in value.journalEntries) {
      if (existing.id == entryId) {
        target = existing;
        break;
      }
    }
    if (target == null) return null;

    final now = timestamp ?? DateTime.now();
    final note = JournalNote(
      id: 'note_${now.toUtc().microsecondsSinceEpoch}',
      entryId: entryId,
      timestamp: now,
      authorId: localActorId,
      authorName: authorName ?? localAuthorName,
      kind: kind,
      body: body.trim(),
      outcomeRating: outcomeRating,
    );
    final updated = target.withAddedNote(note);
    await _update(value.withJournalEntry(updated));
    return updated;
  }

  /// Removes the journal entry with [entryId] from the Biodynamic Field Journal.
  Future<void> removeJournalEntry(String entryId) async {
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      sqlStore.deleteEntry(entryId);
      await _update(value.withoutJournalEntry(entryId), persistProfile: false);
      return;
    }
    await _update(value.withoutJournalEntry(entryId));
  }

  /// Lists known bed/plot names across both `garden_meta.sqlite` and loaded entries.
  final Map<String, GardenPlot> _inMemoryPlots = <String, GardenPlot>{};

  /// Lists all known garden bed/plot names across the shared garden and local entries.
  List<String> listBedNames() {
    final names = <String>{
      if (journalStore != null && !journalStore!.isClosed)
        ...journalStore!.listBedNames(),
      ..._inMemoryPlots.keys,
      for (final entry in value.journalEntries)
        if (entry.bedName != null && entry.bedName!.trim().isNotEmpty)
          entry.bedName!.trim(),
    };
    final sorted = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  /// Lists all active [GardenPlot] definitions across the garden.
  List<GardenPlot> listPlots() {
    final sqlStore = journalStore;
    final byName = <String, GardenPlot>{
      if (sqlStore != null && !sqlStore.isClosed)
        for (final plot in sqlStore.listPlots()) plot.name: plot,
      ..._inMemoryPlots,
    };
    for (final entry in value.journalEntries) {
      final bed = entry.bedName?.trim();
      if (bed != null && bed.isNotEmpty) {
        byName.putIfAbsent(bed, () => GardenPlot(name: bed));
      }
    }
    final list = byName.values.toList(growable: false);
    list.sort((a, b) {
      final areaCmp = a.areaName.toLowerCase().compareTo(
        b.areaName.toLowerCase(),
      );
      if (areaCmp != 0) return areaCmp;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// Looks up a [GardenPlot] by [plotName].
  GardenPlot? findPlot(String? plotName) {
    if (plotName == null || plotName.trim().isEmpty) return null;
    final trimmed = plotName.trim();
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      final found = sqlStore.findPlot(trimmed);
      if (found != null) return found;
    }
    return _inMemoryPlots[trimmed] ??
        (listBedNames().contains(trimmed) ? GardenPlot(name: trimmed) : null);
  }

  /// Creates or updates a [GardenPlot] and notifies listeners.
  GardenPlot upsertPlot(GardenPlot plot) {
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      final saved = sqlStore.upsertPlot(plot);
      notifyListeners();
      return saved;
    }
    _inMemoryPlots[plot.name] = plot;
    notifyListeners();
    return plot;
  }

  /// Soft-deletes a [GardenPlot] by [plotName].
  void deletePlot(String plotName) {
    final trimmed = plotName.trim();
    if (trimmed.isEmpty) return;
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      sqlStore.deletePlot(trimmed);
    }
    _inMemoryPlots.remove(trimmed);
    notifyListeners();
  }

  /// Evaluates crop rotation history and botanical family break rules for [plotName].
  PlotRotationAssessment evaluatePlotRotation(
    String plotName, {
    VegetableEntry? candidateCrop,
    DateTime? referenceTime,
  }) {
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      return sqlStore.evaluatePlotRotation(
        plotName,
        candidateCrop: candidateCrop,
        referenceTime: referenceTime,
      );
    }
    return PlotRotationAssessment.evaluate(
      plotName: plotName.trim(),
      batchesInPlot: listPlantingBatches(bedName: plotName),
      candidateCrop: candidateCrop,
      referenceTime: referenceTime,
    );
  }

  /// Builds a within-season [PlotSuccessionPlan] for [plotName] at [referenceTime],
  /// combining harvested batches from earlier in the season, active batches with
  /// estimated bed-clearing dates, staggered *Hold-såning* batches, and relay
  /// crop candidates (direct sow, transplant, or start in module trays now).
  PlotSuccessionPlan buildPlotSuccessionPlan(
    String plotName, {
    DateTime? referenceTime,
  }) {
    final trimmed = plotName.trim();
    final plot = findPlot(trimmed) ?? GardenPlot(name: trimmed);
    final batches = listPlantingBatches(bedName: trimmed);
    return PlotSuccessionPlan.build(
      plot: plot,
      batchesInPlot: batches,
      referenceTime: referenceTime ?? DateTime.now(),
      starredCropIds: value.starredCropIds,
    );
  }

  /// Lists planting batches (sowings, transplants, cuttings, divisions, grafts)
  /// across months so harvests and observations can link back to them.
  ///
  /// When [onlyActiveInGround] is `true`, only unharvested batches are returned.
  List<PlantingBatchSummary> listPlantingBatches({
    String? cropId,
    String? bedName,
    bool onlyActiveInGround = false,
  }) {
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      return sqlStore.listPlantingBatches(
        cropId: cropId,
        bedName: bedName,
        onlyActiveInGround: onlyActiveInGround,
      );
    }
    final harvestedParentIds = <String, String>{
      for (final e in value.journalEntries)
        if (e.action.isHarvestAction &&
            e.parentEntryId != null &&
            e.parentEntryId!.isNotEmpty)
          e.parentEntryId!: e.id,
    };
    final normalizedBed = bedName != null && bedName.trim().isNotEmpty
        ? bedName.trim()
        : null;
    return [
      for (final entry in value.journalEntries)
        if (entry.action.isPlantingBatch &&
            (cropId == null || entry.cropId == cropId) &&
            (normalizedBed == null || entry.bedName == normalizedBed) &&
            (!onlyActiveInGround || !harvestedParentIds.containsKey(entry.id)))
          PlantingBatchSummary.fromEntry(
            entry,
            harvestedByEntryId: harvestedParentIds[entry.id],
          ),
    ];
  }

  /// Searches journal entries across all local monthly SQLite shards (or loaded entries).
  List<FieldJournalEntry> searchJournalEntries(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return value.journalEntries;
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      return sqlStore.searchEntries(trimmed);
    }
    final q = trimmed.toLowerCase();
    return value.journalEntries
        .where((e) {
          if (e.title.toLowerCase().contains(q)) return true;
          if (e.cropId?.toLowerCase().contains(q) ?? false) return true;
          if (e.bedName?.toLowerCase().contains(q) ?? false) return true;
          if (e.notes.toLowerCase().contains(q)) return true;
          if (e.outcomeNote.toLowerCase().contains(q)) return true;
          if (e.activeNotes.any((n) => n.body.toLowerCase().contains(q))) {
            return true;
          }
          if (e.activeAttachments.any(
            (a) => a.caption.toLowerCase().contains(q),
          )) {
            return true;
          }
          return false;
        })
        .toList(growable: false);
  }

  /// Lists all known monthly shard keys (`YYYY-MM`) across local disk and
  /// unhydrated cloud catalog, sorted newest-first.
  List<String> listKnownShardKeys() {
    final keys = <String>{
      if (journalStore != null && !journalStore!.isClosed) ...[
        ...journalStore!.listLocalShardKeys(),
        ...journalStore!.listUnhydratedRemoteShardKeys(),
      ],
      for (final entry in value.journalEntries) entry.shardKey,
    };
    final sorted = keys.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  /// Whether the monthly shard [shardKey] (`YYYY-MM`) is already downloaded on local disk.
  bool isShardHydrated(String shardKey) {
    final sqlStore = journalStore;
    if (sqlStore == null || sqlStore.isClosed) return true;
    return sqlStore.hasLocalShard(shardKey);
  }

  /// Resolves a [PlantingBatchSummary] by [entryId].
  PlantingBatchSummary? findPlantingBatch(String? entryId) {
    if (entryId == null || entryId.trim().isEmpty) return null;
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      final indexed = sqlStore.findPlantingBatch(entryId);
      if (indexed != null) return indexed;
    }
    for (final entry in value.journalEntries) {
      if (entry.id == entryId) {
        return PlantingBatchSummary.fromEntry(entry);
      }
    }
    return null;
  }

  /// Updates the local gardener's author name and/or shared garden title.
  void updateGardenIdentity({String? authorName, String? gardenName}) {
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      sqlStore.setAuthorAndGardenIdentity(
        authorName: authorName,
        gardenName: gardenName,
      );
      notifyListeners();
    }
  }

  /// Configures the [GardenSyncTransport] used for shared garden cloud/folder sync.
  void setSyncTransport(GardenSyncTransport? transport) {
    _syncTransport = transport;
    notifyListeners();
  }

  /// Connects a [GoogleDriveGardenSyncTransport] from a Google Drive folder ID,
  /// Drive folder URL, or `magiccalendar://join-garden` invite link.
  ///
  /// Throws a [FormatException] if [folderIdOrInvite] is not a valid folder ID or invite link.
  GoogleDriveGardenSyncTransport connectGoogleDrive({
    required String folderIdOrInvite,
    required GoogleDriveAccessTokenProvider tokenProvider,
    String? gardenName,
    http.Client? client,
  }) {
    final parsed = GardenInviteLink.tryParse(folderIdOrInvite);
    if (parsed == null) {
      throw FormatException(
        'Invalid Google Drive folder link or invite code',
        folderIdOrInvite,
      );
    }
    final effectiveGardenName =
        (gardenName != null && gardenName.trim().isNotEmpty)
        ? gardenName.trim()
        : parsed.gardenName;
    if (effectiveGardenName != null && effectiveGardenName.isNotEmpty) {
      updateGardenIdentity(gardenName: effectiveGardenName);
    }
    final transport = GoogleDriveGardenSyncTransport(
      rootFolderId: parsed.driveFolderId,
      tokenProvider: tokenProvider,
      gardenName: effectiveGardenName ?? this.gardenName,
      client: client,
    );
    _syncTransport = transport;
    notifyListeners();
    return transport;
  }

  /// Exports a portable [GardenSharedNoteBundle] of [entries] and [plots]
  /// (defaulting to the active profile entries and plots).
  GardenSharedNoteBundle exportSharedNoteBundle({
    Iterable<FieldJournalEntry>? entries,
    Iterable<GardenPlot>? plots,
  }) {
    return GardenSharedNoteBundle(
      gardenName: gardenName,
      exportedBy: localAuthorName,
      exportedAt: DateTime.now().toUtc(),
      plots: plots ?? listPlots(),
      entries: (entries ?? value.journalEntries).where((e) => !e.isDeleted),
    );
  }

  /// Imports and merges a shared [GardenSharedNoteBundle] from a JSON string.
  ///
  /// Returns the parsed [GardenSharedNoteBundle] after merging its plots and entries.
  /// Throws a [FormatException] if [rawJson] is not a valid bundle.
  Future<GardenSharedNoteBundle> importSharedNoteBundle(String rawJson) async {
    final bundle = GardenSharedNoteBundle.fromJsonString(rawJson);

    for (final plot in bundle.plots) {
      upsertPlot(plot);
    }

    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      for (final incoming in bundle.entries) {
        sqlStore.upsertEntry(incoming);
      }
      _refreshEntriesFromSqlite();
      return bundle;
    }

    GardenProfile next = value;
    for (final incoming in bundle.entries) {
      next = next.withJournalEntry(incoming);
    }
    await _update(next);
    return bundle;
  }

  /// Synchronizes the local monthly SQLite shards with [syncTransport].
  Future<GardenSyncReport?> syncJournal({
    DateTime? activeWindowStart,
    DateTime? activeWindowEnd,
    bool hydrateAllShards = false,
  }) async {
    final sqlStore = journalStore;
    final transport = _syncTransport;
    if (sqlStore == null || sqlStore.isClosed || transport == null) {
      return null;
    }
    _isSyncing = true;
    notifyListeners();
    try {
      final engine = GardenSyncEngine(store: sqlStore, transport: transport);
      final report = await engine.sync(
        activeWindowStart: activeWindowStart ?? _loadedWindowStart,
        activeWindowEnd: activeWindowEnd ?? _loadedWindowEnd,
        hydrateAllShards: hydrateAllShards,
      );
      _lastSyncReport = report;
      _refreshEntriesFromSqlite();
      return report;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    journalStore?.close();
    super.dispose();
  }
}
