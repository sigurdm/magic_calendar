import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../core/garden/field_journal_entry.dart';
import '../core/garden/garden_profile.dart';
import '../core/garden/hlc.dart';
import '../core/models/models.dart';

/// Validates canonical monthly shard keys (`YYYY-MM`).
final RegExp _shardKeyPattern = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

/// Validates canonical content-addressed media filenames (`<64-hex-sha256>.(jpg|png|webp)`).
final RegExp _mediaFileNamePattern = RegExp(r'^[0-9a-f]{64}\.(jpg|png|webp)$');

/// Monthly SQLite-sharded store for the Biodynamic Field Journal & Shared Garden Diary.
///
/// Stores cross-month garden metadata (members, shared beds, active planting batch
/// index, and sync watermarks) in `garden_meta.sqlite` and partitions journal
/// entries and collaborative notes into monthly SQLite files under
/// `shards/YYYY-MM.sqlite`.
///
/// Only the monthly shards needed for the active timeline window or diary page
/// are kept open in an LRU cache ([maxOpenShards]); older months are closed and
/// evicted from memory automatically.
final class ShardedSqliteJournalStore {
  /// Root directory containing `garden_meta.sqlite` and `shards/YYYY-MM.sqlite`.
  final Directory rootDirectory;

  /// Maximum number of monthly SQLite shard databases held open simultaneously.
  final int maxOpenShards;

  late final Database _metaDb;
  late HlcClock _clock;
  late String _gardenId;
  late String _gardenName;
  late String _localActorId;
  late String _localAuthorName;

  final LinkedHashMap<String, Database> _openShards =
      LinkedHashMap<String, Database>();
  bool _isClosed = false;

  /// Creates and initializes a [ShardedSqliteJournalStore] rooted at [rootDirectoryPath].
  ///
  /// The [maxOpenShards] must be at least `1`.
  ShardedSqliteJournalStore({
    required String rootDirectoryPath,
    this.maxOpenShards = 6,
    String? initialGardenId,
    String initialGardenName = 'Shared Biodynamic Garden',
    String? initialActorId,
    String initialAuthorName = 'Gardener',
  }) : rootDirectory = Directory(p.canonicalize(rootDirectoryPath)) {
    if (maxOpenShards < 1) {
      throw RangeError.range(maxOpenShards, 1, null, 'maxOpenShards');
    }
    rootDirectory.createSync(recursive: true);
    Directory(p.join(rootDirectory.path, 'shards')).createSync(recursive: true);
    Directory(p.join(rootDirectory.path, 'media')).createSync(recursive: true);

    final metaPath = p.join(rootDirectory.path, 'garden_meta.sqlite');
    _metaDb = sqlite3.open(metaPath);
    _initMetaSchema(_metaDb);

    _gardenId = _readOrInitConfig(
      'garden_id',
      initialGardenId ??
          'garden_${DateTime.now().toUtc().millisecondsSinceEpoch}',
    );
    _gardenName = _readOrInitConfig('garden_name', initialGardenName);
    _localActorId = _readOrInitConfig(
      'local_actor_id',
      initialActorId ??
          'actor_${DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36)}',
    );
    _localAuthorName = _readOrInitConfig(
      'local_author_name',
      initialAuthorName,
    );

    final savedLastHlc = Hlc.tryParse(_readConfig('last_hlc'));
    _clock = HlcClock(actorId: _localActorId, initial: savedLastHlc);

    _upsertLocalMemberRecord();
  }

  /// Whether this store has been closed.
  bool get isClosed => _isClosed;

  /// Unique identifier of the shared garden.
  String get gardenId => _gardenId;

  /// Display name of the shared garden.
  String get gardenName => _gardenName;

  /// Unique actor identifier for the local device/gardener.
  String get localActorId => _localActorId;

  /// Display name for the local gardener.
  String get localAuthorName => _localAuthorName;

  /// Number of monthly shard SQLite databases currently open in the LRU cache.
  int get openShardCount => _openShards.length;

  /// Keys (`YYYY-MM`) of the monthly shards currently open in the LRU cache.
  List<String> get openShardKeys => List<String>.unmodifiable(_openShards.keys);

  void _checkNotClosed() {
    if (_isClosed) {
      throw StateError('ShardedSqliteJournalStore has already been closed.');
    }
  }

  /// Validates that [shardKey] has the canonical `YYYY-MM` format.
  static void validateShardKey(String shardKey) {
    if (!_shardKeyPattern.hasMatch(shardKey)) {
      throw ArgumentError.value(
        shardKey,
        'shardKey',
        'Must match YYYY-MM (01..12)',
      );
    }
  }

  static void _initMetaSchema(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS garden_config (
        config_key TEXT PRIMARY KEY NOT NULL,
        config_value TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS garden_members (
        actor_id TEXT PRIMARY KEY NOT NULL,
        display_name TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        updated_hlc TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS garden_beds (
        bed_name TEXT PRIMARY KEY NOT NULL,
        updated_hlc TEXT NOT NULL,
        deleted_hlc TEXT
      );

      CREATE TABLE IF NOT EXISTS planting_index (
        entry_id TEXT PRIMARY KEY NOT NULL,
        shard_key TEXT NOT NULL,
        timestamp_ms INTEGER NOT NULL,
        action TEXT NOT NULL,
        title TEXT NOT NULL,
        crop_id TEXT,
        bed_name TEXT,
        quality TEXT NOT NULL,
        cosmic_summary TEXT NOT NULL,
        updated_hlc TEXT NOT NULL,
        deleted_hlc TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_planting_time
        ON planting_index(timestamp_ms DESC);

      CREATE TABLE IF NOT EXISTS sync_merged_blobs (
        blob_name TEXT PRIMARY KEY NOT NULL,
        merged_at_ms INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS remote_shard_catalog (
        shard_key TEXT NOT NULL,
        blob_name TEXT NOT NULL,
        PRIMARY KEY (shard_key, blob_name)
      );
    ''');
  }

  static void _initShardSchema(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS journal_entries (
        entry_id TEXT PRIMARY KEY NOT NULL,
        timestamp_ms INTEGER NOT NULL,
        action TEXT NOT NULL,
        title TEXT NOT NULL,
        crop_id TEXT,
        prep_code TEXT,
        bed_name TEXT,
        parent_entry_id TEXT,
        quality TEXT NOT NULL,
        author_id TEXT NOT NULL,
        author_name TEXT NOT NULL,
        cosmic_json TEXT NOT NULL,
        weather_json TEXT,
        location_json TEXT,
        initial_notes TEXT NOT NULL DEFAULT '',
        outcome_note TEXT NOT NULL DEFAULT '',
        outcome_rating INTEGER,
        updated_hlc TEXT NOT NULL,
        deleted_hlc TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_entries_time
        ON journal_entries(timestamp_ms DESC);
      CREATE INDEX IF NOT EXISTS idx_entries_crop
        ON journal_entries(crop_id, timestamp_ms DESC);

      CREATE TABLE IF NOT EXISTS entry_field_lww (
        entry_id TEXT NOT NULL,
        field_name TEXT NOT NULL,
        value_json TEXT NOT NULL,
        updated_hlc TEXT NOT NULL,
        PRIMARY KEY (entry_id, field_name)
      );

      CREATE TABLE IF NOT EXISTS journal_notes (
        note_id TEXT PRIMARY KEY NOT NULL,
        entry_id TEXT NOT NULL,
        timestamp_ms INTEGER NOT NULL,
        author_id TEXT NOT NULL,
        author_name TEXT NOT NULL,
        kind TEXT NOT NULL,
        body TEXT NOT NULL,
        outcome_rating INTEGER,
        updated_hlc TEXT NOT NULL,
        deleted_hlc TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_notes_entry
        ON journal_notes(entry_id, timestamp_ms ASC);

      CREATE TABLE IF NOT EXISTS journal_attachments (
        attachment_id TEXT PRIMARY KEY NOT NULL,
        entry_id TEXT NOT NULL,
        note_id TEXT,
        media_sha256 TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        width INTEGER,
        height INTEGER,
        caption TEXT NOT NULL DEFAULT '',
        author_id TEXT NOT NULL,
        author_name TEXT NOT NULL,
        timestamp_ms INTEGER NOT NULL,
        thumbnail_bytes BLOB,
        updated_hlc TEXT NOT NULL,
        deleted_hlc TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_attachments_entry
        ON journal_attachments(entry_id, timestamp_ms ASC);
    ''');
  }

  String? _readConfig(String key) {
    final rows = _metaDb.select(
      'SELECT config_value FROM garden_config WHERE config_key = ?',
      [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['config_value'] as String?;
  }

  String _readOrInitConfig(String key, String defaultValue) {
    final existing = _readConfig(key);
    if (existing != null && existing.isNotEmpty) return existing;
    _writeConfig(key, defaultValue);
    return defaultValue;
  }

  void _writeConfig(String key, String value) {
    _metaDb.execute(
      '''
      INSERT INTO garden_config (config_key, config_value)
      VALUES (?, ?)
      ON CONFLICT(config_key) DO UPDATE SET config_value = excluded.config_value
      ''',
      [key, value],
    );
  }

  Hlc _nextHlc([DateTime? wallTime]) {
    final next = _clock.now(wallTime);
    _writeConfig('last_hlc', next.toCanonicalString());
    return next;
  }

  void _observeHlcString(String? hlcString) {
    final parsed = Hlc.tryParse(hlcString);
    if (parsed == null) return;
    final next = _clock.receive(parsed);
    _writeConfig('last_hlc', next.toCanonicalString());
  }

  void _upsertLocalMemberRecord() {
    final hlc = _nextHlc().toCanonicalString();
    _metaDb.execute(
      '''
      INSERT INTO garden_members (actor_id, display_name, color_value, updated_hlc)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(actor_id) DO UPDATE SET
        display_name = excluded.display_name,
        updated_hlc = excluded.updated_hlc
      WHERE excluded.updated_hlc >= garden_members.updated_hlc
      ''',
      [_localActorId, _localAuthorName, 0xFFD4AF37, hlc],
    );
  }

  /// Updates the local gardener's display name and shared garden name.
  void setAuthorAndGardenIdentity({String? authorName, String? gardenName}) {
    _checkNotClosed();
    if (authorName != null && authorName.trim().isNotEmpty) {
      _localAuthorName = authorName.trim();
      _writeConfig('local_author_name', _localAuthorName);
      _upsertLocalMemberRecord();
    }
    if (gardenName != null && gardenName.trim().isNotEmpty) {
      _gardenName = gardenName.trim();
      _writeConfig('garden_name', _gardenName);
    }
  }

  /// Returns all members known in this shared garden.
  List<GardenMember> listMembers() {
    _checkNotClosed();
    final rows = _metaDb.select(
      'SELECT actor_id, display_name, color_value, updated_hlc FROM garden_members ORDER BY display_name ASC',
    );
    return [
      for (final row in rows)
        GardenMember(
          actorId: row['actor_id'] as String,
          displayName: row['display_name'] as String,
          colorValue: row['color_value'] as int,
          updatedHlc: row['updated_hlc'] as String,
        ),
    ];
  }

  /// Returns all active shared bed/plot names in alphabetical order.
  List<String> listBedNames() {
    _checkNotClosed();
    final rows = _metaDb.select('''
      SELECT bed_name FROM garden_beds
      WHERE deleted_hlc IS NULL OR deleted_hlc < updated_hlc
      ORDER BY bed_name COLLATE NOCASE ASC
      ''');
    return [for (final row in rows) row['bed_name'] as String];
  }

  /// Adds or updates a shared garden bed/plot name.
  void addBedName(String bedName, {String? hlcOverride}) {
    _checkNotClosed();
    final trimmed = bedName.trim();
    if (trimmed.isEmpty) return;
    final hlc = hlcOverride ?? _nextHlc().toCanonicalString();
    _metaDb.execute(
      '''
      INSERT INTO garden_beds (bed_name, updated_hlc, deleted_hlc)
      VALUES (?, ?, NULL)
      ON CONFLICT(bed_name) DO UPDATE SET
        updated_hlc = excluded.updated_hlc,
        deleted_hlc = NULL
      WHERE excluded.updated_hlc >= garden_beds.updated_hlc
      ''',
      [trimmed, hlc],
    );
  }

  /// Queries the cross-month planting index in `garden_meta.sqlite` without opening monthly shards.
  List<PlantingBatchSummary> listPlantingBatches({String? cropId}) {
    _checkNotClosed();
    final ResultSet rows;
    if (cropId != null && cropId.trim().isNotEmpty) {
      rows = _metaDb.select(
        '''
        SELECT * FROM planting_index
        WHERE (deleted_hlc IS NULL OR deleted_hlc < updated_hlc)
          AND crop_id = ?
        ORDER BY timestamp_ms DESC
        ''',
        [cropId.trim()],
      );
    } else {
      rows = _metaDb.select('''
        SELECT * FROM planting_index
        WHERE (deleted_hlc IS NULL OR deleted_hlc < updated_hlc)
        ORDER BY timestamp_ms DESC
        ''');
    }
    return [for (final row in rows) _plantingSummaryFromRow(row)];
  }

  /// Looks up a specific [PlantingBatchSummary] by [entryId] from `garden_meta.sqlite`.
  PlantingBatchSummary? findPlantingBatch(String entryId) {
    _checkNotClosed();
    final rows = _metaDb.select(
      '''
      SELECT * FROM planting_index
      WHERE entry_id = ? AND (deleted_hlc IS NULL OR deleted_hlc < updated_hlc)
      ''',
      [entryId],
    );
    if (rows.isEmpty) return null;
    return _plantingSummaryFromRow(rows.first);
  }

  PlantingBatchSummary _plantingSummaryFromRow(Row row) {
    final actionName = row['action'] as String;
    final qualityName = row['quality'] as String;
    FieldJournalAction action = FieldJournalAction.sowSeeds;
    for (final candidate in FieldJournalAction.values) {
      if (candidate.name == actionName) {
        action = candidate;
        break;
      }
    }
    PlantQuality quality = PlantQuality.root;
    for (final candidate in PlantQuality.values) {
      if (candidate.name == qualityName) {
        quality = candidate;
        break;
      }
    }
    return PlantingBatchSummary(
      entryId: row['entry_id'] as String,
      shardKey: row['shard_key'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        row['timestamp_ms'] as int,
        isUtc: true,
      ).toLocal(),
      action: action,
      title: row['title'] as String,
      cropId: row['crop_id'] as String?,
      bedName: row['bed_name'] as String?,
      quality: quality,
      cosmicSummary: row['cosmic_summary'] as String,
      updatedHlc: row['updated_hlc'] as String,
      deletedHlc: row['deleted_hlc'] as String?,
    );
  }

  File _shardFile(String shardKey) {
    validateShardKey(shardKey);
    final safeName = p.basename('$shardKey.sqlite');
    return File(p.join(rootDirectory.path, 'shards', safeName));
  }

  /// Whether the monthly shard for [shardKey] (`YYYY-MM`) exists on local disk.
  bool hasLocalShard(String shardKey) => _shardFile(shardKey).existsSync();

  /// Lists all monthly shard keys (`YYYY-MM`) present on local disk, sorted newest-first.
  List<String> listLocalShardKeys() {
    _checkNotClosed();
    final shardsDir = Directory(p.join(rootDirectory.path, 'shards'));
    if (!shardsDir.existsSync()) return const [];
    final keys = <String>[];
    for (final entity in shardsDir.listSync()) {
      if (entity is! File) continue;
      final base = p.basename(entity.path);
      if (!base.endsWith('.sqlite')) continue;
      final key = base.substring(0, base.length - '.sqlite'.length);
      if (_shardKeyPattern.hasMatch(key)) {
        keys.add(key);
      }
    }
    keys.sort((a, b) => b.compareTo(a));
    return keys;
  }

  /// Computes the ordered list of monthly shard keys (`YYYY-MM`) intersecting `[start, end]`.
  static List<String> shardKeysInRange(DateTime start, DateTime end) {
    final startUtc = (start.isBefore(end) ? start : end).toUtc();
    final endUtc = (start.isBefore(end) ? end : start).toUtc();
    final keys = <String>[];
    int year = startUtc.year;
    int month = startUtc.month;
    while (year < endUtc.year ||
        (year == endUtc.year && month <= endUtc.month)) {
      keys.add(
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}',
      );
      month += 1;
      if (month > 12) {
        month = 1;
        year += 1;
      }
    }
    return keys;
  }

  Database _openOrTouchShard(String shardKey, {bool createIfMissing = true}) {
    validateShardKey(shardKey);
    final existing = _openShards.remove(shardKey);
    if (existing != null) {
      // Re-insert at the end to mark as most-recently-used.
      _openShards[shardKey] = existing;
      return existing;
    }

    final file = _shardFile(shardKey);
    if (!createIfMissing && !file.existsSync()) {
      throw StateError('Shard $shardKey does not exist on disk');
    }

    while (_openShards.length >= maxOpenShards) {
      final oldestKey = _openShards.keys.first;
      final evicted = _openShards.remove(oldestKey);
      evicted?.dispose();
    }

    final db = sqlite3.open(file.path);
    _initShardSchema(db);
    _openShards[shardKey] = db;
    return db;
  }

  /// Inserts or updates [entry] in its monthly SQLite shard (`YYYY-MM.sqlite`)
  /// using per-field LWW CRDT tracking and append-only note rows.
  FieldJournalEntry upsertEntry(FieldJournalEntry entry) {
    _checkNotClosed();
    final hlc = _nextHlc().toCanonicalString();
    final effectiveAuthorId = entry.authorId == 'local'
        ? _localActorId
        : entry.authorId;
    final effectiveAuthorName = entry.authorName == 'Gardener'
        ? _localAuthorName
        : entry.authorName;

    final shardKey = entry.shardKey;
    final db = _openOrTouchShard(shardKey, createIfMissing: true);

    final seededNotes = <JournalNote>[...entry.noteThread];
    if (entry.notes.trim().isNotEmpty &&
        !seededNotes.any(
          (n) =>
              n.kind == JournalNoteKind.fieldNote &&
              n.body.trim() == entry.notes.trim(),
        )) {
      seededNotes.add(
        JournalNote(
          id: 'note_init_${entry.id}_$effectiveAuthorId',
          entryId: entry.id,
          timestamp: entry.timestamp,
          authorId: effectiveAuthorId,
          authorName: effectiveAuthorName,
          kind: JournalNoteKind.fieldNote,
          body: entry.notes.trim(),
          updatedHlc: hlc,
        ),
      );
    }
    if ((entry.outcomeNote.trim().isNotEmpty || entry.outcomeRating != null) &&
        !seededNotes.any(
          (n) =>
              n.kind == JournalNoteKind.outcome &&
              n.body.trim() == entry.outcomeNote.trim() &&
              n.outcomeRating == entry.outcomeRating,
        )) {
      seededNotes.add(
        JournalNote(
          id: 'note_outcome_${entry.id}_$effectiveAuthorId',
          entryId: entry.id,
          timestamp: DateTime.now(),
          authorId: effectiveAuthorId,
          authorName: effectiveAuthorName,
          kind: JournalNoteKind.outcome,
          body: entry.outcomeNote.trim(),
          outcomeRating: entry.outcomeRating,
          updatedHlc: hlc,
        ),
      );
    }

    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute(
        '''
        INSERT INTO journal_entries (
          entry_id, timestamp_ms, action, title, crop_id, prep_code,
          bed_name, parent_entry_id, quality, author_id, author_name,
          cosmic_json, weather_json, location_json,
          initial_notes, outcome_note, outcome_rating,
          updated_hlc, deleted_hlc
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
        ON CONFLICT(entry_id) DO UPDATE SET
          timestamp_ms = excluded.timestamp_ms,
          action = excluded.action,
          title = excluded.title,
          crop_id = excluded.crop_id,
          prep_code = excluded.prep_code,
          bed_name = excluded.bed_name,
          parent_entry_id = excluded.parent_entry_id,
          quality = excluded.quality,
          initial_notes = excluded.initial_notes,
          outcome_note = excluded.outcome_note,
          outcome_rating = excluded.outcome_rating,
          updated_hlc = excluded.updated_hlc,
          deleted_hlc = NULL
        ''',
        [
          entry.id,
          entry.timestamp.toUtc().millisecondsSinceEpoch,
          entry.action.name,
          entry.title,
          entry.cropId,
          entry.prepCode,
          entry.bedName,
          entry.parentEntryId,
          entry.quality.name,
          effectiveAuthorId,
          effectiveAuthorName,
          jsonEncode(entry.cosmicSnapshot.toJson()),
          entry.weatherSnapshot != null
              ? jsonEncode(entry.weatherSnapshot!.toJson())
              : null,
          entry.location != null ? jsonEncode(entry.location!.toJson()) : null,
          entry.notes,
          entry.outcomeNote,
          entry.outcomeRating,
          hlc,
        ],
      );

      final fields = <String, Object?>{
        'action': entry.action.name,
        'title': entry.title,
        'crop_id': entry.cropId,
        'prep_code': entry.prepCode,
        'bed_name': entry.bedName,
        'parent_entry_id': entry.parentEntryId,
        'quality': entry.quality.name,
        'initial_notes': entry.notes,
        'outcome_note': entry.outcomeNote,
        'outcome_rating': entry.outcomeRating,
        'deleted_hlc': null,
      };
      for (final item in fields.entries) {
        _upsertFieldLww(db, entry.id, item.key, item.value, hlc);
      }

      for (final note in seededNotes) {
        _upsertNoteRow(db, note);
      }

      for (final attachment in entry.attachments) {
        _upsertAttachmentRow(db, attachment);
      }

      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }

    if (entry.bedName != null && entry.bedName!.trim().isNotEmpty) {
      addBedName(entry.bedName!, hlcOverride: hlc);
    }

    final saved = getEntry(entry.id, shardKey: shardKey) ?? entry;
    _syncPlantingIndexForEntry(saved, hlc: hlc);
    return saved;
  }

  void _upsertFieldLww(
    Database db,
    String entryId,
    String fieldName,
    Object? value,
    String hlc,
  ) {
    db.execute(
      '''
      INSERT INTO entry_field_lww (entry_id, field_name, value_json, updated_hlc)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(entry_id, field_name) DO UPDATE SET
        value_json = excluded.value_json,
        updated_hlc = excluded.updated_hlc
      WHERE excluded.updated_hlc >= entry_field_lww.updated_hlc
      ''',
      [entryId, fieldName, jsonEncode(value), hlc],
    );
  }

  void _upsertNoteRow(Database db, JournalNote note) {
    db.execute(
      '''
      INSERT INTO journal_notes (
        note_id, entry_id, timestamp_ms, author_id, author_name,
        kind, body, outcome_rating, updated_hlc, deleted_hlc
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(note_id) DO UPDATE SET
        body = excluded.body,
        outcome_rating = excluded.outcome_rating,
        updated_hlc = excluded.updated_hlc,
        deleted_hlc = excluded.deleted_hlc
      WHERE excluded.updated_hlc >= journal_notes.updated_hlc
      ''',
      [
        note.id,
        note.entryId,
        note.timestamp.toUtc().millisecondsSinceEpoch,
        note.authorId,
        note.authorName,
        note.kind.name,
        note.body,
        note.outcomeRating,
        note.updatedHlc,
        note.deletedHlc,
      ],
    );
  }

  void _upsertAttachmentRow(Database db, JournalAttachment attachment) {
    db.execute(
      '''
      INSERT INTO journal_attachments (
        attachment_id, entry_id, note_id, media_sha256, mime_type,
        width, height, caption, author_id, author_name, timestamp_ms,
        thumbnail_bytes, updated_hlc, deleted_hlc
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(attachment_id) DO UPDATE SET
        caption = excluded.caption,
        thumbnail_bytes = COALESCE(excluded.thumbnail_bytes, journal_attachments.thumbnail_bytes),
        updated_hlc = excluded.updated_hlc,
        deleted_hlc = excluded.deleted_hlc
      WHERE excluded.updated_hlc >= journal_attachments.updated_hlc
      ''',
      [
        attachment.id,
        attachment.entryId,
        attachment.noteId,
        attachment.mediaSha256,
        attachment.mimeType,
        attachment.width,
        attachment.height,
        attachment.caption,
        attachment.authorId,
        attachment.authorName,
        attachment.timestamp.toUtc().millisecondsSinceEpoch,
        attachment.thumbnailBytes,
        attachment.updatedHlc,
        attachment.deletedHlc,
      ],
    );
  }

  File _mediaFileForAttachment(JournalAttachment attachment) {
    final fileName = '${attachment.mediaSha256}.${attachment.fileExtension}';
    if (!_mediaFileNamePattern.hasMatch(fileName)) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'Must be a canonical content-addressed media filename',
      );
    }
    return File(p.join(rootDirectory.path, 'media', p.basename(fileName)));
  }

  /// Verifies and persists full-resolution [fullBytes] for [attachment] under
  /// `media/<sha256>.<ext>`.
  ///
  /// Throws a [FormatException] if [fullBytes] does not match [attachment]'s
  /// magic-byte format or SHA-256 content digest.
  void saveMediaBytesForAttachment(
    JournalAttachment attachment,
    Uint8List fullBytes,
  ) {
    _checkNotClosed();
    if (!attachment.verifyBytes(fullBytes)) {
      throw FormatException(
        'Attachment bytes failed SHA-256 or magic-byte verification for ${attachment.mediaSha256}',
      );
    }
    final target = _mediaFileForAttachment(attachment);
    if (target.existsSync()) return;
    target.parent.createSync(recursive: true);
    final tmp = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    tmp.writeAsBytesSync(fullBytes, flush: true);
    tmp.renameSync(target.path);
  }

  /// Reads and verifies the local full-resolution media bytes for [attachment],
  /// or returns `null` if the full-resolution file is not cached on disk.
  Uint8List? readLocalMediaBytes(JournalAttachment attachment) {
    _checkNotClosed();
    final file = _mediaFileForAttachment(attachment);
    if (!file.existsSync()) return null;
    final bytes = file.readAsBytesSync();
    if (!attachment.verifyBytes(bytes)) return null;
    return bytes;
  }

  /// Lists all local content-addressed media blob paths (`media/<sha256>.<ext>`)
  /// stored on disk, sorted alphabetically.
  List<String> listLocalMediaBlobNames() {
    _checkNotClosed();
    final mediaDir = Directory(p.join(rootDirectory.path, 'media'));
    if (!mediaDir.existsSync()) return const [];
    final blobs = <String>[];
    for (final entity in mediaDir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final base = p.basename(entity.path);
      if (_mediaFileNamePattern.hasMatch(base)) {
        blobs.add('media/$base');
      }
    }
    blobs.sort();
    return blobs;
  }

  /// Reads raw bytes for a canonical `media/<sha256>.<ext>` blob path from local disk.
  Uint8List? readLocalMediaBlobByName(String blobName) {
    _checkNotClosed();
    if (!blobName.startsWith('media/')) return null;
    final base = p.basename(blobName.substring('media/'.length));
    if (!_mediaFileNamePattern.hasMatch(base)) return null;
    final file = File(p.join(rootDirectory.path, 'media', base));
    if (!file.existsSync()) return null;
    return file.readAsBytesSync();
  }

  /// Attaches a photo ([fullBytes] + optional [thumbnailBytes]) to [entryId]
  /// in its monthly SQLite shard and persists the full-resolution image in
  /// `media/<sha256>.<ext>`.
  FieldJournalEntry? attachPhotoToEntry({
    required String entryId,
    String? shardKey,
    String? noteId,
    required Uint8List fullBytes,
    Uint8List? thumbnailBytes,
    int? width,
    int? height,
    String caption = '',
    String? authorId,
    String? authorName,
    DateTime? timestamp,
    String? attachmentId,
  }) {
    _checkNotClosed();
    final resolvedShard = shardKey ?? _findShardKeyForEntry(entryId);
    if (resolvedShard == null || !hasLocalShard(resolvedShard)) return null;

    final hlc = _nextHlc().toCanonicalString();
    final now = timestamp ?? DateTime.now();
    final resolvedAuthorId = (authorId != null && authorId.trim().isNotEmpty)
        ? authorId.trim()
        : _localActorId;
    final resolvedAuthorName =
        (authorName != null && authorName.trim().isNotEmpty)
        ? authorName.trim()
        : _localAuthorName;

    final attachment = JournalAttachment.fromRawBytes(
      id: attachmentId,
      entryId: entryId,
      noteId: noteId,
      fullBytes: fullBytes,
      thumbnailBytes: thumbnailBytes,
      width: width,
      height: height,
      caption: caption,
      authorId: resolvedAuthorId,
      authorName: resolvedAuthorName,
      timestamp: now,
      updatedHlc: hlc,
    );

    saveMediaBytesForAttachment(attachment, fullBytes);

    final db = _openOrTouchShard(resolvedShard, createIfMissing: false);
    db.execute('BEGIN IMMEDIATE');
    try {
      _upsertAttachmentRow(db, attachment);
      _rematerializeEntryFromFieldLww(db, entryId);
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }

    return getEntry(entryId, shardKey: resolvedShard);
  }

  void _syncPlantingIndexForEntry(
    FieldJournalEntry entry, {
    required String hlc,
  }) {
    if (!entry.action.isPlantingBatch) return;
    _metaDb.execute(
      '''
      INSERT INTO planting_index (
        entry_id, shard_key, timestamp_ms, action, title,
        crop_id, bed_name, quality, cosmic_summary, updated_hlc, deleted_hlc
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(entry_id) DO UPDATE SET
        shard_key = excluded.shard_key,
        timestamp_ms = excluded.timestamp_ms,
        action = excluded.action,
        title = excluded.title,
        crop_id = excluded.crop_id,
        bed_name = excluded.bed_name,
        quality = excluded.quality,
        cosmic_summary = excluded.cosmic_summary,
        updated_hlc = excluded.updated_hlc,
        deleted_hlc = excluded.deleted_hlc
      WHERE excluded.updated_hlc >= planting_index.updated_hlc
      ''',
      [
        entry.id,
        entry.shardKey,
        entry.timestamp.toUtc().millisecondsSinceEpoch,
        entry.action.name,
        entry.title,
        entry.cropId,
        entry.bedName,
        entry.quality.name,
        entry.cosmicSnapshot.rhythmBadgeLabel,
        hlc,
        entry.deletedHlc,
      ],
    );
  }

  /// Appends or updates a collaborative [JournalNote] on an existing entry without
  /// overwriting notes written by other garden members.
  FieldJournalEntry? addNoteToEntry({
    required String entryId,
    String? shardKey,
    required String body,
    JournalNoteKind kind = JournalNoteKind.observation,
    int? outcomeRating,
    String? authorId,
    String? authorName,
    DateTime? timestamp,
    String? noteId,
  }) {
    _checkNotClosed();
    final resolvedShard = shardKey ?? _findShardKeyForEntry(entryId);
    if (resolvedShard == null || !hasLocalShard(resolvedShard)) return null;

    final hlc = _nextHlc().toCanonicalString();
    final now = timestamp ?? DateTime.now();
    final resolvedAuthorId = (authorId != null && authorId.trim().isNotEmpty)
        ? authorId.trim()
        : _localActorId;
    final resolvedAuthorName =
        (authorName != null && authorName.trim().isNotEmpty)
        ? authorName.trim()
        : _localAuthorName;
    final resolvedNoteId = (noteId != null && noteId.trim().isNotEmpty)
        ? noteId.trim()
        : 'note_${now.toUtc().microsecondsSinceEpoch}_$resolvedAuthorId';

    final note = JournalNote(
      id: resolvedNoteId,
      entryId: entryId,
      timestamp: now,
      authorId: resolvedAuthorId,
      authorName: resolvedAuthorName,
      kind: kind,
      body: body.trim(),
      outcomeRating: outcomeRating,
      updatedHlc: hlc,
    );

    final db = _openOrTouchShard(resolvedShard, createIfMissing: false);
    db.execute('BEGIN IMMEDIATE');
    try {
      _upsertNoteRow(db, note);
      if (kind == JournalNoteKind.outcome || outcomeRating != null) {
        if (body.trim().isNotEmpty) {
          _upsertFieldLww(db, entryId, 'outcome_note', body.trim(), hlc);
        }
        if (outcomeRating != null) {
          _upsertFieldLww(db, entryId, 'outcome_rating', outcomeRating, hlc);
        }
      }
      _rematerializeEntryFromFieldLww(db, entryId);
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }

    return getEntry(entryId, shardKey: resolvedShard);
  }

  /// Soft-deletes [entryId] via an HLC tombstone so the deletion propagates on sync.
  bool deleteEntry(String entryId, {String? shardKey}) {
    _checkNotClosed();
    final resolvedShard = shardKey ?? _findShardKeyForEntry(entryId);
    if (resolvedShard == null || !hasLocalShard(resolvedShard)) return false;

    final hlc = _nextHlc().toCanonicalString();
    final db = _openOrTouchShard(resolvedShard, createIfMissing: false);
    db.execute('BEGIN IMMEDIATE');
    try {
      _upsertFieldLww(db, entryId, 'deleted_hlc', hlc, hlc);
      db.execute(
        '''
        UPDATE journal_entries
        SET deleted_hlc = ?, updated_hlc = ?
        WHERE entry_id = ?
        ''',
        [hlc, hlc, entryId],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }

    _metaDb.execute(
      '''
      UPDATE planting_index
      SET deleted_hlc = ?, updated_hlc = ?
      WHERE entry_id = ?
      ''',
      [hlc, hlc, entryId],
    );
    return true;
  }

  String? _findShardKeyForEntry(String entryId) {
    final indexRows = _metaDb.select(
      'SELECT shard_key FROM planting_index WHERE entry_id = ?',
      [entryId],
    );
    if (indexRows.isNotEmpty) {
      return indexRows.first['shard_key'] as String;
    }
    for (final key in listLocalShardKeys()) {
      final db = _openOrTouchShard(key, createIfMissing: false);
      final rows = db.select(
        'SELECT 1 FROM journal_entries WHERE entry_id = ? LIMIT 1',
        [entryId],
      );
      if (rows.isNotEmpty) return key;
    }
    return null;
  }

  /// Retrieves a single [FieldJournalEntry] by [entryId], or `null` if absent or deleted.
  FieldJournalEntry? getEntry(String entryId, {String? shardKey}) {
    _checkNotClosed();
    final resolvedShard = shardKey ?? _findShardKeyForEntry(entryId);
    if (resolvedShard == null || !hasLocalShard(resolvedShard)) return null;
    final db = _openOrTouchShard(resolvedShard, createIfMissing: false);
    final rows = db.select(
      '''
      SELECT * FROM journal_entries
      WHERE entry_id = ? AND deleted_hlc IS NULL
      ''',
      [entryId],
    );
    if (rows.isEmpty) return null;
    final notesMap = _loadNotesForEntries(db, [entryId]);
    final attachmentsMap = _loadAttachmentsForEntries(db, [entryId]);
    return _entryFromRow(
      rows.first,
      notesMap[entryId] ?? const [],
      attachmentsMap[entryId] ?? const [],
    );
  }

  /// Loads only the journal entries within `[start, end]` by querying only the
  /// intersecting monthly SQLite shards (`YYYY-MM.sqlite`).
  List<FieldJournalEntry> loadRange(DateTime start, DateTime end) {
    _checkNotClosed();
    final minTime = start.isBefore(end) ? start : end;
    final maxTime = start.isBefore(end) ? end : start;
    final minMs = minTime.toUtc().millisecondsSinceEpoch;
    final maxMs = maxTime.toUtc().millisecondsSinceEpoch;

    final results = <FieldJournalEntry>[];
    final keys = shardKeysInRange(minTime, maxTime);
    for (final key in keys.reversed) {
      if (!hasLocalShard(key)) continue;
      final db = _openOrTouchShard(key, createIfMissing: false);
      final rows = db.select(
        '''
        SELECT * FROM journal_entries
        WHERE deleted_hlc IS NULL
          AND timestamp_ms >= ? AND timestamp_ms <= ?
        ORDER BY timestamp_ms DESC
        ''',
        [minMs, maxMs],
      );
      if (rows.isEmpty) continue;
      final ids = [for (final r in rows) r['entry_id'] as String];
      final notesByEntry = _loadNotesForEntries(db, ids);
      final attachmentsByEntry = _loadAttachmentsForEntries(db, ids);
      for (final row in rows) {
        final id = row['entry_id'] as String;
        results.add(
          _entryFromRow(
            row,
            notesByEntry[id] ?? const [],
            attachmentsByEntry[id] ?? const [],
          ),
        );
      }
    }
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }

  /// Loads up to [limit] journal entries newest-first, walking monthly shards
  /// lazily and stopping as soon as [limit] entries are collected.
  List<FieldJournalEntry> loadRecentPage({int limit = 25, DateTime? before}) {
    _checkNotClosed();
    if (limit <= 0) return const [];
    final beforeMs = before?.toUtc().millisecondsSinceEpoch;
    final results = <FieldJournalEntry>[];

    for (final key in listLocalShardKeys()) {
      if (results.length >= limit) break;
      final remaining = limit - results.length;
      final db = _openOrTouchShard(key, createIfMissing: false);
      final ResultSet rows;
      if (beforeMs != null) {
        rows = db.select(
          '''
          SELECT * FROM journal_entries
          WHERE deleted_hlc IS NULL AND timestamp_ms < ?
          ORDER BY timestamp_ms DESC
          LIMIT ?
          ''',
          [beforeMs, remaining],
        );
      } else {
        rows = db.select(
          '''
          SELECT * FROM journal_entries
          WHERE deleted_hlc IS NULL
          ORDER BY timestamp_ms DESC
          LIMIT ?
          ''',
          [remaining],
        );
      }
      if (rows.isEmpty) continue;
      final ids = [for (final r in rows) r['entry_id'] as String];
      final notesByEntry = _loadNotesForEntries(db, ids);
      final attachmentsByEntry = _loadAttachmentsForEntries(db, ids);
      for (final row in rows) {
        final id = row['entry_id'] as String;
        results.add(
          _entryFromRow(
            row,
            notesByEntry[id] ?? const [],
            attachmentsByEntry[id] ?? const [],
          ),
        );
      }
    }
    return results;
  }

  Map<String, List<JournalAttachment>> _loadAttachmentsForEntries(
    Database db,
    List<String> entryIds,
  ) {
    if (entryIds.isEmpty) return const {};
    final placeholders = List.filled(entryIds.length, '?').join(', ');
    final rows = db.select('''
      SELECT * FROM journal_attachments
      WHERE entry_id IN ($placeholders)
        AND deleted_hlc IS NULL
      ORDER BY timestamp_ms ASC, updated_hlc ASC
      ''', entryIds);
    final grouped = <String, List<JournalAttachment>>{};
    for (final row in rows) {
      final entryId = row['entry_id'] as String;
      final mimeRaw = row['mime_type'] as String? ?? 'image/jpeg';
      final format =
          JournalImageFormat.tryFromMimeOrExtension(mimeRaw) ??
          JournalImageFormat.jpeg;
      final rawThumb = row['thumbnail_bytes'];
      final Uint8List? thumbBytes = switch (rawThumb) {
        final Uint8List b => b,
        final List<int> l => Uint8List.fromList(l),
        _ => null,
      };
      final attachment = JournalAttachment(
        id: row['attachment_id'] as String,
        entryId: entryId,
        noteId: row['note_id'] as String?,
        mediaSha256: row['media_sha256'] as String,
        format: format,
        width: row['width'] as int?,
        height: row['height'] as int?,
        caption: row['caption'] as String? ?? '',
        authorId: row['author_id'] as String,
        authorName: row['author_name'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          row['timestamp_ms'] as int,
          isUtc: true,
        ).toLocal(),
        thumbnailBytes: thumbBytes,
        updatedHlc: row['updated_hlc'] as String,
        deletedHlc: row['deleted_hlc'] as String?,
      );
      (grouped[entryId] ??= <JournalAttachment>[]).add(attachment);
    }
    return grouped;
  }

  Map<String, List<JournalNote>> _loadNotesForEntries(
    Database db,
    List<String> entryIds,
  ) {
    if (entryIds.isEmpty) return const {};
    final placeholders = List.filled(entryIds.length, '?').join(', ');
    final rows = db.select('''
      SELECT * FROM journal_notes
      WHERE entry_id IN ($placeholders)
        AND deleted_hlc IS NULL
      ORDER BY timestamp_ms ASC, updated_hlc ASC
      ''', entryIds);
    final grouped = <String, List<JournalNote>>{};
    for (final row in rows) {
      final entryId = row['entry_id'] as String;
      final kindRaw = row['kind'] as String;
      JournalNoteKind kind = JournalNoteKind.fieldNote;
      for (final candidate in JournalNoteKind.values) {
        if (candidate.name == kindRaw) {
          kind = candidate;
          break;
        }
      }
      final note = JournalNote(
        id: row['note_id'] as String,
        entryId: entryId,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          row['timestamp_ms'] as int,
          isUtc: true,
        ).toLocal(),
        authorId: row['author_id'] as String,
        authorName: row['author_name'] as String,
        kind: kind,
        body: row['body'] as String,
        outcomeRating: row['outcome_rating'] as int?,
        updatedHlc: row['updated_hlc'] as String,
        deletedHlc: row['deleted_hlc'] as String?,
      );
      (grouped[entryId] ??= <JournalNote>[]).add(note);
    }
    return grouped;
  }

  FieldJournalEntry _entryFromRow(
    Row row,
    List<JournalNote> notes, [
    List<JournalAttachment> attachments = const [],
  ]) {
    final actionRaw = row['action'] as String;
    FieldJournalAction action = FieldJournalAction.sowSeeds;
    for (final candidate in FieldJournalAction.values) {
      if (candidate.name == actionRaw) {
        action = candidate;
        break;
      }
    }

    final qualityRaw = row['quality'] as String;
    PlantQuality quality = PlantQuality.root;
    for (final candidate in PlantQuality.values) {
      if (candidate.name == qualityRaw) {
        quality = candidate;
        break;
      }
    }

    final cosmicMap =
        jsonDecode(row['cosmic_json'] as String) as Map<String, Object?>;
    final cosmicSnapshot = FieldJournalCosmicSnapshot.fromJson(cosmicMap);

    FieldJournalWeatherSnapshot? weatherSnapshot;
    if (row['weather_json'] case final String weatherStr
        when weatherStr.isNotEmpty) {
      weatherSnapshot = FieldJournalWeatherSnapshot.fromJson(
        jsonDecode(weatherStr) as Map<String, Object?>,
      );
    }

    SavedLocation? location;
    if (row['location_json'] case final String locStr when locStr.isNotEmpty) {
      location = SavedLocation.fromJson(
        jsonDecode(locStr) as Map<String, Object?>,
      );
    }

    // Synthesize field notes & outcome from collaborative noteThread when present.
    final fieldNotesList = notes
        .where((n) => n.kind != JournalNoteKind.outcome && n.body.isNotEmpty)
        .toList(growable: false);
    final outcomeNotesList = notes
        .where(
          (n) =>
              (n.kind == JournalNoteKind.outcome || n.outcomeRating != null) &&
              n.body.isNotEmpty,
        )
        .toList(growable: false);

    String synthesizedNotes = row['initial_notes'] as String? ?? '';
    if (fieldNotesList.isNotEmpty) {
      synthesizedNotes = fieldNotesList.length == 1
          ? fieldNotesList.first.body
          : fieldNotesList.map((n) => '${n.authorName}: ${n.body}').join('\n');
    }

    String synthesizedOutcome = row['outcome_note'] as String? ?? '';
    if (outcomeNotesList.isNotEmpty) {
      synthesizedOutcome = outcomeNotesList.length == 1
          ? outcomeNotesList.first.body
          : outcomeNotesList
                .map((n) => '${n.authorName}: ${n.body}')
                .join('\n');
    }

    int? effectiveRating = row['outcome_rating'] as int?;
    for (int i = notes.length - 1; i >= 0; i--) {
      if (notes[i].outcomeRating != null) {
        effectiveRating = notes[i].outcomeRating;
        break;
      }
    }

    return FieldJournalEntry(
      id: row['entry_id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        row['timestamp_ms'] as int,
        isUtc: true,
      ).toLocal(),
      action: action,
      title: row['title'] as String,
      cropId: row['crop_id'] as String?,
      prepCode: row['prep_code'] as String?,
      bedName: row['bed_name'] as String?,
      parentEntryId: row['parent_entry_id'] as String?,
      quality: quality,
      authorId: row['author_id'] as String,
      authorName: row['author_name'] as String,
      cosmicSnapshot: cosmicSnapshot,
      weatherSnapshot: weatherSnapshot,
      location: location,
      notes: synthesizedNotes,
      outcomeNote: synthesizedOutcome,
      outcomeRating: effectiveRating,
      noteThread: notes,
      attachments: attachments,
      updatedHlc: row['updated_hlc'] as String,
      deletedHlc: row['deleted_hlc'] as String?,
    );
  }

  /// Merges a remote monthly shard SQLite file at [remoteFilePath] into local
  /// shard [shardKey] using SQLite `ATTACH DATABASE` and per-field + per-note
  /// HLC CRDT semantics.
  void mergeRemoteShardFile(String shardKey, String remoteFilePath) {
    _checkNotClosed();
    validateShardKey(shardKey);
    _verifySqliteFileIntegrity(remoteFilePath);

    final db = _openOrTouchShard(shardKey, createIfMissing: true);
    final attachStmt = db.prepare('ATTACH DATABASE ? AS remote');
    try {
      attachStmt.execute([remoteFilePath]);
    } finally {
      attachStmt.dispose();
    }

    try {
      db.execute('BEGIN IMMEDIATE');
      try {
        // 1. Insert any base entries missing locally.
        db.execute('''
          INSERT OR IGNORE INTO main.journal_entries (
            entry_id, timestamp_ms, action, title, crop_id, prep_code,
            bed_name, parent_entry_id, quality, author_id, author_name,
            cosmic_json, weather_json, location_json,
            initial_notes, outcome_note, outcome_rating,
            updated_hlc, deleted_hlc
          )
          SELECT
            entry_id, timestamp_ms, action, title, crop_id, prep_code,
            bed_name, parent_entry_id, quality, author_id, author_name,
            cosmic_json, weather_json, location_json,
            initial_notes, outcome_note, outcome_rating,
            updated_hlc, deleted_hlc
          FROM remote.journal_entries
        ''');

        // 2. Merge per-field LWW CRDT state.
        db.execute('''
          INSERT INTO main.entry_field_lww (entry_id, field_name, value_json, updated_hlc)
          SELECT entry_id, field_name, value_json, updated_hlc
          FROM remote.entry_field_lww WHERE true
          ON CONFLICT(entry_id, field_name) DO UPDATE SET
            value_json = excluded.value_json,
            updated_hlc = excluded.updated_hlc
          WHERE excluded.updated_hlc > main.entry_field_lww.updated_hlc
        ''');

        // 3. Merge collaborative journal_notes (append-only union + per-note LWW).
        db.execute('''
          INSERT INTO main.journal_notes (
            note_id, entry_id, timestamp_ms, author_id, author_name,
            kind, body, outcome_rating, updated_hlc, deleted_hlc
          )
          SELECT
            note_id, entry_id, timestamp_ms, author_id, author_name,
            kind, body, outcome_rating, updated_hlc, deleted_hlc
          FROM remote.journal_notes WHERE true
          ON CONFLICT(note_id) DO UPDATE SET
            body = excluded.body,
            outcome_rating = excluded.outcome_rating,
            updated_hlc = excluded.updated_hlc,
            deleted_hlc = excluded.deleted_hlc
          WHERE excluded.updated_hlc > main.journal_notes.updated_hlc
        ''');

        // 3b. Merge photo attachments (append-only union + per-attachment LWW).
        db.execute('''
          INSERT INTO main.journal_attachments (
            attachment_id, entry_id, note_id, media_sha256, mime_type,
            width, height, caption, author_id, author_name, timestamp_ms,
            thumbnail_bytes, updated_hlc, deleted_hlc
          )
          SELECT
            attachment_id, entry_id, note_id, media_sha256, mime_type,
            width, height, caption, author_id, author_name, timestamp_ms,
            thumbnail_bytes, updated_hlc, deleted_hlc
          FROM remote.journal_attachments WHERE true
          ON CONFLICT(attachment_id) DO UPDATE SET
            caption = excluded.caption,
            thumbnail_bytes = COALESCE(excluded.thumbnail_bytes, main.journal_attachments.thumbnail_bytes),
            updated_hlc = excluded.updated_hlc,
            deleted_hlc = excluded.deleted_hlc
          WHERE excluded.updated_hlc > main.journal_attachments.updated_hlc
        ''');

        // 4. Rematerialize all entries in this shard from winning field LWW values.
        final entryIdsRows = db.select(
          'SELECT entry_id FROM main.journal_entries',
        );
        for (final row in entryIdsRows) {
          final id = row['entry_id'] as String;
          _rematerializeEntryFromFieldLww(db, id);
        }

        // 5. Advance local HLC past the maximum remote HLC observed.
        final maxHlcRows = db.select('''
          SELECT MAX(hlc) AS max_hlc FROM (
            SELECT MAX(updated_hlc) AS hlc FROM main.entry_field_lww
            UNION ALL
            SELECT MAX(updated_hlc) AS hlc FROM main.journal_notes
            UNION ALL
            SELECT MAX(updated_hlc) AS hlc FROM main.journal_attachments
            UNION ALL
            SELECT MAX(updated_hlc) AS hlc FROM main.journal_entries
          )
        ''');
        if (maxHlcRows.isNotEmpty) {
          _observeHlcString(maxHlcRows.first['max_hlc'] as String?);
        }

        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.execute('DETACH DATABASE remote');
    }

    // Update cross-month planting_index and beds in garden_meta.sqlite.
    final activeRows = db.select('SELECT * FROM journal_entries');
    final allIds = [for (final r in activeRows) r['entry_id'] as String];
    final notesByEntry = _loadNotesForEntries(db, allIds);
    final attachmentsByEntry = _loadAttachmentsForEntries(db, allIds);
    for (final row in activeRows) {
      final id = row['entry_id'] as String;
      final entry = _entryFromRow(
        row,
        notesByEntry[id] ?? const [],
        attachmentsByEntry[id] ?? const [],
      );
      if (entry.bedName != null && entry.bedName!.trim().isNotEmpty) {
        addBedName(entry.bedName!, hlcOverride: entry.updatedHlc);
      }
      _syncPlantingIndexForEntry(entry, hlc: entry.updatedHlc);
    }
  }

  void _rematerializeEntryFromFieldLww(Database db, String entryId) {
    final fieldRows = db.select(
      'SELECT field_name, value_json, updated_hlc FROM entry_field_lww WHERE entry_id = ?',
      [entryId],
    );
    if (fieldRows.isEmpty) return;

    final values = <String, Object?>{};
    String maxHlc = '';
    for (final row in fieldRows) {
      final name = row['field_name'] as String;
      final val = jsonDecode(row['value_json'] as String);
      final hlc = row['updated_hlc'] as String;
      values[name] = val;
      if (hlc.compareTo(maxHlc) > 0) maxHlc = hlc;
    }

    final noteMaxRows = db.select(
      'SELECT MAX(updated_hlc) AS m FROM journal_notes WHERE entry_id = ?',
      [entryId],
    );
    if (noteMaxRows.isNotEmpty && noteMaxRows.first['m'] is String) {
      final noteMax = noteMaxRows.first['m'] as String;
      if (noteMax.compareTo(maxHlc) > 0) maxHlc = noteMax;
    }

    final attMaxRows = db.select(
      'SELECT MAX(updated_hlc) AS m FROM journal_attachments WHERE entry_id = ?',
      [entryId],
    );
    if (attMaxRows.isNotEmpty && attMaxRows.first['m'] is String) {
      final attMax = attMaxRows.first['m'] as String;
      if (attMax.compareTo(maxHlc) > 0) maxHlc = attMax;
    }

    db.execute(
      '''
      UPDATE journal_entries SET
        action = COALESCE(?, action),
        title = COALESCE(?, title),
        crop_id = ?,
        prep_code = ?,
        bed_name = ?,
        parent_entry_id = ?,
        quality = COALESCE(?, quality),
        initial_notes = COALESCE(?, initial_notes),
        outcome_note = COALESCE(?, outcome_note),
        outcome_rating = ?,
        deleted_hlc = ?,
        updated_hlc = CASE WHEN ? > updated_hlc THEN ? ELSE updated_hlc END
      WHERE entry_id = ?
      ''',
      [
        values['action'] as String?,
        values['title'] as String?,
        values['crop_id'] as String?,
        values['prep_code'] as String?,
        values['bed_name'] as String?,
        values['parent_entry_id'] as String?,
        values['quality'] as String?,
        values['initial_notes'] as String?,
        values['outcome_note'] as String?,
        values['outcome_rating'] as int?,
        values['deleted_hlc'] as String?,
        maxHlc,
        maxHlc,
        entryId,
      ],
    );
  }

  /// Merges a remote `garden_meta.sqlite` snapshot at [remoteMetaPath] into the
  /// local `garden_meta.sqlite` via `ATTACH DATABASE`.
  void mergeRemoteMetaFile(String remoteMetaPath) {
    _checkNotClosed();
    _verifySqliteFileIntegrity(remoteMetaPath);

    final attachStmt = _metaDb.prepare('ATTACH DATABASE ? AS remote_meta');
    try {
      attachStmt.execute([remoteMetaPath]);
    } finally {
      attachStmt.dispose();
    }

    try {
      _metaDb.execute('BEGIN IMMEDIATE');
      try {
        _metaDb.execute('''
          INSERT INTO main.garden_members (actor_id, display_name, color_value, updated_hlc)
          SELECT actor_id, display_name, color_value, updated_hlc
          FROM remote_meta.garden_members WHERE true
          ON CONFLICT(actor_id) DO UPDATE SET
            display_name = excluded.display_name,
            color_value = excluded.color_value,
            updated_hlc = excluded.updated_hlc
          WHERE excluded.updated_hlc > main.garden_members.updated_hlc
        ''');

        _metaDb.execute('''
          INSERT INTO main.garden_beds (bed_name, updated_hlc, deleted_hlc)
          SELECT bed_name, updated_hlc, deleted_hlc
          FROM remote_meta.garden_beds WHERE true
          ON CONFLICT(bed_name) DO UPDATE SET
            updated_hlc = excluded.updated_hlc,
            deleted_hlc = excluded.deleted_hlc
          WHERE excluded.updated_hlc > main.garden_beds.updated_hlc
        ''');

        _metaDb.execute('''
          INSERT INTO main.planting_index (
            entry_id, shard_key, timestamp_ms, action, title,
            crop_id, bed_name, quality, cosmic_summary, updated_hlc, deleted_hlc
          )
          SELECT
            entry_id, shard_key, timestamp_ms, action, title,
            crop_id, bed_name, quality, cosmic_summary, updated_hlc, deleted_hlc
          FROM remote_meta.planting_index WHERE true
          ON CONFLICT(entry_id) DO UPDATE SET
            shard_key = excluded.shard_key,
            timestamp_ms = excluded.timestamp_ms,
            action = excluded.action,
            title = excluded.title,
            crop_id = excluded.crop_id,
            bed_name = excluded.bed_name,
            quality = excluded.quality,
            cosmic_summary = excluded.cosmic_summary,
            updated_hlc = excluded.updated_hlc,
            deleted_hlc = excluded.deleted_hlc
          WHERE excluded.updated_hlc > main.planting_index.updated_hlc
        ''');

        _metaDb.execute('COMMIT');
      } catch (_) {
        _metaDb.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      _metaDb.execute('DETACH DATABASE remote_meta');
    }
  }

  static void _verifySqliteFileIntegrity(String filePath) {
    final file = File(filePath);
    if (!file.existsSync() || file.lengthSync() < 100) {
      throw FormatException('Invalid or truncated SQLite file', filePath);
    }
    final probe = sqlite3.open(filePath, mode: OpenMode.readOnly);
    try {
      final check = probe.select('PRAGMA quick_check');
      if (check.isEmpty || check.first.values.first != 'ok') {
        throw FormatException('SQLite quick_check failed', filePath);
      }
    } finally {
      probe.dispose();
    }
  }

  /// Computes a deterministic 24-hex-character SHA-256 digest of the CRDT state
  /// inside shard [shardKey].
  ///
  /// Any two devices holding the same merged CRDT rows produce the exact same
  /// digest regardless of SQLite B-tree page layout.
  String computeShardDigest(String shardKey) {
    _checkNotClosed();
    validateShardKey(shardKey);
    if (!hasLocalShard(shardKey)) return '0' * 24;
    final db = _openOrTouchShard(shardKey, createIfMissing: false);

    final buffer = StringBuffer();
    final entries = db.select(
      'SELECT entry_id, timestamp_ms, author_id, updated_hlc, deleted_hlc FROM journal_entries ORDER BY entry_id ASC',
    );
    for (final row in entries) {
      buffer.writeln(
        'E:${row['entry_id']}:${row['timestamp_ms']}:${row['author_id']}:${row['updated_hlc']}:${row['deleted_hlc'] ?? ''}',
      );
    }

    final fields = db.select(
      'SELECT entry_id, field_name, value_json, updated_hlc FROM entry_field_lww ORDER BY entry_id ASC, field_name ASC',
    );
    for (final row in fields) {
      buffer.writeln(
        'F:${row['entry_id']}:${row['field_name']}:${row['updated_hlc']}:${row['value_json']}',
      );
    }

    final notes = db.select(
      'SELECT note_id, entry_id, updated_hlc, deleted_hlc, body, outcome_rating FROM journal_notes ORDER BY note_id ASC',
    );
    for (final row in notes) {
      buffer.writeln(
        'N:${row['note_id']}:${row['entry_id']}:${row['updated_hlc']}:${row['deleted_hlc'] ?? ''}:${row['outcome_rating'] ?? ''}:${row['body']}',
      );
    }

    final attachments = db.select(
      'SELECT attachment_id, entry_id, media_sha256, updated_hlc, deleted_hlc, caption FROM journal_attachments ORDER BY attachment_id ASC',
    );
    for (final row in attachments) {
      buffer.writeln(
        'A:${row['attachment_id']}:${row['entry_id']}:${row['media_sha256']}:${row['updated_hlc']}:${row['deleted_hlc'] ?? ''}:${row['caption']}',
      );
    }

    final digest = sha256.convert(utf8.encode(buffer.toString())).toString();
    return digest.substring(0, 24);
  }

  /// Computes a deterministic 24-hex-character SHA-256 digest of the shared CRDT
  /// tables in `garden_meta.sqlite`.
  String computeMetaDigest() {
    _checkNotClosed();
    final buffer = StringBuffer();
    final members = _metaDb.select(
      'SELECT actor_id, display_name, color_value, updated_hlc FROM garden_members ORDER BY actor_id ASC',
    );
    for (final r in members) {
      buffer.writeln(
        'M:${r['actor_id']}:${r['updated_hlc']}:${r['display_name']}:${r['color_value']}',
      );
    }
    final beds = _metaDb.select(
      'SELECT bed_name, updated_hlc, deleted_hlc FROM garden_beds ORDER BY bed_name ASC',
    );
    for (final r in beds) {
      buffer.writeln(
        'B:${r['bed_name']}:${r['updated_hlc']}:${r['deleted_hlc'] ?? ''}',
      );
    }
    final plantings = _metaDb.select(
      'SELECT entry_id, shard_key, updated_hlc, deleted_hlc FROM planting_index ORDER BY entry_id ASC',
    );
    for (final r in plantings) {
      buffer.writeln(
        'P:${r['entry_id']}:${r['shard_key']}:${r['updated_hlc']}:${r['deleted_hlc'] ?? ''}',
      );
    }
    final digest = sha256.convert(utf8.encode(buffer.toString())).toString();
    return digest.substring(0, 24);
  }

  /// Exports a compact, standalone SQLite snapshot of [shardKey] as raw bytes
  /// using `VACUUM INTO`.
  Uint8List exportShardBytes(String shardKey) {
    _checkNotClosed();
    validateShardKey(shardKey);
    final db = _openOrTouchShard(shardKey, createIfMissing: false);
    final tmpPath = p.join(
      rootDirectory.path,
      'export_${shardKey}_${DateTime.now().microsecondsSinceEpoch}.tmp.sqlite',
    );
    final tmpFile = File(tmpPath);
    if (tmpFile.existsSync()) tmpFile.deleteSync();
    final stmt = db.prepare('VACUUM INTO ?');
    try {
      stmt.execute([tmpPath]);
    } finally {
      stmt.dispose();
    }
    try {
      return tmpFile.readAsBytesSync();
    } finally {
      if (tmpFile.existsSync()) tmpFile.deleteSync();
    }
  }

  /// Exports a compact, standalone SQLite snapshot of `garden_meta.sqlite` as raw bytes.
  Uint8List exportMetaBytes() {
    _checkNotClosed();
    final tmpPath = p.join(
      rootDirectory.path,
      'export_meta_${DateTime.now().microsecondsSinceEpoch}.tmp.sqlite',
    );
    final tmpFile = File(tmpPath);
    if (tmpFile.existsSync()) tmpFile.deleteSync();
    final stmt = _metaDb.prepare('VACUUM INTO ?');
    try {
      stmt.execute([tmpPath]);
    } finally {
      stmt.dispose();
    }
    try {
      return tmpFile.readAsBytesSync();
    } finally {
      if (tmpFile.existsSync()) tmpFile.deleteSync();
    }
  }

  /// Whether [blobName] has already been merged into this local store.
  bool isBlobMerged(String blobName) {
    _checkNotClosed();
    final rows = _metaDb.select(
      'SELECT 1 FROM sync_merged_blobs WHERE blob_name = ? LIMIT 1',
      [blobName],
    );
    return rows.isNotEmpty;
  }

  /// Records [blobName] as merged into this local store.
  void markBlobMerged(String blobName) {
    _checkNotClosed();
    _metaDb.execute(
      '''
      INSERT OR REPLACE INTO sync_merged_blobs (blob_name, merged_at_ms)
      VALUES (?, ?)
      ''',
      [blobName, DateTime.now().toUtc().millisecondsSinceEpoch],
    );
  }

  /// Records remote shard blobs discovered during `list('shards/')` that have not
  /// been downloaded yet (for lazy hydration when the user scrolls to that month).
  void updateRemoteShardCatalog(Map<String, List<String>> blobsByShardKey) {
    _checkNotClosed();
    _metaDb.execute('BEGIN IMMEDIATE');
    try {
      _metaDb.execute('DELETE FROM remote_shard_catalog');
      final stmt = _metaDb.prepare(
        'INSERT OR IGNORE INTO remote_shard_catalog (shard_key, blob_name) VALUES (?, ?)',
      );
      try {
        for (final entry in blobsByShardKey.entries) {
          for (final blob in entry.value) {
            stmt.execute([entry.key, blob]);
          }
        }
      } finally {
        stmt.dispose();
      }
      _metaDb.execute('COMMIT');
    } catch (_) {
      _metaDb.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Returns remote shard keys (`YYYY-MM`) known in the cloud catalog that have
  /// not yet been downloaded locally.
  List<String> listUnhydratedRemoteShardKeys() {
    _checkNotClosed();
    final rows = _metaDb.select(
      'SELECT DISTINCT shard_key FROM remote_shard_catalog ORDER BY shard_key DESC',
    );
    final unhydrated = <String>[];
    for (final row in rows) {
      final key = row['shard_key'] as String;
      if (!hasLocalShard(key)) {
        unhydrated.add(key);
      }
    }
    return unhydrated;
  }

  /// Closes all open monthly shard databases and `garden_meta.sqlite`.
  void close() {
    if (_isClosed) return;
    _isClosed = true;
    for (final db in _openShards.values) {
      db.dispose();
    }
    _openShards.clear();
    _metaDb.dispose();
  }
}
