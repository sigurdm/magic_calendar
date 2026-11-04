import 'dart:convert';

import 'field_journal_entry.dart';
import 'garden_plot.dart';

/// Parsed invite link or Google Drive folder reference for joining a shared
/// multi-gardener diary on mobile or desktop.
final class GardenInviteLink {
  /// Google Drive folder ID (`rootFolderId`) hosting the shared SQLite shards.
  final String driveFolderId;

  /// Optional human-readable shared garden name.
  final String? gardenName;

  /// Creates a [GardenInviteLink].
  ///
  /// The [driveFolderId] must be a valid Google Drive file/folder identifier.
  GardenInviteLink({required this.driveFolderId, this.gardenName}) {
    if (!_validDriveIdPattern.hasMatch(driveFolderId)) {
      throw ArgumentError.value(
        driveFolderId,
        'driveFolderId',
        'Must be a valid alphanumeric Google Drive folder ID',
      );
    }
  }

  static final RegExp _validDriveIdPattern = RegExp(r'^[A-Za-z0-9_-]{6,128}$');

  static final RegExp _driveFolderUrlPattern = RegExp(
    r'drive\.google\.com/(?:drive/(?:u/\d+/)?folders/|open\?id=)([A-Za-z0-9_-]{6,128})',
  );

  /// Canonical `magiccalendar://join-garden` URI that can be shared with co-gardeners.
  Uri toUri() => Uri(
    scheme: 'magiccalendar',
    host: 'join-garden',
    queryParameters: <String, String>{
      'driveFolderId': driveFolderId,
      if (gardenName != null && gardenName!.trim().isNotEmpty)
        'name': gardenName!.trim(),
    },
  );

  /// Standard Google Drive web folder URL for opening in the Drive mobile app or browser.
  Uri get driveWebUrl =>
      Uri.https('drive.google.com', '/drive/folders/$driveFolderId');

  /// Formatted shareable invitation message containing both the Google Drive link
  /// and the `magiccalendar://` invite code.
  String formatInviteMessage() {
    final title = (gardenName != null && gardenName!.trim().isNotEmpty)
        ? gardenName!.trim()
        : 'Shared Biodynamic Garden';
    return '🌱 Join "$title" on Magic Calendar!\n'
        'Google Drive Folder: $driveWebUrl\n'
        'App Invite Code: ${toUri()}';
  }

  /// Parses a [GardenInviteLink] from:
  /// - a `magiccalendar://join-garden?driveFolderId=...&name=...` URI,
  /// - a Google Drive folder URL (`https://drive.google.com/drive/folders/<id>`), or
  /// - a bare Google Drive folder ID.
  ///
  /// Returns `null` if [rawInput] does not contain a valid folder identifier.
  static GardenInviteLink? tryParse(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    // 1. Check for magiccalendar://join-garden URI (even if embedded in a multi-line message)
    final magicUriMatch = RegExp(r'magiccalendar://join-garden\?[^\s]+')
        .firstMatch(trimmed);
    final rawCandidate = magicUriMatch?.group(0) ?? trimmed;
    final candidateUriStr = rawCandidate.replaceAll(
      RegExp(r'''[),.;'">\]]+$'''),
      '',
    );
    final parsedUri = Uri.tryParse(candidateUriStr);
    if (parsedUri != null &&
        parsedUri.scheme == 'magiccalendar' &&
        parsedUri.host == 'join-garden') {
      Map<String, String>? queryParams;
      try {
        queryParams = parsedUri.queryParameters;
      } on FormatException {
        queryParams = null;
      }
      if (queryParams != null) {
        final folderId = queryParams['driveFolderId']?.trim();
        final name = queryParams['name']?.trim();
        if (folderId != null && _validDriveIdPattern.hasMatch(folderId)) {
          return GardenInviteLink(
            driveFolderId: folderId,
            gardenName: (name != null && name.isNotEmpty) ? name : null,
          );
        }
      }
    }

    // 2. Check for https://drive.google.com/drive/folders/<id> URL
    final urlMatch = _driveFolderUrlPattern.firstMatch(trimmed);
    if (urlMatch != null) {
      final folderId = urlMatch.group(1)!;
      if (_validDriveIdPattern.hasMatch(folderId)) {
        return GardenInviteLink(driveFolderId: folderId);
      }
    }

    // 3. Check for a bare Google Drive folder ID
    if (_validDriveIdPattern.hasMatch(trimmed)) {
      return GardenInviteLink(driveFolderId: trimmed);
    }

    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GardenInviteLink &&
          driveFolderId == other.driveFolderId &&
          gardenName == other.gardenName;

  @override
  int get hashCode => Object.hash(driveFolderId, gardenName);

  @override
  String toString() =>
      'GardenInviteLink(driveFolderId: $driveFolderId, gardenName: $gardenName)';
}

/// Formats [FieldJournalEntry] records and [GardenPlot] succession/rotation plans
/// into human-readable Markdown/plain-text summaries for sharing via mobile share
/// sheets, messaging apps, email, or clipboard.
final class GardenNoteShareFormatter {
  GardenNoteShareFormatter._();

  static const List<String> _monthShort = [
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

  static String _formatDateTime(DateTime dt) {
    final month = _monthShort[dt.month.clamp(1, 12)];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $month ${dt.year} $hh:$mm';
  }

  /// Formats a single [FieldJournalEntry] into a shareable text card.
  static String formatEntry(FieldJournalEntry entry, {String? gardenName}) {
    final buf = StringBuffer();
    final headerPrefix = (gardenName != null && gardenName.trim().isNotEmpty)
        ? '[${gardenName.trim()}] '
        : '';
    buf.writeln(
      '${entry.action.timelineGlyph} $headerPrefix${entry.title} — ${_formatDateTime(entry.timestamp)}',
    );

    final metaParts = <String>[
      '${entry.action.displayName} (${entry.quality.displayName} Day)',
      if (entry.crop != null) '${entry.crop!.nameEn} / ${entry.crop!.nameDa}',
      if (entry.bedName != null && entry.bedName!.isNotEmpty)
        '📍 ${entry.bedName}',
    ];
    buf.writeln(metaParts.join(' • '));

    final snap = entry.cosmicSnapshot;
    final cosmicParts = <String>[
      '☽ ${snap.rhythmBadgeLabel}',
      snap.moonBadgeLabel,
      if (entry.weatherSnapshot != null &&
          entry.weatherSnapshot!.compactSummary.isNotEmpty)
        entry.weatherSnapshot!.compactSummary,
    ];
    buf.writeln(cosmicParts.join(' • '));

    final notes = entry.activeNotes;
    if (notes.isNotEmpty) {
      for (final note in notes) {
        final author = note.authorName.trim().isNotEmpty
            ? '${note.authorName}: '
            : '';
        buf.writeln('📝 $author${note.body}');
      }
    } else if (entry.notes.trim().isNotEmpty) {
      buf.writeln('📝 ${entry.notes.trim()}');
    }

    if (entry.hasOutcome) {
      final stars = entry.outcomeRating != null
          ? '${"★" * entry.outcomeRating!}${"☆" * (5 - entry.outcomeRating!)}'
          : '';
      final outNote = entry.outcomeNote.trim();
      buf.writeln(
        '🌾 Outcome: $stars${outNote.isNotEmpty ? " — $outNote" : ""}',
      );
    }

    final photos = entry.activeAttachments;
    if (photos.isNotEmpty) {
      buf.writeln('📷 ${photos.length} attached photo(s)');
    }

    return buf.toString().trimRight();
  }

  /// Formats a [GardenPlot]'s status, soil prep, rotation guidance, and
  /// within-season succession plan into a shareable text card.
  static String formatPlotSummary({
    required GardenPlot plot,
    required PlotRotationAssessment rotation,
    required PlotSuccessionPlan successionPlan,
    Iterable<FieldJournalEntry> recentEntries = const [],
  }) {
    final buf = StringBuffer();
    final dims = plot.dimensions.isNotEmpty ? ' (${plot.dimensions})' : '';
    buf.writeln(
      '${plot.plotType.glyph} Plot: ${plot.name}$dims — ${plot.plotType.displayName}',
    );

    if (plot.lastSoilPrepSummary != null &&
        plot.lastSoilPrepSummary!.isNotEmpty) {
      buf.writeln('🌀 Last Soil Prep: ${plot.lastSoilPrepSummary}');
    }

    if (successionPlan.seasonPipelineSummary.isNotEmpty) {
      buf.writeln(
        '🔄 Season Pipeline: ${successionPlan.seasonPipelineSummary}',
      );
    }

    if (rotation.seasonTrail.isNotEmpty) {
      final trailStr = rotation.seasonTrail.take(4).join(' → ');
      buf.writeln('📜 Rotation History: $trailStr');
    }

    buf.writeln('🧭 Rotation Guidance: ${rotation.rotationGuidance}');

    if (successionPlan.candidates.isNotEmpty) {
      final suggestions = successionPlan.candidates
          .take(4)
          .map((c) => c.badgeLabel)
          .join(', ');
      buf.writeln('💡 Next Succession Ideas: $suggestions');
    }

    final entriesList = recentEntries.take(3).toList(growable: false);
    if (entriesList.isNotEmpty) {
      buf.writeln('\nRecent Plot Notes:');
      for (final entry in entriesList) {
        buf.writeln(
          '• ${_formatDateTime(entry.timestamp)} — ${entry.action.timelineGlyph} ${entry.title}',
        );
      }
    }

    return buf.toString().trimRight();
  }

  /// Formats a collection of [FieldJournalEntry] records into a multi-entry
  /// Markdown/text digest for sharing a monthly or plot update.
  static String formatEntriesDigest(
    Iterable<FieldJournalEntry> entries, {
    required String title,
    String? gardenName,
  }) {
    final list = entries.where((e) => !e.isDeleted).toList(growable: false);
    final buf = StringBuffer();
    final gardenHeader = (gardenName != null && gardenName.trim().isNotEmpty)
        ? '${gardenName.trim()} — '
        : '';
    buf.writeln('# 🌱 $gardenHeader$title (${list.length} entries)\n');
    for (final entry in list) {
      buf.writeln(formatEntry(entry));
      buf.writeln('---');
    }
    return buf.toString().trimRight();
  }
}

/// Portable, versioned JSON bundle of [FieldJournalEntry] and [GardenPlot] records
/// that can be shared via any messaging app or file drop and merged into another
/// gardener's Magic Calendar diary with CRDT conflict safety.
final class GardenSharedNoteBundle {
  /// Format discriminator for bundle validation.
  static const String bundleFormat = 'magic_calendar_garden_bundle_v1';

  /// Name of the garden from which the bundle was exported.
  final String gardenName;

  /// Gardener who exported the bundle.
  final String exportedBy;

  /// UTC timestamp when the bundle was exported.
  final DateTime exportedAt;

  /// Shared garden plots included in the bundle.
  final List<GardenPlot> plots;

  /// Shared journal entries (with co-gardener notes and inline thumbnails) included in the bundle.
  final List<FieldJournalEntry> entries;

  /// Creates an immutable [GardenSharedNoteBundle].
  GardenSharedNoteBundle({
    required this.gardenName,
    required this.exportedBy,
    required this.exportedAt,
    Iterable<GardenPlot> plots = const [],
    Iterable<FieldJournalEntry> entries = const [],
  }) : plots = List<GardenPlot>.unmodifiable(plots),
       entries = List<FieldJournalEntry>.unmodifiable(entries);

  /// Serializes this bundle to a JSON map.
  Map<String, Object?> toJson() => {
    'format': bundleFormat,
    'gardenName': gardenName,
    'exportedBy': exportedBy,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'plots': [for (final p in plots) p.toJson()],
    'entries': [for (final e in entries) e.toJson()],
  };

  /// Encodes this bundle as a compact JSON string ready for sharing.
  String toJsonString({bool pretty = false}) => pretty
      ? const JsonEncoder.withIndent('  ').convert(toJson())
      : jsonEncode(toJson());

  /// Deserializes a [GardenSharedNoteBundle] from a decoded JSON map.
  ///
  /// Throws a [FormatException] if the format header or required fields are invalid.
  factory GardenSharedNoteBundle.fromJson(Map<String, Object?> json) {
    final format = json['format'];
    if (format != bundleFormat) {
      throw FormatException('Unsupported garden note bundle format', format);
    }
    final gardenName = json['gardenName'];
    final exportedBy = json['exportedBy'];
    final exportedAtRaw = json['exportedAt'];
    final plotsRaw = json['plots'];
    final entriesRaw = json['entries'];

    DateTime exportedAt = DateTime.now().toUtc();
    if (exportedAtRaw != null) {
      if (exportedAtRaw is! String) {
        throw FormatException(
          'GardenSharedNoteBundle exportedAt must be an ISO-8601 string',
          exportedAtRaw,
        );
      }
      final parsedExportedAt = DateTime.tryParse(exportedAtRaw);
      if (parsedExportedAt == null) {
        throw FormatException(
          'Invalid GardenSharedNoteBundle exportedAt timestamp',
          exportedAtRaw,
        );
      }
      exportedAt = parsedExportedAt.toUtc();
    }

    final parsedPlots = <GardenPlot>[];
    if (plotsRaw != null) {
      if (plotsRaw is! List) {
        throw FormatException(
          'GardenSharedNoteBundle plots must be a JSON list',
          plotsRaw,
        );
      }
      for (final item in plotsRaw) {
        if (item is Map<String, Object?>) {
          parsedPlots.add(GardenPlot.fromJson(item));
        } else if (item is Map) {
          parsedPlots.add(GardenPlot.fromJson(Map<String, Object?>.from(item)));
        } else {
          throw FormatException(
            'GardenSharedNoteBundle plot item must be a JSON object',
            item,
          );
        }
      }
    }

    final parsedEntries = <FieldJournalEntry>[];
    if (entriesRaw != null) {
      if (entriesRaw is! List) {
        throw FormatException(
          'GardenSharedNoteBundle entries must be a JSON list',
          entriesRaw,
        );
      }
      for (final item in entriesRaw) {
        if (item is Map<String, Object?>) {
          parsedEntries.add(FieldJournalEntry.fromJson(item));
        } else if (item is Map) {
          parsedEntries.add(
            FieldJournalEntry.fromJson(Map<String, Object?>.from(item)),
          );
        } else {
          throw FormatException(
            'GardenSharedNoteBundle entry item must be a JSON object',
            item,
          );
        }
      }
    }

    return GardenSharedNoteBundle(
      gardenName: gardenName is String && gardenName.trim().isNotEmpty
          ? gardenName.trim()
          : 'Shared Biodynamic Garden',
      exportedBy: exportedBy is String && exportedBy.trim().isNotEmpty
          ? exportedBy.trim()
          : 'Co-Gardener',
      exportedAt: exportedAt,
      plots: parsedPlots,
      entries: parsedEntries,
    );
  }

  /// Parses a [GardenSharedNoteBundle] from a JSON string.
  ///
  /// Throws a [FormatException] if [rawJson] is not valid JSON or not a valid bundle.
  factory GardenSharedNoteBundle.fromJsonString(String rawJson) {
    final decoded = jsonDecode(rawJson.trim());
    if (decoded is! Map) {
      throw const FormatException(
        'GardenSharedNoteBundle must be a JSON object',
      );
    }
    return GardenSharedNoteBundle.fromJson(Map<String, Object?>.from(decoded));
  }
}
