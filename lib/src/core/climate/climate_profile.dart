import 'dart:math' as math;

import 'hardiness_zone.dart';
import 'koppen_class.dart';
import 'monthly_climate_normals.dart';

/// Number of days in the no-leap calendar that climatology is computed in.
///
/// 29 February is folded into 28 February, so every year has the same
/// day numbering.
const int climateYearLength = 365;

const List<int> _monthStartDays = [
  0,
  31,
  59,
  90,
  120,
  151,
  181,
  212,
  243,
  273,
  304,
  334,
];

/// The day of the no-leap year of [date], from 0 (1 January) to 364
/// (31 December).
///
/// 29 February counts as 28 February (day 58).
int climateDayOfYear(DateTime date) {
  final day = date.month == 2 ? math.min(date.day, 28) : date.day;
  return _monthStartDays[date.month - 1] + day - 1;
}

/// A UTC date in the non-leap year 2001 falling on [dayOfYear] of the
/// no-leap year.
///
/// Only the month and day of the result are meaningful. The [dayOfYear] is
/// taken modulo [climateYearLength], so negative values and values past the
/// end of the year wrap around.
DateTime climateDateOfDay(int dayOfYear) =>
    DateTime.utc(2001, 1, 1 + dayOfYear % climateYearLength);

/// Thirty years or so of daily weather for one location, as fetched from a
/// reanalysis archive.
final class DailyClimateSeries {
  /// The calendar day of each value, as UTC midnight.
  final List<DateTime> dates;

  /// Daily mean air temperature at 2 m in °C, or null where missing.
  final List<double?> meanTemperature;

  /// Daily minimum air temperature at 2 m in °C, or null where missing.
  final List<double?> minimumTemperature;

  /// Daily precipitation total in mm, or null where missing.
  final List<double?> precipitation;

  /// Elevation of the data's grid cell in m, if known.
  final double? elevation;

  /// Creates a series from parallel daily lists.
  ///
  /// All four lists must have the same length. They are copied.
  DailyClimateSeries({
    required List<DateTime> dates,
    required List<double?> meanTemperature,
    required List<double?> minimumTemperature,
    required List<double?> precipitation,
    this.elevation,
  }) : dates = List.unmodifiable(dates),
       meanTemperature = List.unmodifiable(meanTemperature),
       minimumTemperature = List.unmodifiable(minimumTemperature),
       precipitation = List.unmodifiable(precipitation) {
    final length = dates.length;
    if (meanTemperature.length != length) {
      throw ArgumentError.value(
        meanTemperature.length,
        'meanTemperature',
        'Must have one value per date ($length)',
      );
    }
    if (minimumTemperature.length != length) {
      throw ArgumentError.value(
        minimumTemperature.length,
        'minimumTemperature',
        'Must have one value per date ($length)',
      );
    }
    if (precipitation.length != length) {
      throw ArgumentError.value(
        precipitation.length,
        'precipitation',
        'Must have one value per date ($length)',
      );
    }
  }

  /// Number of days in the series.
  int get length => dates.length;
}

/// The part of the year during which the smoothed climatological daily mean
/// temperature is at or above [thresholdCelsius].
///
/// Days are season offsets: the number of days after the climatological
/// coldest day of the owning [ClimateProfile] (see
/// [ClimateProfile.dayOfYearAtOffset]).
final class ThermalSeason {
  /// The daily mean temperature defining the season, in °C.
  final int thresholdCelsius;

  /// The season offset on which the smoothed mean first reaches the
  /// threshold, or null if it never does or never drops below it.
  final int? start;

  /// The first season offset after the warmest day on which the smoothed
  /// mean is below the threshold again, or null when [start] is null.
  ///
  /// This is [climateYearLength] when the mean stays above the threshold
  /// until the next coldest day.
  final int? end;

  /// Whether the smoothed mean stays at or above the threshold all year.
  final bool isYearRound;

  const ThermalSeason._(
    this.thresholdCelsius, {
    required this.start,
    required this.end,
    required this.isYearRound,
  });

  /// A season from season offset [start] up to, but excluding, [end].
  ///
  /// It must hold that 0 ≤ [start] < [end] ≤ [climateYearLength].
  factory ThermalSeason.bounded(
    int thresholdCelsius, {
    required int start,
    required int end,
  }) {
    RangeError.checkValueInInterval(start, 0, climateYearLength - 1, 'start');
    RangeError.checkValueInInterval(end, start + 1, climateYearLength, 'end');
    return ThermalSeason._(
      thresholdCelsius,
      start: start,
      end: end,
      isYearRound: false,
    );
  }

  /// A threshold the smoothed mean never drops below.
  const ThermalSeason.yearRound(this.thresholdCelsius)
    : start = null,
      end = null,
      isYearRound = true;

  /// A threshold the smoothed mean never reaches.
  const ThermalSeason.neverReached(this.thresholdCelsius)
    : start = null,
      end = null,
      isYearRound = false;

  /// Whether the season has a start and an end within the year.
  bool get isBounded => start != null;

  /// Whether the smoothed mean never reaches the threshold.
  bool get isNeverReached => !isYearRound && start == null;

  /// Length of the season in days.
  int get lengthInDays => switch ((start, end)) {
    (final start?, final end?) => end - start,
    _ => isYearRound ? climateYearLength : 0,
  };

  Map<String, Object?> _toJson() => {
    'threshold': thresholdCelsius,
    'start': ?start,
    'end': ?end,
    if (isYearRound) 'yearRound': true,
  };

  static ThermalSeason _fromJson(Map<String, Object?> json) {
    final threshold = _readInt(json, 'threshold');
    if (json['yearRound'] == true) return ThermalSeason.yearRound(threshold);
    final start = _readOptionalInt(json, 'start');
    if (start == null) return ThermalSeason.neverReached(threshold);
    final end = _readInt(json, 'end');
    if (start < 0 || end <= start || end > climateYearLength) {
      throw FormatException('Thermal season out of range', json);
    }
    return ThermalSeason.bounded(threshold, start: start, end: end);
  }

  @override
  bool operator ==(Object other) =>
      other is ThermalSeason &&
      thresholdCelsius == other.thresholdCelsius &&
      start == other.start &&
      end == other.end &&
      isYearRound == other.isYearRound;

  @override
  int get hashCode => Object.hash(thresholdCelsius, start, end, isYearRound);

  @override
  String toString() => isYearRound
      ? 'ThermalSeason($thresholdCelsius °C, year-round)'
      : isBounded
      ? 'ThermalSeason($thresholdCelsius °C, $start–$end)'
      : 'ThermalSeason($thresholdCelsius °C, never)';
}

/// Air-frost statistics: days with a minimum temperature of 0 °C or below.
///
/// Each season year runs from one climatological coldest day to the next.
/// Frosts before the warmest day are spring frosts, frosts after it are
/// autumn frosts. Days are season offsets, as in [ThermalSeason].
final class FrostStatistics {
  /// Number of complete season years the statistics cover.
  final int seasonCount;

  /// Number of season years with at least one air frost.
  final int seasonsWithFrost;

  /// Median season offset of the last spring frost, or null when most
  /// season years have no spring frost.
  final int? medianLastSpringFrost;

  /// Season offset by which the last spring frost had passed in nine of ten
  /// season years, or null when fewer than one in ten have a spring frost.
  final int? lastSpringFrost90;

  /// Median season offset of the first autumn frost, or null when most
  /// season years have no autumn frost.
  final int? medianFirstAutumnFrost;

  /// Season offset before which the first autumn frost had come in one of
  /// ten season years, or null when fewer than one in ten have an autumn
  /// frost.
  final int? firstAutumnFrost10;

  /// Median number of days between the last spring and the first autumn
  /// frost.
  final int medianFrostFreeDays;

  /// Creates frost statistics from already computed values.
  ///
  /// The [seasonsWithFrost] must be between 0 and [seasonCount].
  FrostStatistics({
    required this.seasonCount,
    required this.seasonsWithFrost,
    required this.medianLastSpringFrost,
    required this.lastSpringFrost90,
    required this.medianFirstAutumnFrost,
    required this.firstAutumnFrost10,
    required this.medianFrostFreeDays,
  }) {
    RangeError.checkValueInInterval(
      seasonsWithFrost,
      0,
      seasonCount,
      'seasonsWithFrost',
    );
  }

  /// Whether any season year had an air frost.
  bool get hasFrost => seasonsWithFrost > 0;

  Map<String, Object?> _toJson() => {
    'seasons': seasonCount,
    'seasonsWithFrost': seasonsWithFrost,
    'medianLastSpring': ?medianLastSpringFrost,
    'lastSpring90': ?lastSpringFrost90,
    'medianFirstAutumn': ?medianFirstAutumnFrost,
    'firstAutumn10': ?firstAutumnFrost10,
    'medianFrostFreeDays': medianFrostFreeDays,
  };

  static FrostStatistics _fromJson(Map<String, Object?> json) {
    final seasonCount = _readInt(json, 'seasons');
    final seasonsWithFrost = _readInt(json, 'seasonsWithFrost');
    if (seasonsWithFrost < 0 || seasonsWithFrost > seasonCount) {
      throw FormatException('Frost season count out of range', json);
    }
    return FrostStatistics(
      seasonCount: seasonCount,
      seasonsWithFrost: seasonsWithFrost,
      medianLastSpringFrost: _readOptionalInt(json, 'medianLastSpring'),
      lastSpringFrost90: _readOptionalInt(json, 'lastSpring90'),
      medianFirstAutumnFrost: _readOptionalInt(json, 'medianFirstAutumn'),
      firstAutumnFrost10: _readOptionalInt(json, 'firstAutumn10'),
      medianFrostFreeDays: _readInt(json, 'medianFrostFreeDays'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FrostStatistics &&
      seasonCount == other.seasonCount &&
      seasonsWithFrost == other.seasonsWithFrost &&
      medianLastSpringFrost == other.medianLastSpringFrost &&
      lastSpringFrost90 == other.lastSpringFrost90 &&
      medianFirstAutumnFrost == other.medianFirstAutumnFrost &&
      firstAutumnFrost10 == other.firstAutumnFrost10 &&
      medianFrostFreeDays == other.medianFrostFreeDays;

  @override
  int get hashCode => Object.hash(
    seasonCount,
    seasonsWithFrost,
    medianLastSpringFrost,
    lastSpringFrost90,
    medianFirstAutumnFrost,
    firstAutumnFrost10,
    medianFrostFreeDays,
  );
}

/// The climate of one location, condensed from a multi-decade daily series.
///
/// Holds what the app needs to classify the climate and to line its seasons
/// up with another location's: monthly normals, the smoothed annual
/// temperature cycle's key dates, and frost statistics.
final class ClimateProfile {
  /// Version of the [toJson] format. [ClimateProfile.fromJson] rejects
  /// other versions, which invalidates cached profiles when the derivation
  /// changes.
  static const int jsonVersion = 1;

  /// Daily mean temperatures, in °C, whose crossings define
  /// [thermalSeasons].
  static const List<int> thermalThresholds = [5, 10, 15];

  /// Latitude the data describes, in degrees.
  final double latitude;

  /// Longitude the data describes, in degrees.
  final double longitude;

  /// Elevation of the data's grid cell in m, if known.
  final double? elevation;

  /// First calendar year of the underlying series.
  final int firstYear;

  /// Last calendar year of the underlying series.
  final int lastYear;

  /// Monthly temperature and precipitation normals.
  final MonthlyClimateNormals normals;

  /// Mean over the years of each year's lowest daily minimum temperature,
  /// in °C.
  final double meanAnnualExtremeMinimum;

  /// Day of the no-leap year on which the smoothed daily mean temperature
  /// is lowest. Season offsets count from this day.
  final int coldestDay;

  /// Day of the no-leap year on which the smoothed daily mean temperature
  /// is highest.
  final int warmestDay;

  /// Seasons above each of [thermalThresholds], in the same order.
  final List<ThermalSeason> thermalSeasons;

  /// Air-frost statistics.
  final FrostStatistics frost;

  /// Creates a profile from already derived values.
  ///
  /// The [coldestDay] and [warmestDay] must be different days between 0 and
  /// 364, and [thermalSeasons] must hold one season per entry of
  /// [thermalThresholds], in that order. The list is copied.
  ClimateProfile({
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.firstYear,
    required this.lastYear,
    required this.normals,
    required this.meanAnnualExtremeMinimum,
    required this.coldestDay,
    required this.warmestDay,
    required List<ThermalSeason> thermalSeasons,
    required this.frost,
  }) : thermalSeasons = List.unmodifiable(thermalSeasons) {
    RangeError.checkValueInInterval(
      coldestDay,
      0,
      climateYearLength - 1,
      'coldestDay',
    );
    RangeError.checkValueInInterval(
      warmestDay,
      0,
      climateYearLength - 1,
      'warmestDay',
    );
    if (warmestDay == coldestDay) {
      throw ArgumentError.value(
        warmestDay,
        'warmestDay',
        'Must differ from coldestDay',
      );
    }
    if (thermalSeasons.length != thermalThresholds.length ||
        thermalSeasons.indexed.any(
          (entry) => entry.$2.thresholdCelsius != thermalThresholds[entry.$1],
        )) {
      throw ArgumentError.value(
        thermalSeasons,
        'thermalSeasons',
        'Must hold one season per threshold in $thermalThresholds',
      );
    }
  }

  /// Derives a profile from a daily [series] for the location at
  /// [latitude], [longitude].
  ///
  /// Throws a [FormatException] if the series is not made of whole calendar
  /// years of consecutive days, spans fewer than two years, or has missing
  /// values. Classifying a gappy series would silently skew the result.
  ///
  /// Runs in O(n) time for n days.
  factory ClimateProfile.fromDailySeries(
    DailyClimateSeries series, {
    required double latitude,
    required double longitude,
  }) => _ProfileBuilder(series).build(latitude: latitude, longitude: longitude);

  /// Reads a profile written by [toJson].
  ///
  /// Throws a [FormatException] if [json] is malformed or was written by a
  /// different [jsonVersion].
  factory ClimateProfile.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version != jsonVersion) {
      throw FormatException(
        'Unsupported climate profile version $version (expected $jsonVersion)',
      );
    }
    final coldestDay = _readInt(json, 'coldestDay');
    final warmestDay = _readInt(json, 'warmestDay');
    if (coldestDay < 0 ||
        coldestDay >= climateYearLength ||
        warmestDay < 0 ||
        warmestDay >= climateYearLength ||
        coldestDay == warmestDay) {
      throw FormatException('Coldest or warmest day out of range', json);
    }
    final seasonsJson = json['thermalSeasons'];
    if (seasonsJson is! List<Object?>) {
      throw FormatException('Missing thermal seasons', json);
    }
    final thermalSeasons = [
      for (final season in seasonsJson)
        ThermalSeason._fromJson(_asMap(season, 'thermal season')),
    ];
    if (thermalSeasons.length != thermalThresholds.length ||
        thermalSeasons.indexed.any(
          (entry) => entry.$2.thresholdCelsius != thermalThresholds[entry.$1],
        )) {
      throw FormatException('Unexpected thermal season thresholds', json);
    }
    return ClimateProfile(
      latitude: _readDouble(json, 'latitude'),
      longitude: _readDouble(json, 'longitude'),
      elevation: _readOptionalDouble(json, 'elevation'),
      firstYear: _readInt(json, 'firstYear'),
      lastYear: _readInt(json, 'lastYear'),
      normals: MonthlyClimateNormals.fromJson(
        _asMap(json['normals'], 'normals'),
      ),
      meanAnnualExtremeMinimum: _readDouble(json, 'meanAnnualExtremeMinimum'),
      coldestDay: coldestDay,
      warmestDay: warmestDay,
      thermalSeasons: thermalSeasons,
      frost: FrostStatistics._fromJson(_asMap(json['frost'], 'frost')),
    );
  }

  /// The Köppen–Geiger class of [normals].
  late final KoppenClass koppen = KoppenClass.classify(normals);

  /// The USDA hardiness half-zone of [meanAnnualExtremeMinimum].
  ///
  /// Reanalysis grid cells are 10–30 km across, so expect this to be off by
  /// up to a zone from a local station, especially near coasts.
  HardinessZone get hardinessZone =>
      HardinessZone.fromMeanAnnualExtremeMinimum(meanAnnualExtremeMinimum);

  /// Whether summer falls in April–September, as north of the tropics.
  bool get hasNorthernSeasons => normals.hasNorthernSeasons;

  /// Season offset of [warmestDay].
  int get warmestSeasonOffset => seasonOffsetOf(warmestDay);

  /// The season above [thresholdCelsius].
  ///
  /// The [thresholdCelsius] must be one of [thermalThresholds].
  ThermalSeason thermalSeason(int thresholdCelsius) {
    for (final season in thermalSeasons) {
      if (season.thresholdCelsius == thresholdCelsius) return season;
    }
    throw ArgumentError.value(
      thresholdCelsius,
      'thresholdCelsius',
      'Must be one of $thermalThresholds',
    );
  }

  /// The number of days from [coldestDay] forward to [dayOfYear].
  int seasonOffsetOf(int dayOfYear) =>
      (dayOfYear - coldestDay) % climateYearLength;

  /// The day of the no-leap year [offset] days after [coldestDay].
  int dayOfYearAtOffset(int offset) =>
      (coldestDay + offset) % climateYearLength;

  /// A UTC date in 2001 with the month and day [offset] days after
  /// [coldestDay].
  DateTime dateAtOffset(int offset) =>
      climateDateOfDay(dayOfYearAtOffset(offset));

  /// A JSON-compatible representation, read back by
  /// [ClimateProfile.fromJson].
  Map<String, Object?> toJson() => {
    'version': jsonVersion,
    'latitude': latitude,
    'longitude': longitude,
    'elevation': ?elevation,
    'firstYear': firstYear,
    'lastYear': lastYear,
    'normals': normals.toJson(),
    'meanAnnualExtremeMinimum':
        (meanAnnualExtremeMinimum * 100).roundToDouble() / 100,
    'coldestDay': coldestDay,
    'warmestDay': warmestDay,
    'thermalSeasons': [for (final season in thermalSeasons) season._toJson()],
    'frost': frost._toJson(),
  };

  @override
  String toString() =>
      'ClimateProfile(${koppen.code}, zone ${hardinessZone.label}, '
      '$latitude, $longitude, $firstYear–$lastYear)';
}

/// Derives a [ClimateProfile] from a validated [DailyClimateSeries].
final class _ProfileBuilder {
  final DailyClimateSeries series;

  _ProfileBuilder(this.series);

  ClimateProfile build({required double latitude, required double longitude}) {
    final (firstYear, lastYear) = _validate();
    final normals = _monthlyNormals();
    final meanExtremeMinimum = _meanAnnualExtremeMinimum();

    // Day-of-year climatology in the no-leap calendar, smoothed with a
    // 31-day circular moving average. The smoothing is what keeps a single
    // mild February spell from moving the start of spring by a month.
    final noLeap = _dropLeapDays();
    final years = noLeap.mean.length ~/ climateYearLength;
    final dailyMeans = List.filled(climateYearLength, 0.0);
    for (var i = 0; i < noLeap.mean.length; i++) {
      dailyMeans[i % climateYearLength] += noLeap.mean[i];
    }
    for (var day = 0; day < climateYearLength; day++) {
      dailyMeans[day] /= years;
    }
    final smoothed = _circularMovingAverage(dailyMeans, radius: 15);

    var coldestDay = 0;
    var warmestDay = 0;
    for (var day = 1; day < climateYearLength; day++) {
      if (smoothed[day] < smoothed[coldestDay]) coldestDay = day;
      if (smoothed[day] > smoothed[warmestDay]) warmestDay = day;
    }
    if (coldestDay == warmestDay) {
      // A perfectly flat curve; only possible for synthetic data.
      warmestDay = (coldestDay + climateYearLength ~/ 2) % climateYearLength;
    }
    final warmestOffset = (warmestDay - coldestDay) % climateYearLength;
    final bySeasonOffset = [
      for (var offset = 0; offset < climateYearLength; offset++)
        smoothed[(coldestDay + offset) % climateYearLength],
    ];

    return ClimateProfile(
      latitude: latitude,
      longitude: longitude,
      elevation: series.elevation,
      firstYear: firstYear,
      lastYear: lastYear,
      normals: normals,
      meanAnnualExtremeMinimum: meanExtremeMinimum,
      coldestDay: coldestDay,
      warmestDay: warmestDay,
      thermalSeasons: [
        for (final threshold in ClimateProfile.thermalThresholds)
          _thermalSeason(bySeasonOffset, warmestOffset, threshold),
      ],
      frost: _frostStatistics(
        noLeap.minimum,
        years: years,
        coldestDay: coldestDay,
        warmestOffset: warmestOffset,
      ),
    );
  }

  (int, int) _validate() {
    final dates = series.dates;
    if (dates.isEmpty) {
      throw const FormatException('Empty climate series');
    }
    final first = dates.first;
    final last = dates.last;
    if (first.month != 1 || first.day != 1) {
      throw FormatException('Climate series must start on 1 January', first);
    }
    if (last.month != 12 || last.day != 31) {
      throw FormatException('Climate series must end on 31 December', last);
    }
    if (last.year <= first.year) {
      throw const FormatException(
        'Climate series must span at least two calendar years',
      );
    }
    var expected = DateTime.utc(first.year, first.month, first.day);
    for (final date in dates) {
      if (date.year != expected.year ||
          date.month != expected.month ||
          date.day != expected.day) {
        throw FormatException(
          'Climate series is not a run of consecutive days',
          date,
        );
      }
      expected = DateTime.utc(expected.year, expected.month, expected.day + 1);
    }
    var missing = 0;
    for (var i = 0; i < dates.length; i++) {
      if (series.meanTemperature[i] == null ||
          series.minimumTemperature[i] == null ||
          series.precipitation[i] == null) {
        missing++;
      }
    }
    if (missing > 0) {
      throw FormatException(
        'Climate series has $missing days with missing values',
      );
    }
    return (first.year, last.year);
  }

  MonthlyClimateNormals _monthlyNormals() {
    final temperatureSums = List.filled(12, 0.0);
    final temperatureCounts = List.filled(12, 0);
    final precipitationSums = List.filled(12, 0.0);
    final years = <int>{};
    for (var i = 0; i < series.length; i++) {
      final date = series.dates[i];
      final month = date.month - 1;
      years.add(date.year);
      temperatureSums[month] += series.meanTemperature[i]!;
      temperatureCounts[month]++;
      precipitationSums[month] += series.precipitation[i]!;
    }
    return MonthlyClimateNormals(
      temperature: [
        for (var month = 0; month < 12; month++)
          temperatureSums[month] / temperatureCounts[month],
      ],
      precipitation: [
        for (var month = 0; month < 12; month++)
          precipitationSums[month] / years.length,
      ],
    );
  }

  double _meanAnnualExtremeMinimum() {
    final minimumByYear = <int, double>{};
    for (var i = 0; i < series.length; i++) {
      final year = series.dates[i].year;
      final minimum = series.minimumTemperature[i]!;
      if (minimumByYear[year] case final current? when current <= minimum) {
        continue;
      }
      minimumByYear[year] = minimum;
    }
    return minimumByYear.values.fold(0.0, (sum, t) => sum + t) /
        minimumByYear.length;
  }

  ({List<double> mean, List<double> minimum}) _dropLeapDays() {
    final mean = <double>[];
    final minimum = <double>[];
    for (var i = 0; i < series.length; i++) {
      final date = series.dates[i];
      if (date.month == 2 && date.day == 29) continue;
      mean.add(series.meanTemperature[i]!);
      minimum.add(series.minimumTemperature[i]!);
    }
    return (mean: mean, minimum: minimum);
  }

  static List<double> _circularMovingAverage(
    List<double> values, {
    required int radius,
  }) {
    final length = values.length;
    final width = 2 * radius + 1;
    var sum = 0.0;
    for (var k = -radius; k <= radius; k++) {
      sum += values[k % length];
    }
    final result = List.filled(length, 0.0);
    for (var i = 0; i < length; i++) {
      result[i] = sum / width;
      sum += values[(i + radius + 1) % length] - values[(i - radius) % length];
    }
    return result;
  }

  static ThermalSeason _thermalSeason(
    List<double> bySeasonOffset,
    int warmestOffset,
    int threshold,
  ) {
    if (bySeasonOffset.first >= threshold) {
      return ThermalSeason.yearRound(threshold);
    }
    if (bySeasonOffset[warmestOffset] < threshold) {
      return ThermalSeason.neverReached(threshold);
    }
    var start = 0;
    while (bySeasonOffset[start] < threshold) {
      start++;
    }
    var end = warmestOffset + 1;
    while (end < climateYearLength && bySeasonOffset[end] >= threshold) {
      end++;
    }
    return ThermalSeason.bounded(threshold, start: start, end: end);
  }

  static FrostStatistics _frostStatistics(
    List<double> minimum, {
    required int years,
    required int coldestDay,
    required int warmestOffset,
  }) {
    final lastSpring = <int>[];
    final firstAutumn = <int>[];
    final frostFree = <int>[];
    var seasonsWithFrost = 0;
    // Season year y runs from the coldest day of calendar year y to the
    // coldest day of y + 1; only complete ones count.
    for (
      var start = coldestDay;
      start + climateYearLength <= minimum.length;
      start += climateYearLength
    ) {
      int? spring;
      int? autumn;
      for (var offset = 0; offset < climateYearLength; offset++) {
        if (minimum[start + offset] > 0) continue;
        if (offset < warmestOffset) {
          spring = offset;
        } else {
          autumn ??= offset;
        }
      }
      if (spring != null || autumn != null) seasonsWithFrost++;
      final springOrNone = spring ?? -1;
      final autumnOrNone = autumn ?? climateYearLength;
      lastSpring.add(springOrNone);
      firstAutumn.add(autumnOrNone);
      frostFree.add(autumnOrNone - springOrNone - 1);
    }

    int? springPercentile(double q) {
      final value = _percentile(lastSpring, q);
      return value < 0 ? null : value;
    }

    int? autumnPercentile(double q) {
      final value = _percentile(firstAutumn, q);
      return value >= climateYearLength ? null : value;
    }

    return FrostStatistics(
      seasonCount: lastSpring.length,
      seasonsWithFrost: seasonsWithFrost,
      medianLastSpringFrost: springPercentile(0.5),
      lastSpringFrost90: springPercentile(0.9),
      medianFirstAutumnFrost: autumnPercentile(0.5),
      firstAutumnFrost10: autumnPercentile(0.1),
      medianFrostFreeDays: _percentile(frostFree, 0.5),
    );
  }

  /// Nearest-rank percentile of [values] at quantile [q].
  static int _percentile(List<int> values, double q) {
    final sorted = [...values]..sort();
    return sorted[((sorted.length - 1) * q).round()];
  }
}

Map<String, Object?> _asMap(Object? value, String what) {
  if (value is Map<String, Object?>) return value;
  throw FormatException('Expected an object for $what', value);
}

int _readInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected an integer under "$key"', json);
}

int? _readOptionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int?) return value;
  throw FormatException('Expected an integer under "$key"', json);
}

double _readDouble(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('Expected a number under "$key"', json);
}

double? _readOptionalDouble(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('Expected a number under "$key"', json);
}
