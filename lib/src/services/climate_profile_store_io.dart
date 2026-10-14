import 'dart:convert';
import 'dart:io';

import 'climate_service.dart';

/// Creates a file-backed [ClimateProfileStore] storing one JSON file per
/// location inside [directoryPath].
ClimateProfileStore? createFileClimateProfileStore(String directoryPath) =>
    FileClimateProfileStore(Directory(directoryPath));

/// File-backed [ClimateProfileStore] that persists each [ClimateProfile] as a
/// JSON file in [directory].
///
/// Corrupt or version-mismatched files are treated as cache misses on [read].
final class FileClimateProfileStore implements ClimateProfileStore {
  /// Directory where profile JSON files are stored.
  final Directory directory;

  /// Creates a store rooted at [directory].
  const FileClimateProfileStore(this.directory);

  File _fileFor(String key) {
    final sanitized = key.replaceAll(RegExp(r'[^A-Za-z0-9_.\-]'), '_');
    return File('${directory.path}/$sanitized.json');
  }

  @override
  Future<ClimateProfile?> read(String key) async {
    final file = _fileFor(key);
    try {
      if (!await file.exists()) return null;
      final contents = await file.readAsString();
      final decoded = jsonDecode(contents);
      if (decoded is! Map<String, Object?>) return null;
      return ClimateProfile.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, ClimateProfile profile) async {
    await directory.create(recursive: true);
    final file = _fileFor(key);
    await file.writeAsString(jsonEncode(profile.toJson()));
  }
}
