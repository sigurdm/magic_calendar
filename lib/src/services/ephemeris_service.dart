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

const bool _kIsWeb = bool.fromEnvironment('dart.library.js_interop');

/// Background isolate worker managing Swiss Ephemeris FFI computations.
final class EphemerisWorker {
  static Isolate? _isolate;
  static SendPort? _sendPort;
  static Future<void>? _initFuture;
  static AstronomiaEphemerisService? _webFallbackService;
  static final Set<Completer<Object?>> _pendingReplies = <Completer<Object?>>{};

  /// Initializes persistent background isolate worker.
  static Future<void> init({String? epheFilesPath}) {
    if (_kIsWeb) {
      _webFallbackService ??= AstronomiaEphemerisService();
      return _initFuture ??= Future<void>.value();
    }
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

      final port = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'EphemerisWorker isolate initialization timed out',
          );
        },
      );
      await sub.cancel();
      await errSub.cancel();
      if (_isolate != isolate) {
        isolate.kill(priority: Isolate.immediate);
        throw StateError('EphemerisWorker was disposed during initialization');
      }
      _sendPort = port;
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
    _webFallbackService = null;
    final pending = _pendingReplies.toList(growable: false);
    _pendingReplies.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'EphemerisWorker was disposed while request was in flight',
          ),
        );
      }
    }
  }

  /// Generates interval sequence across [start] and [end].
  static Future<List<CalendarInterval>> getIntervals(
    DateTime start,
    DateTime end,
  ) async {
    if (_kIsWeb) {
      final service = _webFallbackService ??= AstronomiaEphemerisService();
      return service.getIntervals(start, end);
    }
    await init();
    final sendPort = _sendPort;
    if (sendPort == null) {
      throw StateError('EphemerisWorker is not initialized or was disposed');
    }
    final port = ReceivePort();
    final replyCompleter = Completer<Object?>();
    _pendingReplies.add(replyCompleter);
    final sub = port.listen((msg) {
      if (!replyCompleter.isCompleted) {
        replyCompleter.complete(msg);
      }
    });
    try {
      sendPort.send(
        _IntervalsRequest(replyPort: port.sendPort, start: start, end: end),
      );
      final res = await replyCompleter.future;
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
      _pendingReplies.remove(replyCompleter);
      await sub.cancel();
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

  /// Incremented whenever [setObserverLocation] mutates topocentric coordinates.
  int get observerLocationVersion => _syncService.observerLocationVersion;

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

  static const int _topoFlags = 2 | 32768;
  static const int _geoFlags = 2;
  static final SwephFlag _topoSwephFlag = SwephFlag(_topoFlags);
  static final SwephFlag _topoEquatorialSwephFlag = SwephFlag(
    _topoFlags | 2048,
  );
  static final SwephFlag _geoSwephFlag = SwephFlag(_geoFlags);

  double _observerLat = DefaultLocations.dornachLatitude;
  double _observerLon = DefaultLocations.dornachLongitude;
  double _observerAlt = DefaultLocations.dornachAltitude;
  int _observerLocationVersion = 0;
  bool _topoConfigured = false;

  /// Incremented whenever [setObserverLocation] mutates topocentric coordinates.
  int get observerLocationVersion => _observerLocationVersion;

  void _ensureTopoConfigured() {
    if (!_topoConfigured) {
      Sweph.swe_set_topo(_observerLon, _observerLat, _observerAlt);
      _topoConfigured = true;
    }
  }

  @override
  void setObserverLocation(
    double latitude,
    double longitude, [
    double altitude = 0.0,
  ]) {
    if (_observerLat == latitude &&
        _observerLon == longitude &&
        _observerAlt == altitude &&
        _topoConfigured) {
      return;
    }
    _observerLat = latitude;
    _observerLon = longitude;
    _observerAlt = altitude;
    _observerLocationVersion++;
    Sweph.swe_set_topo(longitude, latitude, altitude);
    _topoConfigured = true;
    _phaseCache.clear();
    _declinationCache.clear();
    _planetsCache.clear();
    _sunriseSunsetCache.clear();
    _lastJd = null;
    _lastPlanetsJd = null;
    _lastPlanets = null;
  }

  final Map<DateTime, MoonPhaseInfo> _phaseCache = {};
  final Map<int, double> _declinationCache = {};
  late final Map<int, List<PlanetInfo>> _planetsCache = {};
  late final Map<(int, int, int, int, int), SunriseSunsetInfo>
  _sunriseSunsetCache = {};
  final Map<int, ({double latitude, double longitude, double distance})>
  _geoMoonCache = {};

  double? _lastJd;
  double _lastGeoLat = 0;
  double _lastGeoLon = 0;
  double _lastGeoDist = 0;

  double? _lastPlanetsJd;
  List<PlanetInfo>? _lastPlanets;

  ({double latitude, double longitude, double distance}) _geoMoonAt(double jd) {
    final key = (jd * 86400.0).round();
    if (_geoMoonCache[key] case final cached?) {
      return cached;
    }
    final geo = Sweph.swe_calc_ut(jd, HeavenlyBody.SE_MOON, _geoSwephFlag);
    final val = (
      latitude: geo.latitude,
      longitude: geo.longitude,
      distance: geo.distance,
    );
    if (_geoMoonCache.length >= 8192) {
      _geoMoonCache.clear();
    }
    _geoMoonCache[key] = val;
    return val;
  }

  void _ensureMoon(double jd) {
    if (_lastJd != jd) {
      _lastJd = jd;
      final geo = _geoMoonAt(jd);

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
    final double jd = _toJD(time);
    final int key = (jd * 86400.0).round();
    if (_declinationCache[key] case final cached?) {
      return cached;
    }
    _ensureTopoConfigured();
    final pos = Sweph.swe_calc_ut(
      jd,
      HeavenlyBody.SE_MOON,
      _topoEquatorialSwephFlag,
    );
    if (_declinationCache.length >= 4096) {
      _declinationCache.clear();
    }
    return _declinationCache[key] = pos.latitude;
  }

  @override
  MoonPhaseInfo getMoonPhase(DateTime time) {
    final utc = time.toUtc();
    final cacheKey = DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
    if (_phaseCache[cacheKey] case final cached?) {
      return cached;
    }

    _ensureTopoConfigured();
    final double jd = _toJD(time);
    double sunLon;
    double moonLon;
    if (_lastPlanetsJd == jd && _lastPlanets != null) {
      sunLon = _lastPlanets![0].longitude;
      moonLon = _lastPlanets![1].longitude;
    } else {
      final sun = Sweph.swe_calc_ut(jd, HeavenlyBody.SE_SUN, _topoSwephFlag);
      final moon = Sweph.swe_calc_ut(jd, HeavenlyBody.SE_MOON, _topoSwephFlag);
      sunLon = sun.longitude;
      moonLon = moon.longitude;
    }

    double diff = moonLon - sunLon;
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
    _ensureTopoConfigured();

    final double jd = _toJD(time);
    if (_lastPlanetsJd == jd && _lastPlanets != null) {
      return _lastPlanets!;
    }
    final int cacheKey = (jd * 86400.0).round();
    if (_planetsCache[cacheKey] case final cached?) {
      _lastPlanetsJd = jd;
      _lastPlanets = cached;
      return cached;
    }

    PlanetInfo getPl(HeavenlyBody body, String name) {
      final pos = Sweph.swe_calc_ut(jd, body, _topoSwephFlag);
      return PlanetInfo(name: name, longitude: pos.longitude);
    }

    final planets = List<PlanetInfo>.unmodifiable([
      getPl(HeavenlyBody.SE_SUN, 'Sun'),
      getPl(HeavenlyBody.SE_MOON, 'Moon'),
      getPl(HeavenlyBody.SE_MERCURY, 'Mercury'),
      getPl(HeavenlyBody.SE_VENUS, 'Venus'),
      getPl(HeavenlyBody.SE_MARS, 'Mars'),
      getPl(HeavenlyBody.SE_JUPITER, 'Jupiter'),
      getPl(HeavenlyBody.SE_SATURN, 'Saturn'),
    ]);
    if (_planetsCache.length >= 2048) {
      _planetsCache.clear();
    }
    _planetsCache[cacheKey] = planets;
    _lastPlanetsJd = jd;
    _lastPlanets = planets;
    return planets;
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
    _ensureMoon(jd);
    // In ±12 hours Moon ecliptic latitude changes by < 0.65°, so an eclipse
    // (|lat| <= 0.85°) is impossible when |lat(jd)| > 1.55°.
    if (_lastGeoLat.abs() > 1.55) {
      return false;
    }
    final sunAtJd = Sweph.swe_calc_ut(jd, HeavenlyBody.SE_SUN, _geoSwephFlag);
    double midDiff = (_lastGeoLon - sunAtJd.longitude).abs() % 360.0;
    if (midDiff > 180.0) midDiff = 360.0 - midDiff;
    // In ±12 hours Moon-Sun elongation changes by < 6.8°, so syzygy within 1.5°
    // is impossible when elongation at jd is > 9.0° from 0° or 180°.
    if (midDiff > 9.0 && (midDiff - 180.0).abs() > 9.0) {
      return false;
    }

    final gridJd = (jd * 24.0).roundToDouble() / 24.0;
    const step = 1.0 / 24.0;
    for (int i = -12; i <= 12; i++) {
      final t = gridJd + i * step;
      final moon = _geoMoonAt(t);
      if (moon.latitude.abs() <= 0.85) {
        final sun = Sweph.swe_calc_ut(t, HeavenlyBody.SE_SUN, _geoSwephFlag);
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
    final cacheKey = (
      date.year,
      date.month,
      date.day,
      (lat * 1000).round(),
      (lon * 1000).round(),
    );
    if (_sunriseSunsetCache[cacheKey] case final cached?) {
      return cached;
    }

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
      final polarInfo = SunriseSunsetInfo(noon: date);
      if (_sunriseSunsetCache.length >= 1024) {
        _sunriseSunsetCache.clear();
      }
      return _sunriseSunsetCache[cacheKey] = polarInfo;
    }

    final haDeg = math.acos(cosHA) * 180.0 / math.pi;

    final utcNoon = DateTime.utc(date.year, date.month, date.day, 12);
    final solarNoon = utcNoon.subtract(Duration(seconds: (lon * 240).toInt()));
    final halfDay = Duration(seconds: (haDeg * 240).toInt());

    final info = SunriseSunsetInfo(
      sunrise: solarNoon.subtract(halfDay).toLocal(),
      sunset: solarNoon.add(halfDay).toLocal(),
      noon: solarNoon.toLocal(),
    );
    if (_sunriseSunsetCache.length >= 1024) {
      _sunriseSunsetCache.clear();
    }
    return _sunriseSunsetCache[cacheKey] = info;
  }

  @override
  bool isNearNode(DateTime time) {
    final jd = _toJD(time);
    _ensureMoon(jd);
    // Moon latitude changes by at most ~0.33° in 6 hours; 0.45° is a conservative bound.
    if (_lastGeoLat.abs() > 0.45) {
      return false;
    }

    const step = 1.0 / 24.0;
    final gridJd = (jd * 24.0).roundToDouble() / 24.0;
    double prevLat = _geoMoonAt(gridJd - 0.5).latitude;
    for (int i = -12; i <= 12; i++) {
      final t = gridJd + i * step;
      final nextLat = _geoMoonAt(t + step).latitude;

      if (prevLat * nextLat <= 0 && prevLat != nextLat) {
        final double exactJD = t + step * (0 - prevLat) / (nextLat - prevLat);
        final double diffHours = (exactJD - jd) * 24.0;
        return diffHours.abs() <= 6.0;
      }
      prevLat = nextLat;
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

    const step = 2.0 / 24.0;
    final gridJd = (jd * 12.0).roundToDouble() / 12.0;
    double prevDist1 = double.infinity;
    double prevDist2 = double.infinity;
    double prevT2 = gridJd - 8 * step;

    for (int i = -8; i <= 8; i++) {
      final t = gridJd + i * step;
      final dist = _geoMoonAt(t).distance;
      if (i >= -6 && prevDist2 < prevDist1 && prevDist2 < dist) {
        final y1 = prevDist1;
        final y2 = prevDist2;
        final y3 = dist;
        final denom = 2 * (y1 + y3 - 2 * y2);
        if (denom <= 0) {
          return false;
        }
        final deltaT = -step * (y3 - y1) / denom;
        final exactT = prevT2 + deltaT;
        final double diffHours = (exactT - jd) * 24.0;
        return diffHours.abs() <= 12.0;
      }
      prevDist1 = prevDist2;
      prevDist2 = dist;
      prevT2 = t;
    }
    return false;
  }

  @override
  bool isNearApogee(DateTime time) {
    final jd = _toJD(time);
    _ensureMoon(jd);
    // Lunar apogee is always >= 0.002695 AU (403,000+ km); 0.00266 AU safely
    // prunes the rest of the orbit before scanning the ±16h neighborhood.
    if (_lastGeoDist < 0.00266) {
      return false;
    }

    const step = 2.0 / 24.0;
    final gridJd = (jd * 12.0).roundToDouble() / 12.0;
    double prevDist1 = -double.infinity;
    double prevDist2 = -double.infinity;
    double prevT2 = gridJd - 8 * step;

    for (int i = -8; i <= 8; i++) {
      final t = gridJd + i * step;
      final dist = _geoMoonAt(t).distance;
      if (i >= -6 && prevDist2 > prevDist1 && prevDist2 > dist) {
        final y1 = prevDist1;
        final y2 = prevDist2;
        final y3 = dist;
        final denom = 2 * (y1 + y3 - 2 * y2);
        final deltaT = denom != 0 ? -step * (y3 - y1) / denom : 0.0;
        final exactT = prevT2 + deltaT;
        final double diffHours = (exactT - jd) * 24.0;
        return diffHours.abs() <= 12.0;
      }
      prevDist1 = prevDist2;
      prevDist2 = dist;
      prevT2 = t;
    }
    return false;
  }

  @override
  bool isMoonSaturnOpposition(DateTime time) {
    final jd = _toJD(time);
    double moonLon;
    double saturnLon;
    if (_lastPlanetsJd == jd && _lastPlanets != null) {
      moonLon = _lastPlanets![1].longitude;
      saturnLon = _lastPlanets![6].longitude;
    } else {
      _ensureTopoConfigured();
      final moon = Sweph.swe_calc_ut(jd, HeavenlyBody.SE_MOON, _topoSwephFlag);
      final saturn = Sweph.swe_calc_ut(
        jd,
        HeavenlyBody.SE_SATURN,
        _topoSwephFlag,
      );
      moonLon = moon.longitude;
      saturnLon = saturn.longitude;
    }

    double diff = (moonLon - saturnLon).abs() % 360.0;
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
    const step = 1.0 / 24.0;
    final pos1 = Sweph.swe_calc_ut(
      jd - step,
      HeavenlyBody.SE_MOON,
      _geoSwephFlag,
    );
    final pos3 = Sweph.swe_calc_ut(
      jd + step,
      HeavenlyBody.SE_MOON,
      _geoSwephFlag,
    );

    final lat1 = pos1.latitude.abs();
    final lat2 = _lastGeoLat.abs();
    final lat3 = pos3.latitude.abs();

    return (lat2 >= lat1 && lat2 >= lat3 && lat2 >= 5.0) || lat2 >= 5.12;
  }

  @override
  List<CalendarInterval> getIntervals(DateTime start, DateTime end) {
    final searchStart = start.subtract(const Duration(days: 2));
    final searchEnd = end.add(const Duration(days: 2));
    final startJD = _toJD(searchStart);
    final endJD = _toJD(searchEnd);

    // Single pass at 1-hour steps across [searchStart, searchEnd] to extract:
    // 1. Node crossings (1-hour resolution)
    // 2. Perigee & Apogee extrema (2-hour resolution, every even step)
    final nodeWindows = <(double, double)>[];
    final perigeeWindows = <(double, double)>[];
    final apogeeWindows = <(double, double)>[];

    bool hasPrevious = false;
    double prevLat = 0.0;
    double prevLatT = startJD;

    int distSampleCount = 0;
    double prevDist1 = 0.0;
    double prevDist2 = 0.0;
    double prevDistT2 = startJD;

    const nodeStep = 1.0 / 24.0; // 1 hour steps
    const distStep = 2.0 / 24.0; // 2 hour steps
    int stepIndex = 0;
    for (double t = startJD; t <= endJD; t += nodeStep, stepIndex++) {
      final p = _geoMoonAt(t);
      if (hasPrevious && prevLat * p.latitude <= 0 && prevLat != p.latitude) {
        final exactT =
            prevLatT + nodeStep * (0 - prevLat) / (p.latitude - prevLat);
        nodeWindows.add((exactT - 6.0 / 24.0, exactT + 6.0 / 24.0));
      }
      prevLat = p.latitude;
      prevLatT = t;
      hasPrevious = true;

      if (stepIndex.isEven) {
        if (distSampleCount >= 2) {
          if (prevDist2 <= 0.00258 &&
              prevDist2 < prevDist1 &&
              prevDist2 < p.distance) {
            final y1 = prevDist1;
            final y2 = prevDist2;
            final y3 = p.distance;
            final denom = 2 * (y1 + y3 - 2 * y2);
            final deltaT = denom > 0 ? -distStep * (y3 - y1) / denom : 0.0;
            final exactT = prevDistT2 + deltaT;
            perigeeWindows.add((exactT - 12.0 / 24.0, exactT + 12.0 / 24.0));
          } else if (prevDist2 >= 0.00266 &&
              prevDist2 > prevDist1 &&
              prevDist2 > p.distance) {
            final y1 = prevDist1;
            final y2 = prevDist2;
            final y3 = p.distance;
            final denom = 2 * (y1 + y3 - 2 * y2);
            final deltaT = denom != 0 ? -distStep * (y3 - y1) / denom : 0.0;
            final exactT = prevDistT2 + deltaT;
            apogeeWindows.add((exactT - 12.0 / 24.0, exactT + 12.0 / 24.0));
          }
        }
        prevDist1 = prevDist2;
        prevDist2 = p.distance;
        prevDistT2 = t;
        distSampleCount++;
      }
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

        final isNearApogeeVal = apogeeWindows.any(
          (w) => currentJD >= w.$1 && currentJD <= w.$2,
        );
        final planets = getPlanets(current);
        final isMoonSaturnOpp = isMoonSaturnOpposition(current);
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
