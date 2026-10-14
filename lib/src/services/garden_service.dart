import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/garden/garden.dart';
import '../core/models/models.dart';
import '../core/task_window_planner.dart';

export '../core/garden/garden.dart';
export 'garden_profile_store_stub.dart'
    if (dart.library.io) 'garden_profile_store_io.dart';

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

/// Reactive controller managing the user's [GardenProfile] and persisting updates to [store].
final class GardenProfileController extends ValueNotifier<GardenProfile> {
  /// Optional backing store for persisting changes.
  final GardenProfileStore? store;

  /// Creates a [GardenProfileController] initialized with [initialProfile].
  GardenProfileController({GardenProfile? initialProfile, this.store})
    : super(initialProfile ?? GardenProfile());

  /// Loads the persisted [GardenProfile] from [store], falling back to [fallback] if absent.
  static Future<GardenProfileController> load({
    GardenProfileStore? store,
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
    );
  }

  Future<void> _update(GardenProfile next) async {
    if (next == value) return;
    value = next;
    final backingStore = store;
    if (backingStore != null) {
      try {
        await backingStore.write(next);
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
}
