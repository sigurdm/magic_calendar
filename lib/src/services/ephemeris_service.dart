import 'dart:isolate';
import 'dart:async';
import 'dart:math' as math;

import 'package:sweph/sweph.dart';

import '../core/dornach_boundaries.dart';
import '../core/algorithm.dart' as algo;

/// Plant qualities for agricultural biodynamic calendar.
enum PlantQuality { root, leaf, flower, fruit, none }

/// Info class for sunrise, sunset, and solar noon times.
final class SunriseSunsetInfo {
  /// Sunrise time, if applicable.
  final DateTime? sunrise;

  /// Sunset time, if applicable.
  final DateTime? sunset;

  /// Solar noon time.
  final DateTime noon;

  /// Creates [SunriseSunsetInfo].
  SunriseSunsetInfo({this.sunrise, this.sunset, required this.noon});
}

/// Represents position information for a planet.
final class PlanetInfo {
  /// Name of planet.
  final String name;

  /// Ecliptic longitude (0-360 degrees).
  final double longitude;

  /// Creates [PlanetInfo].
  const PlanetInfo({required this.name, required this.longitude});
}

/// Represents lunar phase calculations.
final class MoonPhaseInfo {
  /// Fraction illuminated (0.0 to 1.0).
  final double illuminatedFraction;

  /// True if waxing, false if waning.
  final bool isWaxing;

  /// Phase angle in degrees.
  final double phaseAngle;

  /// Creates [MoonPhaseInfo].
  const MoonPhaseInfo({
    required this.illuminatedFraction,
    required this.isWaxing,
    required this.phaseAngle,
  });

  /// Name of moon phase.
  String get name {
    if (illuminatedFraction > 0.97) {
      return 'Full Moon';
    }
    if (illuminatedFraction < 0.03) {
      return 'New Moon';
    }
    if (illuminatedFraction >= 0.48 && illuminatedFraction <= 0.52) {
      return isWaxing ? 'First Quarter' : 'Last Quarter';
    }
    if (isWaxing) {
      return illuminatedFraction < 0.5 ? 'Waxing Crescent' : 'Waxing Gibbous';
    } else {
      return illuminatedFraction > 0.5 ? 'Waning Gibbous' : 'Waning Crescent';
    }
  }
}

/// Aggregated calendar information for a given timestamp.
final class CalendarInfo {
  /// Plant quality.
  final PlantQuality quality;

  /// True if Gray Day.
  final bool isGrayDay;

  /// True if Special Day (e.g. planetary trine aspect).
  final bool isSpecial;

  /// True if Moon is near Apogee (Ag).
  final bool isApogee;

  /// True if Moon is in opposition (180 deg) with Saturn.
  final bool isMoonSaturnOpposition;

  /// Message describing Gray Day condition or Special Day.
  final String message;

  /// Sap flow vector text.
  final String sapFlow;

  /// Vitality description text.
  final String vitality;

  /// Moon phase info.
  final MoonPhaseInfo moonPhase;

  /// List of planetary positions.
  final List<PlanetInfo> planets;

  /// Creates [CalendarInfo].
  CalendarInfo({
    required this.quality,
    required this.isGrayDay,
    this.isSpecial = false,
    this.isApogee = false,
    this.isMoonSaturnOpposition = false,
    required this.message,
    required this.sapFlow,
    required this.vitality,
    required this.moonPhase,
    required this.planets,
  });
}

/// Maps ecliptic [longitude] to [PlantQuality] based on constellation boundaries.
PlantQuality getQualityFromLongitude(
  double longitude, [
  List<ConstellationBoundary> boundaries = dornachBoundaries,
]) {
  double normLon = longitude % 360.0;
  if (normLon < 0) {
    normLon += 360.0;
  }
  for (var boundary in boundaries) {
    if (boundary.startDegree <= boundary.endDegree) {
      if (normLon >= boundary.startDegree && normLon < boundary.endDegree) {
        switch (boundary.element) {
          case 'Earth':
            return PlantQuality.root;
          case 'Water':
            return PlantQuality.leaf;
          case 'Air':
            return PlantQuality.flower;
          case 'Fire':
            return PlantQuality.fruit;
        }
      }
    } else {
      if (normLon >= boundary.startDegree || normLon < boundary.endDegree) {
        switch (boundary.element) {
          case 'Earth':
            return PlantQuality.root;
          case 'Water':
            return PlantQuality.leaf;
          case 'Air':
            return PlantQuality.flower;
          case 'Fire':
            return PlantQuality.fruit;
        }
      }
    }
  }
  return PlantQuality.none;
}

/// Abstract contract for ephemeris services computing astronomical data.
abstract mixin class EphemerisService {
  /// Obtains moon ecliptic longitude at [time].
  double getMoonLongitude(DateTime time);

  /// True if Moon is near ascending or descending node at [time].
  bool isNearNode(DateTime time);

  /// True if Moon is near perigee at [time].
  bool isNearPerigee(DateTime time);

  /// True if Moon is near apogee at [time].
  bool isNearApogee(DateTime time);

  /// True if Moon is in opposition (180 deg) with Saturn at [time].
  bool isMoonSaturnOpposition(DateTime time);

  /// True if Moon is square node at [time].
  bool isMoonSquareNode(DateTime time);

  /// Calculates declination of Moon at [time].
  double getMoonDeclination(DateTime time);

  /// Calculates moon phase for [time].
  MoonPhaseInfo getMoonPhase(DateTime time);

  /// Calculates positions of planets at [time].
  List<PlanetInfo> getPlanets(DateTime time);

  /// Returns calendar intervals between [start] and [end].
  FutureOr<List<CalendarInterval>> getIntervals(DateTime start, DateTime end);

  /// Calculates sunrise and sunset for [date] at [lat], [lon].
  SunriseSunsetInfo getSunriseSunset(DateTime date, double lat, double lon);
}

/// Time interval quality entry.
final class CalendarInterval {
  /// Start time of interval.
  final DateTime start;

  /// End time of interval.
  final DateTime end;

  /// Plant quality.
  final PlantQuality quality;

  /// True if Gray Day.
  final bool isGrayDay;

  /// True if Special Day.
  final bool isSpecial;

  /// Message explaining quality or Gray Day.
  final String message;

  /// Creates [CalendarInterval].
  CalendarInterval({
    required this.start,
    required this.end,
    required this.quality,
    required this.isGrayDay,
    this.isSpecial = false,
    required this.message,
  });
}

enum _WorkerCommand { getInfo, getIntervals }

final class _WorkerRequest {
  final _WorkerCommand command;
  final SendPort replyPort;
  final Map<String, dynamic> params;
  _WorkerRequest(this.command, this.replyPort, this.params);
}

/// Background isolate worker managing Swiss Ephemeris FFI computations.
final class EphemerisWorker {
  static SendPort? _sendPort;
  static Future<void>? _initFuture;

  /// Initializes persistent background isolate worker.
  static Future<void> init({String? epheFilesPath}) {
    return _initFuture ??= _doInit(epheFilesPath);
  }

  static Future<void> _doInit(String? epheFilesPath) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_isolateEntry, {
      'sendPort': receivePort.sendPort,
      'epheFilesPath': epheFilesPath,
    });
    _sendPort = await receivePort.first as SendPort;
  }

  /// Obtains calendar info in background isolate.
  static Future<CalendarInfo> getCalendarInfo(
    DateTime time,
    bool includePlanets,
  ) async {
    await init();
    final port = ReceivePort();
    try {
      _sendPort!.send(
        _WorkerRequest(_WorkerCommand.getInfo, port.sendPort, {
          'time': time,
          'includePlanets': includePlanets,
        }),
      );
      return await port.first as CalendarInfo;
    } finally {
      port.close();
    }
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
        _WorkerRequest(_WorkerCommand.getIntervals, port.sendPort, {
          'start': start,
          'end': end,
        }),
      );
      return await port.first as List<CalendarInterval>;
    } finally {
      port.close();
    }
  }

  static void _isolateEntry(Map<String, dynamic> initData) async {
    final sendPort = initData['sendPort'] as SendPort;
    final epheFilesPath = initData['epheFilesPath'] as String?;
    await Sweph.init(epheFilesPath: epheFilesPath);
    final service = AstronomiaEphemerisService();
    final receivePort = ReceivePort();

    sendPort.send(receivePort.sendPort);

    await for (var message in receivePort) {
      if (message is _WorkerRequest) {
        if (message.command == _WorkerCommand.getInfo) {
          final info = algo.getCalendarInfo(
            message.params['time'],
            service,
            includePlanets: message.params['includePlanets'],
          );
          message.replyPort.send(info);
        } else if (message.command == _WorkerCommand.getIntervals) {
          final intervals = service.getIntervals(
            message.params['start'],
            message.params['end'],
          );
          message.replyPort.send(intervals);
        }
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
}

/// Swiss Ephemeris service implementing [EphemerisService].
final class AstronomiaEphemerisService implements EphemerisService {
  /// Creates [AstronomiaEphemerisService].
  AstronomiaEphemerisService();

  static const int _topoFlags = 2 | 256 | 32768;
  static const int _geoFlags = 2 | 256;

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
    final fractionalHour = utc.hour +
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
    double jd = _toJD(time);
    _ensureMoon(jd);
    return _lastGeoLon;
  }

  @override
  double getMoonDeclination(DateTime time) {
    Sweph.swe_set_topo(7.6178, 47.4814, 350.0);
    double jd = _toJD(time);
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

    Sweph.swe_set_topo(7.6178, 47.4814, 350.0);
    double jd = _toJD(time);
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

    double rad = diff * math.pi / 180.0;
    double illuminatedFraction = (1 - math.cos(rad)) / 2.0;
    bool isWaxing = diff < 180.0;

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
    Sweph.swe_set_topo(7.6178, 47.4814, 350.0);

    double jd = _toJD(time);
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

      if (pos1.latitude * pos2.latitude <= 0 && pos1.latitude != pos2.latitude) {
        double exactJD =
            t + step * (0 - pos1.latitude) / (pos2.latitude - pos1.latitude);
        double diffHours = (exactJD - jd) * 24.0;
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
    double diffHours = (exactT - jd) * 24.0;
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
        double diffHours = (exactT - jd) * 24.0;
        return diffHours.abs() <= 12.0;
      }
    }
    return false;
  }

  @override
  bool isMoonSaturnOpposition(DateTime time) {
    final jd = _toJD(time);
    final moon = Sweph.swe_calc_ut(
      jd,
      HeavenlyBody.SE_MOON,
      SwephFlag(_geoFlags),
    );
    final saturn = Sweph.swe_calc_ut(
      jd,
      HeavenlyBody.SE_SATURN,
      SwephFlag(_geoFlags),
    );

    double diff = (moon.longitude - saturn.longitude).abs();
    if (diff > 180.0) {
      diff = 360.0 - diff;
    }
    return (diff - 180.0).abs() <= 6.0;
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
    double prevLat = 0.0;
    double prevLatT = startJD;
    const nodeStep = 1.0 / 24.0; // 1 hour steps
    for (double t = startJD; t <= endJD; t += nodeStep) {
      final p = Sweph.swe_calc_ut(t, HeavenlyBody.SE_MOON, SwephFlag(_geoFlags));
      if (prevLatT != startJD && prevLat * p.latitude <= 0 && prevLat != p.latitude) {
        final exactT = prevLatT + nodeStep * (0 - prevLat) / (p.latitude - prevLat);
        nodeWindows.add((exactT - 6.0 / 24.0, exactT + 6.0 / 24.0));
      }
      prevLat = p.latitude;
      prevLatT = t;
    }

    // 2. Scan for Perigee extrema across [searchStart, searchEnd]
    final perigeeWindows = <(double, double)>[];
    double prevDist1 = double.infinity;
    double prevDist2 = double.infinity;
    double prevDistT2 = startJD;
    const perigeeStep = 2.0 / 24.0; // 2 hour steps
    for (double t = startJD; t <= endJD; t += perigeeStep) {
      final p = Sweph.swe_calc_ut(t, HeavenlyBody.SE_MOON, SwephFlag(_geoFlags));
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
        message = 'Gray Day: Moon Node (N). Plant rest recommended.';
      } else if (isNearPerigee) {
        message = 'Gray Day: Near Lunar Perigee (Pg).';
      }

      PlantQuality quality = PlantQuality.none;
      if (!isGrayDay) {
        final moonLon = getMoonLongitude(current);
        quality = getQualityFromLongitude(moonLon, dornachBoundaries);
      }

      if (intervals.isNotEmpty) {
        final last = intervals.last;
        if (last.quality == quality &&
            last.isGrayDay == isGrayDay &&
            !last.isSpecial &&
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
          isSpecial: false,
          message: message,
        ),
      );

      current = intervalEnd;
    }

    return intervals;
  }
}
