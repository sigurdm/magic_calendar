import 'dart:convert';
import 'dart:js_interop';

import 'garden_service.dart';

@JS('window.localStorage')
external _JSStorage? get _localStorage;

extension type _JSStorage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

/// Creates a persistent [GardenProfileStore] backed by browser `localStorage`
/// on Web, or returns `null` if `localStorage` is unavailable.
///
/// Only non-sensitive user gardening preferences (saved coordinates, starred
/// crops, queued tasks, and journal entries) are stored here.
GardenProfileStore? createFileGardenProfileStore(String filePath) =>
    _WebLocalStorageGardenProfileStore('magic_calendar.garden_profile.v1');

/// Creates a monthly SQLite-sharded [ShardedSqliteJournalStore] rooted at [dirPath],
/// or returns `null` on unsupported platforms (such as Flutter Web).
ShardedSqliteJournalStore? createShardedSqliteJournalStore(String dirPath) =>
    null;

final class _WebLocalStorageGardenProfileStore implements GardenProfileStore {
  final String storageKey;

  const _WebLocalStorageGardenProfileStore(this.storageKey);

  @override
  Future<GardenProfile?> read() async {
    try {
      final storage = _localStorage;
      if (storage == null) return null;
      final raw = storage.getItem(storageKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return GardenProfile.fromJson(Map<String, Object?>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(GardenProfile profile) async {
    try {
      final storage = _localStorage;
      if (storage == null) return;
      storage.setItem(storageKey, jsonEncode(profile.toJson()));
    } catch (_) {
      // Ignore quota/storage errors in private browsing modes.
    }
  }
}
