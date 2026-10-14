import 'dart:math' as math;

/// Long-term monthly means of air temperature and precipitation for one
/// location, January first.
///
/// These are the inputs to the Köppen–Geiger classification (see
/// `KoppenClass.classify`).
final class MonthlyClimateNormals {
  /// Mean daily air temperature of each month in °C, January first.
  final List<double> temperature;

  /// Mean precipitation total of each month in mm, January first.
  final List<double> precipitation;

  /// Creates normals from twelve monthly mean [temperature]s (°C) and twelve
  /// monthly [precipitation] totals (mm), January first.
  ///
  /// Both lists must hold exactly 12 finite values, and every precipitation
  /// value must be non-negative. The lists are copied.
  MonthlyClimateNormals({
    required List<double> temperature,
    required List<double> precipitation,
  }) : temperature = List.unmodifiable(temperature),
       precipitation = List.unmodifiable(precipitation) {
    if (temperature.length != 12 || !temperature.every((t) => t.isFinite)) {
      throw ArgumentError.value(
        temperature,
        'temperature',
        'Must be 12 finite monthly values',
      );
    }
    if (precipitation.length != 12 ||
        !precipitation.every((p) => p.isFinite && p >= 0)) {
      throw ArgumentError.value(
        precipitation,
        'precipitation',
        'Must be 12 finite, non-negative monthly values',
      );
    }
  }

  /// Reads normals written by [toJson].
  ///
  /// Throws a [FormatException] if [json] does not hold two lists of 12
  /// numbers under `t` and `p`.
  factory MonthlyClimateNormals.fromJson(Map<String, Object?> json) {
    List<double> readMonths(String key) {
      final values = json[key];
      if (values is! List<Object?> || values.length != 12) {
        throw FormatException('Expected 12 monthly values under "$key"', json);
      }
      return [
        for (final value in values)
          if (value is num)
            value.toDouble()
          else
            throw FormatException(
              'Non-numeric monthly value under "$key"',
              json,
            ),
      ];
    }

    final temperature = readMonths('t');
    final precipitation = readMonths('p');
    if (!temperature.every((t) => t.isFinite) ||
        !precipitation.every((p) => p.isFinite && p >= 0)) {
      throw FormatException('Monthly values out of range', json);
    }
    return MonthlyClimateNormals(
      temperature: temperature,
      precipitation: precipitation,
    );
  }

  /// Mean annual temperature in °C.
  double get meanAnnualTemperature =>
      temperature.fold(0.0, (sum, t) => sum + t) / 12;

  /// Mean annual precipitation in mm.
  double get annualPrecipitation =>
      precipitation.fold(0.0, (sum, p) => sum + p);

  /// Mean temperature of the coldest month in °C.
  double get coldestMonthTemperature => temperature.reduce(math.min);

  /// Mean temperature of the warmest month in °C.
  double get warmestMonthTemperature => temperature.reduce(math.max);

  /// Number of months with a mean temperature above 10 °C.
  int get monthsAbove10Degrees => temperature.where((t) => t > 10).length;

  /// Whether April–September is at least as warm as October–March.
  ///
  /// This is the Köppen–Geiger definition of which half-year is summer. It
  /// is true north of the tropics and false south of them; inside the
  /// tropics it can go either way.
  bool get hasNorthernSeasons {
    var aprilToSeptember = 0.0;
    var octoberToMarch = 0.0;
    for (var month = 0; month < 12; month++) {
      if (month >= 3 && month <= 8) {
        aprilToSeptember += temperature[month];
      } else {
        octoberToMarch += temperature[month];
      }
    }
    return aprilToSeptember >= octoberToMarch;
  }

  /// Zero-based indexes of the six summer months.
  ///
  /// Summer is April–September when [hasNorthernSeasons] is true, and
  /// October–March otherwise.
  List<int> get summerMonthIndexes => hasNorthernSeasons
      ? const [3, 4, 5, 6, 7, 8]
      : const [9, 10, 11, 0, 1, 2];

  /// Zero-based indexes of the six winter months: those not in
  /// [summerMonthIndexes].
  List<int> get winterMonthIndexes => hasNorthernSeasons
      ? const [9, 10, 11, 0, 1, 2]
      : const [3, 4, 5, 6, 7, 8];

  /// A JSON-compatible representation, read back by
  /// [MonthlyClimateNormals.fromJson].
  Map<String, Object?> toJson() => {
    't': [for (final t in temperature) _round(t, 2)],
    'p': [for (final p in precipitation) _round(p, 1)],
  };

  static double _round(double value, int decimals) {
    final factor = math.pow(10, decimals);
    return (value * factor).roundToDouble() / factor;
  }

  @override
  bool operator ==(Object other) =>
      other is MonthlyClimateNormals &&
      _listEquals(temperature, other.temperature) &&
      _listEquals(precipitation, other.precipitation);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(temperature), Object.hashAll(precipitation));

  @override
  String toString() =>
      'MonthlyClimateNormals(T: ${temperature.map((t) => t.toStringAsFixed(1)).join(' ')}; '
      'P: ${precipitation.map((p) => p.toStringAsFixed(0)).join(' ')})';

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
