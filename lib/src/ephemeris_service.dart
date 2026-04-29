import 'dart:isolate';
import 'dart:async';
import 'dart:math' as math;
import 'package:sweph/sweph.dart';
import 'dornach_boundaries.dart';
import 'algorithm.dart' as algo;

enum PlantQuality { root, leaf, flower, fruit, none }

class SunriseSunsetInfo {
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime noon;

  SunriseSunsetInfo({this.sunrise, this.sunset, required this.noon});
}

class PlanetInfo {
  final String name;
  final double longitude; // degrees 0-360

  PlanetInfo({required this.name, required this.longitude});
}

class MoonPhaseInfo {
  final double illuminatedFraction;
  final bool isWaxing;
  final double phaseAngle;

  MoonPhaseInfo({
    required this.illuminatedFraction,
    required this.isWaxing,
    required this.phaseAngle,
  });

  String get name {
    if (illuminatedFraction > 0.97) return 'Full Moon';
    if (illuminatedFraction < 0.03) return 'New Moon';
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

class CalendarInfo {
  final PlantQuality quality;
  final bool isGrayDay;
  final String message;
  final String sapFlow;
  final String vitality;
  final MoonPhaseInfo moonPhase;
  final List<PlanetInfo> planets;

  CalendarInfo({
    required this.quality,
    required this.isGrayDay,
    required this.message,
    required this.sapFlow,
    required this.vitality,
    required this.moonPhase,
    required this.planets,
  });
}

PlantQuality getQualityFromLongitude(
  double longitude, [
  List<ConstellationBoundary> boundaries = dornachBoundaries,
]) {
  for (var boundary in boundaries) {
    if (longitude >= boundary.startDegree && longitude < boundary.endDegree) {
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
  return PlantQuality.none;
}

abstract class EphemerisService {
  double getMoonLongitude(DateTime time);
  bool isNearNode(DateTime time);
  bool isNearPerigee(DateTime time);
  bool isMoonSquareNode(DateTime time);
  MoonPhaseInfo getMoonPhase(DateTime time);
  double getMoonDeclination(DateTime time);
  List<PlanetInfo> getPlanets(DateTime time);
  List<CalendarInterval> getIntervals(DateTime start, DateTime end);
  SunriseSunsetInfo getSunriseSunset(DateTime date, double lat, double lon);
}

class CalendarInterval {
  final DateTime start;
  final DateTime end;
  final PlantQuality quality;
  final bool isGrayDay;
  final String message;

  CalendarInterval({
    required this.start,
    required this.end,
    required this.quality,
    required this.isGrayDay,
    required this.message,
  });
}



// --- Isolate Worker Implementation ---

enum _WorkerCommand { getInfo, getIntervals }

class _WorkerRequest {
  final _WorkerCommand command;
  final SendPort replyPort;
  final Map<String, dynamic> params;
  _WorkerRequest(this.command, this.replyPort, this.params);
}

class EphemerisWorker {
  static SendPort? _sendPort;
  static final Completer<void> _initCompleter = Completer<void>();

  /// Spawns the persistent background isolate
  static Future<void> init() async {
    if (_initCompleter.isCompleted) return;
    final receivePort = ReceivePort();
    await Isolate.spawn(_isolateEntry, receivePort.sendPort);
    _sendPort = await receivePort.first as SendPort;
    _initCompleter.complete();
  }

  static Future<CalendarInfo> getCalendarInfo(DateTime time, bool includePlanets) async {
    await _initCompleter.future;
    final port = ReceivePort();
    _sendPort!.send(_WorkerRequest(_WorkerCommand.getInfo, port.sendPort, {
      'time': time,
      'includePlanets': includePlanets,
    }));
    return await port.first as CalendarInfo;
  }

  static Future<List<CalendarInterval>> getIntervals(DateTime start, DateTime end) async {
    await _initCompleter.future;
    final port = ReceivePort();
    _sendPort!.send(_WorkerRequest(_WorkerCommand.getIntervals, port.sendPort, {
      'start': start,
      'end': end,
    }));
    return await port.first as List<CalendarInterval>;
  }

  static void _isolateEntry(SendPort sendPort) async {
    // Initialize FFI in the background isolate
    await Sweph.init(); 
    final service = AstronomiaEphemerisService();
    final receivePort = ReceivePort();
    
    // Handshake: send the SendPort back to the main isolate
    sendPort.send(receivePort.sendPort);

    // Event loop for incoming requests
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

// -----------------------------------

class AstronomiaEphemerisService implements EphemerisService {
  AstronomiaEphemerisService() {
    // Topo set is handled in _ensureMoon to prevent isolate state loss.
  }

  // SEFLG_MOSEPH (4) = Use Moshier Ephemeris (no file required, highly accurate)
  // SEFLG_SPEED (256) = Calculate speed
  // SEFLG_TOPOCTR (32768) = Topocentric coordinates for constellation mapping
  static const int _topoFlags = 4 | 256 | 32768; 
  static const int _geoFlags = 4 | 256;

  // Cache structures
  final Map<DateTime, CalendarInfo> _infoCache = {};
  final Map<DateTime, MoonPhaseInfo> _phaseCache = {};

  // Microsecond FFI Cache
  double? _lastJd;
  double _lastGeoLat = 0;
  double _lastGeoDist = 0;
  double _lastTopoLon = 0;

  void _ensureMoon(double jd) {
    if (_lastJd != jd) {
      _lastJd = jd;
      final geo = Sweph.swe_calc_ut(jd, HeavenlyBody.SE_MOON, SwephFlag(_geoFlags));
      
      // Ensure topocentric location is set for this thread/isolate C-context
      Sweph.swe_set_topo(7.6178, 47.4814, 350.0);
      
      final topo = Sweph.swe_calc_ut(jd, HeavenlyBody.SE_MOON, SwephFlag(_topoFlags));
      _lastGeoLat = geo.latitude;
      _lastGeoDist = geo.distance;
      _lastTopoLon = topo.longitude;
    }
  }

  // Persistent search caches
  double? _lastNodeJD;
  double? _lastPerigeeJD;

  double _toJD(DateTime time) {
    final utc = time.toUtc();
    // Note: SWEPH julian day includes fraction of the day
    return Sweph.swe_julday(utc.year, utc.month, utc.day, utc.hour + utc.minute / 60.0 + utc.second / 3600.0, CalendarType.SE_GREG_CAL);
  }

  @override
  double getMoonLongitude(DateTime time) {
    double jd = _toJD(time);
    _ensureMoon(jd);
    return _lastTopoLon;
  }

  @override
  double getMoonDeclination(DateTime time) {
    double jd = _toJD(time);
    final pos = Sweph.swe_calc_ut(jd, HeavenlyBody.SE_MOON, SwephFlag(_topoFlags | 2048));
    return pos.latitude; // In equatorial mode, latitude maps to Declination
  }

  @override
  MoonPhaseInfo getMoonPhase(DateTime time) {
    final utc = time.toUtc();
    final cacheKey = DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute);
    if (_phaseCache.containsKey(cacheKey)) return _phaseCache[cacheKey]!;

    double jd = _toJD(time);
    final sun = Sweph.swe_calc_ut(jd, HeavenlyBody.SE_SUN, SwephFlag(_topoFlags));
    final moon = Sweph.swe_calc_ut(jd, HeavenlyBody.SE_MOON, SwephFlag(_topoFlags));

    double diff = moon.longitude - sun.longitude;
    if (diff < 0) diff += 360.0;

    // Approximate illumination based on phase angle
    double rad = diff * math.pi / 180.0;
    double illuminatedFraction = (1 - math.cos(rad)) / 2.0;
    bool isWaxing = diff < 180.0;

    final info = MoonPhaseInfo(
      illuminatedFraction: illuminatedFraction,
      isWaxing: isWaxing,
      phaseAngle: diff,
    );

    if (_phaseCache.length > 1000) _phaseCache.clear();
    return _phaseCache[cacheKey] = info;
  }

  @override
  List<PlanetInfo> getPlanets(DateTime time) {
    // Ensure topocentric location is set for this thread/isolate C-context
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
    
    // Sun declination approximation
    final decRad = -23.44 * math.cos((360.0 / 365.0) * (dayOfYear + 10) * math.pi / 180.0) * math.pi / 180.0;
    final latRad = lat * math.pi / 180.0;

    // Hour angle calculation (using -0.83 degrees for atmospheric refraction)
    final cosHA = (math.sin(-0.83 * math.pi / 180.0) - math.sin(latRad) * math.sin(decRad)) / 
                  (math.cos(latRad) * math.cos(decRad));
                  
    if (cosHA < -1.0 || cosHA > 1.0) {
      return SunriseSunsetInfo(noon: date); // Sun never rises or sets
    }
    
    final haDeg = math.acos(cosHA) * 180.0 / math.pi;
    
    // Solar noon in UTC = 12:00 - longitude offset. (No Equation of Time for simplicity).
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
    
    // CACHE: If we recently found a node, just check distance to it.
    if (_lastNodeJD != null && (jd - _lastNodeJD!).abs() < 1.0) {
      return (jd - _lastNodeJD!).abs() * 24.0 <= 6.0;
    }

    // FAST PATH: Moon latitude changes at most ~0.06 deg/hour.
    // In a 6 hour window, it changes by at most 0.4 degrees.
    _ensureMoon(jd);
    if (_lastGeoLat.abs() > 0.6) return false;

    final step = 1.0 / 24.0;

    // Search ±6 hours (0.25 days)
    for (double t = jd - 0.25; t <= jd + 0.25; t += step) {
      final pos1 = Sweph.swe_calc_ut(t, HeavenlyBody.SE_MOON, SwephFlag(_geoFlags));
      final pos2 = Sweph.swe_calc_ut(t + step, HeavenlyBody.SE_MOON, SwephFlag(_geoFlags));
      
      if (pos1.latitude * pos2.latitude <= 0) {
        double exactJD = t + step * (0 - pos1.latitude) / (pos2.latitude - pos1.latitude);
        _lastNodeJD = exactJD; // Cache the event
        double diffHours = (exactJD - jd) * 24.0;
        return diffHours.abs() <= 6.0;
      }
    }
    return false;
  }

  @override
  bool isNearPerigee(DateTime time) {
    final jd = _toJD(time);
    
    // CACHE: If we recently found a perigee, just check distance to it.
    if (_lastPerigeeJD != null && (jd - _lastPerigeeJD!).abs() < 1.0) {
      return (jd - _lastPerigeeJD!).abs() * 24.0 <= 12.0;
    }

    // FAST PATH: Max perigee distance is ~0.00246 AU.
    // In a 12 hour window, distance changes by at most ~0.00003 AU.
    _ensureMoon(jd);
    if (_lastGeoDist > 0.00250) return false;

    final step = 1.0 / 24.0;

    // Search ±12 hours (0.5 days)
    for (double t = jd - 0.5; t <= jd + 0.5; t += step) {
      final d1 = Sweph.swe_calc_ut(t - step, HeavenlyBody.SE_MOON, SwephFlag(_geoFlags)).distance;
      final d2 = Sweph.swe_calc_ut(t, HeavenlyBody.SE_MOON, SwephFlag(_geoFlags)).distance;
      final d3 = Sweph.swe_calc_ut(t + step, HeavenlyBody.SE_MOON, SwephFlag(_geoFlags)).distance;

      if (d2 < d1 && d2 < d3) {
        double a = (d1 + d3 - 2 * d2) / 2.0;
        double b = (d3 - d1) / 2.0;
        double offset = -b / (2 * a);
        double exactJD = t + offset * step;
        _lastPerigeeJD = exactJD; // Cache the event
        double diffHours = (exactJD - jd) * 24.0;
        
        return diffHours.abs() <= 12.0;
      }
    }
    return false;
  }

  @override
  bool isMoonSquareNode(DateTime time) => false;

  @override
  List<CalendarInterval> getIntervals(DateTime start, DateTime end) {
    List<CalendarInterval> intervals = [];
    DateTime current = start;

    // Use minimal flag to skip Moon Phase calculations inside the loop
    CalendarInfo currentInfo = _getCalendarInfo(current, minimal: true);
    DateTime intervalStart = current;

    while (current.isBefore(end)) {
      final info = _getCalendarInfo(current, minimal: true);

      // Calculate the maximum safe jump...
      Duration safeJump = const Duration(minutes: 60);
      if (!info.isGrayDay) {
        final tConst = _timeToNextConstellation(current);
        safeJump = tConst < const Duration(hours: 6) ? tConst : const Duration(hours: 6);
        if (safeJump < const Duration(minutes: 15)) safeJump = const Duration(minutes: 15);
      }

      current = current.add(safeJump);
      if (current.isAfter(end)) current = end;

      final nextInfo = _getCalendarInfo(current, minimal: true);

      if (nextInfo.quality != currentInfo.quality || nextInfo.isGrayDay != currentInfo.isGrayDay) {
        DateTime t0 = current.subtract(safeJump);
        DateTime t1 = current;
        DateTime transitionTime = _findTransition(t0, t1, currentInfo.quality, currentInfo.isGrayDay);

        intervals.add(CalendarInterval(
          start: intervalStart,
          end: transitionTime,
          quality: currentInfo.quality,
          isGrayDay: currentInfo.isGrayDay,
          message: currentInfo.message,
        ));

        intervalStart = transitionTime;
        current = transitionTime.add(const Duration(minutes: 1));
        currentInfo = _getCalendarInfo(current, minimal: true);
      }
    }

    intervals.add(CalendarInterval(
      start: intervalStart,
      end: end,
      quality: currentInfo.quality,
      isGrayDay: currentInfo.isGrayDay,
      message: currentInfo.message,
    ));

    return intervals;
  }

  DateTime _findTransition(DateTime t0, DateTime t1, PlantQuality q0, bool g0) {
    while (t1.difference(t0).inMinutes > 1) {
      DateTime mid = t0.add(Duration(minutes: (t1.difference(t0).inMinutes / 2).round()));
      final info = _getCalendarInfo(mid, minimal: true);
      if (info.quality == q0 && info.isGrayDay == g0) {
        t0 = mid;
      } else {
        t1 = mid;
      }
    }
    return t0;
  }

  CalendarInfo _getCalendarInfo(DateTime time, {bool includePlanets = false, bool minimal = false}) {
    if (!includePlanets && !minimal && _infoCache.containsKey(time)) return _infoCache[time]!;

    double moonLongitude = getMoonLongitude(time);
    bool nearNode = isNearNode(time);
    bool nearPerigee = isNearPerigee(time);
    bool isGrayDay = nearNode || nearPerigee;

    // Skip expensive Moon Phase logic if we only need basic info for boundary searching
    final moonPhase = minimal ? MoonPhaseInfo(illuminatedFraction: 0, isWaxing: false, phaseAngle: 0) : getMoonPhase(time);

    String message = '';
    if (nearNode) message = 'Gray Day: Near Lunar Node.';
    else if (nearPerigee) message = 'Gray Day: Near Lunar Perigee.';

    PlantQuality quality = getQualityFromLongitude(moonLongitude);

    final info = CalendarInfo(
      quality: isGrayDay ? PlantQuality.none : quality,
      isGrayDay: isGrayDay,
      message: message,
      sapFlow: 'Ascending',
      vitality: moonPhase.name,
      moonPhase: moonPhase,
      planets: includePlanets ? getPlanets(time) : [],
    );

    if (!includePlanets) {
      if (_infoCache.length > 5000) _infoCache.clear();
      _infoCache[time] = info;
    }

    return info;
  }

  Duration _timeToNextConstellation(DateTime time) {
    final long = getMoonLongitude(time);
    double minDiff = 360.0;
    for (var boundary in dornachBoundaries) {
      double diff = (boundary.startDegree - long) % 360.0;
      if (diff < 0) diff += 360.0;
      if (diff < minDiff) minDiff = diff;
    }
    // Moon max speed is ~0.65 deg/hour.
    double hours = minDiff / 0.65;
    return Duration(minutes: (hours * 60).round());
  }
}

