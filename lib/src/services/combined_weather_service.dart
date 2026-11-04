import 'dart:collection';

import 'weather_service.dart';

/// A weather service combining Yr.no for forecasts and DMI for historical data in Denmark.
final class CombinedWeatherService implements WeatherService {
  static const int _maxCacheEntries = 32;
  static const Duration _forecastTtl = Duration(minutes: 10);
  static const Duration _historicalTtl = Duration(minutes: 30);

  static final Expando<bool> _sortedListCache = Expando<bool>(
    'CombinedWeatherServiceSorted',
  );

  /// Weather service for Yr.no forecasts.
  final WeatherService yrNoService;

  /// Weather service for DMI historical data.
  final WeatherService dmiService;

  final LinkedHashMap<
    (int, int),
    ({DateTime fetchedAt, List<WeatherDataPoint> data})
  >
  _forecastCache =
      LinkedHashMap<
        (int, int),
        ({DateTime fetchedAt, List<WeatherDataPoint> data})
      >();

  final Map<(int, int), Future<List<WeatherDataPoint>>> _inFlightForecasts =
      <(int, int), Future<List<WeatherDataPoint>>>{};

  final LinkedHashMap<
    (int, int, int, int),
    ({DateTime fetchedAt, List<WeatherDataPoint> data})
  >
  _historicalCache =
      LinkedHashMap<
        (int, int, int, int),
        ({DateTime fetchedAt, List<WeatherDataPoint> data})
      >();

  final Map<(int, int, int, int), Future<List<WeatherDataPoint>>>
  _inFlightHistorical =
      <(int, int, int, int), Future<List<WeatherDataPoint>>>{};

  /// Creates a [CombinedWeatherService].
  CombinedWeatherService({required this.yrNoService, required this.dmiService});

  static int _coordKey(double value) => (value * 1000).round();

  static int _hourBucket(DateTime time) =>
      time.toUtc().millisecondsSinceEpoch ~/ 3600000;

  static List<WeatherDataPoint> _normalizeSeries(List<WeatherDataPoint> raw) {
    if (raw.length <= 1) {
      final result = List<WeatherDataPoint>.unmodifiable(raw);
      _sortedListCache[result] = true;
      return result;
    }
    bool sorted = true;
    for (int i = 1; i < raw.length; i++) {
      if (raw[i].time.isBefore(raw[i - 1].time)) {
        sorted = false;
        break;
      }
    }
    if (sorted) {
      final result = List<WeatherDataPoint>.unmodifiable(raw);
      _sortedListCache[result] = true;
      return result;
    }
    final copy = List<WeatherDataPoint>.of(raw)
      ..sort((a, b) => a.time.compareTo(b.time));
    final result = List<WeatherDataPoint>.unmodifiable(copy);
    _sortedListCache[result] = true;
    return result;
  }

  /// Returns whether [points] is sorted in non-decreasing chronological order.
  static bool isChronologicallySorted(List<WeatherDataPoint> points) {
    if (points.length <= 1) return true;
    if (_sortedListCache[points] case final cached?) {
      return cached;
    }
    bool sorted = true;
    for (int i = 1; i < points.length; i++) {
      if (points[i].time.isBefore(points[i - 1].time)) {
        sorted = false;
        break;
      }
    }
    _sortedListCache[points] = sorted;
    return sorted;
  }

  /// Finds the [WeatherDataPoint] in [points] closest to [target] within [maxDelta].
  ///
  /// Uses $O(\log N)$ binary search when [points] is chronologically sorted.
  static WeatherDataPoint? findClosestPoint(
    List<WeatherDataPoint> points,
    DateTime target, {
    Duration maxDelta = const Duration(hours: 3),
  }) {
    if (points.isEmpty) return null;
    final targetMs = target.millisecondsSinceEpoch;
    final maxDeltaMs = maxDelta.inMilliseconds;

    if (isChronologicallySorted(points)) {
      int low = 0;
      int high = points.length - 1;
      while (low <= high) {
        final mid = (low + high) >>> 1;
        final midMs = points[mid].time.millisecondsSinceEpoch;
        if (midMs < targetMs) {
          low = mid + 1;
        } else if (midMs > targetMs) {
          high = mid - 1;
        } else {
          return points[mid];
        }
      }

      WeatherDataPoint? best;
      int bestDiff = maxDeltaMs + 1;
      if (low < points.length) {
        final diff = (points[low].time.millisecondsSinceEpoch - targetMs).abs();
        if (diff <= maxDeltaMs) {
          best = points[low];
          bestDiff = diff;
        }
      }
      if (high >= 0) {
        final diff = (points[high].time.millisecondsSinceEpoch - targetMs)
            .abs();
        if (diff < bestDiff && diff <= maxDeltaMs) {
          best = points[high];
        }
      }
      return best;
    }

    WeatherDataPoint? best;
    int bestDiff = maxDeltaMs + 1;
    for (final point in points) {
      final diff = (point.time.millisecondsSinceEpoch - targetMs).abs();
      if (diff < bestDiff && diff <= maxDeltaMs) {
        best = point;
        bestDiff = diff;
      }
    }
    return best;
  }

  /// Returns the half-open index range `(startIndex, endIndex)` in [points]
  /// covering `[start, end]` inclusive using $O(\log N)$ binary search.
  ///
  /// Returns `null` if [points] is not chronologically sorted.
  static (int, int)? findSortedRangeIndices(
    List<WeatherDataPoint> points,
    DateTime start,
    DateTime end,
  ) {
    if (points.isEmpty) return (0, 0);
    if (!isChronologicallySorted(points)) return null;

    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    int low = 0;
    int high = points.length;
    while (low < high) {
      final mid = (low + high) >>> 1;
      if (points[mid].time.millisecondsSinceEpoch < startMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final firstIdx = low;

    low = firstIdx;
    high = points.length;
    while (low < high) {
      final mid = (low + high) >>> 1;
      if (points[mid].time.millisecondsSinceEpoch <= endMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return (firstIdx, low);
  }

  static void _validateCoordinates(double lat, double lon) {
    if (!lat.isFinite || lat < -90.0 || lat > 90.0) {
      throw ArgumentError.value(
        lat,
        'lat',
        'Must be a finite latitude between -90.0 and 90.0',
      );
    }
    if (!lon.isFinite || lon < -180.0 || lon > 180.0) {
      throw ArgumentError.value(
        lon,
        'lon',
        'Must be a finite longitude between -180.0 and 180.0',
      );
    }
  }

  @override
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon) {
    _validateCoordinates(lat, lon);
    final key = (_coordKey(lat), _coordKey(lon));
    final now = DateTime.now();
    final cached = _forecastCache.remove(key);
    if (cached != null) {
      if (now.difference(cached.fetchedAt) <= _forecastTtl) {
        _forecastCache[key] = cached;
        return Future<List<WeatherDataPoint>>.value(cached.data);
      }
    }

    if (_inFlightForecasts[key] case final inFlight?) {
      return inFlight;
    }

    final future = yrNoService
        .getForecast(lat, lon)
        .then((raw) {
          final normalized = _normalizeSeries(raw);
          if (_forecastCache.length >= _maxCacheEntries) {
            _forecastCache.remove(_forecastCache.keys.first);
          }
          _forecastCache[key] = (fetchedAt: DateTime.now(), data: normalized);
          return normalized;
        })
        .whenComplete(() {
          _inFlightForecasts.remove(key);
        });

    _inFlightForecasts[key] = future;
    return future;
  }

  @override
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) {
    _validateCoordinates(lat, lon);
    if (start.isAfter(end)) {
      throw ArgumentError.value(start, 'start', 'Must not be after end ($end)');
    }
    final key = (
      _coordKey(lat),
      _coordKey(lon),
      _hourBucket(start),
      _hourBucket(end),
    );
    final now = DateTime.now();
    final cached = _historicalCache.remove(key);
    if (cached != null) {
      if (now.difference(cached.fetchedAt) <= _historicalTtl) {
        _historicalCache[key] = cached;
        return Future<List<WeatherDataPoint>>.value(cached.data);
      }
    }

    if (_inFlightHistorical[key] case final inFlight?) {
      return inFlight;
    }

    final future = _fetchHistoricalUncached(lat, lon, start, end)
        .then((raw) {
          final normalized = _normalizeSeries(raw);
          if (_historicalCache.length >= _maxCacheEntries) {
            _historicalCache.remove(_historicalCache.keys.first);
          }
          _historicalCache[key] = (fetchedAt: DateTime.now(), data: normalized);
          return normalized;
        })
        .whenComplete(() {
          _inFlightHistorical.remove(key);
        });

    _inFlightHistorical[key] = future;
    return future;
  }

  Future<List<WeatherDataPoint>> _fetchHistoricalUncached(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) async {
    // Denmark bounding box: latitude 54.5°N to 57.8°N, longitude 8.0°E to 15.3°E
    // (includes Bornholm: ~14.68°E to 15.19°E).
    if (lat >= 54.5 && lat <= 57.8 && lon >= 8.0 && lon <= 15.3) {
      try {
        return await dmiService.getHistoricalData(lat, lon, start, end);
      } catch (e) {
        return await yrNoService.getHistoricalData(lat, lon, start, end);
      }
    } else {
      return await yrNoService.getHistoricalData(lat, lon, start, end);
    }
  }

  @override
  void close() {
    _forecastCache.clear();
    _inFlightForecasts.clear();
    _historicalCache.clear();
    _inFlightHistorical.clear();
    yrNoService.close();
    dmiService.close();
  }
}
