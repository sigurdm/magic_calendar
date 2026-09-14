import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:magic_calendar/src/services/weather_service.dart';

/// Configurable stand-in for [EphemerisService].
///
/// Every knob defaults to an inert value, so a test only has to spell out the
/// behaviour it actually depends on. Prefer this over hand-rolling another
/// mock: the eleven it replaced had drifted apart in small ways (different
/// moon phases, different sunrise times) that had nothing to do with what the
/// individual tests were checking.
final class FakeEphemerisService with EphemerisService {
  /// Creates a fake returning the supplied fixed values.
  FakeEphemerisService({
    this.moonLongitude = 0.0,
    this.moonDeclination = 0.0,
    this.nearNode = false,
    this.nearPerigee = false,
    this.nearApogee = false,
    this.moonSaturnOpposition = false,
    this.moonSquareNode = false,
    MoonPhaseInfo? moonPhase,
    this.planets = const [],
    this.declinationAt,
    this.sunTimesAt,
    this.intervalsAt,
    this.error,
  }) : moonPhase =
           moonPhase ??
           const MoonPhaseInfo(
             illuminatedFraction: 0.5,
             isWaxing: true,
             phaseAngle: 0.0,
           );

  /// Value returned by [getMoonLongitude].
  final double moonLongitude;

  /// Value returned by [getMoonDeclination] when [declinationAt] is null.
  final double moonDeclination;

  /// Value returned by [isNearNode].
  final bool nearNode;

  /// Value returned by [isNearPerigee].
  final bool nearPerigee;

  /// Value returned by [isNearApogee].
  final bool nearApogee;

  /// Value returned by [isMoonSaturnOpposition].
  final bool moonSaturnOpposition;

  /// Value returned by [isMoonSquareNode].
  final bool moonSquareNode;

  /// Value returned by [getMoonPhase].
  final MoonPhaseInfo moonPhase;

  /// Value returned by [getPlanets].
  final List<PlanetInfo> planets;

  /// Time-dependent declination, for tests that need the moon to be ascending
  /// or descending across two sampled instants.
  final double Function(DateTime time)? declinationAt;

  /// Time-dependent sun times. Defaults to noon-only at [DateTime.now].
  final SunriseSunsetInfo Function(DateTime date)? sunTimesAt;

  /// Time-dependent intervals. Defaults to an empty list.
  final List<CalendarInterval> Function(DateTime start, DateTime end)?
  intervalsAt;

  /// When non-null, every method on this fake throws it.
  ///
  /// Used to exercise the callers' error handling.
  final Object? error;

  /// Every `(start, end)` pair passed to [getIntervals], in call order.
  ///
  /// Lets caching tests assert that a range was fetched exactly once.
  final List<({DateTime start, DateTime end})> getIntervalsCalls = [];

  void _maybeThrow() {
    final e = error;
    if (e != null) throw e;
  }

  @override
  double getMoonLongitude(DateTime time) {
    _maybeThrow();
    return moonLongitude;
  }

  @override
  double getMoonDeclination(DateTime time) {
    _maybeThrow();
    return declinationAt?.call(time) ?? moonDeclination;
  }

  @override
  bool isNearNode(DateTime time) {
    _maybeThrow();
    return nearNode;
  }

  @override
  bool isNearPerigee(DateTime time) {
    _maybeThrow();
    return nearPerigee;
  }

  @override
  bool isNearApogee(DateTime time) {
    _maybeThrow();
    return nearApogee;
  }

  @override
  bool isMoonSaturnOpposition(DateTime time) {
    _maybeThrow();
    return moonSaturnOpposition;
  }

  @override
  bool isMoonSquareNode(DateTime time) {
    _maybeThrow();
    return moonSquareNode;
  }

  @override
  MoonPhaseInfo getMoonPhase(DateTime time) {
    _maybeThrow();
    return moonPhase;
  }

  @override
  List<PlanetInfo> getPlanets(DateTime time) {
    _maybeThrow();
    return planets;
  }

  @override
  List<CalendarInterval> getIntervals(DateTime start, DateTime end) {
    _maybeThrow();
    getIntervalsCalls.add((start: start, end: end));
    return intervalsAt?.call(start, end) ?? const [];
  }

  @override
  SunriseSunsetInfo getSunriseSunset(DateTime date, double lat, double lon) {
    _maybeThrow();
    return sunTimesAt?.call(date) ?? SunriseSunsetInfo(noon: DateTime.now());
  }
}

/// Sun times spanning a conventional 06:00 / 12:00 / 18:00 day on [date].
SunriseSunsetInfo plainDaylight(DateTime date) => SunriseSunsetInfo(
  sunrise: DateTime(date.year, date.month, date.day, 6),
  sunset: DateTime(date.year, date.month, date.day, 18),
  noon: DateTime(date.year, date.month, date.day, 12),
);

/// One root-quality interval covering the whole requested range.
///
/// Intended for [FakeEphemerisService.intervalsAt] in tests that care about
/// how ranges are merged and cached rather than about their contents.
List<CalendarInterval> singleSpanningInterval(DateTime start, DateTime end) => [
  CalendarInterval(
    start: start,
    end: end,
    quality: PlantQuality.root,
    isGrayDay: false,
    message: '',
  ),
];

/// Configurable stand-in for [WeatherService].
final class FakeWeatherService implements WeatherService {
  /// Creates a fake serving the supplied fixed data.
  FakeWeatherService({
    this.forecast = const [],
    this.historical = const [],
    this.forecastError,
    this.historicalError,
  });

  /// Value returned by [getForecast].
  final List<WeatherDataPoint> forecast;

  /// Value returned by [getHistoricalData].
  final List<WeatherDataPoint> historical;

  /// When non-null, [getForecast] throws it instead of returning.
  final Object? forecastError;

  /// When non-null, [getHistoricalData] throws it instead of returning.
  final Object? historicalError;

  @override
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon) async {
    final e = forecastError;
    if (e != null) throw e;
    return forecast;
  }

  @override
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) async {
    final e = historicalError;
    if (e != null) throw e;
    return historical;
  }

  /// Whether [close] has been called.
  bool isClosed = false;

  @override
  void close() {
    isClosed = true;
  }
}
