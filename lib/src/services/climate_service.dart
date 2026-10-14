import 'dart:async';

import '../core/climate/climate.dart';
import '../repository/open_meteo_client.dart';

export '../core/climate/climate.dart';
export 'climate_profile_store_stub.dart'
    if (dart.library.io) 'climate_profile_store_io.dart';

/// Persistent or in-memory cache of computed [ClimateProfile]s keyed by string.
abstract interface class ClimateProfileStore {
  /// Reads the cached profile for [key], or returns null if absent or invalid.
  Future<ClimateProfile?> read(String key);

  /// Stores [profile] under [key].
  Future<void> write(String key, ClimateProfile profile);
}

/// In-memory implementation of [ClimateProfileStore].
final class MemoryClimateProfileStore implements ClimateProfileStore {
  final Map<String, ClimateProfile> _profiles = {};

  /// Creates an empty in-memory store.
  MemoryClimateProfileStore();

  @override
  Future<ClimateProfile?> read(String key) async => _profiles[key];

  @override
  Future<void> write(String key, ClimateProfile profile) async {
    _profiles[key] = profile;
  }
}

/// Service that resolves a 30-year [ClimateProfile] for a geographic location.
abstract interface class ClimateService {
  /// Resolves the [ClimateProfile] for [latitude] and [longitude].
  ///
  /// The [latitude] must be between -90.0 and 90.0, and [longitude] must be
  /// between -180.0 and 180.0.
  Future<ClimateProfile> profileFor(double latitude, double longitude);

  /// Releases any underlying network resources.
  void close();
}

/// [ClimateService] backed by Open-Meteo's 1991–2020 ERA5 archive with
/// in-memory deduplication and an optional persistent [ClimateProfileStore].
final class OpenMeteoClimateService implements ClimateService {
  final OpenMeteoClient _client;

  /// Optional persistent or in-memory store for resolved profiles.
  final ClimateProfileStore? store;

  /// First calendar year of the archive request (inclusive).
  final int firstYear;

  /// Last calendar year of the archive request (inclusive).
  final int lastYear;

  final Map<String, Future<ClimateProfile>> _cache = {};

  /// Creates an [OpenMeteoClimateService].
  ///
  /// The [firstYear] must be at least two years before [lastYear].
  OpenMeteoClimateService({
    OpenMeteoClient? client,
    this.store,
    this.firstYear = 1991,
    this.lastYear = 2020,
  }) : _client = client ?? OpenMeteoClient() {
    if (lastYear <= firstYear) {
      throw ArgumentError.value(
        lastYear,
        'lastYear',
        'Must be greater than firstYear ($firstYear)',
      );
    }
  }

  /// Rounds [degrees] to the nearest 0.1° (~11 km, matching the ERA5-Land
  /// grid scale) so nearby coordinates share a single cached profile.
  static double roundCoordinate(double degrees) {
    final rounded = (degrees * 10).roundToDouble() / 10;
    return rounded == 0.0 ? 0.0 : rounded;
  }

  /// Cache key for [latitude] and [longitude] after rounding to 0.1°.
  static String cacheKeyFor(
    double latitude,
    double longitude, {
    int firstYear = 1991,
    int lastYear = 2020,
  }) {
    final lat = roundCoordinate(latitude).toStringAsFixed(1);
    final lon = roundCoordinate(longitude).toStringAsFixed(1);
    return 'v${ClimateProfile.jsonVersion}_${firstYear}_${lastYear}_${lat}_$lon';
  }

  @override
  Future<ClimateProfile> profileFor(double latitude, double longitude) {
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
    final roundedLat = roundCoordinate(latitude);
    final roundedLon = roundCoordinate(longitude);
    final key = cacheKeyFor(
      roundedLat,
      roundedLon,
      firstYear: firstYear,
      lastYear: lastYear,
    );
    return _cache[key] ??= _load(key, roundedLat, roundedLon);
  }

  Future<ClimateProfile> _load(
    String key,
    double roundedLat,
    double roundedLon,
  ) async {
    try {
      final backingStore = store;
      if (backingStore != null) {
        final cached = await backingStore.read(key);
        if (cached != null) return cached;
      }
      final series = await _client.getDailyClimateSeries(
        roundedLat,
        roundedLon,
        firstYear: firstYear,
        lastYear: lastYear,
      );
      final profile = ClimateProfile.fromDailySeries(
        series,
        latitude: roundedLat,
        longitude: roundedLon,
      );
      if (backingStore != null) {
        try {
          await backingStore.write(key, profile);
        } catch (_) {
          // Ignore disk persistence failures; the in-memory cache still holds
          // the resolved profile for this session.
        }
      }
      return profile;
    } catch (_) {
      unawaited(_cache.remove(key));
      rethrow;
    }
  }

  @override
  void close() {
    _client.close();
  }
}
