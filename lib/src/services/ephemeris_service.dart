import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:sweph/sweph.dart';

import '../core/algorithm.dart';
import '../core/dornach_boundaries.dart';
import '../core/models/models.dart';

export '../core/models/models.dart';

/// Request for a range of calendar intervals, sent to the worker isolate.
///
/// A typed message rather than a `Map<String, dynamic>`: the previous payload
/// handed `dynamic` values directly to typed parameters, which is unchecked at
/// compile time and only fails once the isolate is already running.
final class _IntervalsRequest {
  /// Port on which the worker sends its reply.
  final SendPort replyPort;

  /// Start of the requested range.
  final DateTime start;

  /// End of the requested range.
  final DateTime end;

  const _IntervalsRequest({
    required this.replyPort,
    required this.start,
    required this.end,
  });
}

/// Failure reply from the worker isolate.
final class _WorkerError {
  /// Description of the original error.
  final String message;

  /// Stack trace of the original error, as a string.
  ///
  /// [StackTrace] itself is not sendable across isolates, so it is carried as
  /// text and rehydrated with [StackTrace.fromString] by the receiver.
  final String stackTrace;

  const _WorkerError(this.message, this.stackTrace);
}

/// Background isolate worker managing Swiss Ephemeris FFI computations.
final class EphemerisWorker {
  static Isolate? _isolate;
  static SendPort? _sendPort;
  static Future<void>? _initFuture;

  /// Initializes persistent background isolate worker.
  static Future<void> init({String? epheFilesPath}) {
    return _initFuture ??= _doInit(epheFilesPath);
  }

  static Future<void> _doInit(String? epheFilesPath) async {
    final receivePort = ReceivePort();
    final errorPort = ReceivePort();
    try {
      final isolate = await Isolate.spawn(_isolateEntry, {
        'sendPort': receivePort.sendPort,
        'epheFilesPath': epheFilesPath,
      }, onError: errorPort.sendPort);
      _isolate = isolate;

      final completer = Completer<SendPort>();
      final sub = receivePort.listen((msg) {
        if (!completer.isCompleted) {
          completer.complete(msg as SendPort);
        }
      });
      final errSub = errorPort.listen((err) {
        if (!completer.isCompleted) {
          final errList = err as List;
          completer.completeError(
            Exception('EphemerisWorker startup failed: ${errList[0]}'),
            StackTrace.fromString(errList[1] as String),
          );
        }
      });

      _sendPort = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'EphemerisWorker isolate initialization timed out',
          );
        },
      );
      await sub.cancel();
      await errSub.cancel();
    } catch (_) {
      _initFuture = null;
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
      _sendPort = null;
      rethrow;
    } finally {
      receivePort.close();
      errorPort.close();
    }
  }

  /// Disposes persistent background isolate worker and resets state.
  static void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _initFuture = null;
  }

  /// Generates interval sequence across [start] and [end].
  static Future<List<CalendarInterval>> getIntervals(
    DateTime start,
    DateTime end,
  ) async {
    await init();
    final port = ReceivePort();
    try {
      _sendPort!.send(
        _IntervalsRequest(replyPort: port.sendPort, start: start, end: end),
      );
      final res = await port.first;
      if (res is _WorkerError) {
        // Rethrow with the worker's original stack trace rather than the
        // (useless) trace of this receiving frame.
        Error.throwWithStackTrace(
          Exception('EphemerisWorker error: ${res.message}'),
          StackTrace.fromString(res.stackTrace),
        );
      }
      return res as List<CalendarInterval>;
    } finally {
      port.close();
    }
  }

  static Future<void> _isolateEntry(Map<String, dynamic> initData) async {
    final sendPort = initData['sendPort'] as SendPort;
    final epheFilesPath = initData['epheFilesPath'] as String?;
    await Sweph.init(epheFilesPath: epheFilesPath);
    final service = AstronomiaEphemerisService();
    final receivePort = ReceivePort();

    sendPort.send(receivePort.sendPort);

    await for (final message in receivePort) {
      if (message is! _IntervalsRequest) {
        continue;
      }
      try {
        message.replyPort.send(
          service.getIntervals(message.start, message.end),
        );
      } catch (e, st) {
        message.replyPort.send(_WorkerError(e.toString(), st.toString()));
      }
    }
  }
}

/// Ephemeris service that delegates heavy interval computations to a background isolate worker.
final class IsolateEphemerisService implements EphemerisService {
  final AstronomiaEphemerisService _syncService = AstronomiaEphemerisService();

  /// Creates [IsolateEphemerisService].
  IsolateEphemerisService();

  @override
  Future<List<CalendarInterval>> getIntervals(DateTime start, DateTime end) {
    return EphemerisWorker.getIntervals(start, end);
  }

  @override
  double getMoonLongitude(DateTime time) => _syncService.getMoonLongitude(time);

  @override
  bool isNearNode(DateTime time) => _syncService.isNearNode(time);

  @override
  bool isNearPerigee(DateTime time) => _syncService.isNearPerigee(time);

  @override
  bool isNearApogee(DateTime time) => _syncService.isNearApogee(time);

  @override
  bool isMoonSaturnOpposition(DateTime time) =>
      _syncService.isMoonSaturnOpposition(time);

  @override
  bool isMoonSquareNode(DateTime time) => _syncService.isMoonSquareNode(time);

  @override
  MoonPhaseInfo getMoonPhase(DateTime time) => _syncService.getMoonPhase(time);

  @override
  double getMoonDeclination(DateTime time) =>
      _syncService.getMoonDeclination(time);

  @override
  List<PlanetInfo> getPlanets(DateTime time) => _syncService.getPlanets(time);

  @override
  SunriseSunsetInfo getSunriseSunset(DateTime date, double lat, double lon) =>
      _syncService.getSunriseSunset(date, lat, lon);

  @override
  void setObserverLocation(
    double latitude,
    double longitude, [
    double altitude = 0.0,
  ]) => _syncService.setObserverLocation(latitude, longitude, altitude);

  @override
  List<PlanetaryAspect> getAspects(DateTime time) =>
      _syncService.getAspects(time);

  @override
  bool isNearEclipse(DateTime time) => _syncService.isNearEclipse(time);

  @override
  void dispose() {
    EphemerisWorker.dispose();
  }
}

/// Swiss Ephemeris service implementing [EphemerisService].
final class AstronomiaEphemerisService implements EphemerisService {
  /// Creates [AstronomiaEphemerisService].
  AstronomiaEphemerisService();

  static const int _topoFlags = 2 | 256 | 32768;
  static const int _geoFlags = 2 | 256;

  double _observerLat = DefaultLocations.dornachLatitude;
  double _observerLon = DefaultLocations.dornachLongitude;
  double _observerAlt = DefaultLocations.dornachAltitude;

  @override
  void setObserverLocation(
    double latitude,
    double longitude, [
    double altitude = 0.0,
  ]) {
    _observerLat = latitude;
    _observerLon = longitude;
    _observerAlt = altitude;
    Sweph.swe_set_topo(longitude, latitude, altitude);
    _phaseCache.clear();
    _lastJd = null;
  }

  final Map<DateTime, MoonPhaseInfo> _phaseCache = {};

  double? _lastJd;
  double _lastGeoLat = 0;
  double _lastGeoLon = 0;
  double _lastGeoDist = 0;

  void _ensureMoon(double jd) {
    if (_lastJd != jd) {
      _lastJd = jd;
      final geo = Sweph.swe_calc_ut(
        jd,
        HeavenlyBody.SE_MOON,
        SwephFlag(_geoFlags),
      );

      _lastGeoLat = geo.latitude;
      _lastGeoLon = geo.longitude;
      _lastGeoDist = geo.distance;
    }
  }

  double _toJD(DateTime time) {
    final utc = time.toUtc();
    final fractionalHour =
        utc.hour +
        utc.minute / 60.0 +
        (utc.second + utc.millisecond / 1000.0) / 3600.0;
    return Sweph.swe_julday(
      utc.year,
      utc.month,
      utc.day,
      fractionalHour,
      CalendarType.SE_GREG_CAL,
    );
  }

  @override
  double getMoonLongitude(DateTime time) {
    final double jd = _toJD(time);
    _ensureMoon(jd);
    return _lastGeoLon;
  }

  @override
  double getMoonDeclination(DateTime time) {
    Sweph.swe_set_topo(_observerLon, _observerLat, _observerAlt);
    final double jd = _toJD(time);
    final pos = Sweph.swe_calc_ut(
      jd,
      HeavenlyBody.SE_MOON,
      SwephFlag(_topoFlags | 2048),
    );
    return pos.latitude;
  }

  @override
  MoonPhaseInfo getMoonPhase(DateTime time) {
    final utc = time.toUtc();
    final cacheKey = DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
    if (_phaseCache.containsKey(cacheKey)) {
      return _phaseCache[cacheKey]!;
    }

    Sweph.swe_set_topo(_observerLon, _observerLat, _observerAlt);
    final double jd = _toJD(time);
    final sun = Sweph.swe_calc_ut(
      jd,
      HeavenlyBody.SE_SUN,
      SwephFlag(_topoFlags),
    );
    final moon = Sweph.swe_calc_ut(
      jd,
      HeavenlyBody.SE_MOON,
      SwephFlag(_topoFlags),
    );

    double diff = moon.longitude - sun.longitude;
    if (diff < 0) {
      diff += 360.0;
    }

    final double rad = diff * math.pi / 180.0;
    final double illuminatedFraction = (1 - math.cos(rad)) / 2.0;
    final bool isWaxing = diff < 180.0;

    final info = MoonPhaseInfo(
      illuminatedFraction: illuminatedFraction,
      isWaxing: isWaxing,
      phaseAngle: diff,
    );

    if (_phaseCache.length > 1000) {
      _phaseCache.clear();
    }
    return _phaseCache[cacheKey] = info;
  }

  @override
  List<PlanetInfo> getPlanets(DateTime time) {
    Sweph.swe_set_topo(_observerLon, _observerLat, _observerAlt);

    final double jd = _toJD(time);
    final flags = SwephFlag(_topoFlags);

    PlanetInfo getPl(HeavenlyBody body, String name) {
      final pos = Sweph.swe_calc_ut(jd, body, flags);
      return PlanetInfo(name: name, longitude: pos.longitude);
    }

    return [
      getPl(HeavenlyBody.SE_SUN, 'Sun'),
      getPl(HeavenlyBody.SE_MOON, 'Moon'),
      getPl(HeavenlyBody.SE_MERCURY, 'Mercury'),
      getPl(HeavenlyBody.SE_VENUS, 'Venus'),
      getPl(HeavenlyBody.SE_MARS, 'Mars'),
      getPl(HeavenlyBody.SE_JUPITER, 'Jupiter'),
      getPl(HeavenlyBody.SE_SATURN, 'Saturn'),
    ];
  }

  @override
  List<PlanetaryAspect> getAspects(DateTime time) {
    final planets = getPlanets(time);
    final aspects = <PlanetaryAspect>[];

    for (int i = 0; i < planets.length; i++) {
      for (int j = i + 1; j < planets.length; j++) {
        final p1 = planets[i];
        final p2 = planets[j];

        double diff = (p1.longitude - p2.longitude).abs() % 360.0;
        if (diff > 180.0) diff = 360.0 - diff;

        // Conjunction: 0° ± 2.5°
        if (diff <= 2.5) {
          final isStress =
              (p1.name == 'Moon' || p2.name == 'Moon') &&
              (p1.name == 'Saturn' ||
                  p2.name == 'Saturn' ||
                  p1.name == 'Mars' ||
                  p2.name == 'Mars');
          aspects.add(
            PlanetaryAspect(
              body1: p1.name,
              body2: p2.name,
              type: AspectType.conjunction,
              separationDegrees: diff,
              orbDegrees: diff,
              isFavorable: !isStress,
              agriculturalEffect: isStress
                  ? 'Conjunction with ${p1.name == "Moon" ? p2.name : p1.name}: Gravitational compression. Rest window.'
                  : 'Conjunction between ${p1.name} and ${p2.name}.',
            ),
          );
        }
        // Square: 90° ± 2.5°
        else if ((diff - 90.0).abs() <= 2.5) {
          aspects.add(
            PlanetaryAspect(
              body1: p1.name,
              body2: p2.name,
              type: AspectType.square,
              separationDegrees: diff,
              orbDegrees: (diff - 90.0).abs(),
              isFavorable: false,
              agriculturalEffect:
                  'Planetary Square (90°): Elemental quadrature conflict between ${p1.name} and ${p2.name}. Stress period.',
            ),
          );
        }
        // Trine: 120° ± 3.0°
        else if ((diff - 120.0).abs() <= 3.0) {
          aspects.add(
            PlanetaryAspect(
              body1: p1.name,
              body2: p2.name,
              type: AspectType.trine,
              separationDegrees: diff,
              orbDegrees: (diff - 120.0).abs(),
              isFavorable: true,
              agriculturalEffect:
                  'Planetary Trine (120°): Harmonious elemental resonance between ${p1.name} and ${p2.name}.',
            ),
          );
        }
        // Opposition: 180° ± 4.0°
        else if ((diff - 180.0).abs() <= 4.0) {
          final isMoonSaturn =
              (p1.name == 'Moon' && p2.name == 'Saturn') ||
              (p1.name == 'Saturn' && p2.name == 'Moon');
          aspects.add(
            PlanetaryAspect(
              body1: p1.name,
              body2: p2.name,
              type: AspectType.opposition,
              separationDegrees: diff,
              orbDegrees: (diff - 180.0).abs(),
              isFavorable: isMoonSaturn,
              agriculturalEffect: isMoonSaturn
                  ? 'Moon-Saturn Opposition (180°): Fungal Resistance & Strong Root Vigor.'
                  : 'Planetary Opposition (180°) between ${p1.name} and ${p2.name}.',
            ),
          );
        }
      }
    }
    return aspects;
  }

  @override
  bool isNearEclipse(DateTime time) {
    final jd = _toJD(time);
    for (double t = jd - 0.5; t <= jd + 0.5; t += 1.0 / 24.0) {
      final sun = Sweph.swe_calc_ut(
        t,
        HeavenlyBody.SE_SUN,
        SwephFlag(_geoFlags),
      );
      final moon = Sweph.swe_calc_ut(
        t,
        HeavenlyBody.SE_MOON,
        SwephFlag(_geoFlags),
      );

      if (moon.latitude.abs() <= 0.85) {
        double diff = (moon.longitude - sun.longitude).abs() % 360.0;
        if (diff > 180.0) diff = 360.0 - diff;
        if (diff <= 1.5 || (diff - 180.0).abs() <= 1.5) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  SunriseSunsetInfo getSunriseSunset(DateTime date, double lat, double lon) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;

    final decRad =
        -23.44 *
        math.cos((360.0 / 365.0) * (dayOfYear + 10) * math.pi / 180.0) *
        math.pi /
        180.0;
    final latRad = lat * math.pi / 180.0;

    final cosHA =
        (math.sin(-0.83 * math.pi / 180.0) -
            math.sin(latRad) * math.sin(decRad)) /
        (math.cos(latRad) * math.cos(decRad));

    if (cosHA < -1.0 || cosHA > 1.0) {
      return SunriseSunsetInfo(noon: date);
    }

    final haDeg = math.acos(cosHA) * 180.0 / math.pi;

    final utcNoon = DateTime.utc(date.year, date.month, date.day, 12);
    final solarNoon = utcNoon.subtract(Duration(seconds: (lon * 240).toInt()));
    final halfDay = Duration(seconds: (haDeg * 240).toInt());

    return SunriseSunsetInfo(
      sunrise: solarNoon.subtract(halfDay).toLocal(),
      sunset: solarNoon.add(halfDay).toLocal(),
      noon: solarNoon.toLocal(),
    );
  }

  @override
  bool isNearNode(DateTime time) {
    final jd = _toJD(time);
    _ensureMoon(jd);
    if (_lastGeoLat.abs() > 0.85) {
      return false;
    }

    final step = 1.0 / 24.0;
    for (double t = jd - 0.5; t <= jd + 0.5; t += step) {
      final pos1 = Sweph.swe_calc_ut(
        t,
        HeavenlyBody.SE_MOON,
        SwephFlag(_geoFlags),
      );
      final pos2 = Sweph.swe_calc_ut(
        t + step,
        HeavenlyBody.SE_MOON,
        SwephFlag(_geoFlags),
      );

      if (pos1.latitude * pos2.latitude <= 0 &&
          pos1.latitude != pos2.latitude) {
        final double exactJD =
            t + step * (0 - pos1.latitude) / (pos2.latitude - pos1.latitude);
        final double diffHours = (exactJD - jd) * 24.0;
        return diffHours.abs() <= 6.0;
      }
    }
    return false;
  }

  @override
  bool isNearPerigee(DateTime time) {
    final jd = _toJD(time);
    _ensureMoon(jd);
    if (_lastGeoDist > 0.00258) {
      return false;
    }

    final step = 2.0 / 24.0;
    double minT = jd;
    double minDist = double.infinity;

    for (double t = jd - 1.5; t <= jd + 1.5; t += step) {
      final pos = Sweph.swe_calc_ut(
        t,
        HeavenlyBody.SE_MOON,
        SwephFlag(_geoFlags),
      );
      if (pos.distance < minDist) {
        minDist = pos.distance;
        minT = t;
      }
    }

    if (minT <= jd - 1.49 || minT >= jd + 1.49) {
      return false;
    }

    final pos1 = Sweph.swe_calc_ut(
      minT - step,
      HeavenlyBody.SE_MOON,
      SwephFlag(_geoFlags),
    );
    final pos2 = Sweph.swe_calc_ut(
      minT,
      HeavenlyBody.SE_MOON,
      SwephFlag(_geoFlags),
    );
    final pos3 = Sweph.swe_calc_ut(
      minT + step,
      HeavenlyBody.SE_MOON,
      SwephFlag(_geoFlags),
    );

    final y1 = pos1.distance;
    final y2 = pos2.distance;
    final y3 = pos3.distance;
    final denom = 2 * (y1 + y3 - 2 * y2);
    if (denom <= 0) {
      return false;
    }
    final deltaT = -step * (y3 - y1) / denom;
    final exactT = minT + deltaT;
    final double diffHours = (exactT - jd) * 24.0;
    return diffHours.abs() <= 12.0;
  }

  @override
  bool isNearApogee(DateTime time) {
    final jd = _toJD(time);
    _ensureMoon(jd);
    if (_lastGeoDist < 0.00258) {
      return false;
    }

    final step = 2.0 / 24.0;
    for (double t = jd - 2.0; t <= jd + 2.0; t += step) {
      final pos1 = Sweph.swe_calc_ut(
        t - step,
        HeavenlyBody.SE_MOON,
        SwephFlag(_geoFlags),
      );
      final pos2 = Sweph.swe_calc_ut(
        t,
        HeavenlyBody.SE_MOON,
        SwephFlag(_geoFlags),
      );
      final pos3 = Sweph.swe_calc_ut(
        t + step,
        HeavenlyBody.SE_MOON,
        SwephFlag(_geoFlags),
      );

      if (pos2.distance > pos1.distance && pos2.distance > pos3.distance) {
        final y1 = pos1.distance;
        final y2 = pos2.distance;
        final y3 = pos3.distance;
        final denom = 2 * (y1 + y3 - 2 * y2);
        final deltaT = denom != 0 ? -step * (y3 - y1) / denom : 0.0;
        final exactT = t + deltaT;
        final double diffHours = (exactT - jd) * 24.0;
        return diffHours.abs() <= 12.0;
      }
    }
    return false;
  }

  @override
  bool isMoonSaturnOpposition(DateTime time) {
    Sweph.swe_set_topo(_observerLon, _observerLat, _observerAlt);
    final jd = _toJD(time);
    final moon = Sweph.swe_calc_ut(
      jd,
      HeavenlyBody.SE_MOON,
      SwephFlag(_topoFlags),
    );
    final saturn = Sweph.swe_calc_ut(
      jd,
      HeavenlyBody.SE_SATURN,
      SwephFlag(_topoFlags),
    );

    double diff = (moon.longitude - saturn.longitude).abs() % 360.0;
    if (diff > 180.0) {
      diff = 360.0 - diff;
    }
    return (diff - 180.0).abs() <= 4.0;
  }

  @override
  bool isMoonSquareNode(DateTime time) {
    final jd = _toJD(time);
    _ensureMoon(jd);
    if (_lastGeoLat.abs() < 4.95) {
      return false;
    }
    final step = 1.0 / 24.0;
    final pos1 = Sweph.swe_calc_ut(
      jd - step,
      HeavenlyBody.SE_MOON,
      SwephFlag(_geoFlags),
    );
    final pos2 = Sweph.swe_calc_ut(
      jd,
      HeavenlyBody.SE_MOON,
      SwephFlag(_geoFlags),
    );
    final pos3 = Sweph.swe_calc_ut(
      jd + step,
      HeavenlyBody.SE_MOON,
      SwephFlag(_geoFlags),
    );

    final lat1 = pos1.latitude.abs();
    final lat2 = pos2.latitude.abs();
    final lat3 = pos3.latitude.abs();

    return (lat2 >= lat1 && lat2 >= lat3 && lat2 >= 5.0) || lat2 >= 5.12;
  }

  @override
  List<CalendarInterval> getIntervals(DateTime start, DateTime end) {
    final searchStart = start.subtract(const Duration(days: 2));
    final searchEnd = end.add(const Duration(days: 2));
    final startJD = _toJD(searchStart);
    final endJD = _toJD(searchEnd);

    // 1. Scan for Node crossings across [searchStart, searchEnd]
    final nodeWindows = <(double, double)>[];
    // `hasPrevious` rather than comparing against `startJD`: the previous
    // version tested `prevLatT != startJD`, but `prevLatT` was re-assigned
    // `startJD` on the first iteration, so the second iteration was skipped
    // too and a crossing in the first hour of the window was lost. A sentinel
    // `prevLat` would be wrong for the same reason, since 0.0 is itself a
    // legal ecliptic latitude (it is exactly what a node crossing looks like).
    bool hasPrevious = false;
    double prevLat = 0.0;
    double prevLatT = startJD;
    const nodeStep = 1.0 / 24.0; // 1 hour steps
    for (double t = startJD; t <= endJD; t += nodeStep) {
      final p = Sweph.swe_calc_ut(
        t,
        HeavenlyBody.SE_MOON,
        SwephFlag(_geoFlags),
      );
      if (hasPrevious && prevLat * p.latitude <= 0 && prevLat != p.latitude) {
        final exactT =
            prevLatT + nodeStep * (0 - prevLat) / (p.latitude - prevLat);
        nodeWindows.add((exactT - 6.0 / 24.0, exactT + 6.0 / 24.0));
      }
      prevLat = p.latitude;
      prevLatT = t;
      hasPrevious = true;
    }

    // 2. Scan for Perigee extrema across [searchStart, searchEnd]
    final perigeeWindows = <(double, double)>[];
    double prevDist1 = double.infinity;
    double prevDist2 = double.infinity;
    double prevDistT2 = startJD;
    const perigeeStep = 2.0 / 24.0; // 2 hour steps
    for (double t = startJD; t <= endJD; t += perigeeStep) {
      final p = Sweph.swe_calc_ut(
        t,
        HeavenlyBody.SE_MOON,
        SwephFlag(_geoFlags),
      );
      if (prevDist2 < prevDist1 && prevDist2 < p.distance) {
        final y1 = prevDist1;
        final y2 = prevDist2;
        final y3 = p.distance;
        final denom = 2 * (y1 + y3 - 2 * y2);
        final deltaT = denom > 0 ? -perigeeStep * (y3 - y1) / denom : 0.0;
        final exactT = prevDistT2 + deltaT;
        perigeeWindows.add((exactT - 12.0 / 24.0, exactT + 12.0 / 24.0));
      }
      prevDist1 = prevDist2;
      prevDist2 = p.distance;
      prevDistT2 = t;
    }

    final List<CalendarInterval> intervals = [];
    DateTime current = start;

    while (current.isBefore(end)) {
      final intervalEnd = current.add(const Duration(hours: 2));
      final currentJD = _toJD(current);

      final isNearNode = nodeWindows.any(
        (w) => currentJD >= w.$1 && currentJD <= w.$2,
      );
      final isNearPerigee = perigeeWindows.any(
        (w) => currentJD >= w.$1 && currentJD <= w.$2,
      );
      final isGrayDay = isNearNode || isNearPerigee;

      String message = '';
      if (isNearNode) {
        message = 'Gray Day: Near Lunar Node.';
      } else if (isNearPerigee) {
        message = 'Gray Day: Near Lunar Perigee (Pg).';
      }

      PlantQuality quality = PlantQuality.none;
      bool isSpecial = false;
      if (!isGrayDay) {
        final moonLon = getMoonLongitude(current);
        quality = getQualityFromLongitude(moonLon, dornachBoundaries);

        final isNearApogeeVal = isNearApogee(current);
        final isMoonSaturnOpp = isMoonSaturnOpposition(current);
        final planets = getPlanets(current);
        final trineResult = calculateTrineQuality(planets, dornachBoundaries);

        if (trineResult.quality != PlantQuality.none) {
          quality = trineResult.quality;
          message = trineResult.message;
          isSpecial = true;
        } else if (isNearApogeeVal) {
          message = 'Apogee Window (Ag): High Light & Warmth Impulse.';
          isSpecial = true;
        } else if (isMoonSaturnOpp) {
          message = 'Moon-Saturn Opposition (180°): Fungal Resistance & Strong Root Vigor.';
          isSpecial = true;
        }
      }

      if (intervals.isNotEmpty) {
        final last = intervals.last;
        if (last.quality == quality &&
            last.isGrayDay == isGrayDay &&
            last.isSpecial == isSpecial &&
            last.message == message) {
          intervals[intervals.length - 1] = CalendarInterval(
            start: last.start,
            end: intervalEnd,
            quality: last.quality,
            isGrayDay: last.isGrayDay,
            isSpecial: last.isSpecial,
            message: last.message,
          );
          current = intervalEnd;
          continue;
        }
      }

      intervals.add(
        CalendarInterval(
          start: current,
          end: intervalEnd,
          quality: quality,
          isGrayDay: isGrayDay,
          isSpecial: isSpecial,
          message: message,
        ),
      );

      current = intervalEnd;
    }

    return intervals;
  }

  @override
  void dispose() {}
}
