import 'dart:convert';
import 'dart:io';

import 'garden_service.dart';

/// Creates a file-backed [GardenProfileStore] persisting the user's garden
/// profile as JSON at [filePath].
GardenProfileStore? createFileGardenProfileStore(String filePath) =>
    FileGardenProfileStore(File(filePath));

/// Creates a monthly SQLite-sharded [ShardedSqliteJournalStore] rooted at [dirPath].
ShardedSqliteJournalStore? createShardedSqliteJournalStore(String dirPath) =>
    ShardedSqliteJournalStore(rootDirectoryPath: dirPath);

/// File-backed [GardenProfileStore] that stores a [GardenProfile] as JSON in [file].
///
/// Corrupt or version-mismatched files are treated as missing on [read].
final class FileGardenProfileStore implements GardenProfileStore {
  /// Backing JSON file on disk.
  final File file;

  /// Creates a store backed by [file].
  const FileGardenProfileStore(this.file);

  @override
  Future<GardenProfile?> read() async {
    try {
      if (!await file.exists()) return null;
      final contents = await file.readAsString();
      final decoded = jsonDecode(contents);
      if (decoded is! Map<String, Object?>) return null;
      return GardenProfile.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(GardenProfile profile) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(profile.toJson()));
  }
}
