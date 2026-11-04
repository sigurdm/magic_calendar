import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../task_window_planner.dart';
import '../vegetable_database.dart';
import 'field_journal_entry.dart';
import 'garden_plot.dart';

/// A named geographic coordinate saved in the user's garden profile.
final class SavedLocation {
  /// Default location (Svendborg / Langeland, Denmark).
  static const SavedLocation defaultLocation = SavedLocation(
    name: 'Svendborg, Denmark',
    latitude: 54.9037,
    longitude: 10.6074,
  );

  /// Built-in quick preset locations.
  static const List<SavedLocation> defaultPresets = [
    defaultLocation,
    SavedLocation(
      name: 'Copenhagen, Denmark',
      latitude: DefaultLocations.copenhagenLatitude,
      longitude: DefaultLocations.copenhagenLongitude,
    ),
    SavedLocation(
      name: 'Frankfurt, Germany',
      latitude: 50.1109,
      longitude: 8.6821,
    ),
    SavedLocation(name: 'London, UK', latitude: 51.5074, longitude: -0.1278),
    SavedLocation(
      name: 'New York, USA',
      latitude: 40.7128,
      longitude: -74.0060,
    ),
  ];

  /// Optional human-readable place or garden name.
  final String name;

  /// Geographic latitude in decimal degrees (-90.0 to 90.0).
  final double latitude;

  /// Geographic longitude in decimal degrees (-180.0 to 180.0).
  final double longitude;

  /// Creates a [SavedLocation].
  ///
  /// The [latitude] must be between -90.0 and 90.0, and [longitude] must be
  /// between -180.0 and 180.0.
  const SavedLocation({
    required this.latitude,
    required this.longitude,
    this.name = '',
  }) : assert(latitude >= -90.0 && latitude <= 90.0),
       assert(longitude >= -180.0 && longitude <= 180.0);

  /// Validates and constructs a [SavedLocation].
  ///
  /// The [latitude] must be finite and between -90.0 and 90.0.
  /// The [longitude] must be finite and between -180.0 and 180.0.
  factory SavedLocation.validated({
    required double latitude,
    required double longitude,
    String name = '',
  }) {
    if (!latitude.isFinite || latitude < -90.0 || latitude > 90.0) {
      throw ArgumentError.value(
        latitude,
        'latitude',
        'Must be between -90.0 and 90.0',
      );
    }
    if (!longitude.isFinite || longitude < -180.0 || longitude > 180.0) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'Must be between -180.0 and 180.0',
      );
    }
    final trimmed = name.trim();
    final resolvedName = trimmed.isNotEmpty
        ? trimmed
        : _matchingPresetName(latitude, longitude) ?? '';
    return SavedLocation(
      latitude: latitude,
      longitude: longitude,
      name: resolvedName,
    );
  }

  static String? _matchingPresetName(double latitude, double longitude) {
    for (final preset in defaultPresets) {
      if (preset.matchesCoordinates(latitude, longitude)) {
        return preset.name;
      }
    }
    return null;
  }

  /// Formatted coordinate string (`54.9°, 10.6°`).
  String get coordinateLabel =>
      '${latitude.toStringAsFixed(1)}°, ${longitude.toStringAsFixed(1)}°';

  /// Primary display label using [name] when non-empty or [coordinateLabel] otherwise.
  String get displayLabel {
    final trimmed = name.trim();
    return trimmed.isEmpty ? coordinateLabel : trimmed;
  }

  /// Compact badge label showing both [name] and [coordinateLabel] when named.
  String get headerBadgeLabel {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return coordinateLabel;
    return '$trimmed ($coordinateLabel)';
  }

  /// Whether [otherLatitude] and [otherLongitude] match within [tolerance] degrees.
  bool matchesCoordinates(
    double otherLatitude,
    double otherLongitude, {
    double tolerance = 0.0005,
  }) =>
      (latitude - otherLatitude).abs() <= tolerance &&
      (longitude - otherLongitude).abs() <= tolerance;

  /// Serializes this location to a JSON map.
  Map<String, Object?> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
  };

  /// Deserializes a [SavedLocation] from [json].
  ///
  /// Throws a [FormatException] if [json] does not contain valid coordinates.
  factory SavedLocation.fromJson(Map<String, Object?> json) {
    final latRaw = json['latitude'];
    final lonRaw = json['longitude'];
    final nameRaw = json['name'];
    if (latRaw is! num || lonRaw is! num) {
      throw const FormatException(
        'SavedLocation requires numeric latitude and longitude',
      );
    }
    final lat = latRaw.toDouble();
    final lon = lonRaw.toDouble();
    if (!lat.isFinite || lat < -90.0 || lat > 90.0) {
      throw FormatException('Invalid latitude out of range', lat);
    }
    if (!lon.isFinite || lon < -180.0 || lon > 180.0) {
      throw FormatException('Invalid longitude out of range', lon);
    }
    final name = nameRaw is String ? nameRaw : '';
    return SavedLocation.validated(latitude: lat, longitude: lon, name: name);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedLocation &&
          name == other.name &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(name, latitude, longitude);

  @override
  String toString() =>
      'SavedLocation(name: "$name", lat: $latitude, lon: $longitude)';
}

/// A pending garden task queued in the user's personal garden wishlist or
/// placed in time on a specific bed for succession planning.
final class QueuedGardenTask {
  /// Unique identifier for this queued task.
  final String id;

  /// The biodynamic agricultural action to perform.
  final TaskActionType action;

  /// Optional specific plant identifier in [VegetableDatabase].
  final String? cropId;

  /// Target plant organ quality governing the cosmic window.
  final PlantQuality targetQuality;

  /// Optional user note (e.g. bed name or cultivar).
  final String note;

  /// Optional target garden plot or bed name (e.g. `'Bed 1'`, `'Greenhouse'`).
  final String? bedName;

  /// Optional planned start date when placed in time on a bed in the succession planner.
  final DateTime? plannedStartDate;

  /// Optional explicit planned clearing/end date on the bed.
  ///
  /// When `null` and [plannedStartDate] is set, [effectiveEndDate] is derived
  /// automatically from [CropMaturityProfile.estimateClearingDateForCrop].
  final DateTime? plannedEndDate;

  /// Creates a [QueuedGardenTask].
  ///
  /// It is an error if [id] is empty or if [targetQuality] is [PlantQuality.none].
  QueuedGardenTask({
    required this.id,
    required this.action,
    required this.targetQuality,
    this.cropId,
    this.note = '',
    String? bedName,
    this.plannedStartDate,
    this.plannedEndDate,
  }) : bedName = bedName != null && bedName.trim().isNotEmpty
           ? bedName.trim()
           : null {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty');
    }
    if (targetQuality == PlantQuality.none) {
      throw ArgumentError.value(
        targetQuality,
        'targetQuality',
        'Must not be PlantQuality.none',
      );
    }
  }

  /// Deterministic canonical ID for an [action], optional [cropId], [targetQuality],
  /// optional [bedName], and optional [plannedStartDate].
  static String canonicalIdFor({
    required TaskActionType action,
    String? cropId,
    required PlantQuality targetQuality,
    String? bedName,
    DateTime? plannedStartDate,
  }) {
    final base = '${action.name}:${cropId ?? "any"}:${targetQuality.name}';
    final trimmedBed = bedName?.trim() ?? '';
    final withBed = trimmedBed.isEmpty ? base : '$base:$trimmedBed';
    if (plannedStartDate == null) return withBed;
    final utc = plannedStartDate.toUtc();
    final dayTag =
        '${utc.year}-${utc.month.toString().padLeft(2, "0")}-${utc.day.toString().padLeft(2, "0")}';
    return '$withBed:$dayTag';
  }

  /// Resolves the associated [VegetableEntry] from [VegetableDatabase], if any.
  VegetableEntry? get crop =>
      cropId == null ? null : VegetableDatabase.findById(cropId!);

  /// Display label for the target plant or organ category.
  String get targetLabel =>
      crop?.localizedDisplayName ?? 'Any ${targetQuality.displayName} Plant';

  /// Effective bed clearing date when [plannedStartDate] is set.
  DateTime? get effectiveEndDate {
    if (plannedEndDate != null) return plannedEndDate;
    final start = plannedStartDate;
    if (start == null) return null;
    return CropMaturityProfile.estimateClearingDateForCrop(
      crop: crop,
      plantedAt: start,
      isTransplant: action == TaskActionType.transplant,
    );
  }

  /// Estimated indoor module nursery start date when this task is a planned
  /// [TaskActionType.transplant] of a crop with module lead time.
  DateTime? get indoorNurseryStartDate {
    final start = plannedStartDate;
    final resolvedCrop = crop;
    if (start == null ||
        resolvedCrop == null ||
        action != TaskActionType.transplant) {
      return null;
    }
    final leadDays = CropMaturityProfile.forCrop(resolvedCrop)
        .seasonalModuleLeadTimeDays(start.month);
    if (leadDays <= 0) return null;
    return start.subtract(Duration(days: leadDays));
  }

  /// Estimated days the crop occupies the bed when [plannedStartDate] is set.
  int? get estimatedDaysInBed {
    final start = plannedStartDate;
    final end = effectiveEndDate;
    if (start == null || end == null) return null;
    return end.difference(start).inDays.clamp(1, 366);
  }

  /// Concise summary combining [action], [targetLabel], optional [bedName], and optional planned dates.
  String get summaryLabel {
    final bedPart = bedName != null ? ' ($bedName)' : '';
    final start = plannedStartDate;
    if (start == null) {
      return '${action.displayName} · $targetLabel$bedPart';
    }
    const months = [
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
    final end = effectiveEndDate;
    final datePart = end != null
        ? ' • ${months[start.month]} ${start.day}→${months[end.month]} ${end.day}'
        : ' • ${months[start.month]} ${start.day}';
    return '${action.displayName} · $targetLabel$bedPart$datePart';
  }

  /// Returns a copy of this task with updated fields.
  QueuedGardenTask copyWith({
    String? id,
    TaskActionType? action,
    String? cropId,
    PlantQuality? targetQuality,
    String? note,
    String? bedName,
    DateTime? plannedStartDate,
    DateTime? plannedEndDate,
    bool clearPlannedEndDate = false,
  }) => QueuedGardenTask(
    id: id ?? this.id,
    action: action ?? this.action,
    cropId: cropId ?? this.cropId,
    targetQuality: targetQuality ?? this.targetQuality,
    note: note ?? this.note,
    bedName: bedName ?? this.bedName,
    plannedStartDate: plannedStartDate ?? this.plannedStartDate,
    plannedEndDate: clearPlannedEndDate
        ? null
        : (plannedEndDate ?? this.plannedEndDate),
  );

  /// Whether this queued task matches the given selection parameters.
  bool matchesSelection({
    required TaskActionType selectedAction,
    required String? selectedCropId,
    required PlantQuality selectedQuality,
    String? selectedBedName,
  }) {
    final normalizedSelectedBed =
        selectedBedName != null && selectedBedName.trim().isNotEmpty
        ? selectedBedName.trim().toLowerCase()
        : null;
    return action == selectedAction &&
        cropId == selectedCropId &&
        targetQuality == selectedQuality &&
        bedName?.toLowerCase() == normalizedSelectedBed;
  }

  /// Serializes this queued task to a JSON map.
  Map<String, Object?> toJson() => {
    'id': id,
    'action': action.name,
    'cropId': cropId,
    'targetQuality': targetQuality.name,
    if (note.isNotEmpty) 'note': note,
    if (bedName != null) 'bedName': bedName,
    if (plannedStartDate != null)
      'plannedStartDate': plannedStartDate!.toUtc().toIso8601String(),
    if (plannedEndDate != null)
      'plannedEndDate': plannedEndDate!.toUtc().toIso8601String(),
  };

  /// Deserializes a [QueuedGardenTask] from [json].
  ///
  /// Throws a [FormatException] if required fields are missing or invalid.
  factory QueuedGardenTask.fromJson(Map<String, Object?> json) {
    final idRaw = json['id'];
    final actionRaw = json['action'];
    final cropIdRaw = json['cropId'];
    final qualityRaw = json['targetQuality'];
    final noteRaw = json['note'];
    final bedNameRaw = json['bedName'];
    final plannedStartRaw = json['plannedStartDate'];
    final plannedEndRaw = json['plannedEndDate'];

    if (idRaw is! String || idRaw.trim().isEmpty) {
      throw const FormatException('QueuedGardenTask requires a non-empty id');
    }
    if (actionRaw is! String) {
      throw const FormatException('QueuedGardenTask requires an action name');
    }
    if (qualityRaw is! String) {
      throw const FormatException(
        'QueuedGardenTask requires a targetQuality name',
      );
    }

    TaskActionType? parsedAction;
    for (final candidate in TaskActionType.values) {
      if (candidate.name == actionRaw) {
        parsedAction = candidate;
        break;
      }
    }
    if (parsedAction == null) {
      throw FormatException('Unknown TaskActionType', actionRaw);
    }

    PlantQuality? parsedQuality;
    for (final candidate in PlantQuality.values) {
      if (candidate.name == qualityRaw && candidate != PlantQuality.none) {
        parsedQuality = candidate;
        break;
      }
    }
    if (parsedQuality == null) {
      throw FormatException('Invalid PlantQuality', qualityRaw);
    }

    return QueuedGardenTask(
      id: idRaw,
      action: parsedAction,
      cropId: cropIdRaw is String && cropIdRaw.isNotEmpty ? cropIdRaw : null,
      targetQuality: parsedQuality,
      note: noteRaw is String ? noteRaw : '',
      bedName: bedNameRaw is String && bedNameRaw.trim().isNotEmpty
          ? bedNameRaw.trim()
          : null,
      plannedStartDate: plannedStartRaw is String
          ? DateTime.tryParse(plannedStartRaw)?.toLocal()
          : null,
      plannedEndDate: plannedEndRaw is String
          ? DateTime.tryParse(plannedEndRaw)?.toLocal()
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueuedGardenTask &&
          id == other.id &&
          action == other.action &&
          cropId == other.cropId &&
          targetQuality == other.targetQuality &&
          note == other.note &&
          bedName == other.bedName &&
          plannedStartDate == other.plannedStartDate &&
          plannedEndDate == other.plannedEndDate;

  @override
  int get hashCode => Object.hash(
    id,
    action,
    cropId,
    targetQuality,
    note,
    bedName,
    plannedStartDate,
    plannedEndDate,
  );
}

/// Immutable user garden profile storing saved locations, starred crops, and queued tasks.
final class GardenProfile {
  /// Schema version for JSON persistence.
  static const int jsonVersion = 1;

  /// Currently selected geographic location.
  final SavedLocation activeLocation;

  /// User-saved custom locations.
  final List<SavedLocation> savedLocations;

  /// Ordered set of starred crop IDs in the user's personal garden patch.
  final Set<String> starredCropIds;

  /// Active queue of pending garden tasks to watch for upcoming windows.
  final List<QueuedGardenTask> taskQueue;

  /// Comparative biodynamic field journal entries (sorted newest-first by timestamp).
  final List<FieldJournalEntry> journalEntries;

  /// Persisted garden plots/beds when running without a separate SQLite metadata store.
  final List<GardenPlot> plots;

  /// Creates a [GardenProfile] with defensive copies of all collections.
  GardenProfile({
    this.activeLocation = SavedLocation.defaultLocation,
    Iterable<SavedLocation> savedLocations = const [],
    Iterable<String> starredCropIds = const [],
    Iterable<QueuedGardenTask> taskQueue = const [],
    Iterable<FieldJournalEntry> journalEntries = const [],
    Iterable<GardenPlot> plots = const [],
  }) : savedLocations = List<SavedLocation>.unmodifiable(savedLocations),
       starredCropIds = Set<String>.unmodifiable(starredCropIds),
       taskQueue = List<QueuedGardenTask>.unmodifiable(taskQueue),
       journalEntries = List<FieldJournalEntry>.unmodifiable(
         _sortEntriesNewestFirst(journalEntries),
       ),
       plots = List<GardenPlot>.unmodifiable(plots);

  static List<FieldJournalEntry> _sortEntriesNewestFirst(
    Iterable<FieldJournalEntry> entries,
  ) {
    final copy = entries.toList(growable: false);
    copy.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return copy;
  }

  /// Whether the user has starred at least one crop in their garden.
  bool get hasStarredCrops => starredCropIds.isNotEmpty;

  /// Whether the user has at least one pending task in [taskQueue].
  bool get hasQueuedTasks => taskQueue.isNotEmpty;

  /// Whether the user has recorded at least one entry in [journalEntries].
  bool get hasJournalEntries => journalEntries.isNotEmpty;

  /// Resolved [VegetableEntry] records for all [starredCropIds] present in [VegetableDatabase].
  List<VegetableEntry> get starredCrops => [
    for (final id in starredCropIds) ?VegetableDatabase.findById(id),
  ];

  /// Whether [cropId] is currently starred in [starredCropIds].
  bool isCropStarred(String cropId) => starredCropIds.contains(cropId);

  /// Whether a task matching [action], [cropId], [targetQuality], and optional [bedName] is in [taskQueue].
  bool isTaskQueued({
    required TaskActionType action,
    String? cropId,
    required PlantQuality targetQuality,
    String? bedName,
  }) => taskQueue.any(
    (t) => t.matchesSelection(
      selectedAction: action,
      selectedCropId: cropId,
      selectedQuality: targetQuality,
      selectedBedName: bedName,
    ),
  );

  /// Returns a copy with [location] as the [activeLocation].
  ///
  /// When [saveIfNamed] is true and [location.name] is non-empty (and not already
  /// one of [SavedLocation.defaultPresets]), it is also added to [savedLocations].
  GardenProfile withActiveLocation(
    SavedLocation location, {
    bool saveIfNamed = true,
  }) {
    final updatedSaved = <SavedLocation>[...savedLocations];
    final isPreset = SavedLocation.defaultPresets.any(
      (p) => p.matchesCoordinates(location.latitude, location.longitude),
    );
    if (saveIfNamed && location.name.trim().isNotEmpty && !isPreset) {
      final existingIndex = updatedSaved.indexWhere(
        (s) => s.matchesCoordinates(location.latitude, location.longitude),
      );
      if (existingIndex >= 0) {
        updatedSaved[existingIndex] = location;
      } else {
        updatedSaved.add(location);
      }
    }
    return GardenProfile(
      activeLocation: location,
      savedLocations: updatedSaved,
      starredCropIds: starredCropIds,
      taskQueue: taskQueue,
      journalEntries: journalEntries,
      plots: plots,
    );
  }

  /// Returns a copy with [location] removed from [savedLocations].
  GardenProfile withoutSavedLocation(SavedLocation location) {
    return GardenProfile(
      activeLocation: activeLocation,
      savedLocations: savedLocations.where(
        (s) =>
            !s.matchesCoordinates(location.latitude, location.longitude) &&
            s != location,
      ),
      starredCropIds: starredCropIds,
      taskQueue: taskQueue,
      journalEntries: journalEntries,
      plots: plots,
    );
  }

  /// Returns a copy with [cropId] added to [starredCropIds] if absent, or removed if present.
  GardenProfile withToggledCrop(String cropId) {
    if (cropId.trim().isEmpty) {
      throw ArgumentError.value(cropId, 'cropId', 'Must not be empty');
    }
    final updated = <String>{...starredCropIds};
    if (!updated.remove(cropId)) {
      updated.add(cropId);
    }
    return GardenProfile(
      activeLocation: activeLocation,
      savedLocations: savedLocations,
      starredCropIds: updated,
      taskQueue: taskQueue,
      journalEntries: journalEntries,
      plots: plots,
    );
  }

  /// Returns a copy with [task] added to [taskQueue] (or replacing an existing task with the same ID).
  GardenProfile withQueuedTask(QueuedGardenTask task) {
    final updated = <QueuedGardenTask>[
      for (final existing in taskQueue)
        if (existing.id != task.id) existing,
      task,
    ];
    return GardenProfile(
      activeLocation: activeLocation,
      savedLocations: savedLocations,
      starredCropIds: starredCropIds,
      taskQueue: updated,
      journalEntries: journalEntries,
      plots: plots,
    );
  }

  /// Returns a copy with the task matching [taskId] removed from [taskQueue].
  GardenProfile withoutQueuedTask(String taskId) {
    return GardenProfile(
      activeLocation: activeLocation,
      savedLocations: savedLocations,
      starredCropIds: starredCropIds,
      taskQueue: taskQueue.where((t) => t.id != taskId),
      journalEntries: journalEntries,
      plots: plots,
    );
  }

  /// Returns a copy with [entry] added to [journalEntries] (or replacing an existing entry with the same ID).
  GardenProfile withJournalEntry(FieldJournalEntry entry) {
    final updated = <FieldJournalEntry>[
      for (final existing in journalEntries)
        if (existing.id != entry.id) existing,
      entry,
    ];
    return GardenProfile(
      activeLocation: activeLocation,
      savedLocations: savedLocations,
      starredCropIds: starredCropIds,
      taskQueue: taskQueue,
      journalEntries: updated,
      plots: plots,
    );
  }

  /// Returns a copy with the journal entry matching [entryId] removed from [journalEntries].
  GardenProfile withoutJournalEntry(String entryId) {
    return GardenProfile(
      activeLocation: activeLocation,
      savedLocations: savedLocations,
      starredCropIds: starredCropIds,
      taskQueue: taskQueue,
      journalEntries: journalEntries.where((e) => e.id != entryId),
      plots: plots,
    );
  }

  /// Returns a copy with [updatedPlots] replacing [plots].
  GardenProfile withPlots(Iterable<GardenPlot> updatedPlots) {
    return GardenProfile(
      activeLocation: activeLocation,
      savedLocations: savedLocations,
      starredCropIds: starredCropIds,
      taskQueue: taskQueue,
      journalEntries: journalEntries,
      plots: updatedPlots,
    );
  }

  /// Serializes this profile to a versioned JSON map.
  Map<String, Object?> toJson() => {
    'version': jsonVersion,
    'activeLocation': activeLocation.toJson(),
    'savedLocations': [for (final loc in savedLocations) loc.toJson()],
    'starredCropIds': starredCropIds.toList(growable: false),
    'taskQueue': [for (final task in taskQueue) task.toJson()],
    'journalEntries': [for (final entry in journalEntries) entry.toJson()],
    if (plots.isNotEmpty) 'plots': [for (final plot in plots) plot.toJson()],
  };

  /// Deserializes a [GardenProfile] from [json].
  ///
  /// Throws a [FormatException] if [json] has an unsupported version or invalid structure.
  factory GardenProfile.fromJson(Map<String, Object?> json) {
    if (json['version'] != jsonVersion) {
      throw FormatException(
        'Unsupported GardenProfile version',
        json['version'],
      );
    }

    final activeRaw = json['activeLocation'];
    if (activeRaw is! Map) {
      throw const FormatException('GardenProfile requires an activeLocation');
    }
    final activeLocation = SavedLocation.fromJson(
      activeRaw is Map<String, Object?>
          ? activeRaw
          : Map<String, Object?>.from(activeRaw),
    );

    final savedLocations = <SavedLocation>[];
    if (json['savedLocations'] case final List<Object?> rawSaved) {
      for (final item in rawSaved) {
        if (item is Map) {
          savedLocations.add(
            SavedLocation.fromJson(
              item is Map<String, Object?>
                  ? item
                  : Map<String, Object?>.from(item),
            ),
          );
        }
      }
    }

    final starredCropIds = <String>[];
    if (json['starredCropIds'] case final List<Object?> rawStarred) {
      for (final item in rawStarred) {
        if (item is String && item.trim().isNotEmpty) {
          starredCropIds.add(item.trim());
        }
      }
    }

    final taskQueue = <QueuedGardenTask>[];
    if (json['taskQueue'] case final List<Object?> rawTasks) {
      for (final item in rawTasks) {
        if (item is Map) {
          try {
            taskQueue.add(
              QueuedGardenTask.fromJson(
                item is Map<String, Object?>
                    ? item
                    : Map<String, Object?>.from(item),
              ),
            );
          } on FormatException {
            // Skip individual malformed tasks rather than losing the whole profile.
          }
        }
      }
    }

    final journalEntries = <FieldJournalEntry>[];
    if (json['journalEntries'] case final List<Object?> rawEntries) {
      for (final item in rawEntries) {
        if (item is Map) {
          try {
            journalEntries.add(
              FieldJournalEntry.fromJson(
                item is Map<String, Object?>
                    ? item
                    : Map<String, Object?>.from(item),
              ),
            );
          } on FormatException {
            // Skip individual malformed journal entries rather than losing the whole profile.
          }
        }
      }
    }

    final plots = <GardenPlot>[];
    if (json['plots'] case final List<Object?> rawPlots) {
      for (final item in rawPlots) {
        if (item is Map) {
          try {
            plots.add(
              GardenPlot.fromJson(
                item is Map<String, Object?>
                    ? item
                    : Map<String, Object?>.from(item),
              ),
            );
          } on FormatException {
            // Skip individual malformed plots rather than losing the whole profile.
          }
        }
      }
    }

    return GardenProfile(
      activeLocation: activeLocation,
      savedLocations: savedLocations,
      starredCropIds: starredCropIds,
      taskQueue: taskQueue,
      journalEntries: journalEntries,
      plots: plots,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GardenProfile &&
          activeLocation == other.activeLocation &&
          listEquals(savedLocations, other.savedLocations) &&
          setEquals(starredCropIds, other.starredCropIds) &&
          listEquals(taskQueue, other.taskQueue) &&
          listEquals(journalEntries, other.journalEntries) &&
          listEquals(plots, other.plots);

  @override
  int get hashCode => Object.hash(
    activeLocation,
    Object.hashAll(savedLocations),
    Object.hashAll(starredCropIds),
    Object.hashAll(taskQueue),
    Object.hashAll(journalEntries),
    Object.hashAll(plots),
  );
}
