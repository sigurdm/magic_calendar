import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/garden/garden.dart';
import '../core/models/models.dart';
import '../core/task_window_planner.dart';
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
      // Seed any entries passed in initialProfile into SQLite shards, then load initial window.
      if (initialProfile != null && initialProfile.journalEntries.isNotEmpty) {
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
    value = GardenProfile(
      activeLocation: value.activeLocation,
      savedLocations: value.savedLocations,
      starredCropIds: value.starredCropIds,
      taskQueue: value.taskQueue,
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
  Future<void> addQueuedTask(QueuedGardenTask task) =>
      _update(value.withQueuedTask(task));

  /// Removes the task with [taskId] from the active garden task queue.
  Future<void> removeQueuedTask(String taskId) =>
      _update(value.withoutQueuedTask(taskId));

  /// Toggles a task in the active garden queue for [action], [cropId], and [targetQuality].
  Future<void> toggleQueuedTask({
    required TaskActionType action,
    String? cropId,
    required PlantQuality targetQuality,
    String note = '',
  }) {
    final id = QueuedGardenTask.canonicalIdFor(
      action: action,
      cropId: cropId,
      targetQuality: targetQuality,
    );
    if (value.isTaskQueued(
      action: action,
      cropId: cropId,
      targetQuality: targetQuality,
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
      ),
    );
  }

  /// Adds or updates [entry] in the user's Biodynamic Field Journal & Diary.
  Future<void> addJournalEntry(FieldJournalEntry entry) async {
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      final saved = sqlStore.upsertEntry(entry);
      await _update(value.withJournalEntry(saved), persistProfile: false);
      return;
    }
    await _update(value.withJournalEntry(entry));
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
  List<String> listBedNames() {
    final names = <String>{
      if (journalStore != null && !journalStore!.isClosed)
        ...journalStore!.listBedNames(),
      for (final entry in value.journalEntries)
        if (entry.bedName != null && entry.bedName!.trim().isNotEmpty)
          entry.bedName!.trim(),
    };
    final sorted = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  /// Lists active planting batches (sowings, transplants, cuttings, divisions, grafts)
  /// across months so harvests and observations can link back to them.
  List<PlantingBatchSummary> listPlantingBatches({String? cropId}) {
    final sqlStore = journalStore;
    if (sqlStore != null && !sqlStore.isClosed) {
      return sqlStore.listPlantingBatches(cropId: cropId);
    }
    return [
      for (final entry in value.journalEntries)
        if (entry.action.isPlantingBatch &&
            (cropId == null || entry.cropId == cropId))
          PlantingBatchSummary.fromEntry(entry),
    ];
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
