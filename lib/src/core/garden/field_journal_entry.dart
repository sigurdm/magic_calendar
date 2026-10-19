import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../biodynamic_prep.dart';
import '../dornach_boundaries.dart';
import '../models/models.dart';
import '../task_window_planner.dart';
import '../vegetable_database.dart';
import 'garden_profile.dart';
import 'hlc.dart';

/// Allowed image file formats for garden diary photo attachments, verified by magic bytes.
enum JournalImageFormat {
  /// JPEG (`FF D8 FF`).
  jpeg('jpg', 'image/jpeg'),

  /// PNG (`89 50 4E 47 0D 0A 1A 0A`).
  png('png', 'image/png'),

  /// WebP (`RIFF....WEBP`).
  webp('webp', 'image/webp');

  /// Canonical file extension (`'jpg'`, `'png'`, `'webp'`).
  final String extension;

  /// Canonical MIME type.
  final String mimeType;

  const JournalImageFormat(this.extension, this.mimeType);

  /// Inspects the magic-byte header of [bytes] to determine its [JournalImageFormat].
  ///
  /// Throws a [FormatException] if [bytes] does not match PNG, JPEG, or WebP magic bytes.
  static JournalImageFormat detect(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return JournalImageFormat.png;
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return JournalImageFormat.jpeg;
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return JournalImageFormat.webp;
    }
    throw const FormatException(
      'Unsupported image format: magic bytes must be PNG, JPEG, or WebP',
    );
  }

  /// Resolves a [JournalImageFormat] from a [mimeType] or [extension] string.
  static JournalImageFormat? tryFromMimeOrExtension(String value) {
    final lower = value.trim().toLowerCase();
    for (final candidate in JournalImageFormat.values) {
      if (candidate.mimeType == lower ||
          candidate.extension == lower ||
          candidate.name == lower) {
        return candidate;
      }
    }
    if (lower == 'image/jpg' || lower == 'jpeg') {
      return JournalImageFormat.jpeg;
    }
    return null;
  }
}

/// A photo attachment associated with a [FieldJournalEntry] or [JournalNote].
///
/// Full-resolution image bytes are content-addressed by [mediaSha256] and
/// stored outside the monthly SQLite database (`media/<mediaSha256>.<ext>`) so
/// editing text notes in a shard never re-uploads multi-megabyte photos, while
/// a compact [thumbnailBytes] preview is embedded inside `YYYY-MM.sqlite` for
/// instant offline rendering.
final class JournalAttachment {
  /// Maximum allowed full-resolution photo size (`10 MB`).
  static const int maxPhotoBytes = 10 * 1024 * 1024;

  /// Maximum inline SQLite thumbnail size (`64 KB`).
  static const int maxInlineThumbnailBytes = 64 * 1024;

  static final RegExp _sha256HexPattern = RegExp(r'^[0-9a-f]{64}$');

  /// Unique attachment identifier.
  final String id;

  /// Parent [FieldJournalEntry.id].
  final String entryId;

  /// Optional [JournalNote.id] if attached to a specific note in the thread.
  final String? noteId;

  /// Lowercase 64-hex-character SHA-256 hash of the full-resolution image bytes.
  final String mediaSha256;

  /// Verified image format (`jpeg`, `png`, `webp`).
  final JournalImageFormat format;

  /// Optional image width in pixels.
  final int? width;

  /// Optional image height in pixels.
  final int? height;

  /// Optional user caption describing the photo.
  final String caption;

  /// Unique actor ID of the gardener who attached the photo.
  final String authorId;

  /// Display name of the gardener who attached the photo.
  final String authorName;

  /// Timestamp when the photo was attached.
  final DateTime timestamp;

  /// Compact inline thumbnail bytes stored in the monthly SQLite shard (`YYYY-MM.sqlite`).
  final Uint8List? thumbnailBytes;

  /// Hybrid Logical Clock watermark for CRDT synchronization.
  final String updatedHlc;

  /// Optional HLC tombstone if the attachment was removed.
  final String? deletedHlc;

  /// Creates a [JournalAttachment].
  ///
  /// It is an error if [id] or [entryId] is empty, or if [mediaSha256] is not a
  /// 64-character lowercase hex SHA-256 string.
  JournalAttachment({
    required this.id,
    required this.entryId,
    this.noteId,
    required this.mediaSha256,
    this.format = JournalImageFormat.jpeg,
    this.width,
    this.height,
    this.caption = '',
    this.authorId = 'local',
    this.authorName = 'Gardener',
    required this.timestamp,
    Uint8List? thumbnailBytes,
    String? updatedHlc,
    this.deletedHlc,
  }) : thumbnailBytes = thumbnailBytes == null
           ? null
           : Uint8List.fromList(thumbnailBytes),
       updatedHlc =
           updatedHlc ??
           Hlc.fromDateTime(
             timestamp,
             actorId: authorId.trim().isEmpty ? 'local' : authorId.trim(),
           ).toCanonicalString() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty');
    }
    if (entryId.trim().isEmpty) {
      throw ArgumentError.value(entryId, 'entryId', 'Must not be empty');
    }
    if (!_sha256HexPattern.hasMatch(mediaSha256)) {
      throw ArgumentError.value(
        mediaSha256,
        'mediaSha256',
        'Must be a 64-character lowercase hex SHA-256 digest',
      );
    }
  }

  /// Validates [fullBytes] (magic bytes and `<= 10 MB`), computes its SHA-256
  /// content address, and constructs a [JournalAttachment].
  ///
  /// Throws a [FormatException] if [fullBytes] is empty, exceeds [maxPhotoBytes],
  /// or does not have valid PNG, JPEG, or WebP magic bytes.
  factory JournalAttachment.fromRawBytes({
    String? id,
    required String entryId,
    String? noteId,
    required Uint8List fullBytes,
    Uint8List? thumbnailBytes,
    int? width,
    int? height,
    String caption = '',
    String authorId = 'local',
    String authorName = 'Gardener',
    DateTime? timestamp,
    String? updatedHlc,
  }) {
    if (fullBytes.isEmpty) {
      throw const FormatException('Photo bytes must not be empty');
    }
    if (fullBytes.length > maxPhotoBytes) {
      throw FormatException(
        'Photo exceeds maximum allowed size of $maxPhotoBytes bytes',
        fullBytes.length,
      );
    }
    final format = JournalImageFormat.detect(fullBytes);
    final sha = sha256.convert(fullBytes).toString();
    final now = timestamp ?? DateTime.now();
    final effectiveThumb =
        thumbnailBytes ??
        (fullBytes.length <= maxInlineThumbnailBytes ? fullBytes : null);
    final resolvedId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : 'att_${now.toUtc().microsecondsSinceEpoch}_${sha.substring(0, 12)}';

    return JournalAttachment(
      id: resolvedId,
      entryId: entryId,
      noteId: noteId,
      mediaSha256: sha,
      format: format,
      width: width,
      height: height,
      caption: caption.trim(),
      authorId: authorId,
      authorName: authorName,
      timestamp: now,
      thumbnailBytes: effectiveThumb,
      updatedHlc: updatedHlc,
    );
  }

  /// Whether this attachment has been soft-deleted via an HLC tombstone.
  bool get isDeleted => deletedHlc != null && deletedHlc!.isNotEmpty;

  /// Canonical MIME type (`'image/jpeg'`, `'image/png'`, `'image/webp'`).
  String get mimeType => format.mimeType;

  /// Canonical file extension (`'jpg'`, `'png'`, `'webp'`).
  String get fileExtension => format.extension;

  /// Relative content-addressed object path on [`GardenSyncTransport`] (`media/<sha256>.<ext>`).
  String get remoteBlobName => 'media/$mediaSha256.$fileExtension';

  /// Verifies that [candidateBytes] matches both [format]'s magic header and [mediaSha256].
  bool verifyBytes(Uint8List candidateBytes) {
    if (candidateBytes.isEmpty || candidateBytes.length > maxPhotoBytes) {
      return false;
    }
    try {
      final detected = JournalImageFormat.detect(candidateBytes);
      if (detected != format) return false;
    } on FormatException {
      return false;
    }
    final actualSha = sha256.convert(candidateBytes).toString();
    return actualSha == mediaSha256;
  }

  /// Serializes this attachment metadata (and base64 inline thumbnail if present) to JSON.
  Map<String, Object?> toJson() => {
    'id': id,
    'entryId': entryId,
    if (noteId != null && noteId!.isNotEmpty) 'noteId': noteId,
    'mediaSha256': mediaSha256,
    'mimeType': mimeType,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (caption.isNotEmpty) 'caption': caption,
    'authorId': authorId,
    'authorName': authorName,
    'timestamp': timestamp.toIso8601String(),
    if (thumbnailBytes != null)
      'thumbnailBase64': base64Encode(thumbnailBytes!),
    'updatedHlc': updatedHlc,
    if (deletedHlc != null) 'deletedHlc': deletedHlc,
  };

  /// Deserializes a [JournalAttachment] from [json].
  ///
  /// Throws a [FormatException] if required fields are missing or invalid.
  factory JournalAttachment.fromJson(Map<String, Object?> json) {
    final idRaw = json['id'];
    final entryIdRaw = json['entryId'];
    final shaRaw = json['mediaSha256'];
    final timestampRaw = json['timestamp'];
    if (idRaw is! String || idRaw.trim().isEmpty) {
      throw const FormatException('JournalAttachment requires a non-empty id');
    }
    if (entryIdRaw is! String || entryIdRaw.trim().isEmpty) {
      throw const FormatException(
        'JournalAttachment requires a non-empty entryId',
      );
    }
    if (shaRaw is! String || !_sha256HexPattern.hasMatch(shaRaw)) {
      throw const FormatException(
        'JournalAttachment requires a 64-char hex mediaSha256',
      );
    }
    if (timestampRaw is! String) {
      throw const FormatException(
        'JournalAttachment requires an ISO-8601 timestamp',
      );
    }
    final parsedTimestamp = DateTime.tryParse(timestampRaw);
    if (parsedTimestamp == null) {
      throw FormatException('Invalid timestamp', timestampRaw);
    }

    final mimeRaw = json['mimeType'];
    final format =
        (mimeRaw is String
            ? JournalImageFormat.tryFromMimeOrExtension(mimeRaw)
            : null) ??
        JournalImageFormat.jpeg;

    Uint8List? thumbBytes;
    if (json['thumbnailBase64'] case final String b64 when b64.isNotEmpty) {
      try {
        thumbBytes = base64Decode(b64);
      } on FormatException {
        thumbBytes = null;
      }
    }

    return JournalAttachment(
      id: idRaw,
      entryId: entryIdRaw,
      noteId: json['noteId'] is String ? json['noteId'] as String : null,
      mediaSha256: shaRaw,
      format: format,
      width: json['width'] is int ? json['width'] as int : null,
      height: json['height'] is int ? json['height'] as int : null,
      caption: json['caption'] is String ? json['caption'] as String : '',
      authorId: json['authorId'] is String
          ? json['authorId'] as String
          : 'local',
      authorName: json['authorName'] is String
          ? json['authorName'] as String
          : 'Gardener',
      timestamp: parsedTimestamp,
      thumbnailBytes: thumbBytes,
      updatedHlc: json['updatedHlc'] is String
          ? json['updatedHlc'] as String
          : null,
      deletedHlc: json['deletedHlc'] is String
          ? json['deletedHlc'] as String
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalAttachment &&
          id == other.id &&
          entryId == other.entryId &&
          noteId == other.noteId &&
          mediaSha256 == other.mediaSha256 &&
          format == other.format &&
          width == other.width &&
          height == other.height &&
          caption == other.caption &&
          authorId == other.authorId &&
          authorName == other.authorName &&
          timestamp == other.timestamp &&
          listEquals(thumbnailBytes, other.thumbnailBytes) &&
          updatedHlc == other.updatedHlc &&
          deletedHlc == other.deletedHlc;

  @override
  int get hashCode => Object.hash(
    id,
    entryId,
    noteId,
    mediaSha256,
    format,
    width,
    height,
    caption,
    authorId,
    authorName,
    timestamp,
    thumbnailBytes == null ? null : Object.hashAll(thumbnailBytes!),
    updatedHlc,
    deletedHlc,
  );
}

/// Categories of field actions recorded in the Biodynamic Field Journal & Diary.
enum FieldJournalAction {
  /// Direct or indoor seed sowing.
  sowSeeds('Sow Seeds', 'Sow', '🌱', Icons.grass_outlined),

  /// Transplanting seedlings or bare-root stock during Descending Moon (*Pflanzzeit*).
  transplant(
    'Transplant (Pflanzzeit)',
    'Transplant',
    '🪴',
    Icons.south_outlined,
  ),

  /// Taking softwood or hardwood cuttings.
  takeCuttings('Take Cuttings', 'Cuttings', '✂️', Icons.content_cut_outlined),

  /// Dividing perennial crowns, bulbs, or rhizomes.
  dividePerennials(
    'Divide Perennials',
    'Divide',
    '🌿',
    Icons.call_split_outlined,
  ),

  /// Scion or bud grafting on fruit trees and vines.
  graft('Graft', 'Graft', '🌳', Icons.call_merge_outlined),

  /// Pruning orchard trees, vines, or bushes.
  prune('Prune', 'Prune', '🪚', Icons.carpenter_outlined),

  /// Hoeing, weeding, or deep soil aeration.
  cultivateSoil(
    'Hoe & Cultivate Soil',
    'Cultivate',
    '⛏️',
    Icons.landscape_outlined,
  ),

  /// Stirring and spraying biodynamic preparations (BD 500, BD 501, CPP, BD 508).
  sprayPreparation('Spray Preparation', 'Spray', '🌀', Icons.cyclone_outlined),

  /// Harvesting crops for immediate fresh consumption.
  harvestFresh(
    'Harvest (Fresh)',
    'Harvest',
    '🧺',
    Icons.shopping_basket_outlined,
  ),

  /// Harvesting crops for long cellar storage or seed saving.
  harvestStorage('Harvest & Store', 'Store', '🏺', Icons.inventory_2_outlined),

  /// Inoculating compost (BD 502–507), mulching, or general field care.
  compostAndCare('Compost & Field Care', 'Compost', '♻️', Icons.eco_outlined),

  /// Free-form diary note or field observation (frost, pests, emergence, weather).
  observation('Note & Observation', 'Note', '📝', Icons.sticky_note_2_outlined);

  /// User-facing action label.
  final String displayName;

  /// Compact badge label for timeline markers and chips.
  final String shortLabel;

  /// Unicode glyph rendered inside timeline markers.
  final String timelineGlyph;

  /// Material icon representing the action in cards and modals.
  final IconData icon;

  const FieldJournalAction(
    this.displayName,
    this.shortLabel,
    this.timelineGlyph,
    this.icon,
  );

  /// Whether this action establishes a new planting batch that later observations or harvests can link to.
  bool get isPlantingBatch => switch (this) {
    FieldJournalAction.sowSeeds ||
    FieldJournalAction.transplant ||
    FieldJournalAction.takeCuttings ||
    FieldJournalAction.dividePerennials ||
    FieldJournalAction.graft => true,
    _ => false,
  };

  /// Maps a [TaskActionType] from [TaskWindowPlanner] to a [FieldJournalAction].
  static FieldJournalAction fromTaskAction(TaskActionType action) =>
      switch (action) {
        TaskActionType.sowOutdoor ||
        TaskActionType.sowIndoor => FieldJournalAction.sowSeeds,
        TaskActionType.transplant => FieldJournalAction.transplant,
        TaskActionType.takeCuttings => FieldJournalAction.takeCuttings,
        TaskActionType.divide => FieldJournalAction.dividePerennials,
        TaskActionType.graft => FieldJournalAction.graft,
        TaskActionType.prune => FieldJournalAction.prune,
        TaskActionType.cultivateSoil => FieldJournalAction.cultivateSoil,
        TaskActionType.harvestStorage => FieldJournalAction.harvestStorage,
        TaskActionType.harvestFresh => FieldJournalAction.harvestFresh,
      };

  /// Maps an [AgriculturalTaskType] to a [FieldJournalAction].
  static FieldJournalAction fromAgriculturalTask(
    AgriculturalTaskType task,
  ) => switch (task) {
    AgriculturalTaskType.soilCultivation => FieldJournalAction.cultivateSoil,
    AgriculturalTaskType.pruning => FieldJournalAction.prune,
    AgriculturalTaskType.harvestStorage => FieldJournalAction.harvestStorage,
    AgriculturalTaskType.harvestFresh => FieldJournalAction.harvestFresh,
    AgriculturalTaskType.timberFelling => FieldJournalAction.prune,
    AgriculturalTaskType.peppering => FieldJournalAction.compostAndCare,
  };

  /// Maps a [BiodynamicPrepType] to a [FieldJournalAction].
  static FieldJournalAction fromPrepType(BiodynamicPrepType prep) =>
      switch (prep.category) {
        PrepCategory.fieldSpray => FieldJournalAction.sprayPreparation,
        PrepCategory.compostPrep => FieldJournalAction.compostAndCare,
      };
}

/// Classification of a collaborative [JournalNote] attached to a [FieldJournalEntry].
enum JournalNoteKind {
  /// Initial or follow-up field note (bed details, seed lot, soil condition).
  fieldNote('Field Note'),

  /// General diary observation (emergence, pests, frost, moisture).
  observation('Observation'),

  /// Comparative trial outcome observation and/or vigor rating.
  outcome('Trial Outcome');

  /// Display label for badges.
  final String displayName;

  const JournalNoteKind(this.displayName);
}

/// An individual append-only / per-note CRDT note attached to a [FieldJournalEntry].
///
/// Storing notes as discrete [JournalNote] rows keyed by [id] with an HLC
/// watermark ([updatedHlc]) allows multiple gardeners sharing a garden to add
/// notes to the same planting or day offline and merge them without overwriting
/// each other's notes.
final class JournalNote {
  /// Unique identifier for this note.
  final String id;

  /// Identifier of the parent [FieldJournalEntry].
  final String entryId;

  /// Timestamp when the note was written.
  final DateTime timestamp;

  /// Unique actor identifier of the gardener who wrote this note.
  final String authorId;

  /// Display name of the gardener who wrote this note.
  final String authorName;

  /// Semantic category of this note.
  final JournalNoteKind kind;

  /// Text content of the note.
  final String body;

  /// Optional 1..5 comparative rating associated with this note.
  final int? outcomeRating;

  /// Canonical Hybrid Logical Clock string for Last-Write-Wins updates on this specific [id].
  final String updatedHlc;

  /// Optional HLC tombstone if this note was deleted.
  final String? deletedHlc;

  /// Creates a [JournalNote].
  ///
  /// It is an error if [id] or [entryId] is empty, or if [outcomeRating] is
  /// non-null and outside `1..5`.
  JournalNote({
    required this.id,
    required this.entryId,
    required this.timestamp,
    this.authorId = 'local',
    this.authorName = 'Gardener',
    this.kind = JournalNoteKind.fieldNote,
    required this.body,
    this.outcomeRating,
    String? updatedHlc,
    this.deletedHlc,
  }) : updatedHlc =
           updatedHlc ??
           Hlc.fromDateTime(
             timestamp,
             actorId: authorId.trim().isEmpty ? 'local' : authorId.trim(),
           ).toCanonicalString() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty');
    }
    if (entryId.trim().isEmpty) {
      throw ArgumentError.value(entryId, 'entryId', 'Must not be empty');
    }
    if (outcomeRating != null) {
      RangeError.checkValueInInterval(outcomeRating!, 1, 5, 'outcomeRating');
    }
  }

  /// Whether this note has been soft-deleted via a tombstone.
  bool get isDeleted => deletedHlc != null && deletedHlc!.isNotEmpty;

  /// Serializes this note to a JSON map.
  Map<String, Object?> toJson() => {
    'id': id,
    'entryId': entryId,
    'timestamp': timestamp.toIso8601String(),
    'authorId': authorId,
    'authorName': authorName,
    'kind': kind.name,
    'body': body,
    if (outcomeRating != null) 'outcomeRating': outcomeRating,
    'updatedHlc': updatedHlc,
    if (deletedHlc != null) 'deletedHlc': deletedHlc,
  };

  /// Deserializes a [JournalNote] from [json].
  ///
  /// Throws a [FormatException] if required fields are missing or invalid.
  factory JournalNote.fromJson(Map<String, Object?> json) {
    final idRaw = json['id'];
    final entryIdRaw = json['entryId'];
    final timestampRaw = json['timestamp'];
    final bodyRaw = json['body'];
    if (idRaw is! String || idRaw.trim().isEmpty) {
      throw const FormatException('JournalNote requires a non-empty id');
    }
    if (entryIdRaw is! String || entryIdRaw.trim().isEmpty) {
      throw const FormatException('JournalNote requires a non-empty entryId');
    }
    if (timestampRaw is! String) {
      throw const FormatException('JournalNote requires an ISO-8601 timestamp');
    }
    final parsedTimestamp = DateTime.tryParse(timestampRaw);
    if (parsedTimestamp == null) {
      throw FormatException('Invalid JournalNote timestamp', timestampRaw);
    }

    final kindRaw = json['kind'];
    JournalNoteKind parsedKind = JournalNoteKind.fieldNote;
    if (kindRaw is String) {
      for (final candidate in JournalNoteKind.values) {
        if (candidate.name == kindRaw) {
          parsedKind = candidate;
          break;
        }
      }
    }

    final ratingRaw = json['outcomeRating'];
    final int? parsedRating =
        (ratingRaw is int && ratingRaw >= 1 && ratingRaw <= 5)
        ? ratingRaw
        : null;

    return JournalNote(
      id: idRaw,
      entryId: entryIdRaw,
      timestamp: parsedTimestamp,
      authorId: json['authorId'] is String
          ? json['authorId'] as String
          : 'local',
      authorName: json['authorName'] is String
          ? json['authorName'] as String
          : 'Gardener',
      kind: parsedKind,
      body: bodyRaw is String ? bodyRaw : '',
      outcomeRating: parsedRating,
      updatedHlc: json['updatedHlc'] is String
          ? json['updatedHlc'] as String
          : null,
      deletedHlc: json['deletedHlc'] is String
          ? json['deletedHlc'] as String
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalNote &&
          id == other.id &&
          entryId == other.entryId &&
          timestamp == other.timestamp &&
          authorId == other.authorId &&
          authorName == other.authorName &&
          kind == other.kind &&
          body == other.body &&
          outcomeRating == other.outcomeRating &&
          updatedHlc == other.updatedHlc &&
          deletedHlc == other.deletedHlc;

  @override
  int get hashCode => Object.hash(
    id,
    entryId,
    timestamp,
    authorId,
    authorName,
    kind,
    body,
    outcomeRating,
    updatedHlc,
    deletedHlc,
  );
}

/// A member participating in a shared garden diary.
final class GardenMember {
  /// Unique actor identifier for this member or device.
  final String actorId;

  /// Human-readable gardener name shown on diary notes.
  final String displayName;

  /// ARGB accent color value used for author badges.
  final int colorValue;

  /// HLC watermark of the latest profile update for this member.
  final String updatedHlc;

  /// Creates a [GardenMember].
  GardenMember({
    required this.actorId,
    required this.displayName,
    this.colorValue = 0xFFD4AF37,
    String? updatedHlc,
  }) : updatedHlc =
           updatedHlc ??
           Hlc.fromDateTime(
             DateTime.now().toUtc(),
             actorId: actorId.trim().isEmpty ? 'local' : actorId.trim(),
           ).toCanonicalString() {
    if (actorId.trim().isEmpty) {
      throw ArgumentError.value(actorId, 'actorId', 'Must not be empty');
    }
    if (displayName.trim().isEmpty) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'Must not be empty',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GardenMember &&
          actorId == other.actorId &&
          displayName == other.displayName &&
          colorValue == other.colorValue &&
          updatedHlc == other.updatedHlc;

  @override
  int get hashCode => Object.hash(actorId, displayName, colorValue, updatedHlc);
}

/// Compact cross-month summary of a sowing or planting entry stored in `garden_meta.sqlite`.
///
/// Allows linking a harvest or observation in October back to a sowing in April
/// without loading all intermediate monthly shards into memory.
final class PlantingBatchSummary {
  /// Identifier of the planting [FieldJournalEntry].
  final String entryId;

  /// Monthly shard key (`YYYY-MM`) where the full entry is stored.
  final String shardKey;

  /// Timestamp when the batch was sown or planted.
  final DateTime timestamp;

  /// Planting action performed.
  final FieldJournalAction action;

  /// Entry headline.
  final String title;

  /// Optional crop ID in [VegetableDatabase].
  final String? cropId;

  /// Optional garden bed or plot name.
  final String? bedName;

  /// Target plant organ quality.
  final PlantQuality quality;

  /// Concise cosmic rhythm summary at planting time (e.g. `'Root · Descending ↓'`).
  final String cosmicSummary;

  /// HLC watermark for CRDT synchronization.
  final String updatedHlc;

  /// Optional HLC tombstone if the planting entry was deleted.
  final String? deletedHlc;

  /// Creates a [PlantingBatchSummary].
  const PlantingBatchSummary({
    required this.entryId,
    required this.shardKey,
    required this.timestamp,
    required this.action,
    required this.title,
    required this.quality,
    required this.cosmicSummary,
    required this.updatedHlc,
    this.cropId,
    this.bedName,
    this.deletedHlc,
  });

  /// Creates a [PlantingBatchSummary] from a full [FieldJournalEntry].
  factory PlantingBatchSummary.fromEntry(FieldJournalEntry entry) {
    return PlantingBatchSummary(
      entryId: entry.id,
      shardKey: entry.shardKey,
      timestamp: entry.timestamp,
      action: entry.action,
      title: entry.title,
      cropId: entry.cropId,
      bedName: entry.bedName,
      quality: entry.quality,
      cosmicSummary: entry.cosmicSnapshot.rhythmBadgeLabel,
      updatedHlc: entry.updatedHlc,
      deletedHlc: entry.deletedHlc,
    );
  }

  /// Number of whole days elapsed between this planting and [laterTime].
  int daysElapsedAt(DateTime laterTime) =>
      laterTime.difference(timestamp).inDays;

  /// Concise display label for lifecycle dropdowns and chips.
  String get displayLabel {
    final bedPart = (bedName != null && bedName!.trim().isNotEmpty)
        ? ' • ${bedName!.trim()}'
        : '';
    final ymd =
        '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
    return '$title$bedPart ($ymd · $cosmicSummary)';
  }
}

/// Immutable snapshot of the astronomical/biodynamic [CalendarInfo] at the moment a field action was logged.
final class FieldJournalCosmicSnapshot {
  /// Active sidereal plant organ quality ([PlantQuality]).
  final PlantQuality quality;

  /// Whether the timestamp fell within a Gray Day (lunar node, perigee, apogee, Saturn opposition, or eclipse).
  final bool isGrayDay;

  /// Whether a planetary trine or special cosmic aspect was active.
  final bool isSpecial;

  /// Whether the Moon was ascending in declination (rising sap).
  final bool isMoonAscending;

  /// Whether the Moon was descending in declination (*Pflanzzeit* / rooting impulse).
  bool get isMoonDescending => !isMoonAscending;

  /// Sidereal constellation of the Moon at the logged instant (e.g. `'Taurus'`), if known.
  final String moonConstellation;

  /// Illuminated fraction of the Moon (`0.0` to `1.0`).
  final double moonIllumination;

  /// Whether the synodic Moon phase was waxing toward Full Moon.
  final bool isWaxing;

  /// Optional diurnal Earth breathing phase label (e.g. `'Morning Exhalation'`).
  final String? diurnalPhaseName;

  /// Summary message from [CalendarInfo.message].
  final String summaryMessage;

  /// Creates a [FieldJournalCosmicSnapshot].
  ///
  /// The [moonIllumination] must be between `0.0` and `1.0`.
  FieldJournalCosmicSnapshot({
    required this.quality,
    required this.isGrayDay,
    this.isSpecial = false,
    required this.isMoonAscending,
    this.moonConstellation = '',
    this.moonIllumination = 0.5,
    this.isWaxing = true,
    this.diurnalPhaseName,
    this.summaryMessage = '',
  }) {
    if (!moonIllumination.isFinite ||
        moonIllumination < 0.0 ||
        moonIllumination > 1.0) {
      throw ArgumentError.value(
        moonIllumination,
        'moonIllumination',
        'Must be between 0.0 and 1.0',
      );
    }
  }

  /// Captures a [FieldJournalCosmicSnapshot] from an active [CalendarInfo].
  factory FieldJournalCosmicSnapshot.fromCalendarInfo(CalendarInfo info) {
    String constellation = '';
    for (final planet in info.planets) {
      if (planet.name.toLowerCase() == 'moon') {
        constellation = findBoundaryForLongitude(planet.longitude)?.name ?? '';
        break;
      }
    }
    return FieldJournalCosmicSnapshot(
      quality: info.quality,
      isGrayDay: info.isGrayDay,
      isSpecial: info.isSpecial,
      isMoonAscending: info.isMoonAscending,
      moonConstellation: constellation,
      moonIllumination: info.moonPhase.illuminatedFraction.clamp(0.0, 1.0),
      isWaxing: info.moonPhase.isWaxing,
      diurnalPhaseName: info.diurnalRhythm?.title,
      summaryMessage: info.message,
    );
  }

  /// Concise cosmic rhythm badge (e.g. `'Root · Descending (Pflanzzeit)'`).
  String get rhythmBadgeLabel {
    if (isGrayDay) {
      return 'Gray Day · ${isMoonDescending ? "Descending ↓" : "Ascending ↑"}';
    }
    final qualityText = quality == PlantQuality.none
        ? 'Neutral'
        : quality.displayName;
    final declText = isMoonDescending
        ? 'Descending ↓ (Pflanzzeit)'
        : 'Ascending ↑';
    return '$qualityText · $declText';
  }

  /// Concise lunar phase and constellation label (e.g. `'Taurus · 72% Waxing'`).
  String get moonBadgeLabel {
    final pct = '${(moonIllumination * 100).round()}%';
    final phaseDir = isWaxing ? 'Waxing' : 'Waning';
    if (moonConstellation.trim().isEmpty) {
      return 'Moon $pct $phaseDir';
    }
    return '${moonConstellation.trim()} · $pct $phaseDir';
  }

  /// Serializes this cosmic snapshot to a JSON map.
  Map<String, Object?> toJson() => {
    'quality': quality.name,
    'isGrayDay': isGrayDay,
    'isSpecial': isSpecial,
    'isMoonAscending': isMoonAscending,
    if (moonConstellation.isNotEmpty) 'moonConstellation': moonConstellation,
    'moonIllumination': moonIllumination,
    'isWaxing': isWaxing,
    if (diurnalPhaseName != null && diurnalPhaseName!.isNotEmpty)
      'diurnalPhaseName': diurnalPhaseName,
    if (summaryMessage.isNotEmpty) 'summaryMessage': summaryMessage,
  };

  /// Deserializes a [FieldJournalCosmicSnapshot] from [json].
  ///
  /// Throws a [FormatException] if required fields are missing or invalid.
  factory FieldJournalCosmicSnapshot.fromJson(Map<String, Object?> json) {
    final qualityRaw = json['quality'];
    if (qualityRaw is! String) {
      throw const FormatException(
        'FieldJournalCosmicSnapshot requires a quality string',
      );
    }
    PlantQuality? parsedQuality;
    for (final candidate in PlantQuality.values) {
      if (candidate.name == qualityRaw) {
        parsedQuality = candidate;
        break;
      }
    }
    if (parsedQuality == null) {
      throw FormatException('Unknown PlantQuality', qualityRaw);
    }

    final isGrayDay = json['isGrayDay'] == true;
    final isSpecial = json['isSpecial'] == true;
    final isMoonAscending = json['isMoonAscending'] == true;
    final moonConstellation = json['moonConstellation'] is String
        ? json['moonConstellation'] as String
        : '';
    final illumRaw = json['moonIllumination'];
    final moonIllumination = illumRaw is num
        ? illumRaw.toDouble().clamp(0.0, 1.0)
        : 0.5;
    final isWaxing = json['isWaxing'] != false;
    final diurnalPhaseName = json['diurnalPhaseName'] is String
        ? json['diurnalPhaseName'] as String
        : null;
    final summaryMessage = json['summaryMessage'] is String
        ? json['summaryMessage'] as String
        : '';

    return FieldJournalCosmicSnapshot(
      quality: parsedQuality,
      isGrayDay: isGrayDay,
      isSpecial: isSpecial,
      isMoonAscending: isMoonAscending,
      moonConstellation: moonConstellation,
      moonIllumination: moonIllumination,
      isWaxing: isWaxing,
      diurnalPhaseName: diurnalPhaseName,
      summaryMessage: summaryMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldJournalCosmicSnapshot &&
          quality == other.quality &&
          isGrayDay == other.isGrayDay &&
          isSpecial == other.isSpecial &&
          isMoonAscending == other.isMoonAscending &&
          moonConstellation == other.moonConstellation &&
          moonIllumination == other.moonIllumination &&
          isWaxing == other.isWaxing &&
          diurnalPhaseName == other.diurnalPhaseName &&
          summaryMessage == other.summaryMessage;

  @override
  int get hashCode => Object.hash(
    quality,
    isGrayDay,
    isSpecial,
    isMoonAscending,
    moonConstellation,
    moonIllumination,
    isWaxing,
    diurnalPhaseName,
    summaryMessage,
  );
}

/// Immutable snapshot of local weather and soil conditions at the moment a field action was logged.
final class FieldJournalWeatherSnapshot {
  /// Air temperature at 2m in degrees Celsius, if available.
  final double? temperatureCelsius;

  /// Root-zone soil temperature in degrees Celsius, if available.
  final double? soilTemperatureCelsius;

  /// Hourly precipitation in millimeters.
  final double precipitationMm;

  /// Wind speed in meters per second.
  final double windSpeedMs;

  /// Cloud cover percentage (`0.0` to `100.0`).
  final double cloudCoverPercent;

  /// Optional multi-horizon soil moisture label (e.g. `'Workable'`, `'Moist'`, `'Waterlogged'`).
  final String? soilMoistureLabel;

  /// Creates a [FieldJournalWeatherSnapshot].
  ///
  /// The [precipitationMm] and [windSpeedMs] must be non-negative.
  FieldJournalWeatherSnapshot({
    this.temperatureCelsius,
    this.soilTemperatureCelsius,
    this.precipitationMm = 0.0,
    this.windSpeedMs = 0.0,
    this.cloudCoverPercent = 0.0,
    this.soilMoistureLabel,
  }) {
    if (!precipitationMm.isFinite || precipitationMm < 0.0) {
      throw ArgumentError.value(
        precipitationMm,
        'precipitationMm',
        'Must be non-negative',
      );
    }
    if (!windSpeedMs.isFinite || windSpeedMs < 0.0) {
      throw ArgumentError.value(
        windSpeedMs,
        'windSpeedMs',
        'Must be non-negative',
      );
    }
  }

  /// Captures a [FieldJournalWeatherSnapshot] from a [WeatherDataPoint] and optional [horizon].
  factory FieldJournalWeatherSnapshot.fromWeather(
    WeatherDataPoint point, {
    MultiHorizonWeatherAnalysis? horizon,
  }) {
    return FieldJournalWeatherSnapshot(
      temperatureCelsius: point.temperature,
      soilTemperatureCelsius: horizon?.estimatedSoilTemperatureCelsius,
      precipitationMm: point.precipitation.clamp(0.0, double.infinity),
      windSpeedMs: point.windSpeed.clamp(0.0, double.infinity),
      cloudCoverPercent: point.cloudCover.clamp(0.0, 100.0),
      soilMoistureLabel: horizon?.soilMoisture.shortLabel,
    );
  }

  /// Compact one-line summary for journal cards.
  String get compactSummary {
    final parts = <String>[];
    if (temperatureCelsius != null) {
      parts.add('${temperatureCelsius!.toStringAsFixed(1)}°C');
    }
    if (soilTemperatureCelsius != null) {
      parts.add('Soil ${soilTemperatureCelsius!.toStringAsFixed(1)}°C');
    }
    parts.add('${precipitationMm.toStringAsFixed(1)}mm');
    parts.add('${windSpeedMs.toStringAsFixed(1)}m/s');
    if (soilMoistureLabel != null && soilMoistureLabel!.isNotEmpty) {
      parts.add(soilMoistureLabel!);
    }
    return parts.join(' · ');
  }

  /// Serializes this weather snapshot to a JSON map.
  Map<String, Object?> toJson() => {
    if (temperatureCelsius != null) 'temperatureCelsius': temperatureCelsius,
    if (soilTemperatureCelsius != null)
      'soilTemperatureCelsius': soilTemperatureCelsius,
    'precipitationMm': precipitationMm,
    'windSpeedMs': windSpeedMs,
    'cloudCoverPercent': cloudCoverPercent,
    if (soilMoistureLabel != null && soilMoistureLabel!.isNotEmpty)
      'soilMoistureLabel': soilMoistureLabel,
  };

  /// Deserializes a [FieldJournalWeatherSnapshot] from [json].
  factory FieldJournalWeatherSnapshot.fromJson(Map<String, Object?> json) {
    final tempRaw = json['temperatureCelsius'];
    final soilTempRaw = json['soilTemperatureCelsius'];
    final precipRaw = json['precipitationMm'];
    final windRaw = json['windSpeedMs'];
    final cloudRaw = json['cloudCoverPercent'];
    final moistureRaw = json['soilMoistureLabel'];

    return FieldJournalWeatherSnapshot(
      temperatureCelsius: tempRaw is num ? tempRaw.toDouble() : null,
      soilTemperatureCelsius: soilTempRaw is num
          ? soilTempRaw.toDouble()
          : null,
      precipitationMm: precipRaw is num
          ? precipRaw.toDouble().clamp(0.0, double.infinity)
          : 0.0,
      windSpeedMs: windRaw is num
          ? windRaw.toDouble().clamp(0.0, double.infinity)
          : 0.0,
      cloudCoverPercent: cloudRaw is num
          ? cloudRaw.toDouble().clamp(0.0, 100.0)
          : 0.0,
      soilMoistureLabel: moistureRaw is String ? moistureRaw : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldJournalWeatherSnapshot &&
          temperatureCelsius == other.temperatureCelsius &&
          soilTemperatureCelsius == other.soilTemperatureCelsius &&
          precipitationMm == other.precipitationMm &&
          windSpeedMs == other.windSpeedMs &&
          cloudCoverPercent == other.cloudCoverPercent &&
          soilMoistureLabel == other.soilMoistureLabel;

  @override
  int get hashCode => Object.hash(
    temperatureCelsius,
    soilTemperatureCelsius,
    precipitationMm,
    windSpeedMs,
    cloudCoverPercent,
    soilMoistureLabel,
  );
}

/// A sowing, spraying, harvesting, or observation entry in the Biodynamic Field Journal & Diary.
///
/// Captures what the gardener performed alongside a snapshot of the active
/// [CalendarInfo] ([cosmicSnapshot]) and local [WeatherDataPoint] ([weatherSnapshot]),
/// plus collaborative [noteThread] items, optional bed/plot tag ([bedName]),
/// and optional seed-to-harvest link ([parentEntryId]).
final class FieldJournalEntry {
  /// Unique identifier for this journal entry.
  final String id;

  /// Timestamp of the logged garden action.
  final DateTime timestamp;

  /// Category of agricultural action performed.
  final FieldJournalAction action;

  /// Human-readable headline (e.g. `'Sow Carrot (Gulerod)'` or `'Spray BD 500 Horn Manure'`).
  final String title;

  /// Optional crop identifier in [VegetableDatabase].
  final String? cropId;

  /// Optional biodynamic preparation code (e.g. `'BD 500'`, `'BD 501'`, `'CPP'`).
  final String? prepCode;

  /// Optional garden bed, plot, or greenhouse name (e.g. `'Bed 2'`, `'Greenhouse'`).
  final String? bedName;

  /// Optional ID of an earlier planting [FieldJournalEntry] that this entry follows up on.
  final String? parentEntryId;

  /// Target or active plant organ quality governing the entry's pigment color.
  final PlantQuality quality;

  /// Unique actor identifier of the gardener who created this entry.
  final String authorId;

  /// Display name of the gardener who created this entry.
  final String authorName;

  /// Snapshot of the cosmic/biodynamic conditions at [timestamp].
  final FieldJournalCosmicSnapshot cosmicSnapshot;

  /// Optional snapshot of local weather and soil conditions at [timestamp].
  final FieldJournalWeatherSnapshot? weatherSnapshot;

  /// Optional saved location where the action took place.
  final SavedLocation? location;

  /// Primary field notes recorded on this entry.
  final String notes;

  /// Follow-up comparative trial notes (e.g. germination days, vigor, cellar keeping quality).
  final String outcomeNote;

  /// Optional comparative trial rating from `1` (poor) to `5` (exceptional).
  final int? outcomeRating;

  /// Collaborative append-only note thread attached to this entry across shared garden members.
  final List<JournalNote> noteThread;

  /// Photo attachments associated with this entry or its notes.
  final List<JournalAttachment> attachments;

  /// Hybrid Logical Clock watermark of the latest mutation on this entry.
  final String updatedHlc;

  /// Optional HLC tombstone if this entry was deleted.
  final String? deletedHlc;

  /// Creates a [FieldJournalEntry].
  ///
  /// It is an error if [id] or [title] is empty, or if [outcomeRating] is non-null
  /// and outside `1..5`.
  FieldJournalEntry({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.title,
    required this.quality,
    required this.cosmicSnapshot,
    this.cropId,
    this.prepCode,
    this.bedName,
    this.parentEntryId,
    this.authorId = 'local',
    this.authorName = 'Gardener',
    this.weatherSnapshot,
    this.location,
    this.notes = '',
    this.outcomeNote = '',
    this.outcomeRating,
    Iterable<JournalNote> noteThread = const [],
    Iterable<JournalAttachment> attachments = const [],
    String? updatedHlc,
    this.deletedHlc,
  }) : noteThread = List<JournalNote>.unmodifiable(noteThread),
       attachments = List<JournalAttachment>.unmodifiable(attachments),
       updatedHlc =
           updatedHlc ??
           Hlc.fromDateTime(
             timestamp,
             actorId: authorId.trim().isEmpty ? 'local' : authorId.trim(),
           ).toCanonicalString() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Must not be empty');
    }
    if (outcomeRating != null) {
      RangeError.checkValueInInterval(outcomeRating!, 1, 5, 'outcomeRating');
    }
  }

  /// Computes the canonical monthly SQLite shard key (`YYYY-MM` in UTC) for [time].
  static String shardKeyFor(DateTime time) {
    final utc = time.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}';
  }

  /// Monthly shard key (`YYYY-MM` in UTC) where this entry resides.
  String get shardKey => shardKeyFor(timestamp);

  /// Creates a [FieldJournalEntry] from live [CalendarInfo] and optional [WeatherDataPoint].
  factory FieldJournalEntry.fromLiveContext({
    String? id,
    required DateTime timestamp,
    required FieldJournalAction action,
    String? title,
    String? cropId,
    String? prepCode,
    String? bedName,
    String? parentEntryId,
    PlantQuality? quality,
    String authorId = 'local',
    String authorName = 'Gardener',
    required CalendarInfo calendarInfo,
    WeatherDataPoint? weather,
    MultiHorizonWeatherAnalysis? horizon,
    SavedLocation? location,
    String notes = '',
    String outcomeNote = '',
    int? outcomeRating,
    Iterable<JournalNote> noteThread = const [],
    Iterable<JournalAttachment> attachments = const [],
    String? updatedHlc,
  }) {
    final crop = cropId != null ? VegetableDatabase.findById(cropId) : null;
    final effectiveQuality = quality ?? crop?.quality ?? calendarInfo.quality;
    final resolvedTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : _buildDefaultTitle(
            action: action,
            crop: crop,
            prepCode: prepCode,
            quality: effectiveQuality,
          );
    final resolvedId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : 'journal_${timestamp.millisecondsSinceEpoch}_${action.name}_${cropId ?? prepCode ?? effectiveQuality.name}';

    return FieldJournalEntry(
      id: resolvedId,
      timestamp: timestamp,
      action: action,
      title: resolvedTitle,
      cropId: cropId,
      prepCode: prepCode,
      bedName: bedName?.trim().isEmpty == true ? null : bedName?.trim(),
      parentEntryId: parentEntryId?.trim().isEmpty == true
          ? null
          : parentEntryId?.trim(),
      quality: effectiveQuality,
      authorId: authorId,
      authorName: authorName,
      cosmicSnapshot: FieldJournalCosmicSnapshot.fromCalendarInfo(calendarInfo),
      weatherSnapshot: weather != null
          ? FieldJournalWeatherSnapshot.fromWeather(weather, horizon: horizon)
          : null,
      location: location,
      notes: notes.trim(),
      outcomeNote: outcomeNote.trim(),
      outcomeRating: outcomeRating,
      noteThread: noteThread,
      attachments: attachments,
      updatedHlc: updatedHlc,
    );
  }

  static String _buildDefaultTitle({
    required FieldJournalAction action,
    required VegetableEntry? crop,
    required String? prepCode,
    required PlantQuality quality,
  }) {
    if (prepCode != null && prepCode.trim().isNotEmpty) {
      return '${action.shortLabel} ${prepCode.trim()}';
    }
    if (crop != null) {
      return '${action.shortLabel} ${crop.localizedDisplayName}';
    }
    if (quality != PlantQuality.none) {
      return '${action.displayName} (${quality.displayName})';
    }
    return action.displayName;
  }

  /// Resolved [VegetableEntry] from [VegetableDatabase], if [cropId] is set.
  VegetableEntry? get crop =>
      cropId == null ? null : VegetableDatabase.findById(cropId!);

  /// Unicode glyph for timeline markers.
  String get timelineMarkerGlyph => action.timelineGlyph;

  /// Short label displayed next to the marker on [InfiniteTimelinePainter] when zoomed in.
  String get timelineMarkerLabel {
    if (prepCode != null && prepCode!.trim().isNotEmpty) {
      return prepCode!.trim();
    }
    final resolvedCrop = crop;
    if (resolvedCrop != null) {
      return resolvedCrop.nameEn;
    }
    if (bedName != null && bedName!.trim().isNotEmpty) {
      return '${action.shortLabel} (${bedName!.trim()})';
    }
    return action.shortLabel;
  }

  /// Active (non-deleted) collaborative notes from [noteThread], ordered chronologically.
  List<JournalNote> get activeNotes => [
    for (final note in noteThread)
      if (!note.isDeleted &&
          (note.body.trim().isNotEmpty || note.outcomeRating != null))
        note,
  ];

  /// Active (non-deleted) photo attachments on this entry, ordered chronologically.
  List<JournalAttachment> get activeAttachments => [
    for (final att in attachments)
      if (!att.isDeleted) att,
  ];

  /// Whether the gardener has recorded a follow-up comparative outcome note or star rating.
  bool get hasOutcome =>
      outcomeRating != null ||
      outcomeNote.trim().isNotEmpty ||
      activeNotes.any(
        (n) => n.kind == JournalNoteKind.outcome || n.outcomeRating != null,
      );

  /// Effective star rating, checking [outcomeRating] or the latest rated note in [activeNotes].
  int? get effectiveOutcomeRating {
    if (outcomeRating != null) return outcomeRating;
    for (int i = activeNotes.length - 1; i >= 0; i--) {
      final rating = activeNotes[i].outcomeRating;
      if (rating != null) return rating;
    }
    return null;
  }

  /// Returns a copy of this entry with updated [notes], [outcomeNote], [outcomeRating],
  /// [bedName], [parentEntryId], [noteThread], or [attachments].
  FieldJournalEntry withOutcome({
    String? notes,
    String? outcomeNote,
    int? outcomeRating,
    bool clearRating = false,
    String? bedName,
    String? parentEntryId,
    Iterable<JournalNote>? noteThread,
    Iterable<JournalAttachment>? attachments,
    String? updatedHlc,
  }) {
    return FieldJournalEntry(
      id: id,
      timestamp: timestamp,
      action: action,
      title: title,
      cropId: cropId,
      prepCode: prepCode,
      bedName: bedName ?? this.bedName,
      parentEntryId: parentEntryId ?? this.parentEntryId,
      quality: quality,
      authorId: authorId,
      authorName: authorName,
      cosmicSnapshot: cosmicSnapshot,
      weatherSnapshot: weatherSnapshot,
      location: location,
      notes: notes ?? this.notes,
      outcomeNote: outcomeNote ?? this.outcomeNote,
      outcomeRating: clearRating ? null : (outcomeRating ?? this.outcomeRating),
      noteThread: noteThread ?? this.noteThread,
      attachments: attachments ?? this.attachments,
      updatedHlc: updatedHlc ?? this.updatedHlc,
      deletedHlc: deletedHlc,
    );
  }

  /// Returns a copy of this entry with [note] appended or updated in [noteThread].
  FieldJournalEntry withAddedNote(JournalNote note) {
    final updatedThread = <JournalNote>[
      for (final existing in noteThread)
        if (existing.id != note.id) existing,
      note,
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final isOutcome =
        note.kind == JournalNoteKind.outcome || note.outcomeRating != null;
    final nextOutcomeNote = isOutcome && note.body.trim().isNotEmpty
        ? note.body.trim()
        : outcomeNote;
    final nextRating = note.outcomeRating ?? outcomeRating;
    final nextNotes = !isOutcome && notes.isEmpty && note.body.trim().isNotEmpty
        ? note.body.trim()
        : notes;

    final nextHlc = note.updatedHlc.compareTo(updatedHlc) > 0
        ? note.updatedHlc
        : updatedHlc;

    return FieldJournalEntry(
      id: id,
      timestamp: timestamp,
      action: action,
      title: title,
      cropId: cropId,
      prepCode: prepCode,
      bedName: bedName,
      parentEntryId: parentEntryId,
      quality: quality,
      authorId: authorId,
      authorName: authorName,
      cosmicSnapshot: cosmicSnapshot,
      weatherSnapshot: weatherSnapshot,
      location: location,
      notes: nextNotes,
      outcomeNote: nextOutcomeNote,
      outcomeRating: nextRating,
      noteThread: updatedThread,
      attachments: attachments,
      updatedHlc: nextHlc,
      deletedHlc: deletedHlc,
    );
  }

  /// Returns a copy of this entry with [attachment] appended or updated in [attachments].
  FieldJournalEntry withAddedAttachment(JournalAttachment attachment) {
    final updatedAttachments = <JournalAttachment>[
      for (final existing in attachments)
        if (existing.id != attachment.id) existing,
      attachment,
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final nextHlc = attachment.updatedHlc.compareTo(updatedHlc) > 0
        ? attachment.updatedHlc
        : updatedHlc;

    return FieldJournalEntry(
      id: id,
      timestamp: timestamp,
      action: action,
      title: title,
      cropId: cropId,
      prepCode: prepCode,
      bedName: bedName,
      parentEntryId: parentEntryId,
      quality: quality,
      authorId: authorId,
      authorName: authorName,
      cosmicSnapshot: cosmicSnapshot,
      weatherSnapshot: weatherSnapshot,
      location: location,
      notes: notes,
      outcomeNote: outcomeNote,
      outcomeRating: outcomeRating,
      noteThread: noteThread,
      attachments: updatedAttachments,
      updatedHlc: nextHlc,
      deletedHlc: deletedHlc,
    );
  }

  /// Serializes this entry to a JSON map.
  Map<String, Object?> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'action': action.name,
    'title': title,
    if (cropId != null && cropId!.isNotEmpty) 'cropId': cropId,
    if (prepCode != null && prepCode!.isNotEmpty) 'prepCode': prepCode,
    if (bedName != null && bedName!.isNotEmpty) 'bedName': bedName,
    if (parentEntryId != null && parentEntryId!.isNotEmpty)
      'parentEntryId': parentEntryId,
    'quality': quality.name,
    'authorId': authorId,
    'authorName': authorName,
    'cosmicSnapshot': cosmicSnapshot.toJson(),
    if (weatherSnapshot != null) 'weatherSnapshot': weatherSnapshot!.toJson(),
    if (location != null) 'location': location!.toJson(),
    if (notes.isNotEmpty) 'notes': notes,
    if (outcomeNote.isNotEmpty) 'outcomeNote': outcomeNote,
    if (outcomeRating != null) 'outcomeRating': outcomeRating,
    if (noteThread.isNotEmpty)
      'noteThread': [for (final n in noteThread) n.toJson()],
    if (attachments.isNotEmpty)
      'attachments': [for (final a in attachments) a.toJson()],
    'updatedHlc': updatedHlc,
    if (deletedHlc != null) 'deletedHlc': deletedHlc,
  };

  /// Deserializes a [FieldJournalEntry] from [json].
  ///
  /// Throws a [FormatException] if required fields are missing or invalid.
  factory FieldJournalEntry.fromJson(Map<String, Object?> json) {
    final idRaw = json['id'];
    final timestampRaw = json['timestamp'];
    final actionRaw = json['action'];
    final titleRaw = json['title'];
    final qualityRaw = json['quality'];
    final cosmicRaw = json['cosmicSnapshot'];

    if (idRaw is! String || idRaw.trim().isEmpty) {
      throw const FormatException('FieldJournalEntry requires a non-empty id');
    }
    if (timestampRaw is! String) {
      throw const FormatException(
        'FieldJournalEntry requires an ISO-8601 timestamp',
      );
    }
    final parsedTimestamp = DateTime.tryParse(timestampRaw);
    if (parsedTimestamp == null) {
      throw FormatException('Invalid timestamp', timestampRaw);
    }
    if (actionRaw is! String) {
      throw const FormatException('FieldJournalEntry requires an action name');
    }
    FieldJournalAction? parsedAction;
    for (final candidate in FieldJournalAction.values) {
      if (candidate.name == actionRaw) {
        parsedAction = candidate;
        break;
      }
    }
    if (parsedAction == null) {
      throw FormatException('Unknown FieldJournalAction', actionRaw);
    }

    if (titleRaw is! String || titleRaw.trim().isEmpty) {
      throw const FormatException('FieldJournalEntry requires a title');
    }
    if (qualityRaw is! String) {
      throw const FormatException('FieldJournalEntry requires a quality');
    }
    PlantQuality? parsedQuality;
    for (final candidate in PlantQuality.values) {
      if (candidate.name == qualityRaw) {
        parsedQuality = candidate;
        break;
      }
    }
    if (parsedQuality == null) {
      throw FormatException('Unknown PlantQuality', qualityRaw);
    }

    if (cosmicRaw is! Map<String, Object?>) {
      throw const FormatException(
        'FieldJournalEntry requires a cosmicSnapshot map',
      );
    }
    final cosmicSnapshot = FieldJournalCosmicSnapshot.fromJson(cosmicRaw);

    FieldJournalWeatherSnapshot? weatherSnapshot;
    if (json['weatherSnapshot'] case final Map<String, Object?> weatherRaw) {
      weatherSnapshot = FieldJournalWeatherSnapshot.fromJson(weatherRaw);
    }

    SavedLocation? location;
    if (json['location'] case final Map<String, Object?> locRaw) {
      try {
        location = SavedLocation.fromJson(locRaw);
      } on FormatException {
        location = null;
      }
    }

    final cropIdRaw = json['cropId'];
    final prepCodeRaw = json['prepCode'];
    final bedNameRaw = json['bedName'];
    final parentEntryIdRaw = json['parentEntryId'];
    final authorIdRaw = json['authorId'];
    final authorNameRaw = json['authorName'];
    final notesRaw = json['notes'];
    final outcomeNoteRaw = json['outcomeNote'];
    final ratingRaw = json['outcomeRating'];
    int? parsedRating;
    if (ratingRaw is int && ratingRaw >= 1 && ratingRaw <= 5) {
      parsedRating = ratingRaw;
    }

    final parsedThread = <JournalNote>[];
    if (json['noteThread'] case final List<Object?> rawThread) {
      for (final item in rawThread) {
        if (item is Map<String, Object?>) {
          try {
            parsedThread.add(JournalNote.fromJson(item));
          } on FormatException {
            // Skip malformed note item.
          }
        }
      }
    }

    final parsedAttachments = <JournalAttachment>[];
    if (json['attachments'] case final List<Object?> rawAttachments) {
      for (final item in rawAttachments) {
        if (item is Map<String, Object?>) {
          try {
            parsedAttachments.add(JournalAttachment.fromJson(item));
          } on FormatException {
            // Skip malformed attachment item.
          }
        }
      }
    }

    return FieldJournalEntry(
      id: idRaw,
      timestamp: parsedTimestamp,
      action: parsedAction,
      title: titleRaw,
      cropId: cropIdRaw is String && cropIdRaw.isNotEmpty ? cropIdRaw : null,
      prepCode: prepCodeRaw is String && prepCodeRaw.isNotEmpty
          ? prepCodeRaw
          : null,
      bedName: bedNameRaw is String && bedNameRaw.isNotEmpty
          ? bedNameRaw
          : null,
      parentEntryId: parentEntryIdRaw is String && parentEntryIdRaw.isNotEmpty
          ? parentEntryIdRaw
          : null,
      quality: parsedQuality,
      authorId: authorIdRaw is String && authorIdRaw.isNotEmpty
          ? authorIdRaw
          : 'local',
      authorName: authorNameRaw is String && authorNameRaw.isNotEmpty
          ? authorNameRaw
          : 'Gardener',
      cosmicSnapshot: cosmicSnapshot,
      weatherSnapshot: weatherSnapshot,
      location: location,
      notes: notesRaw is String ? notesRaw : '',
      outcomeNote: outcomeNoteRaw is String ? outcomeNoteRaw : '',
      outcomeRating: parsedRating,
      noteThread: parsedThread,
      attachments: parsedAttachments,
      updatedHlc: json['updatedHlc'] is String
          ? json['updatedHlc'] as String
          : null,
      deletedHlc: json['deletedHlc'] is String
          ? json['deletedHlc'] as String
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldJournalEntry &&
          id == other.id &&
          timestamp == other.timestamp &&
          action == other.action &&
          title == other.title &&
          cropId == other.cropId &&
          prepCode == other.prepCode &&
          bedName == other.bedName &&
          parentEntryId == other.parentEntryId &&
          quality == other.quality &&
          authorId == other.authorId &&
          authorName == other.authorName &&
          cosmicSnapshot == other.cosmicSnapshot &&
          weatherSnapshot == other.weatherSnapshot &&
          location == other.location &&
          notes == other.notes &&
          outcomeNote == other.outcomeNote &&
          outcomeRating == other.outcomeRating &&
          listEquals(noteThread, other.noteThread) &&
          listEquals(attachments, other.attachments);

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    action,
    title,
    cropId,
    prepCode,
    bedName,
    parentEntryId,
    quality,
    authorId,
    authorName,
    cosmicSnapshot,
    weatherSnapshot,
    location,
    notes,
    outcomeNote,
    outcomeRating,
    Object.hashAll(noteThread),
    Object.hashAll(attachments),
  );
}
