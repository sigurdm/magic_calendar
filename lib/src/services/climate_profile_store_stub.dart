import 'dart:convert';
import 'dart:js_interop';

import 'climate_service.dart';

@JS('window.localStorage')
external _JSStorage? get _localStorage;

extension type _JSStorage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

/// Creates a persistent [ClimateProfileStore] backed by browser `localStorage`
/// on Web.
ClimateProfileStore? createFileClimateProfileStore(String directoryPath) =>
    const _WebLocalStorageClimateProfileStore();

final class _WebLocalStorageClimateProfileStore implements ClimateProfileStore {
  const _WebLocalStorageClimateProfileStore();

  String _storageKey(String key) {
    final sanitized = key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return 'magic_calendar.climate.$sanitized';
  }

  @override
  Future<ClimateProfile?> read(String key) async {
    try {
      final storage = _localStorage;
      if (storage == null) return null;
      final raw = storage.getItem(_storageKey(key));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ClimateProfile.fromJson(Map<String, Object?>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, ClimateProfile profile) async {
    try {
      final storage = _localStorage;
      if (storage == null) return;
      storage.setItem(_storageKey(key), jsonEncode(profile.toJson()));
    } catch (_) {
      // Ignore storage quota errors in private browsing modes.
    }
  }
}
