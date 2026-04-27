import 'package:astronomia/moonposition.dart' as moonpos;
import 'package:astronomia/moonillum.dart' as moonillum;
import 'package:astronomia/planetposition.dart' as planetpos;
import 'package:astronomia/solar.dart' as solar;
import 'package:astronomia/coord.dart' as coord;
import 'package:astronomia/nutation.dart';
import 'package:astronomia/astronomia.dart';
import 'package:astronomia/sunrise.dart' as sunrise;
import 'dart:math' as math;
import 'dornach_boundaries.dart';
import 'algorithm.dart';

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

class IntervalRequest {
  final DateTime start;
  final DateTime end;
  IntervalRequest(this.start, this.end);
}

List<CalendarInterval> computeIntervalsInIsolate(IntervalRequest req) {
  return AstronomiaEphemerisService().getIntervals(req.start, req.end);
}

class InfoRequest {
  final DateTime time;
  final bool includePlanets;
  InfoRequest(this.time, this.includePlanets);
}

CalendarInfo computeCalendarInfoInIsolate(InfoRequest req) {
  return getCalendarInfo(
    req.time,
    AstronomiaEphemerisService(),
    includePlanets: req.includePlanets,
  );
}

class AstronomiaEphemerisService implements EphemerisService {
  final _earth = planetpos.Planet(planetpos.planetEarth);
  final _mercury = planetpos.Planet(planetpos.planetMercury);
  final _venus = planetpos.Planet(planetpos.planetVenus);
  final _mars = planetpos.Planet(planetpos.planetMars);
  final _jupiter = planetpos.Planet(planetpos.planetJupiter);
  final _saturn = planetpos.Planet(planetpos.planetSaturn);

  // High performance caches
  final Map<int, dynamic> _moonPosCache = {};
  final Map<DateTime, CalendarInfo> _infoCache = {};
  final Map<DateTime, List<PlanetInfo>> _planetsCache = {};
  final Map<DateTime, MoonPhaseInfo> _phaseCache = {};

  dynamic _getMoonPosition(double jd) {
    // Round JD to nearest 10 seconds (roughly) for cache alignment
    final key = (jd * 8640.0).round();
    if (_moonPosCache.containsKey(key)) return _moonPosCache[key]!;
    final pos = moonpos.position(jd);
    if (_moonPosCache.length > 5000) _moonPosCache.clear();
    return _moonPosCache[key] = pos;
  }

  @override
  double getMoonLongitude(DateTime time) {
    double jd = _toJD(time);
    return _getMoonPosition(jd).lon * 180 / math.pi;
  }

  @override
  double getMoonDeclination(DateTime time) {
    double jd = _toJD(time);
    final pos = _getMoonPosition(jd);
    final eps = meanObliquity(jd);
    final eq = coord.eclToEq(pos.lon, pos.lat, math.sin(eps), math.cos(eps));
    return eq.dec * 180 / math.pi;
  }

  double _toJD(DateTime time) {
    double dayFraction =
        time.day +
        time.hour / 24.0 +
        time.minute / 1440.0 +
        time.second / 86400.0;
    return calendarGregorianToJD(time.year, time.month, dayFraction);
  }

  @override
  MoonPhaseInfo getMoonPhase(DateTime time) {
    // Round to 1 minute UTC for smoothness and cache stability
    final utc = time.toUtc();
    final cacheKey = DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
    );
    if (_phaseCache.containsKey(cacheKey)) return _phaseCache[cacheKey]!;

    double jd = _toJD(time);
    double i = moonillum.phaseAngle3(jd);
    double k = moonillum.illuminated(i);

    double t = j2000Century(jd);
    double d = mod2pi(
      toRad(
        horner(t, [
          297.8501921,
          445267.1114034,
          -0.0018819,
          1 / 545868.0,
          -1 / 113065000.0,
        ]),
      ),
    );

    bool isWaxing = d < math.pi;

    final info = MoonPhaseInfo(
      illuminatedFraction: k,
      isWaxing: isWaxing,
      phaseAngle: i,
    );

    if (_phaseCache.length > 1000) _phaseCache.clear();
    return _phaseCache[cacheKey] = info;
  }

  @override
  List<PlanetInfo> getPlanets(DateTime time) {
    // Round time to nearest 1 minute in UTC for visual smoothness and cache stability
    final utc = time.toUtc();
    final cacheKey = DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
    );
    if (_planetsCache.containsKey(cacheKey)) return _planetsCache[cacheKey]!;

    double jd = _toJD(time);
    double t = j2000Century(jd);

    final results = <PlanetInfo>[];

    final sun = solar.trueSun(t);
    results.add(PlanetInfo(name: 'Sun', longitude: sun.lon * 180 / math.pi));
    results.add(PlanetInfo(name: 'Moon', longitude: getMoonLongitude(time)));

    results.add(_getGeocentricPlanet('Mercury', _mercury, jd));
    results.add(_getGeocentricPlanet('Venus', _venus, jd));
    results.add(_getGeocentricPlanet('Mars', _mars, jd));
    results.add(_getGeocentricPlanet('Jupiter', _jupiter, jd));
    results.add(_getGeocentricPlanet('Saturn', _saturn, jd));

    if (_planetsCache.length > 2000) _planetsCache.clear();
    return _planetsCache[cacheKey] = results;
  }

  PlanetInfo _getGeocentricPlanet(
    String name,
    planetpos.Planet planet,
    double jd,
  ) {
    final pPos = planet.position(jd);
    final ePos = _earth.position(jd);

    final x =
        pPos.range * math.cos(pPos.lat) * math.cos(pPos.lon) -
        ePos.range * math.cos(ePos.lat) * math.cos(ePos.lon);
    final y =
        pPos.range * math.cos(pPos.lat) * math.sin(pPos.lon) -
        ePos.range * math.cos(ePos.lat) * math.sin(ePos.lon);

    double lon = math.atan2(y, x) * 180 / math.pi;
    if (lon < 0) lon += 360;

    return PlanetInfo(name: name, longitude: lon);
  }

  @override
  SunriseSunsetInfo getSunriseSunset(DateTime date, double lat, double lon) {
    // Astronomia expects jd to be the center of the period to search.
    // Passing 12h UTC ensures we find the sunrise and sunset for this calendar day.
    final dateMidday = DateTime.utc(date.year, date.month, date.day, 12);
    double jd = _toJD(dateMidday);

    final latRad = lat * math.pi / 180;
    final lonRad = -lon * math.pi / 180;
    final result = sunrise.sunriseSunset(jd, latRad, lonRad);

    return SunriseSunsetInfo(
      sunrise: result.rise != null ? _fromJD(result.rise!) : null,
      sunset: result.set != null ? _fromJD(result.set!) : null,
      noon: _fromJD(result.noon),
    );
  }

  DateTime _fromJD(double jd) {
    final seconds = (jd - 2440587.5) * 86400.0;
    return DateTime.fromMillisecondsSinceEpoch(
      (seconds * 1000).round(),
      isUtc: true,
    ).toLocal();
  }

  @override
  bool isNearNode(DateTime time) {
    double jd = _toJD(time);
    final pos = _getMoonPosition(jd);
    final node = moonpos.node(jd);

    double moonLong = pos.lon * 180 / math.pi;
    double nodeLong1 = node * 180 / math.pi;
    double nodeLong2 = (nodeLong1 + 180.0) % 360.0;

    double diff1 = (moonLong - nodeLong1).abs();
    if (diff1 > 180) diff1 = 360 - diff1;

    double diff2 = (moonLong - nodeLong2).abs();
    if (diff2 > 180) diff2 = 360 - diff2;

    return diff1 < 2.43 || diff2 < 2.43;
  }

  @override
  bool isNearPerigee(DateTime time) {
    double jd = _toJD(time);
    final pos = _getMoonPosition(jd);
    final perigee = moonpos.perigee(jd);

    double moonLong = pos.lon * 180 / math.pi;
    double perigeeLong = perigee * 180 / math.pi;

    double diff = (moonLong - perigeeLong).abs();
    if (diff > 180) diff = 360 - diff;

    return diff < 6.6;
  }

  bool isMoonSquareNode(DateTime time) {
    double jd = _toJD(time);
    final pos = _getMoonPosition(jd);
    final node = moonpos.node(jd);

    double moonLong = pos.lon * 180 / math.pi;
    double nodeLong1 = node * 180 / math.pi;

    double diff1 = (moonLong - nodeLong1).abs();
    if (diff1 > 180) diff1 = 360 - diff1;

    return (diff1 - 90.0).abs() < 6.5;
  }

  @override
  List<CalendarInterval> getIntervals(DateTime start, DateTime end) {
    List<CalendarInterval> intervals = [];
    DateTime current = start;

    CalendarInfo currentInfo = _getCalendarInfo(current);
    DateTime intervalStart = current;

    while (current.isBefore(end)) {
      final tConst = _timeToNextConstellation(current);
      final tNode = _timeToNextNodeEvent(current);
      final tPerigee = _timeToNextPerigeeEvent(current);

      Duration minJump = tConst;
      if (tNode < minJump) minJump = tNode;
      if (tPerigee < minJump) minJump = tPerigee;

      if (minJump <= Duration.zero || minJump < const Duration(minutes: 5)) {
        minJump = const Duration(minutes: 15);
      }

      Duration safeJump = Duration(minutes: (minJump.inMinutes * 0.9).round());
      if (safeJump < const Duration(minutes: 5))
        safeJump = const Duration(minutes: 5);

      current = current.add(safeJump);
      if (current.isAfter(end)) current = end;

      final info = _getCalendarInfo(current);

      if (info.quality != currentInfo.quality ||
          info.isGrayDay != currentInfo.isGrayDay) {
        DateTime t0 = current.subtract(safeJump);
        DateTime t1 = current;
        DateTime transitionTime = _findTransition(
          t0,
          t1,
          currentInfo.quality,
          currentInfo.isGrayDay,
        );

        intervals.add(
          CalendarInterval(
            start: intervalStart,
            end: transitionTime,
            quality: currentInfo.quality,
            isGrayDay: currentInfo.isGrayDay,
            message: currentInfo.message,
          ),
        );

        intervalStart = transitionTime;
        current = transitionTime.add(const Duration(minutes: 1));
        currentInfo = _getCalendarInfo(current);
      }
    }

    intervals.add(
      CalendarInterval(
        start: intervalStart,
        end: end,
        quality: currentInfo.quality,
        isGrayDay: currentInfo.isGrayDay,
        message: currentInfo.message,
      ),
    );

    return intervals;
  }

  DateTime _findTransition(DateTime t0, DateTime t1, PlantQuality q0, bool g0) {
    while (t1.difference(t0).inMinutes > 1) {
      DateTime mid = t0.add(
        Duration(minutes: (t1.difference(t0).inMinutes / 2).round()),
      );
      final info = _getCalendarInfo(mid);
      if (info.quality == q0 && info.isGrayDay == g0) {
        t0 = mid;
      } else {
        t1 = mid;
      }
    }
    return t0;
  }

  CalendarInfo _getCalendarInfo(DateTime time, {bool includePlanets = false}) {
    if (!includePlanets && _infoCache.containsKey(time))
      return _infoCache[time]!;

    double moonLongitude = getMoonLongitude(time);
    bool isNearNode = this.isNearNode(time);
    bool isNearPerigee = this.isNearPerigee(time);
    bool isSquare = this.isMoonSquareNode(time);
    bool isGrayDay = isNearNode || isNearPerigee || isSquare;
    final moonPhase = getMoonPhase(time);

    String message = '';
    if (isNearNode) {
      message = 'Gray Day: Near Lunar Node.';
    } else if (isNearPerigee) {
      message = 'Gray Day: Near Lunar Perigee.';
    } else if (isSquare) {
      message = 'Gray Day: Moon Square Node.';
    }

    PlantQuality quality = getQualityFromLongitude(moonLongitude);

    final info = CalendarInfo(
      quality: isGrayDay ? PlantQuality.none : quality,
      isGrayDay: isGrayDay,
      message: message,
      sapFlow: includePlanets ? _calculateSapFlow(time) : 'Ascending',
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

  String _calculateSapFlow(DateTime time) {
    double dec1 = getMoonDeclination(time);
    double dec2 = getMoonDeclination(time.add(const Duration(hours: 1)));
    return dec2 > dec1 ? 'Ascending' : 'Descending';
  }

  Duration _timeToNextConstellation(DateTime time) {
    final long = getMoonLongitude(time);
    double minDiff = 360.0;
    for (var boundary in dornachBoundaries) {
      double diff = (boundary.startDegree - long) % 360.0;
      if (diff < 0) diff += 360.0;
      if (diff < minDiff) minDiff = diff;
    }
    double hours = minDiff / 0.54;
    return Duration(minutes: (hours * 60).round());
  }

  Duration _timeToNextNodeEvent(DateTime time) {
    double jd = _toJD(time);
    final pos = _getMoonPosition(jd);
    final node = moonpos.node(jd);

    double moonLong = pos.lon * 180 / math.pi;
    double nodeLong = node * 180 / math.pi;

    double diff = (nodeLong - moonLong) % 180.0;
    if (diff < 0) diff += 180.0;

    double hoursToAlignment = diff / 0.54;
    DateTime alignmentTime = time.add(
      Duration(minutes: (hoursToAlignment * 60).round()),
    );

    DateTime entryTime = alignmentTime.subtract(
      const Duration(hours: 4, minutes: 30),
    );
    DateTime exitTime = alignmentTime.add(
      const Duration(hours: 4, minutes: 30),
    );

    if (entryTime.isAfter(time)) {
      return entryTime.difference(time);
    } else if (exitTime.isAfter(time)) {
      return exitTime.difference(time);
    } else {
      return const Duration(days: 13);
    }
  }

  Duration _timeToNextPerigeeEvent(DateTime time) {
    double jd = _toJD(time);
    final pos = _getMoonPosition(jd);
    final perigee = moonpos.perigee(jd);

    double moonLong = pos.lon * 180 / math.pi;
    double perigeeLong = perigee * 180 / math.pi;

    double diff = (perigeeLong - moonLong) % 360.0;
    if (diff < 0) diff += 360.0;

    double hoursToAlignment = diff / 0.54;
    DateTime alignmentTime = time.add(
      Duration(minutes: (hoursToAlignment * 60).round()),
    );

    DateTime entryTime = alignmentTime.subtract(const Duration(hours: 12));
    DateTime exitTime = alignmentTime.add(const Duration(hours: 12));

    if (entryTime.isAfter(time)) {
      return entryTime.difference(time);
    } else if (exitTime.isAfter(time)) {
      return exitTime.difference(time);
    } else {
      return const Duration(days: 27);
    }
  }
}
