import 'package:astronomia/moonposition.dart' as moonpos;
import 'package:astronomia/moonillum.dart' as moonillum;
import 'package:astronomia/planetposition.dart' as planetpos;
import 'package:astronomia/solar.dart' as solar;
import 'package:astronomia/coord.dart' as coord;
import 'package:astronomia/nutation.dart';
import 'package:astronomia/astronomia.dart';
import 'dart:math' as math;
import 'dornach_boundaries.dart';
import 'algorithm.dart';

enum PlantQuality { root, leaf, flower, fruit, none }

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
    if (illuminatedFraction > 0.99) return 'Full Moon';
    if (illuminatedFraction < 0.01) return 'New Moon';
    if (isWaxing) {
      if (illuminatedFraction < 0.5) return 'Waxing Crescent';
      if (illuminatedFraction < 0.51) return 'First Quarter';
      return 'Waxing Gibbous';
    } else {
      if (illuminatedFraction > 0.5) return 'Waning Gibbous';
      if (illuminatedFraction > 0.49) return 'Last Quarter';
      return 'Waning Crescent';
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
    double jd = _toJD(time);
    double i = moonillum.phaseAngle3(jd);
    double k = moonillum.illuminated(i);
    
    double t = j2000Century(jd);
    double d = mod2pi(toRad(horner(t, [297.8501921, 445267.1114034,
      -0.0018819, 1 / 545868.0, -1 / 113065000.0])));
    
    bool isWaxing = d < math.pi;

    return MoonPhaseInfo(
      illuminatedFraction: k,
      isWaxing: isWaxing,
      phaseAngle: i,
    );
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
      String name, planetpos.Planet planet, double jd) {
    final pPos = planet.position(jd);
    final ePos = _earth.position(jd);

    final x = pPos.range * math.cos(pPos.lat) * math.cos(pPos.lon) -
        ePos.range * math.cos(ePos.lat) * math.cos(ePos.lon);
    final y = pPos.range * math.cos(pPos.lat) * math.sin(pPos.lon) -
        ePos.range * math.cos(ePos.lat) * math.sin(ePos.lon);

    double lon = math.atan2(y, x) * 180 / math.pi;
    if (lon < 0) lon += 360;

    return PlanetInfo(name: name, longitude: lon);
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

    // Perigee window is +/- 12 hours. Moon moves ~13.2 deg/day, so ~6.6 deg in 12h.
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

  DateTime? _findExactSquareTime(DateTime time) {
    final startTime = time.subtract(const Duration(days: 1));
    final interval = const Duration(hours: 12);
    
    List<double> y = [];
    for (int i = 0; i < 5; i++) {
      final t = startTime.add(interval * i);
      double dayFraction = t.day + t.hour / 24.0 + t.minute / 1440.0 + t.second / 86400.0;
      double jd = calendarGregorianToJD(t.year, t.month, dayFraction);
      final pos = _getMoonPosition(jd);
      final node = moonpos.node(jd);
      
      double moonLong = pos.lon * 180 / math.pi;
      double nodeLong = node * 180 / math.pi;
      
      double diff = (moonLong - nodeLong).abs();
      if (diff > 180) diff = 360 - diff;
      
      y.add((diff - 90.0).abs());
    }
    
    final x1 = 0.0;
    final x5 = 48.0;
    
    final len5 = Len5(x1, x5, y);
    
    try {
      final ext = len5.extremum();
      if (ext.y < 1.0) {
        return startTime.add(Duration(minutes: (ext.x * 60).round()));
      }
    } catch (e) {
      // No extremum
    }
    
    return null;
  }

  @override
  List<CalendarInterval> getIntervals(DateTime start, DateTime end) {
    List<CalendarInterval> intervals = [];
    DateTime current = start;
    
    CalendarInfo? lastInfo;
    DateTime? intervalStart;
    
    while (current.isBefore(end)) {
      final info = _getCalendarInfo(current);
      
      if (lastInfo == null) {
        lastInfo = info;
        intervalStart = current;
      } else if (info.quality != lastInfo.quality || info.isGrayDay != lastInfo.isGrayDay) {
        intervals.add(CalendarInterval(
          start: intervalStart!,
          end: current,
          quality: lastInfo.quality,
          isGrayDay: lastInfo.isGrayDay,
          message: lastInfo.message,
        ));
        lastInfo = info;
        intervalStart = current;
      }
      
      current = current.add(const Duration(hours: 1));
    }
    
    if (lastInfo != null && intervalStart != null) {
      intervals.add(CalendarInterval(
        start: intervalStart,
        end: end,
        quality: lastInfo.quality,
        isGrayDay: lastInfo.isGrayDay,
        message: lastInfo.message,
      ));
    }
    
    return intervals;
  }



  CalendarInfo _getCalendarInfo(DateTime time, {bool includePlanets = false}) {
    if (!includePlanets && _infoCache.containsKey(time)) return _infoCache[time]!;

    double moonLongitude = getMoonLongitude(time);
    bool isNearNode = this.isNearNode(time);
    bool isNearPerigee = this.isNearPerigee(time);
    
    DateTime? squareTime = _findExactSquareTime(time);
    bool isSquare = false;
    if (squareTime != null) {
      final duration = const Duration(hours: 26);
      final endTime = squareTime.add(duration);
      isSquare = time.isAfter(squareTime) && time.isBefore(endTime);
    }
    
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


}
